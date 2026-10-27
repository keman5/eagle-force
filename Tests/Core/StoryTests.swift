import Foundation
import Testing
@testable import EagleCore

@Test func legacySavesDefaultToVoiceWithoutLosingProgress() throws {
    var pilot = PilotProgress()
    pilot.crystals = 1732
    pilot.medals = [1: ["clear", "rescue"]]
    pilot.voiceSupport = false
    let encoded = try JSONEncoder().encode(pilot)
    #expect(try JSONDecoder().decode(PilotProgress.self, from: encoded).voiceSupport == false)
    var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    object.removeValue(forKey: "voiceMuted")
    let legacy = try JSONDecoder().decode(PilotProgress.self, from: JSONSerialization.data(withJSONObject: object))
    #expect(legacy.voiceSupport)
    #expect(legacy.crystals == 1732)
    #expect(legacy.medals == pilot.medals)
    #expect(legacy.loadout == pilot.loadout)
}

@Test func everyMissionHasAnOriginalCastAndConnectedStory() {
    #expect(MissionStory.chapters.count == Mission.campaign.count)
    #expect(Set(MissionStory.chapters.map { $0.enemy.name }).count == 5)
    #expect(Set(MissionStory.chapters.map { $0.enemy.portrait }).count == 5)
    for mission in Mission.campaign {
        #expect(!mission.story.enemy.biography.isEmpty)
        #expect(mission.story.opening.contains("游隼"))
        #expect(!mission.story.analysis.isEmpty)
        #expect(!mission.story.victory.isEmpty)
    }
    #expect(Mission.campaign[4].story.enemy.biography.contains("68%"))
    #expect(Mission.campaign[4].story.enemy.biography.contains("40%"))
}

@Test func radioUsesUnscaledTimeAndDoesNotRepeatOpening() {
    var radio = RadioDirector()
    var world = GameWorld(mission: Mission.campaign[0], loadout: Loadout())
    radio.update(world: world, delta: 0.01)
    #expect(radio.current?.id == "opening")
    for _ in 0..<30 {
        world.advance(1.0 / 30, speed: 2)
        radio.update(world: world, delta: 1.0 / 30)
    }
    #expect(radio.current?.id == "opening")
    let before = radio.current
    radio.update(world: world, delta: 0)
    radio.update(world: world, delta: .nan)
    #expect(radio.current == before)
    radio.update(world: world, delta: 30)
    #expect(radio.current == nil)
    #expect(radio.history.filter { $0.id == "opening" }.count == 1)
}

@Test func interceptorSupportAppearsOnceForAnOnscreenThreat() {
    var radio = RadioDirector()
    var world = GameWorld(mission: Mission.campaign[1], loadout: Loadout())
    radio.update(world: world, delta: 0.01)
    radio.update(world: world, delta: 30)
    world.entities = [Entity(id: 900, kind: .interceptor, position: Vector(x: 300, y: 260), velocity: .zero,
                             hp: 22, maxHP: 22, originX: 300)]
    radio.update(world: world, delta: 0.01)
    #expect(radio.current?.id == "enemy-interceptor")
    #expect(radio.current?.text.contains("双弹") == true)
    radio.update(world: world, delta: 30)
    radio.update(world: world, delta: 30)
    #expect(radio.history.filter { $0.id == "enemy-interceptor" }.count == 1)
}

@Test(arguments: [Mission.campaign[1], Mission.campaign[2]])
func urgentLaserInterruptsAndExpiresWithoutReplaying(_ mission: Mission) {
    var radio = RadioDirector()
    var world = GameWorld(mission: mission, loadout: Loadout())
    radio.update(world: world, delta: 0.01)
    world.health = 20
    world.lanes = [DangerLane(id: 1, x: world.player.x)]
    radio.update(world: world, delta: 0.01)
    #expect(radio.current?.id == "laser-1")
    #expect(radio.current?.text.contains(mission.axis == .horizontal ? "上下" : "左右") == true)
    #expect(radio.history.contains { $0.id == "critical" })
    world.lanes.removeAll()
    radio.update(world: world, delta: 0.01)
    #expect(radio.current == nil)
    world.lanes = [DangerLane(id: 2, x: world.player.x)]
    radio.update(world: world, delta: 1)
    #expect(radio.current == nil)
    radio.update(world: world, delta: 10)
    #expect(radio.current?.id == "laser-2")
    #expect(radio.history.filter { $0.id == "critical" }.count == 1)
}

@Test(arguments: Mission.campaign)
func bossIntroductionAnalysisAndPhaseFollowActualBattle(_ mission: Mission) throws {
    var world = GameWorld(mission: mission, loadout: Loadout())
    var radio = RadioDirector()
    world.elapsed = mission.bossTime - 8
    radio.update(world: world, delta: 0.1)
    #expect(radio.current?.speaker == mission.story.enemy)
    #expect(radio.current?.text == mission.story.taunt)
    world.elapsed = mission.bossTime
    world.invincibleUntil = .infinity
    world.step(0.01)
    world.lanes.removeAll()
    radio.update(world: world, delta: 30)
    #expect(radio.current?.id == "analysis")
    let index = try #require(world.entities.firstIndex { $0.kind == .boss })
    world.entities[index].hp = world.entities[index].maxHP * (mission.id == 5 ? 0.65 : 0.49)
    radio.update(world: world, delta: 30)
    #expect(radio.current?.text == mission.story.phase)
    radio.update(world: world, delta: 30)
    #expect(radio.history.filter { $0.id == "boss" }.count == 1)
    #expect(radio.history.filter { $0.id == "phase" }.count == 1)
    if mission.id == 5 {
        world.entities[index].hp = world.entities[index].maxHP * 0.39
        radio.update(world: world, delta: 0.1)
        #expect(radio.current?.id == "finalPhase")
    }
}

@Test func terminalMessageClearsQueuedHintsAndDoesNotAnnounceRescueWithoutPickup() {
    var world = GameWorld(mission: Mission.campaign[0], loadout: Loadout())
    var radio = RadioDirector()
    world.elapsed = 44
    world.step(0.01)
    radio.update(world: world, delta: 0.01)
    #expect(!radio.history.contains { $0.id == "rescue" })
    world.result = SortieResult(id: UUID(), missionID: 1, won: false, crystals: 0, rescued: 0, healthFraction: 0, kills: 0)
    radio.update(world: world, delta: 0.01)
    #expect(radio.current?.id == "ending")
    #expect(radio.current?.text.contains("救援队") == true)
    radio.update(world: world, delta: 30)
    #expect(radio.current == nil)
    #expect(!radio.history.contains { $0.id == "route" || $0.id == "sos" })
}
