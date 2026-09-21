//
//  Constant.swift
//  yugioh
//
//  Created by Aaron on 24/9/2016.
//  Copyright © 2016 sightcorner. All rights reserved.
//

import Foundation
import UIKit
import SQLite

public let materialGap: CGFloat = 8
public let redColor = UIColor(red: 237 / 255.0, green: 65 / 255.0, blue: 45 / 255.0, alpha: 1.0)
public let blueColor = UIColor(red: 62 / 255.0, green: 130 / 255.0, blue: 247 / 255.0, alpha: 1.0)
public let greenColor = UIColor(red: 45 / 255.0, green: 169 / 255.0, blue: 79 / 255.0, alpha: 1.0)
public let yellowColor = UIColor(red: 253 / 255.0, green: 189 / 255.0, blue: 0.0, alpha: 1.0)
public let greyColor = UIColor(red: 238 / 255.0, green: 238 / 255.0, blue: 238 / 255.0, alpha: 1.0)
public let darkColor = UIColor(red: 33/255, green: 33/255, blue: 33/255, alpha: 1)


public let navigationBarTitleText = "游戏王卡牌"


public let tabBarItemCard = "卡牌"
public let tabBarItemStar = "收藏"
public let tabBarItemSetting = "关于"

public let qiniuUrlPrefix: String = "http://yugioh.oss-cn-beijing.aliyuncs.com/yugiohnewpro/en/"
public let qiniuUrlSuffix: String = ".jpg"

//wechat id
public let wechatKey: String = Bundle.main.object(forInfoDictionaryKey: "WeChatAppID") as? String ?? ""


public let nc = NotificationCenter.default

extension Notification.Name {
    static let NOTIFICATION_NAME_LANGUAGE_CHANGE = Notification.Name("notification_name_language_change")
}



//font
//0.87 0.54 0.38
//16 14 12
//roboto medium light



private let path = Bundle.main.path(forResource: "cards", ofType: "cdb")
private var db: Connection?
public func getDB() -> Connection {
    if db == nil {
        do {
            db = try Connection(path!)
        } catch {
            print(error.localizedDescription)
        }
        
    }
    return db!
}



// Configure WeChat values in the Git-ignored Config/Local.xcconfig.
enum WeChatSharing {
    private(set) static var isRegistered = false

    static func shareButton(target: Any, action: Selector) -> UIBarButtonItem {
        let button = UIButton(type: .system)
        var style = UIButton.Configuration.tinted()
        style.title = "分享"
        style.image = UIImage(systemName: "square.and.arrow.up")
        style.imagePadding = 6
        style.baseForegroundColor = UIColor(red: 0.12, green: 0.36, blue: 0.29, alpha: 1)
        style.baseBackgroundColor = style.baseForegroundColor
        style.cornerStyle = .capsule
        style.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
        button.configuration = style
        button.accessibilityLabel = "分享到微信"
        button.addTarget(target, action: action, for: .touchUpInside)
        return UIBarButtonItem(customView: button)
    }

    static func sendImage(_ image: UIImage, from presenter: UIViewController) {
        // Keep text lossless where possible; OpenSDK permits up to 25 MB.
        guard let png = image.pngData(),
              let data = png.count <= 25 * 1024 * 1024 ? png : image.jpegData(compressionQuality: 0.95),
              data.count <= 25 * 1024 * 1024 else {
            showError("分享图片过大，请减少卡组中的卡牌后重试。", from: presenter)
            return
        }
        let object = WXImageObject()
        object.imageData = data
        let message = WXMediaMessage()
        message.mediaObject = object
        let ratio = 240 / max(image.size.width, image.size.height)
        let size = CGSize(width: max(1, image.size.width * ratio), height: max(1, image.size.height * ratio))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let thumbnail = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        if let data = thumbnail.jpegData(compressionQuality: 0.7), data.count <= 64 * 1024 {
            message.thumbData = data
        }
        let request = SendMessageToWXReq()
        request.message = message
        request.bText = false
        request.scene = 0
        send(request, from: presenter)
    }

    static func register() {
        guard let link = Bundle.main.object(forInfoDictionaryKey: "WeChatUniversalLink") as? String,
              let url = URL(string: link), url.scheme == "https", url.host != nil else {
            print("WeChat: configure WECHAT_UNIVERSAL_LINK in Config/Local.xcconfig before sharing.")
            return
        }
        isRegistered = WXApi.registerApp(wechatKey, universalLink: link)
        if !isRegistered { print("WeChat: SDK registration failed.") }
    }

    static func send(_ request: SendMessageToWXReq, from presenter: UIViewController) {
        guard WXApi.isWXAppInstalled() else {
            showError("请先安装微信，再使用微信分享。", from: presenter)
            return
        }
        guard isRegistered else {
            showError("微信分享配置未完成，请配置微信开放平台的 Universal Link 后重新打包。", from: presenter)
            return
        }
        WXApi.send(request) { [weak presenter] success in
            guard !success else { return }
            DispatchQueue.main.async {
                guard let presenter = presenter else { return }
                showError("无法发起微信分享，请检查微信版本及应用的微信开放平台配置。", from: presenter)
            }
        }
    }

    static func showError(_ message: String, from presenter: UIViewController) {
        guard presenter.presentedViewController == nil else { return }
        let alert = UIAlertController(title: "微信分享", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好", style: .default))
        presenter.present(alert, animated: true)
    }
}
