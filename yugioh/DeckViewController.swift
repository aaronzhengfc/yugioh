import UIKit

class DeckViewController: UIViewController {
    @IBOutlet weak var tableView: UITableView!
    var showsWorldChampionships = false
    private var rootController: ViewController?

    private struct Section {
        let title: String
        let decks: [DeckViewEntity]
    }
    private var sections: [Section] = []
    private var summaries: [String: String] = [:]

    override func loadView() {
        guard showsWorldChampionships else {
            super.loadView()
            return
        }
        let root = UIView()
        let table = UITableView(frame: .zero, style: .plain)
        table.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(table)
        NSLayoutConstraint.activate([
            table.topAnchor.constraint(equalTo: root.safeAreaLayoutGuide.topAnchor),
            table.bottomAnchor.constraint(equalTo: root.safeAreaLayoutGuide.bottomAnchor),
            table.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            table.trailingAnchor.constraint(equalTo: root.trailingAnchor)
        ])
        view = root
        tableView = table
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        for deck in sections.flatMap({ $0.decks }) {
            guard !deck.isCancelled else { continue }
            let key = deck.type + ":" + deck.id
            if deck.type == "banlist" {
                summaries[key] = L10n.text("OCG / TCG · 按生效日期查看", "OCG / TCG · Browse by effective date")
            } else if deck.type == "championship-list" {
                summaries[key] = L10n.text("查看历年世界锦标赛卡组", "Browse decks by World Championship year")
            } else if deck.type == "star" {
                let count = CardService().list().count
                summaries[key] = L10n.text("已收藏 \(count) 张卡牌", "\(count) favorite cards")
            } else if deck.type == "physical" {
                let count = PhysicalCardService().list().reduce(0) { $0 + $1.quantity }
                summaries[key] = L10n.text("已拥有 \(count) 张实体卡", "\(count) physical cards")
            } else if deck.type == "self" || summaries[key] == nil {
                if let history = deck.history, !history.hasRecipe {
                    summaries[key] = history.recipeLabel
                    continue
                }
                let cards = deck.type == "history" ? loadHistoryCards(id: deck.id)
                    : (deck.type == "self" ? DeckService().list() : getDeckEntity(deckFormat: deck.type, deckName: deck.id))
                let counts = (0...2).map { (cards[String($0)] ?? []).reduce(0) { $0 + $1.number } }
                let side = deck.history?.recipeStatus == "partial" ? L10n.text("待补", "Pending") : String(counts[1])
                summaries[key] = L10n.text("主 \(counts[0])   ·   额外 \(counts[2])   ·   副 \(side)", "Main \(counts[0]) · Extra \(counts[2]) · Side \(side)")
            }
        }
        tableView.reloadData()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let decks = getDeckViewEntity()
        if showsWorldChampionships {
            title = L10n.text("冠军卡组", "World Champions")
            let history = loadDeckHistory()
            if history.isEmpty {
                sections = [Section(title: L10n.text("历届世界冠军", "World Champions"), decks: decks.filter { $0.type == "worldchampionship" })]
            } else {
                sections = history.map { Section(title: L10n.text("\($0.year) 世界锦标赛", "\($0.year) World Championship"), decks: $0.decks) }
            }
        } else {
            let physical = DeckViewEntity(id: "physical", title: L10n.text("我的实际卡", "My Physical Cards"), introduction: "", type: "physical")
            sections = [Section(title: L10n.text("我的空间", "My Collection"), decks: decks.filter { $0.type == "star" || $0.type == "self" } + [physical])]
            sections.append(Section(title: L10n.text("禁限卡档案", "Forbidden & Limited Archive"), decks: [
                DeckViewEntity(id: "banlists", title: L10n.text("历期禁限表", "Forbidden & Limited Lists"), introduction: "", type: "banlist")
            ]))
            sections.append(Section(title: L10n.text("冠军卡组", "World Champions"), decks: [
                DeckViewEntity(id: "championships", title: L10n.text("冠军卡组", "World Champions"), introduction: "", type: "championship-list")
            ]))
            sections.append(Section(title: L10n.text("经典卡组", "Classic Decks"), decks: decks.filter { !["star", "self", "worldchampionship"].contains($0.type) }))
        }
        sections.removeAll { $0.decks.isEmpty }
        view.backgroundColor = .systemGroupedBackground
        tableView.backgroundColor = .systemGroupedBackground
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 58
        tableView.sectionHeaderTopPadding = 0
        tableView.contentInset.bottom = 8
        tableView.register(DeckTableCell.self, forCellReuseIdentifier: "DeckCard")
        tableView.tableFooterView = UIView()
    }

}

extension DeckViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int { sections.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].decks.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DeckCard", for: indexPath) as! DeckTableCell
        let deck = sections[indexPath.section].decks[indexPath.row]
        cell.configure(deck, detail: summaries[deck.type + ":" + deck.id] ?? "")
        cell.accessibilityIdentifier = deck.type == "physical" ? "physicalCollectionEntry" : (deck.type == "championship-list" ? "championshipEntry" : nil)
        return cell
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = UIView()
        header.backgroundColor = .systemGroupedBackground
        let label = UILabel()
        label.text = sections[section].title
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.textColor = .secondaryLabel
        label.adjustsFontForContentSizeCategory = true
        label.accessibilityTraits = .header
        label.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -14),
            label.topAnchor.constraint(equalTo: header.topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -6)
        ])
        return header
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, estimatedHeightForHeaderInSection section: Int) -> CGFloat { 32 }

    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        !sections[indexPath.section].decks[indexPath.row].isCancelled
    }

    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        sections[indexPath.section].decks[indexPath.row].isCancelled ? nil : indexPath
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let deck = sections[indexPath.section].decks[indexPath.row]
        guard !deck.isCancelled else { return }
        if deck.type == "banlist" {
            navigationController?.pushViewController(BanlistViewController(), animated: true)
        } else if deck.type == "championship-list" {
            let controller = DeckViewController(nibName: nil, bundle: nil)
            controller.showsWorldChampionships = true
            controller.rootController = tabBarController as? ViewController
            controller.hidesBottomBarWhenPushed = true
            navigationController?.pushViewController(controller, animated: true)
        } else if deck.type == "star" {
            navigationController?.pushViewController(CardViewWithStarController(), animated: true)
        } else if deck.type == "physical" {
            let controller = PhysicalCardsViewController()
            controller.hidesBottomBarWhenPushed = true
            navigationController?.pushViewController(controller, animated: true)
        } else {
            let controller = CardDeckViewController()
            controller.rootController = rootController ?? (tabBarController as? ViewController)
            controller.deckViewEntity = deck
            navigationController?.pushViewController(controller, animated: true)
        }
    }
}
