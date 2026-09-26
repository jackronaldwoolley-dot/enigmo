import Foundation

struct Achievement: Identifiable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let check: (GameModel) -> Bool
}

extension Achievement {
    @MainActor
    static let all: [Achievement] = [
        Achievement(id: "first_drop", title: "First Drop", detail: "Fill your first bucket.", symbol: "drop.fill") { m in
            m.progress.stats.levelsCompleted >= 1
        },
        Achievement(id: "chapter_1", title: "Getting Wet", detail: "Finish every level in First Drops.", symbol: "1.circle.fill") { m in
            m.chapterComplete(0)
        },
        Achievement(id: "chapter_2", title: "Mixed Up", detail: "Finish every level in Mixing It Up.", symbol: "2.circle.fill") { m in
            m.chapterComplete(1)
        },
        Achievement(id: "chapter_3", title: "Pressure Cooker", detail: "Finish every level in Under Pressure.", symbol: "3.circle.fill") { m in
            m.chapterComplete(2)
        },
        Achievement(id: "chapter_4", title: "Master Plumber", detail: "Finish every level in Master Plumber.", symbol: "wrench.and.screwdriver.fill") { m in
            m.chapterComplete(3)
        },
        Achievement(id: "quick_pour", title: "Quick Pour", detail: "Finish any level in under 20 seconds.", symbol: "hare.fill") { m in
            m.run.justWon && m.run.elapsed < 20
        },
        Achievement(id: "less_is_more", title: "Less Is More", detail: "Finish a level with at least two parts left in the tray.", symbol: "minus.circle.fill") { m in
            m.run.justWon && m.level.partsAvailable - m.run.partsUsed >= 2
        },
        Achievement(id: "clean_hands", title: "Clean Hands", detail: "Finish a two-liquid level without poisoning a bucket.", symbol: "hand.raised.fill") { m in
            m.run.justWon && m.level.liquidCount >= 2 && m.run.contaminations == 0
        },
        Achievement(id: "never_give_up", title: "Never Give Up", detail: "Finish a level after resetting it three times.", symbol: "arrow.counterclockwise.circle.fill") { m in
            m.run.justWon && m.run.resets >= 3
        },
        Achievement(id: "bent_space", title: "Bent Space", detail: "Finish a level using a Gravity Well.", symbol: "circle.dotted.circle") { m in
            m.run.justWon && m.run.kindsUsed.contains(.gravity)
        },
        Achievement(id: "sponge_worthy", title: "Sponge Worthy", detail: "Soak up 100 droplets.", symbol: "square.fill") { m in
            m.progress.stats.absorbed >= 100
        },
        Achievement(id: "thousand", title: "A Thousand Drops", detail: "Catch 1,000 droplets in total.", symbol: "drop.triangle.fill") { m in
            m.progress.stats.drops >= 1000
        },
        Achievement(id: "hot_hands", title: "Hot Hands", detail: "Catch 200 lava droplets.", symbol: "flame.fill") { m in
            (m.progress.stats.dropsByKind[DropKind.lava.rawValue] ?? 0) >= 200
        },
        Achievement(id: "rising_star", title: "Rising Star", detail: "Earn three stars on five levels.", symbol: "star.fill") { m in
            m.progress.threeStarCount >= 5
        },
        Achievement(id: "flawless", title: "Flawless", detail: "Earn three stars on every level.", symbol: "sparkles") { m in
            m.progress.threeStarCount >= Level.all.count
        },
        Achievement(id: "whole_flow", title: "The Whole Flow", detail: "Finish every level in the game.", symbol: "checkmark.seal.fill") { m in
            m.progress.stats.levelsCompleted >= Level.all.count
        }
    ]
}
