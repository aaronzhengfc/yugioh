import XCTest
@testable import yugioh

final class BanlistTests: XCTestCase {
    func testCardSearchSnapshotPreservesCrossFieldMatchingAndValues() {
        let card = CardEntity()
        card.id = "89631139"
        card.enName = "Blue-Eyes White Dragon"
        card.cnName = "青眼白龙"
        card.enDesc = "A legendary dragon with immense power."
        card.cnDesc = "传说中的龙。"
        card.atk = "3000"
        var criteria = CardSearchCriteria.empty
        criteria.query = "white legendary"
        criteria.ranges[0] = (3000, 3000)
        let documents = criteria.documents(for: [card])

        // A background search must use the values captured before later edits.
        card.enName = "Changed"
        card.enDesc = "Changed"
        card.atk = "1000"
        XCTAssertEqual(criteria.matchingIndices(in: documents), [0])
        XCTAssertTrue(criteria.filter([card]).isEmpty)

        criteria.query = "white missing"
        XCTAssertTrue(criteria.matchingIndices(in: documents).isEmpty)
        criteria.query = ""
        XCTAssertEqual(criteria.matchingIndices(in: documents), [0], "Range-only searches do not require text")
    }
    private func release(_ id: String, _ format: CardFormat, _ date: String, complete: Bool = true) -> BanlistRelease {
        BanlistRelease(id: id, format: format, effectiveDate: date, sourceURL: "", title: id, isComplete: complete)
    }

    func testLatestUsesFormatEffectiveDateAndCompleteness() {
        let lists = [release("old", .ocg, "2026-07-01"), release("current", .ocg, "2026-10-01"),
                     release("future", .ocg, "2027-01-01"), release("tcg", .tcg, "2026-10-19"),
                     release("incomplete", .ocg, "2026-11-01", complete: false)]
        XCTAssertEqual(BanlistService.latest(in: lists, format: .ocg, on: "2026-11-05")?.id, "current")
        XCTAssertEqual(BanlistService.latest(in: lists, format: .tcg, on: "2026-11-05")?.id, "tcg")
        XCTAssertEqual(BanlistService.latest(in: lists, format: .ocg, on: "2027-01-01")?.id, "future")
        XCTAssertNil(BanlistService.latest(in: lists, format: .ocg, on: "2026-06-30"))
    }

    func testSeparateFormatsAndSemiLimitedAreNotConflated() {
        let ocg = release("ocg", .ocg, "2026-10-01")
        let tcg = release("tcg", .tcg, "2026-10-19")
        let service = BanlistService(releases: [ocg, tcg], entries: ["ocg": ["100": .semiLimited], "tcg": ["100": .forbidden]])
        XCTAssertEqual(service.restriction(for: "100", in: ocg), .semiLimited)
        XCTAssertEqual(service.restriction(for: "100", in: tcg), .forbidden)
        XCTAssertEqual(service.restriction(for: "200", in: ocg), .unlimited)
    }

    func testMissingOrIncompleteDataDoesNotClaimUnlimited() {
        let partial = release("partial", .ocg, "2026-10-01", complete: false)
        let service = BanlistService(releases: [partial], entries: ["partial": ["100": .limited]])
        XCTAssertEqual(service.restriction(for: "100", in: partial), .limited)
        XCTAssertNil(service.restriction(for: "200", in: partial))
        XCTAssertNil(service.restriction(for: "100"))
    }

    func testArchiveComparesFormatsAsOfSelectedRelease() {
        let early = release("early", .ocg, "2011-01-01")
        let tcg = release("tcg", .tcg, "2013-01-01")
        let ocg = release("ocg", .ocg, "2014-01-01")
        let later = release("later", .tcg, "2015-01-01")
        let service = BanlistService(releases: [early, tcg, ocg, later], entries: [
            "early": [:], "tcg": ["100": .semiLimited], "ocg": ["100": .forbidden], "later": [:]
        ])
        XCTAssertNil(service.restriction(for: "100", format: .tcg, asOf: early))
        XCTAssertEqual(service.restriction(for: "100", format: .tcg, asOf: ocg), .semiLimited)
        XCTAssertEqual(service.restriction(for: "100", format: .ocg, asOf: ocg), .forbidden)
        XCTAssertEqual(service.restriction(for: "100", format: .ocg, asOf: tcg), .unlimited)
    }

    func testArtworkAliasesShareRestrictionAndHistoryStaysIndependent() {
        let old = release("old", .ocg, "2026-07-01")
        let new = release("new", .ocg, "2026-10-01")
        let service = BanlistService(releases: [old, new], entries: ["old": ["100": .forbidden], "new": [:]],
                                     names: ["100": "Same Card", "101": "Same Card"])
        XCTAssertEqual(service.restriction(for: "101", in: old), .forbidden)
        XCTAssertEqual(service.restriction(for: "101", in: new), .unlimited)
    }

    func testHistoryReportsChangesAndRemovalSeparatelyForEachFormat() {
        let baseline = release("baseline", .ocg, "2020-01-01")
        let forbidden = release("forbidden", .ocg, "2020-04-01")
        let unchanged = release("unchanged", .ocg, "2020-07-01")
        let limited = release("limited", .ocg, "2020-10-01")
        let removed = release("removed", .ocg, "2021-01-01")
        let tcg = release("tcg", .tcg, "2020-05-01")
        let service = BanlistService(releases: [removed, tcg, unchanged, baseline, limited, forbidden], entries: [
            "baseline": [:], "forbidden": ["100": .forbidden], "unchanged": ["100": .forbidden],
            "limited": ["100": .limited], "removed": [:], "tcg": ["100": .semiLimited]
        ], names: ["100": "Same Card", "101": "Same Card"])

        let ocgHistory = service.history(for: "101", format: .ocg)
        XCTAssertEqual(ocgHistory.map { $0.release.id }, ["removed", "limited", "forbidden"])
        XCTAssertEqual(ocgHistory.map { $0.restriction }, [.unlimited, .limited, .forbidden])
        let tcgHistory = service.history(for: "101", format: .tcg)
        XCTAssertEqual(tcgHistory.map { $0.release.id }, ["tcg"])
        XCTAssertEqual(tcgHistory.map { $0.restriction }, [.semiLimited])
    }

    func testHistoryPreservesUnknownGapsAndOnlyTreatsCompleteAbsenceAsUnlimited() {
        let forbidden = release("forbidden", .ocg, "2020-01-01")
        let partial = release("partial", .ocg, "2020-04-01", complete: false)
        let missing = release("missing", .ocg, "2020-07-01")
        let known = release("known", .ocg, "2020-10-01")
        let partialListed = release("partial-listed", .ocg, "2021-01-01", complete: false)
        let service = BanlistService(releases: [forbidden, partial, missing, known, partialListed], entries: [
            "forbidden": ["100": .forbidden], "partial": [:], "known": [:],
            "partial-listed": ["100": .limited]
        ])

        let history = service.history(for: "100", format: .ocg)
        XCTAssertEqual(history.map { $0.release.id }, ["partial-listed", "known", "partial", "forbidden"])
        XCTAssertEqual(history.map { $0.restriction }, [.limited, .unlimited, nil, .forbidden])
        XCTAssertNil(service.restriction(for: "100", in: missing))
    }

    func testIndexedHistoryMatchesSnapshotRestrictionsForRealCards() {
        let service = BanlistService()
        // Include a card with many historical entries, an artwork alias, and a
        // card without restrictions; compare the indexed path with the full
        // snapshot logic for both formats.
        for id in ["15341821", "100200234", "89631139"] {
            for format in CardFormat.allCases {
                let snapshots = service.releases.filter { $0.format == format }.sorted {
                    if $0.effectiveDate != $1.effectiveDate { return $0.effectiveDate < $1.effectiveDate }
                    return $0.id < $1.id
                }
                var expected: [(String, CardRestriction?)] = []
                var previous: CardRestriction?
                var hasPrevious = false
                for release in snapshots {
                    let current = service.restriction(for: id, in: release)
                    if !hasPrevious {
                        if current != .unlimited { expected.append((release.id, current)) }
                        hasPrevious = true
                    } else if current != previous {
                        expected.append((release.id, current))
                    }
                    previous = current
                }
                let actual = service.history(for: id, format: format)
                XCTAssertEqual(actual.map { $0.release.id }, expected.reversed().map { $0.0 })
                XCTAssertEqual(actual.map { $0.restriction }, expected.reversed().map { $0.1 })
            }
        }
    }
}
