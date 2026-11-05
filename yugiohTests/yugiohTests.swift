import XCTest
import UIKit
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

}
