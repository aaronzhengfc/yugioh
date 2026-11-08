import UIKit
import Kingfisher

/// Cards are added immediately; Done returns to the refreshed personal deck.
final class DeckCardPickerViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate {
    private let service = DeckService()
    private let favorites = CardService()
    private let searchBar = UISearchBar()
    private let sectionControl = UISegmentedControl(items: [L10n.text("自动", "Auto"), L10n.text("主卡", "Main"), L10n.text("额外", "Extra"), L10n.text("副卡", "Side")])
    private let tableView = UITableView(frame: .zero, style: .plain)
    private lazy var pagination = CardListPagination(tableView: tableView)
    private let status = UILabel()
    private let emptyLabel = UILabel()
    private let hint = UILabel()
    private var allCards: [CardEntity] = []
    private var searchIndex: [String] = []
    private var results: [CardEntity] = []
    private var quantities: [String: Int] = [:]
    private var searchTask: DispatchWorkItem?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L10n.text("添加卡牌", "Add Cards")
        view.backgroundColor = .systemGroupedBackground
        view.tintColor = greenColor
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: L10n.text("完成", "Done"), style: .done, target: self, action: #selector(done))
        searchBar.placeholder = L10n.text("搜索卡名、效果或 ID", "Search name, effect or ID")
        searchBar.searchBarStyle = .minimal
        searchBar.delegate = self
        searchBar.searchTextField.autocorrectionType = .no
        searchBar.accessibilityIdentifier = "deckCardSearch"
        sectionControl.selectedSegmentIndex = 0
        sectionControl.addTarget(self, action: #selector(filterCards), for: .valueChanged)
        sectionControl.accessibilityIdentifier = "deckCardSection"
        hint.text = L10n.text("点按卡牌加 1 张；长按查看详情。自动按卡种加入主卡或额外卡组。", "Tap a card to add one copy; hold for details. Auto chooses Main or Extra Deck by card type.")
        hint.font = .preferredFont(forTextStyle: .caption1)
        hint.adjustsFontForContentSizeCategory = true
        hint.textColor = .secondaryLabel
        hint.numberOfLines = 0
        let heading = UIStackView(arrangedSubviews: [searchBar, sectionControl, hint])
        heading.axis = .vertical
        heading.spacing = 8
        heading.isLayoutMarginsRelativeArrangement = true
        heading.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: 12, bottom: 8, trailing: 12)
        status.font = .preferredFont(forTextStyle: .footnote)
        status.adjustsFontForContentSizeCategory = true
        status.textColor = .secondaryLabel
        status.numberOfLines = 3
        status.lineBreakMode = .byTruncatingTail
        status.accessibilityIdentifier = "deckAddStatus"
        let footer = UIView()
        footer.backgroundColor = .secondarySystemGroupedBackground
        footer.addSubview(status)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = .systemGroupedBackground
        tableView.separatorStyle = .none
        tableView.keyboardDismissMode = .onDrag
        tableView.register(CardTableViewCell.self, forCellReuseIdentifier: "DeckPickerCard")
        emptyLabel.text = L10n.text("没有找到符合条件的卡牌", "No cards match your search")
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        emptyLabel.font = .preferredFont(forTextStyle: .body)
        [heading, tableView, footer].forEach { view.addSubview($0); $0.translatesAutoresizingMaskIntoConstraints = false }
        status.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            heading.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            heading.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            heading.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: heading.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: footer.topAnchor),
            footer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footer.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            status.leadingAnchor.constraint(equalTo: footer.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            status.trailingAnchor.constraint(equalTo: footer.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            status.topAnchor.constraint(equalTo: footer.topAnchor, constant: 12),
            status.bottomAnchor.constraint(equalTo: footer.bottomAnchor, constant: -12)
        ])
        allCards = getCardEntity().filter { DeckService.canAdd($0, to: "1") }
        searchIndex = allCards.map {
            [$0.id ?? "", $0.enName ?? "", $0.cnName ?? "", $0.enDesc ?? "", $0.cnDesc ?? ""]
                .joined(separator: " ").lowercased()
        }
        refreshQuantities()
        filterCards()
        showSummary()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        tableView.reloadData()
    }

    @objc private func done() { navigationController?.popViewController(animated: true) }

    private func destination(for card: CardEntity) -> String {
        switch sectionControl.selectedSegmentIndex {
        case 1: return "0"
        case 2: return "2"
        case 3: return "1"
        default: return DeckService.isExtraDeckCard(card) ? "2" : "0"
        }
    }

    @objc private func filterCards() {
        searchTask?.cancel()
        let words = (searchBar.text ?? "").lowercased().split(whereSeparator: { $0.isWhitespace }).map(String.init)
        results = allCards.enumerated().compactMap { index, card in
            guard DeckService.canAdd(card, to: destination(for: card)),
                  words.allSatisfy({ searchIndex[index].contains($0) }) else { return nil }
            return card
        }
        tableView.backgroundView = results.isEmpty ? emptyLabel : nil
        pagination.reset(total: results.count)
        tableView.reloadData()
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        searchTask?.cancel()
        let task = DispatchWorkItem { [weak self] in self?.filterCards() }
        searchTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: task)
    }

    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        // Preserve room for results while the keyboard is open on compact phones.
        hint.isHidden = true
        status.numberOfLines = 2
    }

    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        hint.isHidden = false
        status.numberOfLines = 3
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        filterCards()
        searchBar.resignFirstResponder()
    }

    private func refreshQuantities() {
        quantities = [:]
        for entry in service.list().values.flatMap({ $0 }) {
            quantities[DeckService.identity(for: getCardEntity(id: entry.id)), default: 0] += entry.number
        }
    }

    private func showSummary() {
        let cards = service.list()
        let counts = ["0", "2", "1"].map { key in (cards[key] ?? []).reduce(0) { $0 + $1.number } }
        status.text = L10n.text("主卡 \(counts[0]) 张 · 额外 \(counts[1]) 张 · 副卡 \(counts[2]) 张", "Main \(counts[0]) · Extra \(counts[1]) · Side \(counts[2])")
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { pagination.visibleCount }

    func scrollViewDidScroll(_ scrollView: UIScrollView) { pagination.loadMoreIfNeeded() }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        CardTableViewCell.rowHeight
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DeckPickerCard", for: indexPath) as! CardTableViewCell
        let card = results[indexPath.row]
        card.isSelected = favorites.isExist(id: card.id)
        cell.prepare(cardEntity: card, tableView: tableView, indexPath: indexPath)
        let count = quantities[DeckService.identity(for: card), default: 0]
        let badge = UILabel(frame: CGRect(x: 0, y: 0, width: 36, height: 44))
        badge.text = count >= 3 ? "\(count)/3" : "+\n\(count)/3"
        badge.numberOfLines = 2
        badge.textAlignment = .center
        badge.font = .preferredFont(forTextStyle: .caption1)
        badge.textColor = count > 3 ? .systemOrange : (count == 3 ? .tertiaryLabel : greenColor)
        badge.accessibilityLabel = L10n.text("卡组已有 \(count) 张", "\(count) copies in deck")
        cell.accessoryView = badge
        cell.accessibilityHint = L10n.text("点按添加一张，长按查看详情", "Tap to add one copy, hold for details")
        setImage(card: cell.card, id: card.id)
        return cell
    }

    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        (cell as? CardTableViewCell)?.card.kf.cancelDownloadTask()
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let card = results[indexPath.row]
        let section = destination(for: card)
        let result = service.save(id: card.id, type: section)
        guard result == .saved else {
            let alert = UIAlertController(title: L10n.text("无法添加", "Unable to Add"), message: result.message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: L10n.text("知道了", "OK"), style: .default))
            present(alert, animated: true)
            return
        }
        refreshQuantities()
        let sectionName = ["0": L10n.text("主卡组", "Main Deck"), "1": L10n.text("副卡组", "Side Deck"), "2": L10n.text("额外卡组", "Extra Deck")][section]!
        let count = quantities[DeckService.identity(for: card), default: 0]
        showSummary()
        let summary = status.text ?? ""
        let notice: String
        if let restriction = BanlistService.shared.restriction(for: card.id) {
            notice = count > restriction.rawValue
                ? L10n.text("\(CardFormat.current.rawValue) · \(restriction.title)：当前数量超出限制，已保留在你的卡组。", "\(CardFormat.current.rawValue) · \(restriction.title): this exceeds the limit; kept in your deck.")
                : ""
        } else {
            notice = L10n.text("\(CardFormat.current.rawValue) 禁限资料待更新。", "\(CardFormat.current.rawValue) restriction data is unavailable.")
        }
        let cardName = card.getName() ?? card.id ?? ""
        status.text = [L10n.text("已加入\(sectionName)：\(cardName)（合计 \(count) 张）", "Added to \(sectionName): \(cardName) (\(count) total)"), notice, summary].filter { !$0.isEmpty }.joined(separator: "\n")
        UIAccessibility.post(notification: .announcement, argument: status.text)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        tableView.reloadData()
    }

    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let card = results[indexPath.row]
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            UIMenu(children: [UIAction(title: L10n.text("查看详情", "View Details"), image: UIImage(systemName: "info.circle")) { _ in
                let controller = CardDetailViewController()
                controller.cardEntity = card
                controller.hidesBottomBarWhenPushed = true
                self?.navigationController?.pushViewController(controller, animated: true)
            }])
        }
    }
}
