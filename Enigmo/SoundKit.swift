import AVFoundation
import UIKit

enum Sound {
    case tap, place, pickup, remove, collect(Double), absorb, bad, win, unlock
}

/// Tiny synth. Every sound is generated at launch, so the app ships with no audio files.
final class SoundKit {
    static let shared = SoundKit()
    var enabled = true

    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var next = 0
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var buffers: [String: AVAudioPCMBuffer] = [:]
    private var lastCollect: TimeInterval = 0
    private var ready = false

    private init() {
        for _ in 0..<6 {
            let p = AVAudioPlayerNode()
            engine.attach(p)
            engine.connect(p, to: engine.mainMixerNode, format: format)
            players.append(p)
        }
        engine.mainMixerNode.outputVolume = 0.8
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        build()
        start()
    }

    private func start() {
        do {
            try engine.start()
            ready = true
        } catch {
            ready = false
        }
    }

    func play(_ sound: Sound) {
        guard enabled else { return }
        if !engine.isRunning { start() }
        guard ready else { return }
        let key: String
        switch sound {
        case .tap: key = "tap"
        case .place: key = "place"
        case .pickup: key = "pickup"
        case .remove: key = "remove"
        case .collect(let f):
            let now = CACurrentMediaTime()
            guard now - lastCollect > 0.05 else { return }
            lastCollect = now
            key = "collect\(min(9, max(0, Int(f * 9.99))))"
        case .absorb: key = "absorb"
        case .bad: key = "bad"
        case .win: key = "win"
        case .unlock: key = "unlock"
        }
        guard let buf = buffers[key] else { return }
        let p = players[next]
        next = (next + 1) % players.count
        p.stop()
        p.scheduleBuffer(buf, at: nil, options: [], completionHandler: nil)
        p.play()
    }

    // MARK: Synthesis

    private struct Note { var freqs: [Double]; var start: Double; var dur: Double; var vol: Float; var decay: Double }

    private func render(_ notes: [Note]) -> AVAudioPCMBuffer {
        let sr = format.sampleRate
        let total = notes.map { $0.start + $0.dur }.max() ?? 0.1
        let n = AVAudioFrameCount(sr * total) + 1
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: n)!
        buf.frameLength = n
        let out = buf.floatChannelData![0]
        for i in 0..<Int(n) { out[i] = 0 }
        for note in notes {
            let s = Int(note.start * sr)
            let len = Int(note.dur * sr)
            for i in 0..<len where s + i < Int(n) {
                let t = Double(i) / sr
                let env = exp(-note.decay * t) * min(1, t * 600) * min(1, (note.dur - t) * 200)
                var v = 0.0
                for f in note.freqs { v += sin(2 * .pi * f * t) + 0.25 * sin(4 * .pi * f * t) }
                out[s + i] += Float(v / Double(note.freqs.count)) * note.vol * Float(env)
            }
        }
        return buf
    }

    private func build() {
        buffers["tap"] = render([Note(freqs: [720], start: 0, dur: 0.05, vol: 0.18, decay: 40)])
        buffers["place"] = render([Note(freqs: [420], start: 0, dur: 0.09, vol: 0.30, decay: 28),
                                   Note(freqs: [630], start: 0.03, dur: 0.08, vol: 0.20, decay: 30)])
        buffers["pickup"] = render([Note(freqs: [560], start: 0, dur: 0.06, vol: 0.22, decay: 35)])
        buffers["remove"] = render([Note(freqs: [380], start: 0, dur: 0.07, vol: 0.22, decay: 30),
                                    Note(freqs: [260], start: 0.05, dur: 0.09, vol: 0.20, decay: 25)])
        let scale: [Double] = [523.25, 587.33, 659.25, 783.99, 880.00, 1046.5, 1174.7, 1318.5, 1568.0, 1760.0]
        for (i, f) in scale.enumerated() {
            buffers["collect\(i)"] = render([Note(freqs: [f], start: 0, dur: 0.13, vol: 0.22, decay: 20)])
        }
        buffers["absorb"] = render([Note(freqs: [170, 190], start: 0, dur: 0.12, vol: 0.28, decay: 22)])
        buffers["bad"] = render([Note(freqs: [118, 125], start: 0, dur: 0.28, vol: 0.35, decay: 9)])
        buffers["win"] = render([
            Note(freqs: [523.25], start: 0.00, dur: 0.30, vol: 0.30, decay: 7),
            Note(freqs: [659.25], start: 0.12, dur: 0.30, vol: 0.30, decay: 7),
            Note(freqs: [783.99], start: 0.24, dur: 0.30, vol: 0.30, decay: 7),
            Note(freqs: [1046.5, 523.25], start: 0.36, dur: 0.60, vol: 0.34, decay: 4)
        ])
        buffers["unlock"] = render([
            Note(freqs: [880], start: 0.00, dur: 0.16, vol: 0.26, decay: 14),
            Note(freqs: [1108.7], start: 0.10, dur: 0.16, vol: 0.26, decay: 14),
            Note(freqs: [1318.5], start: 0.20, dur: 0.40, vol: 0.28, decay: 6)
        ])
    }
}

@MainActor
enum Haptics {
    static var enabled = true
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let notify = UINotificationFeedbackGenerator()
    private static var lastWarning: TimeInterval = 0

    static func tap() { guard enabled else { return }; light.impactOccurred(intensity: 0.6) }
    static func place() { guard enabled else { return }; medium.impactOccurred() }
    static func success() { guard enabled else { return }; notify.notificationOccurred(.success) }
    static func warning() {
        guard enabled else { return }
        let now = CACurrentMediaTime()
        guard now - lastWarning > 0.4 else { return }
        lastWarning = now
        notify.notificationOccurred(.warning)
    }
}
