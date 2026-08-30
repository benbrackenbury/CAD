import Cocoa
import OCCTSwiftViewport

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
        refreshInspector()
    }

    func selectFeature(_ id: UUID?) {
        selectedFeatureID = id
        reloadPart()
    }

    func browserViewController(_ browser: BrowserViewController, didSelectFeatureID id: UUID?) {
        selectedFeatureID = id
        refreshInspector()
    }

    func inspectorViewController(_ inspector: InspectorViewController, didUpdate box: BoxFeature, actionName: String) {
        (document as? Document)?.updateBox(box, actionName: actionName)
    }

    private func refreshInspector() {
        guard let document = document as? Document,
              let selectedFeatureID,
              let feature = document.part.features.first(where: { $0.id == selectedFeatureID })
        else {
            inspectorViewController.showNoSelection()
            return
        }
        switch feature {
        case .box(let box):
            inspectorViewController.show(box: box)
        }
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

    @objc func insertBox(_ sender: Any?) {
        (document as? Document)?.insertBox()
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
