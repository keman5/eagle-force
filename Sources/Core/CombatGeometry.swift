import Foundation

// Authored image coordinates are shared by the closed mesh, UVs and projectile hit area.
enum HullDesign: String, CaseIterable, Sendable {
    case player, scout, armored, interceptor, boss, tank, turret, pilot, supply
    var span: Double {
        switch self {
        case .player: 60
        case .scout: 44
        case .armored: 64
        case .interceptor: 48
        case .boss: 146
        case .tank: 74
        case .turret: 76
        case .pilot: 34
        case .supply: 28
        }
    }
    var asset: String {
        switch self {
        case .player: "Ship-player-v15"
        case .boss: "Ship-boss"
        case .tank: "Tank-v16"
        case .turret: "Turret-v16"
        case .pilot: "Pilot-v16"
        case .supply: "Supply-v16"
        default: "Ship-\(rawValue)-v16"
        }
    }
    var pixels: [Vector] {
        let half: [(Double, Double)]
        switch self {
        case .player:
            half = [(627, 98), (596, 99), (574, 120), (537, 188), (519, 244),
                    (508, 303), (495, 303), (478, 254), (457, 230), (399, 227),
                    (376, 246), (337, 329), (326, 387), (127, 486), (115, 422),
                    (112, 351), (73, 351), (65, 423), (48, 426), (9, 648),
                    (10, 676), (283, 834), (299, 829), (305, 850), (327, 885),
                    (234, 974), (211, 1124), (228, 1138), (352, 1062), (356, 1015),
                    (388, 1027), (421, 1027), (444, 1015), (475, 976), (490, 939),
                    (499, 944), (520, 1019), (540, 1038), (627, 1038)]
        case .scout:
            half = [(627, 36), (597, 43), (565, 96), (536, 173), (515, 307),
                    (453, 378), (371, 409), (354, 350), (350, 250), (322, 244),
                    (313, 347), (291, 367), (279, 453), (22, 607), (15, 735),
                    (393, 780), (483, 820), (505, 901), (337, 1014), (320, 976),
                    (295, 1006), (296, 1153), (317, 1170), (338, 1144),
                    (533, 1111), (557, 1080), (562, 1122), (592, 1154), (627, 1158)]
        case .armored:
            half = [(627, 75), (615, 116), (587, 135), (554, 203), (522, 238),
                    (532, 270), (510, 339), (475, 380), (464, 318), (441, 293),
                    (381, 293), (363, 319), (344, 414), (288, 438), (272, 359),
                    (250, 336), (191, 335), (171, 364), (154, 461), (50, 516),
                    (18, 552), (15, 627), (54, 669), (371, 794), (447, 849),
                    (489, 842), (508, 875), (517, 945), (374, 996), (365, 934),
                    (346, 897), (330, 918), (295, 980), (295, 1090), (332, 1153),
                    (351, 1160), (372, 1097), (556, 1119), (591, 1115), (627, 1158)]
        case .interceptor:
            half = [(627, 5), (581, 136), (529, 350), (536, 397), (455, 489),
                    (157, 725), (129, 675), (133, 615), (117, 582), (139, 466),
                    (126, 463), (92, 579), (78, 588), (7, 834), (21, 870),
                    (75, 841), (363, 973), (384, 898), (403, 995), (448, 1018),
                    (493, 1004), (531, 951), (549, 980), (402, 1102), (374, 1232),
                    (558, 1146), (591, 1117), (614, 1183), (627, 1185)]
        case .supply:
            half = [(627, 142), (556, 122), (389, 123), (340, 103), (211, 114),
                    (90, 223), (82, 352), (106, 420), (106, 835), (83, 891),
                    (85, 1019), (207, 1138), (337, 1145), (383, 1127), (627, 1127)]
        case .pilot: half = []
        case .tank:
            half = [(627, 61), (607, 64), (603, 288), (481, 290), (461, 267),
                    (440, 242), (318, 244), (283, 273), (268, 323), (267, 1117),
                    (291, 1159), (416, 1166), (455, 1120), (486, 1144), (541, 1152),
                    (572, 1167), (627, 1168)]
        case .turret:
            half = [(627, 370), (582, 370), (576, 48), (562, 24), (539, 23),
                    (523, 44), (524, 117), (518, 283), (516, 366), (497, 367),
                    (475, 391), (405, 427), (354, 419), (278, 485), (206, 648),
                    (180, 695), (176, 871), (204, 918), (217, 995), (340, 1158),
                    (373, 1144), (495, 1212), (511, 1230), (627, 1232)]
        default:
            half = [(627, 13), (596, 39), (561, 111), (544, 156), (522, 170),
                    (495, 252), (515, 307), (449, 367), (344, 373), (320, 421),
                    (367, 464), (365, 500), (290, 549), (265, 560), (250, 608),
                    (276, 644), (225, 703), (198, 733), (108, 785), (97, 729),
                    (82, 759), (75, 801), (28, 829), (20, 1000), (48, 1030),
                    (91, 968), (326, 988), (345, 1083), (349, 1155),
                    (395, 1191), (458, 1197), (504, 1150), (540, 1200),
                    (592, 1212), (627, 1231)]
        }
        let outline: [(Double, Double)] = self == .pilot
            ? [(628, 281), (576, 296), (527, 354), (511, 398), (374, 351), (283, 286),
               (271, 194), (251, 189), (236, 231), (183, 169), (169, 177), (124, 218),
               (119, 248), (211, 332), (265, 418), (419, 503), (477, 546), (467, 626),
               (482, 695), (469, 739), (492, 853), (474, 916), (493, 950), (526, 948),
               (565, 909), (584, 813), (616, 770), (653, 778), (688, 869), (711, 958),
               (747, 972), (782, 958), (785, 903), (768, 857), (798, 790), (792, 692),
               (806, 588), (912, 646), (1004, 683), (1041, 749), (1060, 755), (1061, 722),
               (1116, 752), (1130, 738), (1128, 708), (1090, 670), (1016, 632),
               (935, 526), (833, 438), (778, 416), (749, 339), (701, 300)]
            : half + half.dropFirst().dropLast().reversed().map { (1254 - $0.0, $0.1) }
        return outline.map { Vector(x: $0.0, y: $0.1) }
    }
    private static let outlines = Dictionary(uniqueKeysWithValues: allCases.map { design in
        (design, design.pixels.map { Vector(x: ($0.x - 627) * design.span / 1254, y: (627 - $0.y) * design.span / 1254) })
    })
    var outline: [Vector] { Self.outlines[self]! }
}

extension Vector {
    func rotated(_ angle: Double) -> Vector {
        Vector(x: x * cos(angle) - y * sin(angle), y: x * sin(angle) + y * cos(angle))
    }
    func dot(_ other: Vector) -> Double { x * other.x + y * other.y }
}

// Physical barrel endpoints in unscaled turret coordinates; rendering and ballistics use this layout.
struct GroundWeaponLayout {
    let form: GroundForm
    let size: ObstacleSize
    var scale: Double { size.radius / (form == .spider ? 35 : form == .patrolBoat ? 36 : form == .turret ? 32 : form == .radar ? size.radius : 28) }
    var volleyCount: Int {
        switch form {
        case .tank: 1
        case .turret, .spider, .patrolBoat: 2
        case .radar, .missileCarrier: 3
        }
    }
    var pivot: Vector { Vector(x: 0, y: form == .patrolBoat ? 16 * scale : 0) }
    var barrels: [Vector] {
        switch form {
        case .tank: [Vector(x: 0, y: 33)]
        case .turret: [-4.7, 4.7].map { Vector(x: $0, y: 36.55) }
        case .spider: [-3.0, 3].map { Vector(x: $0, y: 35.5) }
        case .missileCarrier: [-8.5, -3.5, 6.0].map { Vector(x: $0, y: 13.5) }
        case .patrolBoat: [-6.0, 6].map { Vector(x: $0, y: 13.5) }
        case .radar: [-6.0, 0, 6].map { Vector(x: $0, y: 20) }
        }
    }
    func angle(from center: Vector, to target: Vector) -> Double {
        let aim = target - center - pivot
        return atan2(aim.y, aim.x) - .pi / 2
    }
    func muzzles(from center: Vector, to target: Vector) -> [Vector] {
        let rotation = angle(from: center, to: target)
        return barrels.map { center + pivot + ($0 * scale).rotated(rotation) }
    }
}

extension Entity {
    // Rendered aircraft point down the world y axis. Rotor discs are deliberately not solid targets.
    func hitOutline(mission: Int) -> [Vector] {
        if let design = HullDesign(rawValue: kind.rawValue), kind != .boss || mission == 1 {
            return design.outline.map { $0 * -1 }
        }
        let points: [(Double, Double)]
        switch kind {
        case .propeller, .twinBoom:
            points = [(-31, 11), (-8, 9), (0, 23), (8, 9), (31, 11), (31, 4),
                      (15, -3), (15, -29), (-15, -29), (-15, -3), (-31, 4)]
        case .gunship, .heavyGunship:
            points = [(-9, 33), (9, 33), (9, 11), (23, 11), (23, -11), (5, -11),
                      (5, -31), (9, -35), (3, -43), (-3, -43), (-9, -35), (-5, -31), (-5, -11), (-23, -11), (-23, 11), (-9, 11)]
        case .drone:
            points = [(-9, 18), (9, 18), (19, 0), (19, -14), (-19, -14), (-19, 0)]
        case .boss:
            // shortcut: later bosses use envelope bounds; replace with authored contours when their final models land.
            let half = mission == 2 ? Vector(x: 62, y: 58) : mission == 3 ? Vector(x: 77, y: 67)
                : mission == 4 ? Vector(x: 58, y: 106) : Vector(x: 65, y: 65)
            points = [(-half.x, -half.y), (half.x, -half.y), (half.x, half.y), (-half.x, half.y)]
        default:
            let r = radius
            return [Vector(x: -r, y: -r), Vector(x: r, y: -r), Vector(x: r, y: r), Vector(x: -r, y: r)]
        }
        let scale = kind == .propeller ? 0.75 : kind == .heavyGunship ? 1.15 : 1.0
        return points.map { Vector(x: -$0.0 * scale, y: -$0.1 * scale) }
    }

    func isHit(from start: Vector, to end: Vector, padding: Double, mission: Int) -> Bool {
        let a = start - position, b = end - position
        let extent = kind == .boss ? 120.0 : kind == .obstacle ? radius : 55.0
        guard min(a.x, b.x) <= extent + padding, max(a.x, b.x) >= -extent - padding,
              min(a.y, b.y) <= extent + padding, max(a.y, b.y) >= -extent - padding else { return false }
        let outline = hitOutline(mission: mission)
        func cross(_ u: Vector, _ v: Vector) -> Double { u.x * v.y - u.y * v.x }
        func distance(_ p: Vector, _ u: Vector, _ v: Vector) -> Double {
            let d = v - u
            let t = max(0, min(1, (p - u).dot(d) / max(0.000001, d.dot(d))))
            return (p - u - d * t).length
        }
        func inside(_ p: Vector) -> Bool {
            var contained = false
            for i in outline.indices {
                let u = outline[i], v = outline[(i + 1) % outline.count]
                if (u.y > p.y) != (v.y > p.y), p.x < (v.x - u.x) * (p.y - u.y) / (v.y - u.y) + u.x {
                    contained.toggle()
                }
            }
            return contained
        }
        if inside(a) || inside(b) { return true }
        for i in outline.indices {
            let u = outline[i], v = outline[(i + 1) % outline.count]
            let d = b - a, edge = v - u, denominator = cross(d, edge)
            if abs(denominator) > 0.000001 {
                let t = cross(u - a, edge) / denominator, s = cross(u - a, d) / denominator
                if (0...1).contains(t) && (0...1).contains(s) { return true }
            }
            if min(distance(a, u, v), distance(b, u, v), distance(u, a, b), distance(v, a, b)) <= padding { return true }
        }
        return false
    }
}
