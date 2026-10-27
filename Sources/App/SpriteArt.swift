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
        if metal && !glow {
            let texture = UIImage(named: "Surface-metal")
            assert(texture != nil)
            result.name = "original-armor"
            result.diffuse.contents = texture
            result.multiply.contents = UIColor(hex: color)
            result.diffuse.mipFilter = .linear
            result.metalness.contents = 0.25; result.roughness.contents = 0.62
        }
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

    static func rockMaterial(_ tint: UInt32) -> SCNMaterial {
        let key = "rock-\(tint)"
        if let cached = materials[key] { return cached }
        let result = SCNMaterial()
        let artwork = UIImage(named: "Surface-rock")
        assert(artwork != nil)
        result.diffuse.contents = artwork
        result.diffuse.wrapS = .repeat; result.diffuse.wrapT = .repeat
        result.diffuse.mipFilter = .linear
        result.multiply.contents = UIColor(hex: tint)
        result.lightingModel = .physicallyBased
        result.roughness.contents = 0.9; result.metalness.contents = 0
        materials[key] = result
        return result
    }

    private static var rocks: [Int: SCNGeometry] = [:]

    static func rock(seed: Int, tint: UInt32) -> SCNNode {
        let variant = seed % 7
        let geometry: SCNGeometry
        if let cached = rocks[variant] { geometry = cached.copy() as! SCNGeometry }
        else {
            let columns = 24, rows = 12
            var vertices = [SCNVector3(0, 0, 39)]
            for row in 1..<rows {
                let latitude = Double(row) / Double(rows) * .pi
                for column in 0..<columns {
                    let angle = Double(column) / Double(columns) * .pi * 2
                    let ridges = 1 + sin(angle * 3 + Double(variant)) * sin(latitude) * 0.18
                        + cos(angle * 5 - latitude * 4 + Double(variant)) * 0.09
                    vertices.append(SCNVector3(cos(angle) * sin(latitude) * ridges * 32,
                                              sin(angle) * sin(latitude) * ridges * 43,
                                              cos(latitude) * 34 + 5))
                }
            }
            let bottom = Int32(vertices.count); vertices.append(SCNVector3(0, 0, -29))
            var indices: [Int32] = []
            for column in 0..<columns {
                let a = Int32(1 + column), b = Int32(1 + (column + 1) % columns)
                indices += [0, a, b]
                for row in 0..<rows - 2 {
                    let c = a + Int32(row * columns), d = b + Int32(row * columns)
                    indices += [c, c + Int32(columns), d, d, c + Int32(columns), d + Int32(columns)]
                }
                let offset = Int32((rows - 2) * columns)
                indices += [a + offset, bottom, b + offset]
            }
            let uv = vertices.map { CGPoint(x: Double($0.x) / 85 + 0.5, y: Double($0.y) / 100 + 0.5) }
            geometry = mesh(vertices, uv: uv, indices: indices)
            rocks[variant] = geometry.copy() as? SCNGeometry
        }
        geometry.materials = [rockMaterial(tint)]
        return SCNNode(geometry: geometry)
    }

    static func mesh(_ vertices: [SCNVector3], uv: [CGPoint], indices: [Int32]) -> SCNGeometry {
        assert(vertices.count == uv.count && indices.count.isMultiple(of: 3))
        assert(vertices.allSatisfy { $0.x.isFinite && $0.y.isFinite && $0.z.isFinite })
        assert(indices.allSatisfy { $0 >= 0 && Int($0) < vertices.count })
        var normals = Array(repeating: SIMD3<Float>.zero, count: vertices.count)
        for face in stride(from: 0, to: indices.count, by: 3) {
            let a = Int(indices[face]), b = Int(indices[face + 1]), c = Int(indices[face + 2])
            let normal = simd_cross(SIMD3<Float>(vertices[b]) - SIMD3<Float>(vertices[a]),
                                    SIMD3<Float>(vertices[c]) - SIMD3<Float>(vertices[a]))
            normals[a] += normal; normals[b] += normal; normals[c] += normal
        }
        assert(normals.allSatisfy { simd_length_squared($0) > 0 })
        return SCNGeometry(sources: [.init(vertices: vertices),
                                     .init(normals: normals.map { SCNVector3(simd_normalize($0)) }),
                                     .init(textureCoordinates: uv)],
                           elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)])
    }

    static func island(seed: Int, color: UInt32, shore: UInt32 = 0xAD9E7A) -> SCNNode {
        let sectors = 64
        let radii: [Float] = [0.01, 0.16, 0.32, 0.48, 0.64, 0.78, 0.87, 0.98, 1]
        var rings: [[SIMD3<Float>]] = []
        for (band, radius) in radii.enumerated() {
            rings.append((0..<sectors).map { sector in
                let angle = Float(sector) / Float(sectors) * .pi * 2
                let noise = 1 + sin(angle * 3 + Float(seed)) * 0.19 + cos(angle * 5 - Float(seed)) * 0.11
                let elevation: Float = [44, 41, 35, 28, 20, 11, 4, 0, -5][band]
                let x = cos(angle) * radius * noise * 59, y = sin(angle) * radius * noise * 92
                let crags = sin(x * 0.17 + Float(seed)) * cos(y * 0.12) * 9 * (1 - radius)
                return SIMD3(x, y, elevation + (band < 6 ? crags + sin(angle * 4 + Float(seed)) * radius * (1 - radius) * 20 : 0))
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
        let uv = vertices.map { CGPoint(x: Double($0.x) / 118 + 0.5, y: Double($0.y) / 184 + 0.5) }
        let mesh = SCNGeometry(sources: [.init(vertices: vertices), .init(normals: normals), .init(textureCoordinates: uv)], elements: elements)
        let land = rockMaterial(color)
        let coast = rockMaterial(shore)
        mesh.materials = (0..<radii.count - 1).map { $0 == radii.count - 2 ? coast : land }
        return SCNNode(geometry: mesh)
    }

    private static var coastGeometry: SCNGeometry?

    static func coastalIsland() -> SCNNode {
        if let coastGeometry { return SCNNode(geometry: coastGeometry) }
        let divisions = 32
        var vertices: [SCNVector3] = [], uv: [CGPoint] = [], indices: [Int32] = []
        for row in 0...divisions { for column in 0...divisions {
            let u = Double(column) / Double(divisions), v = Double(row) / Double(divisions)
            let ridge = exp(-pow((u - 0.5) / 0.19, 2)) * pow(sin(v * .pi), 2)
            vertices.append(SCNVector3((u - 0.5) * 190, (v - 0.5) * 245, 2 + ridge * 36))
            uv.append(CGPoint(x: u, y: 1 - v))
        } }
        for row in 0..<divisions { for column in 0..<divisions {
            let a = Int32(row * (divisions + 1) + column), b = a + Int32(divisions + 1)
            indices += [a, a + 1, b, a + 1, b + 1, b]
        } }
        let geometry = mesh(vertices, uv: uv, indices: indices)
        let material = SCNMaterial()
        let artwork = UIImage(named: "Island-v16"); assert(artwork != nil)
        material.diffuse.contents = artwork; material.diffuse.mipFilter = .linear
        material.lightingModel = .physicallyBased; material.roughness.contents = 1.0
        material.multiply.contents = UIColor(hex: 0x83939F)
        material.shaderModifiers = [.fragment: "#pragma body\nif (_output.color.a < 0.05) discard_fragment();"]
        geometry.materials = [material]
        coastGeometry = geometry
        return SCNNode(geometry: geometry)
    }

    private static var airframes: [String: SCNGeometry] = [:]
    private static let modelSpans: [String: Double] = ["player": 60, "scout": 44, "armored": 64, "interceptor": 48, "boss": 146, "pilot": 34, "supply": 28, "tank": 74, "turret": 76]

    // Traced in the original 1254px artwork; UVs and relief share these coordinates.
    private static func referenceAirframe(_ design: String) -> SCNGeometry {
        if let cached = airframes[design] { return cached }
        let half: [(Double, Double)]
        switch design {
        case "player":
            half = [(627, 98), (596, 99), (574, 120), (537, 188), (519, 244),
                    (508, 303), (495, 303), (478, 254), (457, 230), (399, 227),
                    (376, 246), (337, 329), (326, 387), (127, 486), (115, 422),
                    (112, 351), (73, 351), (65, 423), (48, 426), (9, 648),
                    (10, 676), (283, 834), (299, 829), (305, 850), (327, 885),
                    (234, 974), (211, 1124), (228, 1138), (352, 1062), (356, 1015),
                    (388, 1027), (421, 1027), (444, 1015), (475, 976), (490, 939),
                    (499, 944), (520, 1019), (540, 1038), (627, 1038)]
        case "scout":
            half = [(627, 36), (597, 43), (565, 96), (536, 173), (515, 307),
                    (453, 378), (371, 409), (354, 350), (350, 250), (322, 244),
                    (313, 347), (291, 367), (279, 453), (22, 607), (15, 735),
                    (393, 780), (483, 820), (505, 901), (337, 1014), (320, 976),
                    (295, 1006), (296, 1153), (317, 1170), (338, 1144),
                    (533, 1111), (557, 1080), (562, 1122), (592, 1154), (627, 1158)]
        case "armored":
            half = [(627, 75), (615, 116), (587, 135), (554, 203), (522, 238),
                    (532, 270), (510, 339), (475, 380), (464, 318), (441, 293),
                    (381, 293), (363, 319), (344, 414), (288, 438), (272, 359),
                    (250, 336), (191, 335), (171, 364), (154, 461), (50, 516),
                    (18, 552), (15, 627), (54, 669), (371, 794), (447, 849),
                    (489, 842), (508, 875), (517, 945), (374, 996), (365, 934),
                    (346, 897), (330, 918), (295, 980), (295, 1090), (332, 1153),
                    (351, 1160), (372, 1097), (556, 1119), (591, 1115), (627, 1158)]
        case "interceptor":
            half = [(627, 5), (581, 136), (529, 350), (536, 397), (455, 489),
                    (157, 725), (129, 675), (133, 615), (117, 582), (139, 466),
                    (126, 463), (92, 579), (78, 588), (7, 834), (21, 870),
                    (75, 841), (363, 973), (384, 898), (403, 995), (448, 1018),
                    (493, 1004), (531, 951), (549, 980), (402, 1102), (374, 1232),
                    (558, 1146), (591, 1117), (614, 1183), (627, 1185)]
        case "supply":
            half = [(627, 142), (556, 122), (389, 123), (340, 103), (211, 114),
                    (90, 223), (82, 352), (106, 420), (106, 835), (83, 891),
                    (85, 1019), (207, 1138), (337, 1145), (383, 1127), (627, 1127)]
        case "pilot": half = []
        case "tank":
            half = [(627, 61), (607, 64), (603, 288), (481, 290), (461, 267),
                    (440, 242), (318, 244), (283, 273), (268, 323), (267, 1117),
                    (291, 1159), (416, 1166), (455, 1120), (486, 1144), (541, 1152),
                    (572, 1167), (627, 1168)]
        case "turret":
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
        let outline: [(Double, Double)] = design == "pilot"
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
        let span = modelSpans[design]!
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
            let engineX = design == "armored" ? 0.35 : design == "boss" ? 0.17 : design == "player" ? 0.17 : 0.095
            let engines = (dome(-engineX, -0.24, 0.055, 0.20) + dome(engineX, -0.24, 0.055, 0.20)) * 6
            let relief = design == "supply" ? 12 : design == "pilot" ? dome(0, 0.17, 0.10, 0.12) * 16 + 4 : cockpit + spine + engines
            let height = underside ? -2.5 : 1.5 + relief * min(1, edgeDistance / 40)
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
        let asset = design == "tank" ? "Tank-v16" : design == "turret" ? "Turret-v16"
            : design == "pilot" ? "Pilot-v16" : design == "supply" ? "Supply-v16"
            : design == "player" ? "Ship-player-v15" : design == "boss" ? "Ship-boss" : "Ship-\(design)-v16"
        let artwork = UIImage(named: asset)
        assert(artwork != nil, "Missing original aircraft texture")
        paint.diffuse.contents = artwork
        paint.lightingModel = .physicallyBased
        paint.metalness.contents = 0.12
        paint.roughness.contents = 0.65
        paint.emission.contents = artwork; paint.emission.intensity = 0.03
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
        let span = modelSpans[design]!
        let engineX = kind == .armored ? 0.35 : boss || kind == nil ? 0.17 : 0.095
        let engineSides = kind == .scout ? [0.0] : kind == .armored ? [-1.0, -0.53, 0.53, 1.0] : [-1.0, 1.0]
        for side in engineSides {
            let x = side * engineX * span, y = -(kind == .armored ? 0.02 : kind == nil ? 0.30 : 0.43) * span
            let nozzle = part(SCNCylinder(radius: CGFloat(span * 0.027), height: 2), 0x253D4A,
                              in: body, at: SCNVector3(x, y, 2), metal: true)
            nozzle.geometry?.firstMaterial = material(0x516571, metal: true)
            let flame = SCNCone(topRadius: CGFloat(span * 0.022), bottomRadius: 0.15, height: CGFloat(span * 0.16))
            flame.radialSegmentCount = 16
            let engine = part(flame, accent, in: body, at: SCNVector3(x, y - span * 0.08, 2), glow: true)
            engine.name = "engine"
            let core = part(SCNCone(topRadius: CGFloat(span * 0.012), bottomRadius: 0, height: CGFloat(span * 0.12)),
                            0xFFF7E3, in: engine, at: SCNVector3(0, span * 0.025, 1), glow: true)
            core.castsShadow = false; engine.castsShadow = false
        }
        if kind == nil {
            for side in [-1.0, 1.0] {
                let x = side * span * (kind == nil ? 0.37 : 0.28)
                let gun = part(SCNCylinder(radius: 0.85, height: span * 0.22), 0x73848A,
                               in: body, at: SCNVector3(x, span * 0.05, 4), metal: true)
                gun.geometry?.firstMaterial = material(0x73848A, metal: true)
                box(2.2, 2.2, 1, kind == nil ? cyan : orange, in: body, at: SCNVector3(x, -span * 0.15, 5), glow: true)
            }
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
            let plating: UInt32 = [0x637E83, 0x62657C, 0xA28B62, 0xA3CEDD, 0x53536F][(mission - 1) % 5]
            for side in [-1.0, 1.0] {
                let plate = hull([(0, 24), (side * 19, 14), (side * 23, -18), (0, -27)], depth: 5, color: plating, in: body)
                plate.position = SCNVector3(side * (mission == 4 ? 42 : 28), -12, 8)
                for row in 0..<5 {
                    box(mission == 3 ? 15 : 8, 1.1, 1, 0x27343B, in: body,
                        at: SCNVector3(side * 34, Double(row * 5 - 20), 14))
                }
                if mission == 1 || mission == 3 {
                    let pod = part(SCNCapsule(capRadius: mission == 3 ? 8 : 5, height: 58), plating,
                                   in: body, at: SCNVector3(side * 58, -10, 5), metal: true)
                    pod.name = "armor-pod"
                    box(3, 20, 2, accent, in: pod, at: SCNVector3(0, 0, 8), glow: true)
                }
                if mission == 2 {
                    for gun in [-1.0, 1.0] {
                        part(SCNCylinder(radius: 2.5, height: 41), 0x919DA6, in: body,
                             at: SCNVector3(side * 26 + gun * 4, 35, 10), metal: true)
                    }
                }
            }
            let reactor = part(SCNSphere(radius: mission == 5 ? 9 : 4), accent, in: body,
                               at: SCNVector3(0, mission == 5 ? 0 : 12, 18), glow: true)
            reactor.name = "reactor"
        }
        return root
    }

    static func groundUnit(_ size: ObstacleSize) -> SCNNode {
        let root = SCNNode()
        if size != .large {
            let mount = SCNNode(); mount.name = "turret"; root.addChildNode(mount)
            let body = SCNNode(geometry: referenceAirframe(size == .small ? "tank" : "turret"))
            body.name = "authored-prop"; mount.addChildNode(body)
            return root
        }
        let r = CGFloat(size.radius)
        box(r * 1.5, r * 1.6, 9, 0x45545A, in: root)
        let turret = SCNNode(); turret.name = "turret"; root.addChildNode(turret)
        box(37, 42, 22, 0x78888B, in: root, at: SCNVector3(0, 0, 14))
        box(4, 4, 30, 0xB0C1C4, in: root, at: SCNVector3(0, 0, 34))
        let dish = part(SCNCone(topRadius: 22, bottomRadius: 3, height: 10), 0x758487, in: turret, at: SCNVector3(0, 0, 49), metal: true)
        dish.eulerAngles.x = 0.7
        part(SCNTorus(ringRadius: 21, pipeRadius: 0.7), 0xADB7AC, in: dish, at: SCNVector3(0, 5, 0), metal: true)
        for index in 0..<8 {
            let brace = part(SCNCylinder(radius: 0.5, height: 21), 0xADB7AC, in: dish, metal: true)
            brace.position = SCNVector3(sin(Double(index) * .pi / 4) * 10, 5, cos(Double(index) * .pi / 4) * 10)
            brace.eulerAngles = SCNVector3(.pi / 2, Double(index) * .pi / 4, 0)
        }
        for side: Float in [-1, 1] {
            for row in 0..<6 {
                box(6, 2, 2, 0x7A8685, in: root,
                    at: SCNVector3(side * Float(r) * 0.66, Float(row) * Float(r) * 0.29 - Float(r) * 0.72, 8))
            }
            for y: Float in [-1, 1] {
                let bolt = SCNCylinder(radius: 1.5, height: 1.5); bolt.radialSegmentCount = 6
                part(bolt, 0xB4BBA6, in: root, at: SCNVector3(side * Float(r) * 0.45, y * Float(r) * 0.6, 6), metal: true).eulerAngles.x = .pi / 2
            }
        }
        return root
    }

    static func pickup(_ kind: EntityKind) -> SCNNode {
        let root = SCNNode()
        let colors: [EntityKind: UInt32] = [.crystal: orange, .repair: 0x7FF5B3, .shield: cyan, .power: 0xFF765A,
                                         .laser: 0x72F5EB, .spread: 0xACFF7B, .lightning: 0xCF95FF, .escort: 0x82B8FF, .rescue: 0xFFE29A]
        let color = colors[kind] ?? cyan
        if kind == .crystal {
            let points = (0..<10).map { i -> (CGFloat, CGFloat) in
                let angle = Double(i) * .pi / 5 + .pi / 2
                let r = i.isMultiple(of: 2) ? 8.0 : 3.7
                return (CGFloat(cos(angle) * r), CGFloat(sin(angle) * r))
            }
            let star = hull(points, depth: 4, color: 0xFFCC58, in: root)
            star.geometry?.firstMaterial = material(0xC99431)
            let inset = hull(points.map { ($0.0 * 0.68, $0.1 * 0.68) }, depth: 1, color: 0xFFF1AD, in: root)
            inset.position.z = 2.5
            inset.geometry?.firstMaterial = material(0xF5D16A)
        } else if kind == .rescue {
            let pilot = SCNNode(geometry: referenceAirframe("pilot")); pilot.name = "authored-prop"
            root.addChildNode(pilot)
        } else {
            let crate = SCNNode(geometry: referenceAirframe("supply")); crate.name = "authored-prop"
            root.addChildNode(crate)
            let symbol = SCNNode(); root.addChildNode(symbol); symbol.position.z = 5.5
            symbol.scale = SCNVector3(0.48, 0.48, 0.48)
            switch kind {
            case .repair:
                box(5, 17, 3, color, in: symbol, glow: true); box(17, 5, 3, color, in: symbol, glow: true)
            case .shield:
                hull([(-8, 8), (8, 8), (7, -3), (0, -9), (-7, -3)], depth: 3, color: color, in: symbol).geometry?.firstMaterial = material(color, glow: true)
            case .escort:
                let mini = ship(); mini.scale = SCNVector3(0.28, 0.28, 0.28); symbol.addChildNode(mini)
            case .spread:
                for angle in [-0.45, 0, 0.45] { box(3, 17, 3, color, in: symbol, glow: true).eulerAngles.z = Float(angle) }
            case .lightning, .power:
                hull([(2, 10), (-7, -1), (-1, -1), (-3, -10), (7, 3), (1, 3)], depth: 3, color: color, in: symbol).geometry?.firstMaterial = material(color, glow: true)
            default:
                for x: Float in [-5, 5] { box(3, 18, 3, color, in: symbol, at: SCNVector3(x, 0, 0), glow: true) }
            }
        }
        // Collection radius remains generous; the symbol carries identification at combat scale.
        if kind != .crystal { root.scale = SCNVector3(0.78, 0.78, 0.78) }
        if kind != .rescue { return root }
        let text = SCNText(string: "SOS", extrusionDepth: 0.3)
        text.font = .systemFont(ofSize: 7, weight: .bold); text.flatness = 0.4
        let label = part(text, color, in: root, glow: true)
        let bounds = label.boundingBox
        label.position = SCNVector3(-(bounds.max.x + bounds.min.x) / 2, 17, 12)
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
        environment = TerrainScene(world: world, reducedEffects: reducedEffects)
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
        animateShip(player, time: world.elapsed)
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
            animateShip(node, time: world.elapsed + Double(index))
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
            if entity.kind.isEnemy {
                node.eulerAngles = SCNVector3(-0.16, reduced ? 0 : sin(entity.age * 2) * 0.14, .pi)
                animateShip(node, time: entity.age)
            }
            if entity.kind == .bolt || entity.kind == .hostile { node.eulerAngles.z = Float(atan2(entity.velocity.y, entity.velocity.x) - .pi / 2) }
            if entity.kind.isPickup {
                node.position.z = Float(65 + (reduced ? 0 : sin(entity.age * 2) * 5))
                node.eulerAngles = SCNVector3(0.22, reduced ? 0.2 : sin(entity.age * 1.4) * 0.5, world.mission.axis == .horizontal ? .pi / 2 : 0)
                if entity.kind == .rescue {
                    node.eulerAngles.x = 0; node.eulerAngles.y = 0
                    node.position.z = -15
                }
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
                node = SCNNode(); scene.rootNode.addChildNode(node)
                node.position = SCNVector3(lane.x, world.length / 2, 61)
                let area = ModelArt.box(44, CGFloat(world.length), 1, 0xFF5247, in: node, glow: true)
                area.opacity = 0.10
                for x: Float in [-22, 22] { ModelArt.box(0.8, CGFloat(world.length), 1, 0xFF9D68, in: node, at: SCNVector3(x, 0, 1), glow: true) }
                let core = ModelArt.box(16, CGFloat(world.length), 2, 0xFFF2D1, in: node, glow: true)
                core.name = "lane-core"
                lanes[lane.id] = node
            }
            node.opacity = lane.active ? 0.85 : 0.45
            node.childNode(withName: "lane-core", recursively: false)?.isHidden = !lane.active
        }
    }

    private func animateShip(_ node: SCNNode, time: Double) {
        guard let body = node.childNode(withName: "airframe", recursively: false) else { return }
        for child in body.childNodes {
            if child.name == "engine" { child.scale.y = reduced ? 1 : Float(0.9 + sin(time * 27) * 0.14) }
            if child.name == "reactor" {
                let pulse = reduced ? Float(1) : Float(1 + sin(time * 3) * 0.12)
                child.scale = SCNVector3(pulse, pulse, pulse)
            }
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
            if mission <= 2 {
                let foundation = ModelArt.coastalIsland()
                let size = Float(entity.radius / 60)
                foundation.scale = SCNVector3(size, size, 0.4)
                foundation.position.z = -16; foundation.castsShadow = false
                node.addChildNode(foundation)
            }
            let bar = ModelArt.box(CGFloat(entity.radius * 1.4), 2, 2, ModelArt.orange, in: node,
                                   at: SCNVector3(0, -entity.radius - 7, 30), glow: true)
            bar.name = "hp"
            return node
        }
        if entity.kind == .bolt || entity.kind == .hostile {
            let node = SCNNode()
            let hostile = entity.kind == .hostile
            let color: UInt32 = hostile ? 0xFF793C : entity.projectileStyle == .spread ? 0xB2FF88 : entity.projectileStyle == .escort ? 0x8BAFFF : 0xFFD786
            let geometry = SCNCapsule(capRadius: hostile ? 2.7 : 1.1, height: hostile ? 7 : 11)
            geometry.radialSegmentCount = 6; geometry.capSegmentCount = 2
            ModelArt.part(geometry, color, in: node, glow: true)
            let core = SCNCapsule(capRadius: hostile ? 1.1 : 0.5, height: hostile ? 4 : 9)
            core.radialSegmentCount = 6; core.capSegmentCount = 2
            ModelArt.part(core, 0xFFF8DE, in: node, at: SCNVector3(0, 0.5, 3.5), glow: true)
            let trail = ModelArt.part(SCNCone(topRadius: hostile ? 1.8 : 1.0, bottomRadius: 0, height: hostile ? 14 : 20), color,
                                     in: node, at: SCNVector3(0, hostile ? -8 : -12, 0), glow: true)
            trail.opacity = 0.22
            node.castsShadow = false
            return node
        }
        let pickup = ModelArt.pickup(entity.kind)
        if entity.kind == .rescue && mission <= 2 {
            let shore = ModelArt.coastalIsland()
            shore.scale = SCNVector3(0.38, 0.38, 0.4)
            shore.position.z = -16; shore.castsShadow = false
            pickup.addChildNode(shore)
        }
        return pickup
    }

    func show(_ effect: BattleEffect, world: GameWorld) {
        func location(_ p: Vector) -> SCNVector3 { SCNVector3(p.x, p.y, 65) }
        switch effect {
        case let .explosion(p, boss): burst(location(p), radius: boss ? 65 : 23)
        case let .rubble(p, r): burst(SCNVector3(p.x, p.y, -5), radius: r)
        case let .pickup(p, kind):
            let flash = ModelArt.part(SCNSphere(radius: 5), ModelArt.cyan, in: effects, at: location(p), glow: true)
            expire(flash, duration: 0.22, movement: SCNVector3(0, 0, 16), scale: 0.1)
            if effects.childNodes.count < (reduced ? 60 : 180) {
                let feedbackName = kind == .crystal ? "loot-feedback" : "supply-feedback"
                effects.childNode(withName: feedbackName, recursively: false)?.removeFromParentNode()
                let captions: [EntityKind: String] = [.crystal: "+15", .rescue: "救援成功 +40", .repair: "装甲修复",
                    .shield: "护盾就绪", .power: "过载 8s", .laser: "激光 12s", .spread: "散弹 12s", .lightning: "雷电 12s", .escort: "护航补给"]
                let text = SCNText(string: captions[kind] ?? "补给回收", extrusionDepth: 0.1)
                text.font = .systemFont(ofSize: kind == .crystal ? 11 : 14, weight: .heavy)
                text.flatness = 0.5
                let label = ModelArt.part(text, kind == .crystal || kind == .rescue ? 0xFFE29A : ModelArt.cyan, in: effects, at: location(p), glow: true)
                label.name = feedbackName
                let bounds = label.boundingBox
                label.pivot = SCNMatrix4MakeTranslation((bounds.min.x + bounds.max.x) / 2, bounds.min.y, 0)
                label.position.z = 100
                if world.mission.axis == .horizontal {
                    label.eulerAngles.z = .pi / 2
                    label.position.x -= kind == .crystal ? 22 : 44
                } else { label.position.y += kind == .crystal ? 22 : 44 }
                expire(label, duration: kind == .crystal ? 0.6 : 1.1,
                       movement: world.mission.axis == .vertical ? SCNVector3(0, 28, 0) : SCNVector3(-28, 0, 0))
            }
        case let .impact(p): burst(location(p), radius: 5)
        case .damage: burst(location(world.player), radius: 12)
        case .emp: ring(location(world.player), radius: 500, color: ModelArt.cyan)
        case let .beam(a, b): trail([a, b], lightning: false)
        case let .lightningArc(points): trail(points, lightning: true)
        case .shot, .spreadShot:
            guard effects.childNodes.count < (reduced ? 60 : 180) else { return }
            let flash = ModelArt.part(SCNSphere(radius: 2.6), 0xFFF0CB, in: effects,
                                     at: SCNVector3(world.player.x, world.player.y + 25, 66), glow: true)
            flash.scale = SCNVector3(0.7, 2, 0.5)
            expire(flash, duration: 0.06)
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
        if radius >= 40 { ring(point, radius: radius * 1.4, color: ModelArt.orange) }
        let core = SCNSphere(radius: max(2, radius * 0.34)); core.segmentCount = 10
        let flash = ModelArt.part(core, 0xFFF4D6, in: effects, at: point, glow: true)
        expire(flash, duration: reduced ? 0.12 : 0.18, scale: 0.1)
        if radius >= 20 {
            for i in 0..<(reduced ? 1 : 3) {
                let cloud = SCNSphere(radius: radius * (0.17 + Double(i) * 0.04)); cloud.segmentCount = 10
                let smoke = ModelArt.part(cloud, i == 0 ? 0x252D33 : 0x55564F, in: effects,
                                         at: SCNVector3(point.x + Float(i * 5), point.y - Float(i * 6), point.z - 8))
                smoke.opacity = 0.38
                expire(smoke, duration: 0.8 + Double(i) * 0.16, movement: SCNVector3(8 + i * 4, -18 - i * 3, i * 4), scale: 2.6)
                if !reduced {
                    let flame = ModelArt.part(SCNSphere(radius: radius * 0.24), i == 1 ? 0xFFCB66 : 0xF58635,
                                              in: effects, at: SCNVector3(point.x + Float(i * 6 - 6), point.y, point.z + 2), glow: true)
                    expire(flame, duration: 0.22 + Double(i) * 0.07, movement: SCNVector3(i * 9 - 9, 9, 0), scale: 0.2)
                }
            }
        }
        for i in 0..<(reduced ? 4 : 9) {
            let angle = Double(i) * 2.399
            let fragment = SCNBox(width: max(1, radius * 0.09), height: max(2, radius * 0.18), length: 1.5, chamferRadius: 0)
            let node = ModelArt.part(fragment, i.isMultiple(of: 3) ? 0xFFE7B3 : 0x706456, in: effects, at: point, glow: i.isMultiple(of: 3), metal: true)
            node.eulerAngles = SCNVector3(angle, angle * 2, angle)
            expire(node, duration: 0.3 + Double(i % 3) * 0.12,
                   movement: SCNVector3(cos(angle) * radius, sin(angle) * radius, Double(i) * 3), scale: 0.15)
            if !reduced && radius >= 20 {
                let spark = ModelArt.box(1, CGFloat(radius * 0.35), 1, 0xFFD29B, in: effects, at: point, glow: true)
                spark.eulerAngles.z = Float(angle - .pi / 2)
                expire(spark, duration: 0.22 + Double(i % 3) * 0.07,
                       movement: SCNVector3(cos(angle) * radius * 1.9, sin(angle) * radius * 1.9, 4), scale: 0.1)
            }
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
        guard points.count >= 2, effects.childNodes.count < (reduced ? 60 : 180) else { return }
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
                let core = SCNCylinder(radius: lightning ? 0.6 : 0.9, height: d.length)
                core.radialSegmentCount = 5
                ModelArt.part(core, 0xF6FAFF, in: node, at: SCNVector3(0, 0, 2.6), glow: true)
            }
        }
        expire(root, duration: lightning ? 0.22 : 0.13)
    }

    #if DEBUG
    var bankAngle: Double { Double(player.eulerAngles.y) }

    private func validateModels() {
        for seed in 0..<7 {
            let rock = ModelArt.rock(seed: seed, tint: 0xA7AC8A)
            assert(rock.boundingBox.max.z - rock.boundingBox.min.z > 60)
            assert(rock.geometry?.sources(for: .texcoord).count == 1)
            assert(rock.geometry?.sources(for: .normal).count == 1)
            assert(rock.geometry?.firstMaterial?.diffuse.contents is UIImage)
        }
        var models = [ModelArt.ship(), ModelArt.ship(.scout), ModelArt.ship(.armored), ModelArt.ship(.interceptor)]
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
                    if child.name == "airframe" || child.name == "authored-prop" {
                        assert(geometry.sources(for: .texcoord).count == 1)
                        assert(geometry.elements.count == 3, "Textured hull has top, side walls and underside")
                        assert(geometry.boundingBox.max.z - geometry.boundingBox.min.z > 3)
                    } else if geometry.materials.contains(where: { $0.diffuse.contents is UIImage }) {
                        assert(geometry.materials.allSatisfy { $0.name == "original-armor" }, "Only authored armor textures belong on model parts")
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
    private var mist: [SCNNode] = []
    private let horizontal: Bool
    private let biome: Biome
    private var lastWallUpdate = -Double.infinity
    private var tileLength = 1200.0

    init(world: GameWorld, reducedEffects: Bool = false) {
        horizontal = world.mission.axis == .horizontal
        biome = world.mission.biome
        camera.camera = SCNCamera()
        camera.camera?.usesOrthographicProjection = true
        camera.camera?.orthographicScale = 390
        camera.camera?.zFar = 4000
        camera.camera?.wantsHDR = true
        // Keep dark biomes dark; eye adaptation otherwise washes out terrain and clips aircraft paint.
        camera.camera?.wantsExposureAdaptation = false
        camera.camera?.bloomIntensity = 0.18
        camera.camera?.bloomThreshold = 1.2
        camera.camera?.exposureOffset = -0.25
        scene.background.contents = UIColor(hex: 0x04101E)
        camera.position = SCNVector3(world.width / 2, world.length / 2, 1100)
        camera.look(at: SCNVector3(world.width / 2, world.length / 2, 0))
        scene.rootNode.addChildNode(camera)
        if horizontal { camera.eulerAngles.z = .pi / 2 }
        let sun = SCNNode()
        sun.light = SCNLight()
        sun.light?.type = .directional
        sun.light?.color = UIColor(hex: biome == .glacier ? 0xB8E4FF : 0xFFE2B6)
        sun.light?.intensity = 650
        sun.light?.castsShadow = true
        sun.light?.shadowColor = UIColor(hex: 0x07131F, alpha: 0.65)
        sun.light?.shadowMapSize = CGSize(width: reducedEffects ? 1024 : 2048, height: reducedEffects ? 1024 : 2048)
        sun.light?.orthographicScale = 1000
        sun.light?.shadowRadius = 3
        sun.position = SCNVector3(-350, 650, 900)
        sun.look(at: SCNVector3(195, 390, 0))
        scene.rootNode.addChildNode(sun)
        let fill = SCNNode()
        fill.light = SCNLight(); fill.light?.type = .ambient
        fill.light?.color = UIColor(hex: 0xD3E0EB); fill.light?.intensity = 260
        scene.rootNode.addChildNode(fill)
        let colors: [Biome: UInt32] = [.ocean: 0x18384A, .harbor: 0x102534, .desert: 0xAA8060, .glacier: 0x44718D, .orbit: 0x080F20]
        surface.diffuse.contents = UIColor(hex: colors[biome]!)
        surface.lightingModel = biome == .orbit ? .constant : .physicallyBased
        surface.metalness.contents = biome == .ocean || biome == .harbor ? 0.65 : 0.15
        surface.roughness.contents = biome == .ocean || biome == .harbor ? 0.25 : 0.75
        surface.isDoubleSided = true
        if biome != .orbit {
            // World-space UVs keep detail on the scrolling surface; only water moves independently.
            let water = biome == .ocean || biome == .harbor
            surface.shaderModifiers = [.surface: water ? """
                #pragma arguments
                float terrainPhase;
                #pragma body
                float shimmer = sin(_surface.diffuseTexcoord.x * 83.0 + terrainPhase)
                    * sin(_surface.diffuseTexcoord.y * 57.0 - terrainPhase * 0.7);
                // Keep foam below projectile brightness while preserving the deep-water color.
                _surface.diffuse.rgb = mix(float3(0.015, 0.045, 0.075), _surface.diffuse.rgb, 0.40 + shimmer * 0.02);
                """ : """
                #pragma body
                float2 p = _surface.diffuseTexcoord * float2(1220.0, 1200.0);
                float strata = sin(p.y * 0.018 + sin(p.x * 0.027) * 4.0);
                float grain = dot(_surface.diffuse.rgb, float3(0.33));
                _surface.diffuse.rgb = float3(0.28 + grain * 0.27 + strata * 0.025);
                """]
            if water {
                let artwork = UIImage(named: "Surface-ocean-v16"); assert(artwork != nil)
                surface.diffuse.contents = artwork
                surface.diffuse.wrapS = .repeat; surface.diffuse.wrapT = .repeat
                surface.diffuse.mipFilter = .linear
                surface.diffuse.contentsTransform = SCNMatrix4MakeScale(2.0333, 2, 1)
                surface.roughness.contents = 0.85; surface.metalness.contents = 0
                surface.lightingModel = .constant
                surface.setValue(Float(0), forKey: "terrainPhase")
            }
            else {
                surface.diffuse.contents = UIImage(named: "Surface-rock")
                surface.diffuse.wrapS = .repeat; surface.diffuse.wrapT = .repeat
                surface.diffuse.contentsTransform = SCNMatrix4MakeScale(3, 3, 1)
                surface.multiply.contents = UIColor(hex: biome == .glacier ? 0x426D83 : 0xC8A57C)
                surface.roughness.contents = biome == .glacier ? 0.38 : 0.95
            }
        }
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
        if biome != .orbit && !reducedEffects {
            let haze = SCNMaterial()
            haze.diffuse.contents = UIColor(hex: biome == .desert ? 0xD7B99A : 0xC3DCE3, alpha: 0.045)
            haze.lightingModel = .constant; haze.writesToDepthBuffer = false
            for index in 0..<4 {
                let cloud = SCNNode()
                for puff in 0..<3 {
                    let shape = SCNSphere(radius: 55); shape.segmentCount = 12; shape.materials = [haze]
                    let node = SCNNode(geometry: shape); node.castsShadow = false
                    node.scale = SCNVector3(1.2, 2.1, 0.18)
                    node.position = SCNVector3(Float(puff * 15), Float(puff * 58), 0)
                    cloud.addChildNode(node)
                }
                cloud.position.x = index.isMultiple(of: 2) ? -42 : Float(world.width + 12)
                cloud.position.z = 145
                scene.rootNode.addChildNode(cloud); mist.append(cloud)
            }
        }
        if biome == .orbit {
            for index in 0..<110 {
                let star = SCNSphere(radius: index.isMultiple(of: 11) ? 1.7 : 0.7); star.segmentCount = 4
                ModelArt.part(star, 0xA5C8E5, in: scene.rootNode,
                              at: SCNVector3(Double(index * 173 % 650) - 130, Double(index * 293 % 1000) - 110, -60), glow: true)
            }
            let planet = ModelArt.part(SCNSphere(radius: 165), 0x184F76, in: scene.rootNode, at: SCNVector3(400, 570, -360))
            let ocean = ModelArt.material(0x184F76).copy() as! SCNMaterial
            ocean.shaderModifiers = [.surface: """
                #pragma body
                float2 p = _surface.diffuseTexcoord * float2(8.0, 4.0);
                float land = 0.0, weight = 0.5, period = 8.0;
                for (int octave = 0; octave < 6; octave++) {
                    float2 cell = floor(p), f = fract(p);
                    cell.x = fmod(cell.x, period);
                    f = f * f * (3.0 - 2.0 * f);
                    float4 n = float4(dot(cell, float2(127.1, 311.7)),
                        dot(float2(fmod(cell.x + 1.0, period), cell.y), float2(127.1, 311.7)),
                        dot(cell + float2(0.0, 1.0), float2(127.1, 311.7)),
                        dot(float2(fmod(cell.x + 1.0, period), cell.y + 1.0), float2(127.1, 311.7)));
                    float4 h = fract(sin(n) * 43758.5453);
                    land += mix(mix(h.x, h.y, f.x), mix(h.z, h.w, f.x), f.y) * weight;
                    p *= 2.0; period *= 2.0; weight *= 0.5;
                }
                float coast = smoothstep(0.48, 0.56, land);
                float cloud = smoothstep(0.64, 0.78, land);
                _surface.diffuse.rgb = mix(float3(0.002, 0.012, 0.025), float3(0.012, 0.026, 0.018), coast);
                _surface.diffuse.rgb = mix(_surface.diffuse.rgb, float3(0.10, 0.13, 0.15), cloud);
                """]
            planet.geometry?.firstMaterial = ocean
            let air = SCNMaterial(); air.lightingModel = .constant
            air.diffuse.contents = UIColor(hex: 0x56B9ED, alpha: 0.08)
            air.writesToDepthBuffer = false; air.cullMode = .front
            let shell = SCNSphere(radius: 170); shell.segmentCount = 48; shell.materials = [air]
            planet.addChildNode(SCNNode(geometry: shell))
        }
        update(world)
    }

    func update(_ world: GameWorld) {
        if biome == .ocean || biome == .harbor {
            surface.setValue(Float(world.elapsed * 0.35), forKey: "terrainPhase")
        }
        for (index, cloud) in mist.enumerated() {
            let span = world.length + 500
            cloud.position.y = Float((Double(index) * span / 4 + span - (world.elapsed * 19).truncatingRemainder(dividingBy: span)).truncatingRemainder(dividingBy: span) - 250)
        }
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
                structure.position = SCNVector3(left ? bounds.lowerBound - 46 : bounds.upperBound + 46, y, biome == .harbor ? 30 : -25)
            } else {
                let inset = biome == .ocean ? Double(index % 4) * 25 : Double(index % 3) * 17
                let x = left ? -5.0 + inset : 395.0 - inset
                structure.position = SCNVector3(x, y, biome == .ocean ? -60 : height(x, y + scroll))
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
        let bank = (biome == .glacier ? ModelArt.rockMaterial(0x95CBEC) : ModelArt.material(0x82949B, metal: true)).copy() as! SCNMaterial
        bank.diffuse.wrapS = .repeat; bank.diffuse.wrapT = .repeat
        bank.diffuse.contentsTransform = SCNMatrix4MakeScale(4, 4, 1)
        geometry.materials = [bank]
        return geometry
    }

    private func mesh(_ vertices: [SCNVector3], uv: [CGPoint], indices: [Int32]) -> SCNGeometry {
        let geometry = ModelArt.mesh(vertices, uv: uv, indices: indices)
        geometry.materials = [surface]
        return geometry
    }

    private func makeStructure(_ index: Int) -> SCNNode {
        let root = SCNNode()
        switch biome {
        case .ocean:
            let island = ModelArt.coastalIsland()
            island.scale = SCNVector3(0.65 + Float(index % 3) * 0.14, 0.60 + Float(index % 4) * 0.12, 1)
            island.eulerAngles.z = Float(index) * 2.4
            island.castsShadow = false
            root.addChildNode(island)
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
            if index.isMultiple(of: 3) {
                for y: Float in [-28, 28] {
                    ModelArt.box(5, 5, 62, 0x9E875B, in: root, at: SCNVector3(-25, y, 35))
                }
                ModelArt.box(6, 67, 6, 0xB09D72, in: root, at: SCNVector3(-25, 0, 68))
                ModelArt.box(54, 4, 4, 0xB09D72, in: root, at: SCNVector3(-4, 0, 70))
                ModelArt.box(1, 1, 24, 0x8C9699, in: root, at: SCNVector3(20, 0, 56))
            }
        case .desert, .glacier:
            let ice = biome == .glacier
            for i in 0..<6 {
                let rock = ModelArt.rock(seed: index + i, tint: ice ? 0xA1D8F0 : (i.isMultiple(of: 2) ? 0xDBAC7F : 0xA77958))
                rock.position = SCNVector3(i * 13 - 26, i * 26 - 65, 12 + i % 3 * 6)
                rock.scale = SCNVector3(ice ? 0.7 : 0.85, 0.8 + Float(i % 3) * 0.2, ice ? 1.7 : 1.1)
                rock.eulerAngles.z = Float(i) * 0.7
                root.addChildNode(rock)
            }
        case .orbit:
            ModelArt.box(45, 75, 15, 0x66798F, in: root, at: SCNVector3(0, 0, 775))
            for side: Float in [-1, 1] {
                ModelArt.box(44, 88, 3, 0x183C66, in: root, at: SCNVector3(side * 46, 0, 778))
                for row in 0..<8 { ModelArt.box(44, 1, 1, 0x6F9CBD, in: root, at: SCNVector3(side * 46, Float(row * 11 - 39), 781)) }
            }
            ModelArt.box(4, 48, 2, ModelArt.cyan, in: root, at: SCNVector3(0, 0, 786), glow: true)
            for x: Float in [-66, -26, 26, 66] {
                ModelArt.box(1.2, 88, 2, 0x8D9CA6, in: root, at: SCNVector3(x, 0, 782))
            }
            ModelArt.box(2, 36, 3, 0x8D9CA6, in: root, at: SCNVector3(0, 50, 789))
            ModelArt.part(SCNSphere(radius: 2), 0xFFB761, in: root, at: SCNVector3(0, 68, 789), glow: true)
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
        sun.light?.intensity = 950; sun.light?.castsShadow = true
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
