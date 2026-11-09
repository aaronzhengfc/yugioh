//
//  CardViewWithStarController.swift
//  yugioh
//
//  Created by Aaron on 30/1/2017.
//  Copyright © 2017 sightcorner. All rights reserved.
//

import Foundation
import UIKit
import Kingfisher

class CardViewWithStarController: CardViewBaseController {
    
    
    
    @IBOutlet weak var iTableView: UITableView!
    
    private var cardService = CardService()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = L10n.text("我的收藏", "Favorites")
        view.backgroundColor = .systemGroupedBackground
        self.tableView = iTableView
        self.setupTableView()
        self.afterDeselect = starAfterDeselect
        
        
    }
    
    func starAfterDeselect() {
        refreshCards()
    }

    override func cardsForDisplay() -> [CardEntity] {
        cardService.list().map { getCardEntity(id: $0) }
    }
}
