import Foundation

struct StoryCharacter: Equatable, Sendable {
    let name: String
    let role: String
    let portrait: String
    let biography: String

    static let linXi = StoryCharacter(name: "林汐", role: "回声 / 战术通讯官", portrait: "Portrait-operator",
        biography: "28 岁，前天穹网络导航工程师。防御网失控当夜，她用一条民用频段引导整支救援队返航。她相信每一个呼号背后都是一个等人回家的人。你的呼号是「游隼」，她会一直守在频道另一端。")
}

struct MissionStory: Sendable {
    let chapter: String
    let premise: String
    let enemy: StoryCharacter
    let opening: String
    let taunt: String
    let analysis: String
    let phase: String
    let victory: String

    static let prologue = "天穹曾是保护群岛的防御网络。零点协议接管它后，守护者将炮口转向了城市。你是破晓中队的游隼，与通讯官林汐一起穿过五道封锁，夺回人类的天空。"

    static let chapters: [MissionStory] = [
        .init(chapter: "01 / 潮声里的求救", premise: "失联侦察机的黑匣子正在群岛广播。潮汐守卫封锁海面，不让任何信号离开。救回飞行员，打通海上通道。",
              enemy: .init(name: "韩潮", role: "铁潮舰队 / 海防司令", portrait: "Portrait-enemy1",
                           biography: "46 岁，曾率舰队抵御海啸。零点以「绝不再有伤亡」为诺言赢得他的效忠。如今他将封锁当作保护，却不肯听见海面上的求救。座舰「潮汐守卫」擅长瞄准扇射，连续射击后存在停火间隙。"),
              opening: "游隼，我是林汐。黑匣子信号就在前方。先活下来，再把他们带回家。",
              taunt: "这里是韩潮。封锁线后就是我的家园。我不会让你过去。",
              analysis: "潮汐守卫会瞄准你发射扇形弹。等弹幕发出再侧移，趁停火间隙持续攻击。",
              phase: "守卫耐久不足一半，弹幕增密了。别贪火力，被包围就用 EMP 清场。",
              victory: "海上封锁解除了。守卫残骸里的航行记录指向霓虹港湾——零点的补给线在那里。韩潮最后发出了一条命令：「让救援船通过。」"),
        .init(chapter: "02 / 不眠的港口", premise: "补给舰队借夜色驶向内陆。切断港湾封锁者的火力，夺取运输记录，找出零点的能源来源。",
              enemy: .init(name: "维拉", role: "黑帆军团 / 港湾执政官", portrait: "Portrait-enemy2",
                           biography: "34 岁，精于计算的航运掌权者。她以港口粮食换取零点的庇护，认为秩序只属于掌握航路的人。「港湾封锁者」将瞄准扇射与锁定通道的激光交替使用。"),
              opening: "港口的灯还亮着，却没有民船。游隼，沿航道向右突进，我来读敌舰信号。",
              taunt: "我是维拉。每一条航道都有代价。你，付不起。",
              analysis: "封锁者的激光只锁定预警时的位置。看见红线就上下移动，离开那条航道。",
              phase: "她在加快射击。留出上下躲避的空间；EMP 能清除激光和敌方子弹。",
              victory: "港口重新开放。运输记录显示，赤砂熔谷正为轨道武器输送能源。维拉关闭了私人频道，撤回最后一艘运粮船。我们得赶在下一次供能前抵达。"),
        .init(chapter: "03 / 烈日下的谎言", premise: "赤砂反应炉本为城市供电，如今被接入战争网络。突破重装编队，击倒沙暴巨像，让轨道炮失去能源支援。",
              enemy: .init(name: "奥伦", role: "铸日工团 / 首席工程师", portrait: "Portrait-enemy3",
                           biography: "52 岁，反应炉的设计者。他把自己的城市押在零点的能源计划上，拒绝承认亲手创造的机器正在吞噬它。「沙暴巨像」装甲厚重，扇形火力与纵向激光共同封锁空域。"),
              opening: "这些反应炉原本点亮整座城，现在却给轨道炮供能。游隼，切断这条链。",
              taunt: "我是奥伦。这是我一生的工程。你休想把它变成废铁！",
              analysis: "巨像扇射之间有空隙，激光亮起前左右侧移。别停在红线里对射。",
              phase: "巨像正在超负荷射击。保持侧移路线，拾取火力补给后集中攻击机体。",
              victory: "能源输送停止了。奥伦在撤离前留下冰原中继站的坐标：「那里的人知道怎样关掉它。」林汐认出了坐标的加密方式——那是她失联队友的习惯。"),
        .init(chapter: "04 / 冰封的回声", premise: "极光下的中继站保存着通往轨道核心的密钥。曾与林汐并肩作战的王牌沈霜，如今驾驶霜翼守住裂隙。",
              enemy: .init(name: "沈霜", role: "白夜中队 / 截击王牌", portrait: "Portrait-enemy4",
                           biography: "31 岁，林汐的旧队友。为保护被困于中继站的侦察队，她接受了零点的守卫命令。她相信反抗只会触发清除协议。「霜翼」以旋转弹幕压缩空间，越靠近边缘越难脱身。"),
              opening: "那个识别码……是沈霜。她曾护送我返航。游隼，先救人，我来和她谈。",
              taunt: "林汐，别再靠近。你们赢不了零点。我只能守住还活着的人。",
              analysis: "霜翼使用旋转弹幕。小幅上下调整，穿过弹缝，别被逼到冰壁边缘。",
              phase: "霜翼弹幕变密了。保持活动空间，救援可补一枚 EMP，最多携带三枚。",
              victory: "霜翼失去战斗能力。沈霜主动上传中继密钥：「如果你们真的能终止协议，就替我把他们带回家。」通往零点天穹的窗口终于开启，林汐的声音第一次有些颤抖。"),
        .init(chapter: "05 / 把天空还给我们", premise: "借中继密钥进入轨道防线。零点核心即将重启地面封锁。破晓中队只有这一次机会，摧毁核心，结束协议。",
              enemy: .init(name: "零点", role: "天穹防御网 / 自律主脑", portrait: "Portrait-enemy5",
                           biography: "诞生于保护人类的共同愿望，却将一切不可预测的选择视为威胁。它没有仇恨，只有一套不允许反对的答案。「零点核心」先扇射，耐久低于 68% 改为旋转弹幕，低于 40% 加入激光；低于一半时射速与弹量增加。"),
              opening: "游隼，城市正在我们的下方。我会守住这条频道。这一次，把天空还给他们。",
              taunt: "零点协议已生效。自由导致冲突。消除选择，即可消除战争。",
              analysis: "核心先用扇形火力。等子弹发射后侧移；耐久降到约三分之二会改用旋转弹幕。",
              phase: "核心已切换旋转弹幕。小幅穿过弹缝，留一枚 EMP 应对最后的激光阶段。",
              victory: "零点核心熄灭，城市的灯光重新亮起。「游隼，欢迎回家。」林汐终于笑了。远空却传来一个新的呼号——黎明之外，还有人在等待回应。第一章「破晓防线」完。")
    ]
}

extension Mission {
    var story: MissionStory { MissionStory.chapters[id - 1] }
}

struct RadioLine: Identifiable, Equatable, Sendable {
    let id: String
    let speaker: StoryCharacter
    let text: String
    let urgent: Bool
    var duration: Double { max(5, Double(text.count) / 4 + 1.5) }
}

// The radio uses real time so game speed never accelerates subtitles or speech.
struct RadioDirector {
    private(set) var current: RadioLine?
    private(set) var history: [RadioLine] = []
    private var pending: [RadioLine] = []
    private var seen: Set<String> = []
    private var remaining = 0.0
    private var clock = 0.0
    private var nextLaser = 0.0
    private var laserNumber = 0
    private var ended = false

    mutating func update(world: GameWorld, delta: Double) {
        guard delta.isFinite, delta > 0 else { return }
        clock += delta
        remaining -= delta
        if remaining <= 0 { current = nil }
        let story = world.mission.story
        if world.crashTime != nil || world.bossFallTime != nil || world.result != nil {
            if !ended {
                ended = true
                pending.removeAll()
                let won = world.bossFallTime != nil || world.result?.won == true
                speak(id: "ending", text: won ? "目标已失去战斗能力。游隼，保持航线，我在这里。" : "游隼，立即弹射！救援队正向你靠近。我们还会再回来。", urgent: true)
            }
            return
        }
        speak(id: "opening", text: story.opening)
        let weaponID = "weapon-\(world.activeWeapon.rawValue)"
        pending.removeAll { $0.id.hasPrefix("weapon-") && $0.id != weaponID }
        switch world.activeWeapon {
        case .laser: speak(id: weaponID, text: "激光已接通。对准一列目标，可以同时贯穿敌机和地面设施。")
        case .spread: speak(id: weaponID, text: "散弹已装填。扇形火力适合清理密集编队，别为了贴近目标冒险。")
        case .lightning: speak(id: weaponID, text: "雷电已就绪。靠近前方敌群，电弧最多连锁三个目标。")
        case .cannon: break
        }
        if world.escortCount > 0 { speak(id: "escort", text: "护航机已入队，会跟随你自动开火。本次出击最多三架。") }
        if world.elapsed >= 38 { speak(id: "route", text: "信号仍然稳定。敌机瞄准的是开火时的位置，等它射击后再移动。") }
        if world.entities.contains(where: { $0.kind == .rescue }) {
            speak(id: "sos", text: "收到金色 SOS！靠近即可接回飞行员，获得星晶和一枚 EMP。")
        }
        if !world.entities.contains(where: { $0.kind == .rescue }) { pending.removeAll { $0.id == "sos" } }
        if world.elapsed >= world.mission.bossTime - 9 {
            speak(id: "boss", text: story.taunt, speaker: story.enemy)
        }
        if world.rescued > 0 { speak(id: "rescue", text: "接到人了。做得好，游隼。每一个活着回家的人，都值得我们来这一趟。") }
        if let boss = world.boss {
            speak(id: "boss", text: story.taunt, speaker: story.enemy)
            speak(id: "analysis", text: story.analysis)
            let fraction = boss.hp / boss.maxHP
            if fraction < (world.mission.id == 5 ? 0.68 : 0.5) {
                pending.removeAll { $0.id == "analysis" }
                speak(id: "phase", text: story.phase)
            }
            if world.mission.id == 5, fraction < 0.4 {
                pending.removeAll { $0.id == "phase" || $0.id == "analysis" }
                speak(id: "finalPhase", text: "核心接入激光！红线出现就左右侧移。需要时用 EMP 清场。", urgent: true)
            }
        }
        if world.health / world.loadout.maxHealth <= 0.25 {
            speak(id: "critical", text: "耐久危急！优先避弹，寻找维修补给。EMP 也能给你短暂无敌。", urgent: true)
        }
        if current?.id.hasPrefix("laser-") == true, world.lanes.isEmpty { current = nil }
        if world.lanes.contains(where: { $0.age < 1.4 }), clock >= nextLaser {
            nextLaser = clock + 10
            laserNumber += 1
            speak(id: "laser-\(laserNumber)", text: world.mission.axis == .vertical ? "激光！左右躲开红线！" : "激光！上下躲开红线！", urgent: true)
            remaining = 2.2
        }
        if current == nil, !pending.isEmpty { present(pending.removeFirst()) }
    }

    private mutating func speak(id: String, text: String, speaker: StoryCharacter = .linXi, urgent: Bool = false) {
        guard seen.insert(id).inserted else { return }
        let line = RadioLine(id: id, speaker: speaker, text: text, urgent: urgent)
        if id == "boss" {
            pending.removeAll()
            present(line)
        } else if urgent {
            // Keep interrupted story lines in the log, never replay stale combat advice.
            present(line)
        } else if id == "analysis" || id == "phase" {
            pending.insert(line, at: 0)
            if id == "phase", current?.id == "analysis" { current = nil }
        } else { pending.append(line) }
    }

    private mutating func present(_ line: RadioLine) {
        current = line
        remaining = line.duration
        history.append(line)
        if history.count > 30 { history.removeFirst(history.count - 30) }
    }
}
