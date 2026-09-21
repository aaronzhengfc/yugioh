//
//  CalculateView.swift
//  yugioh
//
//  Created by Aaron on 31/12/2018.
//  Copyright © 2018 sightcorner. All rights reserved.
//

import Foundation
import UIKit

class CalculateView: UIView {
    
    
    @IBOutlet var contentView: UIView!
    
    
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        setup()
    }
    
    
    
    
    let datas = ["", "", "", "清除", "",
                 "-", "1", "2", "3", "-",
                 "+", "4", "5", "6", "+",
                 "减半", "7","8","9", "减半",
                 "变成", "0", "00", "000", "变成"]
    
    var calculateButton: DataButton!
    
    @IBOutlet weak var scoreLableOne: UILabel!
    @IBOutlet weak var scoreLableTwo: UILabel!
    
    
    
    
    func setup() {
        backgroundColor = .systemGroupedBackground
        let scroll = UIScrollView()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        addSubview(scroll)
        scroll.addSubview(stack)
        scroll.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 4),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -12),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -24)
        ])
        let scores = UIStackView()
        scores.spacing = 10
        scores.distribution = .fillEqually
        for player in 0...1 {
            let panel = UIStackView()
            panel.axis = .vertical
            panel.spacing = 6
            panel.isLayoutMarginsRelativeArrangement = true
            panel.layoutMargins = UIEdgeInsets(top: 14, left: 12, bottom: 14, right: 12)
            panel.backgroundColor = .secondarySystemGroupedBackground
            panel.layer.cornerRadius = 14
            let title = UILabel()
            title.text = player == 0 ? "玩家 1 · LP" : "玩家 2 · LP"
            title.font = .systemFont(ofSize: 13, weight: .medium)
            title.textColor = .secondaryLabel
            title.textAlignment = .center
            let score = UILabel()
            score.text = "8000"
            score.font = .monospacedDigitSystemFont(ofSize: 34, weight: .semibold)
            score.textAlignment = .center
            score.adjustsFontSizeToFitWidth = true
            score.minimumScaleFactor = 0.4
            panel.addArrangedSubview(title)
            panel.addArrangedSubview(score)
            scores.addArrangedSubview(panel)
            if player == 0 { scoreLableOne = score } else { scoreLableTwo = score }
        }
        stack.addArrangedSubview(scores)
        let inputRow = UIStackView()
        inputRow.spacing = 8
        calculateButton = DataButton(type: .system)
        calculateButton.setTitle("", for: .normal)
        calculateButton.setTitleColor(.label, for: .normal)
        calculateButton.titleLabel?.font = .monospacedDigitSystemFont(ofSize: 26, weight: .medium)
        calculateButton.backgroundColor = .secondarySystemGroupedBackground
        calculateButton.layer.cornerRadius = 12
        calculateButton.isUserInteractionEnabled = false
        calculateButton.accessibilityLabel = "输入的生命值"
        inputRow.addArrangedSubview(calculateButton)
        let clear = makeButton("清除", column: 3)
        clear.widthAnchor.constraint(equalToConstant: 68).isActive = true
        inputRow.addArrangedSubview(clear)
        inputRow.heightAnchor.constraint(equalToConstant: 52).isActive = true
        stack.addArrangedSubview(inputRow)
        for values in [["−", "1", "2", "3", "−"], ["+", "4", "5", "6", "+"],
                       ["减半", "7", "8", "9", "减半"], ["变成", "0", "00", "000", "变成"]] {
            let row = UIStackView()
            row.spacing = 6
            row.distribution = .fillEqually
            for (column, value) in values.enumerated() { row.addArrangedSubview(makeButton(value, column: column)) }
            row.heightAnchor.constraint(equalToConstant: 48).isActive = true
            stack.addArrangedSubview(row)
        }
        let hint = UILabel()
        hint.text = "左侧操作玩家 1，右侧操作玩家 2"
        hint.textAlignment = .center
        hint.textColor = .secondaryLabel
        hint.font = .systemFont(ofSize: 12)
        stack.addArrangedSubview(hint)
    }

    private func makeButton(_ title: String, column: Int) -> DataButton {
        let button = DataButton(type: .system)
        button.data = title == "−" ? "-" : title
        button.index = column
        button.setTitle(title, for: .normal)
        button.setTitleColor(.label, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: title.count > 1 ? 14 : 21, weight: .medium)
        button.backgroundColor = column == 0 || column == 4 ? .tertiarySystemFill : .secondarySystemGroupedBackground
        button.layer.cornerRadius = 10
        button.addTarget(self, action: #selector(performButton), for: .touchUpInside)
        if column == 0 || column == 4 {
            button.accessibilityLabel = "玩家 \(column == 0 ? 1 : 2) \(title)"
        }
        return button
    }

    @objc private func performButton(sender: DataButton) {
        if sender.data == "" {
            return
        }
        
        if sender.data == "+" {
            if self.calculateButton.currentTitle == "" {
                return
            }
            if sender.index == 0 {
                let point = Int(self.calculateButton.currentTitle!)!
                let score = Int(self.scoreLableOne.text!)!
                self.scoreLableOne.text = (score + point).description
            } else {
                let point = Int(self.calculateButton.currentTitle!)!
                let score = Int(self.scoreLableTwo.text!)!
                self.scoreLableTwo.text = (score + point).description
            }
            return
        }
        
        if sender.data == "-" {
            if self.calculateButton.currentTitle == "" {
                return
            }
            if sender.index == 0 {
                let point = Int(self.calculateButton.currentTitle!)!
                let score = Int(self.scoreLableOne.text!)!
                self.scoreLableOne.text = (score - point).description
            } else {
                let point = Int(self.calculateButton.currentTitle!)!
                let score = Int(self.scoreLableTwo.text!)!
                self.scoreLableTwo.text = (score - point).description
            }
            return
        }
        
        if sender.data == "减半" {
            if sender.index == 0 {
                let score = Int(self.scoreLableOne.text!)! / 2
                self.scoreLableOne.text = score.description
            } else {
                let score = Int(self.scoreLableTwo.text!)! / 2
                self.scoreLableTwo.text = score.description
            }
            return
        }
        
        if sender.data == "变成" {
            if self.calculateButton.currentTitle == "" {
                return
            }
            if sender.index == 0 {
                self.scoreLableOne.text = self.calculateButton.currentTitle!
            } else {
                self.scoreLableTwo.text = self.calculateButton.currentTitle!
            }
            return
        }
        
        if sender.data == "清除" {
            self.calculateButton.setTitle("", for: .normal)
        }
        
        if isStringAnInt(string: sender.data) {
            let title = self.calculateButton.currentTitle! + sender.data
            if title.count <= 8 { self.calculateButton.setTitle(title, for: .normal) }
            return
        }
    }
    
    func isStringAnInt(string: String) -> Bool {
        return Int(string) != nil
    }
    
    
}
