import Observation
import SpriteKit
import SceneKit
import UIKit

@MainActor @Observable
final class BattleSession {
    let mission: Mission
    @ObservationIgnored let scene: BattleScene
    var health = 1.0
    var damageVeil = 0.0
    var crashing = false
    var bossFalling = false
    var crashImpact = false
    var crystals = 0
    var rescued = 0
    var empCharges = 2
    var progress = 0.0
    var bossHealth: Double?
    var weaponStatus = "机炮"
    var escortCount = 0
    var status = "拖动任意位置移动 · 自动开火"
    var paused = false
    var gameSpeed = 1.0
    var rescueHint: String?
    var result: SortieResult?
    var radioLine: RadioLine?
    var radioHistory: [RadioLine] = []
    let voice: RadioVoice
    @ObservationIgnored private var radio = RadioDirector()

    init(mission: Mission, pilot: PilotProgress) {
        self.mission = mission
        voice = RadioVoice(enabled: pilot.voiceSupport)
        scene = BattleScene(mission: mission, pilot: pilot)
        scene.session = self
    }

    func pause(_ value: Bool) {
        if value { voice.stop() }
        guard result == nil else { return }
        paused = value
        scene.isPaused = value
        scene.terrainScene?.scene.isPaused = value
        scene.lastTime = 0
        if value { scene.audio.stop(); scene.clearTouch() }
        else { voice.play(radioLine) }
    }

    func updateRadio(world: GameWorld, delta: Double) {
        radio.update(world: world, delta: delta)
        if radioLine?.id != radio.current?.id {
            radioLine = radio.current
            radioHistory = radio.history
            voice.play(radioLine)
        }
    }

    func cycleSpeed() {
        guard !paused, result == nil, !crashing, !bossFalling else { return }
        gameSpeed = gameSpeed == 1 ? 1.5 : gameSpeed == 1.5 ? 2 : 1
    }

    func pulse() {
        guard !paused, result == nil else { return }
        scene.world.pulse()
        empCharges = scene.world.empCharges
    }
}

@MainActor
final class BattleScene: SKScene {
    weak var session: BattleSession?
    var world: GameWorld
    let audio = BattleAudio()
    var lastTime = 0.0
    private let field = SKNode()
    private(set) var terrainScene: CombatRenderer?
    private var touchID: UITouch?
    private var lastTouch: CGPoint?
    private var hudTime = 0.0
    #if DEBUG
    private var maximumTestBank = 0.0
    #endif
    private let reducedEffects: Bool
    #if DEBUG
    var validateProjection: (() -> Void)?
    private let testPilot = ProcessInfo.processInfo.arguments.contains("-ui-testing") && ProcessInfo.processInfo.arguments.contains("-autopilot")
    private let damageDemo = ProcessInfo.processInfo.arguments.contains("-ui-testing") && ProcessInfo.processInfo.arguments.contains("-damage-demo")
    private var demoStage = 0
    private var demoCrashRequested = false
    #endif

    init(mission: Mission, pilot: PilotProgress) {
        world = GameWorld(mission: mission, loadout: pilot.loadout)
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing"), ProcessInfo.processInfo.arguments.contains("-shield-demo") {
            world.shield = true
        }
        #endif
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing"), ProcessInfo.processInfo.arguments.contains("-boss-demo") {
            world.invincibleUntil = .infinity
            while world.elapsed < mission.bossTime { world.step(1.0 / 30) }
            _ = world.drainEffects()
        }
        #endif
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing"), ProcessInfo.processInfo.arguments.contains("-flight-demo") {
            world.player = Vector(x: mission.axis == .vertical ? 100 : 300, y: mission.axis == .vertical ? 250 : 95)
        }
        #endif
        reducedEffects = pilot.reducedEffects || UIAccessibility.isReduceMotionEnabled
        super.init(size: CGSize(width: 390, height: 780))
        scaleMode = .aspectFit
        backgroundColor = .clear
        audio.sound = pilot.sound
        audio.haptics = pilot.haptics
    }

    required init?(coder: NSCoder) { fatalError("BattleScene is created with a mission") }

    override func didMove(to view: SKView) {
        guard field.parent == nil else { return }
        addChild(field)
        if world.mission.axis == .horizontal {
            field.zRotation = -.pi / 2
            field.position = CGPoint(x: 0, y: 780)
        }
        terrainScene = CombatRenderer(world: world, reducedEffects: reducedEffects)
        terrainScene?.update(world)
    }

    override func update(_ currentTime: TimeInterval) {
        #if DEBUG
        validateProjection?()
        #endif
        guard session?.paused == false, session?.result == nil else { lastTime = 0; return }
        if lastTime == 0 { lastTime = currentTime; return }
        let radioDelta = currentTime - lastTime
        let dt = min(radioDelta, 1.0 / 30)
        lastTime = currentTime
        let speed = session?.gameSpeed ?? 1
        #if DEBUG
        let flightTest = ProcessInfo.processInfo.arguments.contains("-ui-testing") &&
            ProcessInfo.processInfo.arguments.contains("-flight-test")
        let flightDemo = flightTest && ProcessInfo.processInfo.arguments.contains("-flight-demo")
        if flightTest { world.invincibleUntil = .infinity }
        if flightDemo { world.steerPlayer(by: Vector(x: 360 * dt, y: 150 * dt)) }
        #endif
        world.updateSteering(dt)
        let previousCrashTime = world.crashTime ?? 0
        let previousBossFallTime = world.bossFallTime ?? 0
        #if DEBUG
        if damageDemo { prepareDamageDemo() }
        if ProcessInfo.processInfo.arguments.contains("-ui-testing"), ProcessInfo.processInfo.arguments.contains("-weapon-demo") { prepareWeaponDemo() }
        if testPilot && world.bossFallTime == nil {
            for _ in 0..<8 {
                if world.bossFallTime != nil { break }
                world.invincibleUntil = .infinity
                if let target = world.boss ?? world.entities.first(where: { $0.kind.isEnemy && $0.position.y > world.player.y + 60 }) {
                    world.movePlayer(by: Vector(x: target.position.x - world.player.x, y: 0))
                }
                world.step(dt)
            }
        } else { world.advance(dt, speed: speed) }
        #else
        world.advance(dt, speed: speed)
        #endif
        terrainScene?.update(world, speed: speed, delta: dt)
        #if DEBUG
        if flightTest {
            let bank = terrainScene?.bankAngle ?? 0
            maximumTestBank = max(maximumTestBank, abs(bank))
            view?.accessibilityLabel = String(format: "%.2f,%.2f,%.3f,%.3f", world.player.x, world.player.y, bank, maximumTestBank)
            // Freeze the real steering/render path at mid-turn for reproducible visual review.
            if flightDemo && world.elapsed >= 0.55 {
                isPaused = true; terrainScene?.scene.isPaused = true; audio.stop()
            }
        }
        #endif
        if previousCrashTime < 1.75 && (world.crashTime ?? 0) >= 1.75 || previousBossFallTime < 3.2 && (world.bossFallTime ?? 0) >= 3.2 {
            audio.play("explosion")
        }
        session?.updateRadio(world: world, delta: radioDelta)
        for effect in world.drainEffects() { show(effect) }
        hudTime += dt
        if hudTime >= 0.1 || world.result != nil {
            hudTime = 0
            session?.health = world.health / world.loadout.maxHealth
            session?.crashing = world.crashTime != nil
            session?.bossFalling = world.bossFallTime != nil
            session?.crashImpact = (world.crashTime ?? 0) >= 1.75
            let hitFade = max(0, 1 - (world.elapsed - world.lastDamageAt) / 0.4)
            let wear = 1 - world.health / world.loadout.maxHealth
            session?.damageVeil = min(0.24, (wear > 0.75 ? 0.07 : 0) + hitFade * (reducedEffects ? 0.08 : 0.17))
            session?.weaponStatus = world.activeWeapon.title + (world.activeWeapon == .cannon ? "" : " · \(world.weaponSeconds)s")
            session?.escortCount = world.escortCount
            session?.crystals = world.crystals
            session?.rescued = world.rescued
            session?.empCharges = world.empCharges
            session?.progress = world.progress
            session?.bossHealth = world.boss.map { $0.hp / $0.maxHP }
            if let pilot = world.entities.first(where: { $0.kind == .rescue }) {
                let offset = pilot.position - world.player
                let direction = offset.direction(on: world.mission.axis)
                session?.rescueHint = "\(direction) SOS · 失联飞行员 · 靠近金色信标"
            } else { session?.rescueHint = nil }
            session?.status = if world.bossFallTime != nil { "敌方核心崩解 · 保持安全距离" }
                else if world.crashTime != nil { "失去动力 · 紧急迫降" }
                else if world.health <= world.loadout.maxHealth * 0.25 { "机体严重受损 · 寻找维修补给" }
                else if world.elapsed < 7 { "拖动任意位置移动 · 自动开火" }
                else if !world.lanes.isEmpty { "激光预警 · 离开红色通道" }
                else if world.entities.contains(where: { $0.kind == .obstacle && $0.position.y > 0 && $0.position.y < world.length }) { "地面防御设施 · 集火摧毁或绕行" }
                else if world.overdriveUntil > world.elapsed { "火力过载 · \(Int(ceil(world.overdriveUntil - world.elapsed))) 秒" }
                else if world.shield { "能量护盾已就绪" }
                else if world.boss != nil { "核心接战 · \(world.mission.boss)" }
                else { "第 \(world.waveNumber) / \(world.mission.waves.count) 波 · 搜寻 SOS 信标" }
            session?.result = world.result
            if world.result != nil { audio.stop() }
        }
    }

    private func show(_ effect: BattleEffect) {
        terrainScene?.show(effect, world: world)
        switch effect {
        case .explosion, .rubble, .damage: audio.play("explosion")
        case let .pickup(_, kind): audio.play(kind == .rescue ? "rescue" : kind == .crystal ? "pickup" : "supply")
        case .beam: audio.play("beam", time: world.elapsed)
        case .lightningArc: audio.play("lightning")
        case .spreadShot: audio.play("spread")
        case .shot: audio.play("shot", time: world.elapsed)
        case .emp: audio.play("emp")
        case .boss: audio.play("alarm")
        case .warning: audio.play("warning")
        case .bossShot: audio.play("bossShot")
        case .laser: audio.play("laser")
        case .rescueBeacon: audio.play("beacon")
        case .crash, .bossDown: clearTouch()
        case .impact: break
        }
    }

    #if DEBUG
    // Deterministic collision fixture exercises the same damage and crash path as live combat.
    private func prepareWeaponDemo() {
        guard demoStage == 0 else { return }
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-weapon-demo"), args.indices.contains(index + 1),
              let kind = EntityKind(rawValue: args[index + 1]), [.laser, .spread, .lightning].contains(kind) else { return }
        world.invincibleUntil = .infinity
        // Fixtures enter through the same pickup collisions and damage path as a normal sortie.
        for (index, pickup) in [EntityKind.escort, .escort, .escort, kind].enumerated() {
            world.entities.append(Entity(id: 80_000 + index, kind: pickup, position: world.player, velocity: .zero,
                                         hp: 1, maxHP: 1, originX: world.player.x))
        }
        let targetOffsets = kind == .laser ? [0.0, 0.0, 100.0] : [0.0, 48.0, -48.0]
        for (index, x) in targetOffsets.enumerated() {
            let point = world.player + Vector(x: x, y: (world.mission.axis == .vertical ? 180 : 120) + Double(index) * 62)
            world.entities.append(Entity(id: 80_010 + index, kind: [EntityKind.scout, .armored, .interceptor][index], position: point, velocity: .zero,
                                         hp: 3000, maxHP: 3000, fireAt: 999, originX: point.x))
        }
        for (index, pickup) in [EntityKind.laser, .spread, .lightning, .escort].enumerated() {
            let point = Vector(x: world.width / 2 - 120 + Double(index) * 80,
                               y: world.length - (world.mission.axis == .vertical ? 180 : 55))
            world.entities.append(Entity(id: 80_020 + index, kind: pickup, position: point, velocity: .zero,
                                         hp: 1, maxHP: 1, originX: point.x))
        }
        demoStage = 1
    }

    private func prepareDamageDemo() {
        world.invincibleUntil = .infinity
        if demoStage == 0 {
            let sideways = world.mission.axis == .horizontal
            world.player.x = sideways ? 260 : 150
            world.entities = ObstacleSize.allCases.enumerated().map { index, size in
                let x = sideways ? 160 + Double(index) * 190 : 70 + Double(index) * 125
                return Entity(id: 900 + index, kind: .obstacle, position: Vector(x: x, y: sideways ? 235 : 440), velocity: Vector(x: 0, y: -GameWorld.groundSpeed), hp: size.durability, maxHP: size.durability, originX: x, obstacleSize: size)
            }
            for (index, kind) in [EntityKind.crystal, .repair, .shield, .power, .rescue].enumerated() {
                let x = sideways ? 150 + Double(index) * 95 : 65 + Double(index) * 65
                world.entities.append(Entity(id: 920 + index, kind: kind, position: Vector(x: x, y: sideways ? (kind == .rescue ? 270 : 330) : 580), velocity: .zero, hp: 1, maxHP: 1, originX: x))
            }
            demoStage = 1
        }
        // Keep the critical state observable even when cold shader compilation delays UI automation.
        if (demoStage == 1 && world.elapsed >= 2) || (demoStage == 2 && demoCrashRequested) {
            world.invincibleUntil = 0
            world.entities.append(Entity(id: 950 + demoStage, kind: .hostile, position: world.player, velocity: .zero, hp: 1, maxHP: 1, originX: world.player.x, damage: demoStage == 1 ? 80 : 25))
            demoStage += 1
        }
    }
    #endif

    #if DEBUG
    func viewPoint(_ point: Vector) -> CGPoint {
        convertPoint(toView: field.convert(CGPoint(x: point.x, y: point.y), to: self))
    }
    #endif

    func clearTouch() { touchID = nil; lastTouch = nil; world.stopSteering() }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard touchID == nil, session?.paused == false, let touch = touches.first else { return }
        #if DEBUG
        if damageDemo && demoStage == 2 { demoCrashRequested = true }
        #endif
        world.stopSteering()
        touchID = touch; lastTouch = touch.location(in: field)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touchID, touches.contains(touchID), let previous = lastTouch, session?.paused == false else { return }
        let current = touchID.location(in: field)
        world.steerPlayer(by: Vector(x: current.x - previous.x, y: current.y - previous.y))
        lastTouch = current
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touchID, touches.contains(touchID) {
            self.touchID = nil; lastTouch = nil
            world.stopSteering(immediately: false)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touchID, touches.contains(touchID) { clearTouch() }
    }
}
