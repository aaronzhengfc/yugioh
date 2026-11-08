import UIKit

final class BanlistViewController: UITableViewController {
    private let formatControl = UISegmentedControl(items: CardFormat.allCases.map { $0.rawValue })
    private var format = CardFormat.current
    private var releases: [BanlistRelease] = []

    init() { super.init(style: .insetGrouped) }
    required init?(coder: NSCoder) { super.init(coder: coder) }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L10n.text("历期禁限表", "Forbidden & Limited Lists")
        tableView.backgroundColor = .systemGroupedBackground
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 64
        formatControl.selectedSegmentIndex = CardFormat.allCases.firstIndex(of: format) ?? 0
        formatControl.accessibilityLabel = L10n.text("禁限规则", "Forbidden and limited format")
        formatControl.addTarget(self, action: #selector(changeFormat), for: .valueChanged)
        let header = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 52))
        formatControl.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(formatControl)
        NSLayoutConstraint.activate([
            formatControl.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),
            formatControl.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -16),
            formatControl.centerYAnchor.constraint(equalTo: header.centerYAnchor)
        ])
        tableView.tableHeaderView = header
        reloadReleases()
    }

    @objc private func changeFormat() {
        format = CardFormat.allCases[formatControl.selectedSegmentIndex]
        reloadReleases()
    }

    private func reloadReleases() {
        releases = BanlistService.shared.releases.filter { $0.format == format }
        let empty = UILabel()
        empty.text = L10n.text("尚未收录该规则的禁限表", "No lists have been archived for this format")
        empty.textColor = .secondaryLabel
        empty.numberOfLines = 0
        empty.textAlignment = .center
        tableView.backgroundView = releases.isEmpty ? empty : nil
        tableView.reloadData()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { releases.count }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        L10n.text("按生效日期 · 已收录 \(releases.count) 期", "By effective date · \(releases.count) archived lists")
    }
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        L10n.text("卡牌页仅采用最新已生效的完整禁限表。历史收录范围以此处为准。", "Cards use the latest effective complete list. This archive shows the available history.")
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Release") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "Release")
        let release = releases[indexPath.row]
        var configuration = cell.defaultContentConfiguration()
        configuration.text = release.format.rawValue + " · " + release.effectiveDate
        let state: String
        if !release.isComplete { state = L10n.text("资料不完整", "Incomplete archive") }
        else if release.effectiveDate > BanlistService.today { state = L10n.text("尚未生效", "Upcoming") }
        else if release.id == BanlistService.shared.latest(for: format)?.id { state = L10n.text("最新已生效", "Latest effective list") }
        else { state = L10n.text("历史禁限表", "Historical list") }
        configuration.secondaryText = state
        configuration.image = UIImage(systemName: "list.bullet.rectangle")
        configuration.imageProperties.tintColor = .systemGreen
        cell.contentConfiguration = configuration
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        navigationController?.pushViewController(BanlistCardsViewController(release: releases[indexPath.row]), animated: true)
    }
}

final class BanlistCardsViewController: UITableViewController {
    private let release: BanlistRelease
    private var sections: [(CardRestriction, [CardEntity])] = []

    init(release: BanlistRelease) {
        self.release = release
        super.init(style: .grouped)
    }
    required init?(coder: NSCoder) { fatalError("Use init(release:)") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = release.format.rawValue + " · " + release.effectiveDate
        tableView.backgroundColor = .systemGroupedBackground
        tableView.separatorStyle = .none
        tableView.register(CardTableViewCell.self, forCellReuseIdentifier: CardTableViewCell.identifier())
        guard let values = BanlistService.shared.cards(in: release) else {
            let message = UILabel()
            message.text = L10n.text("禁限表读取失败，请稍后重试。", "This list could not be loaded. Please try again.")
            message.textAlignment = .center
            message.textColor = .secondaryLabel
            message.numberOfLines = 0
            tableView.backgroundView = message
            return
        }
        // Artwork passwords and pre-release IDs can refer to the same card.
        let allCards = getCardEntity()
        for status in CardRestriction.allCases {
            var canonicalCards: [String: CardEntity] = [:]
            for card in allCards where values[card.id] == status {
                let id = BanlistService.shared.canonicalID(for: card.id)
                if canonicalCards[id] == nil || card.id == id { canonicalCards[id] = card }
            }
            let cards = canonicalCards.values.sorted { $0.getName().localizedStandardCompare($1.getName()) == .orderedAscending }
            if status != .unlimited || !cards.isEmpty { sections.append((status, cards)) }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }

    override func numberOfSections(in tableView: UITableView) -> Int { sections.count }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { sections[section].1.count }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let item = sections[section]
        let upcoming = section == 0 && release.effectiveDate > BanlistService.today
            ? L10n.text("尚未生效 · \(release.effectiveDate)\n", "Upcoming · \(release.effectiveDate)\n") : ""
        let label = item.0 == .unlimited ? L10n.text("解除限制", "No longer restricted") : item.0.title
        return upcoming + label + L10n.text(" · \(item.1.count) 种", " · \(item.1.count) cards")
    }
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard section == sections.count - 1 else { return nil }
        return release.isComplete
            ? L10n.text("\(release.effectiveDate) 生效。未列出的卡牌不受此表额外限制。", "Effective \(release.effectiveDate). Unlisted cards have no additional restriction under this list.")
            : L10n.text("本期资料不完整，未列出卡牌的状态未知。", "This archive is incomplete; unlisted cards have unknown status.")
    }
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        CardTableViewCell.rowHeight
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: CardTableViewCell.identifier(), for: indexPath) as! CardTableViewCell
        let card = sections[indexPath.section].1[indexPath.row]
        card.isSelected = CardService().isExist(id: card.id)
        cell.prepare(cardEntity: card, tableView: tableView, indexPath: indexPath, banlistRelease: release)
        setImage(card: cell.card, id: card.id)
        return cell
    }
    override func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        (cell as? CardTableViewCell)?.card.kf.cancelDownloadTask()
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let detail = CardDetailViewController()
        detail.cardEntity = sections[indexPath.section].1[indexPath.row]
        navigationController?.pushViewController(detail, animated: true)
    }
}
