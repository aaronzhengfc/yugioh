//
//  CardDeckViewController.swift
//  yugioh
//
//  Created by Aaron on 1/7/2017.
//  Copyright © 2017 sightcorner. All rights reserved.
//

import Foundation
import UIKit



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
        let shareButton = UIBarButtonItem.init(
            title: "分享",
            style: .done,
            target: self,
            action: #selector(CardDeckViewController.shareButtonHandler)
        )
        
        self.navigationItem.rightBarButtonItem = shareButton
    }
    
    @objc func shareButtonHandler() {
        guard WeChatSharing.canShare(from: self) else { return }
        
        
        let img = self.getShareViewImage()
        let ext = WXImageObject()
        ext.imageData = img.jpegData(compressionQuality: 1)!
        
        let message = WXMediaMessage()
        message.title = ""
        message.description = ""
        message.mediaObject = ext
        message.mediaTagName = "游戏王卡牌"
        //生成缩略图
        UIGraphicsBeginImageContext(CGSize(width: 100, height: 200))
        img.draw(in: CGRect(x: 0, y: 0, width: 100, height: 200))
        let thumbImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        message.thumbData = thumbImage?.pngData()
        
        let req = SendMessageToWXReq()
        req.text = ""
        req.message = message
        req.bText = false
        req.scene = 0
        WeChatSharing.send(req, from: self)
    }
    
    
    func getShareViewImage() -> UIImage {
        UIGraphicsBeginImageContextWithOptions(tableView.contentSize, false, 0)
        
        tableView.scrollToItem(at: IndexPath(row: 0, section: 0), at: .top, animated: false)
        tableView.layer.render(in: UIGraphicsGetCurrentContext()!)
        let row = tableView.numberOfItems(inSection: 0)
        let numberOfRowThatShowInScreen = 4
        let scrollCount = row / numberOfRowThatShowInScreen
        for i in 0 ..< scrollCount {
            var row = ( i + 1 ) * numberOfRowThatShowInScreen
            if row > 0 {
                row = row - 1
            }
            let indexPath = IndexPath(row: row, section: 0)
            tableView.scrollToItem(at: indexPath, at: .top, animated: false)
            tableView.layer.render(in: UIGraphicsGetCurrentContext()!)
        }
        let image: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        
        return image
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
