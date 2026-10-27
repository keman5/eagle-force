import SwiftUI

enum FlightStyle {
    static let ink = Color(red: 0.018, green: 0.012, blue: 0.008)
    static let panel = Color(red: 0.075, green: 0.045, blue: 0.025)
    static let cyan = Color(red: 0.02, green: 0.94, blue: 0.93)
    static let muted = Color(red: 0.60, green: 0.40, blue: 0.25)
    static let orange = Color(red: 0.94, green: 0.72, blue: 0.42)
}

struct FlightButtonStyle: ButtonStyle {
    var primary = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .medium))
            .frame(maxWidth: .infinity).padding(.vertical, 17)
            .foregroundStyle(primary ? FlightStyle.cyan : FlightStyle.orange)
            .background(.black.opacity(0.3))
            .overlay(Rectangle().stroke((primary ? FlightStyle.cyan : FlightStyle.muted).opacity(0.7), lineWidth: 1))
            .opacity(configuration.isPressed ? 0.5 : 1)
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
                    campaign.ignoresSafeArea()
                } else if tab == 1 {
                    hangar.ignoresSafeArea()
                } else {
                    VStack(spacing: 0) {
                        header
                        ScrollView {
                            VStack(spacing: tab == 1 ? 12 : 24) {
                                profile
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
        Label("\(store.pilot.crystals)", systemImage: "star.fill")
            .font(.system(size: 22, weight: .semibold, design: .monospaced))
            .foregroundStyle(Color(red: 1, green: 0.88, blue: 0.25))
            .accessibilityIdentifier("wallet")
    }

    private let routePoints: [CGPoint] = [
        CGPoint(x: 0.14, y: 0.25), CGPoint(x: 0.34, y: 0.27),
        CGPoint(x: 0.50, y: 0.17), CGPoint(x: 0.72, y: 0.25), CGPoint(x: 0.51, y: 0.32)
    ]

    private var campaign: some View {
        GeometryReader { geo in
            let mission = Mission.campaign[highlightedMissionID - 1]
            let points = routePoints.map { CGPoint(x: $0.x * geo.size.width, y: $0.y * geo.size.height) }
            ZStack(alignment: .topLeading) {
                RadarBackdrop(continents: true)
                Path { path in
                    path.move(to: points[0])
                    for point in points.dropFirst() { path.addLine(to: point) }
                }.stroke(FlightStyle.muted, lineWidth: 1.5)
                Path { path in
                    path.move(to: points[0])
                    for index in 1..<points.count where store.unlocked(index + 1) { path.addLine(to: points[index]) }
                }.stroke(FlightStyle.cyan, lineWidth: 1.5)
                ForEach(Mission.campaign) { item in
                    mapNode(item).position(points[item.id - 1])
                }
                if let transfer {
                    TimelineView(.animation) { clock in
                        let t = min(1, max(0, clock.date.timeIntervalSince(transfer.started) / 1.8))
                        let a = points[transfer.from - 1], b = points[transfer.to - 1]
                        Image(systemName: "airplane").font(.system(size: 22))
                            .foregroundStyle(FlightStyle.cyan)
                            .rotationEffect(.radians(atan2(b.y - a.y, b.x - a.x)))
                            .position(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
                    }.allowsHitTesting(false).accessibilityLabel("战机飞往第 \(transfer.to) 关")
                        .accessibilityIdentifier("campaign-flight")
                }
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("关").font(.system(size: 27, weight: .light))
                        Text(String(format: "%02d", mission.id)).font(.system(size: 29, weight: .bold, design: .monospaced))
                        Text(mission.title).font(.system(size: 14, weight: .light))
                            .accessibilityIdentifier("selected-mission")
                    }.foregroundStyle(FlightStyle.orange)
                    Text(mission.subtitle).font(.system(size: 11, weight: .medium, design: .monospaced))
                        .tracking(1).foregroundStyle(FlightStyle.muted).padding(.top, 8)
                    Text("新补给 / " + mission.newSupplyTitle)
                        .font(.system(size: 10)).foregroundStyle(FlightStyle.orange).padding(.top, 6)
                    Rectangle().fill(FlightStyle.radarLine).frame(height: 1).padding(.top, 9)
                    HStack(spacing: 12) {
                        Text("首次解放").font(.system(size: 15, weight: .light)).foregroundStyle(FlightStyle.muted)
                        Text(store.pilot.medals[mission.id, default: []].contains("clear") ? "已领取" : "★ +\(mission.firstClear)")
                            .font(.system(size: 20, weight: .semibold, design: .monospaced)).foregroundStyle(FlightStyle.orange)
                        Spacer()
                        Text(mission.axisLabel).font(.system(size: 10)).foregroundStyle(FlightStyle.muted)
                    }.frame(height: geo.size.height * 0.064)
                    Rectangle().fill(FlightStyle.radarLine).frame(height: 1)
                    VStack(alignment: .leading, spacing: 16) {
                        missionObjective("clear", title: "击败战区指挥官", mission: mission)
                        missionObjective("rescue", title: "救回所有飞行员", mission: mission)
                        missionObjective("armor", title: "护甲保持 60% 以上", mission: mission)
                    }.padding(.top, 18).padding(.leading, -32)
                }.frame(width: geo.size.width * 0.78).position(x: geo.size.width * 0.5, y: geo.size.height * 0.524)
                Button { dossier = mission } label: {
                    RoundControl(symbol: "waveform", size: 40)
                }.accessibilityLabel("战情与人物").accessibilityIdentifier("open-dossier")
                    .position(x: geo.size.width * 0.78, y: geo.size.height * 0.805)
                Button { tab = 2 } label: { RoundControl(symbol: "list.bullet", size: 42) }
                    .accessibilityLabel("设置与飞行档案").accessibilityIdentifier("open-profile")
                    .position(x: geo.size.width * 0.16, y: geo.size.height * 0.90)
                Button { start(mission) } label: {
                    LaunchCircle(title: "START", subtitle: "出击 / \(String(format: "%02d", mission.id))", diameter: geo.size.width * 0.39)
                }.buttonStyle(.plain).disabled(!store.unlocked(mission.id) || transfer != nil)
                    .accessibilityLabel("出击，第 \(mission.id) 关").accessibilityIdentifier("launch-mission")
                    .position(x: geo.size.width * 0.5, y: geo.size.height * 0.90)
                Button { tab = 1 } label: { RoundControl(symbol: "airplane", size: 58) }
                    .accessibilityLabel("整备机库").accessibilityIdentifier("open-hangar")
                    .position(x: geo.size.width * 0.84, y: geo.size.height * 0.90)
            }.buttonStyle(.plain)
        }
    }

    private func missionObjective(_ key: String, title: String, mission: Mission) -> some View {
        let earned = store.pilot.medals[mission.id, default: []].contains(key)
        return HStack(spacing: 14) {
            Image(systemName: earned ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 19, weight: .light)).foregroundStyle(earned ? FlightStyle.cyan : FlightStyle.radarLine)
            Text(title).font(.system(size: 15, weight: .light))
        }.foregroundStyle(earned ? FlightStyle.cyan : FlightStyle.muted)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title + (earned ? "，勋章已获得" : "，通关达成 · 首次 +100"))
            .accessibilityIdentifier("objective-\(key)")
    }

    private func mapNode(_ mission: Mission) -> some View {
        let unlocked = store.unlocked(mission.id)
        let active = highlightedMissionID == mission.id
        let tint = unlocked ? FlightStyle.cyan : FlightStyle.orange.opacity(0.75)
        let medals = store.pilot.medals[mission.id, default: []].count
        return Button { highlightedMissionID = mission.id } label: {
            ZStack {
                Circle().fill(active ? tint : FlightStyle.ink).padding(active ? 7 : 3)
                Circle().stroke(tint, lineWidth: 2.5)
                if active { Circle().stroke(tint, lineWidth: 1).padding(5) }
                if unlocked {
                    Text(String(format: "%02d", mission.id))
                        .font(.system(size: 17, weight: .bold, design: .monospaced))
                        .foregroundStyle(active ? FlightStyle.ink : tint)
                } else {
                    Image(systemName: "lock.fill").font(.system(size: 17)).foregroundStyle(tint)
                }
            }.frame(width: 40, height: 40)
                .overlay(alignment: .topTrailing) {
                    HStack(spacing: 3) {
                        ForEach(0..<3) { index in
                            Circle().fill(index < medals ? FlightStyle.orange : .clear)
                                .overlay(Circle().stroke(FlightStyle.muted, lineWidth: 1)).frame(width: 5, height: 5)
                        }
                    }.offset(x: 20, y: -7)
                }.frame(width: 48, height: 48)
        }.disabled(!unlocked || transfer != nil)
            .accessibilityLabel("第 \(mission.id) 关，\(mission.title)，\(unlocked ? "已解锁" : "未解锁")")
            .accessibilityIdentifier("mission-\(mission.id)")
    }

    private var hangar: some View {
        GeometryReader { geo in
            ZStack {
                RadarBackdrop(continents: false)
                AircraftBlueprint().stroke(FlightStyle.radarLine, lineWidth: 1.2)
                    .frame(width: geo.size.width * 0.62, height: geo.size.height * 0.48)
                    .position(x: geo.size.width * 0.08, y: geo.size.height * 0.52)
                Path { path in
                    for y in [0.26, 0.39, 0.52, 0.65, 0.75, 0.85] {
                        path.move(to: CGPoint(x: geo.size.width * 0.08, y: geo.size.height * (0.39 + y * 0.38)))
                        path.addLine(to: CGPoint(x: geo.size.width * 0.32, y: geo.size.height * y))
                        path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height * y))
                    }
                }.stroke(FlightStyle.radarLine, lineWidth: 1)
                Path { path in
                    path.move(to: CGPoint(x: 0, y: geo.size.height * 0.26))
                    path.addLine(to: CGPoint(x: geo.size.width * 0.16, y: geo.size.height * 0.26))
                    path.addLine(to: CGPoint(x: geo.size.width * 0.65, y: 0))
                    path.addEllipse(in: CGRect(x: geo.size.width * 0.20, y: geo.size.height * 0.12, width: geo.size.width * 0.18, height: geo.size.width * 0.18))
                }.stroke(FlightStyle.radarLine, lineWidth: 1)
                if store.pilot.loadout.weapon > 0 {
                    Path { path in
                        let x = geo.size.width * 0.08, y = geo.size.height * 0.40
                        path.addRoundedRect(in: CGRect(x: x - 2, y: y, width: 4, height: geo.size.height * 0.095), cornerSize: CGSize(width: 2, height: 2))
                        path.addRoundedRect(in: CGRect(x: x - 7, y: y + geo.size.height * 0.075, width: 14, height: geo.size.height * 0.035), cornerSize: CGSize(width: 3, height: 3))
                    }.stroke(FlightStyle.orange.opacity(0.9), lineWidth: 1.5).allowsHitTesting(false)
                }
                wallet.position(x: geo.size.width * 0.32, y: geo.size.height * 0.16)
                ForEach(Array(Upgrade.allCases.enumerated()), id: \.element) { index, upgrade in
                    upgradeRow(upgrade).frame(width: geo.size.width * 0.52)
                        .position(x: geo.size.width * 0.735, y: geo.size.height * (0.26 + Double(index) * 0.13))
                }
                ForEach(Array([("激光 / 散弹 / 雷电", "战场拾取 · 持续 12 秒"), ("能量护盾", "青色补给 · 抵挡一次伤害"), ("EMP 脉冲", "每次出击 2 次 · 救援补充")].enumerated()), id: \.offset) { index, item in
                    VStack(alignment: .trailing, spacing: 8) {
                        Text(item.0).font(.system(size: 14, weight: .light)).foregroundStyle(FlightStyle.muted)
                        Capsule().fill(FlightStyle.radarLine).frame(height: 9)
                            .overlay(alignment: .leading) { Circle().fill(.black).overlay(Circle().stroke(FlightStyle.radarLine, lineWidth: 2)).frame(width: 18, height: 18) }
                        Text(item.1).font(.system(size: 9)).foregroundStyle(FlightStyle.muted)
                    }.frame(width: geo.size.width * 0.34)
                        .position(x: geo.size.width * 0.66, y: geo.size.height * (0.65 + Double(index) * 0.10) - 1)
                }
                Button { tab = 0 } label: { RoundControl(symbol: "chevron.left.2", size: 58) }
                    .accessibilityLabel("返回战区").accessibilityIdentifier("return-map")
                    .position(x: geo.size.width * 0.16, y: geo.size.height * 0.90)
            }.buttonStyle(.plain)
        }
    }

    private func upgradeRow(_ upgrade: Upgrade) -> some View {
        let level = store.pilot.loadout[upgrade]
        let affordable = level < 4 && store.pilot.crystals >= Upgrade.prices[min(level, 3)]
        return HStack(spacing: 14) {
            VStack(alignment: .trailing, spacing: 7) {
                Text(upgrade.title).font(.system(size: 14, weight: .light)).foregroundStyle(FlightStyle.orange)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().stroke(FlightStyle.orange, lineWidth: 1.5)
                        HStack(spacing: 2) {
                            ForEach(0..<12) { index in
                                Parallelogram().fill(index < level * 3 ? FlightStyle.orange : FlightStyle.orange.opacity(0.08))
                                    .overlay(Parallelogram().stroke(FlightStyle.orange.opacity(0.6), lineWidth: 0.7))
                            }
                        }.padding(.horizontal, 5).padding(.vertical, 2)
                        Circle().fill(FlightStyle.ink).overlay(Circle().stroke(FlightStyle.orange, lineWidth: 2))
                            .frame(width: 18, height: 18).offset(x: -8)
                    }.frame(width: geo.size.width, height: 10)
                }.frame(height: 10)
                HStack(spacing: 3) {
                    Text("LV. \(level) / 4").font(.system(size: 8, design: .monospaced)).foregroundStyle(FlightStyle.muted)
                    Spacer(minLength: 0)
                    Text(level < 4 ? "\(Upgrade.prices[level]) ★" : "MAX")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(affordable ? FlightStyle.orange : FlightStyle.muted)
                }
            }
            Button { store.purchase(upgrade) } label: {
                RoundControl(symbol: level < 4 ? "chevron.up.2" : "checkmark", size: 39,
                             tint: affordable ? FlightStyle.cyan : FlightStyle.radarLine)
            }.disabled(!affordable)
                .accessibilityLabel("\(upgrade.title)，\(level < 4 ? String(Upgrade.prices[level]) + " 星晶" : "已满级")")
                .accessibilityHint(upgrade.detail).accessibilityIdentifier("upgrade-\(upgrade.rawValue)")
        }.padding(.trailing, 7)
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


extension FlightStyle {
    static let radarLine = Color(red: 0.35, green: 0.12, blue: 0.035)
}

struct RoundControl: View {
    let symbol: String
    var size: CGFloat = 44
    var tint: Color = FlightStyle.cyan
    var body: some View {
        Image(systemName: symbol).font(.system(size: size * 0.42, weight: .bold))
            .foregroundStyle(tint).frame(width: size, height: size)
            .background(.black.opacity(0.5), in: Circle())
            .overlay(Circle().stroke(tint, lineWidth: 2.5))
            .shadow(color: tint.opacity(0.2), radius: 3)
            .frame(minWidth: 44, minHeight: 44).contentShape(Circle())
    }
}

struct LaunchCircle: View {
    let title: String
    let subtitle: String
    var diameter: CGFloat = 155
    var body: some View {
        ZStack {
            Circle().strokeBorder(FlightStyle.cyan, lineWidth: 7)
                .mask(LinearGradient(stops: [.init(color: .white, location: 0), .init(color: .white, location: 0.5), .init(color: .clear, location: 0.80)], startPoint: .top, endPoint: .bottom))
            VStack(spacing: 7) {
                Text(subtitle).font(.system(size: 12, weight: .medium)).foregroundStyle(FlightStyle.muted)
                Text(title).font(.system(size: 27, weight: .bold, design: .monospaced)).foregroundStyle(FlightStyle.cyan)
            }
        }.frame(width: diameter, height: diameter).contentShape(Circle())
    }
}

struct Parallelogram: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: 0, y: 0)); p.addLine(to: CGPoint(x: rect.width * 0.72, y: 0))
            p.addLine(to: CGPoint(x: rect.width, y: rect.height)); p.addLine(to: CGPoint(x: rect.width * 0.28, y: rect.height)); p.closeSubpath()
        }
    }
}

struct RadarBackdrop: View {
    var continents = false
    var body: some View {
        Canvas { context, size in
            let bounds = CGRect(origin: .zero, size: size)
            context.fill(Path(bounds), with: .color(.black))
            context.fill(Path(bounds), with: .radialGradient(Gradient(colors: [Color(red: 0.24, green: 0.11, blue: 0.012), .clear]), center: CGPoint(x: size.width * 0.52, y: size.height * 0.13), startRadius: 0, endRadius: size.height * 0.49))
            if continents {
                // Original coastline coordinates; the reference is used for composition only.
                let land: [[CGPoint]] = [
                    [CGPoint(x: -0.08,y: 0.12),CGPoint(x: 0.02,y: 0.09),CGPoint(x: 0.08,y: 0.12),CGPoint(x: 0.06,y: 0.17),CGPoint(x: 0.12,y: 0.20),CGPoint(x: 0.08,y: 0.22),CGPoint(x: 0.19,y: 0.18),CGPoint(x: 0.28,y: 0.19),CGPoint(x: 0.36,y: 0.15),CGPoint(x: 0.44,y: 0.16),CGPoint(x: 0.43,y: 0.12),CGPoint(x: 0.54,y: 0.10),CGPoint(x: 0.65,y: 0.07),CGPoint(x: 0.69,y: 0.045),CGPoint(x: 0.75,y: 0.05),CGPoint(x: 0.73,y: 0.09),CGPoint(x: 0.66,y: 0.13),CGPoint(x: 0.72,y: 0.16),CGPoint(x: 0.67,y: 0.18),CGPoint(x: 0.72,y: 0.22),CGPoint(x: 0.68,y: 0.27),CGPoint(x: 0.59,y: 0.28),CGPoint(x: 0.60,y: 0.33),CGPoint(x: 0.56,y: 0.37),CGPoint(x: 0.48,y: 0.38),CGPoint(x: 0.45,y: 0.34),CGPoint(x: 0.42,y: 0.31),CGPoint(x: 0.46,y: 0.28),CGPoint(x: 0.38,y: 0.26),CGPoint(x: 0.32,y: 0.28),CGPoint(x: 0.27,y: 0.32),CGPoint(x: 0.21,y: 0.31),CGPoint(x: 0.19,y: 0.36),CGPoint(x: 0.13,y: 0.34),CGPoint(x: 0.08,y: 0.39),CGPoint(x: -0.05,y: 0.38)],
                    [CGPoint(x: 0.73,y: 0.11),CGPoint(x: 0.79,y: 0.07),CGPoint(x: 0.88,y: 0.08),CGPoint(x: 0.91,y: 0.04),CGPoint(x: 1.1,y: 0.06),CGPoint(x: 1.1,y: 0.36),CGPoint(x: 0.95,y: 0.33),CGPoint(x: 0.91,y: 0.30),CGPoint(x: 0.87,y: 0.31),CGPoint(x: 0.82,y: 0.27),CGPoint(x: 0.87,y: 0.24),CGPoint(x: 0.84,y: 0.21),CGPoint(x: 0.79,y: 0.22),CGPoint(x: 0.77,y: 0.18)],
                    [CGPoint(x: 0.28,y: 0.10),CGPoint(x: 0.34,y: 0.09),CGPoint(x: 0.39,y: 0.11),CGPoint(x: 0.35,y: 0.14),CGPoint(x: 0.30,y: 0.13)]
                ]
                for coast in land {
                    let path = Path { p in
                        p.move(to: CGPoint(x: coast[0].x * size.width, y: coast[0].y * size.height))
                        for index in coast.indices {
                            let a = CGPoint(x: coast[index].x * size.width, y: coast[index].y * size.height)
                            let b = CGPoint(x: coast[(index + 1) % coast.count].x * size.width, y: coast[(index + 1) % coast.count].y * size.height)
                            let dx = b.x - a.x, dy = b.y - a.y, length = max(1, hypot(dx, dy))
                            let steps = max(3, Int(length / 3))
                            for step in 1...steps {
                                let t = Double(step) / Double(steps)
                                let ripple = sin(t * .pi) * (sin(t * 19 + Double(index) * 2.7) + sin(t * 43 + Double(index))) * size.width * 0.004
                                p.addLine(to: CGPoint(x: a.x + dx * t - dy / length * ripple,
                                                     y: a.y + dy * t + dx / length * ripple))
                            }
                        }
                        p.closeSubpath()
                    }
                    context.fill(path, with: .linearGradient(Gradient(colors: [Color(red: 0.34, green: 0.19, blue: 0.015), Color(red: 0.14, green: 0.075, blue: 0.008)]), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height * 0.42)))
                }
                var grid = Path()
                let step = size.width / 8.6
                for x in stride(from: step * 0.55, through: size.width, by: step) { grid.move(to: CGPoint(x: x, y: 0)); grid.addLine(to: CGPoint(x: x, y: size.height)) }
                for y in stride(from: step * 0.7, through: size.height, by: step) { grid.move(to: CGPoint(x: 0, y: y)); grid.addLine(to: CGPoint(x: size.width, y: y)) }
                context.stroke(grid, with: .linearGradient(Gradient(stops: [.init(color: FlightStyle.radarLine.opacity(0.25), location: 0), .init(color: FlightStyle.radarLine.opacity(0.20), location: 0.85), .init(color: .clear, location: 0.96)]), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)), lineWidth: 1)
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct AircraftBlueprint: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        func line(_ coordinates: [(Double, Double)], closed: Bool = false) {
            for (i, pt) in coordinates.enumerated() {
                let point = CGPoint(x: pt.0 * rect.width, y: pt.1 * rect.height)
                if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            if closed { path.closeSubpath() }
        }
        line([(0.5,0.01),(0.55,0.04),(0.59,0.29),(0.94,0.57),(0.98,0.72),(0.63,0.61),(0.63,0.83),(0.77,0.93),(0.77,0.99),(0.51,0.94),(0.23,0.99),(0.23,0.93),(0.37,0.83),(0.37,0.61),(0.02,0.72),(0.06,0.57),(0.41,0.29),(0.45,0.04)], closed: true)
        line([(0.5,0.06),(0.53,0.18),(0.54,0.43),(0.46,0.43),(0.47,0.18)], closed: true)
        line([(0.48,0.20),(0.52,0.20),(0.54,0.34),(0.46,0.34)], closed: true)
        for flip in [false, true] {
            func mirror(_ points: [(Double,Double)], closed: Bool = false) { line(points.map { (flip ? 1-$0.0 : $0.0, $0.1) }, closed: closed) }
            mirror([(0.39,0.39),(0.10,0.60),(0.09,0.66),(0.37,0.56)], closed: true)
            mirror([(0.30,0.47),(0.30,0.80),(0.34,0.88),(0.40,0.88),(0.43,0.78),(0.43,0.47)], closed: true)
            mirror([(0.33,0.52),(0.39,0.52),(0.39,0.79),(0.33,0.79)], closed: true)
            mirror([(0.32,0.83),(0.41,0.83)])
            mirror([(0.37,0.87),(0.29,0.94),(0.46,0.91)])
            mirror([(0.17,0.52),(0.17,0.39),(0.20,0.39),(0.20,0.55)])
        }
        line([(0.48,0.48),(0.52,0.48),(0.55,0.82),(0.50,0.89),(0.45,0.82)], closed: true)
        return path
    }
}
