import Foundation

enum AudioScore {
    static let effects = ["shot", "pickup", "explosion", "emp", "alarm", "warning", "bossShot", "laser", "beacon", "beam", "spread", "lightning"]

    // Original synthesized score and cues; no downloaded music or external audio dependency.
    static func wav(_ name: String) -> Data {
        let duration: Double = switch name {
        case "music": 32
        case "alarm": 2.4
        case "emp": 1.1
        case "laser": 0.8
        case "warning", "beacon": 0.6
        case "shot": 0.055
        case "beam": 0.11
        case "spread": 0.16
        case "lightning": 0.23
        default: 0.25
        }
        let sampleRate = 22_050
        let count = Int(Double(sampleRate) * duration)
        var data = Data(capacity: 44 + count * 2)
        func text(_ s: String) { data.append(contentsOf: s.utf8) }
        func u32(_ n: UInt32) { withUnsafeBytes(of: n.littleEndian) { data.append(contentsOf: $0) } }
        func u16(_ n: UInt16) { withUnsafeBytes(of: n.littleEndian) { data.append(contentsOf: $0) } }
        text("RIFF"); u32(UInt32(36 + count * 2)); text("WAVEfmt "); u32(16); u16(1); u16(1)
        u32(UInt32(sampleRate)); u32(UInt32(sampleRate * 2)); u16(2); u16(16); text("data"); u32(UInt32(count * 2))
        var noise: UInt32 = 31
        for index in 0..<count {
            let t = Double(index) / Double(sampleRate)
            noise = noise &* 1664525 &+ 1013904223
            let hiss = Double(noise % 2000) / 1000 - 1
            let tau = 2 * Double.pi
            let waveform: Double
            if name == "music" {
                let chord = Int(t / 4) % 4
                let root = [110.0, 87.307, 130.813, 97.999][chord]
                let chordTime = t.truncatingRemainder(dividingBy: 4)
                let padEnvelope = min(1, chordTime * 3, (4 - chordTime) * 3)
                let pad = (sin(tau * root * t) + sin(tau * root * 1.5 * t) * 0.5) * 0.18 * padEnvelope
                let beat = t.truncatingRemainder(dividingBy: 0.5)
                let kick = sin(tau * (48 * beat + 1.6 * (1 - exp(-beat * 30)))) * exp(-beat * 22) * 0.32
                let tick = t.truncatingRemainder(dividingBy: 0.25)
                let hat = hiss * exp(-tick * 90) * 0.045
                let note = [1.0, 1.5, 2.0, 2.378, 2.0, 1.5, 1.335, 1.5][Int(t * 4) % 8]
                let arpeggio = sin(tau * root * 2 * note * tick) * exp(-tick * 15) * 0.1
                let melodyNotes = [9, 12, 16, 14, 12, 9, 7, 4, 5, 9, 12, 16, 14, 12, 7, 9]
                let phrase = Int(t / 2) % melodyNotes.count
                let noteTime = t.truncatingRemainder(dividingBy: 2)
                let hz = 220 * pow(2, Double(melodyNotes[phrase]) / 12)
                let melody = (sin(tau * hz * noteTime) + 0.2 * sin(tau * hz * 2 * noteTime))
                    * min(1, noteTime * 7) * exp(-noteTime * 1.4) * 0.13
                waveform = pad + kick + hat + arpeggio + melody
            } else {
                let envelope = min(1, t * 180) * pow(1 - t / duration, 1.5)
                let tone: Double = switch name {
                case "explosion": hiss * 0.8 + sin(tau * 65 * t) * 0.2
                case "alarm": sin(tau * 520 * t - 65 * cos(tau * 2.5 * t)) * 0.8
                case "warning": sin(tau * 880 * t) * (sin(tau * 8 * t) > 0 ? 0.7 : 0.1)
                case "emp": sin(tau * (180 * t + 180 * t * t)) * 0.6 + hiss * 0.25
                case "laser": sin(tau * (1100 * t - 450 * t * t)) * 0.65 + hiss * 0.2
                case "beam": sin(tau * (1600 * t - 900 * t * t)) * 0.5
                case "spread": hiss * 0.35 + sin(tau * (280 * t - 450 * t * t)) * 0.55
                case "lightning": hiss * 0.5 + sin(tau * 2100 * t) * exp(-t * 30) * 0.3
                case "bossShot": sin(tau * (170 * t - 150 * t * t)) * 0.8
                case "beacon": sin(tau * (t < 0.3 ? 880 : 1320) * t) * 0.6
                case "pickup": sin(tau * (1000 * t + 700 * t * t)) * 0.7
                default: sin(tau * 850 * t * (1 - t / duration * 0.4)) * 0.7
                }
                waveform = tone * envelope
            }
            let edgeFade = min(1, t * 100, (duration - t) * 100)
            assert(waveform.isFinite && abs(waveform) <= 1)
            u16(UInt16(bitPattern: Int16(max(-1, min(1, waveform * edgeFade)) * 26_000)))
        }
        return data
    }
}
