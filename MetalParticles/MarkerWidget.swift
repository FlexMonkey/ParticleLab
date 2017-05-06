//
//  MarkerWidget.swift
//  MetalParticles
//
//  Created by Simon Gladman on 17/01/2015.
//  Copyright (c) 2015 Simon Gladman. All rights reserved.
//

import Foundation
import UIKit

class MarkerWidget: UIView
{
    override func didMoveToSuperview()
    {
        let cirlce = Circle()
        cirlce.draw()
        
        layer.addSublayer(cirlce)
    }
}

class Circle: CAShapeLayer
{
    func draw()
    {
        fillColor = UIColor.lightGray.cgColor
        
        let ballRect = CGRect(x: -10, y: -10, width: 20, height: 20)
        let ballPath = UIBezierPath(ovalIn: ballRect)
        
        path = ballPath.cgPath
    }
}
