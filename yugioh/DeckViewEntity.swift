//
//  DeckView.swift
//  yugioh
//
//  Created by Aaron on 6/8/2017.
//  Copyright © 2017 sightcorner. All rights reserved.
//

import Foundation

class DeckViewEntity {
    // 卡组的唯一标识
    public var id: String = ""
    // 卡组名称
    public var title: String = ""
    // 卡组介绍
    public var introduction: String = ""
    // 卡组类型
    public var type: String = ""
    public var champion: String = ""
    public var championRegion: String = ""
    public var isCancelled: Bool = false
    
    init() {
        
    }
    
    init(id: String, title: String, introduction: String, type: String) {
        self.id = id
        self.title = title
        self.introduction = introduction
        self.type = type
    }
    
}
