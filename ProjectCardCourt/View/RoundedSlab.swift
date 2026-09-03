import RealityKit

/// A card-shaped slab: a rounded rectangle with thickness, built by hand.
///
/// RealityKit will not make this shape. `generateBox(cornerRadius:)` clamps the radius to
/// half the smallest dimension, which on something this thin is a fraction of a
/// millimetre; the `majorCornerRadius` overload does nothing for it at all; and the path
/// extrusion that would have solved it outright is visionOS only. So the mesh is written
/// out directly, which also means the radius is honoured exactly rather than approximately.
///
/// Laid flat: width along X, thickness along Y, depth along Z, centred on the origin.
enum RoundedSlab {

    /// How many segments each of the four corners is drawn with.
    static let cornerSegments = 8

    static func mesh(width: Float, depth: Float, thickness: Float,
                     radius: Float) -> MeshResource {
        let halfWidth = width / 2
        let halfDepth = depth / 2
        let r = max(0, min(radius, min(halfWidth, halfDepth)))
        let top = thickness / 2
        let ring = outline(halfWidth: halfWidth, halfDepth: halfDepth, radius: r)
        let count = ring.count

        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []

        // Caps and walls get their own copies of the ring: a vertex cannot face two ways
        // at once, and sharing them would round the lighting over the edge.
        let topCentre = UInt32(positions.count)
        positions.append(SIMD3(0, top, 0)); normals.append(SIMD3(0, 1, 0))
        let topRing = UInt32(positions.count)
        for point in ring {
            positions.append(SIMD3(point.x, top, point.y)); normals.append(SIMD3(0, 1, 0))
        }

        let bottomCentre = UInt32(positions.count)
        positions.append(SIMD3(0, -top, 0)); normals.append(SIMD3(0, -1, 0))
        let bottomRing = UInt32(positions.count)
        for point in ring {
            positions.append(SIMD3(point.x, -top, point.y)); normals.append(SIMD3(0, -1, 0))
        }

        let wallTop = UInt32(positions.count)
        for point in ring {
            let out = normalize(SIMD3(point.x, 0, point.y))
            positions.append(SIMD3(point.x, top, point.y)); normals.append(out)
        }
        let wallBottom = UInt32(positions.count)
        for point in ring {
            let out = normalize(SIMD3(point.x, 0, point.y))
            positions.append(SIMD3(point.x, -top, point.y)); normals.append(out)
        }

        for i in 0..<count {
            let next = UInt32((i + 1) % count)
            let here = UInt32(i)

            // Wound so the top faces up: (+X then -Z) is what gives a +Y normal.
            indices += [topCentre, topRing + here, topRing + next]
            indices += [bottomCentre, bottomRing + next, bottomRing + here]
            indices += [wallTop + here, wallBottom + here, wallBottom + next]
            indices += [wallTop + here, wallBottom + next, wallTop + next]
        }

        var descriptor = MeshDescriptor(name: "slab")
        descriptor.positions = MeshBuffer(positions)
        descriptor.normals = MeshBuffer(normals)
        descriptor.primitives = .triangles(indices)
        // The shape is a handful of triangles and cannot fail; a square box is a harmless
        // stand-in if a future RealityKit disagrees.
        return (try? MeshResource.generate(from: [descriptor]))
            ?? .generateBox(size: [width, thickness, depth])
    }

    /// The rounded rectangle, counter-clockwise as seen from above.
    private static func outline(halfWidth: Float, halfDepth: Float,
                                radius: Float) -> [SIMD2<Float>] {
        // Each corner's centre, in the order the ring visits them.
        let centres: [SIMD2<Float>] = [
            SIMD2(halfWidth - radius, -halfDepth + radius),
            SIMD2(-halfWidth + radius, -halfDepth + radius),
            SIMD2(-halfWidth + radius, halfDepth - radius),
            SIMD2(halfWidth - radius, halfDepth - radius),
        ]
        guard radius > 0 else { return centres }

        var points: [SIMD2<Float>] = []
        for (corner, centre) in centres.enumerated() {
            let from = Float(corner) * .pi / 2
            for step in 0...cornerSegments {
                let angle = from + Float(step) / Float(cornerSegments) * (.pi / 2)
                points.append(SIMD2(centre.x + radius * cos(angle),
                                    centre.y - radius * sin(angle)))
            }
        }
        return points
    }
}
