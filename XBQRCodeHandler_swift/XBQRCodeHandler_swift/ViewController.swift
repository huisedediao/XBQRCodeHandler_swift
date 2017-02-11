//
//  ViewController.swift
//  XBQRCodeHandler_swift
//
//  Created by xxb on 2017/2/11.
//  Copyright © 2017年 xxb. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    lazy var qrcodeH:XBQRCodeHandler = {
        //如果非透明模式，摄像机展示的画面为这里设置的rect
        //透明模式下，摄像机画面为参数一传的view
        let qr:XBQRCodeHandler = XBQRCodeHandler(inSuperView: self.view, withCameraPicFrame: CGRect(x: 100, y: 100, width: 100, height: 100))
        qr.delegate = self
        qr.effectiveRect = CGRect(x: 100.0/320, y: 100.0/568, width: 100.0/320, height: 100.0/568)
        //透明模式，除了有效范围，可以看见摄像机画面的其他内容
        qr.clearMode = true
        return qr
    }()
    

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
//        qrcodeH.startRunning()
        
        let str = XBQRCodeHandler.recognizedQRCodeOfImage(UIImage(named: "qrbaidu")!) { (str:String, re:Bool) in
            if re
            {
                print(str)
            
            }
        }
        print(str)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

extension ViewController:XBQRCodeHandlerDelegate{
    internal func qrCodeHandler(_ qrCodeHandler: XBQRCodeHandler, messageString: String) {
        print(messageString)
    }



}

