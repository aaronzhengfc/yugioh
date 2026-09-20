//
//  ViewController.swift
//  yugioh
//
//  Created by Aaron on 24/9/2016.
//  Copyright © 2016 sightcorner. All rights reserved.
//

import UIKit
import SQLite

class ViewController: UITabBarController {
    
    // 搜索按钮
    @IBOutlet var packButton: UIBarButtonItem!
    
    // 翻译按钮
    @IBOutlet var languageButton: UIBarButtonItem!
    
    
    private var menuButtons: [UIButton] = []

    fileprivate var currentNodeName: String!
    var cardEntitys: Array<CardEntity> = []
    let cardService = CardService()
    let deckService = DeckService()
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent;
    }
    
    override func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {

        if item.title!.description != tabBarItemCard {
            self.navigationItem.rightBarButtonItem = nil
            self.navigationItem.leftBarButtonItem = nil
        } else {
            self.navigationItem.rightBarButtonItem = packButton
            self.navigationItem.leftBarButtonItem = languageButton
        }
    }
    

    override func viewDidLoad() {
        super.viewDidLoad()
        self.setNeedsStatusBarAppearanceUpdate()
        self.conversion()
        self.setupData()
        self.setupTabBarStyle()
        
        self.languageButton = UIBarButtonItem.init(
            image: UIImage(systemName: "globe"),
            style: .plain,
            target: self,
            action: #selector(ViewController.clickLanguageButton(_:))
        )
        self.languageButton.accessibilityLabel = "切换语言"
        self.navigationItem.leftBarButtonItem = self.languageButton
    }
    
    private func conversion() {
        self.deckService.conversion()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateMenuSelection()
    }
    
    
    private func setupTabBarStyle() {
        // Keep the three destinations evenly spaced, including on iOS 26.
        tabBar.isHidden = true
        view.backgroundColor = greyColor
        let bar = UIView()
        bar.backgroundColor = .systemBackground
        bar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bar)
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(stack)
        let symbols = ["rectangle.stack", "wallet.pass", "wrench.and.screwdriver"]
        for (index, controller) in (viewControllers ?? []).enumerated() {
            var configuration = UIButton.Configuration.plain()
            configuration.title = controller.tabBarItem.title
            configuration.image = UIImage(systemName: symbols[index])
            configuration.imagePlacement = .top
            configuration.imagePadding = 4
            configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 20)
            configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
                var result = attributes
                result.font = UIFont.systemFont(ofSize: 11, weight: .medium)
                return result
            }
            let button = UIButton(configuration: configuration)
            button.tag = index
            button.accessibilityLabel = controller.tabBarItem.title
            button.addTarget(self, action: #selector(selectMenu(_:)), for: .touchUpInside)
            stack.addArrangedSubview(button)
            menuButtons.append(button)
            controller.additionalSafeAreaInsets.bottom = 56
        }
        NSLayoutConstraint.activate([
            bar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: bar.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: bar.trailingAnchor),
            stack.topAnchor.constraint(equalTo: bar.topAnchor),
            stack.heightAnchor.constraint(equalToConstant: 56),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        updateMenuSelection()
    }

    @objc private func selectMenu(_ sender: UIButton) {
        selectedIndex = sender.tag
        navigationItem.leftBarButtonItem = selectedIndex == 0 ? languageButton : nil
        navigationItem.rightBarButtonItem = selectedIndex == 0 ? packButton : nil
        updateMenuSelection()
    }

    private func updateMenuSelection() {
        for button in menuButtons {
            let selected = button.tag == selectedIndex
            button.configuration?.baseForegroundColor = selected ? greenColor : .secondaryLabel
            button.accessibilityTraits = selected ? [.button, .selected] : [.button]
        }
    }

    private func setupData() {
        cardEntitys = getCardEntity()
    }
    @IBAction func clickLanguageButton(_ sender: UIBarButtonItem) {
        let alertController = UIAlertController(title: "选择语言", message: nil, preferredStyle: .actionSheet)
        let chinese = UIAlertAction(title: "中文", style: .default, handler: {(action) -> Void in
            language = "cn"
            nc.post(name: Notification.Name.NOTIFICATION_NAME_LANGUAGE_CHANGE, object: nil)
        })
        let english = UIAlertAction(title: "English", style: .default, handler: {(action) -> Void in
            language = "en"
            nc.post(name: Notification.Name.NOTIFICATION_NAME_LANGUAGE_CHANGE, object: nil)
        })
        let fr = UIAlertAction(title: "Français", style: .default, handler: {(action) -> Void in
            language = "fr"
            nc.post(name: Notification.Name.NOTIFICATION_NAME_LANGUAGE_CHANGE, object: nil)
        })
        let it = UIAlertAction(title: "Italian", style: .default, handler: {(action) -> Void in
            language = "it"
            nc.post(name: Notification.Name.NOTIFICATION_NAME_LANGUAGE_CHANGE, object: nil)
        })
        let pt = UIAlertAction(title: "Português", style: .default, handler: {(action) -> Void in
            language = "pt"
            nc.post(name: Notification.Name.NOTIFICATION_NAME_LANGUAGE_CHANGE, object: nil)
        })
        let cancelButton = UIAlertAction(title: "取消", style: .cancel, handler: { (action) -> Void in
            print("Cancel button tapped")
        })
        alertController.addAction(chinese)
        alertController.addAction(english)
        alertController.addAction(fr)
        alertController.addAction(it)
        alertController.addAction(pt)
        alertController.addAction(cancelButton)
        
        
        alertController.popoverPresentationController?.barButtonItem = sender
        self.present(alertController, animated: true, completion: nil)
    }
    
    
}

