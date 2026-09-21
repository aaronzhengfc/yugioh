import UIKit

final class DeckTableCell: UITableViewCell {
    private let card = UIView()
    private let badge = UIView()
    private let icon = UIImageView()
    private var labelsLeading: NSLayoutConstraint!
    private let heading = UILabel()
    private let subtitle = UILabel()
    private let arrow = UIImageView(image: UIImage(systemName: "chevron.right"))
    private var isCancelled = false
    private var accent = UIColor.systemGreen

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .clear
        selectionStyle = .none
        card.backgroundColor = .secondarySystemGroupedBackground
        card.layer.cornerRadius = 12
        card.layer.cornerCurve = .continuous
        badge.layer.cornerRadius = 10
        badge.layer.cornerCurve = .continuous
        icon.contentMode = .scaleAspectFit
        heading.font = .preferredFont(forTextStyle: .subheadline)
        heading.numberOfLines = 0
        subtitle.font = .preferredFont(forTextStyle: .caption1)
        subtitle.textColor = .secondaryLabel
        subtitle.numberOfLines = 0
        heading.adjustsFontForContentSizeCategory = true
        subtitle.adjustsFontForContentSizeCategory = true
        subtitle.isHidden = false
        let labels = UIStackView(arrangedSubviews: [heading, subtitle])
        labels.axis = .vertical
        labels.spacing = 3
        arrow.tintColor = .tertiaryLabel
        arrow.contentMode = .scaleAspectFit
        contentView.addSubview(card)
        [badge, labels, arrow].forEach { card.addSubview($0) }
        badge.addSubview(icon)
        [card, badge, labels, arrow, icon].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        labelsLeading = labels.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 58)
        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 3),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -3),
            badge.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            badge.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            badge.widthAnchor.constraint(equalToConstant: 34),
            badge.heightAnchor.constraint(equalToConstant: 34),
            card.heightAnchor.constraint(greaterThanOrEqualToConstant: 52),
            icon.centerXAnchor.constraint(equalTo: badge.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 21),
            icon.heightAnchor.constraint(equalToConstant: 21),
            labelsLeading,
            labels.topAnchor.constraint(equalTo: card.topAnchor, constant: 7),
            labels.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -7),
            labels.trailingAnchor.constraint(equalTo: arrow.leadingAnchor, constant: -12),
            arrow.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            arrow.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            arrow.widthAnchor.constraint(equalToConstant: 8)
        ])
        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    func configure(_ deck: DeckViewEntity, detail: String) {
        isCancelled = deck.isCancelled
        arrow.isHidden = isCancelled
        heading.textColor = isCancelled ? .secondaryLabel : .label
        subtitle.textColor = .secondaryLabel
        card.backgroundColor = isCancelled ? .systemGray5 : .secondarySystemGroupedBackground
        accessibilityTraits = isCancelled ? [.staticText, .notEnabled] : .button
        badge.isHidden = deck.type == "worldchampionship"
        labelsLeading.constant = badge.isHidden ? 12 : 58
        heading.text = deck.title
        switch deck.type {
        case "star":
            accent = .systemOrange
            icon.image = UIImage(systemName: "star.fill")
            subtitle.text = "喜欢的卡牌，随时回顾"
        case "self":
            accent = .systemGreen
            icon.image = UIImage(systemName: "rectangle.stack.fill")
            subtitle.text = "管理你的专属卡组"
        case "worldchampionship":
            accent = .systemIndigo
            let digits = String(deck.title.prefix(4))
            if Int(digits) != nil {
                heading.text = "\(digits) 世界冠军卡组"
            } else {
                icon.image = UIImage(systemName: "trophy.fill")
            }
            subtitle.text = "世界锦标赛 · 冠军构筑"
        default:
            accent = .systemTeal
            icon.image = UIImage(systemName: "square.stack.3d.up.fill")
            subtitle.text = deck.introduction == deck.title || deck.introduction.isEmpty
                ? "探索卡牌搭配与构筑" : deck.introduction
        }
        if isCancelled {
            subtitle.text = "世界赛停办"
        } else if deck.type == "worldchampionship", !deck.champion.isEmpty {
            let championLine = ["冠军", deck.champion, deck.championRegion]
                .filter { !$0.isEmpty }.joined(separator: " · ")
            subtitle.text = [championLine, detail].filter { !$0.isEmpty }.joined(separator: "\n")
        } else {
            subtitle.text = detail
        }
        icon.tintColor = accent
        badge.backgroundColor = accent.withAlphaComponent(0.10)
        accessibilityLabel = [heading.text, subtitle.text].compactMap { $0 }.joined(separator: "，")
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        card.backgroundColor = isCancelled ? .systemGray5
            : (highlighted ? accent.withAlphaComponent(0.08) : .secondarySystemGroupedBackground)
    }
}
