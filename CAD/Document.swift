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
}
