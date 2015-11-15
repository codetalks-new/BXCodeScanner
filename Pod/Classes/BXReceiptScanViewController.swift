//
//  BXReceiptScanViewController.swift
//  Pods
//
//  Created by Haizhen Lee on 15/11/15.
//
//

import UIKit
import AVFoundation

@objc
public protocol BXReceiptScanViewControllerDelegate{
    func receiptScanViewController(viewController:BXReceiptScanViewController,didCaptureImage data:NSData)
    optional func receiptScanViewControllerDidCanceled(viewController:BXReceiptScanViewController)
}

public class BXReceiptScanViewController: UIViewController {

    public init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    let scanFeedbackView = BXScanFeedbackView()
    let scanTipLabel = UILabel()
    
    public let cameraButton = UIButton(type: .System)
    public let flashButton = UIButton(type: .System)
    public let cancelButton = UIButton(type: .System)
    public let showExampleButton = UIButton(type: .System)
    public let exampleImageView = UIImageView(frame: CGRectZero)
    
    public weak var delegate:BXReceiptScanViewControllerDelegate?

    
    public override func loadView() {
        super.loadView()
        for childView in [previewView,scanFeedbackView,exampleImageView, scanTipLabel,cameraButton,flashButton,cancelButton,showExampleButton]{
            self.view.addSubview(childView)
            childView.translatesAutoresizingMaskIntoConstraints = false
        }
        // Setup
        scanTipLabel.text = BXStrings.scan_receipt_tip
        scanTipLabel.textColor = self.view.tintColor
        scanTipLabel.font = UIFont.boldSystemFontOfSize(16)
        
        exampleImageView.hidden = true
        exampleImageView.backgroundColor = UIColor.greenColor()
        
        cameraButton.setTitle("拍摄", forState: .Normal)
        showExampleButton.setTitle("示例", forState: .Normal)
        flashButton.setTitle("闪光", forState: .Normal)
        cancelButton.setTitle("取消", forState: .Normal)
        
        let lgButtonImage = UIImage.circleImageWithColor(UIColor.grayColor(), radius: 28)
        let normalButtonImage = UIImage.circleImageWithColor(UIColor.grayColor(), radius: 22)
       
        cameraButton.setBackgroundImage(lgButtonImage, forState: .Normal)
        showExampleButton.setBackgroundImage(lgButtonImage, forState: .Normal)
        flashButton.setBackgroundImage(normalButtonImage, forState: .Normal)
        
        for button in [cameraButton,showExampleButton,flashButton,cancelButton]{
            button.setTitleColor(UIColor.whiteColor(), forState: .Normal)
        }
        
        cameraButton.addTarget(self, action: "takePicture:", forControlEvents: .TouchUpInside)
        showExampleButton.addTarget(self, action: "toggleShowExample:", forControlEvents: .TouchUpInside)
        cancelButton.addTarget(self, action: "cancel:", forControlEvents: .TouchUpInside)
        flashButton.addTarget(self, action: "toggleFlashMode:", forControlEvents: .TouchUpInside)
        
        scanFeedbackView.scanLineHidden = true
        
        installConstraints()
    }
    
    func installConstraints(){
        scanTipLabel.pinCenter()
        pinEdge(previewView)

        
        showExampleButton.pinCenterY()
        showExampleButton.pinLeading()
        flashButton.pinCenterXToSibling(showExampleButton)
        flashButton.pinBelowSibling(showExampleButton, margin: 16)
        
        cameraButton.pinCenterY()
        cameraButton.pinTrailing()
        cancelButton.pinCenterXToSibling(cameraButton)
        cancelButton.pinBelowSibling(cameraButton, margin: 16)
       
        scanFeedbackView.pinLeadingToSibling(showExampleButton,margin: 8)
        scanFeedbackView.pinTrailingToSibing(cameraButton,margin: 8)
        scanFeedbackView.pinTop(32)
        scanFeedbackView.pinBottom(32)
        
        exampleImageView.pinLeadingToSibling(showExampleButton,margin: 9)
        exampleImageView.pinTrailingToSibing(cameraButton,margin: 9)
        exampleImageView.pinTop(33)
        exampleImageView.pinBottom(33)
        
        
    }
    
    
    public override func updateViewConstraints() {
        super.updateViewConstraints()
        NSLog("\(__FUNCTION__)")
    }
    
    
    // MARK: Scan Support Variable
    let previewView = BXPreviewView()
    let sessionQueue = dispatch_queue_create("session_queue", DISPATCH_QUEUE_SERIAL)
    var videoDeviceInput:AVCaptureDeviceInput?
    var videoDevice:AVCaptureDevice?
    let imageOutput = AVCaptureStillImageOutput()
    var session = AVCaptureSession()
    var sessionRunning = false
    var setupResult = BXCodeSetupResult.Success
    
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        // setup session
        previewView.session = session
        setupResult = .Success
        previewView.previewLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
        
        // UI
        scanTipLabel.textColor = UIColor.whiteColor()
        let cancelButton = UIBarButtonItem(barButtonSystemItem: .Cancel, target: self, action: "cancel:")
        navigationItem.rightBarButtonItem = cancelButton
        
        checkAuthorization()
        setupSession()
    }
    
    @IBAction func cancel(sender:AnyObject){
        self.delegate?.receiptScanViewControllerDidCanceled?(self)
        closeSelf()
    }
    
    @IBAction func takePicture(sender:AnyObject){
        session_async{
            let connection = self.imageOutput.connectionWithMediaType(AVMediaTypeVideo)
            self.imageOutput.captureStillImageAsynchronouslyFromConnection(connection){
                (buffer,error) in
                if buffer != nil{
                    let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(buffer)
                    runInUiThread{
                        self.didCapturedStillImage(imageData)
                    }
                }else{
                    NSLog("Could not capture still image %@",error)
                }
            }
            
        }
    }
    
    func didCapturedStillImage(imageData:NSData){
        self.delegate?.receiptScanViewController(self, didCaptureImage: imageData)
        closeSelf()
    }
    
    @IBAction func toggleShowExample(sender:AnyObject){
        let oldValue = exampleImageView.hidden
        exampleImageView.hidden = !oldValue
    }
    
    @IBAction func toggleFlashMode(sender:AnyObject){
        guard let videoDevice = videoDevice else {
            return
        }
        if !(videoDevice.hasFlash && videoDevice.flashAvailable){
           return
        }
        var availabelModes = Set<AVCaptureFlashMode>()
        for mode in [AVCaptureFlashMode.Auto,.Off,.On]{
            if videoDevice.isFlashModeSupported(mode){
                availabelModes.insert(mode)
            }
        }
        if availabelModes.isEmpty || availabelModes.count <= 1 {
           return
        }
        let oldFlashMode = videoDevice.flashMode
        availabelModes.remove(oldFlashMode)
        let mode = availabelModes.first!
        
        var label = ""
        switch mode{
        case .On:label = "On"
        case .Off:label = "Off"
        case .Auto:label = "Auto"
        }
        session_async{
            do{
                try videoDevice.lockForConfiguration()
            }catch {
                NSLog("unable to lockForConfiguration")
               return
            }
            
            self.session.beginConfiguration()
            videoDevice.flashMode = mode
            self.session.commitConfiguration()
            videoDevice.unlockForConfiguration()
        }
        
        flashButton.setTitle(label, forState: .Normal)
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
            self.videoDevice = videoDevice
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
            
            
            if self.session.canAddOutput(self.imageOutput){
                self.session.addOutput(self.imageOutput)
            }else{
                NSLog("Could not add imageOutput to the session")
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
    
    // MARK: Landscape Support
    
    public override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        return .LandscapeLeft
    }
    
    public override func shouldAutorotate() -> Bool {
        return false
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
        self.view.sendSubviewToBack(previewView)
    }
    
    func stopScanningUI(){
        scanFeedbackView.hidden = true
        
    }
   
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        NSLog("\(__FUNCTION__)")
    }
    
    func rectOfInterest() -> CGRect{
        let bounds = self.view.bounds
        let rect = scanFeedbackView.frame
        let x  = rect.origin.x / bounds.width
        let y = rect.origin.y / bounds.height
        let w = rect.width / bounds.width
        let h = rect.height / bounds.height
        let interestRest = CGRect(x: x, y: y, width: w, height: h)
        return interestRest
        
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
    
    
    
    func closeSelf(){
        if let navCtrl = self.navigationController{
            navCtrl.popViewControllerAnimated(true)
        }else{
            dismissViewControllerAnimated(true, completion: nil)
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
