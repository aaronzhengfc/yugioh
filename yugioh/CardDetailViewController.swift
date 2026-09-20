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
    private let deckService = DeckService()
    private let scrollView = UIScrollView()
    private let content = UIStackView()
    private let cardImage = UIImageView()
    private let favoriteButton = UIButton(type: .system)
    private let deckButton = UIButton(type: .system)

    override func loadView() {
        view = UIView()
        view.backgroundColor = pageBackground
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "卡牌详情"
        view.tintColor = accent
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "square.and.arrow.up"), style: .plain,
            target: self, action: #selector(shareButtonHandler))
        navigationItem.rightBarButtonItem?.accessibilityLabel = "分享卡牌"
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
        let actions = UIStackView(arrangedSubviews: [favoriteButton, deckButton])
        actions.spacing = 12
        actions.distribution = .fillEqually
        let bottomBar = UIView()
        bottomBar.backgroundColor = .systemBackground
        view.addSubview(bottomBar)
        bottomBar.addSubview(actions)
        [scrollView, content, bottomBar, actions].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor),
            content.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            content.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            content.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            actions.topAnchor.constraint(equalTo: bottomBar.topAnchor, constant: 8),
            actions.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: 20),
            actions.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor, constant: -20),
            actions.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            actions.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
        favoriteButton.addTarget(self, action: #selector(toggleFavorite), for: .touchUpInside)
        var configuration = UIButton.Configuration.filled()
        configuration.title = "卡组操作"
        configuration.image = UIImage(systemName: "rectangle.stack.badge.plus")
        configuration.imagePadding = 8
        configuration.baseBackgroundColor = accent
        configuration.baseForegroundColor = .systemBackground
        configuration.cornerStyle = .large
        deckButton.configuration = configuration
        deckButton.menu = UIMenu(children: [
            UIAction(title: "加入我的卡组", image: UIImage(systemName: "plus")) { [weak self] _ in
                self?.chooseDeck(isAdd: true)
            },
            UIAction(title: "从我的卡组移除", image: UIImage(systemName: "minus")) { [weak self] _ in
                self?.chooseDeck(isAdd: false)
            }
        ])
        deckButton.showsMenuAsPrimaryAction = true
    }

    private func populateContent() {
        cardImage.translatesAutoresizingMaskIntoConstraints = false
        cardImage.contentMode = .scaleAspectFit
        cardImage.isUserInteractionEnabled = true
        cardImage.accessibilityLabel = "查看卡牌大图"
        cardImage.accessibilityTraits = .button
        cardImage.isAccessibilityElement = true
        cardImage.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(showCardImage)))
        NSLayoutConstraint.activate([
            cardImage.widthAnchor.constraint(equalToConstant: 104),
            cardImage.heightAnchor.constraint(equalTo: cardImage.widthAnchor, multiplier: 230 / 160)
        ])
        cardImage.kf.setImage(with: URL(string: getCardUrl(id: cardEntity.id)), placeholder: UIImage(named: "defaultimg"))
        let summary = UIStackView()
        summary.axis = .vertical
        summary.spacing = 8
        let name = label(cardEntity.getName() ?? "", style: .headline)
        summary.addArrangedSubview(name)
        let metadata = [cardEntity.getType(), cardEntity.getAttribute(), cardEntity.getRace()]
            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " / ")
        summary.addArrangedSubview(label(metadata, style: .footnote, color: .secondaryLabel))

        var stats: [String] = []
        if !cardEntity.getLevel().isEmpty { stats.append("等级  \(cardEntity.getLevel())") }
        if !cardEntity.getAtk().isEmpty { stats.append("ATK  \(cardEntity.getAtk())") }
        if !cardEntity.getDef().isEmpty { stats.append("DEF  \(cardEntity.getDef())") }
        if !cardEntity.getLinkval().isEmpty { stats.append("LINK  \(cardEntity.getLinkval())") }
        if !cardEntity.getScale().isEmpty { stats.append("灵摆刻度  \(cardEntity.getScale())") }
        if !stats.isEmpty {
            let values = label(stats.joined(separator: "   "), style: .footnote)
            values.font = UIFontMetrics(forTextStyle: .footnote).scaledFont(for: .monospacedDigitSystemFont(ofSize: 13, weight: .semibold))
            summary.addArrangedSubview(values)
        }
        let status = UIButton(type: .system)
        var badge = UIButton.Configuration.tinted()
        badge.title = cardEntity.getBanlistInfoText()
        badge.baseForegroundColor = accent
        badge.baseBackgroundColor = accent
        badge.cornerStyle = .capsule
        badge.contentInsets = NSDirectionalEdgeInsets(top: 3, leading: 8, bottom: 3, trailing: 8)
        badge.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var attributes = incoming
            attributes.font = UIFont.preferredFont(forTextStyle: .caption1)
            return attributes
        }
        status.configuration = badge
        status.isUserInteractionEnabled = false
        status.accessibilityTraits = .staticText
        let statusRow = UIStackView(arrangedSubviews: [status, UIView()])
        summary.addArrangedSubview(statusRow)
        let details = ["ID  \(cardEntity.getId())",
                       cardEntity.getStartDate().isEmpty ? nil : cardEntity.getStartDate()]
            .compactMap { $0 }.filter { !$0.isEmpty }
        summary.addArrangedSubview(label(details.joined(separator: " · "), style: .caption1, color: .secondaryLabel))
        let header = UIStackView(arrangedSubviews: [cardImage, summary])
        header.spacing = 12
        header.alignment = .center
        header.isLayoutMarginsRelativeArrangement = true
        header.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
        header.backgroundColor = .secondarySystemGroupedBackground
        header.layer.cornerRadius = 14
        header.layer.cornerCurve = .continuous
        content.addArrangedSubview(header)
        addPanel(title: "卡牌效果", body: cardEntity.getDesc() ?? "")
        addAlternateImages()
    }

    private func addPanel(title: String, body: String) {
        let heading = label(title, style: .footnote, color: accent)
        heading.font = UIFont.preferredFont(forTextStyle: .footnote).withTraits(.traitBold)
        let text = label(body, style: .subheadline)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3
        text.attributedText = NSAttributedString(string: body, attributes: [.paragraphStyle: paragraph])
        let panel = UIStackView(arrangedSubviews: [heading, text])
        panel.axis = .vertical
        panel.spacing = 8
        panel.isLayoutMarginsRelativeArrangement = true
        panel.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14)
        panel.backgroundColor = .secondarySystemGroupedBackground
        panel.layer.cornerRadius = 14
        panel.layer.cornerCurve = .continuous
        content.addArrangedSubview(panel)
    }

    private func addAlternateImages() {
        guard let data = cardEntity.getCardImages().data(using: .utf8),
              let images = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else { return }
        let ids = images.compactMap { ($0["id"] as? NSNumber)?.stringValue }.filter { $0 != cardEntity.id }
        guard !ids.isEmpty else { return }
        content.addArrangedSubview(label("其他卡图", style: .headline))
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
        content.addArrangedSubview(scroller)
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
    }

    private func updateFavorite() {
        let selected = cardService.isExist(id: cardEntity.id)
        cardEntity.isSelected = selected
        var configuration = UIButton.Configuration.tinted()
        configuration.title = selected ? "已收藏" : "收藏"
        configuration.image = UIImage(systemName: selected ? "star.fill" : "star")
        configuration.imagePadding = 8
        configuration.baseForegroundColor = accent
        configuration.baseBackgroundColor = accent
        configuration.cornerStyle = .large
        favoriteButton.configuration = configuration
        favoriteButton.accessibilityTraits = selected ? [.button, .selected] : [.button]
    }

    private func chooseDeck(isAdd: Bool) {
        let sheet = UIAlertController(title: isAdd ? "加入我的卡组" : "从我的卡组移除", message: "选择卡组区域", preferredStyle: .actionSheet)
        for (title, type) in [("主卡组", "0"), ("副卡组", "1"), ("额外卡组", "2")] {
            sheet.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                guard let self = self else { return }
                if isAdd { self.deckService.save(id: self.cardEntity.id, type: type) }
                else { self.deckService.delete(id: self.cardEntity.id, type: type) }
            })
        }
        sheet.addAction(UIAlertAction(title: "取消", style: .cancel))
        sheet.popoverPresentationController?.sourceView = deckButton
        sheet.popoverPresentationController?.sourceRect = deckButton.bounds
        present(sheet, animated: true)
    }

    @objc private func shareButtonHandler() {
        view.layoutIfNeeded()
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: content.bounds.size, format: format).image { context in
            content.layer.render(in: context.cgContext)
        }
        guard let data = image.jpegData(compressionQuality: 0.9) else { return }
        let object = WXImageObject()
        object.imageData = data
        let message = WXMediaMessage()
        message.mediaObject = object
        let thumbSize = CGSize(width: 80, height: max(1, 80 * image.size.height / image.size.width))
        message.thumbData = UIGraphicsImageRenderer(size: thumbSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: thumbSize))
        }.jpegData(compressionQuality: 0.5)
        let request = SendMessageToWXReq()
        request.message = message
        request.bText = false
        request.scene = 0
        WeChatSharing.send(request, from: self)
    }
}

private extension UIFont {
    func withTraits(_ traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(traits) else { return self }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}
