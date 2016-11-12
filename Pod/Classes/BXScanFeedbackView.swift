//
//  BXScanFeedbackView.swift
//
//  Created by Haizhen Lee on 15/11/15.
//  Copyright (c) 2015年 banxi1988. All rights reserved.
//

import UIKit

extension CGRect{
  
  var upLeftPoint:CGPoint{
    return CGPoint(x: minX, y: minY)
  }
  
  var upRightPoint:CGPoint{
    return CGPoint(x: maxX, y: minY)
  }
  
  var downLeftPoint:CGPoint{
    return CGPoint(x: minX, y: maxY)
  }
  
  var downRightPoint:CGPoint{
    return CGPoint(x: maxX, y: maxY)
  }
}

open class BXScanFeedbackView:UIView{
  open let scanLineLayer = CAShapeLayer()
  
  public override init(frame:CGRect){
    super.init(frame: frame)
    commonInit()
  }
  
  open var scanLineHidden:Bool{
    get{
      return scanLineLayer.isHidden
    }set{
      scanLineLayer.isHidden = newValue
    }
  }
  
  open var cornerLength :CGFloat = 30{
    didSet{
      setNeedsDisplay()
    }
  }
  
  open var showOutline = true{
    didSet{
      setNeedsDisplay()
    }
  }
  
  func commonInit(){
    backgroundColor = .clear
    scanLineLayer.fillColor = UIColor.red.cgColor
    scanLineLayer.shadowOpacity = 0.7
    scanLineLayer.shadowColor = UIColor(red: 0.9, green: 0.0, blue: 0.0, alpha: 1.0).cgColor
    scanLineLayer.shadowRadius = 3.0
    layer.addSublayer(scanLineLayer)
  }
  
  required public init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }
  
  override open func awakeFromNib() {
    super.awakeFromNib()
    commonInit()
  }
  
  override open func layoutSublayers(of layer: CALayer) {
    super.layoutSublayers(of: layer)
    scanLineLayer.frame = CGRect(x: 0, y: 0, width: bounds.width, height: 1)
    scanLineLayer.path = UIBezierPath(ovalIn: scanLineLayer.frame).cgPath
  }
  
  func animateScanLineWithExplictAnimation(){
    let scanAnim = CABasicAnimation(keyPath: "position.y")
    scanAnim.duration = 1.5
    scanAnim.repeatCount = Float.infinity
    scanAnim.fromValue = 8.0
    scanAnim.toValue = bounds.height - 8
    scanLineLayer.add(scanAnim, forKey: "myScanAnimation")
  }
  
  func stopScanLineAnimation(){
    scanLineLayer.removeAllAnimations()
  }
  
  func animateScanLine(){
    animateScanLineWithExplictAnimation()
  }
  
  var timer:CADisplayLink?
  var scanLineFromY:CGFloat = 0
  var scanLineToY:CGFloat = 0
  var scanLineLastStepTime:CFTimeInterval!
  var scanLineAnimTimeOffset : CFTimeInterval = 0.0
  var scanLineAnimDuration = 2.0
  func animateScanLineWithDisplayLink(){
    timer = CADisplayLink(target: self, selector: #selector(BXScanFeedbackView.scanLineStep))
    //        timer?.frameInterval = 60 * 2
    scanLineToY = bounds.height
    scanLineLastStepTime = CACurrentMediaTime()
    timer?.add(to: RunLoop.main, forMode: RunLoopMode.defaultRunLoopMode)
  }
  
  func interpolate(_ from:CGFloat,to:CGFloat,time:CGFloat) -> CGFloat{
    return (to - from) * time + from
  }
  
  func scanLineStep(){
    let thisStep = CACurrentMediaTime()
    let stepDuration = thisStep - scanLineLastStepTime
    scanLineLastStepTime = thisStep
    scanLineAnimTimeOffset = min(scanLineAnimTimeOffset + stepDuration, scanLineAnimDuration)
    let time = scanLineAnimTimeOffset / scanLineAnimDuration
    let currentY  =  interpolate(scanLineFromY, to: scanLineToY, time: CGFloat(time))
    //        println("current Y \(currentY)")
    scanLineLayer.position = CGPoint(x: scanLineLayer.position.x, y: currentY)
    // reset the offset if we reaching the bottom
    if scanLineAnimTimeOffset >= scanLineAnimDuration{
      scanLineAnimTimeOffset = 0.0
      scanLineLayer.position = CGPoint(x: scanLineLayer.position.x, y: scanLineFromY)
    }
  }
  
  override open func draw(_ rect: CGRect) {
    super.draw(rect)
    if showOutline{
      let outlineRect = rect.insetBy(dx: 1, dy: 1)
      let outlinePath = UIBezierPath(rect: outlineRect)
      outlinePath.lineWidth = 1.0
      UIColor.white.setStroke()
      outlinePath.stroke()
    }
    
    tintColor.set()
    let ctx = UIGraphicsGetCurrentContext()
    let cornerArray :[(startPoint:CGPoint,firstLineMul:CGPoint,secondLineMul:CGPoint)] = [
      (rect.upLeftPoint,CGPoint(x: 1, y: 0),CGPoint(x: 0, y: 1)),
      (rect.upRightPoint,CGPoint(x: -1, y: 0),CGPoint(x: 0, y: 1)),
      (rect.downLeftPoint,CGPoint(x: 1, y: 0),CGPoint(x: 0, y: -1)),
      (rect.downRightPoint,CGPoint(x: -1, y: 0),CGPoint(x: 0, y: -1)),
      ]
    
    for corner in cornerArray{
      let startPoint = corner.startPoint
      let firstEndX = startPoint.x + cornerLength * corner.firstLineMul.x
      let firstEndY = startPoint.y + cornerLength * corner.firstLineMul.y
      ctx?.move(to: CGPoint(x: startPoint.x, y: startPoint.y))
      ctx?.addLine(to: CGPoint(x: firstEndX, y: firstEndY))
      
      let secondEndX = startPoint.x + cornerLength * corner.secondLineMul.x
      let secondEndY = startPoint.y + cornerLength * corner.secondLineMul.y
      ctx?.move(to: CGPoint(x: startPoint.x, y: startPoint.y))
      ctx?.addLine(to: CGPoint(x: secondEndX, y: secondEndY))
      ctx?.setLineWidth(3.0)
      ctx?.strokePath()
    }
  }
  
  open override func tintColorDidChange() {
    super.tintColorDidChange()
    setNeedsDisplay()
  }
  
}
