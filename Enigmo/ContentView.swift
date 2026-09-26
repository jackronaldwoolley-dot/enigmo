import SwiftUI
import SpriteKit

// MARK: - Theme

enum Theme {
    static let bg = Color(red: 0.05, green: 0.07, blue: 0.12)
    static let panel = Color(red: 0.09, green: 0.11, blue: 0.18)
    static let gold = Color(red: 1, green: 0.85, blue: 0.4)
    static let accent = Color(red: 0.35, green: 0.55, blue: 1)
    static let title = LinearGradient(colors: [Color(red: 0.55, green: 0.85, blue: 1), Color(red: 0.35, green: 0.45, blue: 1)],
                                      startPoint: .top, endPoint: .bottom)
    static func font(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

struct ContentView: View {
    @StateObject private var model = GameModel()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let scene = model.scene {
                    SceneHost(scene: scene, isPaused: model.state == .menu)
                        .ignoresSafeArea()
                } else {
                    Theme.bg.ignoresSafeArea()
                }

                switch model.state {
                case .menu:
                    MenuView(model: model)
                        .transition(.opacity)
                case .playing:
                    HUDView(model: model)
                case .won:
                    HUDView(model: model)
                    WinView(model: model)
                        .transition(.opacity)
                }

                ToastHost(model: model)
            }
            .animation(.easeInOut(duration: 0.25), value: model.state == .menu)
            .onAppear {
                let full = CGSize(width: geo.size.width + geo.safeAreaInsets.leading + geo.safeAreaInsets.trailing,
                                  height: geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom)
                model.prepareScene(size: full)
            }
        }
    }
}

/// Hosts the SKScene in an SKView and presents it exactly once.
struct SceneHost: UIViewRepresentable {
    let scene: GameScene
    let isPaused: Bool

    func makeUIView(context: Context) -> GameView {
        let view = GameView()
        view.ignoresSiblingOrder = true
        view.preferredFramesPerSecond = 60
        view.presentScene(scene)
        return view
    }

    func updateUIView(_ view: GameView, context: Context) {
        if view.scene !== scene { view.presentScene(scene) }
        view.isPaused = isPaused
    }
}

/// SKView that forwards its real safe-area insets to the scene.
final class GameView: SKView {
    override func layoutSubviews() {
        super.layoutSubviews()
        (scene as? GameScene)?.applyInsets(top: safeAreaInsets.top, bottom: safeAreaInsets.bottom)
    }
    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        (scene as? GameScene)?.applyInsets(top: safeAreaInsets.top, bottom: safeAreaInsets.bottom)
    }
}

// MARK: - Shared bits

struct StarRow: View {
    let stars: Int
    var size: CGFloat = 12
    var animated = false
    @State private var shown = 0

    var body: some View {
        HStack(spacing: size * 0.25) {
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: "star.fill")
                    .font(.system(size: size, weight: .bold))
                    .foregroundStyle(i < (animated ? shown : stars) ? Theme.gold : Color.white.opacity(0.18))
                    .scaleEffect(animated && i < shown ? 1 : (animated ? 0.6 : 1))
                    .animation(.spring(response: 0.35, dampingFraction: 0.5), value: shown)
            }
        }
        .task(id: stars) {
            guard animated else { return }
            shown = 0
            for i in 0..<stars {
                try? await Task.sleep(nanoseconds: 350_000_000)
                shown = i + 1
            }
        }
    }
}

struct RoundButton: View {
    let symbol: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .bold))
                .frame(width: 36, height: 36)
                .background(Color.white.opacity(0.10), in: Circle())
        }
        .foregroundStyle(.white)
    }
}

struct PillButton: View {
    let title: String
    var primary = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.font(15))
                .frame(maxWidth: .infinity).padding(.vertical, 13)
                .background(primary ? Theme.accent : Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 13))
        }
        .foregroundStyle(.white)
    }
}

// MARK: - HUD

struct HUDView: View {
    @ObservedObject var model: GameModel
    @State private var showHint = false

    private var timeColor: Color {
        if model.elapsed <= model.level.par { return .white }
        if model.elapsed <= model.level.par * 1.6 { return Theme.gold }
        return Color(red: 1, green: 0.45, blue: 0.4)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                RoundButton(symbol: "chevron.left") { model.toMenu() }
                VStack(alignment: .leading, spacing: 1) {
                    Text("LEVEL \(model.levelIndex + 1)")
                        .font(Theme.font(10, .heavy)).foregroundStyle(.white.opacity(0.55))
                    Text(model.level.name)
                        .font(Theme.font(15)).lineLimit(1).minimumScaleFactor(0.7)
                }
                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 1) {
                    Text("TIME · PAR \(model.level.par.clock)")
                        .font(Theme.font(9, .heavy)).foregroundStyle(.white.opacity(0.55))
                    Text(model.elapsed.clock)
                        .font(Theme.font(15).monospacedDigit()).foregroundStyle(timeColor)
                }
                VStack(alignment: .trailing, spacing: 1) {
                    Text("DROPS")
                        .font(Theme.font(10, .heavy)).foregroundStyle(.white.opacity(0.55))
                    Text("\(model.collected)/\(model.goal)")
                        .font(Theme.font(15).monospacedDigit())
                }
                RoundButton(symbol: "arrow.counterclockwise") { model.reset() }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .frame(height: 62)

            if model.tutorialStep < 3 {
                TutorialCard(step: model.tutorialStep)
                    .padding(.horizontal, 16).padding(.top, 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else if showHint {
                Text(model.level.hint)
                    .font(Theme.font(13, .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Color.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 24).padding(.top, 10)
                    .transition(.opacity)
            }
            Spacer()
        }
        .task(id: model.levelIndex) {
            guard model.tutorialStep >= 3 else { return }
            withAnimation(.easeIn(duration: 0.3)) { showHint = true }
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            withAnimation(.easeOut(duration: 0.6)) { showHint = false }
        }
    }
}

struct TutorialCard: View {
    let step: Int
    private var text: (String, String) {
        switch step {
        case 0: return ("hand.draw.fill", "Drag a Slider out of the tray and drop it under the stream.")
        case 1: return ("rotate.right.fill", "Tap the Slider, then drag its knob to tilt it toward the bucket.")
        default: return ("drop.fill", "That's it. Fill the bucket to finish the level.")
        }
    }
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: text.0)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.gold)
                .frame(width: 30)
            Text(text.1)
                .font(Theme.font(14, .semibold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Text("\(step + 1)/3")
                .font(Theme.font(11, .heavy)).foregroundStyle(.white.opacity(0.4))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.panel.opacity(0.96))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.gold.opacity(0.5), lineWidth: 1))
        )
        .id(step)
    }
}

// MARK: - Menu

struct MenuView: View {
    @ObservedObject var model: GameModel
    @State private var showAchievements = false
    @State private var showSettings = false

    private var chapter: Chapter { Level.chapters[model.selectedChapter] }
    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.07, green: 0.09, blue: 0.16), Color(red: 0.03, green: 0.04, blue: 0.08)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                header
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        chapterPicker
                        chapterPanel
                        legend
                    }
                    .padding(.bottom, 110)
                }
            }
            VStack {
                Spacer()
                continueButton
            }
        }
        .sheet(isPresented: $showAchievements) { AchievementsView(model: model) }
        .sheet(isPresented: $showSettings) { SettingsView(model: model) }
    }

    private var header: some View {
        VStack(spacing: 6) {
            HStack {
                RoundButton(symbol: "trophy.fill") { showAchievements = true; Haptics.tap() }
                Spacer()
                HStack(spacing: 5) {
                    Image(systemName: "star.fill").foregroundStyle(Theme.gold)
                    Text("\(model.totalStars) / \(model.maxStars)")
                        .font(Theme.font(14).monospacedDigit()).foregroundStyle(.white)
                }
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Color.white.opacity(0.08), in: Capsule())
                Spacer()
                RoundButton(symbol: "gearshape.fill") { showSettings = true; Haptics.tap() }
            }
            .padding(.horizontal, 16)
            Text("ENIGMO")
                .font(.system(size: 52, weight: .black, design: .rounded))
                .foregroundStyle(Theme.title)
                .shadow(color: Color(red: 0.3, green: 0.6, blue: 1).opacity(0.5), radius: 18)
                .padding(.top, 2)
        }
        .padding(.top, 6)
        .padding(.bottom, 8)
    }

    private var chapterPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Level.chapters) { ch in
                    let unlocked = model.isUnlocked(chapter: ch)
                    let selected = ch.id == model.selectedChapter
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { model.selectedChapter = ch.id }
                        Haptics.tap()
                    } label: {
                        HStack(spacing: 6) {
                            if !unlocked { Image(systemName: "lock.fill").font(.system(size: 10, weight: .bold)) }
                            Text(ch.name).font(Theme.font(13))
                        }
                        .foregroundStyle(selected ? .black : .white.opacity(unlocked ? 0.85 : 0.45))
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(selected ? Theme.gold : Color.white.opacity(0.08), in: Capsule())
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private var chapterPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("CHAPTER \(chapter.id + 1)")
                    .font(Theme.font(10, .heavy)).foregroundStyle(.white.opacity(0.5))
                Text(chapter.name).font(Theme.font(22, .black)).foregroundStyle(.white)
                Text(chapter.tagline).font(Theme.font(13, .medium)).foregroundStyle(.white.opacity(0.6))
            }
            .padding(.horizontal, 18)

            if model.isUnlocked(chapter: chapter) {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(Array(chapter.levelRange), id: \.self) { i in
                        LevelTile(index: i, level: Level.all[i], stars: model.stars(for: i),
                                  unlocked: model.isUnlocked(level: i), completed: model.progress.completed(i)) {
                            Haptics.tap()
                            model.play(level: i)
                        }
                    }
                }
                .padding(.horizontal, 16)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "lock.fill").font(.system(size: 28)).foregroundStyle(Theme.gold)
                    Text("Earn \(chapter.starsRequired) stars to unlock")
                        .font(Theme.font(16)).foregroundStyle(.white)
                    Text("You have \(model.totalStars). Replay earlier levels under par to pick up more.")
                        .font(Theme.font(13, .medium)).foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                    ProgressView(value: Double(min(model.totalStars, chapter.starsRequired)), total: Double(chapter.starsRequired))
                        .tint(Theme.gold)
                        .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.05)))
                .padding(.horizontal, 16)
            }
        }
    }

    private var legend: some View {
        VStack(spacing: 10) {
            HStack(spacing: 22) {
                LegendDot(color: DropKind.water.color, name: "Water")
                LegendDot(color: DropKind.oil.color, name: "Oil")
                LegendDot(color: DropKind.lava.color, name: "Lava")
            }
            Text("Each bucket takes one liquid. A wrong droplet costs you one you've already caught.")
                .font(Theme.font(12, .medium))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.top, 6)
    }

    private var continueButton: some View {
        let i = model.firstOpenLevel
        let allDone = model.progress.stats.levelsCompleted >= Level.all.count
        return Button {
            Haptics.tap()
            model.play(level: i)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(allDone ? "REPLAY" : (model.progress.stats.levelsCompleted == 0 ? "START" : "CONTINUE"))
                        .font(Theme.font(10, .heavy)).foregroundStyle(.black.opacity(0.6))
                    Text("Level \(i + 1) · \(Level.all[i].name)")
                        .font(Theme.font(16)).foregroundStyle(.black)
                }
                Spacer()
                Image(systemName: "play.fill").foregroundStyle(.black)
            }
            .padding(.horizontal, 18).padding(.vertical, 14)
            .background(Theme.gold, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: Theme.gold.opacity(0.35), radius: 16, y: 6)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }
}

struct LevelTile: View {
    let index: Int
    let level: Level
    let stars: Int
    let unlocked: Bool
    let completed: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                if unlocked {
                    Text("\(index + 1)").font(Theme.font(24, .black))
                } else {
                    Image(systemName: "lock.fill").font(.system(size: 20, weight: .bold)).frame(height: 29)
                }
                Text(level.name)
                    .font(Theme.font(11, .semibold)).lineLimit(1).minimumScaleFactor(0.7)
                StarRow(stars: stars, size: 10)
            }
            .foregroundStyle(.white.opacity(unlocked ? 1 : 0.35))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(unlocked ? (completed ? 0.10 : 0.14) : 0.04))
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .stroke(unlocked && !completed ? Theme.gold.opacity(0.7) : Color.white.opacity(0.12), lineWidth: 1))
            )
        }
        .disabled(!unlocked)
    }
}

struct LegendDot: View {
    let color: UIColor
    let name: String
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(Color(color)).frame(width: 10, height: 10)
                .shadow(color: Color(color).opacity(0.8), radius: 4)
            Text(name).font(Theme.font(12, .semibold)).foregroundStyle(.white.opacity(0.7))
        }
    }
}

// MARK: - Win

struct WinView: View {
    @ObservedObject var model: GameModel

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            if let r = model.lastResult {
                VStack(spacing: 14) {
                    Text(r.isFirstClear ? "LEVEL COMPLETE" : "COMPLETE AGAIN")
                        .font(Theme.font(12, .heavy)).foregroundStyle(.white.opacity(0.55))
                    Text(r.headline)
                        .font(Theme.font(28, .black))
                        .foregroundStyle(Theme.title)
                        .multilineTextAlignment(.center)
                    StarRow(stars: r.stars, size: 34, animated: true)
                        .padding(.vertical, 4)
                    Text(r.message)
                        .font(Theme.font(14, .medium))
                        .foregroundStyle(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 0) {
                        stat("TIME", r.elapsed.clock, sub: "par \(r.par.clock)")
                        stat("PARTS", "\(r.partsUsed)", sub: "of \(r.partsAvailable)")
                        stat("BONUS", r.bonus.formatted(), sub: r.isNewBest ? "new best" : " ")
                    }
                    .padding(.vertical, 6)

                    HStack(spacing: 12) {
                        PillButton(title: "Menu") { model.toMenu() }
                        PillButton(title: "Retry") { model.reset() }
                        PillButton(title: model.nextUnlockedLevel == nil ? "Done" : "Next", primary: true) { model.nextLevel() }
                    }
                }
                .padding(24)
                .frame(maxWidth: 360)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Theme.panel)
                        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.15)))
                )
                .padding(20)
            }
        }
    }

    private func stat(_ label: String, _ value: String, sub: String) -> some View {
        VStack(spacing: 2) {
            Text(label).font(Theme.font(10, .heavy)).foregroundStyle(.white.opacity(0.5))
            Text(value).font(Theme.font(20, .black).monospacedDigit()).foregroundStyle(sub == "new best" ? Theme.gold : .white)
            Text(sub).font(Theme.font(10, .semibold)).foregroundStyle(sub == "new best" ? Theme.gold : .white.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Achievements

struct AchievementsView: View {
    @ObservedObject var model: GameModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 0) {
                        statTile("Drops caught", model.progress.stats.drops.formatted())
                        statTile("Levels done", "\(model.progress.stats.levelsCompleted)/\(Level.all.count)")
                        statTile("Play time", (model.progress.stats.playSeconds).clock)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
                Section("\(model.unlockedAchievements) of \(Achievement.all.count) unlocked") {
                    ForEach(Achievement.all) { a in
                        let date = model.progress.achievements[a.id]
                        HStack(spacing: 14) {
                            Image(systemName: a.symbol)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(date == nil ? Color.white.opacity(0.3) : Theme.gold)
                                .frame(width: 40, height: 40)
                                .background(Color.white.opacity(date == nil ? 0.05 : 0.12), in: RoundedRectangle(cornerRadius: 10))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(a.title).font(Theme.font(15)).foregroundStyle(.white.opacity(date == nil ? 0.6 : 1))
                                Text(a.detail).font(Theme.font(12, .medium)).foregroundStyle(.white.opacity(0.5))
                                if let date {
                                    Text(date.formatted(date: .abbreviated, time: .omitted))
                                        .font(Theme.font(10, .semibold)).foregroundStyle(Theme.gold.opacity(0.8))
                                }
                            }
                            Spacer()
                            if date != nil { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.gold) }
                        }
                        .listRowBackground(Theme.panel)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .navigationTitle("Achievements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .preferredColorScheme(.dark)
    }

    private func statTile(_ label: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(Theme.font(20, .black).monospacedDigit()).foregroundStyle(.white)
            Text(label).font(Theme.font(10, .semibold)).foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

// MARK: - Settings

struct SettingsView: View {
    @ObservedObject var model: GameModel
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            List {
                Section("Feel") {
                    Toggle("Sound effects", isOn: Binding(get: { model.progress.soundOn }, set: { model.setSound($0) }))
                    Toggle("Haptics", isOn: Binding(get: { model.progress.hapticsOn }, set: { model.setHaptics($0) }))
                }
                .listRowBackground(Theme.panel)

                Section("Parts") {
                    ForEach(ToolKind.allCases) { k in
                        HStack(spacing: 12) {
                            Circle().fill(Color(k.color)).frame(width: 12, height: 12)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(k.title == "Accel" ? "Accelerator" : (k == .gravity ? "Gravity Well" : k.title)).font(Theme.font(14))
                                Text(k.blurb).font(Theme.font(12, .medium)).foregroundStyle(.white.opacity(0.55))
                            }
                        }
                    }
                }
                .listRowBackground(Theme.panel)

                Section("Progress") {
                    Button("Replay the tutorial") { model.replayTutorial(); dismiss() }
                    Button("Reset all progress", role: .destructive) { confirmReset = true }
                }
                .listRowBackground(Theme.panel)

                Section {
                    Text("Enigmo tribute · built in one shot.\nDroplets, parts, and buckets, just like you remember.")
                        .font(Theme.font(12, .medium)).foregroundStyle(.white.opacity(0.45))
                }
                .listRowBackground(Color.clear)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .tint(Theme.gold)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .confirmationDialog("Reset all progress?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Reset everything", role: .destructive) { model.resetProgress(); dismiss() }
                Button("Keep my progress", role: .cancel) {}
            } message: {
                Text("Stars, best times, and achievements will be cleared. This can't be undone.")
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Toasts

struct ToastHost: View {
    @ObservedObject var model: GameModel

    var body: some View {
        VStack {
            if let a = model.toasts.first {
                HStack(spacing: 12) {
                    Image(systemName: a.symbol)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Theme.gold)
                        .frame(width: 38, height: 38)
                        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("ACHIEVEMENT UNLOCKED").font(Theme.font(9, .heavy)).foregroundStyle(Theme.gold)
                        Text(a.title).font(Theme.font(15)).foregroundStyle(.white)
                        Text(a.detail).font(Theme.font(11, .medium)).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Theme.panel)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.gold.opacity(0.6), lineWidth: 1))
                        .shadow(color: .black.opacity(0.5), radius: 16, y: 6)
                )
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .transition(.move(edge: .top).combined(with: .opacity))
                .id(a.id)
                .task(id: a.id) {
                    try? await Task.sleep(nanoseconds: 3_200_000_000)
                    withAnimation(.easeInOut(duration: 0.3)) { model.dismissToast() }
                }
                .onTapGesture { withAnimation { model.dismissToast() } }
            }
            Spacer()
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: model.toasts.first?.id)
    }
}
