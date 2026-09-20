import UIKit

class DeckViewController: UIViewController {
    @IBOutlet weak var tableView: UITableView!

    private struct Section {
        let title: String
        let decks: [DeckViewEntity]
    }
    private var sections: [Section] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        let decks = getDeckViewEntity()
        sections = [
            Section(title: "我的空间", decks: decks.filter { $0.type == "star" || $0.type == "self" }),
            Section(title: "历届世界冠军", decks: decks.filter { $0.type == "worldchampionship" }),
            Section(title: "经典卡组", decks: decks.filter { !["star", "self", "worldchampionship"].contains($0.type) })
        ].filter { !$0.decks.isEmpty }
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
        cell.configure(sections[indexPath.section].decks[indexPath.row])
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
            label.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -20),
            label.topAnchor.constraint(equalTo: header.topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -6)
        ])
        return header
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, estimatedHeightForHeaderInSection section: Int) -> CGFloat { 32 }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let deck = sections[indexPath.section].decks[indexPath.row]
        if deck.type == "star" {
            navigationController?.pushViewController(CardViewWithStarController(), animated: true)
        } else {
            let controller = CardDeckViewController()
            controller.rootController = tabBarController as? ViewController
            controller.deckViewEntity = deck
            navigationController?.pushViewController(controller, animated: true)
        }
    }
}
