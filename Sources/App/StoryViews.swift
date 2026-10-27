import SwiftUI

struct RadioCard: View {
    let line: RadioLine
    var compact = false
    private var tint: Color { line.urgent ? FlightStyle.orange : line.speaker == .linXi ? FlightStyle.cyan : FlightStyle.orange }

    var body: some View {
        HStack(alignment: .top, spacing: compact ? 8 : 11) {
            Image(line.speaker.portrait).resizable().scaledToFill()
                .frame(width: compact ? 30 : 64, height: compact ? 38 : 74).clipped()
                .overlay(Rectangle().stroke(tint.opacity(0.6), lineWidth: 1)).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(line.speaker.name).font(.system(size: compact ? 10 : 14, weight: .bold))
                    Spacer(minLength: 4)
                    Text(line.urgent ? "战术警报" : line.speaker == .linXi ? "回声 / 友军频道" : "截获 / 敌军频道")
                        .font(.system(size: 9, weight: .medium))
                }.foregroundStyle(tint)
                Text(line.text).font(.system(size: compact ? 10 : 14)).lineSpacing(compact ? 1 : 3)
                    .fixedSize(horizontal: false, vertical: true).foregroundStyle(.white)
            }
        }.padding(compact ? 6 : 14)
            .background(FlightStyle.ink.opacity(compact ? 0.6 : 0.94), in: RoundedRectangle(cornerRadius: compact ? 0 : 7))
            .overlay(alignment: .leading) { Rectangle().fill(tint).frame(width: 2) }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(compact ? "radio-caption" : "radio-record-\(line.id)")
    }
}

struct StoryDossier: View {
    let mission: Mission
    @Bindable var store: PilotStore
    @State private var voice = RadioVoice(enabled: true)
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("破晓防线 / 战役档案").font(.system(size: 10, weight: .bold)).tracking(3).foregroundStyle(FlightStyle.cyan)
                        Text(mission.story.chapter).font(.title2.bold()).accessibilityIdentifier("story-chapter")
                        Text(MissionStory.prologue).font(.subheadline).foregroundStyle(FlightStyle.muted).lineSpacing(5)
                        Text(mission.story.premise).font(.body).lineSpacing(5)
                    }
                    ZStack(alignment: .bottomLeading) {
                        Image(mission.story.enemy.portrait).resizable().scaledToFill()
                            .frame(height: 310).clipped().accessibilityHidden(true)
                        LinearGradient(colors: [.clear, FlightStyle.ink], startPoint: .center, endPoint: .bottom)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(mission.story.enemy.role).font(.caption.bold()).foregroundStyle(FlightStyle.orange)
                            Text(mission.story.enemy.name).font(.system(size: 34, weight: .bold)).accessibilityIdentifier("enemy-name")
                            Text("指挥机体 / " + mission.boss).font(.subheadline)
                        }.padding(18)
                    }.clipShape(RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 12) {
                        Text("敌军档案").font(.headline).foregroundStyle(FlightStyle.orange)
                        Text(mission.story.enemy.biography).lineSpacing(5)
                        Text("“\(mission.story.taunt)”").italic().foregroundStyle(FlightStyle.muted)
                    }.font(.subheadline)
                    VStack(alignment: .leading, spacing: 12) {
                        Label("林汐 · 弱点解析", systemImage: "scope").font(.headline).foregroundStyle(FlightStyle.cyan)
                        Text(mission.story.analysis).lineSpacing(5)
                        Text(mission.story.phase).foregroundStyle(FlightStyle.muted).lineSpacing(5)
                        Text("把握射击间隙与弹幕空隙，所有命中均作用于机体耐久。").font(.caption).foregroundStyle(FlightStyle.muted)
                    }.font(.subheadline).padding(18).background(FlightStyle.panel, in: RoundedRectangle(cornerRadius: 12))
                    HStack(alignment: .top, spacing: 14) {
                        Image(StoryCharacter.linXi.portrait).resizable().scaledToFill().frame(width: 76, height: 96).clipped().accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("林汐 / 你的频道搭档").font(.headline).foregroundStyle(FlightStyle.cyan)
                            Text(StoryCharacter.linXi.biography).font(.subheadline).lineSpacing(4)
                        }
                    }
                    Toggle("林汐语音支援", isOn: Binding(get: { store.pilot.voiceSupport }, set: { store.set(\.voiceSupport, to: $0) }))
                        .accessibilityIdentifier("voice-toggle")
                    Text(voice.availability).font(.caption).foregroundStyle(FlightStyle.muted)
                    Button {
                        voice.enabled = store.pilot.voiceSupport
                        voice.play(RadioLine(id: "preview", speaker: .linXi, text: mission.story.opening, urgent: false))
                    } label: {
                        Label(voice.speaking ? "林汐正在通讯" : "试听林汐", systemImage: "waveform")
                    }.buttonStyle(FlightButtonStyle()).disabled(!store.pilot.voiceSupport).accessibilityIdentifier("preview-voice")
                    if store.pilot.medals[mission.id, default: []].contains("clear") {
                        Text("任务后记").font(.headline).foregroundStyle(FlightStyle.orange)
                        Text(mission.story.victory).font(.subheadline).lineSpacing(5)
                    }
                }.padding(22).frame(maxWidth: 600).frame(maxWidth: .infinity)
            }.background(FlightStyle.ink).foregroundStyle(.white)
                .navigationTitle("战情与人物").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("返回战区") { dismiss() }.accessibilityIdentifier("close-dossier") } }
                .toolbarBackground(FlightStyle.ink, for: .navigationBar).toolbarBackground(.visible, for: .navigationBar)
        }.tint(FlightStyle.cyan).preferredColorScheme(.dark)
            .onDisappear { voice.stop() }
            .onChange(of: store.pilot.voiceSupport) { _, enabled in voice.enabled = enabled }
            .onChange(of: scenePhase) { _, phase in if phase != .active { voice.stop() } }
    }
}

struct RadioLogView: View {
    let mission: Mission
    let lines: [RadioLine]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("暂停期间可回顾本次通讯；继续飞行后频道恢复。").font(.caption).foregroundStyle(FlightStyle.muted)
                    ForEach(lines) { RadioCard(line: $0) }
                    Text("战术备忘 / " + mission.boss).font(.headline).foregroundStyle(FlightStyle.cyan)
                    Text(mission.story.analysis).font(.subheadline).lineSpacing(4)
                    Text(mission.story.phase).font(.subheadline).foregroundStyle(FlightStyle.muted).lineSpacing(4)
                }.padding(18).frame(maxWidth: 600).frame(maxWidth: .infinity)
            }.background(FlightStyle.ink).foregroundStyle(.white)
                .navigationTitle("通讯记录").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("关闭") { dismiss() }.accessibilityIdentifier("close-radio-log") } }
        }.tint(FlightStyle.cyan).preferredColorScheme(.dark)
    }
}

struct OpeningStoryView: View {
    let voiceEnabled: Bool
    let reducedMotion: Bool
    let finished: () -> Void
    @State private var page = 0
    @State private var voice = RadioVoice(enabled: true)
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var systemReducedMotion

    private let titles = ["天穹失联", "最后的频道", "破晓，起航"]
    private let scenes: [ModelPreview.Content] = [.orbit, .hangar, .departure]
    private let captions = [
        "游隼，听得到吗？天穹曾是保护群岛的防御网络。今夜，零点协议接管了它。守护者的炮口，正在转向城市。",
        "我是林汐，呼号回声。主频道已经中断，但我会一直在这里。海面上还有失联的飞行员，我们得把他们带回家。",
        "破晓中队，只剩下你能穿过封锁。先去碧潮群岛，找到黑匣子信号。游隼，选择第一条航线，我们一起夺回天空。"
    ]
    private var line: RadioLine { RadioLine(id: "prologue-\(page)", speaker: .linXi, text: captions[page], urgent: false) }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ZStack {
                    ModelPreview(content: scenes[page])
                        .frame(width: geo.size.width, height: geo.size.height).clipped()
                        .overlay(LinearGradient(colors: [.black.opacity(0.25), .clear, FlightStyle.ink], startPoint: .top, endPoint: .bottom))
                        .id(page).transition(.opacity).accessibilityHidden(true)
                }.animation(reducedMotion || systemReducedMotion ? nil : .easeInOut(duration: 0.6), value: page)
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Text("苍穹突击 / 破晓防线").font(.system(size: 11, weight: .bold)).tracking(2)
                        Spacer()
                        Button("跳过剧情", action: complete).font(.system(size: 13, weight: .semibold))
                            .padding(12).background(.black.opacity(0.55), in: Capsule())
                            .accessibilityIdentifier("skip-opening")
                    }
                    Spacer(minLength: 20)
                    HStack(spacing: 6) {
                        ForEach(0..<3) { index in
                            Capsule().fill(index == page ? FlightStyle.cyan : .white.opacity(0.3)).frame(width: index == page ? 32 : 12, height: 3)
                        }
                        Text("序幕 0\(page + 1) / 03").font(.system(size: 10, weight: .bold)).tracking(2).padding(.leading, 7)
                    }
                    Text(titles[page]).font(.system(size: 38, weight: .black)).accessibilityIdentifier("opening-title")
                    RadioCard(line: line)
                    Button(page == 2 ? "进入战区" : "继续通讯", action: next)
                        .buttonStyle(FlightButtonStyle(primary: true)).accessibilityIdentifier("opening-next")
                }.padding(.horizontal, 24).padding(.vertical, 18)
            }.background(FlightStyle.ink).foregroundStyle(.white)
        }
        .task(id: "\(page)-\(scenePhase)") {
            guard scenePhase == .active else { return }
            voice.enabled = voiceEnabled
            voice.play(line)
            do { try await Task.sleep(for: .seconds(line.duration)) } catch { return }
            guard !Task.isCancelled else { return }
            next()
        }
        .onChange(of: scenePhase) { _, phase in if phase != .active { voice.stop() } }
        .onDisappear { voice.stop() }
    }

    private func next() {
        voice.stop()
        if page < 2 { page += 1 } else { complete() }
    }

    private func complete() { voice.stop(); finished() }
}
