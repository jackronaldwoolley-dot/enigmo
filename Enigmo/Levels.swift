import CoreGraphics

enum DropKind: String, CaseIterable, Codable {
    case water, oil, lava
    var title: String { rawValue.capitalized }
}

enum ToolKind: String, CaseIterable, Identifiable, Codable {
    case bumper, slider, sponge, accelerator, gravity
    var id: String { rawValue }
    var title: String {
        switch self {
        case .bumper: return "Bumper"
        case .slider: return "Slider"
        case .sponge: return "Sponge"
        case .accelerator: return "Accel"
        case .gravity: return "Gravity"
        }
    }
    var blurb: String {
        switch self {
        case .bumper: return "Bouncy. Droplets rebound at full speed."
        case .slider: return "Slick. Droplets glide along it."
        case .sponge: return "Soaks up any droplet that touches it."
        case .accelerator: return "Fires droplets along its arrow."
        case .gravity: return "Pulls nearby droplets toward it."
        }
    }
}

/// All level coordinates are fractions (0...1) of the playfield, origin bottom-left.
struct DropperSpec {
    var x: CGFloat
    var y: CGFloat
    /// Emission angle in degrees. 0 = right, 90 = up, -90 = down.
    var angle: CGFloat
    var speed: CGFloat
    var kind: DropKind
}

struct ContainerSpec {
    /// Bottom-center of the container.
    var x: CGFloat
    var y: CGFloat
    var kind: DropKind
}

struct WallSpec {
    var x: CGFloat
    var y: CGFloat
    var w: CGFloat
    var h: CGFloat
}

struct Level {
    var name: String
    var hint: String
    var droppers: [DropperSpec]
    var containers: [ContainerSpec]
    var walls: [WallSpec]
    var tools: [ToolKind: Int]
    /// Droplets each container needs.
    var target: Int
    /// Seconds. Finish within par for three stars.
    var par: Double

    var totalDrops: Int { target * containers.count }
    var partsAvailable: Int { tools.values.reduce(0, +) }
    var liquidCount: Int { Set(droppers.map(\.kind)).count }
}

struct Chapter: Identifiable {
    let id: Int
    let name: String
    let tagline: String
    let starsRequired: Int
    let levelRange: Range<Int>
}

extension Level {
    static let chapters: [Chapter] = [
        Chapter(id: 0, name: "First Drops", tagline: "Learn the parts. Fill the buckets.", starsRequired: 0, levelRange: 0..<6),
        Chapter(id: 1, name: "Mixing It Up", tagline: "Two liquids, tighter spaces, new tricks.", starsRequired: 8, levelRange: 6..<12),
        Chapter(id: 2, name: "Under Pressure", tagline: "Funnels, roofs, and three streams at once.", starsRequired: 20, levelRange: 12..<18),
        Chapter(id: 3, name: "Master Plumber", tagline: "Everything you know, all at once.", starsRequired: 36, levelRange: 18..<24)
    ]

    static func chapter(for levelIndex: Int) -> Chapter {
        chapters.first { $0.levelRange.contains(levelIndex) } ?? chapters[0]
    }

    static let all: [Level] = [
        // MARK: Chapter 1 - First Drops
        Level(name: "First Drop", hint: "Drag a Slider under the stream, then tilt it toward the bucket.",
              droppers: [DropperSpec(x: 0.22, y: 0.93, angle: -90, speed: 40, kind: .water)],
              containers: [ContainerSpec(x: 0.78, y: 0.04, kind: .water)],
              walls: [],
              tools: [.slider: 2, .bumper: 1], target: 40, par: 30),

        Level(name: "Over the Wall", hint: "Bumpers bounce droplets back at full speed. A tiny tilt goes a long way.",
              droppers: [DropperSpec(x: 0.16, y: 0.93, angle: -90, speed: 40, kind: .water)],
              containers: [ContainerSpec(x: 0.80, y: 0.04, kind: .water)],
              walls: [WallSpec(x: 0.48, y: 0.0, w: 0.04, h: 0.52)],
              tools: [.bumper: 2, .slider: 1], target: 40, par: 35),

        Level(name: "Up and Over", hint: "The bucket sits on a ledge. Bounce the stream up to it.",
              droppers: [DropperSpec(x: 0.40, y: 0.95, angle: -90, speed: 40, kind: .water)],
              containers: [ContainerSpec(x: 0.85, y: 0.50, kind: .water)],
              walls: [WallSpec(x: 0.70, y: 0.44, w: 0.30, h: 0.06)],
              tools: [.bumper: 2, .slider: 2], target: 40, par: 45),

        Level(name: "Staircase", hint: "Droplets that stop moving evaporate. Keep the stream flowing.",
              droppers: [DropperSpec(x: 0.10, y: 0.93, angle: -90, speed: 40, kind: .water)],
              containers: [ContainerSpec(x: 0.86, y: 0.04, kind: .water)],
              walls: [WallSpec(x: 0.0, y: 0.62, w: 0.28, h: 0.03), WallSpec(x: 0.36, y: 0.40, w: 0.28, h: 0.03)],
              tools: [.slider: 3, .bumper: 1], target: 40, par: 45),

        Level(name: "Sponge Bath", hint: "Wrong liquids poison a bucket. Sponge the oil before it gets there.",
              droppers: [DropperSpec(x: 0.32, y: 0.93, angle: -90, speed: 40, kind: .water),
                         DropperSpec(x: 0.52, y: 0.93, angle: -90, speed: 40, kind: .oil)],
              containers: [ContainerSpec(x: 0.50, y: 0.04, kind: .water)],
              walls: [WallSpec(x: 0.0, y: 0.0, w: 0.22, h: 0.30)],
              tools: [.sponge: 2, .slider: 2, .bumper: 1], target: 40, par: 50),

        Level(name: "Lava Lamp", hint: "Accelerators fling droplets in the direction of the arrow.",
              droppers: [DropperSpec(x: 0.08, y: 0.55, angle: 0, speed: 180, kind: .lava)],
              containers: [ContainerSpec(x: 0.88, y: 0.04, kind: .lava)],
              walls: [WallSpec(x: 0.60, y: 0.30, w: 0.40, h: 0.05), WallSpec(x: 0.30, y: 0.0, w: 0.05, h: 0.22)],
              tools: [.slider: 2, .accelerator: 1, .bumper: 1], target: 40, par: 50),

        // MARK: Chapter 2 - Mixing It Up
        Level(name: "Oil and Water", hint: "Cross the streams. Each bucket takes only its own liquid.",
              droppers: [DropperSpec(x: 0.15, y: 0.93, angle: -90, speed: 40, kind: .water),
                         DropperSpec(x: 0.85, y: 0.93, angle: -90, speed: 40, kind: .oil)],
              containers: [ContainerSpec(x: 0.70, y: 0.04, kind: .water), ContainerSpec(x: 0.30, y: 0.04, kind: .oil)],
              walls: [WallSpec(x: 0.48, y: 0.0, w: 0.04, h: 0.40)],
              tools: [.bumper: 2, .slider: 3, .sponge: 1], target: 25, par: 70),

        Level(name: "Crossfire", hint: "Two jets, two buckets. Sliders can catch a fast stream.",
              droppers: [DropperSpec(x: 0.06, y: 0.62, angle: 0, speed: 230, kind: .water),
                         DropperSpec(x: 0.94, y: 0.62, angle: 180, speed: 230, kind: .lava)],
              containers: [ContainerSpec(x: 0.84, y: 0.04, kind: .water), ContainerSpec(x: 0.16, y: 0.04, kind: .lava)],
              walls: [WallSpec(x: 0.47, y: 0.0, w: 0.06, h: 0.32)],
              tools: [.bumper: 3, .slider: 2, .sponge: 1, .accelerator: 1], target: 30, par: 70),

        Level(name: "Fountain", hint: "This one shoots up. Catch it on the way down.",
              droppers: [DropperSpec(x: 0.50, y: 0.06, angle: 90, speed: 470, kind: .oil)],
              containers: [ContainerSpec(x: 0.15, y: 0.58, kind: .oil)],
              walls: [WallSpec(x: 0.0, y: 0.52, w: 0.30, h: 0.06)],
              tools: [.bumper: 2, .slider: 2, .accelerator: 1, .sponge: 1], target: 40, par: 60),

        Level(name: "Pull of Gravity", hint: "A Gravity Well bends the stream toward it. Place it beside the flow, not in it.",
              droppers: [DropperSpec(x: 0.28, y: 0.93, angle: -90, speed: 40, kind: .water)],
              containers: [ContainerSpec(x: 0.80, y: 0.04, kind: .water)],
              walls: [WallSpec(x: 0.40, y: 0.0, w: 0.04, h: 0.18)],
              tools: [.gravity: 1, .slider: 1], target: 40, par: 50),

        Level(name: "The Gauntlet", hint: "Thread the needle. Every gap is wider than it looks.",
              droppers: [DropperSpec(x: 0.50, y: 0.95, angle: -90, speed: 40, kind: .water)],
              containers: [ContainerSpec(x: 0.50, y: 0.04, kind: .water)],
              walls: [WallSpec(x: 0.30, y: 0.70, w: 0.40, h: 0.03), WallSpec(x: 0.00, y: 0.45, w: 0.36, h: 0.03),
                      WallSpec(x: 0.64, y: 0.45, w: 0.36, h: 0.03), WallSpec(x: 0.34, y: 0.22, w: 0.32, h: 0.03)],
              tools: [.bumper: 2, .slider: 3, .accelerator: 1], target: 40, par: 70),

        Level(name: "Split Decision", hint: "One stream, two buckets. Catch the edge of the stream to split it.",
              droppers: [DropperSpec(x: 0.50, y: 0.93, angle: -90, speed: 40, kind: .water)],
              containers: [ContainerSpec(x: 0.14, y: 0.04, kind: .water), ContainerSpec(x: 0.86, y: 0.04, kind: .water)],
              walls: [WallSpec(x: 0.48, y: 0.0, w: 0.04, h: 0.30)],
              tools: [.bumper: 2, .slider: 3], target: 20, par: 80),

        // MARK: Chapter 3 - Under Pressure
        Level(name: "Tight Squeeze", hint: "Funnel the stream through the gap, then steer it home.",
              droppers: [DropperSpec(x: 0.50, y: 0.95, angle: -90, speed: 40, kind: .water)],
              containers: [ContainerSpec(x: 0.20, y: 0.04, kind: .water)],
              walls: [WallSpec(x: 0.0, y: 0.55, w: 0.42, h: 0.03), WallSpec(x: 0.58, y: 0.55, w: 0.42, h: 0.03),
                      WallSpec(x: 0.34, y: 0.0, w: 0.04, h: 0.30)],
              tools: [.slider: 3, .bumper: 1], target: 40, par: 60),

        Level(name: "Triple Threat", hint: "Three streams, three buckets, all shuffled. Work one liquid at a time.",
              droppers: [DropperSpec(x: 0.20, y: 0.93, angle: -90, speed: 40, kind: .water),
                         DropperSpec(x: 0.50, y: 0.93, angle: -90, speed: 40, kind: .oil),
                         DropperSpec(x: 0.80, y: 0.93, angle: -90, speed: 40, kind: .lava)],
              containers: [ContainerSpec(x: 0.20, y: 0.04, kind: .lava), ContainerSpec(x: 0.50, y: 0.04, kind: .water),
                           ContainerSpec(x: 0.80, y: 0.04, kind: .oil)],
              walls: [],
              tools: [.slider: 4, .bumper: 3, .sponge: 1], target: 20, par: 110),

        Level(name: "Under the Roof", hint: "The bucket is covered. Come in low and from the side.",
              droppers: [DropperSpec(x: 0.20, y: 0.93, angle: -90, speed: 40, kind: .water)],
              containers: [ContainerSpec(x: 0.82, y: 0.04, kind: .water)],
              walls: [WallSpec(x: 0.62, y: 0.22, w: 0.38, h: 0.04)],
              tools: [.accelerator: 1, .slider: 2, .bumper: 1], target: 40, par: 70),

        Level(name: "Sideways", hint: "Only water belongs in this bucket. Clear the oil out of the lane.",
              droppers: [DropperSpec(x: 0.05, y: 0.85, angle: 0, speed: 260, kind: .water),
                         DropperSpec(x: 0.95, y: 0.70, angle: 180, speed: 260, kind: .oil)],
              containers: [ContainerSpec(x: 0.88, y: 0.04, kind: .water)],
              walls: [],
              tools: [.sponge: 2, .slider: 2, .bumper: 1], target: 40, par: 70),

        Level(name: "Pinball", hint: "Pegs everywhere. Use them, or bounce around them.",
              droppers: [DropperSpec(x: 0.50, y: 0.95, angle: -90, speed: 40, kind: .water)],
              containers: [ContainerSpec(x: 0.50, y: 0.04, kind: .water)],
              walls: [WallSpec(x: 0.47, y: 0.72, w: 0.06, h: 0.03), WallSpec(x: 0.62, y: 0.60, w: 0.06, h: 0.03),
                      WallSpec(x: 0.36, y: 0.50, w: 0.06, h: 0.03), WallSpec(x: 0.20, y: 0.38, w: 0.06, h: 0.03),
                      WallSpec(x: 0.66, y: 0.34, w: 0.06, h: 0.03), WallSpec(x: 0.44, y: 0.20, w: 0.12, h: 0.03)],
              tools: [.bumper: 3, .slider: 2], target: 40, par: 70),

        Level(name: "Orbit", hint: "The bucket sits in a pit. Let gravity pull the jet down into it.",
              droppers: [DropperSpec(x: 0.08, y: 0.62, angle: 0, speed: 210, kind: .lava)],
              containers: [ContainerSpec(x: 0.50, y: 0.04, kind: .lava)],
              walls: [WallSpec(x: 0.30, y: 0.0, w: 0.05, h: 0.45), WallSpec(x: 0.65, y: 0.0, w: 0.05, h: 0.45)],
              tools: [.gravity: 2, .slider: 1, .bumper: 1], target: 40, par: 80),

        // MARK: Chapter 4 - Master Plumber
        Level(name: "Long Way Round", hint: "Straight down is blocked. Go around and slip in from the side.",
              droppers: [DropperSpec(x: 0.90, y: 0.93, angle: -90, speed: 40, kind: .water)],
              containers: [ContainerSpec(x: 0.88, y: 0.04, kind: .water)],
              walls: [WallSpec(x: 0.60, y: 0.50, w: 0.40, h: 0.04), WallSpec(x: 0.72, y: 0.20, w: 0.28, h: 0.04)],
              tools: [.slider: 3, .bumper: 2, .accelerator: 1], target: 40, par: 90),

        Level(name: "Fire and Water", hint: "Lava from the side, water from above. Keep them apart.",
              droppers: [DropperSpec(x: 0.50, y: 0.93, angle: -90, speed: 40, kind: .water),
                         DropperSpec(x: 0.05, y: 0.50, angle: 0, speed: 200, kind: .lava)],
              containers: [ContainerSpec(x: 0.85, y: 0.04, kind: .water), ContainerSpec(x: 0.15, y: 0.04, kind: .lava)],
              walls: [WallSpec(x: 0.48, y: 0.0, w: 0.04, h: 0.35)],
              tools: [.bumper: 2, .slider: 3, .sponge: 1, .gravity: 1], target: 30, par: 100),

        Level(name: "High Rise", hint: "Shoot for the ledge. Trim the arc with a bumper.",
              droppers: [DropperSpec(x: 0.12, y: 0.06, angle: 80, speed: 560, kind: .oil)],
              containers: [ContainerSpec(x: 0.50, y: 0.55, kind: .oil)],
              walls: [WallSpec(x: 0.35, y: 0.49, w: 0.30, h: 0.06)],
              tools: [.bumper: 2, .slider: 2, .accelerator: 1], target: 40, par: 90),

        Level(name: "Four Corners", hint: "Both streams have to cross under the bar. Stack your sliders at different heights.",
              droppers: [DropperSpec(x: 0.08, y: 0.93, angle: -90, speed: 40, kind: .water),
                         DropperSpec(x: 0.92, y: 0.93, angle: -90, speed: 40, kind: .oil)],
              containers: [ContainerSpec(x: 0.92, y: 0.04, kind: .water), ContainerSpec(x: 0.08, y: 0.04, kind: .oil)],
              walls: [WallSpec(x: 0.48, y: 0.30, w: 0.04, h: 0.70), WallSpec(x: 0.20, y: 0.30, w: 0.60, h: 0.04)],
              tools: [.slider: 4, .bumper: 2, .sponge: 1, .accelerator: 1], target: 25, par: 120),

        Level(name: "Rain", hint: "Three streams, one bucket. The middle one is blocked.",
              droppers: [DropperSpec(x: 0.20, y: 0.93, angle: -90, speed: 40, kind: .water),
                         DropperSpec(x: 0.50, y: 0.93, angle: -90, speed: 40, kind: .water),
                         DropperSpec(x: 0.80, y: 0.93, angle: -90, speed: 40, kind: .water)],
              containers: [ContainerSpec(x: 0.50, y: 0.04, kind: .water)],
              walls: [WallSpec(x: 0.40, y: 0.24, w: 0.20, h: 0.03)],
              tools: [.slider: 4, .bumper: 2, .gravity: 1], target: 60, par: 90),

        Level(name: "Grand Finale", hint: "Everything at once. Breathe. One liquid at a time.",
              droppers: [DropperSpec(x: 0.10, y: 0.93, angle: -90, speed: 40, kind: .water),
                         DropperSpec(x: 0.90, y: 0.93, angle: -90, speed: 40, kind: .lava),
                         DropperSpec(x: 0.50, y: 0.06, angle: 90, speed: 500, kind: .oil)],
              containers: [ContainerSpec(x: 0.75, y: 0.04, kind: .water), ContainerSpec(x: 0.25, y: 0.04, kind: .lava),
                           ContainerSpec(x: 0.50, y: 0.45, kind: .oil)],
              walls: [WallSpec(x: 0.38, y: 0.39, w: 0.24, h: 0.06), WallSpec(x: 0.48, y: 0.0, w: 0.04, h: 0.25)],
              tools: [.slider: 4, .bumper: 3, .sponge: 1, .accelerator: 1, .gravity: 1], target: 25, par: 160)
    ]
}
