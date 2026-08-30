import Cocoa
import Combine
import OCCTSwiftViewport
import simd
import SwiftUI

final class ViewportScene: ObservableObject {
    @Published var bodies: [ViewportBody] = []
}

struct ViewportRoot: View {
    @ObservedObject var controller: ViewportController
    @ObservedObject var scene: ViewportScene

    var body: some View {
        MetalViewportView(controller: controller, bodies: $scene.bodies)
    }
}

final class BodyDragOverlay: NSView {
    weak var owner: ViewportViewController?

    override var isOpaque: Bool { false }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let event = NSApp.currentEvent else { return nil }
        if event.type == .scrollWheel { return nil }
        let modifiers = event.modifierFlags.intersection([.shift, .option, .command, .control])
        if !modifiers.isEmpty { return nil }
        let cube: CGFloat = 120
        if point.x > bounds.width - cube && point.y < cube { return nil }
        if point.x < 88 && point.y > bounds.height - 88 { return nil }
        return self
    }

    override func mouseDown(with event: NSEvent) {
        owner?.beginBodyDrag(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        owner?.continueBodyDrag(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        owner?.endBodyDrag()
    }
}

final class ViewportViewController: NSViewController {
    private(set) var controller: ViewportController
    let scene = ViewportScene()
    var onSelectFeature: ((UUID?) -> Void)?
    var originOfFeature: ((UUID) -> (x: Double, y: Double, z: Double)?)?
    var onPreviewOrigin: ((UUID, Double, Double, Double) -> Void)?
    var onCommitMove: ((UUID, Double, Double, Double) -> Void)?

    var bodies: [ViewportBody] {
        get { scene.bodies }
        set { scene.bodies = newValue }
    }

    private var overlay: BodyDragOverlay?
    private var dragID: UUID?
    private var dragStart: (x: Double, y: Double, z: Double)?
    private var dragOrigin: (x: Double, y: Double, z: Double)?
    private var lastDragPoint: NSPoint = .zero

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
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let container = NSView()
        let hosting = NSHostingView(rootView: ViewportRoot(controller: controller, scene: scene))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        let overlay = BodyDragOverlay()
        overlay.owner = self
        overlay.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hosting)
        container.addSubview(overlay)
        NSLayoutConstraint.activate([
            hosting.topAnchor.constraint(equalTo: container.topAnchor),
            hosting.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hosting.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            overlay.topAnchor.constraint(equalTo: container.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        self.overlay = overlay
        view = container
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
        controller.selectedBodyIDs = []
        let selectedID = featureID?.uuidString
        for index in scene.bodies.indices {
            scene.bodies[index].color =
                scene.bodies[index].id == selectedID
                ? Tessellator.selectedColor
                : Tessellator.solidColor
        }
    }

    func setBodyOrigin(id: UUID, x: Double, y: Double, z: Double) {
        guard let index = scene.bodies.firstIndex(where: { $0.id == id.uuidString }) else { return }
        scene.bodies[index].transform.columns.3 = SIMD4(Float(x), Float(y), Float(z), 1)
    }

    func beginBodyDrag(with event: NSEvent) {
        let point = view.convert(event.locationInWindow, from: nil)
        lastDragPoint = event.locationInWindow
        guard let id = pickFeatureID(at: point), let origin = originOfFeature?(id) else {
            dragID = nil
            onSelectFeature?(nil)
            return
        }
        dragID = id
        dragStart = origin
        dragOrigin = origin
        onSelectFeature?(id)
    }

    func continueBodyDrag(with event: NSEvent) {
        guard let id = dragID, var origin = dragOrigin else { return }
        let point = event.locationInWindow
        let delta = SIMD2<Float>(
            Float(point.x - lastDragPoint.x),
            Float(point.y - lastDragPoint.y)
        )
        lastDragPoint = point
        let camera = controller.cameraState
        let gestures = controller.configuration.gestureConfiguration
        let scale = max(gestures.minPanSpeed, camera.distance * gestures.panSensitivity)
        let world = camera.rightVector * delta.x * scale + camera.upVector * delta.y * scale
        origin.x += Double(world.x)
        origin.y += Double(world.y)
        origin.z += Double(world.z)
        dragOrigin = origin
        let x = origin.x.rounded()
        let y = origin.y.rounded()
        let z = origin.z.rounded()
        setBodyOrigin(id: id, x: x, y: y, z: z)
        onPreviewOrigin?(id, x, y, z)
    }

    func endBodyDrag() {
        defer {
            dragID = nil
            dragStart = nil
            dragOrigin = nil
        }
        guard let id = dragID, let origin = dragOrigin, let start = dragStart else { return }
        let x = origin.x.rounded()
        let y = origin.y.rounded()
        let z = origin.z.rounded()
        guard x != start.x || y != start.y || z != start.z else { return }
        onCommitMove?(id, x, y, z)
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

    fileprivate func pickFeatureID(at viewPoint: NSPoint) -> UUID? {
        let size = view.bounds.size
        guard size.width > 1, size.height > 1 else { return nil }
        let ndc = SIMD2<Float>(
            Float(viewPoint.x / size.width) * 2 - 1,
            Float(viewPoint.y / size.height) * 2 - 1
        )
        let ray = Ray.fromCamera(
            ndc: ndc,
            cameraState: controller.cameraState,
            aspectRatio: Float(size.width / size.height)
        )
        var best: (UUID, Float)?
        for body in scene.bodies {
            guard body.isVisible, let id = UUID(uuidString: body.id) else { continue }
            let inverse = body.transform.inverse
            let origin = inverse * SIMD4<Float>(ray.origin.x, ray.origin.y, ray.origin.z, 1)
            let direction = inverse * SIMD4<Float>(ray.direction.x, ray.direction.y, ray.direction.z, 0)
            let localDirection = SIMD3<Float>(direction.x, direction.y, direction.z)
            guard simd_length_squared(localDirection) > 1e-12 else { continue }
            let localRay = Ray(
                origin: SIMD3(origin.x, origin.y, origin.z),
                direction: localDirection
            )
            if let box = body.boundingBox, localRay.intersects(box) == nil { continue }
            let stride = 6
            var index = 0
            while index + 2 < body.indices.count {
                func vertex(_ i: Int) -> SIMD3<Float> {
                    let base = Int(body.indices[i]) * stride
                    return SIMD3(
                        body.vertexData[base],
                        body.vertexData[base + 1],
                        body.vertexData[base + 2]
                    )
                }
                if let distance = localRay.intersectsTriangle(
                    v0: vertex(index),
                    v1: vertex(index + 1),
                    v2: vertex(index + 2)
                ), best == nil || distance < best!.1 {
                    best = (id, distance)
                }
                index += 3
            }
        }
        return best?.0
    }
}
