import UIKit

/// One line in reading order. The scroll view also preserves full-size text
/// when an accessibility font is too wide even for the short badges.
final class CardMetadataRow: UIScrollView {
    private let ocg = RestrictionBadgeLabel()
    private let tcg = RestrictionBadgeLabel()
    private let cardNumber = UILabel()
    private let releaseDate = UILabel()
    private let stack = UIStackView()

    init() {
        super.init(frame: .zero)
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        contentInsetAdjustmentBehavior = .never
        isDirectionalLockEnabled = true
        delaysContentTouches = false
        releaseDate.accessibilityIdentifier = "cardReleaseDate"
        for label in [cardNumber, releaseDate] {
            label.font = UIFontMetrics(forTextStyle: .caption2).scaledFont(for: .systemFont(ofSize: 10))
            label.adjustsFontForContentSizeCategory = true
            label.textColor = .secondaryLabel
            label.setContentCompressionResistancePriority(.required, for: .horizontal)
            label.setContentHuggingPriority(.required, for: .horizontal)
        }
        let space = UIView()
        [ocg, tcg, space, cardNumber, releaseDate].forEach(stack.addArrangedSubview)
        stack.alignment = .center
        stack.spacing = 3
        stack.setCustomSpacing(0, after: space)
        stack.setCustomSpacing(5, after: cardNumber)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        let preferredWidth = stack.widthAnchor.constraint(equalTo: frameLayoutGuide.widthAnchor)
        preferredWidth.priority = .defaultHigh
        NSLayoutConstraint.activate([
            preferredWidth,
            stack.leadingAnchor.constraint(equalTo: contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentLayoutGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: contentLayoutGuide.bottomAnchor),
            stack.heightAnchor.constraint(equalTo: frameLayoutGuide.heightAnchor),
            stack.widthAnchor.constraint(greaterThanOrEqualTo: frameLayoutGuide.widthAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(cardID: String, date: String, release: BanlistRelease? = nil) {
        ocg.configure(cardID: cardID, format: .ocg, release: release)
        tcg.configure(cardID: cardID, format: .tcg, release: release)
        cardNumber.text = cardID
        releaseDate.text = date
        releaseDate.isHidden = date.isEmpty
        setContentOffset(.zero, animated: false)
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    override var intrinsicContentSize: CGSize {
        let height = max(ocg.intrinsicContentSize.height, cardNumber.intrinsicContentSize.height)
        return CGSize(width: UIView.noIntrinsicMetric, height: height)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        isScrollEnabled = contentSize.width > bounds.width + 1
    }
}
