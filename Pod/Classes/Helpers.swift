//
//  Helpers.swift
//  Pods
//
//  Created by Haizhen Lee on 15/11/15.
//
//

import Foundation

func currentAppName() ->String?{
    let bundleNameKey = String(kCFBundleNameKey)
    return Bundle.main.infoDictionary?[bundleNameKey] as? String
}

struct BXStrings{
    static let camera_permission_tip = "请在 iPhone 的 “设置-隐私-相机” 选项中，允许应用访问你的相机"
    static let scan_tip = "对准要扫描的二维码"
    static let scan_receipt_tip = "请将发票完整置入抓取的线框内"
    static let error_no_device = "没有找到可用的摄像头。"
    static let error_session_failed = "无法启动扫描。"
}

enum BXCodeSetupResult:Int{
    case noDevice
    case success
    case notAuthorized
    case sessionconfigurationFailed
}

internal func runInUiThread(_ block:@escaping ()->()){
    DispatchQueue.main.async(execute: block)
}

extension UIViewController{
    
    // MARK: UI Helper
    func showTip(_ tip:String){
        let alert = UIAlertController(title: "提示", message: tip, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "知道了", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
        
    }
    
    func promptNotAuthorized(){
        let message = BXStrings.camera_permission_tip
        let bundleNameKey = String(kCFBundleNameKey)
        let title = Bundle.main.infoDictionary?[bundleNameKey] as? String ?? "提示"
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "确定", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "设置", style: .default){
            action in
            UIApplication.shared.openURL(URL(string: UIApplicationOpenSettingsURLString)!)
            })
        present(alert, animated: true, completion: nil)
    }
    
    
}

extension UIImage{
    static func circleImageWithColor(_ color:UIColor,radius:CGFloat=22) -> UIImage{
        let rect = CGRect(x: 0, y: 0, width: radius * 2, height: radius * 2)
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0)
        let ctx = UIGraphicsGetCurrentContext()
        UIColor.clear.setFill()
        ctx?.fill(rect)
        let path = UIBezierPath(ovalIn: rect)
        color.setFill()
        path.fill()
        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return img!
    }
}
