//
//  XBQRCodeHandler.swift
//  XBQRCodeHandler_swift
//
//  Created by xxb on 2017/2/11.
//  Copyright © 2017年 xxb. All rights reserved.
//

import UIKit
import AVFoundation
import MobileCoreServices

protocol XBQRCodeHandlerDelegate:NSObjectProtocol {
    func qrCodeHandler(_ qrCodeHandler:XBQRCodeHandler,messageString:String) -> Void
}

class XBQRCodeHandler: NSObject {
    
    /**
     *  透明模式，除了有效扫描范围，还显示相机画面内的其他内容
     */
    var clearMode = false {
        didSet{
            if preview != nil
            {
                if clearMode == true
                {
                    preview?.frame = (superView?.bounds)!
                    var rect:CGRect = CGRect()
                    let w = preview?.bounds.size.width
                    let h = preview?.bounds.size.height
                    
                    
                    if NSStringFromCGRect(effectiveRect!) == NSStringFromCGRect(CGRect.zero)
                    {
                        output?.rectOfInterest = CGRect(x: 0, y: 0, width: 1, height: 1)
                        rect = (preview?.bounds)!
                    }
                    else
                    {
                        output?.rectOfInterest = CGRect(x: effectiveRect!.origin.y, y: effectiveRect!.origin.x, width: effectiveRect!.size.height, height: effectiveRect!.size.width)
                        rect = CGRect(x: w!*(self.effectiveRect?.origin.x)!, y: h!*(self.effectiveRect?.origin.y)!, width: w!*(self.effectiveRect?.size.width)!, height: h!*effectiveRect!.size.height)
                    }
                    createBackgroundLayerWithClearRect(rect: rect)
                }
                else
                {
                    remodeBackgroundLayer()
                    preview?.frame = frame!
                    output?.rectOfInterest = CGRect(x: 0, y: 0, width: 1, height: 1)
                }
            }
        }
    }
    
    
    /**
     *  有效的扫描范围比例
     *  透明模式下才有效果，非透明模式下，有效范围为摄像机画面范围
     *  例如（0.2，0.2，0.5，0.6），距离左边，距离上边，宽的比例，高的比例
     */
    var effectiveRect:CGRect?
    
    /// 代理
    weak var delegate:XBQRCodeHandlerDelegate?
    
    ///
    var backgroundLayer:CALayer?
    
    
    fileprivate var device:AVCaptureDevice?
    fileprivate var input:AVCaptureDeviceInput?
    fileprivate var output:AVCaptureMetadataOutput?
    fileprivate var session:AVCaptureSession?
    fileprivate var preview:AVCaptureVideoPreviewLayer?
    
    fileprivate var frame:CGRect?
    fileprivate var superView:UIView?
    
    

    /// 生成二维码
    class func createQRForString(qrString: String?, qrImageName: String?) -> UIImage?{
        if let sureQRString = qrString{
            let stringData = sureQRString.data(using: String.Encoding.utf8, allowLossyConversion: false)
            //创建一个二维码的滤镜
            let qrFilter = CIFilter(name: "CIQRCodeGenerator")
            qrFilter?.setValue(stringData, forKey: "inputMessage")
            qrFilter?.setValue("H", forKey: "inputCorrectionLevel")
            let qrCIImage = qrFilter?.outputImage
            
            // 创建一个颜色滤镜,黑白色
            let colorFilter = CIFilter(name: "CIFalseColor")!
            colorFilter.setDefaults()
            colorFilter.setValue(qrCIImage, forKey: "inputImage")
            colorFilter.setValue(CIColor(red: 0, green: 0, blue: 0), forKey: "inputColor0")
            colorFilter.setValue(CIColor(red: 1, green: 1, blue: 1), forKey: "inputColor1")
            // 返回二维码image
            let codeImage = UIImage(ciImage: (colorFilter.outputImage!.applying(CGAffineTransform(scaleX: 5, y: 5))))
            
            // 中间一般放logo
            if let iconImage = UIImage(named: qrImageName!) {
                let rect = CGRect(x: 0, y: 0, width: codeImage.size.width, height: codeImage.size.height)
                
                UIGraphicsBeginImageContext(rect.size)
                codeImage.draw(in: rect)
                let avatarSize = CGSize(width: rect.size.width*0.25, height: rect.size.height*0.25)
                
                let x = (rect.width - avatarSize.width) * 0.5
                let y = (rect.height - avatarSize.height) * 0.5
                iconImage.draw(in: CGRect(x: x, y: y, width: avatarSize.width, height: avatarSize.height))
                
                let resultImage = UIGraphicsGetImageFromCurrentImageContext()
                
                UIGraphicsEndImageContext()
                return resultImage
            }
            return codeImage
        }
        return nil
    }


    
    /// 识别图片二维码
    class func recognizedQRCodeOfImage(_ image:UIImage, complete:((String,Bool) ->Void)) -> String? {
        //1.初始化扫描仪，设置设别类型和识别质量
        var detectorOptions = [String:Any]()
        detectorOptions[CIDetectorAccuracy] = CIDetectorAccuracyHigh
        
        /* CIDetectorTypeFace:识别脸部，CIDetectorTypeRectangle:矩形，CIDetectorTypeQRCode：二维码 CIDetectorTypeText：文字 */
        let qrDetector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: detectorOptions)
        
      
        //2.扫描获取的特征组
        /* CIFeature的子类 CIFaceFeature CIRectangleFeature CIQRCodeFeature CITextFeature */
        let features = qrDetector?.features(in: CIImage(cgImage: image.cgImage!))
        
        
        if (features?.count)! > 0
        {
            let qrCodeFeature:CIQRCodeFeature = features?.first as! CIQRCodeFeature
            
            complete(qrCodeFeature.messageString!,true)

            return qrCodeFeature.messageString!;
        }
        else
        {
            complete("",false)
            return nil;
        }
    }

    
    ///扫描二维码
    /**
     *  参数一：展示在哪个view上
     *  参数而：摄像机画面的展示frame
     */
    init(inSuperView:UIView, withCameraPicFrame frame:CGRect){
        super.init()
        superView = inSuperView
        self.frame = frame
        setupCaptureDevice()
    }
    
    private func setupCaptureDevice() {
        device = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
        var hasError:Bool = false
        do {
            try input = AVCaptureDeviceInput.init(device: device)
        } catch  {
            hasError = true
        }
        
        if hasError == false
        {
            output = AVCaptureMetadataOutput()
            output?.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            
            // Session
            session = AVCaptureSession()
            session?.sessionPreset = AVCaptureSessionPresetHigh
            if (session?.canAddInput(input))! {
                session?.addInput(input!)
            }
            if (session?.canAddOutput(output))! {
                session?.addOutput(output)
            }
            
            output?.metadataObjectTypes = [AVMetadataObjectTypeQRCode,AVMetadataObjectTypeCode39Code,AVMetadataObjectTypeCode128Code,AVMetadataObjectTypeCode39Mod43Code,AVMetadataObjectTypeEAN13Code,AVMetadataObjectTypeEAN8Code,AVMetadataObjectTypeCode93Code]
            //设置识别码
            preview = AVCaptureVideoPreviewLayer.init(session: session!)
            preview?.videoGravity = AVLayerVideoGravityResizeAspectFill
            preview!.frame = clearMode ? superView!.bounds : frame!
            superView?.layer.insertSublayer(preview!, at: 0)
            clearMode = false
            
        }
        else
        {
            let alert = UIAlertView(title: "提示", message: "提示", delegate: self, cancelButtonTitle: "知道了")
            alert.tag = 0
            alert.show()
        }
    }

    

    /**
     *  @brief 扫描识别之后会自动关闭，继续扫描请重新打开
     *  开始扫描
     */
    func startRunning() {
        if (session?.isRunning)! == false {
            session?.startRunning()
        }
    }
    
    /**
     *  结束扫描
     */
    func stopRunning() {
        if (session?.isRunning)! {
            session?.stopRunning()
        }
    }

    private func createBackgroundLayerWithClearRect(rect:CGRect) -> Void {
        remodeBackgroundLayer()
        backgroundLayer = CALayer()
        preview?.addSublayer(backgroundLayer!)
        backgroundLayer?.frame = preview!.bounds;
        backgroundLayer?.backgroundColor = UIColor.gray.withAlphaComponent(0.5).cgColor
        
        //create path
        let path = UIBezierPath(rect: backgroundLayer!.bounds)
        path.append(UIBezierPath(rect: rect).reversing())
        
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path.cgPath
        backgroundLayer?.mask = shapeLayer
    }


    
    private func remodeBackgroundLayer() {
        if backgroundLayer != nil
        {
            backgroundLayer?.removeFromSuperlayer()
            backgroundLayer = nil
        }
    }



}

extension XBQRCodeHandler:AVCaptureMetadataOutputObjectsDelegate{
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputMetadataObjects metadataObjects: [Any]!, from connection: AVCaptureConnection!) {
        
        if metadataObjects == nil || metadataObjects.count == 0 {
//            qrCodeFrameView?.frame = CGRect.zero
//            messageLabel.text = "No QR code is detected"
            return
        }
        
        // Get the metadata object.
        let metadataObj = metadataObjects[0] as! AVMetadataMachineReadableCodeObject
        
        if metadataObj.type == AVMetadataObjectTypeQRCode {
            // If the found metadata is equal to the QR code metadata then update the status label's text and set the bounds
            delegate?.qrCodeHandler(self, messageString: metadataObj.stringValue)
        }

        stopRunning()
    }
}
