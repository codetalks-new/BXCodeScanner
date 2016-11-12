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
        scanResultLabel.isHidden = true
        capturedImageView.isHidden = true
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func scan(_ sender: AnyObject) {
       let vc = BXCodeScanViewController()
        vc.delegate = self
        show(vc, sender: self)
    }
    @IBAction func scanReceipt(_ sender: AnyObject) {
        let vc = BXReceiptScanViewController()
        vc.delegate = self
        present(vc, animated: true, completion: nil)
    }
    
    func codeScanViewControllerDidCanceled(_ viewController: BXCodeScanViewController) {
        scanResultLabel.isHidden = false
        scanResultLabel.text = "扫码取消了"
    }
    
    func codeScanViewController(_ viewController: BXCodeScanViewController, didRecognizeCode code: String) {
        updateScanResult(code)
    }
    
    func receiptScanViewController(_ viewController: BXReceiptScanViewController, didCaptureImage data: Data) {
        capturedImageView.image = UIImage(data: data)
        capturedImageView.isHidden = false
    }
    
    
    func updateScanResult(_ qrcodeString:String){
        // Set Result Label
        let attributedString = NSMutableAttributedString()
        let resultLabelString = NSAttributedString(string: "扫码结果:", attributes: [
            NSFontAttributeName:UIFont.preferredFont(forTextStyle: UIFontTextStyle.caption1),
            NSForegroundColorAttributeName:UIColor.gray
            ])
        let resultString = NSAttributedString(string:qrcodeString,attributes:[
            NSFontAttributeName:UIFont.preferredFont(forTextStyle: UIFontTextStyle.body),
            NSForegroundColorAttributeName:UIColor.darkText
            ])
        attributedString.append(resultLabelString)
        attributedString.append(resultString)
        scanResultLabel.attributedText = attributedString
        scanResultLabel.isHidden = false
    }
    
}

