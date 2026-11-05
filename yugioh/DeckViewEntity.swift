//
//  DeckView.swift
//  yugioh
//
//  Created by Aaron on 6/8/2017.
//  Copyright © 2017 sightcorner. All rights reserved.
//

import Foundation

class DeckViewEntity {
    // 卡组的唯一标识
    public var id: String = ""
    // 卡组名称
    public var title: String = ""
    // 卡组介绍
    public var introduction: String = ""
    // 卡组类型
    public var type: String = ""
    public var champion: String = ""
    public var championRegion: String = ""
    public var isCancelled: Bool = false
    var history: DeckHistory?
    
    init() {
        
    }
    
    init(id: String, title: String, introduction: String, type: String) {
        self.id = id
        self.title = title
        self.introduction = introduction
        self.type = type
    }
    
}

struct DeckHistoryParagraph: Decodable {
    let title: String
    let text: String
}

struct DeckHistory {
    let year: Int
    let placement: String
    let sourceURL: String
    let recipeSourceURL: String
    let recipeStatus: String
    let analysisKind: String
    let paragraphs: [DeckHistoryParagraph]

    var hasRecipe: Bool { recipeStatus != "missing" }
    var recipeLabel: String {
        switch recipeStatus {
        case "missing": return L10n.text("配方待补充", "Deck list pending")
        case "partial": return L10n.text("配方缺项", "Incomplete deck list")
        case "verified_transcription": return L10n.text("已核对配方", "Verified deck list")
        default: return L10n.text("历史配方", "Historical deck list")
        }
    }
    var analysisLabel: String {
        switch analysisKind {
        case "recipe_editorial": return L10n.text("基于配方的编辑解读 · 非选手自述", "Editorial analysis of the deck list · Not a player statement")
        case "recipe_observation": return L10n.text("类型介绍与配比观察 · 非选手自述", "Strategy overview and card ratios · Not a player statement")
        default: return L10n.text("卡组类型介绍 · 选手配方待补充", "Strategy overview · Player deck list pending")
        }
    }
}

struct DeckHistoryYear {
    let year: Int
    let decks: [DeckViewEntity]
}

func loadDeckHistory() -> [DeckHistoryYear] {
    var years: [DeckHistoryYear] = []
    do {
        for event in try getDB().prepare("SELECT id,year,status,sourceUrl FROM history_event ORDER BY year DESC") {
            guard let eventID = event[0] as? String, let yearValue = event[1] as? Int64 else { continue }
            let year = Int(yearValue)
            if event[2] as? String == "not_held" {
                let deck = DeckViewEntity(id: eventID, title: L10n.text("世界赛停办", "World Championship not held"), introduction: "", type: "history")
                deck.isCancelled = true
                years.append(DeckHistoryYear(year: year, decks: [deck]))
                continue
            }
            var decks: [DeckViewEntity] = []
            // Show the podium, or both semifinalists when the event awards joint third place.
            for row in try getDB().prepare("SELECT id,placementLabel,player,region,strategy,recipeStatus,recipeSourceUrl,analysisKind,analysisJson,strategyOriginal,placement FROM history_deck WHERE eventId = ? AND placement IN ('1st', '2nd', '3rd', '3-4th') ORDER BY sortOrder", eventID) {
                guard let id = row[0] as? String, let json = row[8] as? String,
                      let data = json.data(using: .utf8) else { continue }
                let paragraphs = try JSONDecoder().decode([DeckHistoryParagraph].self, from: data)
                let originalStrategy = row[9] as? String ?? ""
                let title = L10n.text(row[4] as? String ?? "卡组类型待考证", originalStrategy.isEmpty ? "Strategy unconfirmed" : originalStrategy)
                let deck = DeckViewEntity(id: id, title: title, introduction: "", type: "history")
                deck.champion = row[2] as? String ?? ""
                deck.championRegion = localizedDeckRegion(row[3] as? String ?? "")
                deck.history = DeckHistory(year: year, placement: L10n.text(row[1] as? String ?? "", localizedDeckPlacement(row[10] as? String ?? "")), sourceURL: event[3] as? String ?? "",
                                           recipeSourceURL: row[6] as? String ?? "", recipeStatus: row[5] as? String ?? "missing",
                                           analysisKind: row[7] as? String ?? "type_overview", paragraphs: paragraphs)
                decks.append(deck)
            }
            years.append(DeckHistoryYear(year: year, decks: decks))
        }
    } catch {
        print("Unable to load deck history: \(error.localizedDescription)")
        return []
    }
    return years
}

func loadHistoryCards(id: String) -> [String: [DeckEntity]] {
    var cards: [String: [DeckEntity]] = ["0": [], "1": [], "2": []]
    do {
        for row in try getDB().prepare("SELECT cardId,section,quantity FROM history_card WHERE deckId = ? ORDER BY section,sortOrder", id) {
            guard let cardID = row[0] as? String, let section = row[1] as? Int64,
                  let quantity = row[2] as? Int64 else { continue }
            let key = String(section)
            cards[key, default: []].append(DeckEntity(id: cardID, number: Int(quantity), type: key))
        }
    } catch { print("Unable to load historical recipe: \(error.localizedDescription)") }
    return cards
}

// Preserve source names while translating the region labels stored by the historical importer.
private func localizedDeckRegion(_ region: String) -> String {
    let englishNames = [
        "中国香港": "Hong Kong, China", "日本": "Japan", "美国": "United States",
        "英国": "United Kingdom", "希腊": "Greece", "墨西哥": "Mexico", "德国": "Germany",
        "中国台湾": "Taiwan", "意大利": "Italy", "波兰": "Poland", "智利": "Chile",
        "加拿大": "Canada", "新加坡": "Singapore", "韩国": "South Korea", "巴拿马": "Panama",
        "泰国": "Thailand", "澳大利亚": "Australia", "秘鲁": "Peru", "挪威": "Norway"
    ]
    return L10n.text(region, englishNames[region] ?? region)
}

private func localizedDeckPlacement(_ placement: String) -> String {
    switch placement {
    case "1st": return "Champion"
    case "2nd": return "Runner-up"
    case "3rd": return "Third place"
    case "4th": return "Fourth place"
    case "3-4th": return "Semifinalist"
    default: return placement
    }
}
