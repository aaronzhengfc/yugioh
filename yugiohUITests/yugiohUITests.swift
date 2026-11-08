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
        XCTAssertTrue(app.navigationBars.firstMatch.buttons["languageButton"].firstMatch.waitForExistence(timeout: 15))
        XCTAssertEqual(app.buttons["cardsTab"].firstMatch.label, "Cards")
        app.navigationBars.firstMatch.buttons["languageButton"].firstMatch.tap()
        XCTAssertTrue(app.buttons["English"].firstMatch.exists)
        XCTAssertTrue(app.buttons["简体中文"].firstMatch.exists)
        XCTAssertFalse(app.buttons["Français"].firstMatch.exists)
        XCTAssertFalse(app.buttons["Italian"].firstMatch.exists)
        XCTAssertFalse(app.buttons["Português"].firstMatch.exists)
        app.buttons["简体中文"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars.firstMatch.buttons["搜索"].firstMatch.waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons["cardsTab"].firstMatch.label, "卡牌")
        app.buttons["decksTab"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["我的收藏"].firstMatch.exists)

        app.terminate()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.navigationBars.firstMatch.buttons["搜索"].firstMatch.waitForExistence(timeout: 15))
        XCTAssertEqual(app.buttons["cardsTab"].firstMatch.label, "卡牌")
        app.navigationBars.firstMatch.buttons["languageButton"].firstMatch.tap()
        app.buttons["English"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars.firstMatch.buttons["Search"].firstMatch.waitForExistence(timeout: 10))
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
        app.navigationBars.firstMatch.buttons["Search"].firstMatch.tap()
        XCTAssertTrue(app.searchFields["cardSearchField"].firstMatch.exists)
        app.buttons["cardSearchCancel"].firstMatch.tap()
        XCTAssertTrue(app.buttons["cardsTab"].firstMatch.waitForExistence(timeout: 5))
    }

    func testSearchSheetAppliesFiltersToCurrentListAndClearRestoresAllCards() {
        let app = launchInEnglish()
        let results = app.tables["cardSearchResults"].firstMatch
        XCTAssertTrue(results.cells.firstMatch.waitForExistence(timeout: 5))
        app.navigationBars.firstMatch.buttons["Search"].firstMatch.tap()
        let sheet = app.descendants(matching: .any)["cardSearchSheet"].firstMatch
        let field = app.searchFields["cardSearchField"].firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 5))
        XCTAssertTrue(field.exists)
        XCTAssertGreaterThan(sheet.frame.height, app.frame.height * 0.8,
                             "The search sheet should open at its largest size")
        captureScreenshot(app, name: "Search — fully expanded on opening")
        // All condition groups must remain reachable by scrolling on small screens.
        let conditions = app.scrollViews["cardSearchConditions"].firstMatch
        XCTAssertTrue(conditions.exists)
        let light = app.buttons["LIGHT"].firstMatch
        for _ in 0..<5 where !light.isHittable { conditions.swipeUp() }
        XCTAssertTrue(light.isHittable)
        light.tap()
        let raceHeading = app.staticTexts["Race"].firstMatch
        for _ in 0..<8 where !raceHeading.isHittable { conditions.swipeUp() }
        XCTAssertTrue(raceHeading.isHittable, "The expanded sheet must reach the final filter group")
        field.tap()
        field.typeText("89631139")
        app.buttons["cardSearchSubmit"].firstMatch.tap()
        XCTAssertFalse(field.waitForExistence(timeout: 2))
        let blueEyes = results.cells.containing(.staticText, identifier: "89631139").firstMatch
        XCTAssertTrue(blueEyes.waitForExistence(timeout: 5))
        let resultCount = app.staticTexts["cardSearchResultCount"].firstMatch
        let clearSearch = app.buttons["clearCardSearch"].firstMatch
        XCTAssertTrue(resultCount.exists && clearSearch.exists)
        XCTAssertEqual(resultCount.frame.midY, clearSearch.frame.midY, accuracy: 4,
                       "The result count and clear action should share a visual center")
        XCTAssertLessThan(resultCount.frame.maxX, clearSearch.frame.minX,
                          "The result count and clear action must not overlap")
        captureScreenshot(app, name: "Search results — aligned clear action")

        // Reopening preserves applied conditions; cancelling an edit preserves the results.
        app.navigationBars.firstMatch.buttons["Search"].firstMatch.tap()
        XCTAssertEqual(field.value as? String, "89631139")
        replaceText(in: field, with: "discarded edit")
        app.buttons["cardSearchCancel"].firstMatch.tap()
        XCTAssertTrue(blueEyes.waitForExistence(timeout: 5))

        app.navigationBars.firstMatch.buttons["Search"].firstMatch.tap()
        XCTAssertEqual(field.value as? String, "89631139")
        replaceText(in: field, with: "no-card-matches-this-query-xyz")
        app.buttons["cardSearchSubmit"].firstMatch.tap()
        XCTAssertTrue(results.staticTexts["cardSearchEmptyState"].firstMatch.waitForExistence(timeout: 5))
        app.buttons["clearCardSearch"].firstMatch.tap()
        XCTAssertTrue(results.cells.firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["clearCardSearch"].firstMatch.exists)
        app.navigationBars.firstMatch.buttons["Search"].firstMatch.tap()
        XCTAssertTrue((field.value as? String ?? "").isEmpty)
        app.buttons["cardSearchCancel"].firstMatch.tap()
    }

    func testBothFormatsAndHistoryStayIndependent() {
        let app = launchInEnglish()
        XCTAssertFalse(app.buttons["OCG"].firstMatch.exists)
        XCTAssertFalse(app.buttons["TCG"].firstMatch.exists)
        let firstCard = app.tables.firstMatch.cells.firstMatch
        XCTAssertTrue(firstCard.waitForExistence(timeout: 5))
        XCTAssertEqual(firstCard.staticTexts["restrictionOCG"].firstMatch.label, "OCG · Unlimited")
        XCTAssertEqual(firstCard.staticTexts["restrictionTCG"].firstMatch.label, "TCG · Unlimited")
        assertCardMetadataFitsOneRow(in: firstCard, screen: app.frame)
        captureScreenshot(app, name: "Cards — both current formats")

        // Maxx C has different restrictions in the two bundled current lists.
        app.navigationBars.firstMatch.buttons["Search"].firstMatch.tap()
        app.searchFields["cardSearchField"].firstMatch.tap()
        app.searchFields["cardSearchField"].firstMatch.typeText("23434538\n")
        let card = app.tables.firstMatch.cells.containing(.staticText, identifier: "23434538").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertEqual(card.staticTexts["restrictionOCG"].firstMatch.label, "OCG · Limited 1")
        XCTAssertEqual(card.staticTexts["restrictionTCG"].firstMatch.label, "TCG · Forbidden")
        let favoriteLabels = NSPredicate(format: "label IN %@", ["Favorite card", "Remove from favorites"])
        let listStar = card.buttons.matching(favoriteLabels).firstMatch
        XCTAssertTrue(listStar.exists)
        let originalListLabel = listStar.label
        let originallyFavorite = originalListLabel == "Remove from favorites"
        captureScreenshot(app, name: "Card list — different OCG and TCG limits")
        card.tap()
        XCTAssertTrue(app.navigationBars["Card Details"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["restrictionOCG"].firstMatch.label, "OCG · Limited 1")
        XCTAssertEqual(app.staticTexts["restrictionTCG"].firstMatch.label, "TCG · Forbidden")
        assertCardMetadataFitsOneRow(in: app, screen: app.frame, expectedID: "23434538")
        captureScreenshot(app, name: "Card details — both current formats")

        let detailStar = app.buttons["detailFavoriteStar"].firstMatch
        XCTAssertTrue(detailStar.isHittable)
        XCTAssertGreaterThan(detailStar.frame.midX, app.frame.midX)
        XCTAssertLessThan(detailStar.frame.midY, app.frame.midY)
        XCTAssertEqual(detailStar.isSelected, originallyFavorite)
        detailStar.tap()
        let detailStateAfterTap = detailStar.isSelected
        app.navigationBars.firstMatch.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(listStar.waitForExistence(timeout: 5))
        let listLabelAfterTap = listStar.label

        // Reopen the card to read and restore the persisted state before asserting
        // the captured values, even if the list failed to refresh after the tap.
        card.tap()
        XCTAssertTrue(detailStar.waitForExistence(timeout: 5))
        if detailStar.isSelected != originallyFavorite { detailStar.tap() }
        app.navigationBars.firstMatch.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(listStar.waitForExistence(timeout: 5))
        XCTAssertEqual(listStar.label, originalListLabel)
        XCTAssertEqual(detailStateAfterTap, !originallyFavorite)
        XCTAssertEqual(listLabelAfterTap, originallyFavorite ? "Favorite card" : "Remove from favorites")

        app.buttons["decksTab"].firstMatch.tap()
        let archive = app.tables.firstMatch.cells.matching(NSPredicate(format: "label BEGINSWITH %@", "Forbidden & Limited Lists")).firstMatch
        XCTAssertTrue(archive.waitForExistence(timeout: 5))
        archive.tap()
        app.buttons["OCG"].firstMatch.tap()
        captureScreenshot(app, name: "Forbidden and limited archive — OCG")
        let release = app.tables.firstMatch.cells.firstMatch
        XCTAssertTrue(release.waitForExistence(timeout: 5))
        release.tap()
        let historicalCard = app.tables.firstMatch.cells.firstMatch
        XCTAssertTrue(historicalCard.waitForExistence(timeout: 5))
        let historicalCardID = historicalCard.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "[0-9]+")).firstMatch.label
        XCTAssertFalse(historicalCardID.isEmpty)
        XCTAssertFalse(app.navigationBars.firstMatch.buttons["Source"].exists)
        XCTAssertTrue(historicalCard.staticTexts["restrictionOCG"].firstMatch.exists)
        XCTAssertTrue(historicalCard.staticTexts["restrictionTCG"].firstMatch.exists)
        captureScreenshot(app, name: "Historical forbidden and limited cards")
        historicalCard.tap()
        XCTAssertTrue(app.navigationBars["Card Details"].firstMatch.waitForExistence(timeout: 5))
        let archiveHeading = app.staticTexts["banlistHistory"].firstMatch
        let effectHeading = app.staticTexts["Card Effect"].firstMatch
        XCTAssertTrue(archiveHeading.exists && effectHeading.exists)
        XCTAssertLessThan(effectHeading.frame.maxY, archiveHeading.frame.minY)
        let archiveHistory = historyText(in: app)
        captureScreenshot(app, name: "Card effect and historical list")
        // Detail -> release -> archive -> Tab 2.
        for _ in 0..<3 { app.navigationBars.firstMatch.buttons.element(boundBy: 0).tap() }
        app.buttons["cardsTab"].firstMatch.tap()
        XCTAssertFalse(app.buttons["OCG"].firstMatch.exists)
        XCTAssertFalse(app.buttons["TCG"].firstMatch.exists)
        XCTAssertTrue(firstCard.staticTexts["restrictionOCG"].firstMatch.exists)
        XCTAssertTrue(firstCard.staticTexts["restrictionTCG"].firstMatch.exists)
        // Open the same card through the catalogue and compare the entire
        // history panel, not just the current restriction badges.
        app.navigationBars.firstMatch.buttons["Search"].firstMatch.tap()
        let historySearch = app.searchFields["cardSearchField"].firstMatch
        XCTAssertTrue(historySearch.waitForExistence(timeout: 5))
        replaceText(in: historySearch, with: historicalCardID + "\n")
        let catalogueCard = app.tables["cardSearchResults"].firstMatch.cells.containing(.staticText, identifier: historicalCardID).firstMatch
        XCTAssertTrue(catalogueCard.waitForExistence(timeout: 5))
        catalogueCard.tap()
        XCTAssertTrue(app.navigationBars["Card Details"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(historyText(in: app), archiveHistory, "History must be identical from either entry point")
        app.navigationBars.firstMatch.buttons.element(boundBy: 0).tap()
        app.buttons["clearCardSearch"].firstMatch.tap()
        // Check the Chinese presentation too: the compact badges must retain
        // their complete status for accessibility in both supported languages.
        app.navigationBars.firstMatch.buttons["languageButton"].firstMatch.tap()
        app.buttons["简体中文"].firstMatch.tap()
        captureScreenshot(app, name: "卡牌列表 — 双赛制标签")
        app.tables.firstMatch.cells.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["卡牌详情"].firstMatch.waitForExistence(timeout: 5))
        let artwork = app.descendants(matching: .any).matching(identifier: "查看卡牌大图").firstMatch
        XCTAssertTrue(artwork.exists)
        XCTAssertGreaterThanOrEqual(app.staticTexts["restrictionOCG"].firstMatch.frame.minX, artwork.frame.maxX)
        assertCardMetadataFitsOneRow(in: app, screen: app.frame)
        captureScreenshot(app, name: "卡牌详情 — 卡图右侧信息行")
        app.navigationBars.firstMatch.buttons.element(boundBy: 0).tap()
        app.navigationBars.firstMatch.buttons["搜索"].firstMatch.tap()
        let chineseSearch = app.searchFields["cardSearchField"].firstMatch
        chineseSearch.tap()
        chineseSearch.typeText("23434538\n")
        let chineseCard = app.tables.firstMatch.cells.containing(.staticText, identifier: "23434538").firstMatch
        XCTAssertTrue(chineseCard.waitForExistence(timeout: 5))
        captureScreenshot(app, name: "卡牌列表 — 限制状态")
        chineseCard.tap()
        XCTAssertEqual(app.staticTexts["restrictionOCG"].firstMatch.label, "OCG · 限 1 张")
        XCTAssertEqual(app.staticTexts["restrictionTCG"].firstMatch.label, "TCG · 禁止")
        captureScreenshot(app, name: "卡牌详情 — 禁限状态")
    }

    func testMyDeckAddsFromPickerAndFavoriteDoesNotAddCard() throws {
        let app = launchInEnglish()
        app.buttons["decksTab"].firstMatch.tap()
        let myDeck = app.tables.firstMatch.cells.matching(NSPredicate(format: "label BEGINSWITH %@", "My Deck")).firstMatch
        XCTAssertTrue(myDeck.waitForExistence(timeout: 5))
        myDeck.tap()
        app.navigationBars.firstMatch.buttons["addDeckCards"].firstMatch.tap()
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        // Pick a known Main Deck card with room left, without clearing the saved deck.
        let candidates = [("40640057", "Kuriboh"), ("46986414", "Dark Magician"),
                          ("89631139", "Blue-Eyes White Dragon"), ("74677422", "Red-Eyes Black Dragon")]
        var selected: (String, String, Int)?
        for (id, name) in candidates {
            replaceText(in: field, with: id + "\n")
            let row = app.tables.firstMatch.cells.containing(.staticText, identifier: id).firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: 5))
            let badge = row.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "[0-9]+ copies in deck")).firstMatch
            XCTAssertTrue(badge.exists)
            let count = Int(badge.label.split(separator: " ").first ?? "") ?? 3
            if count < 3 { selected = (id, name, count); break }
        }
        guard let (id, name, initialCount) = selected else {
            throw XCTSkip("All four sample cards already have three copies in this simulator's saved deck")
        }
        let row = app.tables.firstMatch.cells.containing(.staticText, identifier: id).firstMatch
        captureScreenshot(app, name: "My Deck — card picker")
        let favorite = row.buttons.matching(NSPredicate(format: "label IN %@", ["Favorite card", "Remove from favorites"])).firstMatch
        XCTAssertTrue(favorite.exists)
        favorite.tap()
        XCTAssertTrue(app.navigationBars["Add Cards"].firstMatch.exists)
        XCTAssertTrue(row.staticTexts["\(initialCount) copies in deck"].firstMatch.exists, "Favorite must not also add a copy")
        row.buttons.matching(NSPredicate(format: "label IN %@", ["Favorite card", "Remove from favorites"])).firstMatch.tap()

        row.tap()
        let status = app.staticTexts["deckAddStatus"].firstMatch
        expectation(for: NSPredicate(format: "label CONTAINS %@", "Added to Main Deck:"), evaluatedWith: status)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(row.staticTexts["\(initialCount + 1) copies in deck"].firstMatch.exists)
        captureScreenshot(app, name: "My Deck — card added")
        app.navigationBars.firstMatch.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars.firstMatch.buttons["addDeckCards"].firstMatch.waitForExistence(timeout: 5))
        let addedCard = app.collectionViews.firstMatch.cells.matching(NSPredicate(format: "label BEGINSWITH %@", name + ", ")).firstMatch
        for _ in 0..<15 where !addedCard.isHittable { app.collectionViews.firstMatch.swipeUp() }
        XCTAssertTrue(addedCard.isHittable)
        captureScreenshot(app, name: "My Deck — refreshed recipe")
        // Restore the one copy added by this test, also verifying in-deck editing.
        addedCard.press(forDuration: 1.1)
        let removeOne = app.buttons["Remove One Copy"].firstMatch
        XCTAssertTrue(removeOne.waitForExistence(timeout: 5))
        removeOne.tap()
    }

    private func launchInEnglish() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-appLanguage", "en", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.navigationBars.firstMatch.buttons["Search"].firstMatch.waitForExistence(timeout: 15))
        return app
    }

    private func historyText(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) -> [String] {
        let panel = app.descendants(matching: .any)["banlistHistoryPanel"].firstMatch
        XCTAssertTrue(panel.waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertTrue(panel.staticTexts["banlistHistoryOCG"].firstMatch.exists, file: file, line: line)
        XCTAssertTrue(panel.staticTexts["banlistHistoryTCG"].firstMatch.exists, file: file, line: line)
        let text = panel.staticTexts.allElementsBoundByIndex.map(\.label)
        XCTAssertGreaterThan(text.count, 2, "The history panel must include history as well as format headings", file: file, line: line)
        return text
    }

    private func assertCardMetadataFitsOneRow(in container: XCUIElement, screen: CGRect, expectedID: String? = nil,
                                              file: StaticString = #filePath, line: UInt = #line) {
        let idLabel = container.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "[0-9]+")).firstMatch
        let labels = [container.staticTexts["restrictionOCG"].firstMatch,
                      container.staticTexts["restrictionTCG"].firstMatch,
                      idLabel, container.staticTexts["cardReleaseDate"].firstMatch]
        for label in labels {
            XCTAssertTrue(label.exists, "Missing card metadata label", file: file, line: line)
            XCTAssertFalse(label.label.isEmpty, file: file, line: line)
        }
        if let expectedID = expectedID { XCTAssertEqual(idLabel.label, expectedID, file: file, line: line) }
        let frames = labels.map { $0.frame }
        for frame in frames {
            XCTAssertGreaterThan(frame.width, 0, file: file, line: line)
            XCTAssertGreaterThan(frame.height, 0, file: file, line: line)
            XCTAssertGreaterThanOrEqual(frame.minX, screen.minX, file: file, line: line)
            XCTAssertLessThanOrEqual(frame.maxX, screen.maxX, file: file, line: line)
            XCTAssertEqual(frame.midY, frames[0].midY, accuracy: 3, "Metadata wrapped onto another line", file: file, line: line)
        }
        for (left, right) in zip(frames, frames.dropFirst()) {
            XCTAssertLessThanOrEqual(left.maxX, right.minX, "Metadata labels overlap or have changed reading order", file: file, line: line)
        }
    }

    private func replaceText(in field: XCUIElement, with value: String) {
        field.tap()
        let existing = field.value as? String ?? ""
        if existing != field.placeholderValue && !existing.isEmpty {
            // Tapping a long query places the cursor in the middle. Use the
            // search field's clear action instead of deleting only its prefix.
            let clear = field.buttons["Clear text"].firstMatch
            XCTAssertTrue(clear.waitForExistence(timeout: 3))
            clear.tap()
        }
        field.typeText(value)
    }

    private func captureScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
