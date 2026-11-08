import UIKit
import Kingfisher
import Agrume

class CardDetailViewController: UIViewController {
    var cardEntity: CardEntity!
    var proxy: UIScrollView!

    private let accent = UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.42, green: 0.78, blue: 0.65, alpha: 1)
        : UIColor(red: 0.12, green: 0.36, blue: 0.29, alpha: 1) }
    private let pageBackground = UIColor { $0.userInterfaceStyle == .dark
        ? .systemBackground : UIColor(red: 0.96, green: 0.965, blue: 0.96, alpha: 1) }

    private let cardService = CardService()
    private let scrollView = UIScrollView()
    private let content = UIStackView()
    private let cardImage = UIImageView()
    private let favoriteButton = UIButton(type: .system)

    override func loadView() {
        view = UIView()
        view.backgroundColor = pageBackground
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L10n.text("卡牌详情", "Card Details")
        view.tintColor = accent
        navigationItem.rightBarButtonItem = WeChatSharing.shareButton(target: self, action: #selector(shareButtonHandler))
        setupLayout()
        populateContent()
        updateFavorite()
    }

    private func label(_ text: String, style: UIFont.TextStyle, color: UIColor = .label) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .preferredFont(forTextStyle: style)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = color
        label.numberOfLines = 0
        return label
    }

    private func setupLayout() {
        scrollView.alwaysBounceVertical = true
        content.axis = .vertical
        content.spacing = 10
        content.isLayoutMarginsRelativeArrangement = true
        content.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 12, trailing: 16)
        content.backgroundColor = pageBackground
        view.addSubview(scrollView)
        scrollView.addSubview(content)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        content.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            content.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            content.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            content.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
        favoriteButton.addTarget(self, action: #selector(toggleFavorite), for: .touchUpInside)
    }

    private func populateContent() {
        cardImage.translatesAutoresizingMaskIntoConstraints = false
        cardImage.contentMode = .scaleAspectFit
        cardImage.isUserInteractionEnabled = true
        cardImage.accessibilityLabel = L10n.text("查看卡牌大图", "View full card image")
        cardImage.accessibilityTraits = .button
        cardImage.isAccessibilityElement = true
        cardImage.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(showCardImage)))
        let preferredArtworkWidth = cardImage.widthAnchor.constraint(equalToConstant: 104)
        preferredArtworkWidth.priority = UILayoutPriority(998)
        NSLayoutConstraint.activate([
            preferredArtworkWidth,
            cardImage.widthAnchor.constraint(lessThanOrEqualToConstant: 104),
            cardImage.widthAnchor.constraint(greaterThanOrEqualToConstant: 64),
            cardImage.heightAnchor.constraint(equalTo: cardImage.widthAnchor, multiplier: 230 / 160)
        ])
        cardImage.kf.setImage(with: URL(string: getCardUrl(id: cardEntity.id)), placeholder: UIImage(named: "defaultimg"))
        let summary = UIStackView()
        summary.axis = .vertical
        summary.spacing = 8
        let name = label(cardEntity.getName() ?? "", style: .headline)
        favoriteButton.accessibilityIdentifier = "detailFavoriteStar"
        favoriteButton.setPreferredSymbolConfiguration(UIImage.SymbolConfiguration(font: name.font, scale: .small), forImageIn: .normal)
        NSLayoutConstraint.activate([
            favoriteButton.widthAnchor.constraint(equalToConstant: 44),
            favoriteButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        let titleRow = UIStackView(arrangedSubviews: [name, favoriteButton])
        titleRow.alignment = .center
        titleRow.spacing = 4
        summary.addArrangedSubview(titleRow)
        let metadata = cardEntity.getMetadataText()
        summary.addArrangedSubview(label(metadata, style: .footnote, color: .secondaryLabel))

        let stats = cardEntity.getStatsText()
        if !stats.isEmpty {
            let values = label(stats, style: .footnote, color: .secondaryLabel)
            values.font = UIFontMetrics(forTextStyle: .footnote).scaledFont(for: .monospacedDigitSystemFont(ofSize: 13, weight: .regular))
            summary.addArrangedSubview(values)
        }
        let metadataRow = CardMetadataRow()
        metadataRow.configure(cardID: cardEntity.id, date: cardEntity.getStartDate())
        summary.addArrangedSubview(UIView())
        summary.addArrangedSubview(metadataRow)

        // Let the artwork yield some width on smaller phones before scrolling the metadata.
        let visibleMetadata = summary.widthAnchor.constraint(greaterThanOrEqualTo: metadataRow.contentLayoutGuide.widthAnchor)
        visibleMetadata.priority = UILayoutPriority(999)
        visibleMetadata.isActive = true
        let artworkSummary = UIStackView(arrangedSubviews: [cardImage, summary])
        artworkSummary.spacing = 10
        artworkSummary.alignment = .center
        summary.heightAnchor.constraint(greaterThanOrEqualTo: cardImage.heightAnchor).isActive = true
        let header = makePanel([artworkSummary])
        header.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
        content.addArrangedSubview(header)
        addPanel(title: L10n.text("卡牌效果", "Card Effect"), body: cardEntity.getDesc() ?? "")
        addArchivedRestrictionPanel()
        addAlternateImages()
    }

    private func addArchivedRestrictionPanel() {
        let service = BanlistService.shared
        let heading = panelHeading(L10n.text("历史禁限表", "Forbidden & Limited History"))
        heading.accessibilityIdentifier = "banlistHistory"
        var views: [UIView] = [heading]

        for format in CardFormat.allCases {
            let formatHeading = label(format.rawValue, style: .subheadline)
            formatHeading.font = UIFont.preferredFont(forTextStyle: .subheadline).withTraits(.traitBold)
            formatHeading.accessibilityIdentifier = "banlistHistory" + format.rawValue
            views.append(formatHeading)
            let history = service.history(for: cardEntity.id, format: format)
            if history.isEmpty {
                views.append(label(L10n.text("已收录版本中没有限制变化", "No restriction changes in the archive"), style: .caption1, color: .secondaryLabel))
            } else {
                for entry in history {
                    let status = entry.restriction?.title ?? L10n.text("待更新", "Unknown")
                    let upcoming = entry.release.effectiveDate > BanlistService.today
                        ? L10n.text(" · 尚未生效", " · Upcoming") : ""
                    let incomplete = !entry.release.isComplete
                        ? L10n.text(" · 资料不完整", " · Incomplete archive") : ""
                    let row = label("\(entry.release.effectiveDate) · \(status)\(upcoming)\(incomplete)",
                                    style: .caption1, color: RestrictionBadgeLabel.ink(for: entry.restriction))
                    views.append(row)
                }
            }
        }
        let panel = makePanel(views)
        panel.accessibilityIdentifier = "banlistHistoryPanel"
        content.addArrangedSubview(panel)
    }

    private func panelHeading(_ title: String) -> UILabel {
        let heading = label(title, style: .footnote, color: accent)
        heading.font = UIFont.preferredFont(forTextStyle: .footnote).withTraits(.traitBold)
        return heading
    }

    private func addPanel(title: String, body: String) {
        let text = label(body, style: .subheadline)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3
        text.attributedText = NSAttributedString(string: body, attributes: [.paragraphStyle: paragraph])
        content.addArrangedSubview(makePanel([panelHeading(title), text]))
    }

    private func makePanel(_ views: [UIView]) -> UIStackView {
        let panel = UIStackView(arrangedSubviews: views)
        panel.axis = .vertical
        panel.spacing = 8
        panel.isLayoutMarginsRelativeArrangement = true
        panel.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14)
        panel.backgroundColor = .secondarySystemGroupedBackground
        panel.layer.cornerRadius = 14
        panel.layer.cornerCurve = .continuous
        return panel
    }

    private func addAlternateImages() {
        guard let data = cardEntity.getCardImages().data(using: .utf8),
              let images = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else { return }
        let ids = images.compactMap { ($0["id"] as? NSNumber)?.stringValue }.filter { $0 != cardEntity.id }
        guard !ids.isEmpty else { return }
        let scroller = UIScrollView()
        let row = UIStackView()
        row.spacing = 12
        scroller.addSubview(row)
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scroller.heightAnchor.constraint(equalToConstant: 116),
            row.leadingAnchor.constraint(equalTo: scroller.contentLayoutGuide.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: scroller.contentLayoutGuide.trailingAnchor),
            row.topAnchor.constraint(equalTo: scroller.contentLayoutGuide.topAnchor),
            row.bottomAnchor.constraint(equalTo: scroller.contentLayoutGuide.bottomAnchor),
            row.heightAnchor.constraint(equalTo: scroller.frameLayoutGuide.heightAnchor)
        ])
        for id in ids {
            let image = UIImageView()
            image.contentMode = .scaleAspectFit
            image.isUserInteractionEnabled = true
            image.widthAnchor.constraint(equalToConstant: 80).isActive = true
            image.kf.setImage(with: URL(string: getCardUrl(id: id)), placeholder: UIImage(named: "defaultimg"))
            image.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(showAlternateImage(_:))))
            row.addArrangedSubview(image)
        }
        let heading = panelHeading(L10n.text("其他卡图", "Alternate Artwork"))
        content.addArrangedSubview(makePanel([heading, scroller]))
    }

    @objc private func showCardImage() { showImage(cardImage.image) }
    @objc private func showAlternateImage(_ gesture: UITapGestureRecognizer) {
        showImage((gesture.view as? UIImageView)?.image)
    }
    private func showImage(_ image: UIImage?) {
        guard let image = image else { return }
        let viewer = Agrume(image: image)
        viewer.hideStatusBar = true
        viewer.show(from: self)
    }

    @objc private func toggleFavorite() {
        if cardService.isExist(id: cardEntity.id) { cardService.delete(id: cardEntity.id) }
        else { cardService.save(id: cardEntity.id) }
        updateFavorite()
        FavoriteFeedback.play(on: favoriteButton, selected: cardEntity.isSelected)
    }

    private func updateFavorite() {
        let selected = cardService.isExist(id: cardEntity.id)
        cardEntity.isSelected = selected
        favoriteButton.setImage(UIImage(systemName: selected ? "star.fill" : "star"), for: .normal)
        favoriteButton.tintColor = selected ? .systemOrange : .tertiaryLabel
        favoriteButton.accessibilityLabel = selected ? L10n.text("取消收藏", "Remove from favorites") : L10n.text("收藏卡牌", "Favorite card")
        favoriteButton.accessibilityTraits = selected ? [.button, .selected] : [.button]
    }

    @objc private func shareButtonHandler() {
        view.layoutIfNeeded()
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        let image = UIGraphicsImageRenderer(size: content.bounds.size, format: format).image { context in
            let previousAlpha = favoriteButton.alpha
            favoriteButton.alpha = 0
            defer { favoriteButton.alpha = previousAlpha }
            content.layer.render(in: context.cgContext)
        }
        WeChatSharing.sendImage(image, from: self)
    }
}

private extension UIFont {
    func withTraits(_ traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(traits) else { return self }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}
