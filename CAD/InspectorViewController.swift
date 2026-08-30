import Cocoa

protocol InspectorViewControllerDelegate: AnyObject {
    func inspectorViewController(_ inspector: InspectorViewController, didUpdate box: BoxFeature, actionName: String)
}

final class InspectorViewController: NSViewController, NSTextFieldDelegate {
    weak var delegate: InspectorViewControllerDelegate?

    private let titleLabel = NSTextField(labelWithString: "Inspector")
    private let placeholderLabel = NSTextField(labelWithString: "No Selection")
    private let stack = NSStackView()
    private var widthField = NSTextField()
    private var depthField = NSTextField()
    private var heightField = NSTextField()
    private var editingBox: BoxFeature?

    override func loadView() {
        view = NSView()

        titleLabel.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        placeholderLabel.textColor = .secondaryLabelColor
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false

        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isHidden = true

        widthField = makeMillimetreField()
        depthField = makeMillimetreField()
        heightField = makeMillimetreField()
        stack.addArrangedSubview(labeledRow("Width", field: widthField))
        stack.addArrangedSubview(labeledRow("Depth", field: depthField))
        stack.addArrangedSubview(labeledRow("Height", field: heightField))

        view.addSubview(titleLabel)
        view.addSubview(placeholderLabel)
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            placeholderLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            placeholderLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            placeholderLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            stack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
        ])
    }

    func showNoSelection() {
        editingBox = nil
        titleLabel.stringValue = "Inspector"
        placeholderLabel.isHidden = false
        stack.isHidden = true
    }

    func show(box: BoxFeature) {
        editingBox = box
        titleLabel.stringValue = "Box"
        placeholderLabel.isHidden = true
        stack.isHidden = false
        widthField.doubleValue = box.width
        depthField.doubleValue = box.depth
        heightField.doubleValue = box.height
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        commitEdits()
    }

    private func commitEdits() {
        guard var box = editingBox else { return }
        let width = max(widthField.doubleValue, 0.01)
        let depth = max(depthField.doubleValue, 0.01)
        let height = max(heightField.doubleValue, 0.01)
        guard width != box.width || depth != box.depth || height != box.height else { return }
        box.width = width
        box.depth = depth
        box.height = height
        editingBox = box
        delegate?.inspectorViewController(self, didUpdate: box, actionName: "Resize Box")
    }

    private func makeMillimetreField() -> NSTextField {
        let field = NSTextField()
        field.translatesAutoresizingMaskIntoConstraints = false
        field.alignment = .right
        field.formatter = millimetreFormatter()
        field.delegate = self
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.widthAnchor.constraint(greaterThanOrEqualToConstant: 72).isActive = true
        field.setAccessibilityLabel("Millimetres")
        return field
    }

    private func labeledRow(_ title: String, field: NSTextField) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        let unit = NSTextField(labelWithString: "mm")
        unit.textColor = .secondaryLabelColor
        let row = NSStackView(views: [label, field, unit])
        row.orientation = .horizontal
        row.spacing = 8
        row.alignment = .centerY
        label.widthAnchor.constraint(equalToConstant: 56).isActive = true
        return row
    }

    private func millimetreFormatter() -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 3
        formatter.minimum = 0.01
        return formatter
    }
}
