//
//  ViewController.swift
//  BXQRCodeScaner
//
//  Created by banxi1988 on 11/14/2015.
//  Copyright (c) 2015 banxi1988. All rights reserved.
//

import UIKit
import BXCodeScanner

class ViewController: UIViewController,BXCodeScanViewControllerDelegate,BXReceiptScanViewControllerDelegate{

    @IBOutlet weak var capturedImageView: UIImageView!
    @IBOutlet weak var scanResultLabel: UILabel!
    override func viewDidLoad() {
        super.viewDidLoad()
        scanResultLabel.hidden = true
        capturedImageView.hidden = true
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func scan(sender: AnyObject) {
       let vc = BXCodeScanViewController()
        vc.delegate = self
        showViewController(vc, sender: self)
    }
    @IBAction func scanReceipt(sender: AnyObject) {
        let vc = BXReceiptScanViewController()
        vc.delegate = self
        presentViewController(vc, animated: true, completion: nil)
    }
    
    func codeScanViewControllerDidCanceled(viewController: BXCodeScanViewController) {
        scanResultLabel.hidden = false
        scanResultLabel.text = "扫码取消了"
    }
    
    func codeScanViewController(viewController: BXCodeScanViewController, didRecognizeCode code: String) {
        updateScanResult(code)
    }
    
    func receiptScanViewController(viewController: BXReceiptScanViewController, didCaptureImage data: NSData) {
        capturedImageView.image = UIImage(data: data)
        capturedImageView.hidden = false
    }
    
    
    func updateScanResult(qrcodeString:String){
        // Set Result Label
        let attributedString = NSMutableAttributedString()
        let resultLabelString = NSAttributedString(string: "扫码结果:", attributes: [
            NSFontAttributeName:UIFont.preferredFontForTextStyle(UIFontTextStyleCaption1),
            NSForegroundColorAttributeName:UIColor.grayColor()
            ])
        let resultString = NSAttributedString(string:qrcodeString,attributes:[
            NSFontAttributeName:UIFont.preferredFontForTextStyle(UIFontTextStyleBody),
            NSForegroundColorAttributeName:UIColor.darkTextColor()
            ])
        attributedString.appendAttributedString(resultLabelString)
        attributedString.appendAttributedString(resultString)
        scanResultLabel.attributedText = attributedString
        scanResultLabel.hidden = false
    }
    
}

