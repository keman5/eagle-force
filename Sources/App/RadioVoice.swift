import AVFoundation
import Observation

@MainActor @Observable
final class RadioVoice: NSObject, @preconcurrency AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private let voice: AVSpeechSynthesisVoice?
    private var utterance: AVSpeechUtterance?
    private(set) var speaking = false
    var enabled: Bool { didSet { if !enabled { stop() } } }
    var availability: String {
        guard let voice else { return "本机暂无中文语音，字幕仍可使用" }
        return voice.gender == .female ? "本机中文女声 · 字幕始终显示" : "本机中文语音 · 字幕始终显示"
    }

    init(enabled: Bool) {
        self.enabled = enabled
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "zh-CN" }
        voice = voices.first(where: { $0.gender == .female && $0.quality == .enhanced })
            ?? voices.first(where: { $0.gender == .female }) ?? voices.first
        super.init()
        synthesizer.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(interrupted), name: AVAudioSession.interruptionNotification, object: nil)
    }

    func play(_ line: RadioLine?) {
        stop()
        guard enabled, let line, line.speaker == .linXi, let voice else { return }
        // shortcut: local speech synthesis; replace with recorded performance for release-quality acting.
        let speech = AVSpeechUtterance(string: line.text)
        speech.voice = voice
        speech.rate = AVSpeechUtteranceDefaultSpeechRate
        speech.volume = 0.9
        utterance = speech
        synthesizer.speak(speech)
    }

    func stop() {
        utterance = nil
        synthesizer.stopSpeaking(at: .immediate)
        speaking = false
        FlightMusic.shared.duckForRadio(false)
    }

    @objc private func interrupted() { stop() }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        guard self.utterance === utterance else { return }
        speaking = true
        FlightMusic.shared.duckForRadio(true)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        if self.utterance === utterance { stop() }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        if self.utterance === utterance { stop() }
    }
}
