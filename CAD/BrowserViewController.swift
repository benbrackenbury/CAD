import Cocoa

protocol BrowserViewControllerDelegate: AnyObject {
    func browserViewController(_ browser: BrowserViewController, didSelectFeatureID id: UUID?)
}

final class BrowserViewController: NSViewController, NSOutlineViewDataSource, NSOutlineViewDelegate {
    private enum Group: String, CaseIterable {
        case bodies = "Bodies"
        case timeline = "Timeline"
    }

    weak var delegate: BrowserViewControllerDelegate?

    private let outline = NSOutlineView()
    private let scrollView = NSScrollView()
    private var part = PartFile()
    private var selectedFeatureID: UUID?

    override func loadView() {
        view = NSView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        column.title = "Part"
        outline.addTableColumn(column)
        outline.outlineTableColumn = column
        outline.headerView = nil
        outline.delegate = self
        outline.dataSource = self
        outline.rowSizeStyle = .default
        outline.allowsMultipleSelection = false
        outline.selectionHighlightStyle = .regular
        outline.style = .sourceList
        outline.floatsGroupRows = false
        outline.indentationPerLevel = 12
        outline.backgroundColor = .clear

        scrollView.documentView = outline
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        reload(part, selectedFeatureID: selectedFeatureID)
    }

    func reload(_ part: PartFile, selectedFeatureID: UUID?) {
        self.part = part
        self.selectedFeatureID = selectedFeatureID
        outline.reloadData()
        outline.expandItem(Group.bodies)
        outline.expandItem(Group.timeline)
        if let selectedFeatureID {
            let row = outline.row(forItem: selectedFeatureID.uuidString)
            if row >= 0 {
                outline.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            }
        } else {
            outline.deselectAll(nil)
        }
    }

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil {
            return Group.allCases.count
        }
        if let group = item as? Group {
            switch group {
            case .bodies:
                return part.features.isEmpty ? 0 : 1
            case .timeline:
                return part.features.count
            }
        }
        return 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil {
            return Group.allCases[index]
        }
        if let group = item as? Group {
            switch group {
            case .bodies:
                return "Body 1"
            case .timeline:
                return part.features[index].id.uuidString
            }
        }
        return index
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        item is Group
    }

    func outlineView(_ outlineView: NSOutlineView, isGroupItem item: Any) -> Bool {
        item is Group
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("SidebarCell")
        let cell = outlineView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView
            ?? makeCell(identifier: identifier)
        if let group = item as? Group {
            cell.textField?.stringValue = group.rawValue
            cell.textField?.font = .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)
        } else if let idString = item as? String, let id = UUID(uuidString: idString),
                  let feature = part.features.first(where: { $0.id == id }) {
            cell.textField?.stringValue = feature.timelineName
            cell.textField?.font = .systemFont(ofSize: NSFont.systemFontSize)
        } else if let title = item as? String {
            cell.textField?.stringValue = title
            cell.textField?.font = .systemFont(ofSize: NSFont.systemFontSize)
        }
        return cell
    }

    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        item is String && UUID(uuidString: item as? String ?? "") != nil
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard outline.selectedRow >= 0 else { return }
        let item = outline.item(atRow: outline.selectedRow) as? String
        delegate?.browserViewController(self, didSelectFeatureID: item.flatMap(UUID.init(uuidString:)))
    }

    private func makeCell(identifier: NSUserInterfaceItemIdentifier) -> NSTableCellView {
        let cell = NSTableCellView()
        cell.identifier = identifier
        let field = NSTextField(labelWithString: "")
        field.translatesAutoresizingMaskIntoConstraints = false
        field.lineBreakMode = .byTruncatingTail
        cell.addSubview(field)
        cell.textField = field
        NSLayoutConstraint.activate([
            field.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
            field.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -2),
            field.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])
        return cell
    }
}
