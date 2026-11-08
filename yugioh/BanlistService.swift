import Foundation
import UIKit

enum CardFormat: String, CaseIterable {
    case ocg = "OCG"
    case tcg = "TCG"

    static var current: CardFormat {
        get { CardFormat(rawValue: UserDefaults.standard.string(forKey: "cardFormat") ?? "") ?? .ocg }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "cardFormat") }
    }
}

enum CardRestriction: Int, CaseIterable {
    case forbidden = 0, limited = 1, semiLimited = 2, unlimited = 3

    var title: String {
        switch self {
        case .forbidden: return L10n.text("禁止", "Forbidden")
        case .limited: return L10n.text("限 1 张", "Limited 1")
        case .semiLimited: return L10n.text("限 2 张", "Limited 2")
        case .unlimited: return L10n.text("不限制", "Unlimited")
        }
    }

    var color: UIColor {
        switch self {
        case .forbidden: return .systemRed
        case .limited: return .systemOrange
        case .semiLimited: return .systemBlue
        case .unlimited: return .secondaryLabel
        }
    }
}

struct BanlistRelease {
    let id: String
    let format: CardFormat
    let effectiveDate: String
    let sourceURL: String
    let title: String
    let isComplete: Bool
}

/// A release is a complete snapshot, not a set of changes. Absence means unlimited
/// only after a complete snapshot has been loaded successfully.
final class BanlistService {
    static let shared = BanlistService()
    private(set) var releases: [BanlistRelease] = []
    private var entries: [String: [String: CardRestriction]] = [:]
    private var names: [String: String] = [:]
    private var IDsByName: [String: [String]] = [:]
    private var canonicalIDs: [String: String] = [:]
    private var latestCache: [CardFormat: (day: String, release: BanlistRelease?)] = [:]
    private let loadsFromDatabase: Bool
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    init(releases: [BanlistRelease], entries: [String: [String: CardRestriction]], names: [String: String] = [:]) {
        loadsFromDatabase = false
        self.releases = releases
        self.entries = entries
        self.names = names
        for (id, name) in names { IDsByName[name, default: []].append(id) }
    }

    init() {
        loadsFromDatabase = true
        do {
            let database = getDB()
            let exists = try database.scalar("SELECT count(*) FROM sqlite_master WHERE type='table' AND name='banlist_release'") as? Int64 ?? 0
            guard exists > 0 else { return }
            for row in try database.prepare("SELECT id,format,effectiveDate,sourceURL,title,isComplete FROM banlist_release ORDER BY effectiveDate DESC,format") {
                guard let id = row[0] as? String, let rawFormat = row[1] as? String,
                      let format = CardFormat(rawValue: rawFormat), let date = row[2] as? String else { continue }
                releases.append(BanlistRelease(id: id, format: format, effectiveDate: date,
                    sourceURL: row[3] as? String ?? "", title: row[4] as? String ?? "",
                    isComplete: (row[5] as? Int64) == 1))
            }
            for row in try database.prepare("SELECT id,enName FROM newpro") {
                guard let id = row[0] as? Int64, let name = row[1] as? String, !name.isEmpty else { continue }
                names[String(id)] = name
                IDsByName[name, default: []].append(String(id))
            }
            let hasAliases = try database.scalar("SELECT count(*) FROM sqlite_master WHERE type='table' AND name='banlist_card_alias'") as? Int64 ?? 0
            if hasAliases > 0 {
                for row in try database.prepare("SELECT cardId,rootCardId FROM banlist_card_alias") {
                    if let id = row[0] as? String, let root = row[1] as? String { canonicalIDs[id] = root }
                }
            }
        } catch { print("Unable to load banlist releases: \(error.localizedDescription)") }
    }

    static var today: String {
        dayFormatter.string(from: Date())
    }

    static func latest(in releases: [BanlistRelease], format: CardFormat, on date: String) -> BanlistRelease? {
        releases.filter { $0.format == format && $0.isComplete && $0.effectiveDate <= date }
            .max { $0.effectiveDate < $1.effectiveDate }
    }

    func latest(for format: CardFormat = .current, on day: String = BanlistService.today) -> BanlistRelease? {
        if let cached = latestCache[format], cached.day == day { return cached.release }
        let release = Self.latest(in: releases, format: format, on: day)
        latestCache[format] = (day, release)
        return release
    }

    func canonicalID(for cardID: String) -> String {
        canonicalIDs[cardID] ?? names[cardID].flatMap { IDsByName[$0]?.min() } ?? cardID
    }

    func cards(in release: BanlistRelease) -> [String: CardRestriction]? {
        if let cached = entries[release.id] { return cached }
        guard loadsFromDatabase else { return nil }
        do {
            var values: [String: CardRestriction] = [:]
            for row in try getDB().prepare("SELECT cardId,limitCount FROM banlist_entry WHERE releaseId = ?", release.id) {
                guard let id = row[0] as? String, let count = row[1] as? Int64,
                      let restriction = CardRestriction(rawValue: Int(count)) else { return nil }
                values[id] = restriction
            }
            entries[release.id] = values
            return values
        } catch { print("Unable to load banlist entries: \(error.localizedDescription)"); return nil }
    }

    func restriction(for cardID: String, in release: BanlistRelease? = nil, format: CardFormat = .current) -> CardRestriction? {
        guard let release = release ?? latest(for: format), let values = cards(in: release) else { return nil }
        // Different artwork passwords for the same named card share its restriction.
        let aliases = names[cardID].flatMap { IDsByName[$0] } ?? [cardID]
        if let count = aliases.compactMap({ values[$0]?.rawValue }).min() {
            return CardRestriction(rawValue: count)
        }
        return release.isComplete ? .unlimited : nil
    }

    func restriction(for cardID: String, format: CardFormat, asOf archive: BanlistRelease?) -> CardRestriction? {
        guard let archive = archive else { return restriction(for: cardID, format: format) }
        if archive.format == format { return restriction(for: cardID, in: archive) }
        guard let other = latest(for: format, on: archive.effectiveDate) else { return nil }
        return restriction(for: cardID, in: other)
    }

    /// Changes in the available snapshots, newest first. An unknown status breaks
    /// the known sequence: the next known status is shown without assuming what
    /// happened during the gap. A card never listed in a complete snapshot starts
    /// unrestricted, so that initial baseline is not itself a history event.
    func history(for cardID: String, format: CardFormat) -> [(release: BanlistRelease, restriction: CardRestriction?)] {
        let snapshots = releases.filter { $0.format == format }.sorted {
            if $0.effectiveDate != $1.effectiveDate { return $0.effectiveDate < $1.effectiveDate }
            return $0.id < $1.id
        }
        var result: [(release: BanlistRelease, restriction: CardRestriction?)] = []
        var previous: CardRestriction?
        var hasPrevious = false
        for release in snapshots {
            let current = restriction(for: cardID, in: release)
            if !hasPrevious {
                if current != .unlimited { result.append((release, current)) }
                hasPrevious = true
            } else if current != previous {
                result.append((release, current))
            }
            previous = current
        }
        return Array(result.reversed())
    }

    func label(for cardID: String, in release: BanlistRelease? = nil, format: CardFormat = .current) -> String {
        let selected = release?.format ?? format
        let status = restriction(for: cardID, in: release, format: selected)?.title ?? L10n.text("待更新", "Unknown")
        return selected.rawValue + " · " + status
    }
}
