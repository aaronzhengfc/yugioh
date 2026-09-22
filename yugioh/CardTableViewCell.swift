import UIKit
import Kingfisher

class CardTableViewCell: UITableViewCell {
    let card = UIImageView()
    private let panel = UIView()
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
        backgroundColor = .clear
        selectionStyle = .none
        panel.backgroundColor = .secondarySystemGroupedBackground
        panel.layer.cornerRadius = 12
        panel.layer.cornerCurve = .continuous
        panel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(panel)
        card.contentMode = .scaleAspectFit
        for (label, size, weight) in [(nameLabel, CGFloat(15), UIFont.Weight.semibold),
                                       (metadata, 11, .regular), (stats, 12, .regular),
                                       (effect, 12, .regular), (footnote, 10, .regular),
                                       (cardID, 10, .regular), (date, 10, .regular)] {
            label.font = UIFontMetrics(forTextStyle: .caption1).scaledFont(for: .systemFont(ofSize: size, weight: weight))
            label.adjustsFontForContentSizeCategory = true
            label.textColor = label == nameLabel ? .label : .secondaryLabel
        }
        stats.font = UIFontMetrics(forTextStyle: .caption1).scaledFont(for: .monospacedDigitSystemFont(ofSize: 12, weight: .regular))
        effect.numberOfLines = 2
        effect.lineBreakMode = .byTruncatingTail
        favorite.setPreferredSymbolConfiguration(UIImage.SymbolConfiguration(font: nameLabel.font, scale: .small), forImageIn: .normal)
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
        [card, text, footer, favorite].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            panel.addSubview($0)
        }
        NSLayoutConstraint.activate([
            panel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            panel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            panel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 3),
            panel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -3),
            card.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 12),
            card.topAnchor.constraint(equalTo: panel.topAnchor, constant: 9),
            card.widthAnchor.constraint(equalToConstant: 72),
            card.heightAnchor.constraint(equalToConstant: 104),
            card.bottomAnchor.constraint(lessThanOrEqualTo: panel.bottomAnchor, constant: -9),
            text.leadingAnchor.constraint(equalTo: card.trailingAnchor, constant: 10),
            text.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -14),
            text.topAnchor.constraint(equalTo: panel.topAnchor, constant: 9),
            text.bottomAnchor.constraint(lessThanOrEqualTo: footer.topAnchor, constant: -4),
            footer.leadingAnchor.constraint(equalTo: text.leadingAnchor),
            footer.trailingAnchor.constraint(equalTo: text.trailingAnchor),
            footer.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -9),
            favorite.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -4),
            favorite.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            favorite.widthAnchor.constraint(equalToConstant: 44),
            favorite.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        panel.backgroundColor = highlighted ? .tertiarySystemGroupedBackground : .secondarySystemGroupedBackground
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
        metadata.text = cardEntity.getMetadataText()
        let statsText = cardEntity.getStatsText()
        stats.text = statsText
        stats.isHidden = statsText.isEmpty
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
