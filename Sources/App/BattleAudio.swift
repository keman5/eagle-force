import AVFoundation
import UIKit
import Observation

@MainActor @Observable
final class FlightMusic: NSObject {
    static let shared = FlightMusic()
    private(set) var playing = false
    private var player: AVAudioPlayer?
    private var enabled = false
    private var active = false
    private var interrupted = false

    private override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(interruption(_:)), name: AVAudioSession.interruptionNotification, object: nil)
    }

    func update(enabled: Bool, active: Bool) {
        self.enabled = enabled
        self.active = active
        refresh()
    }

    func duckForRadio(_ active: Bool) { player?.setVolume(active ? 0.12 : 0.42, fadeDuration: 0.15) }

    private func refresh() {
        guard enabled, active, !interrupted else { player?.pause(); playing = false; return }
        do {
            if player == nil {
                try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
                player = try AVAudioPlayer(data: AudioScore.wav("music"))
                player?.numberOfLoops = -1
                player?.volume = 0.42
                player?.prepareToPlay()
            }
            try AVAudioSession.sharedInstance().setActive(true)
            if player?.isPlaying != true { player?.play() }
            playing = player?.isPlaying == true
        } catch { playing = false }
    }

    @objc private func interruption(_ notification: Notification) {
        guard let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        if type == .began { interrupted = true }
        else {
            let options = AVAudioSession.InterruptionOptions(rawValue: notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0)
            interrupted = !options.contains(.shouldResume)
        }
        refresh()
    }
}

@MainActor
final class BattleAudio {
    private var players: [String: AVAudioPlayer] = [:]
    private let impact = UIImpactFeedbackGenerator(style: .light)
    private var lastShot = 0.0
    var sound = true
    var haptics = true

    init() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            for name in AudioScore.effects {
                let player = try AVAudioPlayer(data: AudioScore.wav(name))
                player.volume = ["shot", "beam", "spread", "lightning"].contains(name) ? 0.08 : name == "alarm" ? 0.4 : 0.23
                player.prepareToPlay(); players[name] = player
            }
        } catch {
            // Sound is optional; interruption or unavailable audio must not stop the sortie.
            players.removeAll()
        }
    }

    func play(_ name: String, time: Double = 0) {
        if name == "shot" {
            guard time - lastShot > 0.12 else { return }
            lastShot = time
        }
        if sound, let player = players[name] { player.currentTime = 0; player.play() }
        if haptics && (name == "explosion" || name == "emp") { impact.impactOccurred(intensity: name == "emp" ? 0.8 : 0.35) }
    }

    func stop() { players.values.forEach { $0.stop() } }

}
