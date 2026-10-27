import Foundation

enum FlightAxis: String, Codable, Sendable { case vertical, horizontal }
enum Biome: String, Sendable { case ocean, harbor, desert, glacier, orbit }
enum Formation: Sendable { case arrow, sweep, weave, wall, pincer }

struct Wave: Sendable {
    let time: Double
    let formation: Formation
    let count: Int
    let kind: EntityKind
}

struct Mission: Identifiable, Sendable {
    let id: Int
    let title: String
    let subtitle: String
    let axis: FlightAxis
    let biome: Biome
    let boss: String
    let briefing: String
    let firstClear: Int
    let bossTime: Double
    let waves: [Wave]

    var axisLabel: String { axis == .vertical ? "纵向突击" : "横向穿越" }

    var supplyPool: [EntityKind] {
        [.repair, .power] + (id >= 2 ? [.shield, .spread] : [])
            + (id >= 3 ? [.laser] : []) + (id >= 4 ? [.escort] : []) + (id >= 5 ? [.lightning] : [])
    }
    var newSupplyTitle: String {
        ["维修箱 · 火力过载", "护盾 · 扇形散弹", "贯穿激光", "护航僚机", "连锁雷电"][id - 1]
    }

    static let campaign: [Mission] = [
        Mission(id: 1, title: "碧潮群岛", subtitle: "TIDAL FRONTIER", axis: .vertical, biome: .ocean,
                boss: "潮汐守卫", briefing: "穿越礁岛防线，接回 3 名失联飞行员。瞄准弹发射后再侧移，留一次 EMP 给守卫。",
                firstClear: 300, bossTime: 94, waves: waves([.arrow, .sweep, .arrow, .weave, .sweep, .pincer, .arrow, .wall], kinds: [.propeller, .scout, .propeller, .gunship, .scout, .gunship, .armored, .propeller])),
        Mission(id: 2, title: "霓虹港湾", subtitle: "NEON BLOCKADE", axis: .horizontal, biome: .harbor,
                boss: "港湾封锁者", briefing: "横向穿越夜港。上下移动引开追踪火力，看到红色通道时立即离开激光射线。",
                firstClear: 400, bossTime: 104, waves: waves([.sweep, .pincer, .weave, .wall, .sweep, .weave, .pincer, .wall, .arrow], kinds: [.scout, .propeller, .gunship, .interceptor, .scout, .gunship, .interceptor, .armored, .propeller])),
        Mission(id: 3, title: "赤砂熔谷", subtitle: "EMBER CANYON", axis: .vertical, biome: .desert,
                boss: "沙暴巨像", briefing: "装甲编队需要持续输出。火力补给持续 8 秒，优先击破装甲机，穿过双扇形弹幕的空隙。",
                firstClear: 500, bossTime: 114, waves: waves([.wall, .arrow, .pincer, .weave, .wall, .sweep, .pincer, .wall, .weave, .arrow], kinds: [.propeller, .scout, .twinBoom, .gunship, .armored, .twinBoom, .interceptor, .armored, .gunship, .twinBoom])),
        Mission(id: 4, title: "极光裂隙", subtitle: "AURORA PASSAGE", axis: .horizontal, biome: .glacier,
                boss: "霜翼", briefing: "在冰川间接回侦察队。小幅移动穿过旋转弹幕，避免被逼到边缘；救援能补充 EMP。",
                firstClear: 600, bossTime: 124, waves: waves([.weave, .sweep, .pincer, .weave, .wall, .pincer, .sweep, .weave, .wall, .pincer, .arrow], kinds: [.scout, .gunship, .twinBoom, .heavyGunship, .interceptor, .armored, .heavyGunship, .twinBoom, .gunship, .interceptor, .propeller])),
        Mission(id: 5, title: "零点天穹", subtitle: "ZERO HORIZON", axis: .vertical, biome: .orbit,
                boss: "零点核心", briefing: "突破轨道要塞。核心有三段火力：扇形、旋转、激光。救援与护盾留给最后的核心战。",
                firstClear: 800, bossTime: 134, waves: waves([.arrow, .wall, .pincer, .weave, .sweep, .wall, .pincer, .weave, .wall, .pincer, .weave, .wall], kinds: [.propeller, .drone, .gunship, .twinBoom, .interceptor, .heavyGunship, .drone, .scout, .twinBoom, .drone, .heavyGunship, .armored]))
    ]

    private static func waves(_ formations: [Formation], kinds: [EntityKind]) -> [Wave] {
        precondition(formations.count == kinds.count)
        return formations.enumerated().map { index, formation in
            let kind = kinds[index]
            let count = kind.isRotorcraft ? (kind == .heavyGunship ? 1 : 2)
                : index < 2 ? 3 : formation == .wall ? 5 : 4
            return Wave(time: 4 + Double(index) * 10, formation: formation, count: count, kind: kind)
        }
    }

    var groundForms: [GroundForm] {
        switch id {
        case 1: [.tank, .turret, .tank]
        case 2: [.patrolBoat, .turret, .patrolBoat]
        case 3: [.tank, .missileCarrier, .turret]
        case 4: [.turret, .spider, .missileCarrier]
        default: [.spider, .radar, .missileCarrier]
        }
    }

}

enum Upgrade: String, Codable, CaseIterable, Sendable {
    case weapon, armor, magnet
    var title: String { switch self { case .weapon: "脉冲主炮"; case .armor: "复合装甲"; case .magnet: "星晶回收" } }
    var detail: String { switch self {
    case .weapon: "提高伤害与射速，2 级解锁翼炮"
    case .armor: "每级增加 25 点护甲"
    case .magnet: "扩大星晶、补给与救援回收范围"
    } }
    static let prices = [200, 350, 550, 800]
}

struct Loadout: Codable, Equatable, Sendable {
    var weapon = 0
    var armor = 0
    var magnet = 0
    var maxHealth: Double { 100 + Double(armor) * 25 }
    var pickupRadius: Double { 44 + Double(magnet) * 16 }

    subscript(_ upgrade: Upgrade) -> Int {
        get { switch upgrade { case .weapon: weapon; case .armor: armor; case .magnet: magnet } }
        set { switch upgrade { case .weapon: weapon = newValue; case .armor: armor = newValue; case .magnet: magnet = newValue } }
    }
}

struct SortieResult: Codable, Sendable {
    let id: UUID
    let missionID: Int
    let won: Bool
    let crystals: Int
    let rescued: Int
    let healthFraction: Double
    let kills: Int

    var medals: Set<String> {
        guard won else { return [] }
        var result: Set<String> = ["clear"]
        if rescued >= 3 { result.insert("rescue") }
        if healthFraction >= 0.6 { result.insert("armor") }
        return result
    }
}

struct Reward: Equatable, Sendable {
    let loot: Int
    let firstClear: Int
    let medals: Int
    var total: Int { loot + firstClear + medals }
}

struct PilotProgress: Codable, Equatable, Sendable {
    var crystals = 250
    var loadout = Loadout()
    var medals: [Int: Set<String>] = [:]
    var settledSorties: Set<UUID> = []
    var sound = true
    var haptics = true
    var reducedEffects = false
    private var voiceMuted: Bool?
    var voiceSupport: Bool {
        get { voiceMuted != true }
        set { voiceMuted = !newValue }
    }

    var medalCount: Int { medals.values.reduce(0) { $0 + $1.count } }
    func unlocked(_ missionID: Int) -> Bool {
        Mission.campaign.contains { $0.id == missionID } && (missionID == 1 || medals[missionID - 1, default: []].contains("clear"))
    }

    mutating func purchase(_ upgrade: Upgrade) -> Bool {
        let level = loadout[upgrade]
        guard Upgrade.prices.indices.contains(level), crystals >= Upgrade.prices[level] else { return false }
        crystals -= Upgrade.prices[level]
        loadout[upgrade] += 1
        return true
    }

    mutating func settle(_ result: SortieResult) -> Reward? {
        guard !settledSorties.contains(result.id), unlocked(result.missionID),
              let mission = Mission.campaign.first(where: { $0.id == result.missionID }),
              (0...1).contains(result.healthFraction), (0...3).contains(result.rescued),
              (0...100_000).contains(result.crystals), result.kills >= 0 else { return nil }
        let previous = medals[result.missionID, default: []]
        let reward = Reward(loot: result.won ? result.crystals : result.crystals / 4,
                            firstClear: result.won && !previous.contains("clear") ? mission.firstClear : 0,
                            medals: result.medals.subtracting(previous).count * 100)
        crystals += reward.total
        medals[result.missionID] = previous.union(result.medals)
        settledSorties.insert(result.id)
        return reward
    }

    func validated() throws -> Self {
        guard (0...100_000_000).contains(crystals),
              Upgrade.allCases.allSatisfy({ (0...4).contains(loadout[$0]) }),
              medals.allSatisfy({ (1...Mission.campaign.count).contains($0.key) && $0.value.isSubset(of: ["clear", "rescue", "armor"]) })
        else { throw CocoaError(.fileReadCorruptFile) }
        return self
    }
}

struct SaveFile {
    let url: URL

    func load() throws -> PilotProgress {
        guard FileManager.default.fileExists(atPath: url.path) else { return PilotProgress() }
        return try JSONDecoder().decode(PilotProgress.self, from: Data(contentsOf: url)).validated()
    }

    func write(_ progress: PilotProgress) throws {
        _ = try progress.validated()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(progress).write(to: url, options: .atomic)
    }
}
