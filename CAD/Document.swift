import Cocoa

final class Document: NSDocument {
    static let uti = "dev.brackenbury.cad"

    var part = PartFile()

    override init() {
        super.init()
        fileType = Self.uti
    }

    override nonisolated class var autosavesInPlace: Bool {
        true
    }

    override nonisolated class var readableTypes: [String] {
        [uti]
    }

    override nonisolated func writableTypes(for saveOperation: NSDocument.SaveOperationType) -> [String] {
        [Self.uti]
    }

    override func makeWindowControllers() {
        let controller = DocumentWindowController()
        addWindowController(controller)
        controller.reloadPart()
        controller.showWindow(self)
    }

    override func data(ofType typeName: String) throws -> Data {
        try part.encoded()
    }

    override nonisolated func read(from data: Data, ofType typeName: String) throws {
        let loaded = try PartFile.decoded(from: data)
        MainActor.assumeIsolated {
            part = loaded
        }
    }

    override func windowControllerDidLoadNib(_ windowController: NSWindowController) {
        super.windowControllerDidLoadNib(windowController)
        (windowController as? DocumentWindowController)?.reloadPart()
    }

    func notifyWindows() {
        for controller in windowControllers {
            (controller as? DocumentWindowController)?.reloadPart()
        }
    }

    func replacePart(_ newPart: PartFile, actionName: String) {
        let oldPart = part
        undoManager?.registerUndo(withTarget: self) { document in
            document.replacePart(oldPart, actionName: actionName)
        }
        undoManager?.setActionName(actionName)
        part = newPart
        notifyWindows()
    }

    func insertBox() {
        insert(.box(BoxFeature(width: 40, depth: 20, height: 10)), actionName: "Insert Box")
    }

    func insertCylinder() {
        insert(.cylinder(CylinderFeature(radius: 10, height: 30)), actionName: "Insert Cylinder")
    }

    func insertSphere() {
        insert(.sphere(SphereFeature(radius: 15)), actionName: "Insert Sphere")
    }

    func updateFeature(_ feature: Feature, actionName: String) {
        var next = part
        guard let index = next.features.firstIndex(where: { $0.id == feature.id }) else { return }
        next.features[index] = feature
        replacePart(next, actionName: actionName)
    }

    private func insert(_ feature: Feature, actionName: String) {
        var next = part
        next.features.append(feature)
        replacePart(next, actionName: actionName)
        if let windowController = windowControllers.first as? DocumentWindowController {
            windowController.selectFeature(feature.id)
        }
    }

    func deleteFeature(id: UUID) {
        var next = part
        next.features.removeAll { $0.id == id }
        replacePart(next, actionName: "Delete")
    }
}
