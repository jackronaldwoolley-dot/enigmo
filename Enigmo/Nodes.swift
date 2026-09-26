import SpriteKit

enum Bits {
    static let droplet: UInt32 = 1 << 0
    static let wall: UInt32 = 1 << 1
    static let tool: UInt32 = 1 << 2
    static let sponge: UInt32 = 1 << 3
    static let catcher: UInt32 = 1 << 4
}

extension DropKind {
    var color: SKColor {
        switch self {
        case .water: return SKColor(red: 0.30, green: 0.68, blue: 1.00, alpha: 1)
        case .oil: return SKColor(red: 0.78, green: 0.70, blue: 0.30, alpha: 1)
        case .lava: return SKColor(red: 1.00, green: 0.40, blue: 0.16, alpha: 1)
        }
    }
    var lightColor: SKColor {
        switch self {
        case .water: return SKColor(red: 0.70, green: 0.88, blue: 1.00, alpha: 1)
        case .oil: return SKColor(red: 0.95, green: 0.90, blue: 0.60, alpha: 1)
        case .lava: return SKColor(red: 1.00, green: 0.78, blue: 0.55, alpha: 1)
        }
    }
}

extension ToolKind {
    var color: SKColor {
        switch self {
        case .bumper: return SKColor(red: 0.47, green: 0.33, blue: 1.00, alpha: 1)
        case .slider: return SKColor(red: 0.62, green: 0.85, blue: 0.88, alpha: 1)
        case .sponge: return SKColor(red: 0.96, green: 0.78, blue: 0.26, alpha: 1)
        case .accelerator: return SKColor(red: 1.00, green: 0.55, blue: 0.20, alpha: 1)
        case .gravity: return SKColor(red: 0.85, green: 0.45, blue: 1.00, alpha: 1)
        }
    }
    var size: CGSize {
        switch self {
        case .bumper: return CGSize(width: 78, height: 12)
        case .slider: return CGSize(width: 92, height: 8)
        case .sponge: return CGSize(width: 66, height: 16)
        case .accelerator: return CGSize(width: 44, height: 44)
        case .gravity: return CGSize(width: 40, height: 40)
        }
    }
}

// MARK: - Droplet

final class DropletNode: SKSpriteNode {
    var kind: DropKind = .water
    var born: TimeInterval = 0
    var idle: TimeInterval = 0
}

// MARK: - Tool

final class ToolNode: SKNode {
    let kind: ToolKind
    private let body: SKNode
    private let knob = SKNode()
    private let ring: SKShapeNode
    private let highlight: SKShapeNode

    /// Local +Y rotated into parent space (the "up"/arrow direction of the tool).
    var direction: CGVector { CGVector(dx: -sin(zRotation), dy: cos(zRotation)) }

    var isSelected: Bool = false {
        didSet {
            knob.isHidden = !isSelected
            highlight.isHidden = !isSelected
        }
    }

    init(kind: ToolKind) {
        self.kind = kind
        self.body = ToolNode.makeShape(kind: kind)
        let s = kind.size
        highlight = SKShapeNode(rectOf: CGSize(width: s.width + 14, height: s.height + 14), cornerRadius: 10)
        highlight.strokeColor = SKColor(white: 1, alpha: 0.55)
        highlight.lineWidth = 1
        highlight.fillColor = .clear
        highlight.isHidden = true
        ring = SKShapeNode(circleOfRadius: 9)
        super.init()
        zPosition = 10
        addChild(highlight)
        addChild(body)

        let stem = SKShapeNode(rect: CGRect(x: -0.75, y: s.height / 2, width: 1.5, height: 20))
        stem.fillColor = SKColor(white: 1, alpha: 0.7)
        stem.strokeColor = .clear
        ring.position = CGPoint(x: 0, y: s.height / 2 + 28)
        ring.strokeColor = .white
        ring.lineWidth = 2
        ring.fillColor = SKColor(white: 1, alpha: 0.2)
        knob.addChild(stem)
        knob.addChild(ring)
        knob.isHidden = true
        addChild(knob)

        switch kind {
        case .bumper:
            let b = SKPhysicsBody(rectangleOf: s)
            b.isDynamic = false
            b.restitution = 1.0
            b.friction = 0
            b.categoryBitMask = Bits.tool
            b.collisionBitMask = Bits.droplet
            physicsBody = b
        case .slider:
            let b = SKPhysicsBody(rectangleOf: s)
            b.isDynamic = false
            b.restitution = 0
            b.friction = 0
            b.categoryBitMask = Bits.tool
            b.collisionBitMask = Bits.droplet
            physicsBody = b
        case .sponge:
            let b = SKPhysicsBody(rectangleOf: s)
            b.isDynamic = false
            b.categoryBitMask = Bits.sponge
            b.collisionBitMask = 0
            b.contactTestBitMask = Bits.droplet
            physicsBody = b
        case .accelerator, .gravity:
            break // handled in the scene's update loop
        }
        if kind == .gravity { startPulsing() }
    }

    private func startPulsing() {
        guard let ring = body.childNode(withName: "pulse") else { return }
        ring.run(.repeatForever(.sequence([
            .group([.scale(to: 2.6, duration: 1.4), .fadeOut(withDuration: 1.4)]),
            .run { ring.setScale(0.4); ring.alpha = 0.7 }
        ])))
    }

    required init?(coder: NSCoder) { fatalError() }

    func knobContains(_ p: CGPoint) -> Bool {
        guard isSelected, let parent else { return false }
        let kp = convert(ring.position, to: parent)
        return hypot(p.x - kp.x, p.y - kp.y) < 24
    }

    func hitTest(_ p: CGPoint) -> Bool {
        guard let parent else { return false }
        let local = convert(p, from: parent)
        let s = kind.size
        return abs(local.x) <= s.width / 2 + 14 && abs(local.y) <= s.height / 2 + 14
    }

    static func icon(kind: ToolKind) -> SKNode {
        let n = makeShape(kind: kind)
        n.setScale(kind == .accelerator || kind == .gravity ? 0.75 : 0.7)
        return n
    }

    static func makeShape(kind: ToolKind) -> SKNode {
        let s = kind.size
        let root = SKNode()
        switch kind {
        case .bumper:
            let r = SKShapeNode(rectOf: s, cornerRadius: 6)
            r.fillColor = kind.color
            r.strokeColor = SKColor(red: 0.78, green: 0.72, blue: 1, alpha: 1)
            r.lineWidth = 1.5
            root.addChild(r)
            let hl = SKShapeNode(rect: CGRect(x: -s.width / 2 + 8, y: 1.5, width: s.width - 16, height: 2.5), cornerRadius: 1)
            hl.fillColor = SKColor(white: 1, alpha: 0.45)
            hl.strokeColor = .clear
            root.addChild(hl)
        case .slider:
            let r = SKShapeNode(rectOf: s, cornerRadius: 4)
            r.fillColor = kind.color
            r.strokeColor = SKColor(red: 0.90, green: 0.98, blue: 1, alpha: 1)
            r.lineWidth = 1.2
            root.addChild(r)
            let shadow = SKShapeNode(rect: CGRect(x: -s.width / 2 + 6, y: -s.height / 2 - 2, width: s.width - 12, height: 2), cornerRadius: 1)
            shadow.fillColor = SKColor(red: 0.30, green: 0.55, blue: 0.60, alpha: 1)
            shadow.strokeColor = .clear
            root.addChild(shadow)
        case .sponge:
            let r = SKShapeNode(rectOf: s, cornerRadius: 5)
            r.fillColor = kind.color
            r.strokeColor = SKColor(red: 1, green: 0.90, blue: 0.55, alpha: 1)
            r.lineWidth = 1.2
            root.addChild(r)
            for i in 0..<6 {
                let d = SKShapeNode(circleOfRadius: 1.8)
                d.fillColor = SKColor(red: 0.70, green: 0.52, blue: 0.10, alpha: 0.8)
                d.strokeColor = .clear
                d.position = CGPoint(x: -s.width / 2 + 9 + CGFloat(i) * (s.width - 18) / 5, y: i % 2 == 0 ? 3 : -3)
                root.addChild(d)
            }
        case .accelerator:
            let c = SKShapeNode(circleOfRadius: s.width / 2)
            c.fillColor = kind.color.withAlphaComponent(0.22)
            c.strokeColor = kind.color
            c.lineWidth = 2
            root.addChild(c)
            let inner = SKShapeNode(circleOfRadius: s.width / 2 - 6)
            inner.strokeColor = kind.color.withAlphaComponent(0.5)
            inner.lineWidth = 1
            inner.fillColor = .clear
            root.addChild(inner)
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 0, y: 14))
            p.addLine(to: CGPoint(x: -9, y: -4))
            p.addLine(to: CGPoint(x: -3, y: -4))
            p.addLine(to: CGPoint(x: -3, y: -12))
            p.addLine(to: CGPoint(x: 3, y: -12))
            p.addLine(to: CGPoint(x: 3, y: -4))
            p.addLine(to: CGPoint(x: 9, y: -4))
            p.closeSubpath()
            let arrow = SKShapeNode(path: p)
            arrow.fillColor = kind.color
            arrow.strokeColor = SKColor(red: 1, green: 0.85, blue: 0.65, alpha: 1)
            arrow.lineWidth = 1
            root.addChild(arrow)
        case .gravity:
            let halo = SKShapeNode(circleOfRadius: s.width / 2)
            halo.fillColor = kind.color.withAlphaComponent(0.12)
            halo.strokeColor = kind.color.withAlphaComponent(0.6)
            halo.lineWidth = 1.5
            root.addChild(halo)
            let pulse = SKShapeNode(circleOfRadius: s.width / 2)
            pulse.name = "pulse"
            pulse.strokeColor = kind.color
            pulse.lineWidth = 1
            pulse.fillColor = .clear
            pulse.alpha = 0.7
            pulse.setScale(0.4)
            root.addChild(pulse)
            let core = SKShapeNode(circleOfRadius: 7)
            core.fillColor = kind.color
            core.strokeColor = .white
            core.lineWidth = 1
            core.glowWidth = 4
            root.addChild(core)
        }
        return root
    }
}

// MARK: - Container

final class ContainerNode: SKNode {
    let kind: DropKind
    let target: Int
    private(set) var count = 0
    static let width: CGFloat = 46
    static let height: CGFloat = 56

    private let fill = SKShapeNode()
    private let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let outline: SKShapeNode

    var isFull: Bool { count >= target }

    init(kind: DropKind, target: Int) {
        self.kind = kind
        self.target = target
        let w = ContainerNode.width, h = ContainerNode.height
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -w / 2, y: h))
        path.addLine(to: CGPoint(x: -w / 2, y: 0))
        path.addLine(to: CGPoint(x: w / 2, y: 0))
        path.addLine(to: CGPoint(x: w / 2, y: h))
        outline = SKShapeNode(path: path)
        super.init()
        zPosition = 5

        let glass = SKShapeNode(rect: CGRect(x: -w / 2, y: 0, width: w, height: h))
        glass.fillColor = kind.color.withAlphaComponent(0.10)
        glass.strokeColor = .clear
        addChild(glass)

        fill.fillColor = kind.color.withAlphaComponent(0.85)
        fill.strokeColor = .clear
        addChild(fill)

        outline.strokeColor = kind.color
        outline.lineWidth = 3
        outline.lineCap = .round
        outline.lineJoin = .round
        outline.fillColor = .clear
        addChild(outline)

        label.fontSize = 11
        label.fontColor = kind.lightColor
        label.position = CGPoint(x: 0, y: h + 8)
        label.horizontalAlignmentMode = .center
        addChild(label)

        let walls = SKPhysicsBody(edgeChainFrom: path)
        walls.categoryBitMask = Bits.wall
        walls.collisionBitMask = Bits.droplet
        walls.friction = 0.4
        walls.restitution = 0.05
        physicsBody = walls

        let catcher = SKNode()
        catcher.position = CGPoint(x: 0, y: 9)
        let cb = SKPhysicsBody(rectangleOf: CGSize(width: w - 6, height: 14))
        cb.isDynamic = false
        cb.categoryBitMask = Bits.catcher
        cb.collisionBitMask = 0
        cb.contactTestBitMask = Bits.droplet
        catcher.physicsBody = cb
        addChild(catcher)

        refresh()
    }

    required init?(coder: NSCoder) { fatalError() }

    func add() {
        count = min(target, count + 1)
        refresh()
    }

    func contaminate() {
        count = max(0, count - 1)
        refresh()
        outline.removeAllActions()
        outline.run(.sequence([
            .run { [outline] in outline.strokeColor = SKColor(red: 1, green: 0.25, blue: 0.25, alpha: 1) },
            .wait(forDuration: 0.18),
            .run { [outline, kind] in outline.strokeColor = kind.color }
        ]))
    }

    func reset() {
        count = 0
        refresh()
    }

    private func refresh() {
        let w = ContainerNode.width, h = ContainerNode.height
        let frac = CGFloat(count) / CGFloat(max(1, target))
        let fh = max(0, (h - 6) * frac)
        fill.path = CGPath(rect: CGRect(x: -w / 2 + 2, y: 2, width: w - 4, height: fh), transform: nil)
        label.text = "\(count)/\(target)"
        if isFull, label.fontColor != .white {
            label.fontColor = .white
            outline.glowWidth = 6
            run(.sequence([.scale(to: 1.12, duration: 0.12), .scale(to: 1.0, duration: 0.18)]))
        }
    }
}

// MARK: - Dropper

final class DropperNode: SKNode {
    let spec: DropperSpec
    var accumulator: TimeInterval = 0
    let interval: TimeInterval = 0.24

    init(spec: DropperSpec) {
        self.spec = spec
        super.init()
        zPosition = 6
        zRotation = spec.angle * .pi / 180 + .pi / 2

        let body = SKShapeNode(rect: CGRect(x: -13, y: 4, width: 26, height: 26), cornerRadius: 5)
        body.fillColor = SKColor(red: 0.30, green: 0.33, blue: 0.40, alpha: 1)
        body.strokeColor = SKColor(red: 0.62, green: 0.66, blue: 0.75, alpha: 1)
        body.lineWidth = 1.5
        addChild(body)

        let p = CGMutablePath()
        p.move(to: CGPoint(x: -7, y: 6))
        p.addLine(to: CGPoint(x: 7, y: 6))
        p.addLine(to: CGPoint(x: 4, y: -5))
        p.addLine(to: CGPoint(x: -4, y: -5))
        p.closeSubpath()
        let nozzle = SKShapeNode(path: p)
        nozzle.fillColor = SKColor(red: 0.42, green: 0.45, blue: 0.52, alpha: 1)
        nozzle.strokeColor = SKColor(red: 0.62, green: 0.66, blue: 0.75, alpha: 1)
        nozzle.lineWidth = 1
        addChild(nozzle)

        let light = SKShapeNode(circleOfRadius: 5)
        light.position = CGPoint(x: 0, y: 17)
        light.fillColor = spec.kind.color
        light.strokeColor = spec.kind.lightColor
        light.lineWidth = 1
        light.glowWidth = 2
        addChild(light)
    }

    required init?(coder: NSCoder) { fatalError() }

    var emitPoint: CGPoint { convert(CGPoint(x: 0, y: -8), to: parent!) }
}
