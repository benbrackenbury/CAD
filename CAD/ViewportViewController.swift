import Cocoa
import OCCTSwiftViewport
import simd
import SwiftUI

struct ViewportRoot: View {
    @ObservedObject var controller: ViewportController
    @Binding var bodies: [ViewportBody]

    var body: some View {
        MetalViewportView(controller: controller, bodies: $bodies)
    }
}

final class ViewportViewController: NSViewController {
    private(set) var controller: ViewportController
    var bodies: [ViewportBody] = [] {
        didSet {
            bodiesBox.value = bodies
            hostingView?.rootView = ViewportRoot(controller: controller, bodies: bindingBodies)
        }
    }

    private var hostingView: NSHostingView<ViewportRoot>?
    private var bodiesBox: BodiesBox

    private final class BodiesBox {
        var value: [ViewportBody]
        init(_ value: [ViewportBody]) { self.value = value }
    }

    init() {
        var configuration = ViewportConfiguration.cad
        configuration.gestureConfiguration = GestureConfiguration(
            mouseDrag: .select,
            shiftDrag: .pan,
            optionDrag: .orbit,
            commandDrag: .none,
            scrollWheel: .zoom,
            trackpadPinch: .zoom,
            doubleClick: .resetView
        )
        configuration.showOrientationGnomon = true
        configuration.showScaleBar = true
        configuration.scaleBarUnitLabel = "mm"
        configuration.gridStyle = .dots
        configuration.gridBaseSpacing = 1
        configuration.gridSize = 200
        configuration.axisLength = 20
        controller = ViewportController(configuration: configuration)
        bodiesBox = BodiesBox([])
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let root = ViewportRoot(controller: controller, bodies: bindingBodies)
        let hosting = NSHostingView(rootView: root)
        hostingView = hosting
        view = hosting
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.makeFirstResponder(view)
    }

    func frameAll() {
        controller.reset(animated: true)
    }

    func goToStandardView(_ view: StandardView) {
        controller.goToStandardView(view)
    }

    func toggleProjection() {
        controller.toggleProjection()
    }

    func toggleGrid() {
        controller.toggleGrid()
    }

    func highlight(featureID: UUID?) {
        if let featureID {
            controller.selectedBodyIDs = [featureID.uuidString]
        } else {
            controller.selectedBodyIDs = []
        }
    }

    func setBodyOrigin(id: UUID, x: Double, y: Double, z: Double) {
        guard let index = bodiesBox.value.firstIndex(where: { $0.id == id.uuidString }) else { return }
        var body = bodiesBox.value[index]
        body.transform.columns.3 = SIMD4(Float(x), Float(y), Float(z), 1)
        bodiesBox.value[index] = body
        hostingView?.rootView = ViewportRoot(controller: controller, bodies: bindingBodies)
    }

    @objc func frameSelection(_ sender: Any?) {
        frameAll()
    }

    @objc func viewFront(_ sender: Any?) { goToStandardView(.front) }
    @objc func viewBack(_ sender: Any?) { goToStandardView(.back) }
    @objc func viewLeft(_ sender: Any?) { goToStandardView(.left) }
    @objc func viewRight(_ sender: Any?) { goToStandardView(.right) }
    @objc func viewTop(_ sender: Any?) { goToStandardView(.top) }
    @objc func viewBottom(_ sender: Any?) { goToStandardView(.bottom) }
    @objc func viewIsometric(_ sender: Any?) { goToStandardView(.isometricFrontRight) }

    @objc func toggleOrthographic(_ sender: Any?) {
        toggleProjection()
    }

    @objc func toggleGridShown(_ sender: Any?) {
        toggleGrid()
    }

    private var bindingBodies: Binding<[ViewportBody]> {
        Binding(
            get: { [bodiesBox] in bodiesBox.value },
            set: { [bodiesBox] in bodiesBox.value = $0 }
        )
    }
}
