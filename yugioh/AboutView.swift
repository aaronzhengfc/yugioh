//
//  AboutView.swift
//  yugioh
//
//  Created by Aaron on 16/8/2020.
//  Copyright © 2020 sightcorner. All rights reserved.
//

import Foundation
import UIKit

class AboutView: UIView {
    
    @IBOutlet var contentView: UIView!
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        self.setup()
    }
    
    private func setup() {
        let scroll = UIScrollView()
        let panel = UIStackView()
        panel.axis = .vertical
        panel.spacing = 14
        panel.backgroundColor = .secondarySystemGroupedBackground
        panel.layer.cornerRadius = 14
        panel.isLayoutMarginsRelativeArrangement = true
        panel.layoutMargins = UIEdgeInsets(top: 18, left: 16, bottom: 18, right: 16)
        let title = UILabel()
        title.text = L10n.text("游戏王卡牌", "Card Guide")
        title.font = .preferredFont(forTextStyle: .headline)
        let version = UILabel()
        version.text = L10n.text("版本 ", "Version ") + (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
        version.font = .preferredFont(forTextStyle: .caption1)
        version.textColor = .secondaryLabel
        let body = UILabel()
        body.text = L10n.text(
            """
            查询卡牌资料，收藏喜欢的卡牌，管理自己的卡组，并使用生命值计分器和模拟抽卡工具。

            本应用由 Aaron-Zheng 利用个人时间开发。欢迎在 App Store 留下反馈和功能建议。
            https://github.com/Aaron-zheng

            本应用为非官方爱好者作品，与 Yu-Gi-Oh! 或 Konami 无关联。相关作品版权归高桥和希及各权利人所有，卡牌资料与图片版权归 Konami 所有。

            菜单图标使用 Google Material Design 图标，字体使用 Google Roboto。
            """,
            """
            Look up cards, save favorites, manage your deck, and use the life point calculator and draw simulator.

            Created by Aaron-Zheng as a personal project. Feedback and feature suggestions are welcome on the App Store.
            https://github.com/Aaron-zheng

            This is an unofficial fan app and is not affiliated with Yu-Gi-Oh! or Konami. Related works belong to Kazuki Takahashi and their respective rights holders. Card information and images belong to Konami.

            Menu icons use Google Material Design icons. Fonts use Google Roboto.
            """
        )
        body.numberOfLines = 0
        body.font = .preferredFont(forTextStyle: .subheadline)
        body.textColor = .secondaryLabel
        [title, version, body].forEach { $0.adjustsFontForContentSizeCategory = true; panel.addArrangedSubview($0) }
        backgroundColor = .systemGroupedBackground
        addSubview(scroll)
        scroll.addSubview(panel)
        [scroll, panel].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
            panel.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 12),
            panel.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -12),
            panel.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 4),
            panel.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -12),
            panel.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -24)
        ])
    }
}
