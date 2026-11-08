import UIKit

/// A quiet, noninteractive status badge shared by card lists and detail views.
final class RestrictionBadgeLabel: UILabel {
    private var format: CardFormat?
    private var restriction: CardRestriction?
    private let padding = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)

    init() {
        super.init(frame: .zero)
        numberOfLines = 1
        adjustsFontForContentSizeCategory = true
        layer.cornerRadius = 6
        layer.cornerCurve = .continuous
        clipsToBounds = true
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .vertical)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(cardID: String, format: CardFormat, release: BanlistRelease? = nil) {
        let service = BanlistService.shared
        self.format = format
        restriction = service.restriction(for: cardID, format: format, asOf: release)
        backgroundColor = Self.fill(for: restriction)
        accessibilityLabel = format.rawValue + " · " + (restriction?.title ?? L10n.text("待更新", "Unknown"))
        accessibilityIdentifier = "restriction" + format.rawValue
        updateText()
    }

    private func updateText() {
        guard let format = format else { return }
        let symbol = restriction.map { "×" + String($0.rawValue) } ?? "?"
        let metrics = UIFontMetrics(forTextStyle: .caption2)
        let prefixAttributes: [NSAttributedString.Key: Any] = [
            .font: metrics.scaledFont(for: .systemFont(ofSize: 9, weight: .semibold)),
            .foregroundColor: UIColor.secondaryLabel, .kern: 0.2
        ]
        let statusAttributes: [NSAttributedString.Key: Any] = [
            .font: metrics.scaledFont(for: .systemFont(ofSize: 10, weight: .semibold)),
            .foregroundColor: Self.ink(for: restriction)
        ]
        let content = NSMutableAttributedString(string: format.rawValue, attributes: prefixAttributes)
        content.append(NSAttributedString(string: symbol, attributes: statusAttributes))
        attributedText = content
        invalidateIntrinsicContentSize()
    }

    static func ink(for restriction: CardRestriction?) -> UIColor {
        UIColor { trait in
            let dark = trait.userInterfaceStyle == .dark
            switch restriction {
            case .forbidden: return dark ? UIColor(red: 0.96, green: 0.60, blue: 0.62, alpha: 1)
                : UIColor(red: 0.63, green: 0.24, blue: 0.28, alpha: 1)
            case .limited: return dark ? UIColor(red: 0.91, green: 0.73, blue: 0.43, alpha: 1)
                : UIColor(red: 0.53, green: 0.37, blue: 0.14, alpha: 1)
            case .semiLimited: return dark ? UIColor(red: 0.60, green: 0.73, blue: 0.92, alpha: 1)
                : UIColor(red: 0.28, green: 0.43, blue: 0.61, alpha: 1)
            case .unlimited, nil: return UIColor.secondaryLabel.resolvedColor(with: trait)
            }
        }
    }

    static func fill(for restriction: CardRestriction?) -> UIColor {
        UIColor { trait in
            guard let restriction = restriction, restriction != .unlimited else {
                return UIColor.tertiarySystemFill.resolvedColor(with: trait)
            }
            return ink(for: restriction).resolvedColor(with: trait)
                .withAlphaComponent(trait.userInterfaceStyle == .dark ? 0.15 : 0.075)
        }
    }

    override func drawText(in rect: CGRect) { super.drawText(in: rect.inset(by: padding)) }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: ceil(size.width) + padding.left + padding.right,
                      height: ceil(size.height) + padding.top + padding.bottom)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
            updateText()
        }
    }
}
