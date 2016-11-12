//
//  BXReceiptScanViewController.swift
//  Pods
//
//  Created by Haizhen Lee on 15/11/15.
//
//

import UIKit
import AVFoundation
import PinAuto

@objc
public protocol BXReceiptScanViewControllerDelegate{
  func receiptScanViewController(_ viewController:BXReceiptScanViewController,didCaptureImage data:Data)
  @objc optional func receiptScanViewControllerDidCanceled(_ viewController:BXReceiptScanViewController)
}

open class BXReceiptScanViewController: UIViewController {
  
  public init() {
    super.init(nibName: nil, bundle: nil)
  }
  
  required public init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }
  
  open let scanFeedbackView = BXScanFeedbackView()
  open let scanTipLabel = UILabel()
  
  open let cameraButton = UIButton(type: .system)
  open let flashButton = UIButton(type: .system)
  open let cancelButton = UIButton(type: .system)
  open let showExampleButton = UIButton(type: .system)
  open let exampleImageView = UIImageView(frame: CGRect.zero)
  
  open weak var delegate:BXReceiptScanViewControllerDelegate?
  
  
  open override func loadView() {
    super.loadView()
    for childView in [previewView,scanFeedbackView,exampleImageView, scanTipLabel,cameraButton,flashButton,cancelButton,showExampleButton]{
      self.view.addSubview(childView)
      childView.translatesAutoresizingMaskIntoConstraints = false
    }
    // Setup
    scanTipLabel.text = BXStrings.scan_receipt_tip
    scanTipLabel.textColor = self.view.tintColor
    scanTipLabel.font = UIFont.boldSystemFont(ofSize: 16)
    
    exampleImageView.isHidden = true
    exampleImageView.backgroundColor = UIColor.green
    
    cameraButton.setTitle("拍摄", for: UIControlState())
    showExampleButton.setTitle("示例", for: UIControlState())
    flashButton.setTitle("闪光", for: UIControlState())
    cancelButton.setTitle("取消", for: UIControlState())
    
    let lgButtonImage = UIImage.circleImageWithColor(UIColor.gray, radius: 28)
    let normalButtonImage = UIImage.circleImageWithColor(UIColor.gray, radius: 22)
    
    cameraButton.setBackgroundImage(lgButtonImage, for: UIControlState())
    showExampleButton.setBackgroundImage(lgButtonImage, for: UIControlState())
    flashButton.setBackgroundImage(normalButtonImage, for: UIControlState())
    
    for button in [cameraButton,showExampleButton,flashButton,cancelButton]{
      button.setTitleColor(UIColor.white, for: UIControlState())
    }
    
    cameraButton.addTarget(self, action: #selector(BXReceiptScanViewController.takePicture(_:)), for: .touchUpInside)
    showExampleButton.addTarget(self, action: #selector(BXReceiptScanViewController.toggleShowExample(_:)), for: .touchUpInside)
    cancelButton.addTarget(self, action: #selector(BXReceiptScanViewController.cancel(_:)), for: .touchUpInside)
    flashButton.addTarget(self, action: #selector(BXReceiptScanViewController.toggleFlashMode(_:)), for: .touchUpInside)
    
    scanFeedbackView.scanLineHidden = true
    
    installConstraints()
  }
  
  func installConstraints(){
    scanTipLabel.pac_center()
    previewView.pac_edge()
    
    
    showExampleButton.pa_centerY.install()
    showExampleButton.pa_width.eq(64).install()
    showExampleButton.pac_aspectRatio(1)
    showExampleButton.pa_leading.eq(15).install()
    flashButton.pa_centerX.eqTo(showExampleButton).install()
    flashButton.pa_below(showExampleButton, offset: 16).install()
    
    cameraButton.pa_centerY.install()
    cameraButton.pa_trailing.eq(15).install()
    cameraButton.pa_width.eq(64).install()
    cameraButton.pac_aspectRatio(1)
    cancelButton.pa_centerX.eqTo(cameraButton).install()
    cancelButton.pa_below(cameraButton, offset: 16).install()
    
    scanFeedbackView.pa_after(showExampleButton, offset: 8).install()
    scanFeedbackView.pa_before(cameraButton, offset: 8).install()
    scanFeedbackView.pac_vertical(32)
    
    exampleImageView.pa_after(showExampleButton, offset: 9).install()
    exampleImageView.pa_before(cameraButton, offset: 9).install()
    exampleImageView.pac_vertical(33)
    
    
  }
  
  
  open override func updateViewConstraints() {
    super.updateViewConstraints()
    NSLog("\(#function)")
  }
  
  
  // MARK: Scan Support Variable
  let previewView = BXPreviewView()
  let sessionQueue = DispatchQueue(label: "session_queue", attributes: [])
  var videoDeviceInput:AVCaptureDeviceInput?
  var videoDevice:AVCaptureDevice?
  let imageOutput = AVCaptureStillImageOutput()
  var session = AVCaptureSession()
  var sessionRunning = false
  var setupResult = BXCodeSetupResult.success
  
  
  override open func viewDidLoad() {
    super.viewDidLoad()
    // setup session
    previewView.session = session
    setupResult = .success
    previewView.previewLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
    
    // UI
    scanTipLabel.textColor = UIColor.white
    let cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(BXReceiptScanViewController.cancel(_:)))
    navigationItem.rightBarButtonItem = cancelButton
    
    checkAuthorization()
    setupSession()
  }
  
  @IBAction func cancel(_ sender:AnyObject){
    self.delegate?.receiptScanViewControllerDidCanceled?(self)
    closeSelf()
  }
  
  @IBAction func takePicture(_ sender:AnyObject){
    session_async{
      let connection = self.imageOutput.connection(withMediaType: AVMediaTypeVideo)
      self.imageOutput.captureStillImageAsynchronously(from: connection){
        (buffer,error) in
        if buffer != nil{
          let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(buffer)
          runInUiThread{
            self.didCapturedStillImage(imageData!)
          }
        }else{
          NSLog("Could not capture still image \(error)")
        }
      }
      
    }
  }
  
  func didCapturedStillImage(_ imageData:Data){
    self.delegate?.receiptScanViewController(self, didCaptureImage: imageData)
    closeSelf()
  }
  
  @IBAction func toggleShowExample(_ sender:AnyObject){
    let oldValue = exampleImageView.isHidden
    exampleImageView.isHidden = !oldValue
  }
  
  @IBAction func toggleFlashMode(_ sender:AnyObject){
    guard let videoDevice = videoDevice else {
      return
    }
    if !(videoDevice.hasFlash && videoDevice.isFlashAvailable){
      return
    }
    var availabelModes = Set<AVCaptureFlashMode>()
    for mode in [AVCaptureFlashMode.auto,.off,.on]{
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
    case .on:label = "On"
    case .off:label = "Off"
    case .auto:label = "Auto"
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
    
    flashButton.setTitle(label, for: UIControlState())
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
      
      
      if self.session.canAddOutput(self.imageOutput){
        self.session.addOutput(self.imageOutput)
      }else{
        NSLog("Could not add imageOutput to the session")
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
  
  // MARK: Landscape Support
  
  open override var supportedInterfaceOrientations : UIInterfaceOrientationMask {
    return .landscape
  }
  
  open override var shouldAutorotate : Bool {
    return false
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
    self.view.sendSubview(toBack: previewView)
  }
  
  func stopScanningUI(){
    scanFeedbackView.isHidden = true
    
  }
  
  open override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    NSLog("\(#function)")
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
  
  
  
  func closeSelf(){
    if let navCtrl = self.navigationController{
      navCtrl.popViewController(animated: true)
    }else{
      dismiss(animated: true, completion: nil)
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
