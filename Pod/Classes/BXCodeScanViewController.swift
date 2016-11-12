//
//  BXCodeScanViewController.swift
//
//  Created by Haizhen Lee on 15/11/14.
//

import UIKit
import AVFoundation
import PinAuto

// For Tool convient method
public extension UIViewController{
   public func openCodeScanViewControllerWithDelegate(_ delegate:BXCodeScanViewControllerDelegate?){
        let vc = BXCodeScanViewController()
        vc.delegate = delegate
        let nvc = UINavigationController(rootViewController: vc)
        present(nvc, animated: true, completion: nil)
    }
}

@objc
public protocol BXCodeScanViewControllerDelegate{
    func codeScanViewController(_ viewController:BXCodeScanViewController,didRecognizeCode code:String)
    @objc optional func codeScanViewControllerDidCanceled(_ viewController:BXCodeScanViewController)
}





open class BXCodeScanViewController:UIViewController,AVCaptureMetadataOutputObjectsDelegate {
    
    public init() {
        super.init(nibName: nil, bundle: nil)
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    var restartButtonItem : UIBarButtonItem?
    open let scanFeedbackView = BXScanFeedbackView()
    open lazy var scanTipLabel: UILabel = {
        let label = UILabel(frame: CGRect.zero)
        label.text = BXStrings.scan_tip
        label.textColor = .white
        label.font = UIFont.boldSystemFont(ofSize: 18)
        return label
    }()
    
    // MARK: Customize Property
    open var scanRectSize = CGSize(width: 208, height: 208)
    open var scanCodeTypes = [
      AVMetadataObjectTypeQRCode,
      AVMetadataObjectTypeAztecCode,
      AVMetadataObjectTypeDataMatrixCode,
  ]
  
  
    open var tipsOnTop = true
    open var tipsMargin :CGFloat = 40
    
    open weak var delegate:BXCodeScanViewControllerDelegate?
    open override func loadView() {
        super.loadView()
        for childView in [previewView,scanFeedbackView, scanTipLabel]{
                self.view.addSubview(childView)
                childView.translatesAutoresizingMaskIntoConstraints = false
        }
        // Setup

        
        installConstraints()
    }
    
    func installConstraints(){
        scanTipLabel.pa_centerX.install()
        previewView.pac_edge()
        scanFeedbackView.pac_center()
        scanFeedbackView.pac_size(scanRectSize)
      if tipsOnTop{
        scanTipLabel.pa_above(scanFeedbackView, offset: 40).install()
      }else{
        scanTipLabel.pa_below(scanFeedbackView, offset: 40).install()
      }
        
    }
    
    
    open override func updateViewConstraints() {
        super.updateViewConstraints()
        NSLog("\(#function)")
    }
    
    
    // MARK: Scan Support Variable
    let previewView = BXPreviewView()
    let sessionQueue = DispatchQueue(label: "session_queue", attributes: [])
    var videoDeviceInput:AVCaptureDeviceInput?
    var session = AVCaptureSession()
    var sessionRunning = false
    var setupResult = BXCodeSetupResult.success
    
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        // prepare
        loadQRCodeCompletedSound()
        // setup session
        setupResult = .success
        previewView.previewLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
       
        // UI
        let cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(BXCodeScanViewController.cancel(_:)))
        navigationItem.rightBarButtonItem = cancelButton
        
        checkAuthorization()
        setupSession()
    }
    
    @IBAction func cancel(_ sender:AnyObject){
        closeSelf()
    }
    
    func setupSession(){
        session_async{
            if self.setupResult != .success{
                return
            }
            guard let videoDevice = self.deviceWithMediaType(AVMediaTypeVideo, preferringPosition: AVCaptureDevicePosition.back) else {
                self.setupResult = .noDevice
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
                    self.previewView.session = self.session
                    let statusBarOrientation = UIApplication.shared.statusBarOrientation
                    var initialVideoOrientation = AVCaptureVideoOrientation.portrait
                    if statusBarOrientation != .unknown{
                       initialVideoOrientation = AVCaptureVideoOrientation(rawValue: statusBarOrientation.rawValue)!
                    }
                    self.previewView.previewLayer?.connection.videoOrientation = initialVideoOrientation
                }
            }else{
                NSLog("Could not add video deviceinput to the session")
                self.setupResult = BXCodeSetupResult.sessionconfigurationFailed
            }
            NSLog("session preset \(self.session.sessionPreset)")
            
            
            let metadataOutput = AVCaptureMetadataOutput()
            if self.session.canAddOutput(metadataOutput){
                let queue = DispatchQueue(label: "myScanOutputQueue", attributes: [])
                metadataOutput.setMetadataObjectsDelegate(self, queue: queue)
                self.session.addOutput(metadataOutput)
              let types: [String] = metadataOutput.availableMetadataObjectTypes as? [String] ?? []
              let availableTypes =  self.scanCodeTypes.filter{types.contains($0)}
                if availableTypes.count > 0{
                    metadataOutput.metadataObjectTypes = availableTypes
                }else{
                    NSLog("QRCode metadataObjectType is not available ,available types \(types)")
                    self.setupResult = .sessionconfigurationFailed
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
                self.setupResult = BXCodeSetupResult.sessionconfigurationFailed
            }
            
            self.session.commitConfiguration()
        }
        
    }
   
    func checkAuthorization(){
        let status = AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo)
        switch status{
        case .authorized:
            if setupResult != .success{
                setupSession()
            }
            break
        case .notDetermined:
            promptAuthorize()
        default:
            setupResult = .notAuthorized // Deny or Restricted
        }
    }
    
    func promptAuthorize(){
        sessionQueue.suspend()
        AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo){
            granted in
            if !granted{
                self.setupResult = BXCodeSetupResult.notAuthorized
            }
            self.sessionQueue.resume()
        }
    }
    
    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        checkAuthorization() // authorization can be change we we are not in front
        self.sessionQueue.async{
            switch self.setupResult{
            case .success:
                self.session.startRunning()
                self.sessionRunning = self.session.isRunning
            case .notAuthorized:
                runInUiThread{
                    self.promptNotAuthorized()
                }
            case .noDevice:
                runInUiThread{
                    self.showTip(BXStrings.error_no_device)
                }
            case .sessionconfigurationFailed:
                runInUiThread{
                    self.showTip(BXStrings.error_session_failed)
                }
            }
        }
    }
    
    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if self.setupResult == .success && self.sessionRunning{
            startScanningUI()
        }
    }
    
    open override func viewWillDisappear(_ animated: Bool) {
        session_async{
            if self.setupResult == .success{
                self.session.stopRunning()
            }
        }
        stopScanningUI()
        super.viewDidDisappear(animated)
    }
   
    override open func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopScanning()
    }
    
    
    open override var supportedInterfaceOrientations : UIInterfaceOrientationMask {
        return .all
    }
    
    open override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        let deviceOrientation = UIDevice.current.orientation
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
    

    
    
    func session_async(_ block:@escaping ()->()){
        self.sessionQueue.async(execute: block)
    }
    
    func startScanningUI(){
        scanFeedbackView.isHidden = false
        scanFeedbackView.animateScanLine()
        self.view.sendSubview(toBack: previewView)
    }
    
    func stopScanningUI(){
        scanFeedbackView.isHidden = true
        scanFeedbackView.stopScanLineAnimation()
        
    }
    
    
    // MARK: Capture Manager
    
    func deviceWithMediaType(_ mediaType:String,preferringPosition:AVCaptureDevicePosition) -> AVCaptureDevice?{
        let devices = AVCaptureDevice.devices(withMediaType: mediaType)
        for obj in devices!{
            if let device = obj as? AVCaptureDevice{
                if device.position == preferringPosition{
                    return device
                }
            }
        }
        return devices?.first as? AVCaptureDevice
    }
    

    
    // MARK : AVCaptureMetadataOutputObjectsDelegate
    var isRecognized = false
    open func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputMetadataObjects metadataObjects: [Any]!, from connection: AVCaptureConnection!) {
        if let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject
            , self.scanCodeTypes.contains(metadataObject.type){
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
    
    func onCodeRecognized(_ codeString:String){
        audioPlayer?.play()
        self.delegate?.codeScanViewController(self, didRecognizeCode: codeString)
        closeSelf()
    }
    
    func closeSelf(){
      let poped = self.navigationController?.popViewController(animated: true)
      if poped == nil{
        dismiss(animated: true, completion: nil)
      }
    }
    

    
    

    // MARK: Recognized Sound Effects
    
    var audioPlayer:AVAudioPlayer?
    func loadQRCodeCompletedSound(){
        let assetBundle = Bundle.main
      guard let soundURL = assetBundle.url(forResource: "qrcode_completed", withExtension: "mp3")   else{
        return
      }
        audioPlayer = try? AVAudioPlayer(contentsOf: soundURL)
        if audioPlayer == nil{
            NSLog("unable to read qrcode_completed file")
        }else{
            audioPlayer?.prepareToPlay()
        }
        
    }
    
    
    // MARK: State Restoration
    open override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
        coder.encode(sessionRunning, forKey: BXCoderKey.sessionRunning)
    }
    
    open override func decodeRestorableState(with coder: NSCoder) {
        super.decodeRestorableState(with: coder)
    }
    
}
