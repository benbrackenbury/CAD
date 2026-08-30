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
}

private extension simd_float4x4 {
    init(translation: SIMD3<Float>) {
        self = matrix_identity_float4x4
        columns.3 = SIMD4<Float>(translation.x, translation.y, translation.z, 1)
    }
}
