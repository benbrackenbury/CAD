import Cocoa

final class ViewportView: NSView {
    override var isOpaque: Bool { true }
    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
    }
}

final class ViewportViewController: NSViewController {
    override func loadView() {
        view = ViewportView()
    }
}
