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
