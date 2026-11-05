import XCTest

class yugiohUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testLanguageSwitchPersistsAndUpdatesScreens() {
        let app = XCUIApplication()
        // An unsupported saved value must fall back to the system language.
        app.launchArguments = ["-appLanguage", "removed-language", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.navigationBars.buttons["languageButton"].firstMatch.waitForExistence(timeout: 15))
        XCTAssertEqual(app.buttons["cardsTab"].firstMatch.label, "Cards")
        app.navigationBars.buttons["languageButton"].firstMatch.tap()
        XCTAssertTrue(app.buttons["English"].firstMatch.exists)
        XCTAssertTrue(app.buttons["简体中文"].firstMatch.exists)
        XCTAssertFalse(app.buttons["Français"].firstMatch.exists)
        XCTAssertFalse(app.buttons["Italian"].firstMatch.exists)
        XCTAssertFalse(app.buttons["Português"].firstMatch.exists)
        app.buttons["简体中文"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars.buttons["搜索"].firstMatch.waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons["cardsTab"].firstMatch.label, "卡牌")
        app.buttons["decksTab"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["我的收藏"].firstMatch.exists)

        app.terminate()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.navigationBars.buttons["搜索"].firstMatch.waitForExistence(timeout: 15))
        XCTAssertEqual(app.buttons["cardsTab"].firstMatch.label, "卡牌")
        app.navigationBars.buttons["languageButton"].firstMatch.tap()
        app.buttons["English"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars.buttons["Search"].firstMatch.waitForExistence(timeout: 10))
        app.buttons["decksTab"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Favorites"].firstMatch.exists)
        app.buttons["toolsTab"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Life Points"].firstMatch.exists)
        app.buttons["Player 1, Half"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["4000"].firstMatch.exists)
        app.buttons["Draw Test"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Shuffle"].firstMatch.exists)
        app.buttons["About"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Card Guide"].firstMatch.exists)
        app.buttons["cardsTab"].firstMatch.tap()
        app.navigationBars.buttons["Search"].firstMatch.tap()
        XCTAssertTrue(app.textFields["Search name, effect or ID"].firstMatch.exists)
        XCTAssertTrue(app.buttons["Cancel"].firstMatch.exists)
    }
}
