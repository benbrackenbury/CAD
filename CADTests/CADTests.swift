import Foundation
import Testing
@testable import CAD

struct PartFileTests {
    @Test func emptyPartRoundTrips() throws {
        let original = PartFile()
        let data = try original.encoded()
        let loaded = try PartFile.decoded(from: data)
        #expect(loaded == original)
        #expect(loaded.version == 1)
        #expect(loaded.units == .millimetres)
        #expect(loaded.features.isEmpty)
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("\"units\" : \"mm\""))
    }

    @Test func boxFeatureRoundTrips() throws {
        let box = BoxFeature(width: 40, depth: 20, height: 10)
        let original = PartFile(features: [.box(box)])
        let loaded = try PartFile.decoded(from: original.encoded())
        #expect(loaded == original)
    }

    @Test func cylinderAndSphereRoundTrip() throws {
        let original = PartFile(features: [
            .cylinder(CylinderFeature(radius: 10, height: 30)),
            .sphere(SphereFeature(radius: 15)),
        ])
        let loaded = try PartFile.decoded(from: original.encoded())
        #expect(loaded == original)
    }

    @Test func futureVersionIsRejected() {
        let json = """
        { "version": 99, "units": "mm", "features": [] }
        """.data(using: .utf8)!
        #expect(throws: PartFileError.self) {
            try PartFile.decoded(from: json)
        }
    }
}
