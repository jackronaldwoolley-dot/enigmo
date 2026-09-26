import Foundation

struct LevelRecord: Codable {
    var stars = 0
    var bestBonus = 0
    var bestTime: Double = 0
    var completions = 0
}

struct Stats: Codable {
    var drops = 0
    var dropsByKind: [String: Int] = [:]
    var absorbed = 0
    var contaminations = 0
    var partsPlaced = 0
    var resets = 0
    var levelsCompleted = 0
    var playSeconds: Double = 0
}

struct Progress: Codable {
    var records: [Int: LevelRecord] = [:]
    var achievements: [String: Date] = [:]
    var stats = Stats()
    var tutorialDone = false
    var soundOn = true
    var hapticsOn = true

    static let key = "enigmo.progress.v2"

    static func load() -> Progress {
        guard let data = UserDefaults.standard.data(forKey: key),
              let p = try? JSONDecoder().decode(Progress.self, from: data) else { return Progress() }
        return p
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Progress.key)
        }
    }

    var totalStars: Int { records.values.reduce(0) { $0 + $1.stars } }
    var threeStarCount: Int { records.values.filter { $0.stars == 3 }.count }
    func completed(_ level: Int) -> Bool { (records[level]?.completions ?? 0) > 0 }
}

/// What happened during the current attempt at a level.
struct RunStats {
    var partsPlaced = 0
    var partsUsed = 0
    var kindsUsed: Set<ToolKind> = []
    var contaminations = 0
    var resets = 0
    var elapsed: Double = 0
    var justWon = false
}

struct LevelOutcome {
    var stars: Int
    var bonus: Int
    var elapsed: Double
    var par: Double
    var partsUsed: Int
    var partsAvailable: Int
    var isNewBest: Bool
    var isFirstClear: Bool
    var headline: String
    var message: String
}

enum GameEvent {
    case placed(ToolKind)
    case removed(ToolKind)
    case rotated
    case caught(DropKind, fraction: Double)
    case absorbed
    case contaminated
    case tick(Double)
    case won(elapsed: Double, partsUsed: Int, kindsUsed: Set<ToolKind>)
}

extension Double {
    var clock: String {
        let t = max(0, Int(self.rounded(.down)))
        return String(format: "%d:%02d", t / 60, t % 60)
    }
}
