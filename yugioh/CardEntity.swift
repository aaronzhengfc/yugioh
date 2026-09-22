//
//  CardEntity.swift
//  yugioh
//
//  Created by Aaron on 21/10/2016.
//  Copyright © 2016 sightcorner. All rights reserved.
//

import Foundation

class CardEntity {
    
    // 唯一标识
    var id: String! = ""
    //
    var enName: String! = ""
    var frName: String! = ""
    var deName: String! = ""
    var itName: String! = ""
    var ptName: String! = ""
    var cnName: String! = ""
    var jpName: String! = ""
    //
    var enDesc: String! = ""
    var frDesc: String! = ""
    var deDesc: String! = ""
    var itDesc: String! = ""
    var ptDesc: String! = ""
    var cnDesc: String! = ""
    var jpDesc: String! = ""
    
    //
    var archetype: String! = ""
    
    //
    var frameType: String! = ""
    
    // 种族，鸟兽，念动力，等等
    var race: String! = ""
    
    // 类型，空格隔离
    var type: String! = ""
    
    // 属性，光，暗，风，等灯
    var attribute: String! = ""
    
    //
    var cardImages: String! = ""
    
    //
    var cardPrices: String! = ""
    
    //
    var cardSets: String! = ""
    
    // 攻击力
    var atk: String! = ""
    
    // 防御力
    var def: String! = ""
    
    // 星级
    var level: String! = ""
    
    // 灵摆，数字表示
    var scale: String! = ""
    
    
    // 连接，数字表示
    var linkval: String! = ""
    
    // 连接标记，大概为 左上，左下
    var linkmarkers: String! = ""
    
    //
    var banlistInfo: String! = ""
    
    //
    var miscInfo: String! = ""
    
    //
    var startDate: String! = ""
    
    // 额外添加属性
    // var url: String! = ""
    var isSelected: Bool = false
    
    
    func getId() -> String {
        return id;
    }
    
    
    func getName() -> String! {
        var r = "";
        if(language == "en") {
            r = enName;
        }
        if(language == "cn") {
            r = cnName;
        }
        if(language == "fr") {
            r = frName;
        }
        if(language == "it") {
            r = itName
        }
        if(language == "pt") {
            r = ptName
        }
        if r == "" {
            if language == "cn" {
                r = "[待译] " + enName
            } else {
                r = "[To be translated]  " + enName
            }
        }
        return r;
    }
    
    func getDesc() -> String! {
        var r = ""
        if(language == "en") {
            r = enDesc;
        }
        if(language == "cn") {
            r = cnDesc
        }
        if(language == "fr") {
            r = frDesc;
        }
        if(language == "it") {
            r = itDesc
        }
        if(language == "pt") {
            r = ptDesc
        }
        
        if r == "" {
            if language == "cn" {
                r = "[待译] " + enDesc
            } else {
                r = "[To be translated]  " + enDesc
            }
        }
        return r;
    }
    
    
    func getArchetype() -> String! {
        var r = ""
        if(language == "en") {
            r = archetype;
        } else {
            r = getValue(key: "archietype", subKey: archetype, language: language)
        }
        
        if(r == "") {
            return "-";
        }
        return r;
    }
    
    func getFrameType() -> String! {
        return frameType;
    }
    
    func getRace() -> String!  {
        
        
        var r = ""
        if(language == "en") {
            r = race;
        } else {
            r = getValue(key: "race", subKey: race, language: language)
        }
        return r;
    }
    
    func getType() -> String!  {
        
        var r = ""
        if(language == "en") {
            r = type;
        } else {
            r = handleType(input: type, language: language)
        }
    
        return r;
    }
    
    func getStatsText() -> String {
        var values: [String] = []
        if !getLevel().isEmpty { values.append("★ " + getLevel()) }
        if !getLinkval().isEmpty { values.append("LINK " + getLinkval()) }
        if !getAtk().isEmpty { values.append("ATK " + getAtk()) }
        if !getDef().isEmpty { values.append("DEF " + getDef()) }
        if !getScale().isEmpty { values.append("刻度 " + getScale()) }
        return values.joined(separator: "   ")
    }

    func getMetadataText() -> String {
        let rawType = type ?? ""
        let typeKeys = rawType.hasSuffix("Monster")
            ? rawType.split(separator: " ").map(String.init) : [rawType]
        // Use the same entries and labels as the search filter buttons.
        let typeLabels = keyValueMap.filter {
            $0.key == "type" && typeKeys.contains($0.subKey)
        }.map { getValue(entry: $0) }
        let parts = (typeLabels.isEmpty ? [getType() ?? ""] : typeLabels)
            + [getAttribute() ?? "", getRace() ?? ""]
        return parts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }.joined(separator: " · ")
    }

    func getAttribute() -> String!  {
        
        var r = ""
        if(language == "en") {
            r = attribute;
        } else {
            r = getValue(key: "attribute", subKey: attribute, language: language)
        }
        
        
        return r;
    }
    
    func getCardImages() -> String {
        return cardImages;
    }
    
    func getCardPrices() -> String {
        return cardPrices;
    }
    
    func getCardSets() -> String {
        return cardSets;
    }
    
    func getAtk() -> String {
        return atk;
    }
    
    func getDef() -> String {
        return def;
    }
    
    func getLevel() -> String {
        return level;
    }
    
    func getScale() -> String {
        return scale;
    }
    
    func getLinkval() -> String {
        return linkval;
    }
    
    func getLinkmarkers() -> String {
        return linkmarkers;
    }
    
    func getBanlistInfo() -> String {
        return banlistInfo;
    }
    
    func getBanlistInfoText() -> String {
        // 禁止，限制，准限制，无限制
        var r = "Unlimited"
        if banlistInfo != nil && banlistInfo.contains("Semi-Limited") {
            r = "Semi-Limited"
        }
        if banlistInfo != nil && banlistInfo.contains("Limited") {
            r = "Limited"
        }
        if banlistInfo != nil && banlistInfo.contains("Banned") {
            r = "Forbidden"
        }
        
        if(language != "en") {
            r = getValue(key: "ban", subKey: r, language: language)
        }
        
        return r;
    }
    
    func getStartDate() -> String {
        return startDate;
    }
    
    func handleType(input: String, language:String) -> String {
        var output = input;
        for entry in keyValueMap {
            if entry.key != "type" {
                continue
            }
            let v = getValue(entry: entry)
            output = output.replacingOccurrences(of: entry.subKey, with: v)
        }
        return output;
    }
    
}
