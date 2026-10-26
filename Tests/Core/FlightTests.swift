import Foundation
import Testing
@testable import EagleCore

@Test(arguments: [Mission.campaign[0], Mission.campaign[1]])
func steeringSmoothsClampsAndReleases(_ mission: Mission) {
    var world = GameWorld(mission: mission, loadout: Loadout())
    let start = world.player
    world.steerPlayer(by: Vector(x: 60, y: 40))
    #expect(world.player == start)
    world.updateSteering(1.0 / 60)
    #expect(world.player.x > start.x && world.player.x < start.x + 10)
    #expect(world.player.y > start.y && world.player.y < start.y + 10)
    let release = world.player
    world.stopSteering(immediately: false)
    for _ in 0..<120 { world.updateSteering(1.0 / 60) }
    #expect((world.player - release).length < 16.3)
    world.steerPlayer(by: Vector(x: 10_000, y: -10_000))
    for _ in 0..<60 { world.updateSteering(1.0 / 60) }
    #expect(world.player.x <= world.width - 24 && world.player.y >= 40)
    let paused = world.player
    world.stopSteering()
    for _ in 0..<60 { world.updateSteering(1.0 / 60) }
    #expect(world.player == paused)
}

@Test func steeringIsFrameRateIndependentAndRejectsInvalidInput() {
    func travel(_ fps: Double) -> Vector {
        var world = GameWorld(mission: Mission.campaign[0], loadout: Loadout())
        world.steerPlayer(by: Vector(x: 40, y: 30))
        for _ in 0..<Int(fps / 5) { world.updateSteering(1 / fps) }
        return world.player
    }
    #expect((travel(30) - travel(120)).length < 0.001)
    var world = GameWorld(mission: Mission.campaign[0], loadout: Loadout())
    let start = world.player
    world.steerPlayer(by: Vector(x: .infinity, y: 0))
    world.updateSteering(1.0 / 60)
    #expect(world.player == start)
    world.steerPlayer(by: Vector(x: 50, y: 0))
    world.updateSteering(.nan)
    world.updateSteering(-1)
    #expect(world.player == start)
    world.health = 0
    world.updateSteering(1.0 / 60)
    #expect(world.player == start)
}

@Test func steeringReversesWithoutOvershootOrAnEdgeDeadZone() {
    var world = GameWorld(mission: Mission.campaign[0], loadout: Loadout())
    world.movePlayer(by: Vector(x: 10000, y: 0))
    world.steerPlayer(by: Vector(x: 10000, y: 0))
    world.steerPlayer(by: Vector(x: -50, y: 0))
    let start = world.player
    world.updateSteering(1.0 / 60)
    #expect(world.player.x < start.x)
    for _ in 0..<120 { world.updateSteering(1.0 / 60) }
    #expect(world.player.x >= start.x - 50)
    #expect(world.player.x < start.x - 49.9)
}

@Test func aircraftBanksPitchesReversesAndLevelsAtAnyFrameRate() {
    func attitude(_ fps: Double) -> FlightAttitude {
        var attitude = FlightAttitude()
        for _ in 0..<Int(fps / 2) {
            attitude.update(displacement: Vector(x: 300 / fps, y: 150 / fps), delta: 1 / fps)
        }
        return attitude
    }
    var flight = attitude(60)
    #expect(flight.roll > 0.75 && flight.roll <= 0.78)
    #expect(flight.pitch > 0.32 && flight.pitch < 0.34)
    #expect(abs(flight.roll - attitude(30).roll) < 0.0001)
    #expect(abs(flight.pitch - attitude(120).pitch) < 0.0001)
    for _ in 0..<30 { flight.update(displacement: Vector(x: -5, y: -5), delta: 1.0 / 60) }
    #expect(flight.roll < -0.75 && flight.pitch < 0)
    for _ in 0..<60 { flight.update(displacement: .zero, delta: 1.0 / 60) }
    #expect(abs(flight.roll) < 0.001 && abs(flight.pitch - 0.18) < 0.001)
}
