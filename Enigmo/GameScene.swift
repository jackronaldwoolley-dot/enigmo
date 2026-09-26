import SpriteKit
import UIKit

final class GameScene: SKScene, SKPhysicsContactDelegate {
    weak var model: GameModel?
    var topInset: CGFloat = 0
    var bottomInset: CGFloat = 0

    private(set) var level: Level?
    private var playRect: CGRect = .zero
    private var trayHeight: CGFloat { bottomInset + 92 }
    private var hudHeight: CGFloat { topInset + 62 }

    private let staticLayer = SKNode()
    private let worldLayer = SKNode()
    private let toolLayer = SKNode()
    private let dropLayer = SKNode()
    private let fxLayer = SKNode()
    private let trayLayer = SKNode()

    private var tools: [ToolNode] = []
    private var droppers: [DropperNode] = []
    private var containers: [ContainerNode] = []
    private var counts: [ToolKind: Int] = [:]
    private var slots: [(kind: ToolKind, x: CGFloat, label: SKLabelNode, icon: SKNode)] = []

    private var selected: ToolNode? {
        didSet {
            oldValue?.isSelected = false
            selected?.isSelected = true
        }
    }
    private enum DragMode { case none, move(ToolNode, CGPoint), rotate(ToolNode, CGFloat) }
    private var mode: DragMode = .none
    private var activeTouch: UITouch?

    private var lastTime: TimeInterval = 0
    private var elapsed: TimeInterval = 0
    private var lastTick: TimeInterval = 0
    private var running = false
    private var toRemove = Set<DropletNode>()
    private var textures: [DropKind: SKTexture] = [:]
    private let maxDroplets = 120
    /// Scales the whole simulation. 0.8 = droplets move 20% slower along the same paths.
    static let pace: CGFloat = 0.8
    /// How far above the finger a dragged part floats.
    static let hoverOffset: CGFloat = 40

    // MARK: Setup

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.05, green: 0.07, blue: 0.12, alpha: 1)
        physicsWorld.gravity = CGVector(dx: 0, dy: -2.6 * GameScene.pace * GameScene.pace)
        physicsWorld.contactDelegate = self
        for l in [staticLayer, worldLayer, toolLayer, dropLayer, fxLayer, trayLayer] where l.parent == nil { addChild(l) }
        staticLayer.zPosition = 0
        worldLayer.zPosition = 1
        dropLayer.zPosition = 8
        toolLayer.zPosition = 10
        fxLayer.zPosition = 20
        trayLayer.zPosition = 30
        buildTextures(in: view)
        layoutRects()
        buildBackground()
    }

    private func layoutRects() {
        playRect = CGRect(x: 0, y: trayHeight, width: size.width, height: size.height - trayHeight - hudHeight)
    }

    private func buildTextures(in view: SKView) {
        for kind in DropKind.allCases {
            let s = SKShapeNode(circleOfRadius: 4.5)
            s.fillColor = kind.color
            s.strokeColor = kind.lightColor
            s.lineWidth = 1
            s.glowWidth = 1.5
            if let t = view.texture(from: s) { textures[kind] = t }
        }
    }

    private func buildBackground() {
        staticLayer.removeAllChildren()
        let grid = CGMutablePath()
        let step: CGFloat = 36
        var x = playRect.minX
        while x <= playRect.maxX { grid.move(to: CGPoint(x: x, y: playRect.minY)); grid.addLine(to: CGPoint(x: x, y: playRect.maxY)); x += step }
        var y = playRect.minY
        while y <= playRect.maxY { grid.move(to: CGPoint(x: playRect.minX, y: y)); grid.addLine(to: CGPoint(x: playRect.maxX, y: y)); y += step }
        let g = SKShapeNode(path: grid)
        g.strokeColor = SKColor(white: 1, alpha: 0.045)
        g.lineWidth = 1
        staticLayer.addChild(g)

        let frame = SKShapeNode(rect: playRect.insetBy(dx: 1, dy: 1))
        frame.strokeColor = SKColor(white: 1, alpha: 0.18)
        frame.lineWidth = 2
        frame.fillColor = .clear
        staticLayer.addChild(frame)

        let panel = SKShapeNode(rect: CGRect(x: 0, y: 0, width: size.width, height: trayHeight))
        panel.fillColor = SKColor(red: 0.09, green: 0.11, blue: 0.17, alpha: 1)
        panel.strokeColor = .clear
        staticLayer.addChild(panel)
        let line = SKShapeNode(rect: CGRect(x: 0, y: trayHeight - 1, width: size.width, height: 1))
        line.fillColor = SKColor(white: 1, alpha: 0.2)
        line.strokeColor = .clear
        staticLayer.addChild(line)
    }

    // MARK: Level lifecycle

    func load(_ level: Level) {
        self.level = level
        isPaused = false
        layoutRects()
        buildBackground()
        worldLayer.removeAllChildren()
        toolLayer.removeAllChildren()
        dropLayer.removeAllChildren()
        fxLayer.removeAllChildren()
        removeAllActions()
        tools.removeAll()
        droppers.removeAll()
        containers.removeAll()
        toRemove.removeAll()
        selected = nil
        mode = .none
        activeTouch = nil
        elapsed = 0
        lastTick = 0
        lastTime = 0
        counts = level.tools

        // Boundary: left, top, right (bottom is open; droplets vanish there).
        let edge = CGMutablePath()
        edge.move(to: CGPoint(x: playRect.minX, y: playRect.minY - 40))
        edge.addLine(to: CGPoint(x: playRect.minX, y: playRect.maxY))
        edge.addLine(to: CGPoint(x: playRect.maxX, y: playRect.maxY))
        edge.addLine(to: CGPoint(x: playRect.maxX, y: playRect.minY - 40))
        let boundary = SKNode()
        let eb = SKPhysicsBody(edgeChainFrom: edge)
        eb.categoryBitMask = Bits.wall
        eb.collisionBitMask = Bits.droplet
        eb.friction = 0.2
        eb.restitution = 0.2
        boundary.physicsBody = eb
        worldLayer.addChild(boundary)

        for w in level.walls { worldLayer.addChild(makeWall(w)) }
        for c in level.containers {
            let n = ContainerNode(kind: c.kind, target: level.target)
            n.position = point(c.x, c.y)
            worldLayer.addChild(n)
            containers.append(n)
        }
        for d in level.droppers {
            let n = DropperNode(spec: d)
            n.position = point(d.x, d.y)
            worldLayer.addChild(n)
            droppers.append(n)
        }
        buildTray()
        running = true
    }

    func stopLevel() {
        running = false
        isPaused = true
    }

    /// Called by the hosting view whenever the safe area changes. Rebuilds the current level
    /// only if the playfield actually moved.
    func applyInsets(top: CGFloat, bottom: CGFloat) {
        guard top != topInset || bottom != bottomInset else { return }
        topInset = top
        bottomInset = bottom
        layoutRects()
        buildBackground()
        if let level, running { load(level) }
    }

    private func point(_ fx: CGFloat, _ fy: CGFloat) -> CGPoint {
        CGPoint(x: playRect.minX + fx * playRect.width, y: playRect.minY + fy * playRect.height)
    }

    private func makeWall(_ w: WallSpec) -> SKNode {
        let rect = CGRect(x: playRect.minX + w.x * playRect.width,
                          y: playRect.minY + w.y * playRect.height,
                          width: w.w * playRect.width,
                          height: w.h * playRect.height)
        let n = SKShapeNode(rectOf: rect.size, cornerRadius: 3)
        n.position = CGPoint(x: rect.midX, y: rect.midY)
        n.fillColor = SKColor(red: 0.23, green: 0.26, blue: 0.33, alpha: 1)
        n.strokeColor = SKColor(red: 0.40, green: 0.44, blue: 0.54, alpha: 1)
        n.lineWidth = 1.5
        let hl = SKShapeNode(rect: CGRect(x: -rect.width / 2 + 3, y: rect.height / 2 - 4, width: rect.width - 6, height: 2))
        hl.fillColor = SKColor(white: 1, alpha: 0.12)
        hl.strokeColor = .clear
        n.addChild(hl)
        let b = SKPhysicsBody(rectangleOf: rect.size)
        b.isDynamic = false
        b.categoryBitMask = Bits.wall
        b.collisionBitMask = Bits.droplet
        b.friction = 0.3
        b.restitution = 0.25
        n.physicsBody = b
        return n
    }

    private func buildTray() {
        trayLayer.removeAllChildren()
        slots.removeAll()
        guard let level else { return }
        let kinds = ToolKind.allCases.filter { (level.tools[$0] ?? 0) > 0 }
        let n = CGFloat(max(1, kinds.count))
        for (i, k) in kinds.enumerated() {
            let x = size.width * (CGFloat(i) + 0.5) / n
            let y = bottomInset + 54
            let icon = ToolNode.icon(kind: k)
            icon.position = CGPoint(x: x, y: y)
            trayLayer.addChild(icon)
            let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
            label.fontSize = 12
            label.fontColor = SKColor(white: 1, alpha: 0.85)
            label.position = CGPoint(x: x, y: bottomInset + 14)
            label.horizontalAlignmentMode = .center
            trayLayer.addChild(label)
            slots.append((k, x, label, icon))
        }
        refreshTray()
    }

    private func refreshTray() {
        for s in slots {
            let c = counts[s.kind] ?? 0
            s.label.text = "\(s.kind.title) × \(c)"
            s.icon.alpha = c > 0 ? 1 : 0.28
            s.label.alpha = c > 0 ? 1 : 0.4
        }
    }

    private func send(_ event: GameEvent) {
        MainActor.assumeIsolated { model?.handle(event) }
    }

    // MARK: Update

    override func update(_ currentTime: TimeInterval) {
        guard running else { lastTime = currentTime; return }
        let dt = lastTime == 0 ? 0 : min(currentTime - lastTime, 1.0 / 20.0)
        lastTime = currentTime
        elapsed += dt

        for d in droppers {
            d.accumulator += dt
            while d.accumulator >= d.interval {
                d.accumulator -= d.interval
                if dropLayer.children.count < maxDroplets { emit(from: d) }
            }
        }

        let accels = tools.filter { $0.kind == .accelerator }
        let wells = tools.filter { $0.kind == .gravity }
        let killRect = playRect.insetBy(dx: -30, dy: -30)
        for case let drop as DropletNode in dropLayer.children {
            guard let body = drop.physicsBody else { continue }
            if drop.position.y < playRect.minY - 2 || !killRect.contains(drop.position) || elapsed - drop.born > 30 {
                toRemove.insert(drop)
                continue
            }
            // Droplets that come to rest evaporate so ledges never clog up.
            let speed = hypot(body.velocity.dx, body.velocity.dy)
            drop.idle = speed < 6 * GameScene.pace ? drop.idle + dt : 0
            if drop.idle > 1.6 {
                toRemove.insert(drop)
                puff(at: drop.position, color: drop.kind.color.withAlphaComponent(0.5), big: false)
                continue
            }
            for a in accels where hypot(drop.position.x - a.position.x, drop.position.y - a.position.y) < 20 {
                let dir = a.direction
                body.velocity = CGVector(dx: dir.dx * 320 * GameScene.pace, dy: dir.dy * 320 * GameScene.pace)
            }
            for w in wells {
                let dx = w.position.x - drop.position.x, dy = w.position.y - drop.position.y
                let d = hypot(dx, dy)
                let radius: CGFloat = 130
                guard d < radius, d > 4 else { continue }
                let strength: CGFloat = (1500 * (1 - d / radius) + 200) * GameScene.pace * GameScene.pace
                var v = body.velocity
                v.dx += dx / d * strength * dt
                v.dy += dy / d * strength * dt
                let s = hypot(v.dx, v.dy)
                let cap = 720 * GameScene.pace
                if s > cap { v.dx *= cap / s; v.dy *= cap / s }
                body.velocity = v
            }
        }
        flushRemovals()

        if elapsed - lastTick >= 0.1 {
            lastTick = elapsed
            send(.tick(elapsed))
        }
    }

    override func didSimulatePhysics() {
        flushRemovals()
    }

    private func flushRemovals() {
        guard !toRemove.isEmpty else { return }
        for d in toRemove { d.removeFromParent() }
        toRemove.removeAll()
    }

    private func emit(from dropper: DropperNode) {
        let spec = dropper.spec
        let drop = DropletNode(texture: textures[spec.kind])
        drop.kind = spec.kind
        drop.born = elapsed
        drop.size = CGSize(width: 11, height: 11)
        let angle = spec.angle * .pi / 180
        let dir = CGVector(dx: cos(angle), dy: sin(angle))
        let jitter = CGFloat.random(in: -1.5...1.5)
        let p = dropper.emitPoint
        drop.position = CGPoint(x: p.x + dir.dx * 4 - dir.dy * jitter, y: p.y + dir.dy * 4 + dir.dx * jitter)
        let body = SKPhysicsBody(circleOfRadius: 4)
        body.categoryBitMask = Bits.droplet
        body.collisionBitMask = Bits.wall | Bits.tool
        body.contactTestBitMask = Bits.sponge | Bits.catcher
        body.restitution = 0
        body.friction = 0.05
        body.linearDamping = 0.02
        body.allowsRotation = false
        body.usesPreciseCollisionDetection = true
        body.mass = 0.02
        drop.physicsBody = body
        dropLayer.addChild(drop)
        let perp = CGFloat.random(in: -6...6)
        body.velocity = CGVector(dx: (dir.dx * spec.speed - dir.dy * perp) * GameScene.pace, dy: (dir.dy * spec.speed + dir.dx * perp) * GameScene.pace)
    }

    // MARK: Contacts

    func didBegin(_ contact: SKPhysicsContact) {
        let a = contact.bodyA, b = contact.bodyB
        let (dropBody, other) = a.categoryBitMask == Bits.droplet ? (a, b) : (b, a)
        guard dropBody.categoryBitMask == Bits.droplet,
              let drop = dropBody.node as? DropletNode,
              !toRemove.contains(drop) else { return }

        if other.categoryBitMask == Bits.sponge {
            toRemove.insert(drop)
            puff(at: drop.position, color: drop.kind.color, big: false)
            send(.absorbed)
        } else if other.categoryBitMask == Bits.catcher, let c = other.node?.parent as? ContainerNode {
            toRemove.insert(drop)
            if c.kind == drop.kind {
                if !c.isFull {
                    c.add()
                    puff(at: drop.position, color: drop.kind.lightColor, big: false)
                    send(.caught(drop.kind, fraction: Double(c.count) / Double(c.target)))
                    checkWin()
                }
            } else {
                c.contaminate()
                puff(at: drop.position, color: SKColor(red: 1, green: 0.3, blue: 0.3, alpha: 1), big: true)
                send(.contaminated)
            }
        }
    }

    private func checkWin() {
        guard running, !containers.isEmpty, containers.allSatisfy({ $0.isFull }) else { return }
        running = false
        selected = nil
        mode = .none
        activeTouch = nil
        for c in containers {
            for i in 0..<12 {
                let p = CGPoint(x: c.position.x + CGFloat.random(in: -22...22), y: c.position.y + CGFloat.random(in: 10...64))
                run(.sequence([.wait(forDuration: Double(i) * 0.05), .run { [weak self] in self?.puff(at: p, color: c.kind.lightColor, big: true) }]))
            }
        }
        for case let drop as DropletNode in dropLayer.children {
            drop.run(.sequence([.fadeOut(withDuration: 0.4), .removeFromParent()]))
        }
        let time = elapsed
        let used = tools.count
        let kinds = Set(tools.map(\.kind))
        run(.sequence([.wait(forDuration: 0.8), .run { [weak self] in
            self?.send(.won(elapsed: time, partsUsed: used, kindsUsed: kinds))
        }]))
    }

    private func puff(at p: CGPoint, color: SKColor, big: Bool) {
        let n = SKShapeNode(circleOfRadius: big ? 6 : 3)
        n.fillColor = color
        n.strokeColor = .clear
        n.position = p
        n.alpha = 0.9
        fxLayer.addChild(n)
        n.run(.sequence([.group([.scale(to: big ? 4 : 2.6, duration: 0.3), .fadeOut(withDuration: 0.3)]), .removeFromParent()]))
    }

    // MARK: Touch

    private func slot(at p: CGPoint) -> ToolKind? {
        guard p.y < trayHeight, !slots.isEmpty else { return nil }
        let half = size.width / CGFloat(slots.count) / 2
        return slots.first { abs($0.x - p.x) <= half }?.kind
    }

    private func tool(at p: CGPoint) -> ToolNode? {
        if let s = selected, s.hitTest(p) { return s }
        return tools.reversed().first { $0.hitTest(p) }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard running, activeTouch == nil, let t = touches.first else { return }
        let p = t.location(in: self)

        if let s = selected, s.knobContains(p) {
            activeTouch = t
            mode = .rotate(s, s.zRotation)
            return
        }
        if p.y < trayHeight {
            if let kind = slot(at: p), (counts[kind] ?? 0) > 0 {
                counts[kind]! -= 1
                refreshTray()
                let tool = ToolNode(kind: kind)
                tool.position = CGPoint(x: p.x, y: p.y + GameScene.hoverOffset)
                tool.setScale(0.6)
                tool.run(.scale(to: 1, duration: 0.15))
                toolLayer.addChild(tool)
                tools.append(tool)
                selected = tool
                activeTouch = t
                mode = .move(tool, CGPoint(x: 0, y: GameScene.hoverOffset))
                MainActor.assumeIsolated { SoundKit.shared.play(.pickup) }
            }
            return
        }
        if let tool = tool(at: p) {
            selected = tool
            activeTouch = t
            // Keep the part's x under the finger but hover it a little above so it stays visible.
            mode = .move(tool, CGPoint(x: tool.position.x - p.x, y: max(tool.position.y - p.y, GameScene.hoverOffset)))
            MainActor.assumeIsolated { SoundKit.shared.play(.pickup) }
            return
        }
        selected = nil
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = activeTouch, touches.contains(t) else { return }
        let p = t.location(in: self)
        switch mode {
        case .move(let tool, let off):
            var x = p.x + off.x, y = p.y + off.y
            x = min(max(x, playRect.minX + 8), playRect.maxX - 8)
            y = min(y, playRect.maxY - 8)
            tool.position = CGPoint(x: x, y: y)
            tool.alpha = y < trayHeight + 6 ? 0.45 : 1
        case .rotate(let tool, _):
            tool.zRotation = atan2(p.y - tool.position.y, p.x - tool.position.x) - .pi / 2
        case .none:
            break
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { finishTouch(touches) }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { finishTouch(touches) }

    private func finishTouch(_ touches: Set<UITouch>) {
        guard let t = activeTouch, touches.contains(t) else { return }
        switch mode {
        case .move(let tool, _):
            if tool.position.y < trayHeight + 6 {
                tool.removeFromParent()
                tools.removeAll { $0 === tool }
                counts[tool.kind, default: 0] += 1
                refreshTray()
                if selected === tool { selected = nil }
                send(.removed(tool.kind))
            } else {
                tool.alpha = 1
                send(.placed(tool.kind))
            }
        case .rotate(let tool, let start):
            if abs(tool.zRotation - start) > 0.02 { send(.rotated) }
        case .none:
            break
        }
        activeTouch = nil
        mode = .none
    }
}
