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
    return NSBundle.mainBundle().infoDictionary?[bundleNameKey] as? String
}

struct BXStrings{
    static let camera_permission_tip = "请在 iPhone 的 “设置-隐私-相机” 选项中，允许应用访问你的相机"
    static let scan_tip = "对准要扫描的二维码"
    static let scan_receipt_tip = "请将发票完整置入抓取的线框内"
    static let error_no_device = "没有找到可用的摄像头。"
    static let error_session_failed = "无法启动扫描。"
}

enum BXCodeSetupResult:Int{
    case NoDevice
    case Success
    case NotAuthorized
    case SessionconfigurationFailed
}

internal func runInUiThread(block:dispatch_block_t){
    dispatch_async(dispatch_get_main_queue(), block)
}

extension UIViewController{
    
    // MARK: UI Helper
    func showTip(tip:String){
        let alert = UIAlertController(title: "提示", message: tip, preferredStyle: .Alert)
        alert.addAction(UIAlertAction(title: "知道了", style: .Default, handler: nil))
        presentViewController(alert, animated: true, completion: nil)
        
    }
    
    func promptNotAuthorized(){
        let message = BXStrings.camera_permission_tip
        let bundleNameKey = String(kCFBundleNameKey)
        let title = NSBundle.mainBundle().infoDictionary?[bundleNameKey] as? String ?? "提示"
        let alert = UIAlertController(title: title, message: message, preferredStyle: .Alert)
        
        alert.addAction(UIAlertAction(title: "确定", style: .Cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "设置", style: .Default){
            action in
            UIApplication.sharedApplication().openURL(NSURL(string: UIApplicationOpenSettingsURLString)!)
            })
        presentViewController(alert, animated: true, completion: nil)
    }
    
    
}

extension UIImage{
    static func circleImageWithColor(color:UIColor,radius:CGFloat=22) -> UIImage{
        let rect = CGRect(x: 0, y: 0, width: radius * 2, height: radius * 2)
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0)
        let ctx = UIGraphicsGetCurrentContext()
        UIColor.clearColor().setFill()
        CGContextFillRect(ctx, rect)
        let path = UIBezierPath(ovalInRect: rect)
        color.setFill()
        path.fill()
        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return img
    }
}
