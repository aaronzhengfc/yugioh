import XCTest
import UIKit
import CoreData
@testable import yugioh

class yugiohTests: XCTestCase {
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

}
