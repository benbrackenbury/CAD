import Foundation

enum Units: String, Codable, Sendable {
    case millimetres = "mm"
}

struct BoxFeature: Codable, Equatable, Sendable, Identifiable {
    var id: UUID
    var width: Double
    var depth: Double
    var height: Double
    var originX: Double
    var originY: Double
    var originZ: Double

    init(
        id: UUID = UUID(),
        width: Double,
        depth: Double,
        height: Double,
        originX: Double = 0,
        originY: Double = 0,
        originZ: Double = 0
    ) {
        self.id = id
        self.width = width
        self.depth = depth
        self.height = height
        self.originX = originX
        self.originY = originY
        self.originZ = originZ
    }
}

enum Feature: Equatable, Sendable, Identifiable {
    case box(BoxFeature)

    var id: UUID {
        switch self {
        case .box(let feature):
            return feature.id
        }
    }

    var timelineName: String {
        switch self {
        case .box:
            return "Box"
        }
    }
}

extension Feature: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
    }

    private enum FeatureType: String, Codable {
        case box
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(FeatureType.self, forKey: .type)
        switch type {
        case .box:
            self = .box(try BoxFeature(from: decoder))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .box(let feature):
            try container.encode(FeatureType.box, forKey: .type)
            try feature.encode(to: encoder)
        }
    }
}

enum PartFileError: LocalizedError {
    case unsupportedVersion(Int)

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version):
            return "This file uses format version \(version), which CAD cannot open."
        }
    }
}

struct PartFile: Codable, Equatable, Sendable {
    static let currentVersion = 1

    var version: Int
    var units: Units
    var features: [Feature]

    init(
        version: Int = currentVersion,
        units: Units = .millimetres,
        features: [Feature] = []
    ) {
        self.version = version
        self.units = units
        self.features = features
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    static func decoded(from data: Data) throws -> PartFile {
        let file = try JSONDecoder().decode(PartFile.self, from: data)
        guard file.version <= currentVersion else {
            throw PartFileError.unsupportedVersion(file.version)
        }
        return file
    }
}
