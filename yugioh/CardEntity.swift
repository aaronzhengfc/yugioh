//
//  CardEntity.swift
//  yugioh
//
//  Created by Aaron on 21/10/2016.
//  Copyright © 2016 sightcorner. All rights reserved.
//

import Foundation
import SQLite

class CardEntity {
    
    // 唯一标识
    var id: String! = ""
    //
    var enName: String! = ""
    var cnName: String! = ""
    //
    var enDesc: String! = ""
    var cnDesc: String! = ""
    
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
        if language == "cn", !cnName.isEmpty { return (isAITranslated(cardID: id ?? "", field: 1) ? "[AI译] " : "") + cnName }
        if !enName.isEmpty { return language == "cn" ? "[待译] " + enName : enName }
        if !cnName.isEmpty { return "[English unavailable] " + cnName }
        return id
    }

    func getDesc() -> String! {
        if language == "cn", !cnDesc.isEmpty { return (isAITranslated(cardID: id ?? "", field: 2) ? "[AI译] " : "") + cnDesc }
        if !enDesc.isEmpty { return language == "cn" ? "[待译] " + enDesc : enDesc }
        if !cnDesc.isEmpty { return "[English unavailable] " + cnDesc }
        return ""
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
        if !getScale().isEmpty { values.append(L10n.text("刻度 ", "Scale ") + getScale()) }
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
        return BanlistService.shared.label(for: getId())
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

/// Ranks catalogue candidates from on-device OCR. A match is only a suggestion:
/// the user must confirm the card before it is added to the collection.
final class PhysicalCardScanMatcher {
    struct Candidate {
        let card: CardEntity
        let reason: String
    }

    private struct Ranked {
        let card: CardEntity
        let priority: Int
        let reason: String
    }

    private var ids: [String: [CardEntity]] = [:]
    private var setCodes: [String: [CardEntity]] = [:]
    private var names: [String: [CardEntity]] = [:]
    private var japaneseNames: [String: [String]] = [:]

    private static var cached: PhysicalCardScanMatcher?
    // Read the bundled catalogue on the same thread as the app's shared DB.
    private static var cachedJapaneseNames: [String: [String]]?
    private static let indexQueue = DispatchQueue(label: "com.sightcorner.yugioh.physical-card-scan", qos: .userInitiated)

    /// Capture the shared app catalogue on the main thread. Build the index and
    /// search on a dedicated queue, returning UI updates on the main thread.
    static func matchAsync(lines: [String], completion: @escaping ([Candidate]) -> Void) {
        precondition(Thread.isMainThread, "Capture the catalogue on the main thread")
        let cards = getCardEntity()
        if cachedJapaneseNames == nil { cachedJapaneseNames = loadJapaneseNames(from: getDB()) }
        let japaneseNames = cachedJapaneseNames ?? [:]
        indexQueue.async {
            if cached == nil { cached = PhysicalCardScanMatcher(cards: cards, japaneseNames: japaneseNames) }
            let result = cached!.find(lines: lines)
            DispatchQueue.main.async { completion(result) }
        }
    }

    static func loadJapaneseNames(from database: Connection) -> [String: [String]] {
        var result: [String: [String]] = [:]
        do {
            for row in try database.prepare("SELECT cardId, name, ruby FROM card_name_japanese") {
                guard let id = row[0] as? Int64, let name = row[1] as? String, !name.isEmpty else { continue }
                let ruby = row[2] as? String ?? ""
                result[String(id)] = [name, ruby].filter { !$0.isEmpty }
            }
        } catch {
            // A catalogue from an older installation may not contain the table.
            // Other matching methods remain usable until a catalogue is updated.
        }
        return result
    }

    init(cards: [CardEntity], japaneseNames: [String: [String]] = [:]) {
        self.japaneseNames = japaneseNames
        for card in cards {
            guard let id = card.id, !id.isEmpty else { continue }
            if id.count <= 8, id.allSatisfy({ $0.isNumber }) {
                let padded = String(repeating: "0", count: 8 - id.count) + id
                ids[padded, default: []].append(card)
            }
            for name in [card.cnName ?? "", card.enName ?? ""] + (japaneseNames[id] ?? []) {
                let key = Self.normalizeName(name)
                guard key.count >= 2 else { continue }
                if !(names[key] ?? []).contains(where: { $0.id == id }) {
                    names[key, default: []].append(card)
                }
            }
            guard let raw = card.cardSets, let data = raw.data(using: .utf8),
                  let sets = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else { continue }
            var seen = Set<String>()
            for set in sets {
                guard let code = set["set_code"] as? String else { continue }
                let key = Self.normalizeCode(code)
                guard key.count >= 5, seen.insert(key).inserted else { continue }
                setCodes[key, default: []].append(card)
            }
        }
    }

    func find(lines: [String]) -> [Candidate] {
        var ranked: [String: Ranked] = [:]
        func add(_ card: CardEntity, priority: Int, reason: String) {
            guard let id = card.id, !id.isEmpty else { return }
            if let current = ranked[id], current.priority <= priority { return }
            ranked[id] = Ranked(card: card, priority: priority, reason: reason)
        }

        for original in lines.prefix(80) {
            let line = original.precomposedStringWithCompatibilityMapping.uppercased()
            // A password is eight digits, including printed leading zeroes. Do not
            // pull embedded digits out of a set code, date or longer number.
            for token in Self.matches(#"(?<![A-Z0-9])\d{8}(?![A-Z0-9])"#, in: line) {
                for card in ids[token] ?? [] { add(card, priority: 0, reason: L10n.text("卡片密码匹配", "Card password match")) }
            }

            // Only a full, indexed set code is accepted; different printings can
            // share a code, so all matching card identities remain candidates.
            let pattern = #"(?<![A-Z0-9])[A-Z0-9]{2,12}\s*[-‐–—−ー]\s*[A-Z0-9]{2,12}(?![A-Z0-9])"#
            for token in Self.matches(pattern, in: line) {
                for card in setCodes[Self.normalizeCode(token)] ?? [] {
                    add(card, priority: 1, reason: L10n.text("卡包编号匹配", "Set code match"))
                }
            }

            let key = Self.normalizeName(line)
            guard key.count >= 2 else { continue }
            for card in names[key] ?? [] {
                if let japaneseName = matchingJapaneseName(cardID: card.id ?? "", normalized: key) {
                    add(card, priority: 2, reason: L10n.text("日文名匹配", "Japanese name match") + " · " + japaneseName)
                } else {
                    add(card, priority: 2, reason: L10n.text("卡名匹配", "Card name match"))
                }
            }
        }
        // A small OCR spelling error is useful as a fallback, but never overrides
        // an exact password, set code or name. Exclude short fragments and effect
        // text, and allow at most one edit so unrelated cards are not treated as a
        // confident result.
        if ranked.isEmpty {
            for original in lines.prefix(8) {
                let key = Self.normalizeName(original)
                // Japanese names often contain fewer characters than English
                // names. Allow one OCR error for a 4+ character CJK name, while
                // keeping short fragments and very long lines out of the fallback.
                let hasCJK = key.unicodeScalars.contains {
                    (0x3040...0x30FF).contains($0.value) || (0x3400...0x9FFF).contains($0.value)
                }
                let minimumLength = hasCJK ? 4 : 6
                guard (minimumLength...40).contains(key.count) else { continue }
                for (name, matches) in names where abs(name.count - key.count) <= 1 && name.count >= minimumLength {
                    if Self.oneEditAway(key, name) {
                        for card in matches {
                            if let japaneseName = matchingJapaneseName(cardID: card.id ?? "", normalized: name) {
                                add(card, priority: 3, reason: L10n.text("日文名近似匹配，请核对", "Similar Japanese name; verify") + " · " + japaneseName)
                            } else {
                                add(card, priority: 3, reason: L10n.text("卡名近似匹配，请核对", "Similar card name; verify"))
                            }
                        }
                    }
                }
            }
        }
        return ranked.values.sorted {
            if $0.priority != $1.priority { return $0.priority < $1.priority }
            return ($0.card.id ?? "") < ($1.card.id ?? "")
        }.prefix(30).map { match in
            // Even when the stronger signal is a card password or set code,
            // show the Japanese printed name to help verify the physical card.
            let japaneseName = japaneseNames[match.card.id ?? ""]?.first
            let reason = japaneseName.flatMap { match.reason.contains($0) ? nil : match.reason + " · " + $0 } ?? match.reason
            return Candidate(card: match.card, reason: reason)
        }
    }

    private func matchingJapaneseName(cardID: String, normalized: String) -> String? {
        (japaneseNames[cardID] ?? []).first { Self.normalizeName($0) == normalized }
    }

    private static func normalizeName(_ text: String) -> String {
        let normalized = text.precomposedStringWithCompatibilityMapping
        // Japanese dakuten/handakuten change the syllable (ガ vs カ). Treating
        // them as disposable accents can turn different names into an exact match.
        let containsKana = normalized.unicodeScalars.contains { (0x3040...0x30FF).contains($0.value) }
        let options: String.CompareOptions = containsKana ? [.caseInsensitive] : [.caseInsensitive, .diacriticInsensitive]
        let folded = normalized.folding(options: options, locale: Locale(identifier: "en_US_POSIX"))
        return String(folded.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) })
    }

    private static func normalizeCode(_ text: String) -> String {
        return String(text.precomposedStringWithCompatibilityMapping.uppercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) })
    }

    private static func oneEditAway(_ lhs: String, _ rhs: String) -> Bool {
        let a = Array(lhs), b = Array(rhs)
        guard abs(a.count - b.count) <= 1 else { return false }
        var i = 0, j = 0, edits = 0
        while i < a.count && j < b.count {
            if a[i] == b[j] { i += 1; j += 1; continue }
            edits += 1
            if edits > 1 { return false }
            if a.count >= b.count { i += 1 }
            if b.count >= a.count { j += 1 }
        }
        return edits + (a.count - i) + (b.count - j) <= 1
    }

    private static func matches(_ pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { result in
            Range(result.range, in: text).map { String(text[$0]) }
        }
    }
}
