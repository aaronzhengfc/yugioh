import UIKit
import Kingfisher

class CardTableViewCell: UITableViewCell {
    let card = UIImageView()
    private let nameLabel = UILabel()
    private let metadata = UILabel()
    private let stats = UILabel()
    private let effect = UILabel()
    private let footnote = UILabel()
    private let cardID = UILabel()
    private let date = UILabel()
    private let favorite = UIButton(type: .system)
    private var entity: CardEntity?
    private let cardService = CardService()
    var afterDeselect: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .systemBackground
        card.contentMode = .scaleAspectFit
        for (label, size, weight) in [(nameLabel, CGFloat(15), UIFont.Weight.semibold),
                                       (metadata, 11, .regular), (stats, 12, .medium),
                                       (effect, 12, .regular), (footnote, 10, .regular),
                                       (cardID, 10, .regular), (date, 10, .regular)] {
            label.font = UIFontMetrics(forTextStyle: .caption1).scaledFont(for: .systemFont(ofSize: size, weight: weight))
            label.adjustsFontForContentSizeCategory = true
            label.textColor = [metadata, footnote, cardID, date].contains(label) ? .secondaryLabel : .label
        }
        effect.numberOfLines = 2
        effect.lineBreakMode = .byTruncatingTail
        favorite.tintColor = .secondaryLabel
        favorite.addTarget(self, action: #selector(toggleFavorite), for: .touchUpInside)
        favorite.accessibilityLabel = "收藏卡牌"
        let titleRow = UIStackView(arrangedSubviews: [nameLabel, UIView()])
        titleRow.arrangedSubviews[1].widthAnchor.constraint(equalToConstant: 30).isActive = true
        let text = UIStackView(arrangedSubviews: [titleRow, metadata, stats, effect])
        text.axis = .vertical
        text.spacing = 3
        let footer = UIStackView(arrangedSubviews: [footnote, cardID, date])
        footer.distribution = .fillEqually
        footer.spacing = 4
        cardID.textAlignment = .center
        date.textAlignment = .right
        [footnote, cardID, date].forEach {
            $0.setContentCompressionResistancePriority(.required, for: .vertical)
        }
        let divider = UIView()
        divider.backgroundColor = .separator
        [card, text, footer, favorite, divider].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 9),
            card.widthAnchor.constraint(equalToConstant: 72),
            card.heightAnchor.constraint(equalToConstant: 104),
            card.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -9),
            text.leadingAnchor.constraint(equalTo: card.trailingAnchor, constant: 10),
            text.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            text.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 9),
            text.bottomAnchor.constraint(lessThanOrEqualTo: footer.topAnchor, constant: -4),
            footer.leadingAnchor.constraint(equalTo: text.leadingAnchor),
            footer.trailingAnchor.constraint(equalTo: text.trailingAnchor),
            footer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -9),
            favorite.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            favorite.topAnchor.constraint(equalTo: contentView.topAnchor),
            favorite.widthAnchor.constraint(equalToConstant: 44),
            favorite.heightAnchor.constraint(equalToConstant: 44),
            divider.leadingAnchor.constraint(equalTo: text.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: text.trailingAnchor),
            divider.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            divider.heightAnchor.constraint(equalToConstant: 0.5)
        ])
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        FavoriteFeedback.reset(favorite)
        card.kf.cancelDownloadTask()
        card.image = nil
        afterDeselect = nil
    }

    func prepare(cardEntity: CardEntity, tableView: UITableView, indexPath: IndexPath) {
        entity = cardEntity
        nameLabel.text = cardEntity.getName()
        metadata.text = [cardEntity.getType(), cardEntity.getAttribute(), cardEntity.getRace()]
            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
        var values: [String] = []
        if !cardEntity.getLevel().isEmpty { values.append("★ " + cardEntity.getLevel()) }
        if !cardEntity.getLinkval().isEmpty { values.append("LINK " + cardEntity.getLinkval()) }
        if !cardEntity.getAtk().isEmpty { values.append("ATK " + cardEntity.getAtk()) }
        if !cardEntity.getDef().isEmpty { values.append("DEF " + cardEntity.getDef()) }
        if !cardEntity.getScale().isEmpty { values.append("刻度 " + cardEntity.getScale()) }
        stats.text = values.joined(separator: "   ")
        stats.isHidden = values.isEmpty
        effect.text = cardEntity.getDesc()
        footnote.text = cardEntity.getBanlistInfoText()
        cardID.text = "ID " + cardEntity.id
        date.text = cardEntity.getStartDate()
        updateFavorite()
    }

    private func updateFavorite() {
        let selected = entity?.isSelected == true
        favorite.setImage(UIImage(systemName: selected ? "star.fill" : "star"), for: .normal)
        favorite.tintColor = selected ? .systemOrange : .tertiaryLabel
        favorite.accessibilityLabel = selected ? "取消收藏" : "收藏卡牌"
    }

    @objc private func toggleFavorite() {
        guard let entity = entity else { return }
        entity.isSelected.toggle()
        if entity.isSelected { cardService.save(id: entity.id) }
        else { cardService.delete(id: entity.id) }
        updateFavorite()
        FavoriteFeedback.play(on: favorite, selected: entity.isSelected)
        if !entity.isSelected { afterDeselect?() }
    }
}
