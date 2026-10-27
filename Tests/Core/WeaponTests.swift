import Foundation
import Testing
@testable import EagleCore

private func combatEntity(_ kind: EntityKind, id: Int, at point: Vector, hp: Double = 1) -> Entity {
    Entity(id: id, kind: kind, position: point, velocity: .zero, hp: hp, maxHP: hp, fireAt: 999, originX: point.x)
}

private func collect(_ kind: EntityKind, in world: inout GameWorld) {
    world.entities = [combatEntity(kind, id: 90_000, at: world.player)]
    world.step(1.0 / 120)
    world.entities.removeAll()
    _ = world.drainEffects()
}

@Test(arguments: [EntityKind.laser, .spread, .lightning])
func weaponPickupSwitchesRefreshesAndExpires(_ kind: EntityKind) {
    var world = GameWorld(mission: Mission.campaign[0], loadout: Loadout())
    collect(.power, in: &world)
    collect(kind, in: &world)
    #expect(world.activeWeapon.rawValue == kind.rawValue)
    #expect(world.weaponSeconds == 12)
    let expiry = world.weaponUntil
    world.elapsed += 2
    collect(kind, in: &world)
    #expect(world.weaponUntil > expiry)
    #expect(world.overdriveUntil > world.elapsed)
    collect(kind == .laser ? .spread : .laser, in: &world)
    #expect(world.activeWeapon.rawValue != kind.rawValue)
    world.elapsed = world.weaponUntil
    #expect(world.activeWeapon == .cannon)
    #expect(world.weaponSeconds == 0)
    world.step(1.0 / 120)
    #expect(world.entities.contains { $0.kind == .bolt && $0.projectileStyle == .cannon })
}

@Test(arguments: [Mission.campaign[0], Mission.campaign[1]])
func laserPiercesAircraftAndBuildingsButNotSideOrRearTargets(_ mission: Mission) {
    var world = GameWorld(mission: mission, loadout: Loadout())
    collect(.laser, in: &world)
    let points = [world.player + Vector(x: 0, y: 80), world.player + Vector(x: 0, y: 160),
                  world.player + Vector(x: 90, y: 100), world.player + Vector(x: 0, y: -65),
                  Vector(x: world.player.x, y: world.length + 20)]
    world.entities = points.enumerated().map {
        combatEntity($0.offset == 1 ? .obstacle : .scout, id: 100 + $0.offset, at: $0.element, hp: 100)
    }
    world.step(1.0 / 120)
    for id in 100...104 {
        let hp = world.entities.first { $0.id == id }?.hp
        #expect(hp == (id < 102 ? 100 - 11 * 0.85 : 100))
    }
    #expect(world.effects.contains { if case .beam = $0 { true } else { false } })
}

@Test func spreadFiresSevenDistinctForwardPelletsAndDealsDamage() {
    var world = GameWorld(mission: Mission.campaign[0], loadout: Loadout())
    collect(.spread, in: &world)
    world.step(1.0 / 120)
    let pellets = world.entities.filter { $0.kind == .bolt }
    #expect(pellets.count == 7)
    #expect(Set(pellets.map { $0.velocity.x }).count == 7)
    #expect(pellets.allSatisfy { $0.velocity.y > 0 && $0.projectileStyle == .spread })
    for (index, pellet) in pellets.enumerated() {
        let point = pellet.position + pellet.velocity * 0.1
        world.entities.append(combatEntity(.scout, id: 200 + index, at: point, hp: 100))
    }
    for _ in 0..<15 { world.step(1.0 / 120) }
    #expect(world.entities.filter { $0.kind == .scout }.map(\.hp).reduce(0, +) < 700)
    #expect(world.effects.contains { if case .spreadShot = $0 { true } else { false } })
}

@Test(arguments: [Mission.campaign[0], Mission.campaign[1]])
func lightningHitsThreeUniqueTargetsWithFalloffAndLimitedRange(_ mission: Mission) throws {
    var world = GameWorld(mission: mission, loadout: Loadout())
    collect(.lightning, in: &world)
    world.entities = [60.0, 100.0, 140.0, 190.0].enumerated().map {
        combatEntity(.scout, id: 300 + $0.offset, at: world.player + Vector(x: 0, y: $0.element), hp: 100)
    }
    world.step(1.0 / 120)
    for hop in 0..<3 {
        let target = try #require(world.entities.first { $0.id == 300 + hop })
        #expect(abs(target.hp - (100 - 11 * 2.4 * pow(0.72, Double(hop)))) < 0.0001)
    }
    #expect(world.entities.first { $0.id == 303 }?.hp == 100)
    collect(.lightning, in: &world)
    world.entities = [combatEntity(.scout, id: 310, at: world.player + Vector(x: 0, y: 60), hp: 100),
                      combatEntity(.scout, id: 311, at: world.player + Vector(x: -180, y: 100), hp: 100),
                      combatEntity(.scout, id: 312, at: world.player + Vector(x: 0, y: -65), hp: 100)]
    world.step(1.0 / 120)
    #expect(world.entities.first { $0.id == 310 }?.hp == 73.6)
    #expect(world.entities.first { $0.id == 311 }?.hp == 100)
    #expect(world.entities.first { $0.id == 312 }?.hp == 100)
}

@Test(arguments: Mission.campaign)
func escortsCapAtThreeRewardExtrasAndStayInBounds(_ mission: Mission) {
    var world = GameWorld(mission: mission, loadout: Loadout())
    for count in 1...3 {
        collect(.escort, in: &world)
        #expect(world.escortCount == count)
    }
    collect(.escort, in: &world)
    #expect(world.escortCount == 3)
    #expect(world.crystals == 60)
    for position in [Vector(x: 24, y: 40), Vector(x: world.width - 24, y: world.length - 70)] {
        world.player = position
        let points = world.escortPositions
        #expect(Set(points.map(\.x)).count == 3)
        #expect(points.allSatisfy { $0.x >= 18 && $0.x <= world.width - 18 && $0.y >= 18 && $0.y <= world.length - 18 })
        if mission.axis == .horizontal { #expect(points.allSatisfy { world.corridor(at: $0.y).contains($0.x) }) }
    }
    let fresh = GameWorld(mission: mission, loadout: world.loadout)
    #expect(fresh.escortCount == 0)
    #expect(fresh.activeWeapon == .cannon)
}

@Test func escortsDealTheirOwnDamageAndStopAfterCrash() throws {
    var world = GameWorld(mission: Mission.campaign[0], loadout: Loadout())
    collect(.escort, in: &world)
    let position = world.escortPositions[0] + Vector(x: 0, y: 32)
    world.entities = [combatEntity(.scout, id: 400, at: position, hp: 100)]
    world.step(1.0 / 120)
    #expect(world.entities.first { $0.id == 400 }?.hp == 95)
    world.health = 0
    world.step(1.0 / 120)
    #expect(world.crashTime != nil)
    world.entities.removeAll()
    for _ in 0..<60 { world.step(1.0 / 120) }
    #expect(world.entities.isEmpty)
}

@Test func allSuppliesRemainReachableAcrossTheFiveMissionProgression() {
    var drops: Set<String> = []
    for mission in Mission.campaign {
        var world = GameWorld(mission: mission, loadout: Loadout())
        world.health = 50; world.invincibleUntil = .infinity
        for time in [32.0, 56.0, 80.0] {
            world.elapsed = time
            world.entities = (500..<508).map { combatEntity(.scout, id: $0, at: Vector(x: 70, y: 300), hp: 0) }
            world.step(1.0 / 120)
            drops.formUnion(world.entities.filter { $0.kind.isSupply }.map { $0.kind.rawValue })
        }
    }
    #expect(drops == Set(["laser", "spread", "lightning", "repair", "shield", "power", "escort"]))
}

@Test func weaponSupportUsesLiveEquipmentAndDoesNotRepeatOrQueueExpiredAdvice() throws {
    var world = GameWorld(mission: Mission.campaign[0], loadout: Loadout())
    var radio = RadioDirector()
    collect(.laser, in: &world)
    radio.update(world: world, delta: 0.1)
    let opening = try #require(radio.current)
    radio.update(world: world, delta: opening.duration + 0.1)
    #expect(radio.current?.id == "weapon-laser")
    #expect(radio.current?.speaker == .linXi)
    radio.update(world: world, delta: 30)
    #expect(radio.history.filter { $0.id == "weapon-laser" }.count == 1)
    collect(.escort, in: &world)
    radio.update(world: world, delta: 0.1)
    #expect(radio.current?.id == "escort")

    var delayed = RadioDirector()
    delayed.update(world: world, delta: 0.1)
    world.elapsed = world.weaponUntil
    delayed.update(world: world, delta: 30)
    #expect(!delayed.history.contains { $0.id.hasPrefix("weapon-") })
}
