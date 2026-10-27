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
            let texture = UIImage(named: "Surface-mechanical-v17")
            assert(texture != nil)
            result.name = "original-armor-\(color)"
            result.diffuse.contents = texture
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            UIColor(hex: color).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            result.multiply.contents = UIColor(red: sqrt(red), green: sqrt(green), blue: sqrt(blue), alpha: 1)
            result.diffuse.mipFilter = .linear
            result.metalness.contents = 0.08; result.roughness.contents = 0.62
            // Preserve the authored panel relief under the top-down camera's low ambient light.
            result.emission.contents = texture; result.emission.intensity = 0.035
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
    // Traced in the original 1254px artwork; UVs and relief share these coordinates.
    private static func referenceAirframe(_ design: String) -> SCNGeometry {
        if let cached = airframes[design] { return cached }
        let profile = HullDesign(rawValue: design == "turret-base" ? "turret" : design)!
        let pixels = design == "turret-base" ? profile.pixels.filter { $0.y >= 363 } : profile.pixels
        let edge = pixels.map { SIMD2<Double>($0.x, $0.y) }
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
        let span = profile.span
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
        let asset = profile.asset
        let artwork = UIImage(named: asset)
        assert(artwork != nil, "Missing original aircraft texture")
        paint.diffuse.contents = artwork
        paint.lightingModel = .constant
        paint.metalness.contents = 0.12
        paint.roughness.contents = 0.65
        paint.diffuse.mipFilter = .linear
        let edgeMaterial = material(design == "player" ? 0x627785 : 0x30373D, metal: true)
        geometry.materials = [paint, edgeMaterial, edgeMaterial]
        airframes[design] = geometry
        return geometry
    }

    #if DEBUG
    static func exportModelComparison() {
        let directory = URL.documentsDirectory.appending(path: "ModelComparison")
        try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let designs: [HullDesign] = [.player, .scout, .armored, .interceptor, .boss, .tank, .turret]
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        var rows: [[UIImage]] = []
        for design in designs {
            let source = UIGraphicsImageRenderer(size: CGSize(width: 256, height: 256), format: format).image { _ in
                UIImage(named: design.asset)!.draw(in: CGRect(x: 0, y: 0, width: 256, height: 256))
            }
            let scene = SCNScene()
            let body: SCNNode
            if design == .tank || design == .turret {
                body = groundUnit(design == .tank ? .small : .medium, form: design == .tank ? .tank : .turret)
                body.scale = SCNVector3(1, 1, 1)
            } else { body = SCNNode(geometry: referenceAirframe(design.rawValue)) }
            scene.rootNode.addChildNode(body)
            let camera = SCNNode(); camera.camera = SCNCamera()
            camera.camera!.usesOrthographicProjection = true
            camera.camera!.zFar = 1000
            camera.camera!.orthographicScale = design.span / 2
            camera.position = SCNVector3(0, 0, 300)
            scene.rootNode.addChildNode(camera)
            let light = SCNNode(); light.light = SCNLight(); light.light!.type = .ambient
            light.light!.intensity = 700; scene.rootNode.addChildNode(light)
            let renderer = SCNRenderer(device: nil, options: nil)
            renderer.scene = scene; renderer.pointOfView = camera
            let top = renderer.snapshot(atTime: 0, with: CGSize(width: 256, height: 256), antialiasingMode: .multisampling4X)
            body.eulerAngles = SCNVector3(0.65, 0.40, 0)
            let side = renderer.snapshot(atTime: 0, with: CGSize(width: 256, height: 256), antialiasingMode: .multisampling4X)
            for (name, image) in [("source", source), ("top", top), ("oblique", side)] {
                try! image.pngData()!.write(to: directory.appending(path: "\(design.rawValue)-\(name).png"))
            }
            rows.append([source, top, side])
        }
        let board = UIGraphicsImageRenderer(size: CGSize(width: 768, height: designs.count * 282 + 32), format: format).image { context in
            UIColor(hex: 0x152333).setFill(); context.fill(CGRect(x: 0, y: 0, width: 768, height: designs.count * 282 + 32))
            let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 16), .foregroundColor: UIColor.white]
            for (column, title) in ["Original texture", "3D top / no FX", "3D oblique"].enumerated() {
                (title as NSString).draw(at: CGPoint(x: column * 256 + 12, y: 7), withAttributes: attributes)
            }
            for (row, images) in rows.enumerated() {
                for (column, image) in images.enumerated() {
                    image.draw(in: CGRect(x: column * 256, y: row * 282 + 32, width: 256, height: 256))
                }
                (designs[row].rawValue as NSString).draw(at: CGPoint(x: 12, y: row * 282 + 288), withAttributes: attributes)
            }
        }
        try! board.pngData()!.write(to: directory.appending(path: "comparison.png"))
    }
    #endif

    private static func rotor(in parent: SCNNode, at position: SCNVector3, radius: CGFloat) {
        let hub = SCNNode(); hub.name = "rotor"; hub.position = position; parent.addChildNode(hub)
        let shaft = part(SCNCylinder(radius: 2.1, height: 4), 0x7A827F, in: hub, metal: true)
        shaft.eulerAngles.x = .pi / 2
        for index in 0..<4 {
            let blade = hull([(2, -1), (radius, -2), (radius - 2, 1.5), (5, 2)], depth: 0.5, color: 0x414A46, in: hub)
            blade.eulerAngles.z = Float(index) * .pi / 2
            let tip = box(4, 2.6, 0.6, 0xB7A06A, in: blade, at: SCNVector3(Float(radius - 4), 0, 0.6))
            tip.castsShadow = false
        }
    }

    static func mechanicalAircraft(_ kind: EntityKind) -> SCNNode {
        let root = SCNNode(), body = SCNNode()
        body.name = "airframe"; root.addChildNode(body)
        let paint: UInt32 = 0x707C70
        if kind.isRotorcraft {
            let heavy = kind == .heavyGunship
            let fuselage = part(SCNCapsule(capRadius: 9, height: 43), paint, in: body,
                                at: SCNVector3(0, 5, 3), metal: true)
            fuselage.scale.z = 0.62
            for side in [-1.0, 1.0] {
                box(3.5, 19, 2, 0x939B87, in: body, at: SCNVector3(side * 7, 0, 7))
                for row in -2...2 { box(2.4, 0.8, 0.7, 0x34423D, in: body, at: SCNVector3(side * 7, Double(row * 3), 8.5)) }
            }
            let canopy = part(SCNSphere(radius: 6), 0x243F48, in: body, at: SCNVector3(0, 13, 7), metal: true)
            canopy.scale = SCNVector3(0.9, 1.9, 0.65)
            box(0.8, 17, 0.9, 0xA2A99A, in: body, at: SCNVector3(0, 14, 11))
            for y in [9.0, 17.0] { box(8, 0.7, 0.9, 0xA2A99A, in: body, at: SCNVector3(0, y, 10)) }
            let tail = hull([(-4, -9), (-1.5, -42), (1.5, -42), (4, -9)], depth: 3, color: paint, in: body)
            tail.position.z = 2
            box(17, 3, 2, paint, in: body, at: SCNVector3(0, -35, 3))
            let fin = box(2, 10, 8, paint, in: body, at: SCNVector3(0, -39, 5))
            fin.eulerAngles.y = 0.12
            for side in [-1.0, 1.0] {
                box(heavy ? 17 : 12, 4, 2, paint, in: body, at: SCNVector3(side * 12, 0, 2))
                part(SCNCapsule(capRadius: heavy ? 4 : 2.8, height: heavy ? 22 : 15), 0x4C554F,
                     in: body, at: SCNVector3(side * (heavy ? 19 : 15), 0, 2), metal: true)
                for row in 0..<(heavy ? 4 : 2) {
                    box(2, 3, 1, 0xA5AB9E, in: body, at: SCNVector3(side * (heavy ? 19 : 15), Double(row * 4 - 5), 6))
                }
                part(SCNCylinder(radius: 2.3, height: 12), 0x39413D, in: body,
                     at: SCNVector3(side * 5, -7, 9), metal: true)
                box(1.2, 29, 1.5, 0x3A433E, in: body, at: SCNVector3(side * 10, 0, -2))
            }
            for x in (heavy ? [-2.0, 2.0] : [0.0]) {
                part(SCNCylinder(radius: 0.9, height: 10), 0x29332F, in: body, at: SCNVector3(x, 28, 1), metal: true)
            }
            rotor(in: body, at: SCNVector3(0, -2, 14), radius: heavy ? 36 : 30)
            rotor(in: body, at: SCNVector3(2, -40, 9), radius: 7)
            if heavy { body.scale = SCNVector3(1.15, 1.15, 1.15) }
        } else if kind == .drone {
            let shell = part(SCNSphere(radius: 13), paint, in: body, metal: true)
            shell.scale = SCNVector3(1, 1.1, 0.5)
            let cap = part(SCNCylinder(radius: 8, height: 3), 0x9BA89E, in: body, at: SCNVector3(0, 0, 6), metal: true)
            cap.eulerAngles.x = .pi / 2
            part(SCNSphere(radius: 3), 0x8AD6DF, in: body, at: SCNVector3(0, 0, 9), glow: true)
            for index in 0..<3 {
                let angle = Double(index) * .pi * 2 / 3
                let x = sin(angle) * 15, y = cos(angle) * 15
                let pod = box(6, 14, 7, 0x424C49, in: body, at: SCNVector3(x, y, 0))
                pod.eulerAngles.z = Float(-angle)
                box(3, 2, 1, 0x91B4B3, in: pod, at: SCNVector3(0, -5, 4))
            }
        } else {
            let twin = kind == .twinBoom
            let wing = hull([(-31, 4), (-29, 11), (-8, 9), (0, 14), (8, 9), (29, 11), (31, 4), (9, -3), (-9, -3)],
                            depth: 2.5, color: paint, in: body)
            wing.position.z = 1
            let fuselage = part(SCNCapsule(capRadius: 4.5, height: twin ? 29 : 42), paint, in: body,
                                at: SCNVector3(0, twin ? 6 : -1, 3), metal: true)
            fuselage.scale.z = 0.85
            let glass = part(SCNSphere(radius: 3), 0x233B43, in: body, at: SCNVector3(0, 8, 7), metal: true)
            glass.scale = SCNVector3(0.8, 2.2, 0.65)
            let sides = twin ? [-1.0, 1.0] : [0.0]
            for side in sides {
                let x = side * 12
                if twin {
                    let boom = hull([(-3, 18), (-4, 4), (-2, -29), (2, -29), (4, 4), (3, 18)], depth: 5, color: paint, in: body)
                    boom.position = SCNVector3(x, 0, 2)
                    box(1.5, 10, 5, paint, in: body, at: SCNVector3(x, -25, 5))
                }
                let prop = SCNNode(); prop.name = "propeller"; prop.position = SCNVector3(x, twin ? 20 : 22, 3)
                body.addChildNode(prop)
                box(13, 1.2, 1.2, 0x38413E, in: prop)
                part(SCNSphere(radius: 1.5), 0xB3B4A2, in: prop, metal: true)
            }
            box(twin ? 28 : 19, 4, 2, paint, in: body, at: SCNVector3(0, twin ? -27 : -17, 3))
            for side in [-1.0, 1.0] {
                box(3, 10, 0.5, 0xB4B7A1, in: body, at: SCNVector3(side * 25, 7, 3.8))
                for row in 0..<3 { box(5, 0.5, 0.5, 0x404A43, in: body, at: SCNVector3(side * 17, Double(row * 2 + 3), 3.8)) }
            }
            if !twin { body.scale = SCNVector3(0.75, 0.75, 0.75) }
        }
        return root
    }

    static func mechanicalGround(_ form: GroundForm, size: ObstacleSize) -> SCNNode {
        let root = SCNNode(), turret = SCNNode()
        let layout = GroundWeaponLayout(form: form, size: size)
        turret.name = "turret"; root.addChildNode(turret)
        let paint: UInt32 = 0x70786B
        if form == .patrolBoat {
            hull([(0, 43), (-12, 23), (-14, -28), (-9, -35), (9, -35), (14, -28), (12, 23)], depth: 8, color: 0x4B5A5D, in: root)
            box(17, 36, 5, 0x8B9282, in: root, at: SCNVector3(0, -3, 10))
            box(10, 12, 10, paint, in: root, at: SCNVector3(0, -10, 17))
            box(8, 3, 1, 0x253D44, in: root, at: SCNVector3(0, -6, 23))
            box(1, 1, 18, 0x8B9282, in: root, at: SCNVector3(0, -14, 27))
            turret.position = SCNVector3(0, layout.pivot.y / layout.scale, 12)
        } else if form == .spider {
            for side in [-1.0, 1.0] { for row in -1...1 {
                let leg = SCNNode(); leg.position = SCNVector3(side * 9, Double(row) * 12, 3); root.addChildNode(leg)
                let shoulder = box(18, 5, 5, 0x48544E, in: leg, at: SCNVector3(side * 8, Double(row) * 4, 2))
                shoulder.eulerAngles.z = Float(side * Double(row) * 0.35)
                box(10, 6, 10, paint, in: leg, at: SCNVector3(side * 20, Double(row) * 8, 0))
                box(8, 10, 3, 0x343F3C, in: leg, at: SCNVector3(side * 23, Double(row) * 9, -4))
                let hinge = part(SCNCylinder(radius: 3.2, height: 2), 0x9AA594, in: leg,
                                 at: SCNVector3(side * 17, Double(row) * 7, 7), metal: true)
                hinge.eulerAngles.x = .pi / 2
            } }
            let shell = part(SCNCylinder(radius: 13, height: 9), paint, in: root, at: SCNVector3(0, 0, 6), metal: true)
            shell.eulerAngles.x = .pi / 2
            turret.position.z = 13
        } else {
            box(31, 49, 7, paint, in: root, at: SCNVector3(0, -5, 3))
            for side in [-1.0, 1.0] {
                box(8, 54, 9, 0x313C38, in: root, at: SCNVector3(side * 17, -5, 2))
                for row in 0..<10 { box(9, 2, 1, 0x849084, in: root, at: SCNVector3(side * 18, Double(row * 4 - 18), 7)) }
                box(5, 36, 2, paint, in: root, at: SCNVector3(side * 13, 0, 8))
            }
            turret.position.z = 10
        }
        if form == .missileCarrier || form == .patrolBoat {
            for side in [-1.0, 1.0] {
                box(9, 23, 9, paint, in: turret, at: SCNVector3(side * 6, 0, 4))
                for row in 0..<3 {
                    part(SCNCylinder(radius: 1.6, height: 23), 0x293631, in: turret,
                         at: SCNVector3(side * 6 + Double(row - 1) * 2.5, layout.barrels[0].y - 11.5, 8), metal: true).name = "barrel"
                }
            }
        } else {
            let cap = part(SCNCylinder(radius: 10, height: 8), paint, in: turret, metal: true)
            cap.eulerAngles.x = .pi / 2
            box(15, 14, 5, paint, in: turret, at: SCNVector3(0, 0, 4))
            let length = form == .spider ? 37.0 : 30.0
            for point in layout.barrels {
                box(form == .spider ? 2.5 : 2.6, length, 3, 0x9CA89B, in: turret,
                    at: SCNVector3(point.x, point.y - length / 2, 4)).name = "barrel"
            }
            box(5, 6, 2, 0x333F3D, in: turret, at: SCNVector3(0, -4, 8))
        }
        if form == .tank { projectArtwork(.tank, onto: root) }
        let scale = Float(GroundWeaponLayout(form: form, size: size).scale)
        root.scale = SCNVector3(scale, scale, scale)
        return root
    }

    private static func distinctBoss(_ mission: Int) -> SCNNode {
        if mission == 4 {
            let node = mechanicalAircraft(.heavyGunship); node.scale = SCNVector3(2.2, 2.2, 2.2); return node
        }
        if mission == 3 {
            let node = mechanicalGround(.spider, size: .large); node.scale = SCNVector3(2.1, 2.1, 2.1); return node
        }
        let root = SCNNode(), body = SCNNode(); body.name = "airframe"; root.addChildNode(body)
        if mission == 2 {
            for side in [-1.0, 1.0] {
                let pontoon = mechanicalGround(.patrolBoat, size: .large)
                pontoon.position.x = Float(side * 40); body.addChildNode(pontoon)
            }
            box(85, 36, 12, 0x6F7F7B, in: body, at: SCNVector3(0, 0, 12))
            box(24, 19, 20, 0x859184, in: body, at: SCNVector3(0, -5, 26))
            for x in [-7.0, 7.0] { box(9, 3, 2, 0x29424B, in: body, at: SCNVector3(x, 4, 36)) }
        } else {
            let core = part(SCNSphere(radius: 23), 0x6D787A, in: body, metal: true)
            core.scale.z = 0.5
            part(SCNSphere(radius: 10), 0x6EA6B0, in: body, at: SCNVector3(0, 0, 10), glow: true).name = "reactor"
            for index in 0..<4 {
                let arm = SCNNode(); arm.name = "joint-arm"; arm.eulerAngles.z = Float(index) * .pi / 2 + .pi / 4
                body.addChildNode(arm)
                for segment in 0..<3 {
                    let distance = Double(23 + segment * 16)
                    box(19, 7, 5, 0x414E52, in: arm, at: SCNVector3(distance, 0, 0))
                    let joint = part(SCNCylinder(radius: CGFloat(10 - segment), height: 7), 0x929E9C,
                                     in: arm, at: SCNVector3(distance + 9, 0, 3), metal: true)
                    joint.eulerAngles.x = .pi / 2
                    let rim = part(SCNTorus(ringRadius: CGFloat(8 - segment), pipeRadius: 1.3), 0xA5ADAA,
                                   in: arm, at: SCNVector3(distance + 9, 0, 7), metal: true)
                    rim.eulerAngles.x = .pi / 2
                    part(SCNSphere(radius: 3), 0x79BBC5, in: arm, at: SCNVector3(distance + 9, 0, 8), glow: true)
                }
                box(10, 16, 8, 0x48565B, in: arm, at: SCNVector3(70, 0, 3))
            }
        }
        return root
    }

    // Keep saturated paint on solid surfaces, with a colored fill for shaded sides.
    private static func finishVehicle(_ root: SCNNode) -> SCNNode {
        root.enumerateChildNodes { node, _ in
            guard let geometry = node.geometry else { return }
            let copy = geometry.copy() as! SCNGeometry
            copy.materials = geometry.materials.map { source in
                guard let name = source.name, name.hasPrefix("original-armor-"),
                      let rgb = UInt32(name.dropFirst("original-armor-".count)) else { return source }
                let key = "vehicle-\(name)"
                if let cached = materials[key] { return cached }
                let paint = source.copy() as! SCNMaterial
                let color = UIColor(hex: rgb)
                paint.name = key
                paint.diffuse.contents = UIImage(named: "Surface-mechanical-v17")
                paint.diffuse.intensity = 1
                paint.multiply.contents = color
                paint.emission.contents = color; paint.emission.intensity = 0.12
                paint.metalness.contents = 0; paint.roughness.contents = 0.68
                let r = Double((rgb >> 16) & 255) / 255, g = Double((rgb >> 8) & 255) / 255, b = Double(rgb & 255) / 255
                paint.shaderModifiers = [.surface: """
                    #pragma body
                    float detail = dot(_surface.diffuse.rgb, float3(0.3333));
                    _surface.diffuse.rgb = float3(\(r), \(g), \(b)) * (0.62 + detail * 0.75);
                    """]
                materials[key] = paint
                return paint
            }
            node.geometry = copy
        }
        return root
    }

    static func ship(_ kind: EntityKind? = nil, mission: Int = 1) -> SCNNode {
        finishVehicle(buildShip(kind, mission: mission))
    }

    private static func buildShip(_ kind: EntityKind?, mission: Int) -> SCNNode {
        if let kind, [.propeller, .gunship, .heavyGunship, .twinBoom, .drone].contains(kind) { return mechanicalAircraft(kind) }
        if kind == .boss && mission > 1 { return distinctBoss(mission) }
        let design = kind?.rawValue ?? "player"
        let root = SCNNode()
        let body = SCNNode(geometry: referenceAirframe(design)); body.name = "authored-prop"
        root.addChildNode(body)
        let boss = kind == .boss
        let accent: UInt32 = kind == nil ? cyan : [0xFF704B, 0xE26BFF, 0xFFB64F, 0x7BBEFF, 0xFF466D][(mission - 1) % 5]
        let span = HullDesign(rawValue: design)!.span
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
        return root
    }

    private static func projectArtwork(_ design: HullDesign, onto root: SCNNode) {
        let paint = SCNMaterial()
        paint.name = "projected-art"
        paint.diffuse.contents = UIImage(named: design.asset)
        paint.diffuse.mipFilter = .linear
        paint.lightingModel = .constant
        root.enumerateChildNodes { node, _ in
            guard node.name != "authored-prop", let geometry = node.geometry else { return }
            let projected = geometry.copy() as! SCNGeometry
            projected.materials = [paint]
            projected.shaderModifiers = [.geometry: """
                #pragma arguments
                float4x4 artworkTransform;
                float artworkSpan;
                #pragma body
                float4 p = artworkTransform * _geometry.position;
                _geometry.texcoords[0] = float2(p.x / artworkSpan + 0.5, 0.5 - p.y / artworkSpan);
                """]
            projected.setValue(NSValue(scnMatrix4: node.convertTransform(SCNMatrix4Identity, to: root)), forKey: "artworkTransform")
            projected.setValue(Float(design.span), forKey: "artworkSpan")
            node.geometry = projected
        }
    }

    static func groundUnit(_ size: ObstacleSize, form: GroundForm? = nil) -> SCNNode {
        let form = form ?? (size == .small ? .tank : size == .medium ? .turret : .radar)
        let node = finishVehicle(buildGroundUnit(size, form: form))
        if let turret = node.childNode(withName: "turret", recursively: false) {
            for (index, point) in GroundWeaponLayout(form: form, size: size).barrels.enumerated() {
                let muzzle = SCNNode(); muzzle.name = "muzzle-\(index)"
                muzzle.position = SCNVector3(point.x, point.y, 4)
                turret.addChildNode(muzzle)
                if form == .radar {
                    box(2, 16, 3, 0x9CA89B, in: turret, at: SCNVector3(point.x, point.y - 8, 4)).name = "barrel"
                }
            }
        }
        return node
    }

    private static func buildGroundUnit(_ size: ObstacleSize, form: GroundForm?) -> SCNNode {
        if let form, form != .turret && form != .radar { return mechanicalGround(form, size: size) }
        let layout = GroundWeaponLayout(form: form ?? .turret, size: size)
        let size = form == .radar ? ObstacleSize.large : form == .turret ? .medium : size
        let root = SCNNode()
        if size != .large {
            let mount = SCNNode(); mount.name = "turret"; root.addChildNode(mount)
            if size == .small { return mechanicalGround(.tank, size: size) }
            let base = SCNNode(geometry: referenceAirframe("turret-base"))
            base.name = "authored-prop"; root.addChildNode(base)
            box(29, 32, 12, 0xA2AD89, in: mount, at: SCNVector3(0, 0, 10))
            for point in layout.barrels {
                part(SCNCylinder(radius: 1.5, height: point.y), 0xB5C1BD, in: mount,
                     at: SCNVector3(point.x, point.y / 2, 13), metal: true).name = "barrel"
                box(7, 18, 5, 0x53675A, in: mount, at: SCNVector3(point.x < 0 ? -17 : 17, 0, 10))
            }
            projectArtwork(.turret, onto: root)
            root.scale = SCNVector3(layout.scale, layout.scale, layout.scale)
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
        if ProcessInfo.processInfo.arguments.contains("-model-comparison") { ModelArt.exportModelComparison() }
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
            let grounded = world.mission.id == 2 || world.mission.id == 3
            wreck.position = SCNVector3(wreckOrigin.x + sin(t * 3) * (grounded ? 4 : 20),
                                       wreckOrigin.y - t * (grounded ? 25 : 75), (grounded ? -15 : 65) - t * (grounded ? 20 : 105))
            wreck.eulerAngles = SCNVector3(t * (grounded ? 0.1 : 0.8), t * (grounded ? 0.15 : 1.1), .pi + t * 0.5)
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
            let groundBoss = entity.kind == .boss && (world.mission.id == 2 || world.mission.id == 3)
            node.position = SCNVector3(p.x, p.y, entity.kind == .obstacle || groundBoss ? -15 : 65)
            if entity.kind.isEnemy || entity.kind == .obstacle { node.opacity = world.elapsed - entity.lastHitAt < 0.12 ? 0.55 : 1 }
            if entity.kind.isEnemy {
                node.eulerAngles = SCNVector3(groundBoss ? 0 : -0.16, reduced || groundBoss ? 0 : sin(entity.age * 2) * 0.14, .pi)
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
                if entity.kind == .obstacle {
                    turret.eulerAngles.z = Float(GroundWeaponLayout(form: entity.groundForm, size: entity.obstacleSize)
                        .angle(from: entity.position, to: world.player)) - node.eulerAngles.z
                } else {
                    let aim = world.player - entity.position
                    turret.eulerAngles.z = Float(atan2(aim.y, aim.x) - .pi / 2) - node.eulerAngles.z
                }
            }
            if let bar = node.childNode(withName: "hp", recursively: false) { bar.scale.x = Float(max(0.001, entity.hp / entity.maxHP)) }
        }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing"),
           ProcessInfo.processInfo.arguments.contains("-shape-demo"),
           ProcessInfo.processInfo.arguments.contains("-volume-demo") {
            for node in [player] + Array(entities.values) {
                node.eulerAngles.x = 0.85; node.eulerAngles.y = 0.55
            }
        }
        #endif
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
            if child.name == "rotor" { child.eulerAngles.z = Float(time * (reduced ? 8 : 27)) }
            if child.name == "propeller" { child.eulerAngles.y = Float(time * (reduced ? 8 : 35)) }
            if child.name == "joint-arm" {
                let index = body.childNodes.filter { $0.name == "joint-arm" }.firstIndex(of: child) ?? 0
                child.eulerAngles.z = Float(Double(index) * .pi / 2 + .pi / 4 + sin(time * 0.7) * (reduced ? 0 : 0.18))
            }
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
            let node = ModelArt.groundUnit(entity.obstacleSize, form: entity.groundForm)
            if mission <= 2 && entity.groundForm != .patrolBoat {
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
            node.position = location(p)
            if world.mission.id == 2 || world.mission.id == 3 { node.position.z = -15 }
            node.eulerAngles.z = .pi
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
        var models = [ModelArt.ship()] + EntityKind.aircraft.map { ModelArt.ship($0) }
        models += (1...5).map { ModelArt.ship(.boss, mission: $0) }
        models += GroundForm.allCases.map { ModelArt.groundUnit(.medium, form: $0) }
        for design in [HullDesign.player, .scout, .armored, .interceptor, .boss] {
            let geometry = ModelArt.ship(design == .player ? nil : EntityKind(rawValue: design.rawValue))
                .childNode(withName: "authored-prop", recursively: true)!.geometry!
            assert(geometry.elements.count == 3)
            assert(geometry.sources(for: .texcoord).count == 1)
            assert(geometry.firstMaterial?.diffuse.contents is UIImage)
            assert(geometry.boundingBox.max.z - geometry.boundingBox.min.z > 3)
        }
        for form in GroundForm.allCases { for size in ObstacleSize.allCases {
            let node = ModelArt.groundUnit(size, form: form)
            let turret = node.childNode(withName: "turret", recursively: false)!
            let layout = GroundWeaponLayout(form: form, size: size)
            for endpoint in layout.barrels {
                assert(turret.childNodes.contains { gun in
                    guard gun.name == "barrel", let geometry = gun.geometry else { return false }
                    return abs(Double(gun.position.x) - endpoint.x) < 0.01
                        && abs(Double(gun.position.y + geometry.boundingBox.max.y) - endpoint.y) < 0.01
                }, "Projectile sockets must coincide with physical barrel endpoints")
            }
            for aim in [Vector(x: 100, y: -200), Vector(x: -100, y: 80)] {
                turret.eulerAngles.z = Float(layout.angle(from: .zero, to: aim))
                for (index, expected) in layout.muzzles(from: .zero, to: aim).enumerated() {
                    let muzzle = turret.childNode(withName: "muzzle-\(index)", recursively: false)!
                    let p = node.convertPosition(muzzle.convertPosition(.init(), to: node), to: nil)
                    assert(hypot(Double(p.x) - expected.x, Double(p.y) - expected.y) < 0.01)
                }
            }
        } }
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
                        assert(geometry.materials.allSatisfy { $0.name == "projected-art" || $0.name?.contains("original-armor-") == true }, "Vehicle textures must have an authored source")
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
    private var landmarks: [SCNNode] = []
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
        for index in 0..<4 {
            let landmark = makeLandmark(index)
            scene.rootNode.addChildNode(landmark); landmarks.append(landmark)
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
        for (index, landmark) in landmarks.enumerated() {
            let y = world.length + 160 + Double(index) * 800 - scroll
            let bounds = world.corridor(at: y)
            landmark.position = SCNVector3(horizontal ? (bounds.lowerBound + bounds.upperBound) / 2 : world.width / 2, y, -30)
            landmark.isHidden = y < -260 || y > world.length + 300
        }
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

    private func makeLandmark(_ index: Int) -> SCNNode {
        let root = SCNNode()
        let industrial = biome == .harbor || biome == .orbit
        let steel: UInt32 = 0x6B7873
        func bridge(_ width: CGFloat) {
            ModelArt.box(width, 47, 9, steel, in: root)
            for side in [-1.0, 1.0] {
                ModelArt.box(width, 3, 3, 0x34433F, in: root, at: SCNVector3(0, side * 24, 21))
                for i in -4...4 {
                    let x = Double(i) * Double(width) / 9
                    ModelArt.box(3, 3, 23, 0x465550, in: root, at: SCNVector3(x, side * 24, 9))
                    let brace = ModelArt.box(width / 9, 2.5, 2.5, 0x465550, in: root, at: SCNVector3(x + Double(width) / 18, side * 24, 10))
                    brace.eulerAngles.y = i.isMultiple(of: 2) ? 0.42 : -0.42
                }
            }
            for i in -7...7 { ModelArt.box(10, 1, 0.6, 0xB7B6A0, in: root, at: SCNVector3(i * 23, 0, 5)) }
            for side in [-1.0, 1.0] { ModelArt.box(35, 68, 30, 0x777E70, in: root, at: SCNVector3(side * Double(width) * 0.43, 0, -12)) }
        }
        func building(x: Double, y: Double, width: CGFloat, length: CGFloat) {
            ModelArt.box(width + 8, length + 8, 5, 0x555F57, in: root, at: SCNVector3(x, y, 3))
            ModelArt.box(width, length, 20, 0x7D8575, in: root, at: SCNVector3(x, y, 15))
            for row in -2...2 {
                ModelArt.box(width - 4, 2, 1, 0x4A5750, in: root, at: SCNVector3(x, y + Double(row) * Double(length) / 6, 26))
            }
            ModelArt.box(width * 0.6, 2, 13, 0x303D3B, in: root, at: SCNVector3(x, y - Double(length) / 2 - 0.5, 11))
        }
        func tanks(x: Double, y: Double) {
            for row in 0..<3 {
                let tank = ModelArt.part(SCNCylinder(radius: 13, height: 22), steel, in: root,
                                         at: SCNVector3(x, y + Double(row * 33), 12), metal: true)
                tank.eulerAngles.x = .pi / 2
                ModelArt.box(3, 7, 1, 0x394944, in: root, at: SCNVector3(x, y + Double(row * 33), 24))
            }
        }
        if biome == .ocean {
            for side in [-1.0, 1.0] {
                let island = ModelArt.coastalIsland()
                island.scale = SCNVector3(1.2, 1.5, 0.6)
                island.position = SCNVector3(side * 145, 0, -35); root.addChildNode(island)
            }
            if index.isMultiple(of: 2) { bridge(330) }
            else {
                ModelArt.box(95, 190, 6, 0x777E6C, in: root, at: SCNVector3(-125, 0, 0))
                building(x: -125, y: 43, width: 44, length: 53)
                for y in -3...1 { ModelArt.box(3, 14, 1, 0xC1BCA2, in: root, at: SCNVector3(-125, y * 23, 4)) }
                ModelArt.box(110, 17, 8, steel, in: root, at: SCNVector3(85, -20, 0))
                tanks(x: 143, y: -40)
            }
        } else if industrial {
            if biome == .orbit {
                ModelArt.box(340, 215, 12, 0x3D4B51, in: root, at: SCNVector3(0, 0, -3))
                for side in [-1.0, 1.0] {
                    ModelArt.box(28, 200, 9, 0x8A9390, in: root, at: SCNVector3(side * 158, 0, 6))
                    for row in -4...4 { ModelArt.box(25, 5, 2, 0x26353E, in: root, at: SCNVector3(side * 158, Double(row * 20), 12)) }
                }
                for row in -2...2 { ModelArt.box(260, 2, 1, 0x65716F, in: root, at: SCNVector3(0, row * 37, 4)) }
            } else {
                ModelArt.box(165, 230, 13, 0x737E73, in: root, at: SCNVector3(-130, 0, -2))
                for row in 0..<4 {
                    ModelArt.box(55, 23, 17, 0x56675F, in: root, at: SCNVector3(-140, Double(row * 37 - 65), 12))
                    for rib in -3...3 { ModelArt.box(1.3, 23, 1, 0x899387, in: root, at: SCNVector3(-140 + rib * 7, row * 37 - 65, 21)) }
                }
            }
            if index.isMultiple(of: 2) { bridge(410) }
            else {
                building(x: -112, y: 16, width: 62, length: 83)
                tanks(x: 120, y: -53)
                for side in [-1.0, 1.0] {
                    let pipe = ModelArt.part(SCNCylinder(radius: 6, height: 210), 0x8A9386, in: root,
                                             at: SCNVector3(side * 76, 0, 8), metal: true)
                    for row in -3...3 { ModelArt.box(17, 3, 14, 0x46554F, in: pipe, at: SCNVector3(0, row * 30, -3)) }
                }
            }
        } else {
            if index.isMultiple(of: 2) {
                bridge(370)
                for side in [-1.0, 1.0] {
                    let rock = ModelArt.rock(seed: index + 3, tint: biome == .glacier ? 0x9CB4B7 : 0xB9A080)
                    rock.scale = SCNVector3(1.5, 1.6, 1); rock.position = SCNVector3(side * 168, 0, -15)
                    root.addChildNode(rock)
                }
            } else {
                ModelArt.box(75, 240, 3, 0x73776B, in: root, at: SCNVector3(-50, 0, -1))
                for row in -5...5 { ModelArt.box(2, 11, 1, 0xC2BCA4, in: root, at: SCNVector3(-50, row * 21, 1)) }
                building(x: 100, y: 40, width: 65, length: 78)
                tanks(x: 115, y: -75)
                for row in 0..<4 {
                    ModelArt.box(17, 8, CGFloat(9 + row % 2 * 9), steel, in: root, at: SCNVector3(-125, row * 21 - 42, 5))
                }
                if biome == .glacier {
                    ModelArt.part(SCNCylinder(radius: 8, height: 230), steel, in: root, at: SCNVector3(27, 0, 6), metal: true)
                    for row in -3...3 { ModelArt.box(25, 6, 18, 0x657878, in: root, at: SCNVector3(27, row * 32, -2)) }
                }
            }
        }
        root.eulerAngles.z = index.isMultiple(of: 2) ? -0.12 : 0.08
        return root
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
