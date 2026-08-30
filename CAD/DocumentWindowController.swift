import Cocoa
import OCCTSwiftViewport

final class DocumentWindowController: NSWindowController, NSToolbarDelegate {
    private let splitViewController = NSSplitViewController()
    let browserViewController = BrowserViewController()
    let viewportViewController = ViewportViewController()
    let inspectorViewController = InspectorViewController()

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
        window.setFrameUsingName("CADDocumentWindow")
        window.setFrameAutosaveName("CADDocumentWindow")
    }

    func reloadPart() {
        guard let document = document as? Document else { return }
        browserViewController.reload(document.part)
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

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [
            .toggleSidebar,
            .sidebarTrackingSeparator,
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
        nil
    }
}
