//
//  UIVerticalAlignLabel.swift
//  swifttips
//
//  Created by Aaron on 25/7/2016.
//  Copyright © 2016 sightcorner. All rights reserved.
//

import Foundation
import UIKit
import SwiftyJSON

import SQLite


public var Timestamp: String {
    return "\(NSDate().timeIntervalSince1970 * 1000)"
}

public class UIVerticalAlignLabel: UILabel {
    
    enum VerticalAligment: Int {
        case VerticalAligmentTop = 0
        case VerticalAligmentMiddle = 1
        case VerticalAligmentBottom = 2
    }
    
    
    var verticalAligment: VerticalAligment = .VerticalAligmentTop {
        didSet {
            setNeedsDisplay()
        }
    }
    
    /**
     顶部和左对齐的标签
     
     - parameter bounds:
     - parameter numberOfLines:
     
     - returns:
     */
    public override func textRect(forBounds bounds: CGRect, limitedToNumberOfLines numberOfLines: Int) -> CGRect {
        let rect = super.textRect(forBounds: bounds, limitedToNumberOfLines: numberOfLines)
        
        switch verticalAligment {
        case .VerticalAligmentTop:
            return CGRect.init(x: bounds.origin.x, y: bounds.origin.y, width: rect.size.width, height: rect.size.height)
        case .VerticalAligmentMiddle:
            return CGRect.init(x: bounds.origin.x, y: bounds.origin.y + (bounds.size.height - rect.size.height) / 2, width: rect.size.width, height: rect.size.height)
        case .VerticalAligmentBottom:
            return CGRect.init(x: bounds.origin.x, y: bounds.origin.y + (bounds.size.height - rect.size.height), width: rect.size.width, height: rect.size.height)
        }
    }
    
    public override func drawText(in rect: CGRect) {
        let r = self.textRect(forBounds: rect, limitedToNumberOfLines: self.numberOfLines)
        super.drawText(in: r)
    }
}

//预计算文字高度
func preCalculateTextHeight(text: String, font: UIFont, width: CGFloat) -> CGFloat {
    let label:UILabel = UILabel(frame: CGRect.init(x: 0, y: 0, width: width, height: CGFloat.greatestFiniteMagnitude))
    label.numberOfLines = 0
    label.lineBreakMode = .byWordWrapping
    label.font = font
    label.text = text
    label.translatesAutoresizingMaskIntoConstraints = false
//    label.heightAnchor.constraint(equalToConstant: <#T##CGFloat#>).isActive = true
    label.sizeToFit()
    
    return label.frame.height
}

//获取图片链接
func getCardUrl(id: String) -> String {
    return qiniuUrlPrefix + id + qiniuUrlSuffix
}


fileprivate var cardEntitys: Array<CardEntity> = [];


//获取所有卡牌列表
func getCardEntity() -> Array<CardEntity> {
    if cardEntitys.count > 0 {
        if language == preLanuage {
            return cardEntitys;
        }
    }
    
    if keyValueMap.count <= 0 {
        do {
            for each in try getDB().prepare("select * from newmap ") {
                keyValueMap.append(buildKeyValueMap(element: each))
            }
        } catch {
            print(error.localizedDescription)
        }
    }
    
    do {
        cardEntitys = []
        for each in try getDB().prepare("select id, enName,frName,deName,itName,ptName,cnName,jpName,enDesc,frDesc,deDesc,itDesc,ptDesc,cnDesc,jpDesc,archetype,frameType,race,type,attribute,cardImages,cardPrices,cardSets,atk,def,level,scale,linkval,linkmarkers,banlistInfo, miscInfo, startDate from  newpro order by id desc") {
            cardEntitys.append(buildCardEntity(element: each))
        }
        cardEntitys.sort { (c1, c2) -> Bool in
            if c1.startDate != nil && c2.startDate != nil {
                return c1.startDate > c2.startDate
            }
            return false;
        }
        preLanuage = language
    } catch {
        print(error.localizedDescription)
    }
    
    return cardEntitys
}


var language: String = "cn"
var preLanuage: String = "cn"
var keyValueMap: Array<KeyValueEntryEntity> = [];

//获取卡牌详情
func getCardEntity(id: String) -> CardEntity {
    do {
        for each in try getDB().prepare("select id, enName,frName,deName,itName,ptName,cnName,jpName,enDesc,frDesc,deDesc,itDesc,ptDesc,cnDesc,jpDesc,archetype,frameType,race,type,attribute,cardImages,cardPrices,cardSets,atk,def,level,scale,linkval,linkmarkers,banlistInfo, miscInfo, startDate from  newpro where id = \"\(id)\"") {
            return buildCardEntity(element: each)
        }
    } catch {
        print(error.localizedDescription)
    }
    return CardEntity()
}

func getDecksByDeckFormat(deckFormat: String) -> [DeckViewEntity] {
    var decks: Array<DeckViewEntity> = [];
    do {
        for each in try getDB().prepare("select deckCode from newdeck where deckFormat =\"\(deckFormat)\" group by deckCode order by deckCode desc") {
            let deckCode = String(each[0] as? String ?? "");
            let deck: DeckViewEntity = getDeckViewEntity(deckName: deckCode, titleName: deckCode, type: deckFormat)
            decks.append(deck)
        }
    } catch {
        print(error.localizedDescription)
    }
    return decks;
}

private var deckViewEntitysConstant: [DeckViewEntity] = [];
func getDeckViewEntity() -> [DeckViewEntity] {
    if(deckViewEntitysConstant.count > 0) {
        return deckViewEntitysConstant
    }
    
    var tmp: [DeckViewEntity] = [
        DeckViewEntity(id: "1", title: "我的收藏", introduction: "我的收藏", type: "star"),
        DeckViewEntity(id: "0", title: "我的卡组", introduction: "我的卡组", type: "self")
    ]
    // "游戏王世界锦标赛冠军卡组"
    let championDecks: [DeckViewEntity] = getDecksByDeckFormat(deckFormat: "worldchampionship")
    var championNames: [String: String] = [:]
    var championRegions: [String: String] = [:]
    do {
        for row in try getDB().prepare("SELECT deckCode, champion, countryRegionZh FROM newdeck_metadata WHERE deckFormat = 'worldchampionship'") {
            if let year = row[0] as? String, let name = row[1] as? String {
                championNames[year] = name
                championRegions[year] = row[2] as? String ?? ""
            }
        }
    } catch {
        print("Unable to load champion names: \(error.localizedDescription)")
    }
    for each in championDecks {
        each.champion = championNames[each.id] ?? ""
        each.championRegion = championRegions[each.id] ?? ""
        each.title = each.title + "游戏王世界锦标赛冠军卡组"
        tmp.append(each)
    }
    let dm1: [DeckViewEntity] = getDecksByDeckFormat(deckFormat: "1-dm")
    for each in dm1 {
        tmp.append(each)
    }
    
    
    deckViewEntitysConstant = tmp
    return deckViewEntitysConstant
}


// 展示卡组
func getDeckViewEntity(deckName: String, titleName: String, type: String) -> DeckViewEntity {
    let deckViewEntity = DeckViewEntity()
    deckViewEntity.id = deckName
    deckViewEntity.title = titleName
    deckViewEntity.introduction = titleName
    deckViewEntity.type = type
    return deckViewEntity
}


func getDeckEntity(deckFormat: String, deckName: String) -> [String: [DeckEntity]]{
    var deckEntitys = [String: [DeckEntity]]()
    //主卡组 0
    //禁止卡 3
    deckEntitys["0"] = []
    //副卡组 1
    //限制卡 4
    deckEntitys["1"] = []
    //额外卡组 2
    //准限制卡 5
    deckEntitys["2"] = []
    //
    do {
        for each in try getDB().prepare("select cardId, type, number from newdeck where deckFormat =\"\(deckFormat)\" and deckCode = \"\(deckName)\"") {
            let d = DeckEntity()
            d.id = each[0] as! String
            let type = each[1] as! NSString
            if type.integerValue > 2 {
                d.type = String(type.integerValue - 3)
            } else {
                d.type = each[1] as! String
            }
            d.number = Int(truncating: each[2] as! NSNumber)
            deckEntitys[d.type]!.append(d)
        }
    } catch {
        print(error.localizedDescription)
    }
    return deckEntitys
}


//设置图片
func setImage(card: UIImageView, id: String, completionHandler: ((Result) -> Void)? = nil) {
    
    let url = getCardUrl(id: id)
    
    card.kf.setImage(with: URL(string: url),
                          placeholder: UIImage(named: "defaultimg"),
                          options: [
                            .scaleFactor(UIScreen.main.scale),
                            .transition(.fade(0.1)),
                            .cacheOriginalImage]
    )
}

func buildKeyValueMap(element: [Binding?]) -> KeyValueEntryEntity {
    let keyValueEntryEntity = KeyValueEntryEntity()
    keyValueEntryEntity.key = String(element[0] as? String ?? "")
    keyValueEntryEntity.subKey = String(element[1] as? String ?? "")
    keyValueEntryEntity.frValue = String(element[2] as? String ?? "")
    keyValueEntryEntity.deValue = String(element[3] as? String ?? "")
    keyValueEntryEntity.itValue = String(element[4] as? String ?? "")
    keyValueEntryEntity.ptValue = String(element[5] as? String ?? "")
    keyValueEntryEntity.cnValue = String(element[6] as? String ?? "")
    keyValueEntryEntity.jpValue = String(element[7] as? String ?? "")
    return keyValueEntryEntity;
}

/**
 0 b.id,
 1 b.name,
 2 b.type,
 3 b.desc,
 4 b.atk,
 5 b.def,
 6 b.level,
 7 b.race,
 8 b.attribute,
 9 b.archetype,
 10 b.scale,
 11 b.linkval,
 12 b.linkmarkers,
 13 b.card_sets,
 14 b.card_images,
 15 b.card_prices,
 16 b.banlist_info
 **/
//
//构建卡片结构
func buildCardEntity(element: [Binding?]) -> CardEntity {
    let cardEntity = CardEntity()
    //password
    cardEntity.id = String(element[0] as! Int64)
    cardEntity.enName = String(element[1] as? String ?? "")
    cardEntity.frName  = String(element[2] as? String ?? "")
    cardEntity.deName  = String(element[3] as? String ?? "")
    cardEntity.itName  = String(element[4] as? String ?? "")
    cardEntity.ptName  = String(element[5] as? String ?? "")
    cardEntity.cnName  = String(element[6] as? String ?? "")
    cardEntity.jpName  = String(element[7] as? String ?? "")
    cardEntity.enDesc  = String(element[8] as? String ?? "")
    cardEntity.frDesc  = String(element[9] as? String ?? "")
    cardEntity.deDesc  = String(element[10] as? String ?? "")
    cardEntity.itDesc  = String(element[11] as? String ?? "")
    cardEntity.ptDesc  = String(element[12] as? String ?? "")
    cardEntity.cnDesc  = String(element[13] as? String ?? "")
    cardEntity.jpDesc  = String(element[14] as? String ?? "")
    cardEntity.archetype = String(element[15] as? String ?? "")
    cardEntity.frameType = String(element[16] as? String ?? "")
    cardEntity.race = String(element[17] as? String ?? "")
    cardEntity.type = String(element[18] as? String ?? "")
    cardEntity.attribute = String(element[19] as? String ?? "")
    cardEntity.cardImages = String(element[20] as? String ?? "")
    cardEntity.cardPrices = String(element[21] as? String ?? "")
    cardEntity.cardSets = String(element[22] as? String ?? "")
    cardEntity.atk = String(element[23] as? String ?? "")
    cardEntity.def = String(element[24] as? String ?? "")
    cardEntity.level = String(element[25] as? String ?? "")
    cardEntity.scale = String(element[26] as? String ?? "")
    cardEntity.linkval = String(element[27] as? String ?? "")
    cardEntity.linkmarkers = String(element[28] as? String ?? "")
    cardEntity.banlistInfo = String(element[29] as? String ?? "")
    cardEntity.miscInfo = String(element[30] as? String ?? "")
    cardEntity.startDate = String(element[31] as? String ?? "")
    //
    return cardEntity
}

func getPack(s : String?) -> String {
    if let tmp = s?.data(using: .utf8, allowLossyConversion: false) {
        do {
            let json = try JSON(data: tmp)
            var cardSet = ""
            for(_, subJson):(String, JSON) in json {
                if(cardSet != "") {
                    cardSet += ","
                }
                cardSet = "\(cardSet)\(subJson["set_code"])"
            }
            return cardSet
        } catch {
            print("ERROR \(error)")
        }
    }
    
    return ""
}


//获取分享时候使用的小图
func getShareViewImage(v: UIView) -> UIImage {
    let w = v.frame.width
    let h = v.frame.height
    let size = CGSize(width: w, height: h)
    UIGraphicsBeginImageContextWithOptions(size, false, 0)
    v.layer.render(in: UIGraphicsGetCurrentContext()!)
    let image: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
    UIGraphicsEndImageContext()
    
    return image
}

//判断当前是否iphonex，做特殊处理
func isIPhoneX() -> Bool {
    if UIDevice().userInterfaceIdiom == .phone {
        if UIScreen.main.nativeBounds.height >= 1792 {
            return true
        }
//        switch UIScreen.main.nativeBounds.height {
//        case 2436:
//            return true
//        case 2688:
//            return true
//        case 1792:
//            return true
//        default:
//            return false
//        }
    }
    return false
}



func getValue(entry: KeyValueEntryEntity) -> String {
    if language == "fr" {
        return entry.frValue
    }
    if language == "de" {
        return entry.deValue
    }
    if language == "it" {
        return entry.itValue
    }
    if language == "pt" {
        return entry.ptValue
    }
    if language == "cn" {
        return entry.cnValue
    }
    if language == "jp" {
        return entry.jpValue
    }
    if language == "en" {
        return entry.subKey
    }
    return ""
}

func getValue(key: String, subKey: String, language: String) -> String {
    for entry in keyValueMap {
        if entry.key == key && entry.subKey == subKey {
            let v = getValue(entry: entry);
            return v;
        }
    }
    return ""
}


func getValues(inputKey: String) -> Array<String> {
    var values: Array<String>! = []
    for entry in keyValueMap {
        if entry.key == inputKey {
            let value = getValue(entry: entry)
            values.append(value)
        }
    }
    
    return values;
}
