import Cocoa
import OCCTSwiftViewport
import simd

final class DocumentWindowController: NSWindowController, NSToolbarDelegate, BrowserViewControllerDelegate, InspectorViewControllerDelegate {
    private let splitViewController = NSSplitViewController()
    let browserViewController = BrowserViewController()
    let viewportViewController = ViewportViewController()
    let inspectorViewController = InspectorViewController()
    private var selectedFeatureID: UUID?

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.minSize = NSSize(width: 800, height: 500)
        window.tabbingMode = .automatic
        window.setContentSize(NSSize(width: 1100, height: 720))
        window.center()
        self.init(window: window)
        shouldCascadeWindows = true
        window.contentViewController = splitViewController
        configureSplit()
        configureToolbar()
        browserViewController.delegate = self
        inspectorViewController.delegate = self
        wireViewportInteraction()
        window.setFrameUsingName("CADDocumentWindow")
        window.setFrameAutosaveName("CADDocumentWindow")
    }

    func reloadPart() {
        guard let document = document as? Document else { return }
        if let selectedFeatureID, !document.part.features.contains(where: { $0.id == selectedFeatureID }) {
            self.selectedFeatureID = nil
        }
        browserViewController.reload(document.part, selectedFeatureID: selectedFeatureID)
        viewportViewController.bodies = Tessellator.bodies(from: document.part)
        viewportViewController.highlight(featureID: selectedFeatureID)
        refreshInspector()
    }

    func selectFeature(_ id: UUID?) {
        selectedFeatureID = id
        guard let document = document as? Document else { return }
        browserViewController.reload(document.part, selectedFeatureID: id)
        viewportViewController.highlight(featureID: id)
        refreshInspector()
    }

    func browserViewController(_ browser: BrowserViewController, didSelectFeatureID id: UUID?) {
        selectedFeatureID = id
        refreshInspector()
    }

    func inspectorViewController(_ inspector: InspectorViewController, didUpdate feature: Feature, actionName: String) {
        (document as? Document)?.updateFeature(feature, actionName: actionName)
    }

    private func refreshInspector() {
        guard let document = document as? Document,
              let selectedFeatureID,
              let feature = document.part.features.first(where: { $0.id == selectedFeatureID })
        else {
            inspectorViewController.showNoSelection()
            return
        }
        inspectorViewController.show(feature)
    }

    private func configureSplit() {
        let sidebar = NSSplitViewItem(sidebarWithViewController: browserViewController)
        sidebar.minimumThickness = 180
        sidebar.maximumThickness = 320
        sidebar.canCollapse = true
        sidebar.titlebarSeparatorStyle = .automatic

        let content = NSSplitViewItem(viewController: viewportViewController)
        content.minimumThickness = 360
        content.titlebarSeparatorStyle = .line

        let inspector = NSSplitViewItem(inspectorWithViewController: inspectorViewController)
        inspector.minimumThickness = 220
        inspector.maximumThickness = 360
        inspector.canCollapse = true
        inspector.titlebarSeparatorStyle = .automatic

        splitViewController.addSplitViewItem(sidebar)
        splitViewController.addSplitViewItem(content)
        splitViewController.addSplitViewItem(inspector)
        splitViewController.splitView.isVertical = true
        splitViewController.splitView.dividerStyle = .thin
    }

    private func configureToolbar() {
        let toolbar = NSToolbar(identifier: NSToolbar.Identifier("CADDocumentToolbar"))
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = true
        toolbar.autosavesConfiguration = true
        window?.toolbar = toolbar
        window?.toolbarStyle = .unified
    }

    private let boxItemIdentifier = NSToolbarItem.Identifier("InsertBox")

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [
            .toggleSidebar,
            .sidebarTrackingSeparator,
            boxItemIdentifier,
            .flexibleSpace,
            .inspectorTrackingSeparator,
            .toggleInspector,
        ]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    @objc func frameSelection(_ sender: Any?) {
        viewportViewController.frameAll()
    }

    @objc func viewFront(_ sender: Any?) { viewportViewController.goToStandardView(.front) }
    @objc func viewBack(_ sender: Any?) { viewportViewController.goToStandardView(.back) }
    @objc func viewLeft(_ sender: Any?) { viewportViewController.goToStandardView(.left) }
    @objc func viewRight(_ sender: Any?) { viewportViewController.goToStandardView(.right) }
    @objc func viewTop(_ sender: Any?) { viewportViewController.goToStandardView(.top) }
    @objc func viewBottom(_ sender: Any?) { viewportViewController.goToStandardView(.bottom) }
    @objc func viewIsometric(_ sender: Any?) { viewportViewController.goToStandardView(.isometricFrontRight) }

    @objc func toggleOrthographic(_ sender: Any?) {
        viewportViewController.toggleProjection()
    }

    @objc func toggleGridShown(_ sender: Any?) {
        viewportViewController.toggleGrid()
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        switch itemIdentifier {
        case boxItemIdentifier:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Box"
            item.paletteLabel = "Insert Box"
            item.toolTip = "Insert a box"
            item.image = NSImage(systemSymbolName: "cube", accessibilityDescription: "Insert Box")
            item.target = self
            item.action = #selector(insertBox(_:))
            return item
        default:
            return nil
        }
    }

    private struct BodyDrag {
        var id: UUID
        var startX: Double
        var startY: Double
        var startZ: Double
        var x: Double
        var y: Double
        var z: Double
        var pendingDelta: SIMD2<Float>
        var isMoving: Bool
    }

    private var bodyDrag: BodyDrag?

    private func wireViewportInteraction() {
        let viewport = viewportViewController
        viewport.controller.onPick = { [weak self] result in
            self?.handleViewportPick(result)
        }
        viewport.controller.onInputEvent = { [weak self] event in
            self?.handleViewportInput(event)
        }
    }

    private func handleViewportPick(_ result: PickResult?) {
        if let result, let id = UUID(uuidString: result.bodyID) {
            selectFeature(id)
            if var drag = bodyDrag, !drag.isMoving, let feature = currentFeature(id: id) {
                drag.id = id
                drag.startX = feature.originX
                drag.startY = feature.originY
                drag.startZ = feature.originZ
                drag.x = feature.originX
                drag.y = feature.originY
                drag.z = feature.originZ
                drag.isMoving = true
                bodyDrag = drag
                applyPendingDrag()
            }
            return
        }
        if bodyDrag?.isMoving != true {
            bodyDrag = nil
            selectFeature(nil)
        }
    }

    private func handleViewportInput(_ event: ViewportInputEvent) {
        switch event {
        case .dragChanged(let delta, let modifiers):
            let action = viewportViewController.controller.configuration.gestureConfiguration.dragAction(for: modifiers)
            guard action == .select else {
                bodyDrag = nil
                return
            }
            if var drag = bodyDrag {
                drag.pendingDelta += delta
                bodyDrag = drag
                applyPendingDrag()
            } else {
                bodyDrag = BodyDrag(
                    id: selectedFeatureID ?? UUID(),
                    startX: 0, startY: 0, startZ: 0,
                    x: 0, y: 0, z: 0,
                    pendingDelta: delta,
                    isMoving: false
                )
            }
        case .dragEnded:
            commitBodyDrag()
        default:
            break
        }
    }

    private func applyPendingDrag() {
        guard var drag = bodyDrag, drag.isMoving else { return }
        let camera = viewportViewController.controller.cameraState
        let gestures = viewportViewController.controller.configuration.gestureConfiguration
        let scale = max(gestures.minPanSpeed, camera.distance * gestures.panSensitivity)
        let delta = drag.pendingDelta
        drag.pendingDelta = .zero
        let world = camera.rightVector * delta.x * scale + camera.upVector * (-delta.y) * scale
        drag.x += Double(world.x)
        drag.y += Double(world.y)
        drag.z += Double(world.z)
        let x = drag.x.rounded()
        let y = drag.y.rounded()
        let z = drag.z.rounded()
        bodyDrag = drag
        viewportViewController.setBodyOrigin(id: drag.id, x: x, y: y, z: z)
        if let feature = currentFeature(id: drag.id) {
            inspectorViewController.show(feature.placing(x: x, y: y, z: z))
        }
    }

    private func commitBodyDrag() {
        defer { bodyDrag = nil }
        guard let drag = bodyDrag, drag.isMoving else { return }
        let x = drag.x.rounded()
        let y = drag.y.rounded()
        let z = drag.z.rounded()
        guard x != drag.startX || y != drag.startY || z != drag.startZ else { return }
        guard let feature = currentFeature(id: drag.id) else { return }
        (document as? Document)?.updateFeature(feature.placing(x: x, y: y, z: z), actionName: "Move")
    }

    private func currentFeature(id: UUID) -> Feature? {
        (document as? Document)?.part.features.first { $0.id == id }
    }

    @objc func insertBox(_ sender: Any?) {
        (document as? Document)?.insertBox()
    }

    @objc func insertCylinder(_ sender: Any?) {
        (document as? Document)?.insertCylinder()
    }

    @objc func insertSphere(_ sender: Any?) {
        (document as? Document)?.insertSphere()
    }

    override func keyDown(with event: NSEvent) {
        if event.charactersIgnoringModifiers == "\u{7F}" || event.charactersIgnoringModifiers == "\u{F728}" {
            deleteForward(nil)
            return
        }
        super.keyDown(with: event)
    }

    override func deleteForward(_ sender: Any?) {
        guard let selectedFeatureID else { return }
        (document as? Document)?.deleteFeature(id: selectedFeatureID)
        self.selectedFeatureID = nil
    }

    override func deleteBackward(_ sender: Any?) {
        deleteForward(sender)
    }
}
