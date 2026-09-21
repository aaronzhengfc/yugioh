//
//  BattleView.swift
//  yugioh
//
//  Created by Aaron on 31/12/2018.
//  Copyright © 2018 sightcorner. All rights reserved.
//

import Foundation
import UIKit

class BattleView: UIView {
    
    private var deckService = DeckService()
    private var result: [DeckEntity] = []
    private var original: [String] = []
    private var imgArray: [UIImageView] = []
    
    @IBOutlet var contentView: UIView!
    
    @IBOutlet weak var button: UIButton!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        self.setup()
    }
    
    private let status = UILabel()
    private let hint = UILabel()

    private func setup() {
        backgroundColor = .systemGroupedBackground
        let toolbar = UIStackView()
        toolbar.spacing = 10
        toolbar.alignment = .center
        status.font = .monospacedDigitSystemFont(ofSize: 15, weight: .semibold)
        toolbar.addArrangedSubview(status)
        toolbar.addArrangedSubview(UIView())
        let reset = UIButton(type: .system)
        reset.setTitle("重洗", for: .normal)
        reset.setTitleColor(.label, for: .normal)
        reset.addTarget(self, action: #selector(reshuffle), for: .touchUpInside)
        reset.widthAnchor.constraint(equalToConstant: 44).isActive = true
        toolbar.addArrangedSubview(reset)
        let draw = UIButton(type: .system)
        var style = UIButton.Configuration.filled()
        style.title = "抽一张"
        style.image = UIImage(systemName: "rectangle.stack")
        style.imagePadding = 6
        style.baseBackgroundColor = .label
        style.baseForegroundColor = .systemBackground
        style.cornerStyle = .capsule
        draw.configuration = style
        draw.addTarget(self, action: #selector(clickButtonHandler), for: .touchUpInside)
        toolbar.addArrangedSubview(draw)
        button = draw
        hint.font = .systemFont(ofSize: 13)
        hint.textColor = .secondaryLabel
        hint.numberOfLines = 0
        [toolbar, hint].forEach { addSubview($0); $0.translatesAutoresizingMaskIntoConstraints = false }
        NSLayoutConstraint.activate([
            toolbar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            toolbar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            toolbar.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            toolbar.heightAnchor.constraint(equalToConstant: 44),
            hint.topAnchor.constraint(equalTo: toolbar.bottomAnchor, constant: 8),
            hint.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor),
            hint.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor)
        ])
    }

    @objc private func reshuffle() { initialCard() }

    private func updateStatus() {
        status.text = "剩余 \(original.count) · 已抽 \(imgArray.count)"
        button.isEnabled = !original.isEmpty
        hint.text = original.isEmpty && imgArray.isEmpty
            ? "先在卡组页将卡牌加入我的主卡组，即可模拟抽卡。"
            : "点击抽卡，拖动卡牌可自由摆放；重洗可重新开始。"
    }

    func initialCard() {
        for each in imgArray {
            each.removeFromSuperview()
        }
        
        original = []
        imgArray = []
        result = deckService.list()["0"]!
        for each in result {
            for _ in 0 ..< each.number {
                original.append(each.id)
            }
        }
        updateStatus()
    }
    
    @IBAction func clickButtonHandler(_ sender: UIButton) {
        
        if original.count <= 0 {
            return
        }
        
        let randomIndex = Int(arc4random_uniform(UInt32(original.count)))
        let val: String = original[randomIndex]
        original.remove(at: randomIndex)
        
        
        let cardWidth = max(40, (bounds.width - 48) / 4)
        let index = imgArray.count
        let rows = max(1, Int((bounds.height - 110) / (cardWidth * 1.44 + 10)))
        let slot = index % (rows * 4)
        let imgView = UIImageView(frame: CGRect(x: 12 + CGFloat(slot % 4) * (cardWidth + 8),
                                               y: 92 + CGFloat(slot / 4) * (cardWidth * 1.44 + 10),
                                               width: cardWidth, height: cardWidth * 1.44))
        imgView.contentMode = .scaleAspectFit
        setImage(card: imgView, id: val)
        
        var panGesture  = UIPanGestureRecognizer()
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(BattleView.draggedView(_:)))
        imgView.isUserInteractionEnabled = true
        imgView.addGestureRecognizer(panGesture)
        self.addSubview(imgView)
        imgArray.append(imgView)
        updateStatus()
        
    }
    
    @objc func draggedView(_ sender:UIPanGestureRecognizer){
        let viewDrag = sender.view!
        self.bringSubviewToFront(viewDrag)
        let translation = sender.translation(in: self)
        viewDrag.center = CGPoint(x: viewDrag.center.x + translation.x, y: viewDrag.center.y + translation.y)
        sender.setTranslation(CGPoint.zero, in: self)
    }
    
    
}
