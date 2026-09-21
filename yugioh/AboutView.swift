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
        Bundle.main.loadNibNamed("AboutView", owner: self, options: nil)
        let originalText = contentView.subviews.compactMap { ($0 as? UILabel)?.text }.joined(separator: "\n")
        let scroll = UIScrollView()
        let panel = UIStackView()
        panel.axis = .vertical
        panel.spacing = 14
        panel.backgroundColor = .secondarySystemGroupedBackground
        panel.layer.cornerRadius = 14
        panel.isLayoutMarginsRelativeArrangement = true
        panel.layoutMargins = UIEdgeInsets(top: 18, left: 16, bottom: 18, right: 16)
        let title = UILabel()
        title.text = "游戏王卡牌"
        title.font = .preferredFont(forTextStyle: .headline)
        let version = UILabel()
        version.text = "版本 " + (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
        version.font = .preferredFont(forTextStyle: .caption1)
        version.textColor = .secondaryLabel
        let body = UILabel()
        body.text = originalText
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
