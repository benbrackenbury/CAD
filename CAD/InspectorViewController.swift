import Cocoa

final class InspectorViewController: NSViewController {
    private let titleLabel = NSTextField(labelWithString: "Inspector")
    private let placeholderLabel = NSTextField(labelWithString: "No Selection")

    override func loadView() {
        view = NSView()

        titleLabel.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        placeholderLabel.textColor = .secondaryLabelColor
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(titleLabel)
        view.addSubview(placeholderLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            placeholderLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            placeholderLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            placeholderLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
        ])
    }
}
