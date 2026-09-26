import SwiftUI
import Combine

@MainActor
final class GameModel: ObservableObject {
    enum State { case menu, playing, won }

    @Published var state: State = .menu
    @Published var levelIndex: Int = 0
    @Published var collected: Int = 0
    @Published var goal: Int = 40
    @Published var elapsed: Double = 0
    @Published var progress: Progress
    @Published var toasts: [Achievement] = []
    @Published var tutorialStep: Int = 3
    @Published var lastResult: LevelOutcome?
    @Published var selectedChapter: Int = 0

    private(set) var run = RunStats()
    var scene: GameScene?
    private var hintTask: Task<Void, Never>?

    init() {
        progress = Progress.load()
        SoundKit.shared.enabled = progress.soundOn
        Haptics.enabled = progress.hapticsOn
        selectedChapter = Level.chapter(for: firstOpenLevel).id
    }

    // MARK: Derived

    var level: Level { Level.all[levelIndex] }
    var chapter: Chapter { Level.chapter(for: levelIndex) }
    var isLastLevel: Bool { levelIndex >= Level.all.count - 1 }
    var totalStars: Int { progress.totalStars }
    var maxStars: Int { Level.all.count * 3 }
    var unlockedAchievements: Int { progress.achievements.count }

    func stars(for level: Int) -> Int { progress.records[level]?.stars ?? 0 }

    func isUnlocked(chapter: Chapter) -> Bool { totalStars >= chapter.starsRequired }

    func isUnlocked(level i: Int) -> Bool {
        let ch = Level.chapter(for: i)
        guard isUnlocked(chapter: ch) else { return false }
        if i == ch.levelRange.lowerBound { return true }
        return progress.completed(i - 1)
    }

    func chapterComplete(_ id: Int) -> Bool {
        Level.chapters[id].levelRange.allSatisfy { progress.completed($0) }
    }

    /// The level a "Continue" button should open.
    var firstOpenLevel: Int {
        for i in 0..<Level.all.count where isUnlocked(level: i) && !progress.completed(i) { return i }
        return (0..<Level.all.count).last { isUnlocked(level: $0) } ?? 0
    }

    var nextUnlockedLevel: Int? {
        let n = levelIndex + 1
        return n < Level.all.count && isUnlocked(level: n) ? n : nil
    }

    // MARK: Scene

    func prepareScene(size: CGSize) {
        guard scene == nil else { return }
        let s = GameScene(size: size)
        s.scaleMode = .resizeFill
        s.model = self
        scene = s
    }

    // MARK: Flow

    func play(level index: Int) {
        levelIndex = index
        selectedChapter = chapter.id
        run = RunStats()
        beginAttempt()
    }

    func reset() {
        let resets = run.resets + 1
        run = RunStats()
        run.resets = resets
        progress.stats.resets += 1
        SoundKit.shared.play(.remove)
        beginAttempt()
    }

    private func beginAttempt() {
        collected = 0
        elapsed = 0
        goal = level.totalDrops
        lastResult = nil
        tutorialStep = (levelIndex == 0 && !progress.tutorialDone) ? 0 : 3
        state = .playing
        scene?.load(level)
    }

    func nextLevel() {
        if let n = nextUnlockedLevel { play(level: n) } else { toMenu() }
    }

    func toMenu() {
        state = .menu
        scene?.stopLevel()
        save()
    }

    // MARK: Events from the scene

    func handle(_ event: GameEvent) {
        switch event {
        case .placed(let kind):
            run.partsPlaced += 1
            run.kindsUsed.insert(kind)
            progress.stats.partsPlaced += 1
            SoundKit.shared.play(.place)
            Haptics.place()
            if tutorialStep == 0 { advanceTutorial(to: 1) }
        case .removed:
            SoundKit.shared.play(.remove)
            Haptics.tap()
        case .rotated:
            if tutorialStep == 1 { advanceTutorial(to: 2) }
        case .caught(let kind, let fraction):
            collected += 1
            progress.stats.drops += 1
            progress.stats.dropsByKind[kind.rawValue, default: 0] += 1
            SoundKit.shared.play(.collect(fraction))
            if tutorialStep == 2 && collected >= 5 { advanceTutorial(to: 3) }
        case .absorbed:
            progress.stats.absorbed += 1
            SoundKit.shared.play(.absorb)
        case .contaminated:
            collected = max(0, collected - 1)
            run.contaminations += 1
            progress.stats.contaminations += 1
            SoundKit.shared.play(.bad)
            Haptics.warning()
        case .tick(let t):
            elapsed = t
            progress.stats.playSeconds += 0.1
        case .won(let time, let partsUsed, let kinds):
            finish(elapsed: time, partsUsed: partsUsed, kindsUsed: kinds)
            return
        }
        checkAchievements()
    }

    private func advanceTutorial(to step: Int) {
        withAnimation(.easeInOut(duration: 0.3)) { tutorialStep = step }
    }

    // MARK: Winning

    static func stars(elapsed: Double, par: Double) -> Int {
        if elapsed <= par { return 3 }
        if elapsed <= par * 1.6 { return 2 }
        return 1
    }

    private func finish(elapsed time: Double, partsUsed: Int, kindsUsed: Set<ToolKind>) {
        run.elapsed = time
        run.partsUsed = partsUsed
        run.kindsUsed.formUnion(kindsUsed)
        run.justWon = true

        let stars = GameModel.stars(elapsed: time, par: level.par)
        let bonus = Int(max(300, 5000 - time * 15)) + stars * 500
        var rec = progress.records[levelIndex] ?? LevelRecord()
        let first = rec.completions == 0
        let newBest = !first && (stars > rec.stars || time < rec.bestTime)
        rec.completions += 1
        rec.stars = max(rec.stars, stars)
        rec.bestBonus = max(rec.bestBonus, bonus)
        rec.bestTime = first ? time : min(rec.bestTime, time)
        progress.records[levelIndex] = rec
        if first { progress.stats.levelsCompleted += 1 }
        if levelIndex == 0 { progress.tutorialDone = true }
        tutorialStep = 3

        let headline: String
        let message: String
        switch stars {
        case 3:
            headline = ["Flawless flow.", "Perfect pour.", "Textbook plumbing."].randomElement()!
            message = first ? "Three stars on the first try. Next one's tougher." : "Three stars. You own this level."
        case 2:
            headline = "Smooth."
            message = "Beat par (\(level.par.clock)) for the third star."
        default:
            headline = "Bucket filled."
            message = "Two stars under \((level.par * 1.6).clock). Three under \(level.par.clock)."
        }

        lastResult = LevelOutcome(stars: stars, bonus: bonus, elapsed: time, par: level.par,
                                  partsUsed: partsUsed, partsAvailable: level.partsAvailable,
                                  isNewBest: newBest, isFirstClear: first,
                                  headline: headline, message: message)
        state = .won
        SoundKit.shared.play(.win)
        Haptics.success()
        checkAchievements()
        run.justWon = false
        save()
    }

    // MARK: Achievements

    private func checkAchievements() {
        for a in Achievement.all where progress.achievements[a.id] == nil {
            if a.check(self) {
                progress.achievements[a.id] = Date()
                toasts.append(a)
                SoundKit.shared.play(.unlock)
            }
        }
    }

    func dismissToast() {
        if !toasts.isEmpty { toasts.removeFirst() }
    }

    // MARK: Settings

    func setSound(_ on: Bool) {
        progress.soundOn = on
        SoundKit.shared.enabled = on
        if on { SoundKit.shared.play(.tap) }
        save()
    }

    func setHaptics(_ on: Bool) {
        progress.hapticsOn = on
        Haptics.enabled = on
        if on { Haptics.place() }
        save()
    }

    func replayTutorial() {
        progress.tutorialDone = false
        save()
    }

    func resetProgress() {
        let sound = progress.soundOn, haptics = progress.hapticsOn
        progress = Progress()
        progress.soundOn = sound
        progress.hapticsOn = haptics
        selectedChapter = 0
        save()
    }

    func save() { progress.save() }
}
