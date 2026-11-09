import UIKit
import CoreData

class DeckService {
    enum MutationResult: Equatable {
        case saved
        case copyLimit
        case invalidSection
        case storageFailure

        var message: String {
            switch self {
            case .saved: return ""
            case .copyLimit: return L10n.text("同名卡在主卡、额外和副卡组中合计最多 3 张。", "A card may have at most 3 copies across Main, Extra and Side Decks, including alternate artwork.")
            case .invalidSection: return L10n.text("这张卡不能放入所选区域。融合、同调、超量和连接怪兽请加入额外卡组或副卡组。", "This card cannot go in that section. Fusion, Synchro, Xyz and Link Monsters belong in the Extra or Side Deck.")
            case .storageFailure: return L10n.text("卡组保存失败，请重试。", "Your deck could not be saved. Please try again.")
            }
        }
    }

    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext? = nil) {
        self.context = context ?? (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    }

    private func entries() throws -> [DeckPO] {
        let request = NSFetchRequest<DeckPO>(entityName: "DeckPO")
        request.sortDescriptors = [NSSortDescriptor(key: "id", ascending: false)]
        return try context.fetch(request)
    }

    func conversion() {
        do {
            for entry in try entries() where entry.type == nil { entry.type = "0" }
            if context.hasChanges { try context.save() }
        } catch { print("Unable to migrate deck: \(error.localizedDescription)") }
    }

    func list() -> [String: [DeckEntity]] {
        var result: [String: [DeckEntity]] = ["0": [], "1": [], "2": []]
        do {
            for entry in try entries() {
                guard entry.version != nil, let id = entry.id, let type = entry.type,
                      result[type] != nil, let number = entry.number, number.intValue > 0 else { continue }
                result[type]?.append(DeckEntity(id: id, number: number.intValue, type: type))
            }
        } catch { print("Unable to read deck: \(error.localizedDescription)") }
        return result
    }

    static func isExtraDeckCard(_ card: CardEntity) -> Bool {
        let type = (card.type ?? "").lowercased()
        return ["fusion", "synchro", "xyz", "link"].contains { type.contains($0) }
    }

    static func canAdd(_ card: CardEntity, to section: String) -> Bool {
        guard !(card.id ?? "").isEmpty, ["0", "1", "2"].contains(section) else { return false }
        let type = (card.type ?? "").lowercased()
        guard !type.contains("token"), !type.contains("skill"), !type.isEmpty else { return false }
        return section == "1" || (section == "2" ? isExtraDeckCard(card) : !isExtraDeckCard(card))
    }

    static func identity(for card: CardEntity) -> String {
        // The catalogue also links old beta passwords whose English names changed.
        // Share the same canonical identity used by the banlist importer.
        return "card:\(BanlistService.shared.canonicalID(for: card.id ?? ""))"
    }

    func count(of card: CardEntity, in section: String? = nil) -> Int {
        let identity = Self.identity(for: card)
        return list().filter { section == nil || $0.key == section! }.values.flatMap { $0 }.reduce(0) { total, entry in
            total + (Self.identity(for: getCardEntity(id: entry.id)) == identity ? entry.number : 0)
        }
    }

    @discardableResult
    func save(id: String, type: String) -> MutationResult {
        let card = getCardEntity(id: id)
        guard Self.canAdd(card, to: type) else { return .invalidSection }
        do {
            let cards = try entries()
            let identity = Self.identity(for: card)
            let total = cards.reduce(0) { count, entry in
                guard entry.version != nil, let cardID = entry.id, let section = entry.type,
                      ["0", "1", "2"].contains(section),
                      Self.identity(for: getCardEntity(id: cardID)) == identity else { return count }
                return count + (entry.number?.intValue ?? 0)
            }
            guard total < 3 else { return .copyLimit }
            let existing = cards.first { $0.id == id && $0.type == type && $0.version != nil }
            let entry = existing ?? DeckPO(entity: NSEntityDescription.entity(forEntityName: "DeckPO", in: context)!, insertInto: context)
            let previousNumber = entry.number
            entry.id = id
            entry.type = type
            entry.version = "1"
            entry.number = NSNumber(value: (previousNumber?.intValue ?? 0) + 1)
            do { try context.save() }
            catch {
                if existing == nil { context.delete(entry) }
                else { entry.number = previousNumber }
                return .storageFailure
            }
            return .saved
        } catch { return .storageFailure }
    }

    @discardableResult
    func delete(id: String, type: String, all: Bool = false) -> MutationResult {
        do {
            let matching = try entries().filter { $0.id == id && $0.type == type && $0.version != nil }
            guard let entry = matching.first else { return .saved }
            // Keep a zero-count record until persistence succeeds so a failed save can
            // restore the user's count without rolling back unrelated context edits.
            let previousNumber = entry.number
            entry.number = NSNumber(value: all ? 0 : max(0, (entry.number?.intValue ?? 0) - 1))
            do { try context.save() }
            catch { entry.number = previousNumber; return .storageFailure }
            return .saved
        } catch { return .storageFailure }
    }
}

/// An independent count of physical cards. Card IDs are kept distinct and are
/// not subject to deck-building rules or the three-copy limit.
final class PhysicalCardService {
    struct Item {
        let id: String
        let quantity: Int
    }

    struct Quote {
        let tcgplayer: Decimal?
        let cardmarket: Decimal?
        /// Time the snapshot was retrieved, not the original quote time.
        let fetchedAt: Date?
    }

    struct Totals {
        let tcgplayer: Decimal
        let cardmarket: Decimal
        let tcgMissingCount: Int
        let cardmarketMissingCount: Int
        let totalCards: Int
        let earliestFetchedAt: Date?
    }

    private let defaults: UserDefaults
    private let key: String
    private let quoteProvider: (String) -> Quote

    init(defaults: UserDefaults = .standard, key: String = "physicalCardCollection.v1",
         quoteProvider: ((String) -> Quote)? = nil) {
        self.defaults = defaults
        self.key = key
        self.quoteProvider = quoteProvider ?? Self.snapshotQuote
    }

    private func counts() -> [String: Int] {
        (defaults.dictionary(forKey: key) ?? [:]).reduce(into: [:]) { result, pair in
            if let value = pair.value as? Int, value > 0, !pair.key.isEmpty { result[pair.key] = value }
        }
    }

    func list() -> [Item] {
        counts().map { Item(id: $0.key, quantity: $0.value) }.sorted { $0.id > $1.id }
    }

    func count(id: String) -> Int { counts()[id] ?? 0 }

    @discardableResult
    func add(id: String) -> Bool {
        guard !id.isEmpty else { return false }
        var values = counts()
        let current = values[id] ?? 0
        guard current < Int.max else { return false }
        values[id] = current + 1
        defaults.set(values, forKey: key)
        return true
    }

    @discardableResult
    func remove(id: String, all: Bool = false) -> Bool {
        var values = counts()
        guard let current = values[id] else { return true }
        if all || current <= 1 { values.removeValue(forKey: id) }
        else { values[id] = current - 1 }
        defaults.set(values, forKey: key)
        return true
    }

    func quote(id: String) -> Quote { quoteProvider(id) }

    func totals() -> Totals {
        var tcg = Decimal.zero, market = Decimal.zero
        var tcgMissing = 0, marketMissing = 0, total = 0
        var oldest: Date?
        for item in list() {
            let quote = quoteProvider(item.id)
            total += item.quantity
            if let price = quote.tcgplayer { tcg += price * Decimal(item.quantity) }
            else { tcgMissing += item.quantity }
            if let price = quote.cardmarket { market += price * Decimal(item.quantity) }
            else { marketMissing += item.quantity }
            if let date = quote.fetchedAt { oldest = min(oldest ?? date, date) }
        }
        return Totals(tcgplayer: tcg, cardmarket: market, tcgMissingCount: tcgMissing,
                      cardmarketMissingCount: marketMissing, totalCards: total, earliestFetchedAt: oldest)
    }

    private static func snapshotQuote(id: String) -> Quote {
        let unavailable = Quote(tcgplayer: nil, cardmarket: nil, fetchedAt: nil)
        guard let cardID = Int64(id) else { return unavailable }
        do {
            guard let raw = try getDB().scalar("SELECT fetchedAtUtc FROM card_price_sync WHERE cardId = ?", cardID) as? String,
                  let fetchedAt = ISO8601DateFormatter().date(from: raw),
                  let data = getCardEntity(id: id).getCardPrices().data(using: .utf8),
                  let records = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]],
                  let record = records.first else { return unavailable }
            return Quote(tcgplayer: positivePrice(record["tcgplayer_price"]),
                         cardmarket: positivePrice(record["cardmarket_price"]), fetchedAt: fetchedAt)
        } catch { return unavailable }
    }

    private static func positivePrice(_ value: Any?) -> Decimal? {
        let text: String
        if let string = value as? String { text = string }
        else if let number = value as? NSNumber { text = number.stringValue }
        else { return nil }
        guard let price = Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")),
              !price.isNaN, price > .zero else { return nil }
        return price
    }
}
