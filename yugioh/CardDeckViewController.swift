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
    
    
    private let modeControl = UISegmentedControl(items: ["构筑解读", "卡牌配方"])
    private let readingView = UIScrollView()
    private let recipeSummary = UILabel()

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
            heading.addArrangedSubview(makeLabel("\(history.year) 世界锦标赛 · \(history.placement)", style: .caption1))
            heading.addArrangedSubview(makeLabel(deckViewEntity.champion + " · " + deckViewEntity.championRegion, style: .subheadline))
            modeControl.selectedSegmentIndex = 0
            modeControl.setEnabled(history.hasRecipe, forSegmentAt: 1)
            if !history.hasRecipe { modeControl.setTitle("配方待补充", forSegmentAt: 1) }
            modeControl.addTarget(self, action: #selector(changeMode), for: .valueChanged)
            heading.addArrangedSubview(modeControl)
            heading.setCustomSpacing(12, after: heading.arrangedSubviews[heading.arrangedSubviews.count - 2])
        }
        recipeSummary.font = .preferredFont(forTextStyle: .caption1)
        recipeSummary.adjustsFontForContentSizeCategory = true
        recipeSummary.textColor = .secondaryLabel
        recipeSummary.numberOfLines = 0
        heading.addArrangedSubview(recipeSummary)

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
        let guideImage = UIImageView(image: UIImage(named: "guide"))
        guideImage.contentMode = .scaleAspectFit
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
        stack.addArrangedSubview(makeLabel("世界赛历史构筑 · 采用当届赛事规则，不等同于普通 OCG / TCG 环境或现行合法配方。", style: .caption1))
        let links = UIStackView()
        links.distribution = .fillEqually
        links.spacing = 10
        for (index, title) in ["赛事来源", "配方来源"].enumerated() {
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
        let side = deckViewEntity.history?.recipeStatus == "partial" ? "待补充" : "\(counts[1]) 张"
        recipeSummary.text = "主卡 \(counts[0]) 张  ·  额外 \(counts[2]) 张  ·  副卡 \(side)"
        navigationItem.rightBarButtonItem = counts.reduce(0, +) > 0
            ? WeChatSharing.shareButton(target: self, action: #selector(shareButtonHandler)) : nil
        self.tableView.reloadData()
    }
    
    
    override func viewDidLoad() {
        //
        super.viewDidLoad()
        navigationItem.title = deckViewEntity.history == nil ? "卡组" : "赛事卡组"
        self.cardEntitys = rootController?.cardEntitys ?? []
        //
        self.tableView.backgroundColor = .systemGroupedBackground
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.register(CardDeckCollectionViewCell.self, forCellWithReuseIdentifier: CardDeckCollectionViewCell.identifier())
        self.tableView.register(CardDeckViewSectionHeaderView.NibObject(), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: CardDeckViewSectionHeaderView.identifier())
        
        //
        navigationItem.rightBarButtonItem = WeChatSharing.shareButton(target: self, action: #selector(shareButtonHandler))
    }

    @objc func shareButtonHandler() {
        let sections = (0...2).map { deckEntitys[String($0)] ?? [] }
        let cards = sections.flatMap { $0 }
        guard !cards.isEmpty else {
            WeChatSharing.showError("请先向卡组添加卡牌，再分享。", from: self)
            return
        }
        navigationItem.rightBarButtonItem?.customView?.isUserInteractionEnabled = false
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.startAnimating()
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: spinner)
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
            self.navigationItem.rightBarButtonItem = WeChatSharing.shareButton(target: self, action: #selector(self.shareButtonHandler))
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
            "\(history.year) 世界锦标赛 · \(history.placement)\n" + deckViewEntity.champion + " · " + deckViewEntity.championRegion
        } ?? ""
        let detailHeight = detail.isEmpty ? 0 : measuredHeight(detail, width: width - margin * 2, attributes: detailAttributes)
        let counts = sections.map { $0.reduce(0) { $0 + $1.number } }
        let side = deckViewEntity.history?.recipeStatus == "partial" ? "资料缺失" : "\(counts[1]) 张"
        let summary = "主卡 \(counts[0]) 张  ·  额外 \(counts[2]) 张  ·  副卡 \(side)"
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
                text(["主卡组", "副卡组", "额外卡组"][index] + " · \(counts[index]) 张",
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
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        return CGSize(width: collectionView.bounds.width, height: 32)
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let v = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: CardDeckViewSectionHeaderView.identifier(), for: indexPath) as! CardDeckViewSectionHeaderView
        
        if kind == UICollectionView.elementKindSectionHeader {
            
            let count = (deckEntitys[String(indexPath.section)] ?? []).reduce(0) { $0 + $1.number }
            let label = ["主卡组", "副卡组", "额外卡组"][indexPath.section]
            v.sectionHeaderLabel.text = label + " · " + (indexPath.section == 1 && deckViewEntity.history?.recipeStatus == "partial" ? "待补充" : "\(count) 张")
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
        cell.accessibilityLabel = "\(cardEntity.getName() ?? deckEntity.id)，\(deckEntity.number) 张"

        setImage(card: cell.cardImageView, id: cardEntity.id)

        
        return cell
    }
}
