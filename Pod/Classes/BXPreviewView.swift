//
//  BXPreviewView.swift
//  Pods
//
//  Created by Haizhen Lee on 15/11/14.
//
//

import UIKit
import AVFoundation

class BXPreviewView: UIView{
    var session:AVCaptureSession?{
        set{
            if let layer = previewLayer{
                layer.session = newValue
            }
        }get{
            if let layer = previewLayer{
                return layer.session
            }else{
                return nil
            }
        }
    }
    
    override class func layerClass() -> AnyClass{
        return AVCaptureVideoPreviewLayer.self
    }
    
    var previewLayer:AVCaptureVideoPreviewLayer?{
        return layer as? AVCaptureVideoPreviewLayer
    }
}
