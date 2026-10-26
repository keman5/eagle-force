import Foundation

struct Vector: Equatable, Sendable {
    var x: Double
    var y: Double
    static let zero = Vector(x: 0, y: 0)
    static func + (lhs: Self, rhs: Self) -> Self { Self(x: lhs.x + rhs.x, y: lhs.y + rhs.y) }
    static func - (lhs: Self, rhs: Self) -> Self { Self(x: lhs.x - rhs.x, y: lhs.y - rhs.y) }
    static func * (lhs: Self, rhs: Double) -> Self { Self(x: lhs.x * rhs, y: lhs.y * rhs) }
    var length: Double { hypot(x, y) }
    var unit: Self { length > 0 ? self * (1 / length) : Vector(x: 0, y: -1) }
    func direction(on axis: FlightAxis) -> String {
        let angle = axis == .vertical ? atan2(y, x) : atan2(-x, y)
        let octant = (Int((angle / (.pi / 4)).rounded()) + 8) % 8
        return ["→", "↗", "↑", "↖", "←", "↙", "↓", "↘"][octant]
    }
}

enum EntityKind: String, Sendable {
    case scout, armored, boss, bolt, hostile, crystal, rescue, repair, shield, power, obstacle
    case laser, spread, lightning, escort
    var isEnemy: Bool { self == .scout || self == .armored || self == .boss }
    var isPickup: Bool { [.crystal, .rescue, .repair, .shield, .power, .laser, .spread, .lightning, .escort].contains(self) }
    var radius: Double { switch self {
    case .obstacle: 32
    case .boss: 57
    case .armored: 23
    case .scout: 18
    case .hostile: 5
    case .bolt: 4
    default: 15
    } }
}

enum PrimaryWeapon: String, CaseIterable, Sendable {
    case cannon, laser, spread, lightning
    var title: String { switch self {
    case .cannon: "机炮"
    case .laser: "贯穿激光"
    case .spread: "扇形散弹"
    case .lightning: "连锁雷电"
    } }
}

enum ProjectileStyle: Sendable { case cannon, spread, escort }

enum ObstacleSize: Int, CaseIterable, Sendable {
    case small, medium, large
    var radius: Double { [22, 32, 44][rawValue] }
    var durability: Double { [44, 88, 154][rawValue] }
}

struct Entity: Identifiable, Sendable {
    let id: Int
    let kind: EntityKind
    var position: Vector
    var velocity: Vector
    var hp: Double
    var maxHP: Double
    var age = 0.0
    var fireAt = 1.4
    var originX: Double
    var formation: Formation?
    var motionPhase = 0.0
    var damage = 0.0
    var projectileStyle: ProjectileStyle = .cannon
    var obstacleSize: ObstacleSize = .medium
    var lastHitAt = -Double.infinity
    var volleys = 0
    var radius: Double { kind == .obstacle ? obstacleSize.radius : kind.radius }
}

struct DangerLane: Identifiable, Sendable {
    let id: Int
    let x: Double
    var age = 0.0
    var active: Bool { age >= 1.4 && age < 2.2 }
}

enum BattleEffect: Sendable {
    case explosion(Vector, Bool), pickup(Vector, EntityKind), shot, damage, emp, boss, warning
    case beam(Vector, Vector), lightningArc([Vector]), spreadShot
    case impact(Vector), rubble(Vector, Double), crash, bossShot, laser, rescueBeacon, bossDown(Vector)
}

struct GameWorld {
    let sortieID = UUID()
    let mission: Mission
    let loadout: Loadout
    var width: Double { mission.axis == .vertical ? 390 : 780 }
    var length: Double { mission.axis == .vertical ? 780 : 390 }
    var flightScale: Double { mission.axis == .vertical ? 1 : 0.62 }
    var player = Vector(x: 195, y: 130)
    private var steeringTarget: Vector?
    var health: Double
    var shield = false
    var invincibleUntil = 1.8
    var overdriveUntil = 0.0
    private(set) var weapon: PrimaryWeapon = .cannon
    private(set) var weaponUntil = 0.0
    private(set) var escortCount = 0
    var activeWeapon: PrimaryWeapon { elapsed < weaponUntil ? weapon : .cannon }
    var weaponSeconds: Int { max(0, Int(ceil(weaponUntil - elapsed))) }
    var escortPositions: [Vector] {
        (0..<escortCount).map { index in
            let y = min(length - 24, max(18, player.y + (index == 2 ? 58 : -28)))
            let bounds = mission.axis == .horizontal ? corridor(at: y) : 0...width
            let center = min(min(width, bounds.upperBound) - 76, max(max(0, bounds.lowerBound) + 76, player.x))
            return Vector(x: center + [-52.0, 52.0, 0.0][index], y: y)
        }
    }
    var empCharges = 2
    var elapsed = 0.0
    var kills = 0
    var rescued = 0
    var crystals = 0
    var entities: [Entity] = []
    var lanes: [DangerLane] = []
    var effects: [BattleEffect] = []
    var result: SortieResult?
    private(set) var crashTime: Double?
    private(set) var bossFallTime: Double?
    static let bossFallDuration = 5.2
    private(set) var lastDamageAt = -Double.infinity
    private(set) var lastPlayerHitAt = -Double.infinity
    static let crashDuration = 3.4
    private var nextID = 0
    private var nextShot = 0.0
    private var nextEscortShot = 0.0
    private var escortSupplyIndex = 0
    private var nextWave = 0
    private var lastWaveAt = -Double.infinity
    private var reinforcements = 0
    private var rescueIndex = 0
    private var obstacleIndex = 0
    static let groundSpeed = 25.0
    private var bossSpawned = false
    private var nextLaser = 0.0

    init(mission: Mission, loadout: Loadout) {
        self.mission = mission
        self.loadout = loadout
        health = loadout.maxHealth
        player = Vector(x: width / 2, y: mission.axis == .vertical ? 130 : 75)
    }

    var boss: Entity? { entities.first { $0.kind == .boss && $0.hp > 0 } }
    var progress: Double { min(1, elapsed / mission.bossTime) }
    var waveNumber: Int { min(nextWave, mission.waves.count) }

    // A common world-space curve keeps the visible canyon and its collision boundary aligned.
    func corridor(at forward: Double) -> ClosedRange<Double> {
        let distance = elapsed * Self.groundSpeed + forward
        let center = width / 2 + sin(distance * 0.006) * 68 + sin(distance * 0.013) * 26
        return (center - 244)...(center + 244)
    }

    mutating func advance(_ realDelta: Double, speed: Double) {
        guard realDelta.isFinite, realDelta > 0, [1.0, 1.5, 2.0].contains(speed) else { return }
        let duration = min(realDelta, 1.0 / 30) * (bossFallTime == nil ? speed : 1)
        let steps = Int(ceil(duration * 120))
        for _ in 0..<steps { step(duration / Double(steps)) }
    }

    mutating func movePlayer(by delta: Vector) {
        guard result == nil, crashTime == nil, bossFallTime == nil, health > 0 else { return }
        guard delta.x.isFinite, delta.y.isFinite else { return }
        player.x = min(width - 24, max(24, player.x + delta.x))
        player.y = min(length - 70, max(40, player.y + delta.y))
    }

    mutating func steerPlayer(by delta: Vector) {
        guard delta.x.isFinite, delta.y.isFinite else { return }
        var target = (steeringTarget ?? player) + delta
        target.x = min(width - 24, max(24, target.x))
        target.y = min(length - 70, max(40, target.y))
        let offset = target - player
        // Bound queued travel so a fast swipe cannot leave a long flight after the finger stops.
        steeringTarget = player + offset * min(1, 90 / max(0.001, offset.length))
    }

    mutating func updateSteering(_ dt: Double) {
        guard dt.isFinite, dt > 0, let target = steeringTarget else { return }
        let offset = target - player
        let duration = min(dt, 1.0 / 30)
        movePlayer(by: offset * min(1 - exp(-duration / 0.14), 520 * duration / max(0.001, offset.length)))
        if (target - player).length < 0.05 { steeringTarget = nil }
    }

    mutating func stopSteering(immediately: Bool = true) {
        if !immediately, let target = steeringTarget {
            steeringTarget = player + (target - player) * 0.18
        } else { steeringTarget = nil }
    }

    mutating func pulse() {
        guard result == nil, crashTime == nil, bossFallTime == nil, health > 0, empCharges > 0 else { return }
        empCharges -= 1
        invincibleUntil = elapsed + 2
        entities.removeAll { $0.kind == .hostile }
        lanes.removeAll()
        for index in entities.indices where entities[index].kind.isEnemy { entities[index].hp -= 100 }
        effects.append(.emp)
        resolveDestroyed()
    }

    mutating func step(_ delta: Double) {
        guard result == nil, delta.isFinite, delta > 0 else { return }
        let dt = min(delta, 1.0 / 30)
        elapsed += dt
        if let time = bossFallTime {
            bossFallTime = time + dt
            if time + dt >= Self.bossFallDuration { finish(won: true) }
            return
        }
        if let time = crashTime {
            crashTime = time + dt
            if time + dt >= Self.crashDuration { finish(won: false) }
            return
        }
        spawnTimeline()
        if elapsed >= nextShot { firePrimary() }
        if escortCount > 0, elapsed >= nextEscortShot {
            nextEscortShot = elapsed + 0.32
            for point in escortPositions {
                add(.bolt, at: point + Vector(x: 0, y: 18), velocity: Vector(x: 0, y: 610),
                    damage: 5 + Double(loadout.weapon), projectileStyle: .escort)
            }
        }

        var firing: [Entity] = []
        for index in entities.indices {
            entities[index].age += dt
            let kind = entities[index].kind
            if kind == .boss {
                entities[index].position.y = max(length - (mission.axis == .vertical ? 125 : 80), entities[index].position.y - 90 * dt)
                entities[index].position.x = width / 2 + sin(entities[index].age * 0.65) * (mission.axis == .vertical ? 102 : 150)
            } else {
                let distance = (entities[index].position - player).length
                if kind.isPickup && distance < max(kind == .rescue ? 130 : 0, loadout.pickupRadius * 2.5) {
                    entities[index].velocity = (player - entities[index].position).unit * min(560, distance / dt)
                }
                entities[index].position = entities[index].position + entities[index].velocity * dt
                if let formation = entities[index].formation {
                    let age = entities[index].age
                    let phase = entities[index].motionPhase
                    let offset: Double = switch formation {
                    case .arrow, .wall: sin(age * 0.85) * 32
                    case .sweep: sin(age * 0.95) * 64
                    case .weave: (sin(age * 1.65 + phase) - sin(phase)) * 46
                    case .pincer: sin(age * 0.7) * (entities[index].originX < width / 2 ? 82 : -82)
                    }
                    entities[index].position.x = entities[index].originX + offset
                }
            }
            if (kind.isEnemy || kind == .obstacle) && entities[index].hp > 0 && entities[index].age >= entities[index].fireAt && entities[index].position.y < length - 35 && entities[index].position.y > player.y + (kind == .obstacle ? 40 : 0) {
                let enemy = entities[index]
                let interval: Double
                if kind == .boss {
                    // Bursts alternate with readable recovery windows; low health compresses the rhythm.
                    let rhythm = [1.35, 0.48, 0.72, 1.8, 0.6, 1.1, 0.42, 2.0]
                    let beat = (enemy.volleys + mission.id - 1) % rhythm.count
                    interval = (2.5 - Double(mission.id) * 0.18) * rhythm[beat] * (enemy.hp < enemy.maxHP * 0.5 ? 0.82 : 1)
                } else { interval = kind == .obstacle ? 4.5 : 3.4 - Double(mission.id) * 0.12 }
                entities[index].fireAt = enemy.age + interval
                entities[index].volleys += 1
                firing.append(entities[index])
            }
        }
        for enemy in firing { fire(enemy) }

        for index in lanes.indices {
            let wasActive = lanes[index].active
            lanes[index].age += dt
            if !wasActive && lanes[index].active { effects.append(.laser) }
        }
        if lanes.contains(where: { $0.active && abs($0.x - player.x) < 23 }) { hitPlayer(28) }
        if mission.axis == .horizontal && !corridor(at: player.y).contains(player.x) { hitPlayer(12) }
        lanes.removeAll { $0.age >= 2.2 }
        collide()
        resolveDestroyed()
        let maxY = length + 250
        let maxX = width + 100
        entities.removeAll { entity in
            entity.hp <= 0 || entity.position.y < -80 || entity.position.y > maxY || entity.position.x < -100 || entity.position.x > maxX
        }
        if health <= 0 {
            crashTime = 0
            effects.append(.crash)
        }
    }

    mutating func drainEffects() -> [BattleEffect] {
        let pending = effects
        effects.removeAll(keepingCapacity: true)
        return pending
    }

    private mutating func spawnTimeline() {
        let boosted = elapsed < overdriveUntil
        let aircraft = entities.filter { $0.kind.isEnemy && $0.hp > 0 }
        let ahead = aircraft.filter { $0.position.y > player.y + 40 }.count
        let due = nextWave < mission.waves.count && elapsed >= mission.waves[nextWave].time
        let thin = ahead < (boosted ? 3 : 2)
        // Count incoming aircraft too, so an offscreen formation cannot trigger a spawn storm.
        if !bossSpawned, boss == nil, elapsed >= (boosted ? 1 : 4), elapsed < mission.bossTime - 4,
           elapsed - lastWaveAt >= (boosted ? 2 : 4), aircraft.count <= 4, due || thin {
            let authored = nextWave < mission.waves.count
            let wave = mission.waves[authored ? nextWave : reinforcements % mission.waves.count]
            for index in 0..<wave.count {
                let fraction = Double(index + 1) / Double(wave.count + 1)
                let x: Double
                let offset: Double
                switch wave.formation {
                case .arrow: x = 65 + 260 * fraction; offset = abs(fraction - 0.5) * 150
                case .sweep: x = 80 + Double(index) * 55; offset = Double(index) * 48
                case .weave: x = 105 + Double(index) * 55; offset = Double(index) * 42
                case .wall: x = 65 + 260 * fraction; offset = 0
                case .pincer: x = index.isMultiple(of: 2) ? 60 : 330; offset = Double(index / 2) * 75
                }
                let cross = mission.axis == .vertical ? x : width / 2 + (x - 195) * 1.25
                let armored = wave.armored && index.isMultiple(of: 2)
                let hits = min(3, (mission.id + 1 + (armored ? 1 : 0)) / 2)
                add(armored ? .armored : .scout, at: Vector(x: cross, y: length + 12 + min(offset, boosted ? 28 : 90) * flightScale),
                    velocity: Vector(x: 0, y: (-(armored ? 55 : 70) - Double(mission.id) * 4) * flightScale),
                    hp: Double(hits) * 11,
                    formation: wave.formation, motionPhase: Double(index) * 0.8)
            }
            if authored { nextWave += 1 } else { reinforcements += 1 }
            lastWaveAt = elapsed
        }
        let obstacleTimes = [6.0, 37.0, 71.0, 106.0]
        if obstacleIndex < obstacleTimes.count, elapsed >= obstacleTimes[obstacleIndex], elapsed < mission.bossTime - 20 {
            let positions = [136.0, 268.0, 181.0, 110.0]
            let x = positions[(obstacleIndex + mission.id - 1) % positions.count] * width / 390
            let size = ObstacleSize.allCases[(obstacleIndex + mission.id - 1) % 3]
            add(.obstacle, at: Vector(x: x, y: length + 52), velocity: Vector(x: 0, y: -Self.groundSpeed), hp: size.durability, obstacleSize: size)
            obstacleIndex += 1
        }
        let escortTimes = [12.0, 36.0, 60.0, 84.0]
        if escortSupplyIndex < escortTimes.count, elapsed >= escortTimes[escortSupplyIndex], !bossSpawned {
            add(.escort, at: Vector(x: width / 2, y: length - 50), velocity: Vector(x: 0, y: -90 * flightScale))
            escortSupplyIndex += 1
        }
        let rescueTimes = [18.0, 43.0, 70.0]
        if rescueIndex < 3 && elapsed >= rescueTimes[rescueIndex] {
            let x = mission.axis == .vertical ? [80.0, 310.0, 120.0][rescueIndex] : width / 2 + [-100.0, 100.0, -60.0][rescueIndex]
            add(.rescue, at: Vector(x: x, y: length - 45), velocity: Vector(x: 0, y: -24 * flightScale))
            effects.append(.rescueBeacon)
            rescueIndex += 1
        }
        if !bossSpawned && elapsed >= mission.bossTime {
            bossSpawned = true
            nextLaser = elapsed + 5
            add(.boss, at: Vector(x: width / 2, y: length + 70), velocity: .zero, hp: 950 + Double(mission.id) * 220)
            effects.append(.boss)
        }
        if let boss, boss.position.y > player.y, mission.id >= 2, elapsed >= nextLaser {
            let allowsLaser = mission.id == 2 || mission.id == 3 || (mission.id == 5 && boss.hp / boss.maxHP < 0.4)
            if allowsLaser {
                nextID += 1
                lanes.append(DangerLane(id: nextID, x: player.x))
                effects.append(.warning)
            }
            nextLaser = elapsed + 6.5 + Double(boss.volleys % 4) * 0.85
        }
    }

    private mutating func firePrimary() {
        let damage = (11 + Double(loadout.weapon) * 3) * (elapsed < overdriveUntil ? 1.5 : 1)
        let origin = player + Vector(x: 0, y: 24)
        switch activeWeapon {
        case .cannon:
            nextShot = elapsed + max(0.09, 0.19 - Double(loadout.weapon) * 0.018)
            let offsets: [Double] = loadout.weapon >= 2 || elapsed < overdriveUntil ? [-16, 0, 16] : [0]
            for offset in offsets {
                add(.bolt, at: origin + Vector(x: offset, y: 0), velocity: Vector(x: offset * 1.1, y: 650),
                    damage: damage * (offset == 0 ? 1 : 0.55))
            }
            effects.append(.shot)
        case .spread:
            nextShot = elapsed + 0.42
            for pellet in -3...3 {
                let angle = Double(pellet) * 0.14
                add(.bolt, at: origin, velocity: Vector(x: sin(angle), y: cos(angle)) * 590,
                    damage: damage, projectileStyle: .spread)
            }
            effects.append(.spreadShot)
        case .laser:
            nextShot = elapsed + 0.12
            for index in entities.indices where isVisibleTarget(entities[index]) {
                let target = entities[index]
                if target.position.y + target.radius >= origin.y && abs(target.position.x - origin.x) < target.radius + 6 {
                    entities[index].hp -= damage * 0.85
                    entities[index].lastHitAt = elapsed
                    effects.append(.impact(target.position))
                }
            }
            effects.append(.beam(origin, Vector(x: origin.x, y: length)))
        case .lightning:
            nextShot = elapsed + 0.55
            var path = [origin]
            var struck: Set<Int> = []
            for hop in 0..<3 {
                let from = path[path.count - 1]
                let candidates = entities.indices.filter {
                    isVisibleTarget(entities[$0]) && !struck.contains(entities[$0].id)
                        && entities[$0].position.y >= player.y
                        && (entities[$0].position - from).length <= (hop == 0 ? 400 : 145)
                }
                guard let index = candidates.min(by: {
                    (entities[$0].position - from).length < (entities[$1].position - from).length
                }) else { break }
                struck.insert(entities[index].id)
                path.append(entities[index].position)
                entities[index].hp -= damage * 2.4 * pow(0.72, Double(hop))
                entities[index].lastHitAt = elapsed
                effects.append(.impact(entities[index].position))
            }
            // A short discharge shows that the weapon is armed even without a target in range.
            if path.count == 1 { path.append(origin + Vector(x: 0, y: 65)) }
            effects.append(.lightningArc(path))
        }
    }

    private func isVisibleTarget(_ entity: Entity) -> Bool {
        (entity.kind.isEnemy || entity.kind == .obstacle) && entity.hp > 0
            && entity.position.y >= 0 && entity.position.y <= length
            && entity.position.x >= 0 && entity.position.x <= width
    }

    private mutating func fire(_ enemy: Entity) {
        let aim = (player - enemy.position).unit
        if enemy.kind != .boss {
            add(.hostile, at: enemy.position + Vector(x: 0, y: -22), velocity: aim * (90 + Double(mission.id) * 7) * flightScale * 1.5, damage: 18)
            return
        }
        let phase = enemy.hp / enemy.maxHP
        effects.append(.bossShot)
        let speed = (94 + Double(mission.id) * 7 + (phase < 0.5 ? 10 : 0)) * flightScale * 1.5
        let count = [3, 3, 5, 7, 9][mission.id - 1] + (phase < 0.5 ? 2 : 0)
        if mission.id == 4 || (mission.id == 5 && phase < 0.68) {
            for index in 0..<count {
                let angle = Double(index) * 2 * .pi / Double(count) + Double(enemy.volleys) * 0.31
                add(.hostile, at: enemy.position, velocity: Vector(x: cos(angle), y: sin(angle)) * speed, damage: 20)
            }
        } else {
            for index in 0..<count {
                let spacing = enemy.volleys.isMultiple(of: 2) ? 0.23 : 0.3
                let angle = atan2(aim.y, aim.x) + Double(index - count / 2) * spacing
                add(.hostile, at: enemy.position + Vector(x: 0, y: -40), velocity: Vector(x: cos(angle), y: sin(angle)) * speed, damage: 20)
            }
        }
    }

    private mutating func collide() {
        let targets = entities.indices.filter { (entities[$0].kind.isEnemy || entities[$0].kind == .obstacle) && entities[$0].hp > 0 }
        for shot in entities.indices where entities[shot].kind == .bolt && entities[shot].hp > 0 {
            for enemy in targets where entities[enemy].hp > 0 {
                if (entities[shot].position - entities[enemy].position).length < entities[enemy].radius + 5 {
                    let target = entities[enemy].kind
                    let standardShot = entities[shot].projectileStyle == .cannon
                    let damage = standardShot && (target == .scout || target == .armored) ? max(11, entities[shot].damage) : entities[shot].damage
                    entities[enemy].hp -= damage
                    entities[enemy].lastHitAt = elapsed
                    effects.append(.impact(entities[shot].position))
                    entities[shot].hp = 0
                    break
                }
            }
        }
        for index in entities.indices where entities[index].hp > 0 {
            let entity = entities[index]
            let distance = (entity.position - player).length
            if entity.kind == .hostile && distance < 12 {
                entities[index].hp = 0
                hitPlayer(entity.damage)
            } else if (entity.kind.isEnemy || entity.kind == .obstacle) && distance < entity.radius + 8 {
                hitPlayer(25)
            } else if entity.kind.isPickup && distance < 23 && health > 0 {
                entities[index].hp = 0
                switch entity.kind {
                case .crystal: crystals += 15
                case .rescue: rescued += 1; crystals += 40; empCharges = min(3, empCharges + 1)
                case .repair: health = min(loadout.maxHealth, health + 35)
                case .shield: shield = true
                case .power: overdriveUntil = elapsed + 8
                case .laser, .spread, .lightning:
                    weapon = PrimaryWeapon(rawValue: entity.kind.rawValue) ?? .cannon
                    weaponUntil = elapsed + 12
                    nextShot = elapsed
                case .escort:
                    if escortCount < 3 { escortCount += 1 } else { crystals += 60 }
                default: break
                }
                effects.append(.pickup(entity.position, entity.kind))
            }
        }
    }

    private mutating func hitPlayer(_ damage: Double) {
        guard elapsed >= invincibleUntil else { return }
        if shield { shield = false } else {
            health = max(0, health - damage)
            lastDamageAt = elapsed
        }
        lastPlayerHitAt = elapsed
        invincibleUntil = elapsed + 1.25
        effects.append(.damage)
    }

    private mutating func resolveDestroyed() {
        let destroyed = entities.filter { ($0.kind.isEnemy || $0.kind == .obstacle) && $0.hp <= 0 }
        entities.removeAll { ($0.kind.isEnemy || $0.kind == .obstacle) && $0.hp <= 0 }
        for enemy in destroyed {
            if enemy.kind == .obstacle {
                effects.append(.rubble(enemy.position, enemy.radius))
                add(.crystal, at: enemy.position, velocity: Vector(x: 0, y: -Self.groundSpeed))
                continue
            }
            kills += 1
            crystals += enemy.kind == .boss ? 100 : 5
            if enemy.kind == .boss {
                if health > 0 {
                    bossFallTime = 0
                    entities.removeAll()
                    lanes.removeAll()
                    effects.append(.bossDown(enemy.position))
                } else { effects.append(.explosion(enemy.position, true)) }
                return
            }
            effects.append(.explosion(enemy.position, false))
            add(.crystal, at: enemy.position, velocity: Vector(x: 0, y: -44))
            if kills.isMultiple(of: 6) {
                let weapons: [EntityKind] = [.laser, .spread, .lightning]
                add(weapons[(kills / 6 - 1) % weapons.count], at: enemy.position + Vector(x: -23, y: 10), velocity: Vector(x: 0, y: -65))
            }
            if kills.isMultiple(of: 4) {
                let supplies: [EntityKind] = [.power, .repair, .shield]
                add(supplies[(kills / 4 - 1) % supplies.count], at: enemy.position + Vector(x: 23, y: 10), velocity: Vector(x: 0, y: -48))
            }
        }
    }

    private mutating func finish(won: Bool) {
        guard result == nil else { return }
        result = SortieResult(id: sortieID, missionID: mission.id, won: won, crystals: crystals,
                              rescued: rescued, healthFraction: min(1, max(0, health / loadout.maxHealth)), kills: kills)
    }

    private mutating func add(_ kind: EntityKind, at position: Vector, velocity: Vector, hp: Double = 1, formation: Formation? = nil, motionPhase: Double = 0, damage: Double = 0, projectileStyle: ProjectileStyle = .cannon, obstacleSize: ObstacleSize = .medium) {
        nextID += 1
        entities.append(Entity(id: nextID, kind: kind, position: position, velocity: velocity,
                               hp: hp, maxHP: hp, originX: position.x, formation: formation, motionPhase: motionPhase, damage: damage, projectileStyle: projectileStyle, obstacleSize: obstacleSize))
    }
}

struct FlightAttitude {
    private(set) var roll = 0.0
    private(set) var pitch = 0.18

    mutating func update(displacement: Vector, delta: Double) {
        guard delta.isFinite, delta > 0, displacement.x.isFinite, displacement.y.isFinite else { return }
        let response = 1 - exp(-delta / 0.085)
        let lateral = max(-1, min(1, displacement.x / delta / 300))
        let forward = max(-1, min(1, displacement.y / delta / 300))
        roll += (lateral * 0.78 - roll) * response
        pitch += (0.18 + forward * 0.30 - pitch) * response
    }
}
