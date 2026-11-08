import UIKit

/// Bounds the table's presented rows while keeping searching/filtering over the
/// full data set. Accessibility inspection never causes another page to load.
final class CardListPagination: NSObject {
    private weak var tableView: UITableView?
    private let pageSize = 100
    private var total = 0
    private(set) var visibleCount = 0
    private var isLoading = false
    private let footer = UIView()
    private let moreButton = UIButton(type: .system)

    init(tableView: UITableView) {
        self.tableView = tableView
        super.init()
        footer.backgroundColor = .systemGroupedBackground
        moreButton.translatesAutoresizingMaskIntoConstraints = false
        moreButton.titleLabel?.font = .preferredFont(forTextStyle: .subheadline)
        moreButton.titleLabel?.adjustsFontForContentSizeCategory = true
        moreButton.titleLabel?.numberOfLines = 2
        moreButton.titleLabel?.textAlignment = .center
        moreButton.accessibilityIdentifier = "loadMoreCards"
        moreButton.addTarget(self, action: #selector(loadMore), for: .touchUpInside)
        footer.addSubview(moreButton)
        NSLayoutConstraint.activate([
            moreButton.leadingAnchor.constraint(equalTo: footer.leadingAnchor, constant: 16),
            moreButton.trailingAnchor.constraint(equalTo: footer.trailingAnchor, constant: -16),
            moreButton.topAnchor.constraint(equalTo: footer.topAnchor, constant: 8),
            moreButton.bottomAnchor.constraint(equalTo: footer.bottomAnchor, constant: -8)
        ])
    }

    /// Call after changing the underlying result set, then reload the table.
    func reset(total: Int) {
        self.total = max(0, total)
        visibleCount = min(pageSize, self.total)
        updateFooter()
    }

    /// Call from scrollViewDidScroll, never from willDisplay: UIKit can prepare
    /// offscreen rows during an accessibility snapshot without any user scroll.
    func loadMoreIfNeeded() {
        guard let table = tableView, !isLoading, visibleCount < total,
              table.isDragging || table.isDecelerating,
              table.contentOffset.y > 0,
              table.contentSize.height > table.bounds.height else { return }
        let remaining = table.contentSize.height - table.contentOffset.y - table.bounds.height
        guard remaining < max(220, table.bounds.height * 0.65) else { return }
        loadMore()
    }

    @objc private func loadMore() {
        guard let table = tableView, !isLoading, visibleCount < total else { return }
        isLoading = true
        let offset = table.contentOffset
        visibleCount = min(total, visibleCount + pageSize)
        updateFooter()
        table.reloadData()
        table.layoutIfNeeded()
        table.setContentOffset(offset, animated: false)
        isLoading = false
    }

    private func updateFooter() {
        guard let table = tableView else { return }
        guard visibleCount < total else {
            table.tableFooterView = UIView(frame: .zero)
            return
        }
        moreButton.setTitle(L10n.text("显示更多卡牌（\(visibleCount) / \(total)）", "Show more cards (\(visibleCount) / \(total))"), for: .normal)
        let height = max(64, UIFontMetrics(forTextStyle: .subheadline).scaledValue(for: 64))
        footer.frame = CGRect(x: 0, y: 0, width: table.bounds.width, height: height)
        table.tableFooterView = footer
    }
}
