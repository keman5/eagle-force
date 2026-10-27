import Foundation
import Testing
@testable import EagleCore

@Test func initialUnlocksAndUpgradeTransaction() {
    var pilot = PilotProgress()
    #expect(pilot.unlocked(1))
    #expect(!pilot.unlocked(2))
    #expect(!pilot.unlocked(0))
    #expect(!pilot.unlocked(6))
    let purchased = pilot.purchase(.weapon)
    #expect(purchased)
    #expect(pilot.crystals == 50)
    #expect(pilot.loadout.weapon == 1)
    let before = pilot
    let insufficient = pilot.purchase(.armor)
    #expect(!insufficient)
    #expect(pilot == before)
    pilot.crystals = 10_000
    for _ in 0..<4 { _ = pilot.purchase(.armor) }
    let maxed = pilot
    let aboveMaximum = pilot.purchase(.armor)
    #expect(!aboveMaximum)
    #expect(pilot == maxed)
}

@Test func rewardsAreIdempotentAndMedalsAreIncremental() throws {
    var pilot = PilotProgress()
    let clear = SortieResult(id: UUID(), missionID: 1, won: true, crystals: 200, rescued: 1, healthFraction: 0.4, kills: 20)
    let firstReward = pilot.settle(clear)
    let first = try #require(firstReward)
    #expect(first == Reward(loot: 200, firstClear: 300, medals: 100))
    #expect(pilot.crystals == 850)
    #expect(pilot.unlocked(2))
    #expect(!pilot.unlocked(3))
    let settled = pilot
    #expect(pilot.settle(clear) == nil)
    #expect(pilot == settled)
    let replay = SortieResult(id: UUID(), missionID: 1, won: true, crystals: 100, rescued: 3, healthFraction: 0.6, kills: 10)
    #expect(pilot.settle(replay) == Reward(loot: 100, firstClear: 0, medals: 200))
    let third = SortieResult(id: UUID(), missionID: 1, won: true, crystals: 100, rescued: 3, healthFraction: 1, kills: 10)
    #expect(pilot.settle(third) == Reward(loot: 100, firstClear: 0, medals: 0))
}

@Test func lossKeepsQuarterWithoutUnlocking() {
    var pilot = PilotProgress()
    let loss = SortieResult(id: UUID(), missionID: 1, won: false, crystals: 103, rescued: 3, healthFraction: 0, kills: 4)
    #expect(pilot.settle(loss) == Reward(loot: 25, firstClear: 0, medals: 0))
    #expect(!pilot.unlocked(2))
    #expect(pilot.medalCount == 0)
}

@Test func invalidOrLockedResultsCannotPayOut() {
    var pilot = PilotProgress()
    for result in [
        SortieResult(id: UUID(), missionID: 2, won: true, crystals: 100, rescued: 0, healthFraction: 1, kills: 1),
        SortieResult(id: UUID(), missionID: 1, won: true, crystals: -1, rescued: 0, healthFraction: 1, kills: 1),
        SortieResult(id: UUID(), missionID: 1, won: true, crystals: 10, rescued: 4, healthFraction: 1, kills: 1),
        SortieResult(id: UUID(), missionID: 1, won: true, crystals: 10, rescued: 0, healthFraction: .nan, kills: 1)
    ] { #expect(pilot.settle(result) == nil) }
    #expect(pilot == PilotProgress())
}

@Test func atomicSaveRoundTripAndCorruptionProtection() throws {
    let directory = URL.temporaryDirectory.appending(path: "EagleCoreTests-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }
    let save = SaveFile(url: directory.appending(path: "pilot.json"))
    #expect(try save.load() == PilotProgress())
    var pilot = PilotProgress()
    _ = pilot.purchase(.weapon)
    _ = pilot.settle(SortieResult(id: UUID(), missionID: 1, won: true, crystals: 45, rescued: 3, healthFraction: 0.8, kills: 5))
    try save.write(pilot)
    #expect(try save.load() == pilot)
    let bytes = try Data(contentsOf: save.url)
    pilot.loadout.weapon = 90
    #expect(throws: (any Error).self) { try save.write(pilot) }
    #expect(try Data(contentsOf: save.url) == bytes)
    try Data("broken-json".utf8).write(to: save.url)
    #expect(throws: (any Error).self) { try save.load() }
    #expect(try String(contentsOf: save.url, encoding: .utf8) == "broken-json")
}

@Test(arguments: Mission.campaign)
func completeMissionThroughRealTimeline(_ mission: Mission) throws {
    var world = GameWorld(mission: mission, loadout: Loadout())
    // An invulnerable aiming bot verifies the full timeline, collisions and boss completion, not human difficulty.
    world.invincibleUntil = .infinity
    var peakEntities = 0
    for _ in 0..<(60 * 270) {
        if let target = world.boss ?? world.entities.first(where: { $0.kind.isEnemy && $0.position.y > world.player.y + 60 }) {
            world.movePlayer(by: Vector(x: target.position.x - world.player.x, y: 0))
        }
        world.step(1.0 / 60)
        _ = world.drainEffects()
        peakEntities = max(peakEntities, world.entities.count)
        if world.result != nil { break }
    }
    let result = try #require(world.result)
    #expect(result.won)
    #expect(result.kills > 0)
    #expect(world.elapsed >= mission.bossTime)
    #expect(world.waveNumber == mission.waves.count)
    #expect(peakEntities < 350)
}

@Test func pulseConsumesChargesClearsBulletsAndCannotRepeatRewards() {
    var world = GameWorld(mission: Mission.campaign[0], loadout: Loadout())
    world.entities = [entity(.hostile, id: 1, at: Vector(x: 200, y: 300)), entity(.scout, id: 2, at: Vector(x: 100, y: 500), hp: 30)]
    world.pulse()
    #expect(world.empCharges == 1)
    #expect(!world.entities.contains { $0.kind == .hostile })
    #expect(world.kills == 1)
    world.pulse(); world.pulse()
    #expect(world.empCharges == 0)
    #expect(world.kills == 1)
    #expect(world.crystals == 5)
}

@Test func pickupsShieldAndDamageGracePeriod() {
    var world = GameWorld(mission: Mission.campaign[0], loadout: Loadout())
    world.entities = [entity(.rescue, id: 10, at: world.player), entity(.shield, id: 11, at: world.player)]
    world.step(1.0 / 60)
    #expect(world.rescued == 1)
    #expect(world.empCharges == 3)
    #expect(world.shield)
    world.invincibleUntil = 0
    world.entities = [entity(.hostile, id: 12, at: world.player, damage: 20), entity(.hostile, id: 13, at: world.player, damage: 20)]
    world.step(1.0 / 60)
    #expect(!world.shield)
    #expect(world.health == 100)
    #expect(world.lastDamageAt == -Double.infinity)
    #expect(world.lastPlayerHitAt == world.elapsed)
    world.invincibleUntil = 0
    world.entities = [entity(.hostile, id: 14, at: world.player, damage: 20), entity(.hostile, id: 15, at: world.player, damage: 20)]
    world.step(1.0 / 60)
    #expect(world.health == 80)
    #expect(world.lastDamageAt == world.elapsed)
}

@Test func lethalPulseCompletesBossAndCannotPayTwice() throws {
    var world = GameWorld(mission: Mission.campaign[0], loadout: Loadout())
    world.entities = [entity(.boss, id: 40, at: Vector(x: 195, y: 600), hp: 80)]
    world.pulse()
    #expect(world.result == nil)
    #expect(world.bossFallTime == 0)
    #expect(world.kills == 1)
    let position = world.player
    world.movePlayer(by: Vector(x: 50, y: 50))
    #expect(world.player == position)
    world.pulse()
    #expect(world.empCharges == 1)
    #expect(world.kills == 1)
    #expect(world.entities.isEmpty && world.lanes.isEmpty)
    for _ in 0..<300 { world.advance(1.0 / 60, speed: 2) }
    #expect(world.result == nil)
    for _ in 0..<15 { world.advance(1.0 / 60, speed: 2) }
    let result = try #require(world.result)
    #expect(result.won)
    world.step(1)
    #expect(world.result?.id == result.id)
}

@Test func deathTerminatesSimulationAndMovementIsBounded() throws {
    var world = GameWorld(mission: Mission.campaign[1], loadout: Loadout())
    world.movePlayer(by: Vector(x: -10_000, y: 10_000))
    #expect(world.player == Vector(x: 24, y: world.length - 70))
    world.health = 10; world.invincibleUntil = 0
    world.entities = [entity(.hostile, id: 100, at: world.player, damage: 20)]
    world.step(1.0 / 60)
    #expect(world.result == nil)
    #expect(world.crashTime == 0)
    let position = world.player
    let charges = world.empCharges
    let entities = world.entities.map(\.id)
    _ = world.drainEffects()
    world.movePlayer(by: Vector(x: 100, y: -100))
    world.pulse()
    #expect(world.player == position)
    #expect(world.empCharges == charges)
    for _ in 0..<90 { world.step(1.0 / 30) }
    #expect(world.result == nil)
    #expect(world.entities.map(\.id) == entities)
    #expect(world.drainEffects().isEmpty)
    for _ in 0..<13 { world.step(1.0 / 30) }
    #expect(try #require(world.result).won == false)
    let resultID = world.result?.id
    let time = world.elapsed
    world.step(1)
    #expect(world.elapsed == time)
    #expect(world.result?.id == resultID)
}

@Test func campaignDataHasFiveDistinctScenesAndBothAxes() {
    #expect(Mission.campaign.map(\.id) == [1, 2, 3, 4, 5])
    #expect(Set(Mission.campaign.map { $0.biome.rawValue }).count == 5)
    #expect(Mission.campaign.filter { $0.axis == .horizontal }.count == 2)
    for mission in Mission.campaign {
        #expect(mission.waves.map(\.time) == mission.waves.map(\.time).sorted())
        #expect(mission.waves.allSatisfy { $0.time < mission.bossTime && $0.count > 0 })
    }
}

private func entity(_ kind: EntityKind, id: Int, at position: Vector, hp: Double = 1, damage: Double = 0) -> Entity {
    Entity(id: id, kind: kind, position: position, velocity: .zero, hp: hp, maxHP: hp, originX: position.x, damage: damage)
}

@Test(arguments: Mission.campaign)
func obstaclesAreSparseAndLeaveWideEscapeRoutes(_ mission: Mission) {
    var world = GameWorld(mission: mission, loadout: Loadout())
    world.invincibleUntil = .infinity
    var seen: Set<Int> = []
    var times: [Double] = []
    for _ in 0..<Int(mission.bossTime * 30) {
        world.step(1.0 / 30)
        _ = world.drainEffects()
        let obstacles = world.entities.filter { $0.kind == .obstacle }
        #expect(obstacles.count <= 2)
        for obstacle in obstacles {
            if seen.insert(obstacle.id).inserted { times.append(world.elapsed) }
            let clearSide = max(obstacle.position.x - obstacle.radius, world.width - obstacle.position.x - obstacle.radius)
            #expect(clearSide >= 160)
            #expect(obstacle.velocity == Vector(x: 0, y: -GameWorld.groundSpeed))
        }
    }
    #expect(times.count >= 3)
    for pair in zip(times, times.dropFirst()) { #expect(pair.1 - pair.0 >= 30) }
}

@Test func radarSurvivesEMPAndUsesCollisionDamageGrace() {
    var world = GameWorld(mission: Mission.campaign[0], loadout: Loadout())
    world.invincibleUntil = 0
    world.entities = [entity(.obstacle, id: 900, at: world.player, hp: 154)]
    world.step(1.0 / 60)
    #expect(world.health == 75)
    #expect(world.lastDamageAt == world.elapsed)
    world.step(1.0 / 60)
    #expect(world.health == 75)
    let hp = world.entities.first { $0.id == 900 }?.hp
    world.pulse()
    #expect(world.entities.first { $0.id == 900 }?.hp == hp)
    #expect(world.kills == 0)
    #expect(world.crystals == 0)
}

@Test(arguments: ObstacleSize.allCases)
func obstacleDurabilityHitFeedbackAndSingleReward(_ size: ObstacleSize) throws {
    var world = GameWorld(mission: Mission.campaign[0], loadout: Loadout())
    let point = Vector(x: 70, y: 400)
    var obstacle = entity(.obstacle, id: 900, at: point, hp: size.durability)
    obstacle.obstacleSize = size
    world.entities = [obstacle]
    let shots = [4, 8, 14][size.rawValue]
    for shot in 1...shots {
        world.entities.append(entity(.bolt, id: 1000 + shot, at: point, damage: 11))
        world.step(1.0 / 60)
        #expect(!world.entities.contains { $0.id == 1000 + shot })
        if shot < shots {
            let remaining = try #require(world.entities.first { $0.id == 900 })
            #expect(remaining.hp == size.durability - Double(shot * 11))
            #expect(remaining.lastHitAt == world.elapsed)
            #expect(remaining.radius == size.radius)
        }
    }
    #expect(!world.entities.contains { $0.id == 900 })
    #expect(world.entities.filter { $0.kind == .crystal }.count == 1)
    #expect(world.kills == 0)
    let rubble = world.drainEffects().filter { if case .rubble = $0 { true } else { false } }
    #expect(rubble.count == 1)
    world.step(1.0 / 60)
    #expect(!world.drainEffects().contains { if case .rubble = $0 { true } else { false } })
}

@Test func simultaneousBossKillAndLethalHitStillCrashes() {
    var world = GameWorld(mission: Mission.campaign[0], loadout: Loadout())
    world.health = 10; world.invincibleUntil = 0
    let point = Vector(x: 195, y: 655)
    world.entities = [entity(.boss, id: 900, at: point, hp: 11),
                      entity(.bolt, id: 901, at: point, damage: 11),
                      entity(.hostile, id: 902, at: world.player, damage: 20)]
    world.step(1.0 / 60)
    #expect(world.boss == nil)
    #expect(world.crashTime == 0)
    #expect(world.result == nil)
    for _ in 0..<103 { world.step(1.0 / 30) }
    #expect(world.result?.won == false)
}

@Test func repairCannotReviveAfterLethalCollisionInSameFrame() {
    var world = GameWorld(mission: Mission.campaign[0], loadout: Loadout())
    world.health = 10; world.invincibleUntil = 0
    world.entities = [entity(.hostile, id: 900, at: world.player, damage: 20), entity(.repair, id: 901, at: world.player)]
    world.step(1.0 / 60)
    #expect(world.health == 0)
    #expect(world.crashTime == 0)
}

@Test(arguments: [1.0, 1.5, 2.0])
func acceleratedSimulationUsesSmallCollisionSteps(_ speed: Double) {
    var world = GameWorld(mission: Mission.campaign[0], loadout: Loadout())
    world.invincibleUntil = 0
    var shot = entity(.hostile, id: 900, at: world.player + Vector(x: 0, y: 25), damage: 18)
    shot.velocity = Vector(x: 0, y: -650)
    world.entities = [shot]
    for _ in 0..<60 { world.advance(1.0 / 60, speed: speed) }
    #expect(abs(world.elapsed - speed) < 0.00001)
    #expect(world.health == 82)
    let time = world.elapsed
    world.advance(.nan, speed: speed)
    world.advance(1, speed: 100)
    #expect(world.elapsed == time)
}

@Test(arguments: Mission.campaign)
func bossVolleyDensityAndSpeedScaleByMission(_ mission: Mission) {
    for halfHealth in [false, true] {
        var world = GameWorld(mission: mission, loadout: Loadout())
        var boss = entity(.boss, id: 900, at: Vector(x: world.width / 2, y: world.length - 120), hp: 2000)
        boss.hp = halfHealth ? 800 : 2000
        boss.fireAt = 0
        world.entities = [boss]
        world.step(1.0 / 120)
        let bullets = world.entities.filter { $0.kind == .hostile }
        #expect(bullets.count == [3, 3, 5, 7, 9][mission.id - 1] + (halfHealth ? 2 : 0))
        let expectedSpeed = (94 + Double(mission.id) * 7 + (halfHealth ? 10 : 0)) * world.flightScale * 1.5
        #expect(bullets.allSatisfy { abs($0.velocity.length - expectedSpeed) < 0.00001 })
        #expect(world.effects.contains { if case .bossShot = $0 { true } else { false } })
        #expect((world.boss?.fireAt ?? 0) >= 0.6)
    }
}

@Test(arguments: Mission.campaign)
func bossCadenceIncludesBurstsAndRecoveryWindows(_ mission: Mission) {
    var world = GameWorld(mission: mission, loadout: Loadout())
    world.invincibleUntil = .infinity
    var boss = entity(.boss, id: 900, at: Vector(x: world.width / 2, y: world.length - 100), hp: 100_000)
    boss.fireAt = 0
    world.entities = [boss]
    var shots: [Double] = []
    for _ in 0..<1800 {
        world.step(1.0 / 60)
        if world.drainEffects().contains(where: { if case .bossShot = $0 { true } else { false } }) { shots.append(world.elapsed) }
    }
    let gaps = zip(shots.dropFirst(), shots).map(-)
    #expect(gaps.count >= 8)
    #expect((gaps.max() ?? 0) > (gaps.min() ?? 1) * 2)
    #expect(gaps.allSatisfy { $0 >= 0.6 && $0 <= 4.7 })
}

@Test(arguments: [Formation.arrow, .wall, .sweep, .weave, .pincer])
func enemyMotionDisplacesAndPreservesOrderedFormations(_ formation: Formation) {
    var world = GameWorld(mission: Mission.campaign[0], loadout: Loadout())
    world.entities = [150.0, 220.0].enumerated().map { index, x in
        var ship = entity(.armored, id: 900 + index, at: Vector(x: x, y: 580), hp: 500)
        ship.formation = formation; ship.motionPhase = Double(index) * 0.8
        return ship
    }
    for _ in 0..<60 { world.step(1.0 / 60) }
    let ships = world.entities.filter { $0.kind == .armored }
    #expect(ships.count == 2)
    #expect(abs(ships[0].position.x - 150) > 10)
    if formation == .arrow || formation == .wall {
        #expect(abs(ships[1].position.x - ships[0].position.x - 70) < 0.0001)
    }
}

@Test func attractedSuppliesArriveQuicklyWithoutOvershooting() {
    var world = GameWorld(mission: Mission.campaign[0], loadout: Loadout())
    world.entities = [entity(.rescue, id: 900, at: world.player + Vector(x: 95, y: 0))]
    for _ in 0..<12 { world.advance(1.0 / 60, speed: 1) }
    #expect(world.rescued == 1)
    #expect(world.entities.allSatisfy { $0.kind != .rescue })
}

@Test func horizontalCorridorBendsAndWallDamageHasGracePeriod() {
    var world = GameWorld(mission: Mission.campaign[1], loadout: Loadout())
    #expect(world.width == 780 && world.length == 390)
    let start = world.corridor(at: 75)
    world.elapsed = 15
    #expect(abs(start.lowerBound - world.corridor(at: 75).lowerBound) > 30)
    for distance in stride(from: 0.0, through: 5000, by: 10) {
        let corridor = world.corridor(at: distance)
        #expect(corridor.lowerBound >= 50 && corridor.upperBound <= 730)
        #expect(corridor.upperBound - corridor.lowerBound >= 480)
    }
    world.player.x = 24; world.invincibleUntil = 0
    world.step(1.0 / 120)
    #expect(world.health == 88)
    world.step(1.0 / 120)
    #expect(world.health == 88)
}

@Test func originalAudioProducesValidNonSilentPCMWithoutClipping() {
    #expect(AudioScore.wav("rescue") != AudioScore.wav("pickup"))
    #expect(AudioScore.wav("supply") != AudioScore.wav("pickup"))
    for name in AudioScore.effects + ["music"] {
        let bytes = [UInt8](AudioScore.wav(name))
        #expect(String(bytes: bytes[0..<4], encoding: .utf8) == "RIFF")
        #expect(String(bytes: bytes[8..<12], encoding: .utf8) == "WAVE")
        let size = Int(bytes[40]) | Int(bytes[41]) << 8 | Int(bytes[42]) << 16 | Int(bytes[43]) << 24
        #expect(size == bytes.count - 44)
        var peak = 0
        for offset in stride(from: 44, to: bytes.count, by: 2) {
            let sample = Int(Int16(bitPattern: UInt16(bytes[offset]) | UInt16(bytes[offset + 1]) << 8))
            peak = max(peak, abs(sample))
        }
        #expect(peak > 1000 && peak < 32_767)
        #expect(bytes[44] == 0 && bytes[45] == 0)
    }
}

@Test func rescueCompassHandlesTargetsBehindAndBothFlightAxes() {
    let offsets = [Vector(x: 0, y: 100), Vector(x: 100, y: 100), Vector(x: 100, y: 0), Vector(x: 100, y: -100),
                   Vector(x: 0, y: -100), Vector(x: -100, y: -100), Vector(x: -100, y: 0), Vector(x: -100, y: 100)]
    #expect(offsets.map { $0.direction(on: .vertical) } == ["↑", "↗", "→", "↘", "↓", "↙", "←", "↖"])
    #expect(offsets.map { $0.direction(on: .horizontal) } == ["→", "↘", "↓", "↙", "←", "↖", "↑", "↗"])
}

@Test(arguments: Mission.campaign)
func ordinaryEnemiesTakeAtMostThreeHits(mission: Mission) throws {
    var timeline = GameWorld(mission: mission, loadout: Loadout())
    timeline.invincibleUntil = .infinity
    var kinds = Set<EntityKind>()
    for wave in mission.waves {
        timeline.entities = []
        timeline.elapsed = wave.time
        timeline.step(0.001)
        let enemies = timeline.entities.filter { $0.kind.isEnemy && $0.kind != .boss }
        #expect(!enemies.isEmpty)
        for enemy in enemies {
            kinds.insert(enemy.kind)
            // Test the real collision path with both a main shot and the weakest wing shot.
            for damage in [11.0, 9.35, 23.0] {
                var combat = GameWorld(mission: mission, loadout: Loadout())
                var target = entity(enemy.kind, id: 9000, at: Vector(x: combat.width / 2, y: combat.length - 100), hp: enemy.hp)
                target.fireAt = .infinity
                combat.entities = [target]
                var hits = 0
                while combat.entities.contains(where: { $0.id == target.id }), hits < 4 {
                    combat.entities.append(entity(.bolt, id: 10_000 + hits, at: target.position, damage: damage))
                    combat.step(0.001)
                    hits += 1
                }
                #expect(hits <= 3)
                #expect(!combat.entities.contains { $0.id == target.id })
                if damage <= 11 {
                    let expected = enemy.kind.isHeavyAircraft ? [1, 2, 2, 3, 3][mission.id - 1] : [1, 1, 2, 2, 3][mission.id - 1]
                    #expect(hits == expected)
                }
            }
        }
    }
    #expect(kinds == Set(mission.waves.map(\.kind)))
}

@Test func weakShotsKeepTheirDamageAgainstBossesAndObstacles() throws {
    for kind in [EntityKind.boss, .obstacle] {
        var world = GameWorld(mission: Mission.campaign[0], loadout: Loadout())
        let point = Vector(x: world.width / 2, y: world.length - 125)
        world.entities = [entity(kind, id: 9000, at: point, hp: 100), entity(.bolt, id: 9001, at: point, damage: 5)]
        world.step(0.001)
        #expect(try #require(world.entities.first { $0.id == 9000 }).hp == 95)
    }
}


@Test(arguments: Mission.campaign)
func powerPickupDoesNotConsumeFutureWavesEarly(_ mission: Mission) {
    var world = GameWorld(mission: mission, loadout: Loadout())
    world.invincibleUntil = .infinity
    world.elapsed = 4
    world.step(1.0 / 120)
    #expect(world.waveNumber == 1)
    // First formation has been cleared just as its power pickup reaches the player.
    world.entities = [entity(.power, id: 900, at: world.player)]
    world.step(1.0 / 120)
    let collectedAt = world.elapsed
    #expect(world.overdriveUntil > collectedAt)
    for _ in 0..<360 {
        world.advance(1.0 / 120, speed: 1)
        #expect(world.waveNumber == 1)
    }
    world.elapsed = mission.waves[1].time
    world.step(0.001)
    #expect(world.waveNumber == 2)
}

@Test(arguments: Mission.campaign)
func dynamicDensityIsBoundedAndStopsBeforeBoss(_ mission: Mission) {
    var world = GameWorld(mission: mission, loadout: Loadout())
    world.invincibleUntil = .infinity
    world.overdriveUntil = mission.bossTime
    var lastSeen = 0.0
    for _ in 0..<Int(mission.bossTime * 60) {
        world.step(1.0 / 60)
        let aircraft = world.entities.filter { $0.kind.isEnemy && $0.kind != .boss }
        #expect(aircraft.count <= 8)
        if !aircraft.isEmpty { lastSeen = world.elapsed }
        // Fast clears must preserve the authored pauses and final approach to the boss.
        world.entities.removeAll { ($0.kind.isEnemy && $0.kind != .boss) || $0.kind == .hostile }
        _ = world.drainEffects()
    }
    #expect(world.waveNumber == mission.waves.count)
    #expect(abs(lastSeen - (mission.waves.last?.time ?? 0)) < 0.05)
    #expect(lastSeen < mission.bossTime - 4)
    for _ in 0..<600 { world.step(1.0 / 60) }
    #expect(!world.entities.contains { $0.kind.isEnemy && $0.kind != .boss })
}

@Test func incomingFormationCountsTowardDensityCap() {
    var world = GameWorld(mission: Mission.campaign[0], loadout: Loadout())
    world.elapsed = 10; world.overdriveUntil = 18
    world.entities = (900..<909).map { entity(.scout, id: $0, at: Vector(x: 40, y: world.length + 80), hp: 100) }
    world.step(1.0 / 120)
    #expect(world.waveNumber == 0)
    #expect(world.entities.filter { $0.kind == .scout }.count == 9)
}

@Test(arguments: Mission.campaign)
func supplyPacingUnlocksOnlyOneCrateAfterTheOpening(_ mission: Mission) throws {
    var world = GameWorld(mission: mission, loadout: Loadout())
    world.invincibleUntil = .infinity
    let point = Vector(x: 70, y: world.length - 110)
    world.elapsed = 12
    world.entities = (900..<924).map { entity(.scout, id: $0, at: point, hp: 0) }
    world.step(0.001)
    #expect(!world.entities.contains { $0.kind.isSupply })
    world.elapsed = 28
    world.entities = (930..<954).map { entity(.scout, id: $0, at: point, hp: 0) }
    world.step(0.001)
    let first = try #require(world.entities.first { $0.kind.isSupply })
    #expect(first.kind == [EntityKind.power, .spread, .laser, .escort, .lightning][mission.id - 1])
    #expect(world.entities.filter { $0.kind.isSupply }.count == 1)
    world.elapsed = 49
    world.entities = (960..<984).map { entity(.scout, id: $0, at: point, hp: 0) }
    world.step(0.001)
    #expect(!world.entities.contains { $0.kind.isSupply })
    world.elapsed = 51
    world.entities = [first] + (990..<1014).map { entity(.scout, id: $0, at: point, hp: 0) }
    world.step(0.001)
    #expect(world.entities.filter { $0.kind.isSupply }.map(\.id) == [first.id])
    world.elapsed = 52
    world.entities = [entity(.scout, id: 1020, at: point, hp: 0)]
    world.step(0.001)
    #expect(world.entities.filter { $0.kind.isSupply }.count == 1)
    #expect(!world.entities.contains { $0.kind == .repair }) // Healthy pilots do not receive wasted repair kits.
    let locked: Set<EntityKind> = switch mission.id {
    case 1: [.shield, .spread, .laser, .escort, .lightning]
    case 2: [.laser, .escort, .lightning]
    case 3: [.escort, .lightning]
    case 4: [.lightning]
    default: []
    }
    #expect(Set(mission.supplyPool).isDisjoint(with: locked))
}

@Test(arguments: Mission.campaign)
func openingFormationHasRoomBetweenAircraft(_ mission: Mission) {
    var world = GameWorld(mission: mission, loadout: Loadout())
    world.elapsed = 4
    world.step(0.001)
    let aircraft = world.entities.filter { $0.kind.isEnemy }
    #expect(aircraft.count == 3)
    for a in aircraft { for b in aircraft where a.id != b.id {
        #expect((a.position - b.position).length > a.radius + b.radius + 20)
    } }
}

@Test(arguments: Mission.campaign)
func screenEdgeKillsDoNotSpendTheSupplyOpportunity(_ mission: Mission) {
    var world = GameWorld(mission: mission, loadout: Loadout())
    world.invincibleUntil = .infinity
    world.elapsed = 28
    for point in [Vector(x: -30, y: 200), Vector(x: world.width + 30, y: 200),
                  Vector(x: 70, y: -30), Vector(x: 70, y: world.length + 80)] {
        world.entities = (900..<908).map { entity(.scout, id: $0, at: point, hp: 10) }
        world.empCharges = 1
        world.pulse()
        #expect(!world.entities.contains { $0.kind.isSupply })
    }
    world.entities = [entity(.scout, id: 920, at: Vector(x: 70, y: world.length - 110), hp: 10)]
    world.empCharges = 1
    world.pulse()
    #expect(world.entities.filter { $0.kind.isSupply }.map(\.kind) == [mission.supplyPool.last!])
}

@Test(arguments: Mission.campaign)
func suppliesRequireEightFreshKillsAndOfferRepairsOnlyWhenHurt(_ mission: Mission) {
    var world = GameWorld(mission: mission, loadout: Loadout())
    world.invincibleUntil = .infinity
    let point = Vector(x: 70, y: world.length - 110)
    world.elapsed = 28
    world.entities = (900..<908).map { entity(.scout, id: $0, at: point, hp: 0) }
    world.step(0.001)
    #expect(world.entities.filter { $0.kind.isSupply }.count == 1)
    world.elapsed = 51
    world.health = 30
    world.entities = (910..<917).map { entity(.scout, id: $0, at: point, hp: 0) }
    world.step(0.001)
    #expect(!world.entities.contains { $0.kind.isSupply })
    world.entities = [entity(.scout, id: 920, at: point, hp: 0)]
    world.step(0.001)
    #expect(world.entities.filter { $0.kind.isSupply }.count == 1)
    if mission.id == 1 { #expect(world.entities.contains { $0.kind == .repair }) }
}

@Test(arguments: Mission.campaign)
func ordinaryAndGroundEnemyProjectilesAreFiftyPercentFaster(_ mission: Mission) {
    for kind in [EntityKind.scout, .armored, .interceptor, .obstacle] {
        var world = GameWorld(mission: mission, loadout: Loadout())
        var enemy = entity(kind, id: 900, at: Vector(x: 70, y: world.length - 80), hp: 100)
        enemy.fireAt = 0
        world.entities = [enemy]
        world.step(1.0 / 120)
        let shots = world.entities.filter { $0.kind == .hostile }
        #expect(shots.count == (kind == .armored ? 3 : kind == .scout ? 1 : 2))
        #expect(shots.allSatisfy { abs($0.velocity.length - (90 + Double(mission.id) * 7) * world.flightScale * 1.5) < 0.00001 })
        #expect((shots.first?.velocity.y ?? 0) < 0)
    }
}

@Test(arguments: Mission.campaign)
func passedEnemiesStopFiringWithoutDeletingExistingShots(_ mission: Mission) throws {
    for kind in [EntityKind.scout, .armored, .interceptor, .boss, .obstacle] {
        var world = GameWorld(mission: mission, loadout: Loadout())
        let y = world.length - (mission.axis == .vertical ? 125 : 80)
        world.player = Vector(x: world.width / 2 - 100, y: y - 80)
        var enemy = entity(kind, id: 900, at: Vector(x: 70, y: y), hp: 1000)
        enemy.fireAt = 0
        world.entities = [enemy]
        world.step(1.0 / 120)
        let shot = try #require(world.entities.first { $0.kind == .hostile })
        let volleys = try #require(world.entities.first { $0.id == 900 }?.volleys)
        #expect(volleys == 1)
        for offset in [0.0, 10.0, 60.0] {
            world.player.y = y + offset
            let index = try #require(world.entities.firstIndex { $0.id == 900 })
            world.entities[index].fireAt = 0
            world.step(1.0 / 120)
            #expect(world.entities.first { $0.id == 900 }?.volleys == volleys)
        }
        let flyingShot = try #require(world.entities.first { $0.id == shot.id })
        #expect(flyingShot.position != shot.position)
    }
}

@Test(arguments: [Mission.campaign[1], Mission.campaign[2], Mission.campaign[4]])
func passedBossCannotStartLaserButExistingWarningsPersist(_ mission: Mission) {
    var world = GameWorld(mission: mission, loadout: Loadout())
    let y = world.length - (mission.axis == .vertical ? 125 : 80)
    var boss = entity(.boss, id: 900, at: Vector(x: world.width / 2, y: y), hp: 1000)
    boss.hp = 300
    boss.fireAt = .infinity
    world.entities = [boss]
    for offset in [10.0, 0.0] {
        world.player.y = y + offset
        world.step(1.0 / 120)
        #expect(world.lanes.isEmpty)
    }
    world.player.y = y - 80
    world.step(1.0 / 120)
    #expect(world.lanes.count == 1)
    world.player.y = y + 10
    world.step(1.0 / 120)
    #expect(world.lanes.count == 1)
    #expect((world.lanes.first?.age ?? 0) > 1.0 / 120)
}

@Test func aircraftIntroductionsAndEncounterDensity() {
    let expected: [Set<EntityKind>] = [
        [.propeller, .scout, .gunship, .armored],
        [.propeller, .scout, .gunship, .armored, .interceptor],
        [.propeller, .scout, .gunship, .armored, .interceptor, .twinBoom],
        [.propeller, .scout, .gunship, .armored, .interceptor, .twinBoom, .heavyGunship],
        Set(EntityKind.aircraft)
    ]
    for mission in Mission.campaign {
        #expect(Set(mission.waves.map(\.kind)) == expected[mission.id - 1])
        #expect(mission.waves.allSatisfy { $0.kind.isRotorcraft ? $0.count <= 2 : $0.count <= 5 })
    }
    #expect(Mission.campaign[0].waves.prefix(2).allSatisfy { $0.kind != .gunship })
    #expect(!Mission.campaign[0].groundForms.contains(.spider))
    #expect(Mission.campaign[3].groundForms.contains(.spider))
}

@Test func unarmedFlightsAndHoverExitHaveDistinctBehavior() throws {
    for kind in [EntityKind.propeller, .drone, .gunship, .twinBoom] {
        var world = GameWorld(mission: Mission.campaign[0], loadout: Loadout())
        var target = entity(kind, id: 900, at: Vector(x: 60, y: 500), hp: 1000)
        target.fireAt = 0
        target.age = 2.5
        world.entities = [target]
        world.step(0.01)
        let shots = world.entities.filter { $0.kind == .hostile }
        #expect(shots.count == (kind == .gunship ? 2 : kind == .twinBoom ? 3 : 0))
        if kind == .twinBoom { #expect(shots.allSatisfy { abs($0.velocity.x) < 0.001 }) }
        if kind == .gunship {
            let index = try #require(world.entities.firstIndex { $0.id == 900 })
            #expect(world.entities[index].velocity.y == -8)
            world.entities[index].age = 5.1
            world.step(0.01)
            #expect(world.entities.first { $0.id == 900 }?.velocity.y == -86)
        }
    }
}

@Test func largeBossesSettleInsideThePlayableFrame() throws {
    for mission in Mission.campaign {
        var world = GameWorld(mission: mission, loadout: Loadout())
        world.invincibleUntil = .infinity
        world.elapsed = mission.bossTime
        for _ in 0..<150 { world.step(1.0 / 30) }
        let boss = try #require(world.boss)
        #expect(boss.position.y <= world.length - (mission.axis == .vertical ? 165 : mission.id == 4 ? 125 : 90) + 0.001)
        #expect(boss.position.y > world.player.y + 100)
    }
}
