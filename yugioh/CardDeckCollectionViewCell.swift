import UIKit

class CardDeckCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var cardImageView: UIImageView!
    let quantityLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        let image = UIImageView()
        image.contentMode = .scaleAspectFit
        let name = UILabel()
        name.font = .preferredFont(forTextStyle: .caption1)
        name.adjustsFontForContentSizeCategory = true
        name.numberOfLines = 3
        quantityLabel.font = .preferredFont(forTextStyle: .caption1)
        quantityLabel.adjustsFontForContentSizeCategory = true
        quantityLabel.textColor = .secondaryLabel
        let text = UIStackView(arrangedSubviews: [name, quantityLabel])
        text.axis = .vertical
        text.spacing = 4
        contentView.addSubview(image)
        contentView.addSubview(text)
        titleLabel = name
        cardImageView = image
        image.translatesAutoresizingMaskIntoConstraints = false
        text.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            image.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            image.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            image.widthAnchor.constraint(equalToConstant: 42),
            image.heightAnchor.constraint(equalToConstant: 62),
            text.leadingAnchor.constraint(equalTo: image.trailingAnchor, constant: 8),
            text.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            text.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            text.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: 6),
            text.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -6)
        ])
        layer.cornerRadius = 10
        layer.cornerCurve = .continuous
        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    required init?(coder: NSCoder) { super.init(coder: coder) }

    override func prepareForReuse() {
        super.prepareForReuse()
        cardImageView?.kf.cancelDownloadTask()
        cardImageView?.image = nil
    }
}
