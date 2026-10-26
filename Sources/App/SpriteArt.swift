import SwiftUI
import SceneKit
import simd
import UIKit

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255,
                  blue: CGFloat(hex & 255) / 255, alpha: alpha)
    }
}

// All world objects are lit, closed geometry. HUD and radio portraits remain SwiftUI.
@MainActor
enum ModelArt {
    static let cyan: UInt32 = 0x60E9F6
    static let orange: UInt32 = 0xFFAD52
    private static var materials: [String: SCNMaterial] = [:]

    static func material(_ color: UInt32, glow: Bool = false, metal: Bool = false) -> SCNMaterial {
        let key = "\(color)-\(glow)-\(metal)"
        if let cached = materials[key] { return cached }
        let result = SCNMaterial()
        result.diffuse.contents = UIColor(hex: color)
        result.lightingModel = .physicallyBased
        result.metalness.contents = metal ? 0.65 : 0.1
        result.roughness.contents = metal ? 0.3 : 0.65
        if glow { result.emission.contents = UIColor(hex: color) }
        materials[key] = result
        return result
    }

    @discardableResult static func part(_ geometry: SCNGeometry, _ color: UInt32, in parent: SCNNode,
                                       at position: SCNVector3 = SCNVector3Zero, glow: Bool = false, metal: Bool = false) -> SCNNode {
        geometry.materials = [material(color, glow: glow, metal: metal)]
        let node = SCNNode(geometry: geometry)
        node.position = position
        parent.addChildNode(node)
        return node
    }

    @discardableResult static func box(_ w: CGFloat, _ h: CGFloat, _ d: CGFloat, _ color: UInt32,
                                      in parent: SCNNode, at position: SCNVector3 = SCNVector3Zero, glow: Bool = false) -> SCNNode {
        part(SCNBox(width: w, height: h, length: d, chamferRadius: min(2, min(w, h) / 5)), color,
             in: parent, at: position, glow: glow, metal: !glow)
    }

    @discardableResult static func hull(_ points: [(CGFloat, CGFloat)], depth: CGFloat, color: UInt32, in parent: SCNNode) -> SCNNode {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: points[0].0, y: points[0].1))
        for point in points.dropFirst() { path.addLine(to: CGPoint(x: point.0, y: point.1)) }
        path.close()
        let shape = SCNShape(path: path, extrusionDepth: depth)
        shape.chamferRadius = 0.8
        return part(shape, color, in: parent, metal: true)
    }

    static func island(seed: Int, color: UInt32, shore: UInt32 = 0xAD9E7A) -> SCNNode {
        let sectors = 64
        let radii: [Float] = [0.01, 0.16, 0.32, 0.48, 0.64, 0.78, 0.87, 0.94, 1]
        var rings: [[SIMD3<Float>]] = []
        for (band, radius) in radii.enumerated() {
            rings.append((0..<sectors).map { sector in
                let angle = Float(sector) / Float(sectors) * .pi * 2
                let noise = 1 + sin(angle * 3 + Float(seed)) * 0.19 + cos(angle * 5 - Float(seed)) * 0.11
                let elevation: Float = [44, 41, 35, 28, 20, 11, 4, 0, -5][band]
                return SIMD3(cos(angle) * radius * noise * 59,
                             sin(angle) * radius * noise * 92,
                             elevation + (band < 6 ? sin(angle * 4 + Float(seed)) * radius * (1 - radius) * 20 : 0))
            })
        }
        var vertices: [SCNVector3] = [], normals: [SCNVector3] = []
        var elements: [SCNGeometryElement] = []
        for band in 0..<radii.count - 1 {
            var indices: [Int32] = []
            for sector in 0..<sectors {
                let next = (sector + 1) % sectors
                let a = rings[band][sector], b = rings[band + 1][sector]
                let c = rings[band + 1][next], d = rings[band][next]
                for triangle in [[a, b, c], [a, c, d]] {
                    let normal = simd_normalize(simd_cross(triangle[1] - triangle[0], triangle[2] - triangle[0]))
                    assert(normal.x.isFinite && normal.y.isFinite && normal.z.isFinite)
                    for point in triangle {
                        indices.append(Int32(vertices.count)); vertices.append(SCNVector3(point)); normals.append(SCNVector3(normal))
                    }
                }
            }
            elements.append(SCNGeometryElement(indices: indices, primitiveType: .triangles))
        }
        var sharedNormals: [SIMD3<Float>: SIMD3<Float>] = [:]
        for (point, normal) in zip(vertices, normals) {
            sharedNormals[SIMD3<Float>(point), default: .zero] += SIMD3<Float>(normal)
        }
        normals = vertices.map { SCNVector3(simd_normalize(sharedNormals[SIMD3<Float>($0)]!)) }
        let mesh = SCNGeometry(sources: [.init(vertices: vertices), .init(normals: normals)], elements: elements)
        mesh.materials = (0..<radii.count - 1).map { material($0 == radii.count - 2 ? shore : color) }
        return SCNNode(geometry: mesh)
    }

    private static var airframes: [String: SCNGeometry] = [:]

    // Traced in the original 1254px artwork; UVs and relief share these coordinates.
    private static func referenceAirframe(_ design: String) -> SCNGeometry {
        if let cached = airframes[design] { return cached }
        let half: [(Double, Double)]
        switch design {
        case "player":
            half = [(627, 44), (595, 182), (565, 284), (531, 354), (536, 441),
                    (502, 504), (475, 568), (373, 669), (243, 764), (145, 850),
                    (72, 799), (40, 905), (85, 983), (100, 1038), (135, 1002),
                    (375, 1038), (393, 1090), (430, 1063), (450, 1153),
                    (563, 1167), (600, 1138), (627, 1170)]
        case "scout":
            half = [(627, 25), (563, 226), (573, 254), (545, 351), (512, 374),
                    (480, 486), (166, 756), (145, 542), (129, 535), (110, 732),
                    (63, 799), (25, 994), (143, 940), (327, 873), (369, 910),
                    (296, 1067), (289, 1131), (430, 1048), (473, 1164),
                    (504, 1210), (548, 1102), (605, 1085), (627, 1120)]
        case "armored":
            half = [(627, 30), (587, 42), (531, 195), (510, 211), (490, 329),
                    (453, 286), (435, 245), (368, 232), (322, 277), (321, 386),
                    (350, 426), (349, 480), (261, 511), (232, 410), (188, 371),
                    (129, 388), (84, 465), (38, 634), (38, 812), (73, 908),
                    (129, 946), (208, 946), (253, 899), (273, 749), (321, 742),
                    (294, 810), (307, 886), (376, 930), (348, 968), (350, 1133),
                    (422, 1207), (455, 1191), (493, 1158), (552, 1174),
                    (582, 1087), (627, 1088)]
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
        let outline = half + half.dropFirst().dropLast().reversed().map { (1254 - $0.0, $0.1) }
        let edge = outline.map { SIMD2<Double>($0.0, $0.1) }
        // Ear clipping preserves concave wing tips, engine gaps and gun barrels.
        func cross(_ a: SIMD2<Double>, _ b: SIMD2<Double>, _ c: SIMD2<Double>) -> Double {
            (b.y - a.y) * (c.x - a.x) - (b.x - a.x) * (c.y - a.y)
        }
        var remaining = Array(edge.indices), faces: [(Int, Int, Int)] = []
        while remaining.count > 3 {
            var clipped = false
            for i in remaining.indices {
                let a = remaining[(i + remaining.count - 1) % remaining.count]
                let b = remaining[i], c = remaining[(i + 1) % remaining.count]
                guard cross(edge[a], edge[b], edge[c]) > 0.0001 else { continue }
                let containsVertex = remaining.contains { j in
                    j != a && j != b && j != c && cross(edge[a], edge[b], edge[j]) >= -0.0001
                        && cross(edge[b], edge[c], edge[j]) >= -0.0001 && cross(edge[c], edge[a], edge[j]) >= -0.0001
                }
                if !containsVertex {
                    faces.append((a, b, c)); remaining.remove(at: i); clipped = true; break
                }
            }
            precondition(clipped, "Aircraft outline must be a simple polygon")
        }
        faces.append((remaining[0], remaining[1], remaining[2]))
        let span = design == "boss" ? 146.0 : design == "scout" ? 54.0 : design == "armored" ? 67.0 : 74.0
        var vertices: [SCNVector3] = [], uv: [CGPoint] = []
        var vertexIDs: [String: Int32] = [:]
        func vertex(_ p: SIMD2<Double>, underside: Bool = false) -> Int32 {
            let key = "\(Int((p.x * 1000).rounded()))-\(Int((p.y * 1000).rounded()))-\(underside)"
            if let index = vertexIDs[key] { return index }
            let x = (p.x - 627) / 1254, y = (627 - p.y) / 1254
            func dome(_ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double) -> Double {
                exp(-pow((x - cx) / rx, 2) - pow((y - cy) / ry, 2))
            }
            var edgeDistance = Double.infinity
            for i in edge.indices {
                let a = edge[i], segment = edge[(i + 1) % edge.count] - a
                let t = max(0, min(1, simd_dot(p - a, segment) / simd_length_squared(segment)))
                edgeDistance = min(edgeDistance, simd_length(p - a - segment * t))
            }
            let cockpit = dome(0, 0.16, 0.045, 0.15) * 7
            let spine = dome(0, 0.02, 0.075, 0.40) * 4
            let engineX = design == "armored" ? 0.35 : design == "boss" ? 0.17 : 0.095
            let engines = (dome(-engineX, -0.24, 0.055, 0.20) + dome(engineX, -0.24, 0.055, 0.20)) * 6
            let height = underside ? -2.5 : 1.5 + (cockpit + spine + engines) * min(1, edgeDistance / 40)
            let index = Int32(vertices.count)
            vertices.append(SCNVector3(x * span, y * span, height * span / 74))
            uv.append(CGPoint(x: p.x / 1254, y: p.y / 1254))
            vertexIDs[key] = index
            return index
        }
        var top: [Int32] = [], sides: [Int32] = [], bottom: [Int32] = []
        func subdivide(_ a: SIMD2<Double>, _ b: SIMD2<Double>, _ c: SIMD2<Double>, depth: Int) {
            if depth == 0 { top += [vertex(a), vertex(b), vertex(c)]; return }
            let ab = (a + b) / 2, bc = (b + c) / 2, ca = (c + a) / 2
            subdivide(a, ab, ca, depth: depth - 1); subdivide(ab, b, bc, depth: depth - 1)
            subdivide(ca, bc, c, depth: depth - 1); subdivide(ab, bc, ca, depth: depth - 1)
        }
        for (a, b, c) in faces {
            subdivide(edge[a], edge[b], edge[c], depth: 3)
            bottom += [vertex(edge[c], underside: true), vertex(edge[b], underside: true), vertex(edge[a], underside: true)]
        }
        for i in edge.indices {
            let next = (i + 1) % edge.count
            for step in 0..<8 {
                let p = edge[i] + (edge[next] - edge[i]) * Double(step) / 8
                let q = edge[i] + (edge[next] - edge[i]) * Double(step + 1) / 8
                let a = vertex(p), b = vertex(q), c = vertex(p, underside: true), d = vertex(q, underside: true)
                sides += [a, c, b, b, c, d]
            }
        }
        var normals = Array(repeating: SIMD3<Float>.zero, count: vertices.count)
        for indices in [top, sides, bottom] {
            for face in stride(from: 0, to: indices.count, by: 3) {
                let a = Int(indices[face]), b = Int(indices[face + 1]), c = Int(indices[face + 2])
                let normal = simd_cross(SIMD3<Float>(vertices[b]) - SIMD3<Float>(vertices[a]),
                                        SIMD3<Float>(vertices[c]) - SIMD3<Float>(vertices[a]))
                normals[a] += normal; normals[b] += normal; normals[c] += normal
            }
        }
        assert(normals.allSatisfy { simd_length_squared($0) > 0 })
        let geometry = SCNGeometry(sources: [.init(vertices: vertices),
                                            .init(normals: normals.map { SCNVector3(simd_normalize($0)) }),
                                            .init(textureCoordinates: uv)],
                                   elements: [top, sides, bottom].map { SCNGeometryElement(indices: $0, primitiveType: .triangles) })
        let paint = SCNMaterial()
        let artwork = UIImage(named: "Ship-\(design)")
        assert(artwork != nil, "Missing original aircraft texture")
        paint.diffuse.contents = artwork
        paint.lightingModel = .physicallyBased
        paint.metalness.contents = 0.18
        paint.roughness.contents = 0.55
        paint.emission.contents = artwork; paint.emission.intensity = 0.10
        paint.diffuse.mipFilter = .linear
        let edgeMaterial = material(design == "player" ? 0x627785 : 0x30373D, metal: true)
        geometry.materials = [paint, edgeMaterial, edgeMaterial]
        airframes[design] = geometry
        return geometry
    }

    static func ship(_ kind: EntityKind? = nil, mission: Int = 1) -> SCNNode {
        let design = kind?.rawValue ?? "player"
        let root = SCNNode()
        let body = SCNNode(geometry: referenceAirframe(design))
        body.name = "airframe"; root.addChildNode(body)
        let boss = kind == .boss
        let accent: UInt32 = kind == nil ? cyan : [0xFF704B, 0xE26BFF, 0xFFB64F, 0x7BBEFF, 0xFF466D][(mission - 1) % 5]
        let span: Double = boss ? 146 : kind == .scout ? 54 : kind == .armored ? 67 : 74
        let engineX = kind == .armored ? 0.35 : boss ? 0.17 : 0.095
        for side in [-1.0, 1.0] {
            let x = side * engineX * span, y = -(kind == .armored ? 0.26 : 0.43) * span
            let nozzle = part(SCNCylinder(radius: CGFloat(span * 0.027), height: 2), 0x253D4A,
                              in: body, at: SCNVector3(x, y, 2), metal: true)
            nozzle.geometry?.firstMaterial = material(0x516571, metal: true)
            let flame = SCNCone(topRadius: CGFloat(span * 0.022), bottomRadius: 0.15, height: CGFloat(span * 0.16))
            flame.radialSegmentCount = 16
            let engine = part(flame, accent, in: body, at: SCNVector3(x, y - span * 0.08, 2), glow: true)
            engine.name = "engine"
        }
        if boss {
            // The six-turret carrier keeps its reference silhouette; mission equipment sits above it.
            for side in [-1.0, 1.0] { for row in 0..<3 {
                let x = side * [0.17, 0.22, 0.30][row] * span
                let y = [0.16, 0.015, -0.17][row] * span
                let turret = part(SCNCylinder(radius: 5, height: 3), 0x5E655E, in: body, at: SCNVector3(x, y, 5), metal: true)
                turret.eulerAngles.x = .pi / 2
                for barrel in -1...1 {
                    part(SCNCylinder(radius: 0.7, height: 9), 0x87919A, in: body,
                         at: SCNVector3(x + Double(barrel) * 1.7, y + 5, 7), metal: true)
                }
                box(2, 1, 1, accent, in: body, at: SCNVector3(x, y - 3, 7), glow: true)
            } }
            if mission == 2 || mission == 3 {
                for side in [-1.0, 1.0] {
                    box(5, CGFloat(mission == 3 ? 28 : 20), 4, 0x58616D, in: body, at: SCNVector3(side * 13, 0, 13))
                    box(1.2, 13, 1, accent, in: body, at: SCNVector3(side * 13, 0, 15.5), glow: true)
                }
            } else if mission == 4 {
                for side in [-1.0, 1.0] {
                    let fin = hull([(0, 14), (side * 17, -12), (side * 7, -20), (0, -8)], depth: 2, color: 0x7196B1, in: body)
                    fin.position = SCNVector3(side * 41, -10, 5)
                }
            } else if mission == 5 {
                let ring = part(SCNTorus(ringRadius: 15, pipeRadius: 1.3), accent, in: body, at: SCNVector3(0, 0, 17), glow: true)
                ring.eulerAngles.x = .pi / 2
                part(SCNSphere(radius: 6), accent, in: body, at: SCNVector3(0, 0, 17), glow: true)
            }
        }
        return root
    }

    static func groundUnit(_ size: ObstacleSize) -> SCNNode {
        let root = SCNNode()
        let r = CGFloat(size.radius)
        box(r * 1.5, r * 1.6, 9, 0x45545A, in: root)
        let turret = SCNNode(); turret.name = "turret"; root.addChildNode(turret)
        if size == .small {
            for x in [-r * 0.66, r * 0.66] { box(9, r * 1.8, 12, 0x222E32, in: root, at: SCNVector3(Float(x), 0, 1)) }
            box(22, 24, 15, 0x86927B, in: turret, at: SCNVector3(0, 0, 9))
            box(5, 34, 5, 0xB5BBA1, in: turret, at: SCNVector3(0, 20, 15))
        } else if size == .medium {
            let drum = part(SCNCylinder(radius: 22, height: 16), 0x747D7C, in: turret, at: SCNVector3(0, 0, 12))
            drum.eulerAngles.x = .pi / 2
            for x: Float in [-10, 10] { box(6, 37, 6, 0xB7C1BE, in: turret, at: SCNVector3(x, 19, 19)) }
        } else {
            box(37, 42, 22, 0x78888B, in: root, at: SCNVector3(0, 0, 14))
            box(4, 4, 30, 0xB0C1C4, in: root, at: SCNVector3(0, 0, 34))
            let dish = part(SCNCone(topRadius: 22, bottomRadius: 3, height: 10), cyan, in: turret, at: SCNVector3(0, 0, 49), metal: true)
            dish.eulerAngles.x = 0.7
        }
        return root
    }

    static func pickup(_ kind: EntityKind) -> SCNNode {
        let root = SCNNode()
        let colors: [EntityKind: UInt32] = [.crystal: orange, .repair: 0x7FF5B3, .shield: cyan, .power: 0xFF765A,
                                         .laser: 0x72F5EB, .spread: 0xACFF7B, .lightning: 0xCF95FF, .escort: 0x82B8FF, .rescue: 0xFFE29A]
        let color = colors[kind] ?? cyan
        if kind == .crystal {
            let crystal = SCNNode(); root.addChildNode(crystal)
            for sign: Float in [-1, 1] {
                let gem = SCNCone(topRadius: 0, bottomRadius: 9, height: 15); gem.radialSegmentCount = 5
                let node = part(gem, color, in: crystal, at: SCNVector3(0, sign * 7.5, 3), metal: true)
                if sign < 0 { node.eulerAngles.z = .pi }
            }
            crystal.eulerAngles.x = 0.35
        } else if kind == .rescue {
            box(26, 32, 5, 0x434D5C, in: root, at: SCNVector3(0, 0, -5))
            part(SCNSphere(radius: 6), 0xFFE3BC, in: root, at: SCNVector3(0, 9, 7))
            box(12, 15, 9, orange, in: root, at: SCNVector3(0, -3, 5))
            for x: Float in [-8, 8] {
                box(4, 16, 4, 0xE9C287, in: root, at: SCNVector3(x, 0, 4)).eulerAngles.z = x / 18
                box(4, 10, 4, 0x364D63, in: root, at: SCNVector3(x / 2, -14, 3))
            }
        } else {
            box(24, 24, 12, 0x354A60, in: root)
            let symbol = SCNNode(); root.addChildNode(symbol); symbol.position.z = 8
            switch kind {
            case .repair:
                box(5, 17, 3, color, in: symbol, glow: true); box(17, 5, 3, color, in: symbol, glow: true)
            case .shield:
                hull([(-8, 8), (8, 8), (7, -3), (0, -9), (-7, -3)], depth: 3, color: color, in: symbol)
            case .escort:
                let mini = ship(); mini.scale = SCNVector3(0.28, 0.28, 0.28); symbol.addChildNode(mini)
            case .spread:
                for angle in [-0.45, 0, 0.45] { box(3, 17, 3, color, in: symbol, glow: true).eulerAngles.z = Float(angle) }
            case .lightning, .power:
                hull([(2, 10), (-7, -1), (-1, -1), (-3, -10), (7, 3), (1, 3)], depth: 3, color: color, in: symbol)
            default:
                for x: Float in [-5, 5] { box(3, 18, 3, color, in: symbol, at: SCNVector3(x, 0, 0), glow: true) }
            }
        }
        let titles: [EntityKind: String] = [.crystal: "晶石", .repair: "维修", .shield: "护盾", .power: "过载", .laser: "激光", .spread: "散弹", .lightning: "雷电", .escort: "护航", .rescue: "SOS"]
        let text = SCNText(string: titles[kind] ?? "", extrusionDepth: 0.3)
        text.font = .systemFont(ofSize: 9, weight: .bold); text.flatness = 0.4
        let label = part(text, color, in: root, glow: true)
        let bounds = label.boundingBox
        label.position = SCNVector3(-(bounds.max.x + bounds.min.x) / 2, kind == .rescue ? 29 : -31, 12)
        return root
    }
}

@MainActor
final class CombatRenderer {
    let environment: TerrainScene
    var scene: SCNScene { environment.scene }
    var camera: SCNNode { environment.camera }
    private let player = ModelArt.ship()
    private let shield = SCNNode()
    private var entities: [Int: SCNNode] = [:]
    private var lanes: [Int: SCNNode] = [:]
    private var escorts: [SCNNode] = []
    private var wreck: SCNNode?
    private var wreckOrigin = Vector.zero
    private var lastSmoke = 0.0
    private var crashed = false
    private var bossBlast = false
    private var previous = Vector.zero
    private var attitude = FlightAttitude()
    private let reduced: Bool
    private let effects = SCNNode()
    private var effectSpeed = 1.0

    init(world: GameWorld, reducedEffects: Bool) {
        reduced = reducedEffects
        environment = TerrainScene(world: world)
        scene.rootNode.addChildNode(player)
        scene.rootNode.addChildNode(effects)
        let shell = SCNSphere(radius: 36); shell.segmentCount = 24
        let material = SCNMaterial(); material.diffuse.contents = UIColor(hex: ModelArt.cyan, alpha: 0.09)
        material.emission.contents = UIColor(hex: ModelArt.cyan, alpha: 0.15)
        material.transparency = 0.3; material.writesToDepthBuffer = false
        shell.materials = [material]; shield.geometry = shell
        let rim = ModelArt.part(SCNTorus(ringRadius: 35, pipeRadius: 0.8), ModelArt.cyan, in: shield, glow: true)
        rim.eulerAngles.x = .pi / 2
        scene.rootNode.addChildNode(shield)
        previous = world.player
        #if DEBUG
        validateModels()
        #endif
    }

    func update(_ world: GameWorld, speed: Double = 1, delta: Double = 1.0 / 60) {
        environment.update(world)
        effectSpeed = world.bossFallTime == nil ? speed : 1
        attitude.update(displacement: world.player - previous, delta: delta)
        previous = world.player
        player.position = SCNVector3(world.player.x, world.player.y, 65)
        let motionScale = reduced ? 0.25 : 1.0
        player.eulerAngles = SCNVector3(0.18 + (attitude.pitch - 0.18) * motionScale,
                                       attitude.roll * motionScale, -attitude.roll * 0.12 * motionScale)
        player.opacity = world.elapsed - world.lastPlayerHitAt < 1.25 && !reduced ? (sin(world.elapsed * 24) > 0 ? 1 : 0.45) : 1
        shield.position = player.position
        shield.isHidden = !world.shield || world.crashTime != nil
        if let time = world.crashTime {
            let t = min(1, time / 1.75)
            player.position = SCNVector3(world.player.x + sin(t * 4) * 18, world.player.y - t * 50, 65 - t * 95)
            player.eulerAngles = SCNVector3(t, t * 4, -t * 2)
            if time >= 1.75 && !crashed { crashed = true; burst(player.position, radius: 55); player.isHidden = true }
            if time < 1.75 && time > lastSmoke { lastSmoke = time + 0.12; smoke(player.position) }
        } else if world.health < world.loadout.maxHealth * 0.4 && world.elapsed > lastSmoke {
            lastSmoke = world.elapsed + (reduced ? 0.4 : 0.15); smoke(player.position)
        }
        if let time = world.bossFallTime, let wreck {
            let t = min(1, time / 3.2)
            wreck.position = SCNVector3(wreckOrigin.x + sin(t * 3) * 20, wreckOrigin.y - t * 75, 65 - t * 105)
            wreck.eulerAngles = SCNVector3(t * 0.8, t * 1.1, .pi + t * 0.5)
            if time > lastSmoke { lastSmoke = time + 0.16; smoke(wreck.position) }
            if time >= 3.2 && !bossBlast { bossBlast = true; burst(wreck.position, radius: 110); wreck.isHidden = true }
        }
        while escorts.count < world.escortPositions.count {
            let ship = ModelArt.ship(); ship.scale = SCNVector3(0.5, 0.5, 0.5)
            scene.rootNode.addChildNode(ship); escorts.append(ship)
        }
        for (index, node) in escorts.enumerated() {
            let p = world.escortPositions[index]
            node.position = SCNVector3(p.x, p.y, 65); node.eulerAngles = SCNVector3(0.18, attitude.roll * 0.75 * motionScale, -attitude.roll * 0.08 * motionScale)
            node.isHidden = world.crashTime != nil
        }
        let ids = Set(world.entities.map(\.id))
        for id in Array(entities.keys) where !ids.contains(id) { entities.removeValue(forKey: id)?.removeFromParentNode() }
        for entity in world.entities {
            let node: SCNNode
            if let existing = entities[entity.id] { node = existing }
            else {
                node = make(entity, mission: world.mission.id)
                entities[entity.id] = node; scene.rootNode.addChildNode(node)
            }
            let p = entity.position + entity.velocity * (world.crashTime ?? 0)
            node.position = SCNVector3(p.x, p.y, entity.kind == .obstacle ? -15 : 65)
            if entity.kind.isEnemy || entity.kind == .obstacle { node.opacity = world.elapsed - entity.lastHitAt < 0.12 ? 0.55 : 1 }
            if entity.kind.isEnemy { node.eulerAngles = SCNVector3(-0.16, reduced ? 0 : sin(entity.age * 2) * 0.14, .pi) }
            if entity.kind == .bolt || entity.kind == .hostile { node.eulerAngles.z = Float(atan2(entity.velocity.y, entity.velocity.x) - .pi / 2) }
            if entity.kind.isPickup {
                node.position.z = Float(65 + (reduced ? 0 : sin(entity.age * 2) * 5))
                node.eulerAngles = SCNVector3(0.22, reduced ? 0.2 : sin(entity.age * 1.4) * 0.5, world.mission.axis == .horizontal ? .pi / 2 : 0)
            }
            if let turret = node.childNode(withName: "turret", recursively: false) {
                let aim = world.player - entity.position
                turret.eulerAngles.z = Float(atan2(aim.y, aim.x) - .pi / 2)
            }
            if let bar = node.childNode(withName: "hp", recursively: false) { bar.scale.x = Float(max(0.001, entity.hp / entity.maxHP)) }
        }
        let laneIDs = Set(world.lanes.map(\.id))
        for id in Array(lanes.keys) where !laneIDs.contains(id) { lanes.removeValue(forKey: id)?.removeFromParentNode() }
        for lane in world.lanes {
            let node: SCNNode
            if let old = lanes[lane.id] { node = old }
            else {
                node = ModelArt.box(44, CGFloat(world.length), 1, 0xFF5247, in: scene.rootNode,
                                    at: SCNVector3(lane.x, world.length / 2, 61), glow: true)
                lanes[lane.id] = node
            }
            node.opacity = lane.active ? 0.7 : 0.14
        }
    }

    private func make(_ entity: Entity, mission: Int) -> SCNNode {
        if entity.kind.isEnemy {
            let node = ModelArt.ship(entity.kind, mission: mission)
            if entity.kind == .armored {
                let bar = ModelArt.box(30, 2, 1, ModelArt.orange, in: node, at: SCNVector3(0, -34, 12), glow: true)
                bar.name = "hp"
            }
            return node
        }
        if entity.kind == .obstacle {
            let node = ModelArt.groundUnit(entity.obstacleSize)
            let bar = ModelArt.box(CGFloat(entity.radius * 1.4), 2, 2, ModelArt.orange, in: node,
                                   at: SCNVector3(0, -entity.radius - 7, 30), glow: true)
            bar.name = "hp"
            return node
        }
        if entity.kind == .bolt || entity.kind == .hostile {
            let node = SCNNode()
            let color: UInt32 = entity.kind == .hostile ? 0xFF7954 : entity.projectileStyle == .spread ? 0xB2FF88 : entity.projectileStyle == .escort ? 0x8BAFFF : ModelArt.cyan
            let geometry = SCNCapsule(capRadius: entity.kind == .hostile ? 3.8 : 1.8, height: entity.kind == .hostile ? 11 : 19)
            geometry.radialSegmentCount = 6; geometry.capSegmentCount = 2
            ModelArt.part(geometry, color, in: node, glow: true)
            return node
        }
        return ModelArt.pickup(entity.kind)
    }

    func show(_ effect: BattleEffect, world: GameWorld) {
        func location(_ p: Vector) -> SCNVector3 { SCNVector3(p.x, p.y, 65) }
        switch effect {
        case let .explosion(p, boss): burst(location(p), radius: boss ? 65 : 23)
        case let .rubble(p, r): burst(SCNVector3(p.x, p.y, -5), radius: r)
        case let .pickup(p, _):
            let flash = ModelArt.part(SCNSphere(radius: 5), ModelArt.cyan, in: effects, at: location(p), glow: true)
            expire(flash, duration: 0.22, movement: SCNVector3(0, 0, 16), scale: 0.1)
        case let .impact(p): burst(location(p), radius: 5)
        case .damage: burst(location(world.player), radius: 12)
        case .emp: ring(location(world.player), radius: 500, color: ModelArt.cyan)
        case let .beam(a, b): trail([a, b], lightning: false)
        case let .lightningArc(points): trail(points, lightning: true)
        case .crash:
            lastSmoke = 0
            player.enumerateChildNodes { node, _ in if node.name == "engine" { node.isHidden = true } }
        case let .bossDown(p):
            wreckOrigin = p; lastSmoke = 0
            let node = ModelArt.ship(.boss, mission: world.mission.id)
            node.position = location(p); node.eulerAngles.z = .pi
            node.enumerateChildNodes { child, _ in if child.name == "engine" { child.isHidden = true } }
            scene.rootNode.addChildNode(node); wreck = node
            burst(location(p), radius: 42)
        default: break
        }
    }

    private func expire(_ node: SCNNode, duration: Double, movement: SCNVector3 = SCNVector3Zero, scale: CGFloat = 1) {
        let duration = duration / effectSpeed
        node.runAction(.sequence([.group([.moveBy(x: CGFloat(movement.x), y: CGFloat(movement.y), z: CGFloat(movement.z), duration: duration),
                                         .scale(to: scale, duration: duration), .fadeOut(duration: duration)]), .removeFromParentNode()]))
    }

    private func ring(_ point: SCNVector3, radius: Double, color: UInt32) {
        let node = ModelArt.part(SCNTorus(ringRadius: 10, pipeRadius: 0.6), color, in: effects, at: point, glow: true)
        node.eulerAngles.x = .pi / 2
        expire(node, duration: 0.65, scale: radius / 10)
    }

    private func burst(_ point: SCNVector3, radius: Double) {
        // Bounded low-poly debris avoids sprite particles and keeps fill cost predictable.
        guard effects.childNodes.count < (reduced ? 60 : 180) else { return }
        ring(point, radius: radius * 1.4, color: ModelArt.orange)
        for i in 0..<(reduced ? 4 : 9) {
            let angle = Double(i) * 2.399
            let sphere = SCNSphere(radius: max(1, radius * 0.16)); sphere.segmentCount = 6
            let node = ModelArt.part(sphere, i.isMultiple(of: 3) ? 0xFFE7B3 : ModelArt.orange, in: effects, at: point, glow: true)
            expire(node, duration: 0.3 + Double(i % 3) * 0.12,
                   movement: SCNVector3(cos(angle) * radius, sin(angle) * radius, Double(i) * 3), scale: 0.15)
        }
    }

    private func smoke(_ point: SCNVector3) {
        guard effects.childNodes.count < (reduced ? 60 : 180) else { return }
        let sphere = SCNSphere(radius: 7); sphere.segmentCount = 7
        let node = ModelArt.part(sphere, 0x55565F, in: effects, at: point)
        node.opacity = 0.6
        let flame = ModelArt.part(SCNCone(topRadius: 5, bottomRadius: 0, height: 19), ModelArt.orange, in: effects, at: point, glow: true)
        expire(flame, duration: 0.28, movement: SCNVector3(0, -9, 6), scale: 0.2)
        expire(node, duration: 1.2, movement: SCNVector3(14, -30, 15), scale: 3)
    }

    private func trail(_ points: [Vector], lightning: Bool) {
        guard points.count >= 2 else { return }
        let root = SCNNode(); effects.addChildNode(root)
        for (a, b) in zip(points, points.dropFirst()) {
            var knots = [a]
            if lightning {
                let delta = b - a
                for i in 1..<5 { knots.append(a + delta * (Double(i) / 5) + Vector(x: i.isMultiple(of: 2) ? 8 : -8, y: 0)) }
            }
            knots.append(b)
            for (start, end) in zip(knots, knots.dropFirst()) {
                let d = end - start
                let cylinder = SCNCylinder(radius: lightning ? 1.8 : 2.5, height: d.length)
                cylinder.radialSegmentCount = 6
                let node = ModelArt.part(cylinder, lightning ? 0xD3A7FF : ModelArt.cyan, in: root,
                                         at: SCNVector3((start.x + end.x) / 2, (start.y + end.y) / 2, 65), glow: true)
                node.eulerAngles.z = Float(atan2(d.y, d.x) - .pi / 2)
            }
        }
        expire(root, duration: lightning ? 0.22 : 0.13)
    }

    #if DEBUG
    var bankAngle: Double { Double(player.eulerAngles.y) }

    private func validateModels() {
        var models = [ModelArt.ship(), ModelArt.ship(.scout), ModelArt.ship(.armored)]
        models += (1...5).map { ModelArt.ship(.boss, mission: $0) }
        models += ObstacleSize.allCases.map { ModelArt.groundUnit($0) }
        let pickups = [EntityKind.crystal, .repair, .shield, .power, .laser, .spread, .lightning, .escort, .rescue].map { ModelArt.pickup($0) }
        for pickup in pickups {
            pickup.enumerateChildNodes { node, _ in assert(!(node.geometry is SCNTorus), "Pickups have no outer rings") }
        }
        models += pickups
        for model in models {
            let bounds = model.boundingBox
            assert(bounds.max.z - bounds.min.z > 2, "Every model must have physical depth")
            model.enumerateChildNodes { child, _ in
                if let geometry = child.geometry {
                    assert(!(geometry is SCNPlane), "World art cannot be a billboard")
                    assert(!geometry.materials.isEmpty)
                    if geometry.materials.contains(where: { $0.diffuse.contents is UIImage }) {
                        assert(child.name == "airframe")
                        assert(geometry.sources(for: .texcoord).count == 1)
                        assert(geometry.elements.count == 3, "Textured hull has top, side walls and underside")
                        assert(geometry.boundingBox.max.z - geometry.boundingBox.min.z > 8)
                    }
                }
            }
        }
    }
    #endif
}

@MainActor
final class TerrainScene {
    let scene = SCNScene()
    let camera = SCNNode()
    private let surface = SCNMaterial()
    private var tiles: [SCNNode] = []
    private var walls: [SCNNode] = []
    private var structures: [SCNNode] = []
    private let horizontal: Bool
    private let biome: Biome
    private var lastWallUpdate = -Double.infinity
    private var tileLength = 1200.0

    init(world: GameWorld) {
        horizontal = world.mission.axis == .horizontal
        biome = world.mission.biome
        camera.camera = SCNCamera()
        camera.camera?.usesOrthographicProjection = true
        camera.camera?.orthographicScale = 390
        camera.camera?.zFar = 4000
        camera.camera?.wantsHDR = true
        camera.camera?.bloomIntensity = 0.25
        camera.camera?.bloomThreshold = 1.2
        scene.background.contents = UIColor(hex: 0x04101E)
        camera.position = SCNVector3(world.width / 2, world.length / 2, 1100)
        camera.look(at: SCNVector3(world.width / 2, world.length / 2, 0))
        scene.rootNode.addChildNode(camera)
        if horizontal { camera.eulerAngles.z = .pi / 2 }
        let sun = SCNNode()
        sun.light = SCNLight()
        sun.light?.type = .directional
        sun.light?.color = UIColor(hex: biome == .glacier ? 0xB8E4FF : 0xFFE2B6)
        sun.light?.intensity = 950
        sun.light?.castsShadow = true
        sun.light?.shadowColor = UIColor(hex: 0x07131F, alpha: 0.65)
        sun.light?.shadowMapSize = CGSize(width: 1024, height: 1024)
        sun.light?.orthographicScale = 1000
        sun.light?.shadowRadius = 3
        sun.position = SCNVector3(-350, 650, 900)
        sun.look(at: SCNVector3(195, 390, 0))
        scene.rootNode.addChildNode(sun)
        let fill = SCNNode()
        fill.light = SCNLight(); fill.light?.type = .ambient
        fill.light?.color = UIColor(hex: 0xD3E0EB); fill.light?.intensity = 300
        scene.rootNode.addChildNode(fill)
        let colors: [Biome: UInt32] = [.ocean: 0x124E63, .harbor: 0x102B40, .desert: 0x9B6241, .glacier: 0x28566B, .orbit: 0x080F20]
        surface.diffuse.contents = UIColor(hex: colors[biome]!)
        surface.lightingModel = biome == .orbit ? .constant : .physicallyBased
        surface.metalness.contents = biome == .ocean || biome == .harbor ? 0.65 : 0.15
        surface.roughness.contents = biome == .ocean || biome == .harbor ? 0.25 : 0.75
        surface.isDoubleSided = true
        let geometry = groundMesh()
        for _ in 0..<3 {
            let tile = SCNNode(geometry: geometry)
            scene.rootNode.addChildNode(tile); tiles.append(tile)
        }
        if horizontal {
            for _ in 0..<2 {
                let wall = SCNNode(); scene.rootNode.addChildNode(wall); walls.append(wall)
            }
        }
        for index in 0..<16 {
            let structure = makeStructure(index)
            scene.rootNode.addChildNode(structure); structures.append(structure)
        }
        if biome == .orbit {
            for index in 0..<110 {
                let star = SCNSphere(radius: index.isMultiple(of: 11) ? 1.7 : 0.7); star.segmentCount = 4
                ModelArt.part(star, 0xA5C8E5, in: scene.rootNode,
                              at: SCNVector3(Double(index * 173 % 650) - 130, Double(index * 293 % 1000) - 110, -60), glow: true)
            }
            let planet = ModelArt.part(SCNSphere(radius: 165), 0x184F76, in: scene.rootNode, at: SCNVector3(400, 570, -360))
            planet.geometry?.firstMaterial = ModelArt.material(0x184F76)
        }
        update(world)
    }

    func update(_ world: GameWorld) {
        let scroll = world.elapsed * GameWorld.groundSpeed
        let offset = scroll.truncatingRemainder(dividingBy: tileLength)
        for (index, tile) in tiles.enumerated() { tile.position.y = Float(Double(index - 1) * tileLength - offset) }
        if horizontal {
            // Geometry updates at 20 Hz; the rim outline below remains exact every render frame.
            if world.elapsed - lastWallUpdate >= 0.05 || world.elapsed < lastWallUpdate {
                lastWallUpdate = world.elapsed
                for (side, wall) in walls.enumerated() { wall.geometry = canyonMesh(world, upper: side == 0) }
            }
        }
        for (index, structure) in structures.enumerated() {
            let forward = (Double(index) * 129.75 - scroll).truncatingRemainder(dividingBy: 2076)
            let y = forward < -160 ? forward + 2076 : forward
            let left = index.isMultiple(of: 2)
            if horizontal {
                let bounds = world.corridor(at: y)
                structure.position = SCNVector3(left ? bounds.lowerBound - 46 : bounds.upperBound + 46, y, -25)
            } else {
                let x = left ? -5.0 + Double(index % 3) * 17 : 380.0 - Double(index % 3) * 17
                structure.position = SCNVector3(x, y, biome == .ocean ? -55 : height(x, y + scroll))
            }
        }
    }

    private func height(_ x: Double, _ y: Double) -> Double {
        let phase = y / tileLength * .pi * 2
        let ridge = pow(abs(sin(x * 0.013 + sin(phase) * 1.5)), 3)
        let edge = min(1, pow(abs(x - 195) / 165, 2))
        switch biome {
        case .ocean: return -65 + sin(x * 0.05 + phase * 8) * 2
        case .desert: return -55 + ridge * (15 + edge * 48) * (0.7 + 0.3 * cos(phase * 3))
        case .orbit: return -800
        case .harbor: return -65
        case .glacier: return -65 + sin(x * 0.04 + phase * 4) * 4
        }
    }

    private func groundMesh() -> SCNGeometry {
        let columns = 32, rows = 60
        var vertices: [SCNVector3] = [], uv: [CGPoint] = [], indices: [Int32] = []
        for row in 0...rows { for column in 0...columns {
            let x = -220 + Double(column) / Double(columns) * 1220
            let y = Double(row) / Double(rows) * tileLength
            vertices.append(SCNVector3(x, y, height(x, y)))
            uv.append(CGPoint(x: Double(column) / Double(columns), y: 1 - Double(row) / Double(rows)))
        } }
        for row in 0..<rows { for column in 0..<columns {
            let a = Int32(row * (columns + 1) + column), b = a + Int32(columns + 1)
            indices += [a, a + 1, b, a + 1, b + 1, b]
        } }
        return mesh(vertices, uv: uv, indices: indices)
    }

    private func canyonMesh(_ world: GameWorld, upper: Bool) -> SCNGeometry {
        var vertices: [SCNVector3] = [], uv: [CGPoint] = [], indices: [Int32] = []
        let rows = 48
        for row in 0...rows {
            let y = -60 + Double(row) * (world.length + 120) / Double(rows)
            let bounds = world.corridor(at: y)
            let rim = upper ? bounds.lowerBound : bounds.upperBound
            let distance = y + world.elapsed * GameWorld.groundSpeed
            for band in 0..<4 {
                let relief = sin(distance * 0.029) * 10 + cos(distance * 0.061) * 5
                let outward = [0.0, 28 + relief, 92 + relief * 2, 400][band]
                let z = [-25.0, 12 + relief, 55 + relief, 20][band]
                vertices.append(SCNVector3(rim + (upper ? -outward : outward), y, z))
                uv.append(CGPoint(x: distance / 600, y: upper ? 0.4 - outward / 1000 : 0.6 + outward / 1000))
            }
        }
        for row in 0..<rows { for band in 0..<3 {
            let a = Int32(row * 4 + band), b = a + 4
            // Opposite banks have opposite winding so both receive the same sunlight.
            indices += upper ? [a, b, a + 1, a + 1, b, b + 1] : [a, a + 1, b, a + 1, b + 1, b]
        } }
        let geometry = mesh(vertices, uv: uv, indices: indices)
        geometry.materials = [ModelArt.material(biome == .glacier ? 0x9BCBD6 : 0x344557)]
        return geometry
    }

    private func mesh(_ vertices: [SCNVector3], uv: [CGPoint], indices: [Int32]) -> SCNGeometry {
        assert(vertices.count == uv.count && indices.count.isMultiple(of: 3))
        assert(vertices.allSatisfy { $0.x.isFinite && $0.y.isFinite && $0.z.isFinite })
        assert(indices.allSatisfy { $0 >= 0 && Int($0) < vertices.count })
        var normals = Array(repeating: SIMD3<Float>.zero, count: vertices.count)
        for face in stride(from: 0, to: indices.count, by: 3) {
            let a = Int(indices[face]), b = Int(indices[face + 1]), c = Int(indices[face + 2])
            let p = SIMD3<Float>(vertices[a].x, vertices[a].y, vertices[a].z)
            let q = SIMD3<Float>(vertices[b].x, vertices[b].y, vertices[b].z)
            let r = SIMD3<Float>(vertices[c].x, vertices[c].y, vertices[c].z)
            let normal = simd_cross(q - p, r - p)
            normals[a] += normal; normals[b] += normal; normals[c] += normal
        }
        let normalized = normals.map { normal -> SCNVector3 in
            assert(simd_length_squared(normal) > 0)
            return SCNVector3(simd_normalize(normal))
        }
        let geometry = SCNGeometry(sources: [.init(vertices: vertices), .init(normals: normalized), .init(textureCoordinates: uv)],
                                   elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)])
        geometry.materials = [surface]
        return geometry
    }

    private func makeStructure(_ index: Int) -> SCNNode {
        let root = SCNNode()
        switch biome {
        case .ocean:
            let island = ModelArt.island(seed: index, color: index.isMultiple(of: 2) ? 0x456B5E : 0x58745D)
            island.scale = SCNVector3(0.85 + Float(index % 3) * 0.12, 0.8 + Float(index % 4) * 0.1, 1)
            root.addChildNode(island)
            for i in 0..<5 {
                let tree = ModelArt.part(SCNCone(topRadius: 0, bottomRadius: 10, height: 26), 0x234C41, in: root,
                                         at: SCNVector3(i * 13 - 26, i * 22 - 44, 30))
                tree.eulerAngles.x = .pi / 2
            }
            if index.isMultiple(of: 3) {
                ModelArt.box(27, 42, 18, 0xB8C0BA, in: root, at: SCNVector3(0, 5, 27))
                ModelArt.box(20, 4, 2, ModelArt.cyan, in: root, at: SCNVector3(0, 5, 37), glow: true)
            }
        case .harbor:
            ModelArt.box(74, 100, 13, 0x455263, in: root)
            for i in 0..<3 {
                let height = 27 + CGFloat((index + i) % 4) * 12
                let x = Float(i * 21 - 21)
                ModelArt.box(17, 48, height, i == 1 ? 0x536782 : 0x3E4A61, in: root, at: SCNVector3(x, 0, Float(height / 2)))
                for row in 0..<4 {
                    ModelArt.box(10, 2, 1, index.isMultiple(of: 2) ? 0x48CBDC : 0xBD6DE3, in: root,
                                 at: SCNVector3(x, Float(row * 10 - 17), Float(height + 1)), glow: true)
                }
            }
            ModelArt.box(3, 85, 3, 0xE4A254, in: root, at: SCNVector3(-31, 0, 12), glow: true)
        case .desert, .glacier:
            let ice = biome == .glacier
            for i in 0..<5 {
                let cone = SCNCone(topRadius: ice ? 0 : 13, bottomRadius: CGFloat(20 + i * 4), height: CGFloat(35 + i * 10))
                cone.radialSegmentCount = ice ? 5 : 6
                let rock = ModelArt.part(cone, ice ? (i.isMultiple(of: 2) ? 0xACD9E3 : 0x629BAF) : (i.isMultiple(of: 2) ? 0xAF7954 : 0x704737),
                                         in: root, at: SCNVector3(i * 13 - 26, i * 26 - 52, 16))
                rock.eulerAngles = SCNVector3(.pi / 2, Float(i) * 0.25, Float(i) * 0.4)
            }
        case .orbit:
            ModelArt.box(45, 75, 15, 0x66798F, in: root, at: SCNVector3(0, 0, 775))
            for side: Float in [-1, 1] {
                ModelArt.box(44, 88, 3, 0x183C66, in: root, at: SCNVector3(side * 46, 0, 778))
                for row in 0..<8 { ModelArt.box(44, 1, 1, 0x6F9CBD, in: root, at: SCNVector3(side * 46, Float(row * 11 - 39), 781)) }
            }
            ModelArt.box(4, 48, 2, ModelArt.cyan, in: root, at: SCNVector3(0, 0, 786), glow: true)
        }
        return root
    }
}

struct ModelPreview: UIViewRepresentable {
    enum Content { case aircraft, hangar, campaign, orbit, departure }
    let content: Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.accessibilityElementsHidden = true
        if content == .orbit || content == .departure {
            let mission = Mission.campaign[content == .orbit ? 4 : 0]
            let environment = TerrainScene(world: GameWorld(mission: mission, loadout: Loadout()))
            let ship = ModelArt.ship(content == .orbit ? .boss : nil, mission: mission.id)
            ship.position = SCNVector3(195, 430, 85)
            ship.eulerAngles = SCNVector3(0.3, -0.25, -0.25)
            ship.scale = SCNVector3(2, 2, 2)
            environment.scene.rootNode.addChildNode(ship)
            view.scene = environment.scene; view.pointOfView = environment.camera
            view.antialiasingMode = .multisampling2X
            view.isUserInteractionEnabled = false
            return view
        }
        let scene = SCNScene()
        let camera = SCNNode(); camera.camera = SCNCamera()
        camera.camera?.usesOrthographicProjection = true
        camera.camera?.zFar = 2500
        let sun = SCNNode(); sun.light = SCNLight(); sun.light?.type = .directional
        sun.light?.intensity = 1100; sun.light?.castsShadow = true
        sun.eulerAngles = SCNVector3(-0.45, -0.6, 0)
        scene.rootNode.addChildNode(sun)
        let ambient = SCNNode(); ambient.light = SCNLight(); ambient.light?.type = .ambient
        ambient.light?.intensity = 400; scene.rootNode.addChildNode(ambient)
        if content == .campaign {
            camera.position = SCNVector3(195, 390, 1100); camera.camera?.orthographicScale = 390
            ModelArt.box(1000, 1800, 15, 0x143D52, in: scene.rootNode, at: SCNVector3(195, 390, -40))
            let points = [(0.25, 0.67), (0.73, 0.55), (0.30, 0.43), (0.76, 0.32), (0.44, 0.21)]
            let colors: [UInt32] = [0x557E65, 0x566B86, 0xB8824F, 0x9FCAD6, 0x515D7A]
            for (index, point) in points.enumerated() {
                let island = SCNNode(); island.position = SCNVector3(point.0 * 390, (1 - point.1) * 780, 0)
                scene.rootNode.addChildNode(island)
                let land = ModelArt.island(seed: index, color: colors[index], shore: 0x718991)
                land.scale = SCNVector3(1.05, 0.65, 0.75)
                island.addChildNode(land)
                for i in 0..<6 {
                    let x = Float(i * 19 % 77 - 38), y = Float(i * 29 % 65 - 32)
                    if index == 1 || index == 4 {
                        ModelArt.box(10, 17, CGFloat(14 + i * 3), 0x8896AA, in: island, at: SCNVector3(x, y, 20))
                        ModelArt.box(8, 2, 1, ModelArt.cyan, in: island, at: SCNVector3(x, y, Float(28 + i * 2)), glow: true)
                    } else {
                        let rock = SCNCone(topRadius: 0, bottomRadius: 12, height: CGFloat(20 + i * 3)); rock.radialSegmentCount = 5
                        ModelArt.part(rock, colors[index], in: island, at: SCNVector3(x, y, 20)).eulerAngles.x = .pi / 2
                    }
                }
            }
        } else {
            let ship = ModelArt.ship(); scene.rootNode.addChildNode(ship)
            if content == .hangar {
                camera.position = SCNVector3(0, -80, 150); camera.look(at: SCNVector3Zero)
                camera.camera?.orthographicScale = 51
                ship.eulerAngles.z = -0.3
                ModelArt.box(220, 240, 5, 0x1C2C3C, in: scene.rootNode, at: SCNVector3(0, 0, -18))
                for i in -4...4 {
                    ModelArt.box(1, 240, 1, 0x3B5365, in: scene.rootNode, at: SCNVector3(i * 24, 0, -15))
                    ModelArt.box(220, 1, 1, 0x3B5365, in: scene.rootNode, at: SCNVector3(0, i * 24, -15))
                }
                for x: Float in [-42, 42] { ModelArt.box(2, 92, 1, ModelArt.cyan, in: scene.rootNode, at: SCNVector3(x, 0, -14), glow: true) }
                if !reduceMotion { ship.runAction(.repeatForever(.sequence([.rotateBy(x: 0, y: 0.25, z: 0.2, duration: 3), .rotateBy(x: 0, y: -0.25, z: -0.2, duration: 3)]))) }
            } else {
                camera.position = SCNVector3(0, 0, 150); camera.camera?.orthographicScale = 40
            }
        }
        scene.rootNode.addChildNode(camera)
        view.scene = scene; view.pointOfView = camera
        view.backgroundColor = .clear; view.isOpaque = false
        view.antialiasingMode = .multisampling2X
        view.preferredFramesPerSecond = 30
        view.isPlaying = content == .hangar && !reduceMotion
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        view.scene?.isPaused = reduceMotion
    }
    static func dismantleUIView(_ view: SCNView, coordinator: ()) { view.isPlaying = false; view.scene = nil }
}
