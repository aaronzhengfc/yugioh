import XCTest
import UIKit
import CoreData
import Vision
import SQLite
@testable import yugioh

class yugiohTests: XCTestCase {
    func testPhysicalScanWithoutJapaneseNameTableStillMatchesExistingNames() throws {
        let olderCatalogue = try Connection(.inMemory)
        let japaneseNames = PhysicalCardScanMatcher.loadJapaneseNames(from: olderCatalogue)
        XCTAssertTrue(japaneseNames.isEmpty)
        let card = CardEntity(); card.id = "89631139"; card.enName = "Blue-Eyes White Dragon"
        let matcher = PhysicalCardScanMatcher(cards: [card], japaneseNames: japaneseNames)
        XCTAssertEqual(matcher.find(lines: ["Blue-Eyes White Dragon"]).first?.card.id, "89631139")
        XCTAssertEqual(matcher.find(lines: ["89631139"]).first?.card.id, "89631139")
    }

    func testPhysicalScanMatchesJapaneseNameAndReadingWithoutLosingVoicing() {
        let blueEyes = CardEntity(); blueEyes.id = "89631139"; blueEyes.enName = "Blue-Eyes White Dragon"
        let plain = CardEntity(); plain.id = "1"; plain.enName = "Unvoiced"
        let voiced = CardEntity(); voiced.id = "2"; voiced.enName = "Voiced"
        let matcher = PhysicalCardScanMatcher(cards: [blueEyes, plain, voiced], japaneseNames: [
            "89631139": ["青眼の白龍", "ブルーアイズ・ホワイト・ドラゴン"],
            "1": ["カカカ"], "2": ["ガガガ"]
        ])
        XCTAssertEqual(matcher.find(lines: ["青眼の白龍"]).map { $0.card.id }, ["89631139"])
        XCTAssertEqual(matcher.find(lines: ["ﾌﾞﾙｰｱｲｽﾞ・ﾎﾜｲﾄ・ﾄﾞﾗｺﾞﾝ"]).map { $0.card.id }, ["89631139"])
        XCTAssertTrue(matcher.find(lines: ["89631139"]).first?.reason.contains("青眼の白龍") == true)
        XCTAssertEqual(matcher.find(lines: ["ガガガ"]).map { $0.card.id }, ["2"])
        XCTAssertEqual(matcher.find(lines: ["ｶｶｶ"]).map { $0.card.id }, ["1"])
        let suggestion = matcher.find(lines: ["青眼の白竜"])
        XCTAssertEqual(suggestion.first?.card.id, "89631139")
        XCTAssertTrue(suggestion.first?.reason.contains("青眼の白龍") == true)
    }

    @MainActor
    func testPhysicalScanAsyncMatchesJapaneseNameInBundledCatalogue() {
        let complete = expectation(description: "Japanese card name is indexed")
        PhysicalCardScanMatcher.matchAsync(lines: ["青眼の白龍"]) { candidates in
            XCTAssertEqual(candidates.first?.card.id, "89631139")
            complete.fulfill()
        }
        wait(for: [complete], timeout: 20)
    }

    @MainActor
    func testPhysicalScanRecognizesSyntheticJapaneseNameWithVision() throws {
        // This exercises real on-device OCR on rendered text. It is not a test
        // of camera optics, reflections or printed card typography.
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        let available = try request.supportedRecognitionLanguages()
        guard available.contains("ja-JP") else { throw XCTSkip("Japanese Vision OCR unavailable on this device") }
        request.recognitionLanguages = ["ja-JP", "zh-Hans", "en-US"].filter { available.contains($0) }
        request.usesLanguageCorrection = false
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1000, height: 500), format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1000, height: 500))
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 100, weight: .bold),
                .foregroundColor: UIColor.black
            ]
            ("青眼の白龍" as NSString).draw(at: CGPoint(x: 100, y: 150), withAttributes: attrs)
        }
        try VNImageRequestHandler(cgImage: try XCTUnwrap(image.cgImage), options: [:]).perform([request])
        let lines = (request.results ?? []).flatMap { $0.topCandidates(2).map(\.string) }
        let card = getCardEntity(id: "89631139")
        let matcher = PhysicalCardScanMatcher(cards: [card], japaneseNames: ["89631139": ["青眼の白龍"]])
        XCTAssertEqual(matcher.find(lines: lines).first?.card.id, "89631139", "OCR lines: \(lines)")
    }

    func testPhysicalScanMatchesCardPasswordSetCodeAndNamesConservatively() {
        func card(_ id: String, _ chinese: String, _ english: String, _ sets: String) -> CardEntity {
            let value = CardEntity()
            value.id = id
            value.cnName = chinese
            value.enName = english
            value.cardSets = sets
            return value
        }
        let blueEyes = card("89631139", "青眼白龙", "Blue-Eyes White Dragon", #"[{"set_code":"SDK-001"}]"#)
        let darkMagician = card("46986414", "黑魔术师", "Dark Magician", #"[{"set_code":"SDY-006"}]"#)
        let shortId = card("176393", "核成衍生物", "Koa'ki Meiru Token", "[]")
        let matcher = PhysicalCardScanMatcher(cards: [darkMagician, blueEyes, shortId])

        XCTAssertEqual(matcher.find(lines: ["89631139"]).map { $0.card.id }, ["89631139"])
        XCTAssertEqual(matcher.find(lines: ["00176393"]).map { $0.card.id }, ["176393"])
        XCTAssertEqual(matcher.find(lines: ["SDK-001"]).map { $0.card.id }, ["89631139"])
        XCTAssertEqual(matcher.find(lines: ["ＳＤＹ－００６"]).map { $0.card.id }, ["46986414"])
        XCTAssertEqual(matcher.find(lines: ["ＢＬＵＥ－ＥＹＥＳ ＷＨＩＴＥ ＤＲＡＧＯＮ"]).map { $0.card.id }, ["89631139"])
        XCTAssertEqual(matcher.find(lines: ["青眼白龙"]).map { $0.card.id }, ["89631139"])
        XCTAssertEqual(matcher.find(lines: ["Blue-Eyes White Drag0n"]).map { $0.card.id }, ["89631139"])
        XCTAssertTrue(matcher.find(lines: ["TSDK-0019", "1896311399"]).isEmpty)
        XCTAssertTrue(matcher.find(lines: ["Dragon"]).isEmpty)
    }

    func testPhysicalScanKeepsAmbiguousVersionMatchesAndRanksPasswordFirst() {
        let first = CardEntity(); first.id = "89631139"; first.enName = "Blue-Eyes White Dragon"
        let second = CardEntity(); second.id = "46986414"; second.enName = "Dark Magician"
        first.cardSets = #"[{"set_code":"TEST-EN001"}]"#
        second.cardSets = first.cardSets
        let result = PhysicalCardScanMatcher(cards: [second, first]).find(lines: ["TEST-EN001", "89631139"])
        XCTAssertEqual(result.map { $0.card.id }, ["89631139", "46986414"])
    }

    func testPhysicalScanMatchesVersionCodeInBundledCatalogue() {
        let card = getCardEntity(id: "89631139")
        let result = PhysicalCardScanMatcher(cards: [card]).find(lines: ["CT13-EN008"])
        XCTAssertEqual(result.first?.card.id, "89631139")
    }

    @MainActor
    func testPhysicalScanRecognizesSyntheticCardTextWithVision() throws {
        // A rendered fixture exercises real Vision OCR and catalogue matching;
        // it does not substitute for tests with photographed physical cards.
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1100, height: 700), format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1100, height: 700))
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 72, weight: .bold),
                .foregroundColor: UIColor.black
            ]
            ("Blue-Eyes White Dragon" as NSString).draw(at: CGPoint(x: 70, y: 120), withAttributes: attrs)
            ("89631139" as NSString).draw(at: CGPoint(x: 70, y: 400), withAttributes: attrs)
        }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: try XCTUnwrap(image.cgImage), options: [:]).perform([request])
        let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        XCTAssertTrue(lines.contains { $0.lowercased().contains("blue-eyes white dragon") }, "OCR lines: \(lines)")
        XCTAssertTrue(lines.contains { $0.contains("89631139") }, "OCR lines: \(lines)")
        let result = PhysicalCardScanMatcher(cards: [getCardEntity(id: "89631139")]).find(lines: lines)
        XCTAssertEqual(result.first?.card.id, "89631139")
    }

    @MainActor
    func testPhysicalScanAsyncMatchesAndReturnsOnMainThread() {
        let complete = expectation(description: "Scan matching finishes")
        PhysicalCardScanMatcher.matchAsync(lines: ["89631139"]) { candidates in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(candidates.first?.card.id, "89631139")
            complete.fulfill()
        }
        wait(for: [complete], timeout: 20)
    }

    func testPhysicalCardsPersistIndependentlyAndValueOnlyKnownPrices() {
        let suite = "physical-card-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let snapshot = Date(timeIntervalSince1970: 1_700_000_000)
        let service = PhysicalCardService(defaults: defaults, key: "collection") { id in
            if id == "1" {
                return PhysicalCardService.Quote(tcgplayer: Decimal(string: "0.10"), cardmarket: nil, fetchedAt: snapshot)
            }
            return PhysicalCardService.Quote(tcgplayer: nil, cardmarket: Decimal(string: "1.25"), fetchedAt: snapshot)
        }
        for _ in 0..<5 { XCTAssertTrue(service.add(id: "1")) }
        XCTAssertTrue(service.add(id: "2"))
        XCTAssertEqual(service.count(id: "1"), 5)
        let totals = service.totals()
        XCTAssertEqual(totals.totalCards, 6)
        XCTAssertEqual(totals.tcgplayer, Decimal(string: "0.50"))
        XCTAssertEqual(totals.cardmarket, Decimal(string: "1.25"))
        XCTAssertEqual(totals.tcgMissingCount, 1)
        XCTAssertEqual(totals.cardmarketMissingCount, 5)
        XCTAssertEqual(totals.earliestFetchedAt, snapshot)

        let reopened = PhysicalCardService(defaults: defaults, key: "collection")
        XCTAssertEqual(reopened.count(id: "1"), 5)
        XCTAssertTrue(reopened.remove(id: "1"))
        XCTAssertEqual(service.count(id: "1"), 4)
        XCTAssertTrue(service.remove(id: "1", all: true))
        XCTAssertEqual(service.count(id: "1"), 0)
        XCTAssertEqual(service.count(id: "2"), 1)
        XCTAssertEqual(PhysicalCardService(defaults: defaults, key: "other").list().count, 0)
    }

    func testLanguageResolution() {
        XCTAssertEqual(AppLanguage.resolve(savedValue: "cn", preferredLanguages: ["en-US"]), .simplifiedChinese)
        XCTAssertEqual(AppLanguage.resolve(savedValue: "en", preferredLanguages: ["zh-Hans-CN"]), .english)
        XCTAssertEqual(AppLanguage.resolve(savedValue: "fr", preferredLanguages: ["zh-Hans-CN", "en"]), .simplifiedChinese)
        XCTAssertEqual(AppLanguage.resolve(savedValue: nil, preferredLanguages: ["fr-FR", "en-GB"]), .english)
        XCTAssertEqual(AppLanguage.resolve(savedValue: nil, preferredLanguages: ["zh-Hant-HK"]), .simplifiedChinese)
        XCTAssertEqual(AppLanguage.resolve(savedValue: nil, preferredLanguages: ["ja-JP"]), .english)
    }

    func testLanguageChangeReloadsDeckTitlesAndKeepsCardData() {
        let previous = language
        let saved = UserDefaults.standard.string(forKey: AppLanguage.preferenceKey)
        defer {
            language = previous
            if let saved = saved { UserDefaults.standard.set(saved, forKey: AppLanguage.preferenceKey) }
            else { UserDefaults.standard.removeObject(forKey: AppLanguage.preferenceKey) }
        }
        language = "en"
        let card = getCardEntity(id: "89631139")
        XCTAssertEqual(card.getName(), "Blue-Eyes White Dragon")
        XCTAssertEqual(card.getAtk(), "3000")
        XCTAssertFalse(card.getDesc().isEmpty)
        XCTAssertEqual(getDeckViewEntity().first?.title, "Favorites")

        language = "cn"
        XCTAssertEqual(card.getName(), "青眼白龙")
        XCTAssertEqual(getDeckViewEntity().first?.title, "我的收藏")
        XCTAssertEqual(UserDefaults.standard.string(forKey: AppLanguage.preferenceKey), "cn")
        language = "fr"
        XCTAssertEqual(language, "cn")
    }

    func testMissingCardTranslationFallsBackWithoutBlankNormalMonsterEffect() {
        let previous = AppLanguage.current
        defer { AppLanguage.current = previous }
        let card = CardEntity()
        card.enName = "English card"
        card.enDesc = "English effect"
        AppLanguage.current = .simplifiedChinese
        XCTAssertEqual(card.getName(), "[待译] English card")
        XCTAssertEqual(card.getDesc(), "[待译] English effect")
        card.enDesc = ""
        XCTAssertEqual(card.getDesc(), "")
        AppLanguage.current = .english
        XCTAssertEqual(card.getName(), "English card")
    }
    func testImportedChineseIsDisplayedAndSearchable() {
        let previous = AppLanguage.current
        defer { AppLanguage.current = previous }
        AppLanguage.current = .simplifiedChinese
        let crocodile = getCardEntity(id: "77699839")
        XCTAssertEqual(crocodile.getName(), "卡骆鳄鱼")
        XCTAssertFalse(crocodile.getDesc().hasPrefix("[待译]"))
        var search = CardSearchCriteria.empty
        search.query = "卡骆鳄鱼"
        XCTAssertEqual(search.filter([crocodile]).first?.id, "77699839")
        XCTAssertEqual(getCardEntity(id: "1528054").getRace(), "幻想魔")
        let token = getCardEntity(id: "176393")
        XCTAssertEqual(token.getName(), "核成衍生物")
        XCTAssertEqual(token.getDesc(), "由「核成试验台」的效果特殊召唤。")
        let skill = getCardEntity(id: "300101002")
        XCTAssertEqual(skill.getName(), "直入墓场")
        XCTAssertTrue(skill.getDesc().contains("恐龙族·不死族·岩石族"))
        let alias = getCardEntity(id: "100420006")
        XCTAssertEqual(alias.getName(), "异度归零地")
        XCTAssertTrue(alias.getDesc().hasPrefix("[AI译]"))
    }

    func testAITranslationIsMarkedAndSearchableWithoutAffectingEnglish() {
        let previous = AppLanguage.current
        defer { AppLanguage.current = previous }
        let card = getCardEntity(id: "100420016")
        AppLanguage.current = .simplifiedChinese
        XCTAssertTrue(card.getName().hasPrefix("[AI译] "))
        XCTAssertTrue(card.getDesc().hasPrefix("[AI译] "))
        var search = CardSearchCriteria.empty
        search.query = "征服之魂 螺禅"
        XCTAssertEqual(search.filter([card]).first?.id, card.id)
        AppLanguage.current = .english
        XCTAssertEqual(card.getName(), "Vanquish Soul - Razen")
        XCTAssertFalse(card.getDesc().hasPrefix("[AI译] "))
    }

    @MainActor
    func testStoryboardsRefreshBothLanguagesAndCalculatorActions() {
        let previous = language
        let saved = UserDefaults.standard.string(forKey: AppLanguage.preferenceKey)
        defer {
            language = previous
            if let saved = saved { UserDefaults.standard.set(saved, forKey: AppLanguage.preferenceKey) }
            else { UserDefaults.standard.removeObject(forKey: AppLanguage.preferenceKey) }
        }
        for selected in ["en", "cn"] {
            language = selected
            let navigation = UIStoryboard(name: "Main", bundle: nil).instantiateInitialViewController() as! UINavigationController
            let root = navigation.viewControllers[0] as! ViewController
            root.loadViewIfNeeded()
            XCTAssertEqual(root.viewControllers?[0].tabBarItem.title, selected == "en" ? "Cards" : "卡牌")
            XCTAssertEqual(root.packButton.title, selected == "en" ? "Search" : "搜索")
            let tools = root.viewControllers![2] as! ToolViewController
            tools.loadViewIfNeeded()
            XCTAssertEqual(tools.segmentedControl.titleForSegment(at: 0), selected == "en" ? "Life Points" : "计分器")
            func buttons(in view: UIView) -> [DataButton] {
                return (view as? DataButton).map { [$0] } ?? view.subviews.flatMap { buttons(in: $0) }
            }
            let half = buttons(in: tools.calculateView).first { $0.data == "halve" && $0.index == 0 }!
            half.sendActions(for: .touchUpInside)
            XCTAssertEqual(tools.calculateView.scoreLableOne.text, "4000")
        }
    }

    func testCardSearchMatchesKeywordsAcrossLanguagesAndCardFields() {
        let cards = [getCardEntity(id: "89631139"), getCardEntity(id: "46986414"), getCardEntity(id: "53129443")]
        var criteria = CardSearchCriteria.empty
        criteria.query = "WHITE 89631139"
        XCTAssertEqual(criteria.filter(cards).map { $0.id }, ["89631139"])
        criteria.query = "青眼白龙"
        XCTAssertEqual(criteria.filter(cards).map { $0.id }, ["89631139"])
        criteria.query = "ultimate wizard"
        XCTAssertEqual(criteria.filter(cards).map { $0.id }, ["46986414"])
        criteria.query = "white wizard"
        XCTAssertTrue(criteria.filter(cards).isEmpty, "All query words must match the same card")
    }

    func testCardSearchCombinesConditionsAndUsesOrWithinEachGroup() {
        let previous = AppLanguage.current
        defer { AppLanguage.current = previous }
        AppLanguage.current = .english
        let cards = [getCardEntity(id: "89631139"), getCardEntity(id: "46986414"), getCardEntity(id: "53129443")]
        var criteria = CardSearchCriteria.empty
        criteria.selections = [["Normal Monster"], ["LIGHT", "DARK"], ["Dragon"]]
        XCTAssertFalse(criteria.isEmpty)
        XCTAssertEqual(criteria.filter(cards).map { $0.id }, ["89631139"])
        criteria.selections[2] = ["Dragon", "Spellcaster"]
        XCTAssertEqual(criteria.filter(cards).map { $0.id }, ["89631139", "46986414"])
        criteria.query = "magician"
        XCTAssertEqual(criteria.filter(cards).map { $0.id }, ["46986414"])
        criteria.selections[1] = ["LIGHT"]
        XCTAssertTrue(criteria.filter(cards).isEmpty, "Filter groups and query must all match")
    }

    func testCardSearchNumericRangesAndEmptyConditions() {
        let cards = [getCardEntity(id: "89631139"), getCardEntity(id: "46986414"), getCardEntity(id: "53129443")]
        var criteria = CardSearchCriteria.empty
        criteria.query = "  \n "
        XCTAssertTrue(criteria.isEmpty)
        XCTAssertEqual(criteria.filter(cards).map { $0.id }, cards.map { $0.id }, "Empty ranges include cards without stats")
        criteria.ranges = [(3000, 3000), (2500, 2500), (8, 8)]
        XCTAssertFalse(criteria.isEmpty)
        XCTAssertEqual(criteria.filter(cards).map { $0.id }, ["89631139"], "Range endpoints are inclusive")
        criteria.ranges = [(0, 10000), (0, 10000), (7, 7)]
        XCTAssertEqual(criteria.filter(cards).map { $0.id }, ["46986414"], "Cards without a numeric level cannot match an active level range")
    }

    @MainActor
    private func makeDeckService() throws -> DeckService {
        let model = try XCTUnwrap(NSManagedObjectModel.mergedModel(from: [Bundle(for: DeckPO.self)]))
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        try coordinator.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil, options: nil)
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        return DeckService(context: context)
    }

    @MainActor
    func testDeckCopiesAreLimitedAcrossMainAndSide() throws {
        let service = try makeDeckService()
        let card = getCardEntity(id: "89631139")
        XCTAssertEqual(card.enName, "Blue-Eyes White Dragon")
        XCTAssertEqual(service.save(id: card.id, type: "0"), .saved)
        XCTAssertEqual(service.save(id: card.id, type: "0"), .saved)
        XCTAssertEqual(service.save(id: card.id, type: "1"), .saved)
        XCTAssertEqual(service.save(id: card.id, type: "1"), .copyLimit)
        XCTAssertEqual(service.count(of: card), 3)
        XCTAssertEqual(service.count(of: card, in: "0"), 2)
        XCTAssertEqual(service.count(of: card, in: "1"), 1)
    }

    @MainActor
    func testDeckValidatesMainAndExtraSections() throws {
        let service = try makeDeckService()
        let normal = getCardEntity(id: "89631139")
        let fusion = getCardEntity(id: "23995346")
        XCTAssertEqual(fusion.enName, "Blue-Eyes Ultimate Dragon")
        XCTAssertEqual(service.save(id: normal.id, type: "2"), .invalidSection)
        XCTAssertEqual(service.save(id: fusion.id, type: "0"), .invalidSection)
        XCTAssertEqual(service.save(id: fusion.id, type: "2"), .saved)
        XCTAssertEqual(service.save(id: fusion.id, type: "1"), .saved)
        XCTAssertEqual(service.save(id: normal.id, type: "0"), .saved)
        XCTAssertEqual(service.save(id: normal.id, type: "invalid"), .invalidSection)
        XCTAssertEqual(service.list()["0"]?.count, 1)
        XCTAssertEqual(service.list()["2"]?.count, 1)
    }

    @MainActor
    func testDeckCanRemoveLastCopyAndAddItAgain() throws {
        let service = try makeDeckService()
        let card = getCardEntity(id: "89631139")
        XCTAssertEqual(service.save(id: card.id, type: "0"), .saved)
        XCTAssertEqual(service.delete(id: card.id, type: "0"), .saved)
        XCTAssertEqual(service.count(of: card), 0)
        XCTAssertTrue(service.list()["0"]!.isEmpty)
        XCTAssertEqual(service.save(id: card.id, type: "0"), .saved)
        XCTAssertEqual(service.count(of: card), 1)
        XCTAssertEqual(service.list()["0"]?.count, 1)
        XCTAssertEqual(service.save(id: card.id, type: "0"), .saved)
        XCTAssertEqual(service.delete(id: card.id, type: "0", all: true), .saved)
        XCTAssertEqual(service.count(of: card), 0)
        XCTAssertTrue(service.list()["0"]!.isEmpty)
    }

    @MainActor
    func testAlternateArtworkSharesTheThreeCopyLimit() throws {
        let service = try makeDeckService()
        let original = getCardEntity(id: "23995346")
        let alternate = getCardEntity(id: "23995348")
        XCTAssertEqual(original.enName, "Blue-Eyes Ultimate Dragon")
        XCTAssertEqual(alternate.enName, original.enName)
        XCTAssertNotEqual(original.id, alternate.id)
        XCTAssertEqual(service.save(id: original.id, type: "2"), .saved)
        XCTAssertEqual(service.save(id: original.id, type: "2"), .saved)
        XCTAssertEqual(service.save(id: alternate.id, type: "1"), .saved)
        XCTAssertEqual(service.save(id: alternate.id, type: "2"), .copyLimit)
        XCTAssertEqual(service.count(of: original), 3)
        XCTAssertEqual(service.count(of: alternate), 3)
        XCTAssertEqual(service.delete(id: original.id, type: "2"), .saved)
        XCTAssertEqual(service.save(id: alternate.id, type: "2"), .saved)
        XCTAssertEqual(service.count(of: original), 3)
    }

    @MainActor
    func testOldBetaPasswordSharesTheCurrentCardsCopyLimit() throws {
        let service = try makeDeckService()
        let current = getCardEntity(id: "29302858")
        let beta = getCardEntity(id: "100420016")
        XCTAssertEqual(current.enName, "Vanquish Soul Razen")
        XCTAssertFalse(beta.enName.isEmpty)
        XCTAssertNotEqual(current.enName, beta.enName)
        XCTAssertEqual(DeckService.identity(for: current), DeckService.identity(for: beta))
        XCTAssertEqual(service.save(id: current.id, type: "0"), .saved)
        XCTAssertEqual(service.save(id: current.id, type: "0"), .saved)
        XCTAssertEqual(service.save(id: beta.id, type: "1"), .saved)
        XCTAssertEqual(service.save(id: beta.id, type: "0"), .copyLimit)
        XCTAssertEqual(service.count(of: current), 3)
        XCTAssertEqual(service.count(of: beta), 3)
    }

    @MainActor
    func testFavoritesBackgroundMatchesItsListInLightAndDarkMode() throws {
        let controller = CardViewWithStarController()
        controller.loadViewIfNeeded()
        let background = try XCTUnwrap(controller.view.backgroundColor)
        let listBackground = try XCTUnwrap(controller.iTableView.backgroundColor)
        for style in [UIUserInterfaceStyle.light, .dark] {
            let traits = UITraitCollection(userInterfaceStyle: style)
            XCTAssertEqual(background.resolvedColor(with: traits), listBackground.resolvedColor(with: traits))
            XCTAssertEqual(background.resolvedColor(with: traits), UIColor.systemGroupedBackground.resolvedColor(with: traits))
        }
    }
}
