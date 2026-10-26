import SwiftUI

enum FlightStyle {
    static let ink = Color(red: 0.025, green: 0.055, blue: 0.09)
    static let panel = Color(red: 0.055, green: 0.105, blue: 0.15)
    static let cyan = Color(red: 0.45, green: 0.96, blue: 0.88)
    static let muted = Color(red: 0.56, green: 0.66, blue: 0.72)
    static let orange = Color(red: 1, green: 0.72, blue: 0.43)
}

struct FlightButtonStyle: ButtonStyle {
    var primary = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold))
            .frame(maxWidth: .infinity).padding(.vertical, 17)
            .foregroundStyle(primary ? FlightStyle.ink : .white)
            .background(LinearGradient(colors: primary ? [Color(red: 0.9, green: 0.73, blue: 0.39), Color(red: 0.55, green: 0.36, blue: 0.16)] : [FlightStyle.panel, FlightStyle.ink], startPoint: .top, endPoint: .bottom), in: BeveledPanel())
            .overlay(BeveledPanel().stroke(.white.opacity(0.25), lineWidth: 1))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct CampaignView: View {
    @Bindable var store: PilotStore
    @State private var dossier: Mission?
    @State private var tab = 0
    @State private var highlightedMissionID = 1
    @State private var session: BattleSession?
    @State private var showingOpening = true
    @State private var transfer: (from: Int, to: Int, started: Date)?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            FlightStyle.ink.ignoresSafeArea()
            if let session {
                BattleView(session: session, store: store) {
                    session.scene.audio.stop()
                    session.voice.stop()
                    self.session = nil
                    highlightedMissionID = session.mission.id
                    if let result = session.result, result.won, result.missionID < Mission.campaign.count,
                       store.unlocked(result.missionID + 1) {
                        highlightedMissionID = result.missionID + 1
                        if !store.pilot.reducedEffects && !UIAccessibility.isReduceMotionEnabled {
                            transfer = (result.missionID, highlightedMissionID, Date())
                        }
                    }
                    tab = 0
                    AppDelegate.rotate(for: nil)
                }
            } else if store.loadFailed {
                VStack(spacing: 20) {
                    Image(systemName: "externaldrive.badge.exclamationmark").font(.largeTitle)
                    Text("飞行档案暂不可用").font(.title2.bold())
                    Text("原存档已保留。重新读取成功后可继续游戏。").foregroundStyle(FlightStyle.muted)
                    Button("重新读取") { store.reload() }.buttonStyle(FlightButtonStyle(primary: true))
                }.padding(30)
            } else if showingOpening {
                OpeningStoryView(voiceEnabled: store.pilot.voiceSupport, reducedMotion: store.pilot.reducedEffects) {
                    showingOpening = false
                }
            } else {
                if tab == 0 {
                    campaign
                } else {
                    VStack(spacing: 0) {
                        header
                        ScrollView {
                            VStack(spacing: tab == 1 ? 12 : 24) {
                                if tab == 1 { hangar } else { profile }
                            }.frame(maxWidth: 700).padding(22).frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
        .alert("飞行档案", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
            Button("知道了", role: .cancel) { store.error = nil }
        } message: { Text(store.error ?? "") }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { session?.pause(true) }
            FlightMusic.shared.update(enabled: store.pilot.sound, active: phase == .active)
        }
        .onChange(of: store.pilot.sound) { _, enabled in
            FlightMusic.shared.update(enabled: enabled, active: scenePhase == .active)
        }
        .sheet(item: $dossier) { StoryDossier(mission: $0, store: store) }
        .statusBarHidden()
        .task(id: transfer?.started) {
            guard let started = transfer?.started else { return }
            try? await Task.sleep(for: .seconds(2))
            if !Task.isCancelled, transfer?.started == started { transfer = nil }
        }
        .onAppear {
            FlightMusic.shared.update(enabled: store.pilot.sound, active: scenePhase == .active)
            highlightedMissionID = Mission.campaign.last(where: { store.unlocked($0.id) })?.id ?? 1
            #if DEBUG
            let args = ProcessInfo.processInfo.arguments
            if args.contains("-ui-testing"), args.contains("-skip-intro") { showingOpening = false }
            if let index = args.firstIndex(of: "-mission"), args.indices.contains(index + 1),
               let id = Int(args[index + 1]), let mission = Mission.campaign.first(where: { $0.id == id }), store.unlocked(id) {
                start(mission)
            }
            #endif
        }
    }

    private func start(_ mission: Mission) {
        guard store.unlocked(mission.id) else { return }
        transfer = nil
        session = BattleSession(mission: mission, pilot: store.pilot)
        AppDelegate.rotate(for: mission)
    }

    private var header: some View {
        HStack {
            Button { tab = 0 } label: {
                Label("返回战区", systemImage: "chevron.left").font(.system(size: 14, weight: .bold))
                    .padding(14).background(.white.opacity(0.06), in: BeveledPanel())
            }.foregroundStyle(FlightStyle.orange).accessibilityIdentifier("return-map")
            Spacer()
            wallet
        }.padding(.horizontal, 18).padding(.vertical, 10)
    }

    private var wallet: some View {
        Label("\(store.pilot.crystals)", systemImage: "diamond.fill")
            .font(.system(size: 16, weight: .heavy, design: .rounded)).foregroundStyle(FlightStyle.orange)
            .padding(.horizontal, 13).padding(.vertical, 9).background(.black.opacity(0.55), in: BeveledPanel())
            .accessibilityIdentifier("wallet")
    }

    private let routePoints: [CGPoint] = [
        CGPoint(x: 0.25, y: 0.67), CGPoint(x: 0.73, y: 0.55),
        CGPoint(x: 0.30, y: 0.43), CGPoint(x: 0.76, y: 0.32), CGPoint(x: 0.44, y: 0.21)
    ]

    private var campaign: some View {
        GeometryReader { geo in
            let mission = Mission.campaign[highlightedMissionID - 1]
            let points = routePoints.map { CGPoint(x: $0.x * geo.size.width, y: $0.y * geo.size.height) }
            let route = Path { path in
                    path.move(to: points[0])
                    for index in 1..<points.count {
                        let a = points[index - 1], b = points[index]
                        path.addCurve(to: b, control1: CGPoint(x: a.x, y: b.y + 30), control2: CGPoint(x: b.x, y: a.y - 30))
                    }
                }
            ZStack(alignment: .bottom) {
                ModelPreview(content: .campaign)
                    .frame(width: geo.size.width, height: geo.size.height).clipped().ignoresSafeArea()
                LinearGradient(stops: [.init(color: .black.opacity(0.7), location: 0), .init(color: .clear, location: 0.27), .init(color: .clear, location: 0.65), .init(color: FlightStyle.ink, location: 1)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
                route.stroke(.black.opacity(0.6), lineWidth: 5)
                route.stroke(FlightStyle.orange.opacity(0.85), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [3, 7]))
                ForEach(Mission.campaign) { item in
                    mapNode(item).position(points[item.id - 1])
                }
                if let transfer {
                    TimelineView(.animation) { clock in
                        let t = min(1, max(0, clock.date.timeIntervalSince(transfer.started) / 1.8))
                        let a = points[transfer.from - 1], b = points[transfer.to - 1]
                        let point = flightPoint(from: a, to: b, t: t)
                        let ahead = flightPoint(from: a, to: b, t: min(1, t + 0.01))
                        ModelPreview(content: .aircraft).frame(width: 48, height: 48)
                            .rotationEffect(.radians(atan2(ahead.y - point.y, ahead.x - point.x) + .pi / 2))
                            .shadow(color: FlightStyle.cyan.opacity(0.8), radius: 8)
                            .position(point)
                    }.allowsHitTesting(false).accessibilityLabel("战机飞往第 \(transfer.to) 关")
                        .accessibilityIdentifier("campaign-flight")
                }
                VStack(spacing: 14) {
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("战区 " + String(format: "%02d", mission.id) + "  /  " + mission.axisLabel)
                                .font(.system(size: 10, weight: .bold)).tracking(2).foregroundStyle(FlightStyle.orange)
                            Text(mission.title).font(.system(size: 30, weight: .black))
                                .shadow(color: .black, radius: 4).accessibilityIdentifier("selected-mission")
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 6) {
                            Text("◆ +\(mission.firstClear)").font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundStyle(FlightStyle.orange)
                            Text("首次解放").font(.system(size: 10)).foregroundStyle(FlightStyle.muted)
                        }
                    }
                    Button { dossier = mission } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "waveform")
                            Text(mission.story.chapter).font(.system(size: 12, weight: .medium))
                            Spacer()
                            Text("战情与人物").font(.system(size: 11, weight: .bold))
                            Image(systemName: "chevron.right")
                        }.foregroundStyle(FlightStyle.cyan).padding(.vertical, 11)
                    }.accessibilityIdentifier("open-dossier")
                    HStack(spacing: 12) {
                        Button { tab = 1 } label: {
                            VStack(spacing: 4) {
                                ModelPreview(content: .aircraft).frame(width: 42, height: 36)
                                Text("整备机库").font(.system(size: 10, weight: .heavy))
                            }.foregroundStyle(.white).frame(width: 80, height: 67)
                                .background(LinearGradient(colors: [Color(white: 0.25), Color(white: 0.09)], startPoint: .top, endPoint: .bottom), in: BeveledPanel())
                                .overlay(BeveledPanel().stroke(.white.opacity(0.25), lineWidth: 1))
                        }.accessibilityIdentifier("open-hangar")
                        Button { start(mission) } label: {
                            HStack(spacing: 16) {
                                Text("出  击").font(.system(size: 26, weight: .black))
                                Image(systemName: "chevron.right.2").font(.system(size: 18, weight: .black))
                            }.frame(height: 33)
                        }.buttonStyle(FlightButtonStyle(primary: true))
                            .disabled(!store.unlocked(mission.id) || transfer != nil).accessibilityIdentifier("launch-mission")
                    }
                }.padding(.horizontal, 22).padding(.bottom, 18)
            }
            .overlay(alignment: .top) {
                VStack(alignment: .leading, spacing: 13) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("苍穹突击").font(.system(size: 34, weight: .black)).tracking(5)
                                .shadow(color: .black.opacity(0.8), radius: 5, y: 3)
                            Text("E A G L E   F O R C E").font(.system(size: 9, weight: .heavy)).foregroundStyle(FlightStyle.orange)
                        }
                        Spacer()
                        Button { tab = 2 } label: {
                            Image(systemName: "gearshape.fill").font(.system(size: 21)).foregroundStyle(.white)
                                .frame(width: 48, height: 48).background(.black.opacity(0.55), in: BeveledPanel())
                                .overlay(BeveledPanel().stroke(.white.opacity(0.2), lineWidth: 1))
                        }.accessibilityLabel("设置与飞行档案").accessibilityIdentifier("open-profile")
                    }
                    HStack {
                        Text("破晓防线  ·  \(store.pilot.medalCount)/15 ★")
                            .font(.system(size: 11, weight: .bold)).foregroundStyle(.white.opacity(0.8))
                        Spacer()
                        wallet
                    }
                }.padding(.horizontal, 22).padding(.top, 12)
            }
        }
    }

    private func flightPoint(from a: CGPoint, to b: CGPoint, t: Double) -> CGPoint {
        let u = 1 - t
        return CGPoint(x: u * u * u * a.x + 3 * u * u * t * a.x + 3 * u * t * t * b.x + t * t * t * b.x,
                       y: u * u * u * a.y + 3 * u * u * t * (b.y + 30) + 3 * u * t * t * (a.y - 30) + t * t * t * b.y)
    }

    private func mapNode(_ mission: Mission) -> some View {
        let unlocked = store.unlocked(mission.id)
        let active = highlightedMissionID == mission.id
        let medals = store.pilot.medals[mission.id, default: []].count
        return Button { highlightedMissionID = mission.id } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle().fill(.black.opacity(0.4)).frame(width: 58, height: 58).offset(y: 4)
                    Circle().fill(LinearGradient(colors: [Color(white: active ? 0.66 : 0.4), Color(white: 0.12)], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 52, height: 52)
                    Circle().fill(FlightStyle.ink).frame(width: 43, height: 43)
                    Circle().stroke(active ? FlightStyle.orange : .white.opacity(0.4), lineWidth: active ? 3 : 1).frame(width: 49, height: 49)
                    if unlocked {
                        Text(String(format: "%02d", mission.id)).font(.system(size: 22, weight: .black, design: .rounded)).foregroundStyle(active ? FlightStyle.orange : .white)
                    } else {
                        Image(systemName: "lock.fill").font(.system(size: 17)).foregroundStyle(FlightStyle.muted)
                    }
                }
                HStack(spacing: 3) {
                    ForEach(0..<3) { index in Image(systemName: "star.fill").font(.system(size: 9)).foregroundStyle(index < medals ? FlightStyle.orange : .white.opacity(0.35)) }
                }.padding(.horizontal, 7).padding(.vertical, 3).background(.black.opacity(0.6), in: Capsule())
            }.frame(width: 74, height: 82)
        }.buttonStyle(.plain).disabled(!unlocked || transfer != nil)
            .accessibilityLabel("第 \(mission.id) 关，\(mission.title)，\(unlocked ? "已解锁" : "未解锁")")
            .accessibilityIdentifier("mission-\(mission.id)")
    }

    private var hangar: some View {
        Group {
            HStack(alignment: .firstTextBaseline) {
                Text("整备机库").font(.system(size: 22, weight: .heavy))
                Spacer()
                Text("EF–01 / DAWN").font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(2).foregroundStyle(FlightStyle.muted)
            }
            ZStack {
                ModelPreview(content: .hangar)
                VStack {
                    HStack { Text("01  /  拂晓截击机"); Spacer(); Text("● READY").foregroundStyle(FlightStyle.cyan) }
                    Spacer()
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 4) { Text("机炮 MK.\(store.pilot.loadout.weapon + 1)"); Text("装甲 \(Int(store.pilot.loadout.maxHealth))") }
                        Spacer()
                        Text("整备完成 / 可出击").foregroundStyle(FlightStyle.cyan)
                    }
                }.font(.system(size: 9, weight: .semibold, design: .monospaced)).foregroundStyle(FlightStyle.muted).padding(13)
            }.frame(height: 235)
                .overlay(alignment: .bottom) { Rectangle().fill(FlightStyle.cyan.opacity(0.45)).frame(height: 1) }
            ForEach(Upgrade.allCases, id: \.self) { upgrade in
                let level = store.pilot.loadout[upgrade]
                HStack(spacing: 13) {
                    Image(systemName: upgrade == .weapon ? "scope" : upgrade == .armor ? "shield.lefthalf.filled" : "dot.radiowaves.left.and.right")
                        .font(.system(size: 22, weight: .light)).foregroundStyle(FlightStyle.cyan).frame(width: 30)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(upgrade.title).font(.system(size: 13, weight: .bold))
                            Text("LV. \(level) / 4").font(.system(size: 9, weight: .medium, design: .monospaced)).foregroundStyle(FlightStyle.muted)
                        }
                        HStack(spacing: 3) {
                            ForEach(0..<4) { index in Rectangle().fill(index < level ? FlightStyle.cyan : .white.opacity(0.12)).frame(width: 26, height: 3) }
                        }
                        Text(upgrade.detail).font(.system(size: 9)).foregroundStyle(FlightStyle.muted).lineLimit(2)
                    }
                    Spacer(minLength: 0)
                    Button { store.purchase(upgrade) } label: {
                        VStack(spacing: 4) {
                            Text(level < 4 ? "改装 ↑" : "已满级").font(.system(size: 11, weight: .heavy))
                            if level < 4 { Text("◆ \(Upgrade.prices[level])").font(.system(size: 11, weight: .bold, design: .monospaced)) }
                        }.foregroundStyle(FlightStyle.orange).frame(width: 64, height: 52)
                            .background(FlightStyle.orange.opacity(0.08), in: BeveledPanel())
                            .overlay(BeveledPanel().stroke(FlightStyle.orange.opacity(0.4), lineWidth: 1))
                    }.disabled(level >= 4 || store.pilot.crystals < Upgrade.prices[min(level, 3)])
                        .opacity(level < 4 && store.pilot.crystals >= Upgrade.prices[min(level, 3)] ? 1 : 0.4)
                        .accessibilityLabel("\(upgrade.title)，\(level < 4 ? String(Upgrade.prices[level]) + " 星晶" : "已满级")")
                        .accessibilityIdentifier("upgrade-\(upgrade.rawValue)")
                }.padding(.vertical, 9).overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(0.1)).frame(height: 1) }
            }
        }
    }

    private var profile: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("飞行档案").font(.system(size: 30, weight: .bold))
            HStack(spacing: 24) {
                stat("\(store.pilot.medals.values.filter { $0.contains("clear") }.count) / 5", "战区解放")
                stat("\(store.pilot.medalCount) / 15", "挑战勋章")
            }.padding(24).frame(maxWidth: .infinity).background(FlightStyle.panel, in: BeveledPanel()).overlay(BeveledPanel().stroke(.white.opacity(0.1), lineWidth: 1))
            VStack(spacing: 20) {
                Toggle("全局音乐与音效", isOn: Binding(get: { store.pilot.sound }, set: { store.set(\.sound, to: $0) }))
                    .accessibilityIdentifier("audio-toggle")
                Text(FlightMusic.shared.playing ? "背景音乐播放中" : "背景音乐已暂停")
                    .font(.caption).foregroundStyle(FlightStyle.muted).accessibilityIdentifier("music-status")
                Toggle("林汐语音支援", isOn: Binding(get: { store.pilot.voiceSupport }, set: { store.set(\.voiceSupport, to: $0) }))
                    .accessibilityIdentifier("voice-toggle")
                Text("语音独立控制，字幕始终保留").font(.caption).foregroundStyle(FlightStyle.muted)
                Toggle("触感反馈", isOn: Binding(get: { store.pilot.haptics }, set: { store.set(\.haptics, to: $0) }))
                Toggle("降低动态效果", isOn: Binding(get: { store.pilot.reducedEffects }, set: { store.set(\.reducedEffects, to: $0) }))
            }.tint(FlightStyle.cyan).padding(22).background(FlightStyle.panel, in: BeveledPanel()).overlay(BeveledPanel().stroke(.white.opacity(0.1), lineWidth: 1))
            VStack(alignment: .leading, spacing: 12) {
                Text("飞行手册").font(.headline)
                Text("① 拖动任意位置，战机自动开火；右上角切换 1× / 1.5× / 2×。\n② 靠近金色 SOS 人形信标救援，提示箭头指向飞行员。\n③ EMP 清弹并短暂无敌，每关初始 2 次。\n④ 橙色箱火力过载 · 青色箱护盾 · 绿色十字维修。\n⑤ 高塔有耐久条；受损目标冒烟，重伤起火。\n⑥ 手机始终竖屏；横向关卡沿弯曲峡道向右飞行，避开上下岩壁。\n⑦ 通关、全救援、护甲 ≥60% 各获一枚勋章。\n⑧ 激光贯穿直线目标，散弹扇射，雷电最多连锁 3 个目标；拾取切换武器并刷新 12 秒，过载仍可叠加。\n⑨ 蓝色飞机补给增加护航机，本次出击最多 3 架，满编再拾取获得 60 水晶。").font(.system(size: 13)).lineSpacing(9).foregroundStyle(FlightStyle.muted)
            }.padding(22).frame(maxWidth: .infinity, alignment: .leading).background(FlightStyle.panel, in: BeveledPanel()).overlay(BeveledPanel().stroke(.white.opacity(0.1), lineWidth: 1))
            Text("离线飞行 · 本机存档\n无广告、无追踪、无体力等待。删除 App 会移除本机进度。").font(.system(size: 11)).lineSpacing(5).foregroundStyle(FlightStyle.muted)
            Text("EAGLE FORCE  /  0.1.0").font(.system(size: 10, weight: .medium, design: .monospaced)).tracking(2).foregroundStyle(FlightStyle.muted.opacity(0.6))
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func stat(_ number: String, _ title: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(number).font(.system(size: 26, weight: .bold, design: .rounded)).foregroundStyle(FlightStyle.cyan)
            Text(title).font(.system(size: 12)).foregroundStyle(FlightStyle.muted)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }


}

struct BeveledPanel: Shape {
    func path(in rect: CGRect) -> Path {
        let cut: CGFloat = 10
        return Path { p in
            p.move(to: CGPoint(x: cut, y: 0))
            p.addLine(to: CGPoint(x: rect.maxX, y: 0))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cut))
            p.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.maxY))
            p.addLine(to: CGPoint(x: 0, y: rect.maxY))
            p.addLine(to: CGPoint(x: 0, y: cut))
            p.closeSubpath()
        }
    }
}
