import Foundation
import OCCTSwiftViewport
import simd

enum Tessellator {
    static let solidColor = SIMD4<Float>(0.55, 0.62, 0.72, 1)

    static func bodies(from part: PartFile) -> [ViewportBody] {
        part.features.compactMap { feature in
            switch feature {
            case .box(let box):
                return boxBody(box)
            case .cylinder(let cylinder):
                return cylinderBody(cylinder)
            case .sphere(let sphere):
                return sphereBody(sphere)
            }
        }
    }

    private static func boxBody(_ box: BoxFeature) -> ViewportBody {
        var body = ViewportBody.box(
            id: box.id.uuidString,
            width: Float(box.width),
            height: Float(box.depth),
            depth: Float(box.height),
            color: solidColor
        )
        body.transform = simd_float4x4(translation: SIMD3(
            Float(box.originX),
            Float(box.originY),
            Float(box.originZ)
        ))
        return body
    }

    private static func cylinderBody(_ cylinder: CylinderFeature) -> ViewportBody {
        var body = ViewportBody.cylinder(
            id: cylinder.id.uuidString,
            radius: Float(cylinder.radius),
            height: Float(cylinder.height),
            color: solidColor
        )
        // Viewport cylinders are Y-up; CAD is Z-up.
        body.transform = simd_float4x4(translation: SIMD3(
            Float(cylinder.originX),
            Float(cylinder.originY),
            Float(cylinder.originZ)
        )) * simd_float4x4(rotationX: .pi / 2)
        return body
    }

    private static func sphereBody(_ sphere: SphereFeature) -> ViewportBody {
        var body = ViewportBody.sphere(
            id: sphere.id.uuidString,
            radius: Float(sphere.radius),
            color: solidColor
        )
        body.transform = simd_float4x4(translation: SIMD3(
            Float(sphere.originX),
            Float(sphere.originY),
            Float(sphere.originZ)
        ))
        return body
    }
}

private extension simd_float4x4 {
    init(translation: SIMD3<Float>) {
        self = matrix_identity_float4x4
        columns.3 = SIMD4<Float>(translation.x, translation.y, translation.z, 1)
    }

    init(rotationX radians: Float) {
        let c = cos(radians)
        let s = sin(radians)
        self = matrix_identity_float4x4
        columns.1 = SIMD4<Float>(0, c, s, 0)
        columns.2 = SIMD4<Float>(0, -s, c, 0)
    }
}
