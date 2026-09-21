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
    
    
    override func viewWillAppear(_ animated: Bool) {
        self.guide.alpha = 0
        
        //代表是自己的卡组，所以必须请求数据
        if(deckViewEntity.type == "self") {
            deckEntitys = deckService.list();
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

        self.tableView.reloadData()
    }
    
    
    override func viewDidLoad() {
        //
        self.cardEntitys = rootController.cardEntitys
        //
        self.tableView.backgroundColor = greyColor
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.register(CardDeckCollectionViewCell.NibObject(), forCellWithReuseIdentifier: CardDeckCollectionViewCell.identifier())
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
        let rowHeight: CGFloat = 76
        let height = sections.filter { !$0.isEmpty }.reduce(CGFloat(100)) {
            $0 + 38 + CGFloat(($1.count + 1) / 2) * rowHeight + 16
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            let ink = UIColor(red: 0.12, green: 0.36, blue: 0.29, alpha: 1)
            func text(_ value: String, _ rect: CGRect, _ size: CGFloat, _ color: UIColor, bold: Bool = false) {
                let paragraph = NSMutableParagraphStyle()
                paragraph.lineBreakMode = .byTruncatingTail
                (value as NSString).draw(in: rect, withAttributes: [
                    .font: UIFont.systemFont(ofSize: size, weight: bold ? .semibold : .regular),
                    .foregroundColor: color, .paragraphStyle: paragraph
                ])
            }
            text(deckViewEntity.title, CGRect(x: margin, y: 22, width: width - margin * 2, height: 40), 26, ink, bold: true)
            var y: CGFloat = 76
            for (index, entries) in sections.enumerated() where !entries.isEmpty {
                let count = entries.reduce(0) { $0 + $1.number }
                text(["主卡组", "副卡组", "额外卡组"][index] + " · \(count) 张", CGRect(x: margin, y: y, width: width - margin * 2, height: 30), 19, ink, bold: true)
                y += 38
                for (item, card) in entries.enumerated() {
                    let x = margin + CGFloat(item % 2) * 342
                    let top = y + CGFloat(item / 2) * rowHeight
                    let rect = CGRect(x: x, y: top, width: 44, height: 64)
                    if let image = images[card.id] { image.draw(in: rect) }
                    else {
                        UIColor(white: 0.93, alpha: 1).setFill()
                        context.fill(rect)
                    }
                    text(getCardEntity(id: card.id).getName() ?? card.id, CGRect(x: x + 54, y: top + 2, width: 264, height: 43), 16, .black)
                    text("× \(card.number)   ·   ID \(card.id)", CGRect(x: x + 54, y: top + 46, width: 264, height: 20), 13, .darkGray)
                }
                y += CGFloat((entries.count + 1) / 2) * rowHeight + 16
            }
        }
    }

}

extension CardDeckViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        let size = rootController.view.frame.size
        let w = (size.width - 16 - 8) / 2
        let h = (size.height - 50 - 40 - 40 - 16) / 20
        return CGSize.init(width: w, height: h)
        
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
        return CGSize.init(width: 50, height: 24)
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let v = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: CardDeckViewSectionHeaderView.identifier(), for: indexPath) as! CardDeckViewSectionHeaderView
        
        if kind == UICollectionView.elementKindSectionHeader {
            
            v.sectionHeaderLabel.text = ""
            
            if indexPath.section == 0 {
                v.sectionHeaderLabel.text = "主卡组（" + self.deckViewEntity.title + "）"
            } else if indexPath.section == 1 {
                v.sectionHeaderLabel.text = "副卡组"
            } else if indexPath.section == 2 {
                v.sectionHeaderLabel.text = "额外卡组"
            }
            
            
            
            
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
        return deckEntitys.count
    }
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        //按照卡组的大小进行展示
        //如果只有主卡组，只展示1个
        return deckEntitys[section.description]!.count
    }
    
    
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        
        let cell = self.tableView.dequeueReusableCell(withReuseIdentifier: CardDeckCollectionViewCell.identifier(), for: indexPath) as! CardDeckCollectionViewCell
        
        cell.titleLabel.text = ""
        cell.backgroundColor = UIColor.white
        
        let deckEntity = deckEntitys[indexPath.section.description]![indexPath.row]
        let cardEntity = getCardEntity(id: deckEntity.id)
        
        cell.titleLabel.text = cardEntity.getName() + " x " + deckEntity.number.description

        setImage(card: cell.cardImageView, id: cardEntity.id)

        
        return cell
    }
}
