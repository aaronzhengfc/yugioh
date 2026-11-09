//
//  CardViewBaseController.swift
//  yugioh
//
//  Created by Aaron on 2/4/2017.
//  Copyright © 2017 sightcorner. All rights reserved.
//

import Foundation
import UIKit
import Kingfisher

class CardViewBaseController: UIViewController {


    var tableView: UITableView!
    var cardEntitys: Array<CardEntity>! = []
    
    fileprivate let cardService = CardService()
    
    var afterDeselect: (() -> Void)?
    private var pagination: CardListPagination!
    private var searchCriteria: CardSearchCriteria = .empty
    private let searchQueue = DispatchQueue(label: "com.sightcorner.yugioh.card-search", qos: .userInitiated, attributes: .concurrent)
    private var searchGeneration = 0
    private var isSearching = false
    private var lastSourceIDs: [String]?
    private var lastLanguage: String?
    private var lastFavorites: Set<String> = []
    private let resultHeader = UIView()
    private let resultCount = UILabel()
    private let clearSearchButton = UIButton(type: .system)
    
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshCards()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard tableView != nil, !searchCriteria.isEmpty,
              abs(resultHeader.frame.width - tableView.bounds.width) > 0.5 else { return }
        updateSearchResultHeader(count: cardEntitys.count)
    }

    @objc func tableViewReload() {
        refreshCards(resetPagination: true)
    }
    
    
    func setupTableView() {
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.register(CardTableViewCell.self, forCellReuseIdentifier: CardTableViewCell.identifier())
        self.tableView.backgroundColor = .systemGroupedBackground
        self.tableView.separatorStyle = .none
        self.tableView.tableHeaderView = UIView(frame: CGRect.zero)
        self.tableView.accessibilityIdentifier = "cardSearchResults"
        setupSearchResultHeader()
        pagination = CardListPagination(tableView: tableView)
        refreshCards(resetPagination: true)

        
        nc.addObserver(self, selector: #selector(CardViewBaseController.tableViewReload), name: Notification.Name.NOTIFICATION_NAME_LANGUAGE_CHANGE, object: nil)
    }
    
    
    private func setupSearchResultHeader() {
        resultCount.font = .preferredFont(forTextStyle: .subheadline)
        resultCount.adjustsFontForContentSizeCategory = true
        resultCount.textColor = .secondaryLabel
        resultCount.numberOfLines = 0
        resultCount.accessibilityIdentifier = "cardSearchResultCount"
        // Let the count take the available space; otherwise the button can
        // stretch across the header and its centered title appears misplaced.
        resultCount.setContentHuggingPriority(.defaultLow, for: .horizontal)
        resultCount.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        var clearStyle = UIButton.Configuration.tinted()
        clearStyle.title = L10n.text("清除筛选", "Clear filters")
        clearStyle.image = UIImage(systemName: "xmark")
        clearStyle.imagePadding = 5
        let clearAccent = UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(red: 0.42, green: 0.78, blue: 0.65, alpha: 1)
            : UIColor(red: 0.12, green: 0.36, blue: 0.29, alpha: 1) }
        clearStyle.baseForegroundColor = clearAccent
        clearStyle.baseBackgroundColor = clearAccent
        clearStyle.cornerStyle = .capsule
        clearStyle.contentInsets = NSDirectionalEdgeInsets(top: 7, leading: 10, bottom: 7, trailing: 10)
        clearStyle.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var result = attributes
            result.font = .preferredFont(forTextStyle: .subheadline)
            return result
        }
        clearSearchButton.configuration = clearStyle
        clearSearchButton.titleLabel?.adjustsFontForContentSizeCategory = true
        clearSearchButton.setContentHuggingPriority(.required, for: .horizontal)
        clearSearchButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        clearSearchButton.accessibilityIdentifier = "clearCardSearch"
        clearSearchButton.addTarget(self, action: #selector(clearCardSearch), for: .touchUpInside)
        let row = UIStackView(arrangedSubviews: [resultCount, clearSearchButton])
        row.alignment = .center
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        resultHeader.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: resultHeader.topAnchor, constant: 8),
            row.bottomAnchor.constraint(equalTo: resultHeader.bottomAnchor, constant: -8),
            row.leadingAnchor.constraint(equalTo: resultHeader.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: resultHeader.trailingAnchor, constant: -16),
            clearSearchButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
    }

    func presentCardSearch() {
        let controller = CardSearchViewController()
        controller.criteria = searchCriteria
        controller.onSearch = { [weak self] criteria in
            guard let self = self else { return }
            self.searchCriteria = criteria
            self.refreshCards(resetPagination: true)
            self.scrollToTop()
        }
        controller.modalPresentationStyle = .pageSheet
        if let sheet = controller.sheetPresentationController {
            sheet.detents = [.large()]
        }
        present(controller, animated: true)
    }

    @objc private func clearCardSearch() {
        searchCriteria = .empty
        refreshCards(resetPagination: true)
        scrollToTop()
    }

    private func scrollToTop() {
        tableView.setContentOffset(CGPoint(x: 0, y: -tableView.adjustedContentInset.top), animated: false)
    }

    private func updateSearchResultHeader(count: Int) {
        guard !searchCriteria.isEmpty else {
            tableView.tableHeaderView = UIView(frame: .zero)
            tableView.backgroundView = nil
            return
        }
        resultCount.text = isSearching
            ? L10n.text("正在搜索…", "Searching…")
            : L10n.text("搜索结果 · \(count) 张卡牌", "Search results · \(count) cards")
        clearSearchButton.configuration?.title = L10n.text("清除筛选", "Clear filters")
        let width = max(tableView.bounds.width, 1)
        let size = resultHeader.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
        resultHeader.frame = CGRect(x: 0, y: 0, width: width, height: size.height)
        tableView.tableHeaderView = resultHeader
        if count == 0 && !isSearching {
            let empty = UILabel()
            empty.text = L10n.text("没有找到匹配的卡牌\n试试其他搜索条件，或清除筛选。", "No matching cards\nTry other search criteria or clear filters.")
            empty.font = .preferredFont(forTextStyle: .body)
            empty.adjustsFontForContentSizeCategory = true
            empty.textColor = .secondaryLabel
            empty.numberOfLines = 0
            empty.textAlignment = .center
            empty.accessibilityIdentifier = "cardSearchEmptyState"
            tableView.backgroundView = empty
        } else {
            tableView.backgroundView = nil
        }
    }

    /// Subclasses can provide a smaller collection without replacing row counts.
    func cardsForDisplay() -> [CardEntity] { getCardEntity() }

    func refreshCards(resetPagination: Bool = false) {
        guard tableView != nil, pagination != nil else { return }
        let source = cardsForDisplay()
        let sourceIDs = source.map { $0.id ?? "" }
        let currentLanguage = language
        guard resetPagination || sourceIDs != lastSourceIDs || currentLanguage != lastLanguage else {
            // Returning from detail normally does not change the catalogue or
            // search. Keep the result, pagination and scroll position intact.
            synchronizeFavorites()
            return
        }
        lastSourceIDs = sourceIDs
        lastLanguage = currentLanguage
        searchGeneration += 1
        let generation = searchGeneration
        let criteria = searchCriteria

        if criteria.isEmpty {
            isSearching = false
            applyResults(source)
            return
        }

        // Capture only plain values on the main thread. Filtering descriptions
        // for the full catalogue can then happen without blocking navigation.
        let documents = criteria.documents(for: source)
        isSearching = true
        cardEntitys = []
        pagination.reset(total: 0)
        updateSearchResultHeader(count: 0)
        tableView.reloadData()
        searchQueue.async { [weak self] in
            let indices = criteria.matchingIndices(in: documents)
            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.searchGeneration == generation else { return }
                self.applyResults(indices.map { source[$0] })
            }
        }
    }

    private func applyResults(_ updated: [CardEntity]) {
        isSearching = false
        let favorites = Set(cardService.list())
        lastFavorites = favorites
        for card in updated { card.isSelected = favorites.contains(card.id) }
        cardEntitys = updated
        pagination.reset(total: updated.count)
        updateSearchResultHeader(count: updated.count)
        tableView.reloadData()
    }

    private func synchronizeFavorites() {
        let favorites = Set(cardService.list())
        let changed = favorites.symmetricDifference(lastFavorites)
        guard !changed.isEmpty else { return }
        lastFavorites = favorites
        for card in cardEntitys where changed.contains(card.id) {
            card.isSelected = favorites.contains(card.id)
        }
        for index in tableView.indexPathsForVisibleRows ?? [] where index.row < cardEntitys.count {
            guard changed.contains(cardEntitys[index.row].id),
                  let cell = tableView.cellForRow(at: index) as? CardTableViewCell else { continue }
            cell.refreshFavorite()
        }
    }

    @objc(tableView:didSelectRowAtIndexPath:)
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.tableView.deselectRow(at: indexPath, animated: true)
        let controller = CardDetailViewController()
        controller.cardEntity = cardEntitys[indexPath.row]
        controller.hidesBottomBarWhenPushed = true
        controller.proxy = self.tableView
        self.navigationController?.pushViewController(controller, animated: true)
    }
    
    
    
    
}


extension CardViewBaseController: UITableViewDataSource {
    
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return pagination?.visibleCount ?? 0
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = self.tableView.dequeueReusableCell(withIdentifier: CardTableViewCell.identifier(), for: indexPath) as! CardTableViewCell
        let cardEntity = cardEntitys[indexPath.row]
        if let f = afterDeselect {
            cell.afterDeselect = f
        }
        cell.prepare(cardEntity: cardEntity, tableView: tableView, indexPath: indexPath)
        return cell
    }
    
    @objc(tableView:heightForRowAtIndexPath:)
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return CardTableViewCell.rowHeight
    }
    
    @objc(tableView:didEndDisplayingCell:forRowAtIndexPath:)
    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        (cell as! CardTableViewCell).card.kf.cancelDownloadTask()
    }
    
    @objc(tableView:willDisplayCell:forRowAtIndexPath:)
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
        let cell = (cell as! CardTableViewCell)
        setImage(card: cell.card, id: cardEntitys[indexPath.row].id)
        
    }
    
    
}


extension CardViewBaseController: UITableViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        pagination?.loadMoreIfNeeded()
    }
}
