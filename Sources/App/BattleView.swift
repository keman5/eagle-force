import SwiftUI
import SpriteKit
import SceneKit

// SceneKit renders the entire world; the empty SpriteKit surface only drives time and touch coordinates.
final class BattleCanvas: UIView {
    private let battle: BattleScene
    let combat = SKView()
    let terrain = SCNView()

    init(scene: BattleScene) {
        battle = scene
        super.init(frame: .zero)
        backgroundColor = UIColor(hex: 0x071323)
        combat.allowsTransparency = true
        combat.backgroundColor = .clear
        combat.ignoresSiblingOrder = true
        combat.preferredFramesPerSecond = 60
        combat.isMultipleTouchEnabled = false
        combat.accessibilityIdentifier = "battle-surface"
        combat.presentScene(scene)
        terrain.scene = scene.terrainScene?.scene
        terrain.pointOfView = scene.terrainScene?.camera
        terrain.backgroundColor = .clear
        terrain.autoenablesDefaultLighting = false
        terrain.antialiasingMode = .multisampling2X
        terrain.preferredFramesPerSecond = 60
        terrain.accessibilityIdentifier = "world-3d"
        terrain.isUserInteractionEnabled = false
        // Only HUD controls belong in AX; transient 3D nodes are removed during every frame.
        terrain.accessibilityElementsHidden = true
        terrain.isPlaying = true
        addSubview(terrain)
        addSubview(combat)
        #if DEBUG
        scene.validateProjection = { [weak self] in self?.validateProjection() }
        #endif
    }

    required init?(coder: NSCoder) { fatalError("BattleCanvas is created with a battle") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let scale = min(bounds.width / 390, bounds.height / 780)
        terrain.frame = CGRect(x: (bounds.width - 390 * scale) / 2, y: (bounds.height - 780 * scale) / 2,
                               width: 390 * scale, height: 780 * scale)
        combat.frame = bounds
    }

    #if DEBUG
    private func validateProjection() {
        guard bounds.width > 0, bounds.height > 0, window != nil else { return }
        // SceneKit uses a 1x1 viewport until its first render; retry on the next combat frame.
        let far = terrain.projectPoint(SCNVector3(battle.world.width / 2, battle.world.length / 2, 65))
        guard far.x > 1, far.y > 1 else { return }
        for point in [Vector(x: 50, y: 80), Vector(x: battle.world.width - 50, y: battle.world.length - 80)] {
            let expected = battle.viewPoint(point)
            for height in [-20.0, 65.0, 100.0] {
                let projected = terrain.projectPoint(SCNVector3(point.x, point.y, height))
                let actual = terrain.convert(CGPoint(x: CGFloat(projected.x), y: CGFloat(projected.y)), to: combat)
                assert(hypot(actual.x - expected.x, actual.y - expected.y) < 1, "3D projection and input must agree: \(actual) vs \(expected)")
            }
        }
        combat.isAccessibilityElement = true
        combat.accessibilityValue = "3D projection aligned"
        battle.validateProjection = nil
    }
    #endif
}

struct BattleSurface: UIViewRepresentable {
    let scene: BattleScene
    func makeUIView(context: Context) -> BattleCanvas { BattleCanvas(scene: scene) }
    func updateUIView(_ view: BattleCanvas, context: Context) {}
    static func dismantleUIView(_ view: BattleCanvas, coordinator: ()) {
        view.combat.presentScene(nil)
        view.terrain.isPlaying = false
        view.terrain.scene = nil
    }
}

struct BattleView: View {
    @Bindable var session: BattleSession
    @Bindable var store: PilotStore
    let leave: () -> Void
    @State private var reward: Reward?
    @State private var confirmRetreat = false
    @State private var showRadioLog = false

    var body: some View {
        GeometryReader { geometry in
            let landscape = geometry.size.width > geometry.size.height
            ZStack {
                BattleSurface(scene: session.scene).ignoresSafeArea()
                DamageVignette(strength: session.damageVeil, critical: session.health <= 0.25)
                    .ignoresSafeArea().allowsHitTesting(false)
                    .accessibilityElement().accessibilityLabel(session.health <= 0.25 ? "红色低血量晕影" : "受损晕影")
                    .accessibilityIdentifier("damage-vignette")
                VStack(spacing: 0) {
                    hud(landscape: landscape)
                    if let hint = session.rescueHint {
                        Text(hint).font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color(red: 1, green: 0.9, blue: 0.63))
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .shadow(color: .black, radius: 3)
                            .accessibilityIdentifier("rescue-hint").allowsHitTesting(false)
                    }
                    Spacer()
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 7) {
                            HStack(spacing: 12) {
                                Text(session.weaponStatus).foregroundStyle(FlightStyle.cyan).accessibilityIdentifier("weapon-status")
                                Text("护航 \(session.escortCount)/3").foregroundStyle(.white).accessibilityIdentifier("escort-count")
                            }.font(.system(size: 10, weight: .bold, design: .monospaced))
                            Text(session.status).font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.8))
                            HStack(spacing: 14) {
                                Label("\(session.rescued) / 3", systemImage: "person.fill.checkmark")
                                Label("\(session.crystals)", systemImage: "star.fill").foregroundStyle(FlightStyle.orange)
                            }.font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(FlightStyle.cyan)
                        }
                            .shadow(color: .black, radius: 3).allowsHitTesting(false)
                        Spacer(minLength: 10)
                        Button { session.pulse() } label: {
                            RoundControl(symbol: "bolt.fill", size: 43)
                                .overlay(alignment: .bottomTrailing) {
                                    Text("\(session.empCharges)").font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundStyle(FlightStyle.cyan).offset(x: 3, y: 5)
                                }
                        }.disabled(session.empCharges == 0 || session.paused || session.crashing || session.bossFalling || session.result != nil)
                            .opacity(session.empCharges == 0 ? 0.4 : 1).accessibilityLabel("释放 EMP，剩余 \(session.empCharges) 次").accessibilityIdentifier("emp-button")
                    }.padding(.horizontal, landscape ? 22 : 18).padding(.bottom, 10)
                    if let line = session.radioLine {
                        RadioCard(line: line, compact: true).padding(.horizontal, 18).padding(.bottom, 6)
                            .allowsHitTesting(false)
                    }
                }
                if session.crashing, session.result == nil {
                    VStack(spacing: 7) {
                        Text("MAYDAY / 动力丧失").font(.system(size: 12, weight: .heavy, design: .monospaced)).tracking(3)
                        Text(session.crashImpact ? "撞击爆炸" : "战机坠落中")
                            .font(.system(size: 11, weight: .medium)).accessibilityIdentifier("crash-state")
                    }.foregroundStyle(Color(red: 1, green: 0.56, blue: 0.35))
                        .shadow(color: .black, radius: 5).frame(maxHeight: .infinity, alignment: .top).padding(.top, 110)
                        .allowsHitTesting(false)
                }
                if session.paused { pausePanel }
                if session.bossFalling, session.result == nil {
                    VStack(spacing: 8) {
                        Text("敌舰陨落").font(.system(size: 26, weight: .bold))
                        Text("CORE DESTROYED / 正在确认战区安全")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                    }.foregroundStyle(FlightStyle.orange).padding(20)
                        .background(FlightStyle.ink.opacity(0.78), in: RoundedRectangle(cornerRadius: 14))
                        .accessibilityElement(children: .ignore).accessibilityLabel("敌舰陨落演出中")
                        .accessibilityIdentifier("boss-fall-state").allowsHitTesting(false)
                        .frame(maxHeight: .infinity, alignment: .bottom).padding(.bottom, 220)
                }
                if let result = session.result { resultPanel(result, landscape: landscape) }
            }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onChange(of: session.result?.id) { _, id in
            if id != nil, let result = session.result {
                reward = store.settle(result)
                session.voice.play(RadioLine(id: "debrief", speaker: .linXi, text: result.won ? session.mission.story.victory : "游隼，救援队已接到你。先回基地修整，我会重新分析敌方火力。频道为你保留。", urgent: false))
            }
        }
        .sheet(isPresented: $showRadioLog) { RadioLogView(mission: session.mission, lines: session.radioHistory) }
        .onDisappear { session.voice.stop() }
        .onChange(of: store.pilot.voiceSupport) { _, enabled in session.voice.enabled = enabled }
        .confirmationDialog("撤离会放弃本次未结算奖励", isPresented: $confirmRetreat, titleVisibility: .visible) {
            Button("确认撤离", role: .destructive, action: leave).accessibilityIdentifier("confirm-retreat")
            Button("继续任务", role: .cancel) {}
        }
    }

    private func hud(landscape: Bool) -> some View {
        VStack(spacing: 6) {
            HStack(alignment: .center, spacing: 12) {
                Button { session.cycleSpeed() } label: {
                    Text(session.gameSpeed == 1.5 ? "1.5×" : "\(Int(session.gameSpeed))×")
                        .font(.system(size: 13, weight: .bold, design: .monospaced)).frame(width: 44, height: 44)
                }.foregroundStyle(FlightStyle.cyan).accessibilityIdentifier("game-speed")
                    .accessibilityLabel("游戏速度 \(session.gameSpeed.formatted()) 倍")
                    .disabled(session.paused || session.crashing || session.bossFalling || session.result != nil)
                DigitalReadout(value: session.crystals)
                    .frame(maxWidth: 240).frame(height: 27)
                    .accessibilityElement(children: .ignore).accessibilityLabel("本次星晶 \(session.crystals)")
                Button { session.pause(true) } label: {
                    Image(systemName: "pause.circle.fill").font(.system(size: 27)).frame(width: 44, height: 44)
                }.foregroundStyle(FlightStyle.cyan).accessibilityLabel("暂停").accessibilityIdentifier("pause-button")
            }
            VStack(spacing: 5) {
                ProgressView(value: session.progress).tint(FlightStyle.cyan.opacity(0.8)).scaleEffect(y: 0.4)
                HStack(spacing: 3) {
                    ForEach(0..<20) { index in
                        Rectangle().fill(Double(index) / 20 < session.health ? (session.health <= 0.25 ? Color.red : FlightStyle.cyan.opacity(0.7)) : .black.opacity(0.4))
                    }
                }.frame(height: 3)
                    .accessibilityElement(children: .ignore).accessibilityLabel("机体耐久 \(Int(session.health * 100))%")
                    .accessibilityIdentifier("player-health")
                Text(String(format: "%02d", session.mission.id) + " / " + session.mission.title)
                    .font(.system(size: 9, weight: .medium)).foregroundStyle(.white.opacity(0.5))
                    .accessibilityIdentifier("battle-title")
                if let bossHealth = session.bossHealth {
                    HStack(spacing: 8) {
                        Text(session.mission.boss).font(.system(size: 9, weight: .medium)).foregroundStyle(FlightStyle.orange)
                        ProgressView(value: max(0, bossHealth)).tint(FlightStyle.orange).scaleEffect(y: 0.65)
                    }.accessibilityIdentifier("boss-health")
                }
            }.padding(.horizontal, 68)
        }.padding(.horizontal, 10).padding(.top, 0).padding(.bottom, 7)
            .shadow(color: .black.opacity(0.5), radius: 3)
    }

    private var pausePanel: some View {
        GeometryReader { geo in
            ZStack {
                RadarBackdrop(continents: false).ignoresSafeArea()
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Text("关 \(String(format: "%02d", session.mission.id))").font(.system(size: 30, weight: .light))
                        Text("暂停").font(.system(size: 16, weight: .light))
                    }.foregroundStyle(FlightStyle.orange)
                    Text(session.mission.title).font(.system(size: 13)).foregroundStyle(FlightStyle.muted)
                    Rectangle().fill(FlightStyle.radarLine).frame(height: 1)
                    Label("击败战区指挥官", systemImage: "circle")
                    Label("救援 \(session.rescued) / 3", systemImage: session.rescued >= 3 ? "checkmark.circle" : "circle")
                    Label("机体耐久 \(Int(session.health * 100))%", systemImage: "heart")
                    Rectangle().fill(FlightStyle.radarLine).frame(height: 1)
                    Toggle("林汐语音支援", isOn: Binding(get: { store.pilot.voiceSupport }, set: { store.set(\.voiceSupport, to: $0) }))
                        .tint(FlightStyle.cyan).accessibilityIdentifier("voice-toggle")
                    Text(session.voice.speaking ? "语音通讯中" : "语音已停止").font(.system(size: 10)).accessibilityIdentifier("voice-status")
                    Button { showRadioLog = true } label: {
                        Label("通讯记录与战术", systemImage: "waveform").frame(minHeight: 44)
                    }.foregroundStyle(FlightStyle.cyan).accessibilityIdentifier("open-radio-log")
                }.font(.system(size: 15, weight: .light)).foregroundStyle(FlightStyle.muted)
                    .frame(width: geo.size.width * 0.76)
                    .position(x: geo.size.width * 0.5, y: geo.size.height * 0.40)
                Button { session.pause(false) } label: { LaunchCircle(title: "RESUME", subtitle: "继续飞行") }
                    .accessibilityIdentifier("resume-button")
                    .position(x: geo.size.width * 0.5, y: geo.size.height * 0.86)
                Button { confirmRetreat = true } label: { RoundControl(symbol: "chevron.left.2", size: 44) }
                    .accessibilityLabel("撤离战区").accessibilityIdentifier("retreat-button")
                    .position(x: geo.size.width * 0.16, y: geo.size.height * 0.86)
            }.buttonStyle(.plain)
        }
    }

    private func resultPanel(_ result: SortieResult, landscape: Bool) -> some View {
        ZStack {
            FlightStyle.ink.opacity(0.94).ignoresSafeArea()
            ScrollView {
                VStack(spacing: landscape ? 13 : 23) {
                    Image(systemName: result.won ? "laurel.leading" : "airplane.circle").font(.system(size: landscape ? 32 : 50, weight: .light)).foregroundStyle(result.won ? FlightStyle.orange : FlightStyle.muted)
                    Text(result.won ? "战区已解放" : "整备，再出发").font(.system(size: 30, weight: .bold)).accessibilityIdentifier("result-title")
                    Text(result.won ? session.mission.title + " / MISSION COMPLETE" : "任务未完成 · 保留 25% 局内星晶").font(.system(size: 10, weight: .medium)).tracking(2).foregroundStyle(FlightStyle.muted)
                    RadioCard(line: RadioLine(id: "debrief", speaker: .linXi,
                        text: result.won ? session.mission.story.victory : "游隼，救援队已接到你。先回基地修整，我会重新分析敌方火力。频道为你保留。", urgent: false))
                        .accessibilityIdentifier("story-outcome")
                    HStack(spacing: 30) {
                        medal("通关", symbol: "scope", earned: result.medals.contains("clear"))
                        medal("全员救援", symbol: "person.2.fill", earned: result.medals.contains("rescue"))
                        medal("护甲 ≥60%", symbol: "shield.fill", earned: result.medals.contains("armor"))
                    }
                    if let reward {
                        VStack(spacing: 9) {
                            Text("+\(reward.total)").font(.system(size: 38, weight: .bold, design: .rounded)).foregroundStyle(FlightStyle.orange)
                            Text("战利品 \(reward.loot)  ·  首通 \(reward.firstClear)  ·  新勋章 \(reward.medals)").font(.system(size: 11)).foregroundStyle(FlightStyle.muted)
                            Text("击落 \(result.kills)  ·  救援 \(result.rescued)/3  ·  已保存到飞行档案").font(.system(size: 10)).foregroundStyle(FlightStyle.muted)
                        }
                        Button(result.won && result.missionID < Mission.campaign.count ? "前往下一战区" : "返回基地", action: leave).buttonStyle(FlightButtonStyle(primary: true)).accessibilityIdentifier("return-base")
                    } else {
                        Text("奖励尚未保存，重试成功后返回基地。").font(.system(size: 12)).foregroundStyle(FlightStyle.orange)
                        Button("重试保存") { reward = store.settle(result) }.buttonStyle(FlightButtonStyle(primary: true))
                    }
                }.frame(maxWidth: landscape ? 470 : 340).padding(.vertical, landscape ? 24 : 50).padding(.horizontal, 22).frame(maxWidth: .infinity)
            }
        }
    }

    private func medal(_ title: String, symbol: String, earned: Bool) -> some View {
        VStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 20)).frame(width: 53, height: 53)
                .background(earned ? FlightStyle.orange.opacity(0.12) : .white.opacity(0.04), in: Circle())
                .overlay(Circle().stroke(earned ? FlightStyle.orange.opacity(0.5) : .white.opacity(0.1), lineWidth: 1))
            Text(title).font(.system(size: 10))
        }.foregroundStyle(earned ? FlightStyle.orange : FlightStyle.muted.opacity(0.5))
    }
}

struct DamageVignette: View {
    let strength: Double
    let critical: Bool

    var body: some View {
        Canvas { context, size in
            context.scaleBy(x: size.width, y: size.height)
            let tint = critical ? Color(red: 0.65, green: 0.015, blue: 0.025) : Color(red: 0.12, green: 0.035, blue: 0.025)
            context.fill(Path(CGRect(x: 0, y: 0, width: 1, height: 1)), with: .radialGradient(
                Gradient(stops: [.init(color: .clear, location: 0.65), .init(color: tint.opacity(strength * 0.28), location: 0.85), .init(color: tint.opacity(strength), location: 1)]),
                center: CGPoint(x: 0.5, y: 0.5), startRadius: 0, endRadius: 0.71))
        }
    }
}


/// Seven-segment readout of the actual sortie currency, with no invented score economy.
struct DigitalReadout: View {
    let value: Int
    private let masks = [0x3f, 0x06, 0x5b, 0x4f, 0x66, 0x6d, 0x7d, 0x07, 0x7f, 0x6f]
    var body: some View {
        Canvas { context, size in
            let digits = String(format: "%09d", min(999_999_999, max(0, value))).compactMap { $0.wholeNumberValue }
            let unit = min(size.width / 70, size.height / 9)
            let totalWidth = 70 * unit
            for (index, digit) in digits.enumerated() {
                let x = (size.width - totalWidth) / 2 + CGFloat(index * 7 + index / 3 * 3) * unit
                let segments = [CGRect(x: 1, y: 0, width: 4, height: 1), CGRect(x: 5, y: 1, width: 1, height: 3),
                                CGRect(x: 5, y: 5, width: 1, height: 3), CGRect(x: 1, y: 8, width: 4, height: 1),
                                CGRect(x: 0, y: 5, width: 1, height: 3), CGRect(x: 0, y: 1, width: 1, height: 3),
                                CGRect(x: 1, y: 4, width: 4, height: 1)]
                for (segment, rect) in segments.enumerated() {
                    let r = CGRect(x: x + rect.minX * unit, y: rect.minY * unit, width: rect.width * unit, height: rect.height * unit)
                    context.fill(Path(r), with: .color(.white.opacity(masks[digit] & (1 << segment) != 0 ? 0.65 : 0.04)))
                }
            }
        }
    }
}
