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
        case "missing": return "配方待补充"
        case "partial": return "配方缺项"
        case "verified_transcription": return "已核对配方"
        default: return "历史配方"
        }
    }
    var analysisLabel: String {
        switch analysisKind {
        case "recipe_editorial": return "基于配方的编辑解读 · 非选手自述"
        case "recipe_observation": return "类型介绍与配比观察 · 非选手自述"
        default: return "卡组类型介绍 · 选手配方待补充"
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
                let deck = DeckViewEntity(id: eventID, title: "世界赛停办", introduction: "", type: "history")
                deck.isCancelled = true
                years.append(DeckHistoryYear(year: year, decks: [deck]))
                continue
            }
            var decks: [DeckViewEntity] = []
            // Show the podium, or both semifinalists when the event awards joint third place.
            for row in try getDB().prepare("SELECT id,placementLabel,player,region,strategy,recipeStatus,recipeSourceUrl,analysisKind,analysisJson FROM history_deck WHERE eventId = ? AND placement IN ('1st', '2nd', '3rd', '3-4th') ORDER BY sortOrder", eventID) {
                guard let id = row[0] as? String, let json = row[8] as? String,
                      let data = json.data(using: .utf8) else { continue }
                let paragraphs = try JSONDecoder().decode([DeckHistoryParagraph].self, from: data)
                let deck = DeckViewEntity(id: id, title: row[4] as? String ?? "卡组类型待考证", introduction: "", type: "history")
                deck.champion = row[2] as? String ?? ""
                deck.championRegion = row[3] as? String ?? ""
                deck.history = DeckHistory(year: year, placement: row[1] as? String ?? "", sourceURL: event[3] as? String ?? "",
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
