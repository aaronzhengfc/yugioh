//
//  CardDeckViewController.swift
//  yugioh
//
//  Created by Aaron on 1/7/2017.
//  Copyright © 2017 sightcorner. All rights reserved.
//

import Foundation
import UIKit
import Kingfisher
import SafariServices
import AVFoundation
import Vision



class CardDeckViewController: UIViewController {
    
    var rootController: ViewController!
    var deckViewController: DeckViewController!
    //外部传入的 卡组 数据
    var deckViewEntity: DeckViewEntity!
    
    fileprivate var cardEntitys: Array<CardEntity>! = []
    fileprivate var deckService = DeckService()
    
    @IBOutlet weak var guide: UIImageView!
    
    @IBOutlet weak var tableView: UICollectionView!
    
    // 卡组
    var deckEntitys:[String: [DeckEntity]] = [:]
    
    
    private let modeControl = UISegmentedControl(items: [L10n.text("构筑解读", "Analysis"), L10n.text("卡牌配方", "Deck List")])
    private let readingView = UIScrollView()
    private let recipeSummary = UILabel()
    private let restrictionNotice = UILabel()
    private var isSharing = false

    override func loadView() {
        view = UIView()
        view.backgroundColor = .systemGroupedBackground
        let heading = UIStackView()
        heading.axis = .vertical
        heading.spacing = 6
        heading.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(heading)
        let name = makeLabel(deckViewEntity.title, style: .headline, color: .label)
        heading.addArrangedSubview(name)
        if let history = deckViewEntity.history {
            heading.addArrangedSubview(makeLabel(L10n.text("\(history.year) 世界锦标赛 · \(history.placement)", "\(history.year) World Championship · \(history.placement)"), style: .caption1))
            heading.addArrangedSubview(makeLabel(deckViewEntity.champion + " · " + deckViewEntity.championRegion, style: .subheadline))
            modeControl.selectedSegmentIndex = language == "en" && history.hasRecipe ? 1 : 0
            modeControl.setEnabled(history.hasRecipe, forSegmentAt: 1)
            if !history.hasRecipe { modeControl.setTitle(L10n.text("配方待补充", "List pending"), forSegmentAt: 1) }
            modeControl.addTarget(self, action: #selector(changeMode), for: .valueChanged)
            heading.addArrangedSubview(modeControl)
            heading.setCustomSpacing(12, after: heading.arrangedSubviews[heading.arrangedSubviews.count - 2])
        }
        recipeSummary.font = .preferredFont(forTextStyle: .caption1)
        recipeSummary.adjustsFontForContentSizeCategory = true
        recipeSummary.textColor = .secondaryLabel
        recipeSummary.numberOfLines = 0
        heading.addArrangedSubview(recipeSummary)
        if deckViewEntity.type == "self" {
            restrictionNotice.font = .preferredFont(forTextStyle: .caption1)
            restrictionNotice.adjustsFontForContentSizeCategory = true
            restrictionNotice.textColor = .systemOrange
            restrictionNotice.numberOfLines = 0
            heading.addArrangedSubview(restrictionNotice)
            heading.addArrangedSubview(makeLabel(L10n.text("点按查看详情 · 长按卡牌调整数量或移除", "Tap for details · Hold a card to change quantity or remove it"), style: .caption1))
        }

        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        layout.sectionInset = UIEdgeInsets(top: 0, left: 12, bottom: 12, right: 12)
        let collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.addSubview(collection)
        tableView = collection
        collection.translatesAutoresizingMaskIntoConstraints = false
        readingView.translatesAutoresizingMaskIntoConstraints = false
        readingView.alwaysBounceVertical = true
        view.addSubview(readingView)
        let guideImage = UIImageView()
        let emptyMessage = makeLabel(L10n.text("你的卡组还是空的。点击右上角“添加卡牌”，选择要加入的卡牌。", "Your deck is empty. Tap Add Cards at the top right to start building it."), style: .body)
        emptyMessage.textAlignment = .center
        emptyMessage.translatesAutoresizingMaskIntoConstraints = false
        guideImage.addSubview(emptyMessage)
        NSLayoutConstraint.activate([
            emptyMessage.centerYAnchor.constraint(equalTo: guideImage.centerYAnchor),
            emptyMessage.leadingAnchor.constraint(equalTo: guideImage.leadingAnchor),
            emptyMessage.trailingAnchor.constraint(equalTo: guideImage.trailingAnchor)
        ])
        guideImage.translatesAutoresizingMaskIntoConstraints = false
        collection.addSubview(guideImage)
        guide = guideImage
        NSLayoutConstraint.activate([
            heading.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            heading.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            heading.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            collection.topAnchor.constraint(equalTo: heading.bottomAnchor, constant: 8),
            collection.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            collection.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            collection.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            readingView.topAnchor.constraint(equalTo: collection.topAnchor),
            readingView.leadingAnchor.constraint(equalTo: collection.leadingAnchor),
            readingView.trailingAnchor.constraint(equalTo: collection.trailingAnchor),
            readingView.bottomAnchor.constraint(equalTo: collection.bottomAnchor),
            guideImage.centerXAnchor.constraint(equalTo: collection.frameLayoutGuide.centerXAnchor),
            guideImage.centerYAnchor.constraint(equalTo: collection.frameLayoutGuide.centerYAnchor),
            guideImage.widthAnchor.constraint(equalTo: collection.frameLayoutGuide.widthAnchor, multiplier: 0.8),
            guideImage.heightAnchor.constraint(equalTo: collection.frameLayoutGuide.heightAnchor, multiplier: 0.8)
        ])
        if let history = deckViewEntity.history { buildReadingView(history) }
        changeMode()
    }

    private func makeLabel(_ text: String, style: UIFont.TextStyle, color: UIColor = .secondaryLabel) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .preferredFont(forTextStyle: style)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = color
        label.numberOfLines = 0
        return label
    }

    private func buildReadingView(_ history: DeckHistory) {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        readingView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: readingView.contentLayoutGuide.topAnchor, constant: 4),
            stack.bottomAnchor.constraint(equalTo: readingView.contentLayoutGuide.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: readingView.contentLayoutGuide.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: readingView.contentLayoutGuide.trailingAnchor, constant: -12),
            stack.widthAnchor.constraint(equalTo: readingView.frameLayoutGuide.widthAnchor, constant: -24)
        ])
        stack.addArrangedSubview(makeLabel(history.analysisLabel, style: .caption1))
        if language == "en" {
            stack.addArrangedSubview(makeLabel("Historical commentary below is currently available in Simplified Chinese. Card lists and card details are available in English.", style: .subheadline))
        }
        for paragraph in history.paragraphs {
            let panel = UIStackView(arrangedSubviews: [makeLabel(paragraph.title, style: .subheadline, color: .label), makeLabel(paragraph.text, style: .subheadline)])
            panel.axis = .vertical
            panel.spacing = 7
            panel.isLayoutMarginsRelativeArrangement = true
            panel.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
            panel.backgroundColor = .secondarySystemGroupedBackground
            panel.layer.cornerRadius = 12
            panel.layer.cornerCurve = .continuous
            stack.addArrangedSubview(panel)
        }
        stack.addArrangedSubview(makeLabel(L10n.text("世界赛历史构筑 · 采用当届赛事规则，不等同于普通 OCG / TCG 环境或现行合法配方。", "Historical World Championship decks used the rules of their event. They may differ from regular OCG / TCG formats and may not be legal today."), style: .caption1))
        let links = UIStackView()
        links.distribution = .fillEqually
        links.spacing = 10
        for (index, title) in [L10n.text("赛事来源", "Event Source"), L10n.text("配方来源", "Deck Source")].enumerated() {
            guard index == 0 || !history.recipeSourceURL.isEmpty else { continue }
            let button = UIButton(type: .system)
            var configuration = UIButton.Configuration.plain()
            configuration.title = title
            configuration.image = UIImage(systemName: "arrow.up.right.square")
            configuration.imagePadding = 6
            button.configuration = configuration
            button.tag = index
            button.addTarget(self, action: #selector(openHistorySource(_:)), for: .touchUpInside)
            links.addArrangedSubview(button)
        }
        stack.addArrangedSubview(links)
    }

    @objc private func openHistorySource(_ sender: UIButton) {
        guard let history = deckViewEntity.history,
              let url = URL(string: sender.tag == 0 ? history.sourceURL : history.recipeSourceURL),
              ["https", "http"].contains(url.scheme ?? "") else { return }
        present(SFSafariViewController(url: url), animated: true)
    }

    @objc private func changeMode() {
        let reading = deckViewEntity.history != nil && modeControl.selectedSegmentIndex == 0
        readingView.isHidden = !reading
        tableView.isHidden = reading
        recipeSummary.isHidden = reading
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadDeck()
    }

    private func reloadDeck() {
        self.guide.alpha = 0
        
        //代表是自己的卡组，所以必须请求数据
        if(deckViewEntity.type == "self") {
            deckEntitys = deckService.list();
        } else if deckViewEntity.type == "history" {
            deckEntitys = loadHistoryCards(id: deckViewEntity.id)
        } else {
            deckEntitys = getDeckEntity(deckFormat: deckViewEntity.type, deckName: deckViewEntity.id)
        }
        
    
        if deckViewEntity.type == "self" &&
            deckEntitys["0"]!.count <= 0 &&
            deckEntitys["1"]!.count <= 0 &&
            deckEntitys["2"]!.count <= 0 {
            //卡牌为0，展示引导页
            self.guide.alpha = 1
        }

        let counts = (0...2).map { (deckEntitys[String($0)] ?? []).reduce(0) { $0 + $1.number } }
        let side = deckViewEntity.history?.recipeStatus == "partial" ? L10n.text("待补充", "Pending") : L10n.text("\(counts[1]) 张", "\(counts[1]) cards")
        recipeSummary.text = L10n.text("主卡 \(counts[0]) 张  ·  额外 \(counts[2]) 张  ·  副卡 \(side)", "Main \(counts[0]) · Extra \(counts[2]) · Side \(side)")
        updateRestrictionNotice()
        updateNavigationActions()
        self.tableView.reloadData()
    }
    
    
    override func viewDidLoad() {
        //
        super.viewDidLoad()
        if deckViewEntity.type == "self" {
            navigationItem.title = L10n.text("我的卡组", "My Deck")
        } else {
            navigationItem.title = deckViewEntity.history == nil ? L10n.text("卡组", "Deck") : L10n.text("赛事卡组", "Tournament Deck")
        }
        self.cardEntitys = rootController?.cardEntitys ?? []
        //
        self.tableView.backgroundColor = .systemGroupedBackground
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.register(CardDeckCollectionViewCell.self, forCellWithReuseIdentifier: CardDeckCollectionViewCell.identifier())
        self.tableView.register(CardDeckViewSectionHeaderView.NibObject(), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: CardDeckViewSectionHeaderView.identifier())
        
        //
        updateNavigationActions()
    }

    private func updateRestrictionNotice() {
        guard deckViewEntity.type == "self" else { return }
        var totals: [String: (CardEntity, Int)] = [:]
        for entry in deckEntitys.values.flatMap({ $0 }) {
            let card = getCardEntity(id: entry.id)
            let key = DeckService.identity(for: card)
            totals[key] = (card, (totals[key]?.1 ?? 0) + entry.number)
        }
        guard !totals.isEmpty else { restrictionNotice.isHidden = true; return }
        var violations = 0
        var unknown = false
        for (card, count) in totals.values {
            if let restriction = BanlistService.shared.restriction(for: card.id) {
                if count > restriction.rawValue { violations += 1 }
            } else { unknown = true }
        }
        if violations > 0 {
            restrictionNotice.text = L10n.text("\(CardFormat.current.rawValue) 禁限提示：\(violations) 种卡牌超出当前限制，已保留构筑。", "\(CardFormat.current.rawValue): \(violations) cards exceed the current limit. Your build is kept.")
        } else if unknown {
            restrictionNotice.text = L10n.text("\(CardFormat.current.rawValue) 禁限资料待更新。", "\(CardFormat.current.rawValue) restriction data is unavailable.")
        } else {
            restrictionNotice.text = nil
        }
        restrictionNotice.isHidden = restrictionNotice.text == nil
    }

    private func updateNavigationActions() {
        var actions: [UIBarButtonItem] = []
        if deckViewEntity.type == "self" {
            let add = UIBarButtonItem(title: L10n.text("添加卡牌", "Add Cards"), style: .plain, target: self, action: #selector(addCards))
            add.accessibilityIdentifier = "addDeckCards"
            add.isEnabled = !isSharing
            actions.append(add)
        }
        if deckViewEntity.type != "self" {
            if isSharing {
                let spinner = UIActivityIndicatorView(style: .medium)
                spinner.startAnimating()
                actions.append(UIBarButtonItem(customView: spinner))
            } else if deckEntitys.values.flatMap({ $0 }).contains(where: { $0.number > 0 }) {
                actions.append(WeChatSharing.shareButton(target: self, action: #selector(shareButtonHandler)))
            }
        }
        navigationItem.rightBarButtonItems = actions
    }

    @objc private func addCards() {
        let picker = DeckCardPickerViewController()
        picker.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(picker, animated: true)
    }

    private func editCard(id: String, section: String, add: Bool, removeAll: Bool = false) {
        let result = add ? deckService.save(id: id, type: section) : deckService.delete(id: id, type: section, all: removeAll)
        guard result == .saved else {
            let alert = UIAlertController(title: L10n.text("无法更新卡组", "Unable to Update Deck"), message: result.message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: L10n.text("知道了", "OK"), style: .default))
            present(alert, animated: true)
            return
        }
        reloadDeck()
    }

    @objc func shareButtonHandler() {
        guard !isSharing else { return }
        let sections = (0...2).map { deckEntitys[String($0)] ?? [] }
        let cards = sections.flatMap { $0 }
        guard !cards.isEmpty else {
            WeChatSharing.showError(L10n.text("请先向卡组添加卡牌，再分享。", "Add cards to your deck before sharing it."), from: self)
            return
        }
        isSharing = true
        updateNavigationActions()
        let group = DispatchGroup()
        var images: [String: UIImage] = [:]
        for id in Set(cards.map { $0.id }) {
            guard let url = URL(string: getCardUrl(id: id)) else { continue }
            group.enter()
            KingfisherManager.shared.retrieveImage(with: url) { result in
                DispatchQueue.main.async {
                    if case .success(let value) = result { images[id] = value.image }
                    group.leave()
                }
            }
        }
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.isSharing = false
            self.updateNavigationActions()
            let image = self.makeDeckShareImage(sections: sections, images: images)
            WeChatSharing.sendImage(image, from: self)
        }
    }

    // Render the complete deck from data, independent of recycled/offscreen collection cells.
    private func makeDeckShareImage(sections: [[DeckEntity]], images: [String: UIImage]) -> UIImage {
        let width: CGFloat = 720
        let margin: CGFloat = 24
        let gap: CGFloat = 16
        let cellWidth = (width - margin * 2 - gap) / 2
        let cellHeight: CGFloat = 128
        let rowHeight = cellHeight + gap
        let ink = UIColor(white: 0.12, alpha: 1)
        let secondary = UIColor(white: 0.43, alpha: 1)
        // Use explicit light colors so the exported image stays readable in either appearance.
        let background = UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1)
        func attributes(_ size: CGFloat, _ color: UIColor, bold: Bool = false) -> [NSAttributedString.Key: Any] {
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineBreakMode = .byWordWrapping
            return [.font: UIFont.systemFont(ofSize: size, weight: bold ? .semibold : .regular),
                    .foregroundColor: color, .paragraphStyle: paragraph]
        }
        func measuredHeight(_ text: String, width: CGFloat, attributes: [NSAttributedString.Key: Any]) -> CGFloat {
            ceil((text as NSString).boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                 options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil).height)
        }
        let titleAttributes = attributes(28, ink, bold: true)
        let detailAttributes = attributes(18, secondary)
        let titleHeight = measuredHeight(deckViewEntity.title, width: width - margin * 2, attributes: titleAttributes)
        let detail = deckViewEntity.history.map { history in
            L10n.text("\(history.year) 世界锦标赛 · \(history.placement)\n", "\(history.year) World Championship · \(history.placement)\n") + deckViewEntity.champion + " · " + deckViewEntity.championRegion
        } ?? ""
        let detailHeight = detail.isEmpty ? 0 : measuredHeight(detail, width: width - margin * 2, attributes: detailAttributes)
        let counts = sections.map { $0.reduce(0) { $0 + $1.number } }
        let side = deckViewEntity.history?.recipeStatus == "partial" ? L10n.text("资料缺失", "Unavailable") : L10n.text("\(counts[1]) 张", "\(counts[1]) cards")
        let summary = L10n.text("主卡 \(counts[0]) 张  ·  额外 \(counts[2]) 张  ·  副卡 \(side)", "Main \(counts[0]) · Extra \(counts[2]) · Side \(side)")
        let summaryHeight = measuredHeight(summary, width: width - margin * 2, attributes: detailAttributes)
        let contentTop = margin + titleHeight + (detail.isEmpty ? 0 : detailHeight + 8) + 12 + summaryHeight + 24
        let height = sections.filter { !$0.isEmpty }.reduce(contentTop) {
            $0 + 38 + CGFloat(($1.count + 1) / 2) * rowHeight + 8
        } + margin
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
            background.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            func text(_ value: String, _ rect: CGRect, _ style: [NSAttributedString.Key: Any]) {
                (value as NSString).draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: style, context: nil)
            }
            text(deckViewEntity.title, CGRect(x: margin, y: margin, width: width - margin * 2, height: titleHeight), titleAttributes)
            var y = margin + titleHeight
            if !detail.isEmpty {
                y += 8
                text(detail, CGRect(x: margin, y: y, width: width - margin * 2, height: detailHeight), detailAttributes)
                y += detailHeight
            }
            text(summary, CGRect(x: margin, y: y + 12, width: width - margin * 2, height: summaryHeight), detailAttributes)
            y = contentTop
            // Only the recipe is exported, even when sharing from the analysis tab.
            for (index, entries) in sections.enumerated() where !entries.isEmpty {
                text([L10n.text("主卡组", "Main Deck"), L10n.text("副卡组", "Side Deck"), L10n.text("额外卡组", "Extra Deck")][index] + L10n.text(" · \(counts[index]) 张", " · \(counts[index]) cards"),
                     CGRect(x: margin, y: y, width: width - margin * 2, height: 30), attributes(20, secondary, bold: true))
                y += 38
                for (item, card) in entries.enumerated() {
                    let x = margin + CGFloat(item % 2) * (cellWidth + gap)
                    let top = y + CGFloat(item / 2) * rowHeight
                    UIColor.white.setFill()
                    UIBezierPath(roundedRect: CGRect(x: x, y: top, width: cellWidth, height: cellHeight), cornerRadius: 16).fill()
                    let imageRect = CGRect(x: x + 12, y: top + 12, width: 72, height: 104)
                    if let image = images[card.id] ?? UIImage(named: "defaultimg") { image.draw(in: imageRect) }
                    else {
                        background.setFill()
                        context.fill(imageRect)
                    }
                    let name = getCardEntity(id: card.id).getName() ?? card.id
                    let nameWidth = cellWidth - 108
                    var fontSize: CGFloat = 20
                    while fontSize > 14 && measuredHeight(name, width: nameWidth, attributes: attributes(fontSize, ink)) > 78 { fontSize -= 1 }
                    text(name, CGRect(x: x + 96, y: top + 14, width: nameWidth, height: 78), attributes(fontSize, ink))
                    text("× \(card.number)", CGRect(x: x + 96, y: top + 96, width: nameWidth, height: 22), attributes(18, secondary))
                }
                y += CGFloat((entries.count + 1) / 2) * rowHeight + 8
            }
        }
    }

}

extension CardDeckViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        let columns: CGFloat = traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? 1 : 2
        let width = floor((collectionView.bounds.width - 24 - (columns - 1) * 8) / columns)
        return CGSize(width: max(1, width), height: columns == 1 ? 112 : 82)
        
    }
}

extension CardDeckViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        let deckEntity = deckEntitys[indexPath.section.description]![indexPath.row]
        let cardEntity = getCardEntity(id: deckEntity.id)
        let controller = CardDetailViewController()
        
        controller.cardEntity = cardEntity
        controller.hidesBottomBarWhenPushed = true
        controller.proxy = self.tableView
        let back = UIBarButtonItem()
        back.title = navigationBarTitleText
        self.navigationItem.backBarButtonItem = back
        self.navigationController?.pushViewController(controller, animated: true)
        
    }
    
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard deckViewEntity.type == "self",
              let entries = deckEntitys[String(indexPath.section)], indexPath.item < entries.count else { return nil }
        let entry = entries[indexPath.item]
        let card = getCardEntity(id: entry.id)
        let canAdd = deckService.count(of: card) < 3 && DeckService.canAdd(card, to: entry.type)
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            UIMenu(title: L10n.text("当前区域 \(entry.number) 张", "\(entry.number) copies in this section"), children: [
                UIAction(title: L10n.text("增加 1 张", "Add One Copy"), image: UIImage(systemName: "plus"), attributes: canAdd ? [] : .disabled) { _ in
                    self?.editCard(id: entry.id, section: entry.type, add: true)
                },
                UIAction(title: L10n.text("减少 1 张", "Remove One Copy"), image: UIImage(systemName: "minus")) { _ in
                    self?.editCard(id: entry.id, section: entry.type, add: false)
                },
                UIAction(title: L10n.text("从此区域移除", "Remove from This Section"), image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
                    self?.editCard(id: entry.id, section: entry.type, add: false, removeAll: true)
                }
            ])
        }
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        return CGSize(width: collectionView.bounds.width, height: 32)
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let v = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: CardDeckViewSectionHeaderView.identifier(), for: indexPath) as! CardDeckViewSectionHeaderView
        
        if kind == UICollectionView.elementKindSectionHeader {
            
            let count = (deckEntitys[String(indexPath.section)] ?? []).reduce(0) { $0 + $1.number }
            let label = [L10n.text("主卡组", "Main Deck"), L10n.text("副卡组", "Side Deck"), L10n.text("额外卡组", "Extra Deck")][indexPath.section]
            v.sectionHeaderLabel.text = label + " · " + (indexPath.section == 1 && deckViewEntity.history?.recipeStatus == "partial" ? L10n.text("待补充", "Pending") : L10n.text("\(count) 张", "\(count) cards"))
            v.sectionHeaderLabel.textColor = .secondaryLabel
            v.sectionHeaderLabel.font = .preferredFont(forTextStyle: .caption1)

        }
        
        return v
        
    }
    
}

extension CardDeckViewController: UICollectionViewDataSource {
    
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        //根据 卡组中的数据 做展示
        //如果该卡组中 含有3部分，则为 0主 1副 2额外，返回数字3
        //如果该卡组中 含有3部分，则为 3禁止 4限制 5准限制，返回数字3
//        return deckViewEntity.deckEntitys.count
        return 3
    }
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        //按照卡组的大小进行展示
        //如果只有主卡组，只展示1个
        return deckEntitys[section.description]?.count ?? 0
    }
    
    
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        
        let cell = self.tableView.dequeueReusableCell(withReuseIdentifier: CardDeckCollectionViewCell.identifier(), for: indexPath) as! CardDeckCollectionViewCell
        
        cell.titleLabel.text = ""
        cell.backgroundColor = .secondarySystemGroupedBackground
        
        let deckEntity = deckEntitys[indexPath.section.description]![indexPath.row]
        let cardEntity = getCardEntity(id: deckEntity.id)
        
        cell.titleLabel.text = cardEntity.getName()
        cell.quantityLabel.text = "× \(deckEntity.number)"
        cell.accessibilityLabel = L10n.text("\(cardEntity.getName() ?? deckEntity.id)，\(deckEntity.number) 张", "\(cardEntity.getName() ?? deckEntity.id), \(deckEntity.number) copies")

        setImage(card: cell.cardImageView, id: cardEntity.id)

        
        return cell
    }
}

/// A personal inventory, separate from the deck and without deck-building limits.
private final class PhysicalCardCell: UITableViewCell {
    let artwork = UIImageView()
    let nameLabel = UILabel()
    let pricesLabel = UILabel()
    let decreaseButton = UIButton(type: .system)
    let increaseButton = UIButton(type: .system)
    var onDecrease: (() -> Void)?
    var onIncrease: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .secondarySystemGroupedBackground
        accessoryType = .disclosureIndicator

        artwork.contentMode = .scaleAspectFit
        artwork.isAccessibilityElement = false
        artwork.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(artwork)

        nameLabel.font = .preferredFont(forTextStyle: .subheadline)
        nameLabel.adjustsFontForContentSizeCategory = true
        nameLabel.numberOfLines = 0
        pricesLabel.font = .preferredFont(forTextStyle: .caption1)
        pricesLabel.adjustsFontForContentSizeCategory = true
        pricesLabel.textColor = .secondaryLabel
        pricesLabel.numberOfLines = 0
        for (button, symbol) in [(decreaseButton, "minus"), (increaseButton, "plus")] {
            var configuration = UIButton.Configuration.tinted()
            configuration.image = UIImage(systemName: symbol)
            configuration.baseForegroundColor = greenColor
            configuration.cornerStyle = .medium
            button.configuration = configuration
            button.widthAnchor.constraint(equalToConstant: 44).isActive = true
            button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        }
        decreaseButton.addTarget(self, action: #selector(decrease), for: .touchUpInside)
        increaseButton.addTarget(self, action: #selector(increase), for: .touchUpInside)
        let controls = UIStackView(arrangedSubviews: [decreaseButton, increaseButton, UIView()])
        controls.axis = .horizontal
        controls.spacing = 8
        let text = UIStackView(arrangedSubviews: [nameLabel, pricesLabel, controls])
        text.axis = .vertical
        text.spacing = 6
        text.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(text)

        NSLayoutConstraint.activate([
            artwork.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            artwork.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: 10),
            artwork.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -10),
            artwork.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            artwork.widthAnchor.constraint(equalToConstant: 68),
            artwork.heightAnchor.constraint(equalToConstant: 98),
            text.leadingAnchor.constraint(equalTo: artwork.trailingAnchor, constant: 12),
            text.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            text.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: 12),
            text.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -12),
            text.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func decrease() { onDecrease?() }
    @objc private func increase() { onIncrease?() }

    override func prepareForReuse() {
        super.prepareForReuse()
        artwork.kf.cancelDownloadTask()
        artwork.image = nil
        artwork.accessibilityIdentifier = nil
        onDecrease = nil
        onIncrease = nil
    }
}

final class PhysicalCardsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    private let service = PhysicalCardService()
    private let table = UITableView(frame: .zero, style: .plain)
    private let header = UIStackView()
    private let countLabel = UILabel()
    private let marketLabel = UILabel()
    private let noteLabel = UILabel()
    private var entries: [PhysicalCardService.Item] = []
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L10n.text("我的实际卡", "My Physical Cards")
        view.backgroundColor = .systemGroupedBackground
        view.tintColor = greenColor
        let scan = UIBarButtonItem(title: L10n.text("扫描卡牌", "Scan Cards"), style: .plain, target: self, action: #selector(scanCards))
        scan.accessibilityIdentifier = "scanPhysicalCards"
        navigationItem.rightBarButtonItem = scan
        table.backgroundColor = .systemGroupedBackground
        table.separatorStyle = .singleLine
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = 110
        table.delegate = self
        table.dataSource = self
        table.register(PhysicalCardCell.self, forCellReuseIdentifier: "PhysicalCard")
        table.accessibilityIdentifier = "physicalCardsList"
        table.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(table)
        NSLayoutConstraint.activate([
            table.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            table.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            table.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            table.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        header.axis = .vertical
        header.spacing = 6
        header.isLayoutMarginsRelativeArrangement = true
        header.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 14, leading: 16, bottom: 16, trailing: 16)
        for label in [countLabel, marketLabel, noteLabel] {
            label.numberOfLines = 0
            label.adjustsFontForContentSizeCategory = true
            label.font = .preferredFont(forTextStyle: .subheadline)
            header.addArrangedSubview(label)
        }
        countLabel.font = .preferredFont(forTextStyle: .headline)
        marketLabel.font = .preferredFont(forTextStyle: .title3)
        marketLabel.textColor = greenColor
        noteLabel.font = .preferredFont(forTextStyle: .caption1)
        noteLabel.textColor = .secondaryLabel
        marketLabel.accessibilityIdentifier = "physicalTotalCardmarket"
        table.tableHeaderView = header
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        reloadCollection()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let target = CGSize(width: table.bounds.width, height: UIView.layoutFittingCompressedSize.height)
        let height = header.systemLayoutSizeFitting(target, withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel).height
        if header.frame.width != target.width || abs(header.frame.height - height) > 0.5 {
            header.frame = CGRect(x: 0, y: 0, width: target.width, height: height)
            table.tableHeaderView = header
        }
    }

    private func reloadCollection() {
        entries = service.list()
        let totals = service.totals()
        countLabel.text = L10n.text("实体卡 · \(totals.totalCards) 张", "Physical cards · \(totals.totalCards) copies")
        func totalText(_ name: String, _ value: Decimal, _ missing: Int) -> String {
            let shown = totals.totalCards > 0 && missing == totals.totalCards
                ? L10n.text("暂无可用价格", "No price available") : L10n.euro(value)
            let coverage = missing > 0 ? L10n.text(" · \(missing) 张未计价", " · \(missing) unpriced copies") : ""
            return "\(name)：\(shown)\(coverage)"
        }
        marketLabel.text = totalText("Cardmarket", totals.cardmarket, totals.cardmarketMissingCount)
        var note = L10n.text("跨版本最低挂牌参考价，非所持实体卡估值；总计不含未计价卡牌。", "Lowest listings across matched products, not an appraisal of your cards. Totals exclude unpriced copies.")
        if let date = totals.earliestFetchedAt {
            note += "\n" + L10n.text("价格快照：\(dateFormatter.string(from: date)) · Cardmarket", "Price snapshot: \(dateFormatter.string(from: date)) · Cardmarket")
        }
        note += "\n" + L10n.text("点按卡牌查看详情 · 用 − / + 调整数量", "Tap a card for details · Use − / + to change quantity")
        noteLabel.text = note
        let empty = UILabel()
        empty.text = L10n.text("还没有实际卡。点击右上角“扫描卡牌”开始记录。", "No physical cards yet. Tap Scan Cards to start.")
        empty.textAlignment = .center
        empty.numberOfLines = 0
        empty.textColor = .secondaryLabel
        empty.font = .preferredFont(forTextStyle: .body)
        table.backgroundView = entries.isEmpty ? empty : nil
        table.reloadData()
        view.setNeedsLayout()
    }

    @objc private func scanCards() {
        let scanner = PhysicalCardScanViewController()
        scanner.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(scanner, animated: true)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { entries.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PhysicalCard", for: indexPath) as! PhysicalCardCell
        let item = entries[indexPath.row]
        let quote = service.quote(id: item.id)
        let card = getCardEntity(id: item.id)
        let cardName = card.getName() ?? item.id
        cell.nameLabel.text = L10n.text("\(cardName) · \(item.quantity) 张", "\(cardName) · \(item.quantity) copies")
        cell.decreaseButton.accessibilityIdentifier = "physicalDecrease_\(item.id)"
        cell.increaseButton.accessibilityIdentifier = "physicalIncrease_\(item.id)"
        cell.decreaseButton.accessibilityLabel = L10n.text("减少一张\(cardName)", "Remove one copy of \(cardName)")
        cell.increaseButton.accessibilityLabel = L10n.text("增加一张\(cardName)", "Add one copy of \(cardName)")
        cell.onDecrease = { [weak self] in self?.change(id: item.id, add: false) }
        cell.onIncrease = { [weak self] in self?.change(id: item.id, add: true) }
        cell.artwork.accessibilityIdentifier = "physicalCardArtwork_\(item.id)"
        setImage(card: cell.artwork, id: item.id)
        func line(_ title: String, _ price: Decimal?) -> String {
            guard let price = price else { return title + L10n.text("：暂无可用价格", ": No price available") }
            return "\(title)：\(L10n.euro(price)) × \(item.quantity) = \(L10n.euro(price * Decimal(item.quantity)))"
        }
        cell.pricesLabel.text = line("Cardmarket", quote.cardmarket)
        cell.accessibilityIdentifier = "physicalCardRow_\(item.id)"
        cell.accessibilityHint = L10n.text("点按查看详情", "Tap for details")
        return cell
    }

    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        (cell as? PhysicalCardCell)?.artwork.kf.cancelDownloadTask()
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let controller = CardDetailViewController()
        controller.cardEntity = getCardEntity(id: entries[indexPath.row].id)
        controller.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(controller, animated: true)
    }

    private func change(id: String, add: Bool) {
        let success = add ? service.add(id: id) : service.remove(id: id)
        if success { reloadCollection(); return }
        let alert = UIAlertController(title: L10n.text("无法更新", "Unable to Update"), message: L10n.text("保存失败，请重试。", "Could not save. Please try again."), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.text("知道了", "OK"), style: .default))
        present(alert, animated: true)
    }

}

/// Scans a single card on-device and asks the user to confirm a catalogue match.
final class PhysicalCardScanViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UITableViewDataSource, UITableViewDelegate {
    private let preview = UIImageView()
    private let status = UILabel()
    private let captureButton = UIButton(type: .system)
    private let table = UITableView(frame: .zero, style: .plain)
    private var candidates: [PhysicalCardScanMatcher.Candidate] = []
    private var isProcessing = false
    private let service = PhysicalCardService()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L10n.text("扫描卡牌", "Scan Card")
        view.backgroundColor = .systemGroupedBackground
        view.tintColor = greenColor

        preview.contentMode = .scaleAspectFit
        preview.backgroundColor = .secondarySystemGroupedBackground
        preview.layer.cornerRadius = 12
        preview.clipsToBounds = true
        preview.isAccessibilityElement = false
        preview.accessibilityIdentifier = "scanCapturedPhoto"
        preview.image = UIImage(systemName: "camera.viewfinder")
        preview.tintColor = .secondaryLabel
        preview.heightAnchor.constraint(equalToConstant: 180).isActive = true
        status.numberOfLines = 0
        status.font = .preferredFont(forTextStyle: .subheadline)
        status.adjustsFontForContentSizeCategory = true
        status.textColor = .secondaryLabel
        status.accessibilityIdentifier = "scanStatus"
        status.text = L10n.text("将单张卡牌放在明亮处，拍摄卡名和卡号。识别后请选择候选卡牌确认。", "Photograph one card in good lighting, including its name and number. Choose a match to confirm.")
        var captureStyle = UIButton.Configuration.filled()
        captureStyle.title = L10n.text("拍照识别", "Scan with Camera")
        captureStyle.image = UIImage(systemName: "camera.fill")
        captureStyle.imagePadding = 8
        captureStyle.baseForegroundColor = .white
        captureStyle.baseBackgroundColor = UIColor(red: 0.12, green: 0.36, blue: 0.29, alpha: 1)
        captureStyle.cornerStyle = .large
        captureStyle.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20)
        captureStyle.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var result = attributes
            result.font = .preferredFont(forTextStyle: .headline)
            return result
        }
        captureButton.configuration = captureStyle
        captureButton.titleLabel?.adjustsFontForContentSizeCategory = true
        captureButton.accessibilityIdentifier = "scanCaptureButton"
        captureButton.addTarget(self, action: #selector(openCamera), for: .touchUpInside)
        captureButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 52).isActive = true

        let header = UIStackView(arrangedSubviews: [preview, status, captureButton])
        header.axis = .vertical
        header.spacing = 10
        header.isLayoutMarginsRelativeArrangement = true
        header.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        table.backgroundColor = .systemGroupedBackground
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = 64
        table.dataSource = self
        table.delegate = self
        table.accessibilityIdentifier = "scanCandidates"
        let layout = UIStackView(arrangedSubviews: [header, table])
        layout.axis = .vertical
        layout.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(layout)
        NSLayoutConstraint.activate([
            layout.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            layout.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            layout.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            layout.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }

    @objc private func openCamera() {
        guard !isProcessing else { return }
        #if DEBUG
        // The UI test feeds recognized text without camera hardware; production
        // builds always use the camera and Vision below.
        if let injected = ProcessInfo.processInfo.environment["UI_TEST_SCAN_TEXT"] {
            handleRecognizedText(injected.components(separatedBy: "|"))
            return
        }
        #endif
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            status.text = L10n.text("此设备没有可用相机。请在有相机的设备上扫描。", "No camera is available on this device. Scan on a device with a camera.")
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            presentCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] allowed in
                DispatchQueue.main.async {
                    guard let self = self, self.viewIfLoaded?.window != nil else { return }
                    if allowed { self.presentCamera() } else { self.showCameraPermissionMessage() }
                }
            }
        case .denied, .restricted:
            showCameraPermissionMessage()
        @unknown default:
            showCameraPermissionMessage()
        }
    }

    private func presentCamera() {
        guard presentedViewController == nil, viewIfLoaded?.window != nil else { return }
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = self
        present(picker, animated: true)
    }

    private func showCameraPermissionMessage() {
        status.text = L10n.text("无法使用相机。请在系统设置中允许相机访问后重试。", "Camera access is unavailable. Allow access in Settings and try again.")
        let alert = UIAlertController(title: L10n.text("需要相机权限", "Camera Access Needed"), message: status.text, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.text("取消", "Cancel"), style: .cancel))
        if let url = URL(string: UIApplication.openSettingsURLString) {
            alert.addAction(UIAlertAction(title: L10n.text("打开设置", "Open Settings"), style: .default) { _ in UIApplication.shared.open(url) })
        }
        present(alert, animated: true)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            guard let image = info[.originalImage] as? UIImage, let cgImage = image.cgImage else {
                self.status.text = L10n.text("无法读取照片，请重新拍摄。", "Could not read the photo. Please try again.")
                return
            }
            self.preview.image = image
            self.candidates = []
            self.table.reloadData()
            self.isProcessing = true
            self.captureButton.isEnabled = false
            self.status.text = L10n.text("正在识别卡名和卡号…", "Recognizing the card name and number…")
            let orientation = Self.imageOrientation(image.imageOrientation)
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = false
                if let supported = try? request.supportedRecognitionLanguages() {
                    let languages = ["ja-JP", "zh-Hans", "en-US"].filter { supported.contains($0) }
                    if !languages.isEmpty { request.recognitionLanguages = languages }
                }
                do {
                    try VNImageRequestHandler(cgImage: cgImage, orientation: orientation).perform([request])
                    let lines = (request.results ?? []).flatMap { $0.topCandidates(2).map(\.string) }
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        self.handleRecognizedText(lines)
                    }
                } catch {
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        self.isProcessing = false
                        self.captureButton.isEnabled = true
                        self.status.text = L10n.text("识别失败，请重新拍摄。", "Recognition failed. Please take another photo.")
                    }
                }
            }
        }
    }

    private func handleRecognizedText(_ lines: [String]) {
        isProcessing = true
        captureButton.isEnabled = false
        candidates = []
        table.reloadData()
        status.text = L10n.text("正在查找匹配卡牌…", "Finding matching cards…")
        PhysicalCardScanMatcher.matchAsync(lines: lines) { [weak self] matches in
            guard let self = self else { return }
            self.isProcessing = false
            self.captureButton.isEnabled = true
            guard self.viewIfLoaded?.window != nil else { return }
            self.candidates = matches
            self.table.reloadData()
            self.status.text = matches.isEmpty
                ? L10n.text("没有找到匹配的卡牌。请靠近卡牌并避开反光，重新拍摄卡名和卡号。", "No matching card found. Move closer, avoid glare, and photograph the name and number again.")
                : L10n.text("请选择识别到的卡牌，确认后加入收藏。", "Select a recognized card and confirm to add it to your collection.")
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { candidates.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ScanCandidate") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "ScanCandidate")
        let candidate = candidates[indexPath.row]
        cell.textLabel?.text = candidate.card.getName()
        cell.textLabel?.numberOfLines = 0
        cell.textLabel?.font = .preferredFont(forTextStyle: .body)
        cell.textLabel?.adjustsFontForContentSizeCategory = true
        cell.detailTextLabel?.text = "\(candidate.card.id ?? "") · \(candidate.reason)"
        cell.detailTextLabel?.numberOfLines = 0
        cell.detailTextLabel?.font = .preferredFont(forTextStyle: .caption1)
        cell.detailTextLabel?.adjustsFontForContentSizeCategory = true
        cell.accessoryType = .disclosureIndicator
        cell.accessibilityIdentifier = "scanCandidate_\(candidate.card.id ?? "")"
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let card = candidates[indexPath.row].card
        let alert = UIAlertController(title: L10n.text("确认加入收藏？", "Add to Collection?"),
                                      message: "\(card.getName() ?? "")\n\(card.id ?? "")", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.text("取消", "Cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: L10n.text("加入收藏", "Add to Collection"), style: .default) { [weak self] _ in
            guard let self = self, let id = card.id, self.service.add(id: id) else {
                self?.status.text = L10n.text("保存失败，请重试。", "Could not save. Please try again.")
                return
            }
            self.candidates = []
            self.table.reloadData()
            self.status.text = L10n.text("已加入：\(card.getName() ?? id)。可以继续扫描下一张。", "Added: \(card.getName() ?? id). You can scan another card.")
        })
        present(alert, animated: true)
    }

    private static func imageOrientation(_ orientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch orientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
