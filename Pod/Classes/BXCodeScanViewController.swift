//
//  BXCodeScanViewController.swift
//
//  Created by Haizhen Lee on 15/11/14.
//

import UIKit
import AVFoundation
import PinAutoLayout

// For Tool convient method
public extension UIViewController{
   public func openCodeScanViewControllerWithDelegate(delegate:BXCodeScanViewControllerDelegate?){
        let vc = BXCodeScanViewController()
        vc.delegate = delegate
        let nvc = UINavigationController(rootViewController: vc)
        presentViewController(nvc, animated: true, completion: nil)
    }
}

@objc
public protocol BXCodeScanViewControllerDelegate{
    func codeScanViewController(viewController:BXCodeScanViewController,didRecognizeCode code:String)
    optional func codeScanViewControllerDidCanceled(viewController:BXCodeScanViewController)
}





public class BXCodeScanViewController:UIViewController,AVCaptureMetadataOutputObjectsDelegate {
    
    public init() {
        super.init(nibName: nil, bundle: nil)
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    var restartButtonItem : UIBarButtonItem?
    public let scanFeedbackView = BXScanFeedbackView()
    public lazy var scanTipLabel: UILabel = {
        let label = UILabel(frame: CGRectZero)
        label.text = BXStrings.scan_tip
        label.textColor = .whiteColor()
        label.font = UIFont.boldSystemFontOfSize(18)
        return label
    }()
    
    // MARK: Customize Property
    public var scanRectSize = CGSize(width: 208, height: 208)
    public var scanCodeTypes = [
      AVMetadataObjectTypeQRCode,
      AVMetadataObjectTypeAztecCode,
      AVMetadataObjectTypeDataMatrixCode,
  ]
  
  
    public var tipsOnTop = true
    public var tipsMargin :CGFloat = 40
    
    public weak var delegate:BXCodeScanViewControllerDelegate?
    public override func loadView() {
        super.loadView()
        for childView in [previewView,scanFeedbackView, scanTipLabel]{
                self.view.addSubview(childView)
                childView.translatesAutoresizingMaskIntoConstraints = false
        }
        // Setup

        
        installConstraints()
    }
    
    func installConstraints(){
        scanTipLabel.pinCenterX()
        pinEdge(previewView)
        scanFeedbackView.pinCenter()
        scanFeedbackView.pinSize(scanRectSize)
      if tipsOnTop{
        scanTipLabel.pinAboveSibling(scanFeedbackView, margin: 40)
      }else{
        scanTipLabel.pinBelowSibling(scanFeedbackView, margin: 40)
      }
        
    }
    
    
    public override func updateViewConstraints() {
        super.updateViewConstraints()
        NSLog("\(__FUNCTION__)")
    }
    
    
    // MARK: Scan Support Variable
    let previewView = BXPreviewView()
    let sessionQueue = dispatch_queue_create("session_queue", DISPATCH_QUEUE_SERIAL)
    var videoDeviceInput:AVCaptureDeviceInput?
    var session = AVCaptureSession()
    var sessionRunning = false
    var setupResult = BXCodeSetupResult.Success
    
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        // prepare
        loadQRCodeCompletedSound()
        // setup session
        previewView.session = session
        setupResult = .Success
        previewView.previewLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
       
        // UI
        let cancelButton = UIBarButtonItem(barButtonSystemItem: .Cancel, target: self, action: "cancel:")
        navigationItem.rightBarButtonItem = cancelButton
        
        checkAuthorization()
        setupSession()
    }
    
    @IBAction func cancel(sender:AnyObject){
        closeSelf()
    }
    
    func setupSession(){
        session_async{
            if self.setupResult != .Success{
                return
            }
            guard let videoDevice = self.deviceWithMediaType(AVMediaTypeVideo, preferringPosition: AVCaptureDevicePosition.Back) else {
                self.setupResult = .NoDevice
               return
            }
            
            let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice)
            if videoDeviceInput == nil {
                NSLog("Could not create video device input ")
               return
            }
            NSLog("session preset \(self.session.sessionPreset)")
            self.session.beginConfiguration()
            
            if self.session.canAddInput(videoDeviceInput) {
                self.session.addInput(videoDeviceInput)
                self.videoDeviceInput = videoDeviceInput
               
                runInUiThread{
                    let statusBarOrientation = UIApplication.sharedApplication().statusBarOrientation
                    var initialVideoOrientation = AVCaptureVideoOrientation.Portrait
                    if statusBarOrientation != .Unknown{
                       initialVideoOrientation = AVCaptureVideoOrientation(rawValue: statusBarOrientation.rawValue)!
                    }
                    self.previewView.previewLayer?.connection.videoOrientation = initialVideoOrientation
                }
            }else{
                NSLog("Could not add video deviceinput to the session")
                self.setupResult = BXCodeSetupResult.SessionconfigurationFailed
            }
            NSLog("session preset \(self.session.sessionPreset)")
            
            
            let metadataOutput = AVCaptureMetadataOutput()
            if self.session.canAddOutput(metadataOutput){
                let queue = dispatch_queue_create("myScanOutputQueue", DISPATCH_QUEUE_SERIAL)
                metadataOutput.setMetadataObjectsDelegate(self, queue: queue)
                self.session.addOutput(metadataOutput)
              let types: [String] = metadataOutput.availableMetadataObjectTypes as? [String] ?? []
              let availableTypes =  self.scanCodeTypes.filter{types.contains($0)}
                if availableTypes.count > 0{
                    metadataOutput.metadataObjectTypes = availableTypes
                }else{
                    NSLog("QRCode metadataObjectType is not available ,available types \(types)")
                    self.setupResult = .SessionconfigurationFailed
                }
                
                let bounds = self.view.bounds
                
                let x = (bounds.width - self.scanRectSize.width) * 0.5 / bounds.width
                let y = (bounds.height - self.scanRectSize.height) * 0.5 / bounds.height
                let w = self.scanRectSize.width  / bounds.width
                let h = self.scanRectSize.height / bounds.height
                let interestRect = CGRect(x: x, y: y, width: w, height: h)
                NSLog("rectOfInterest \(interestRect)")
//                metadataOutput.rectOfInterest = interestRect
            }else{
                NSLog("Could not add metadata output to the session")
                self.setupResult = BXCodeSetupResult.SessionconfigurationFailed
            }
            
            self.session.commitConfiguration()
        }
        
    }
   
    func checkAuthorization(){
        let status = AVCaptureDevice.authorizationStatusForMediaType(AVMediaTypeVideo)
        switch status{
        case .Authorized:
            if setupResult != .Success{
                setupSession()
            }
            break
        case .NotDetermined:
            promptAuthorize()
        default:
            setupResult = .NotAuthorized // Deny or Restricted
        }
    }
    
    func promptAuthorize(){
        dispatch_suspend(sessionQueue)
        AVCaptureDevice.requestAccessForMediaType(AVMediaTypeVideo){
            granted in
            if !granted{
                self.setupResult = BXCodeSetupResult.NotAuthorized
            }
            dispatch_resume(self.sessionQueue)
        }
    }
    
    public override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        checkAuthorization() // authorization can be change we we are not in front
        dispatch_async(self.sessionQueue){
            switch self.setupResult{
            case .Success:
                self.session.startRunning()
                self.sessionRunning = self.session.running
            case .NotAuthorized:
                runInUiThread{
                    self.promptNotAuthorized()
                }
            case .NoDevice:
                runInUiThread{
                    self.showTip(BXStrings.error_no_device)
                }
            case .SessionconfigurationFailed:
                runInUiThread{
                    self.showTip(BXStrings.error_session_failed)
                }
            }
        }
    }
    
    public override func viewDidAppear(animated: Bool) {
        super.viewDidDisappear(animated)
        if self.setupResult == .Success && self.sessionRunning{
            startScanningUI()
        }
    }
    
    public override func viewWillDisappear(animated: Bool) {
        session_async{
            if self.setupResult == .Success{
                self.session.stopRunning()
            }
        }
        stopScanningUI()
        super.viewDidDisappear(animated)
    }
   
    override public func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        stopScanning()
    }
    
    
    public override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        return .All
    }
    
    public override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)
        let deviceOrientation = UIDevice.currentDevice().orientation
        if deviceOrientation.isPortrait || deviceOrientation.isLandscape{
            if let orientation = AVCaptureVideoOrientation(rawValue: deviceOrientation.rawValue){
                previewView.previewLayer?.connection.videoOrientation = orientation
            }
        }
    }
   
    func stopScanning(){
        session.stopRunning()
        sessionRunning = false
    }
    
    
    struct BXCoderKey{
        static let sessionRunning = "sessionRunning"
    }
    

    
    
    func session_async(block:dispatch_block_t){
        dispatch_async(self.sessionQueue, block)
    }
    
    func startScanningUI(){
        scanFeedbackView.hidden = false
        scanFeedbackView.animateScanLine()
        self.view.sendSubviewToBack(previewView)
    }
    
    func stopScanningUI(){
        scanFeedbackView.hidden = true
        scanFeedbackView.stopScanLineAnimation()
        
    }
    
    
    // MARK: Capture Manager
    
    func deviceWithMediaType(mediaType:String,preferringPosition:AVCaptureDevicePosition) -> AVCaptureDevice?{
        let devices = AVCaptureDevice.devicesWithMediaType(mediaType)
        for obj in devices{
            if let device = obj as? AVCaptureDevice{
                if device.position == preferringPosition{
                    return device
                }
            }
        }
        return devices.first as? AVCaptureDevice
    }
    

    
    // MARK : AVCaptureMetadataOutputObjectsDelegate
    var isRecognized = false
    public func captureOutput(captureOutput: AVCaptureOutput!, didOutputMetadataObjects metadataObjects: [AnyObject]!, fromConnection connection: AVCaptureConnection!) {
        if let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject
            where self.scanCodeTypes.contains(metadataObject.type){
                NSLog("scan result type:\(metadataObject.type) content:\(metadataObject.stringValue)")
                self.stopScanning()
                // 如果不在这里马上停止,那么此结果,因为扫描成功之后,还会有多次回调.
                if isRecognized{
                    // 同时这里没有设置为false,是因为后面也不根据此变量来设置其他值
                    return // 停止得慢可能重复识别
                }
                isRecognized = true
                runInUiThread{
                    self.stopScanningUI()
                    self.onCodeRecognized(metadataObject.stringValue)
                    self.isRecognized = false
                }
        }else{
            NSLog("scan failed")
        }
    }
    
    func onCodeRecognized(codeString:String){
        audioPlayer?.play()
        self.delegate?.codeScanViewController(self, didRecognizeCode: codeString)
        closeSelf()
    }
    
    func closeSelf(){
      let poped = self.navigationController?.popViewControllerAnimated(true)
      if poped == nil{
        dismissViewControllerAnimated(true, completion: nil)
      }
    }
    

    
    

    // MARK: Recognized Sound Effects
    
    var audioPlayer:AVAudioPlayer?
    func loadQRCodeCompletedSound(){
        let bundle = NSBundle(forClass: BXCodeScanViewController.self)
        let bundleURL = bundle.URLForResource("BXCodeScanner", withExtension: "bundle")
        let assetBundle = NSBundle(URL: bundleURL!)
        let soundURL = assetBundle!.URLForResource("qrcode_completed", withExtension: "mp3")
        audioPlayer = try? AVAudioPlayer(contentsOfURL: soundURL!)
        if audioPlayer == nil{
            NSLog("unable to read qrcode_completed file")
        }else{
            audioPlayer?.prepareToPlay()
        }
        
    }
    
    
    // MARK: State Restoration
    public override func encodeRestorableStateWithCoder(coder: NSCoder) {
        super.encodeRestorableStateWithCoder(coder)
        coder.encodeBool(sessionRunning, forKey: BXCoderKey.sessionRunning)
    }
    
    public override func decodeRestorableStateWithCoder(coder: NSCoder) {
        super.decodeRestorableStateWithCoder(coder)
    }
    
}