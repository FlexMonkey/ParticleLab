//
//  Extensions.swift
//  MetalParticles
//
//  Created by Simon Gladman on 05/04/2015.
//  Copyright (c) 2015 Simon Gladman. All rights reserved.
//

import UIKit

extension UIColor
{
    func getRGB() -> (redComponent: Float, greenComponent: Float, blueComponent: Float)
    {
        if CGColorGetNumberOfComponents(self.CGColor) == 4
        {
            let colorRef = CGColorGetComponents(self.CGColor);
            
            let redComponent = zeroIfDodgy(Float(colorRef[0]))
            let greenComponent = zeroIfDodgy(Float(colorRef[1]))
            let blueComponent = zeroIfDodgy(Float(colorRef[2]))
            
            return (redComponent: redComponent, greenComponent: greenComponent, blueComponent: blueComponent)
        }
        else
        {
            return (redComponent: 0, greenComponent: 0, blueComponent: 0)
        }
    }
    
    func zeroIfDodgy(value: Float) -> Float
    {
        if isnan(value) || isinf(value)
        {
            return 0
        }
        else
        {
            return value
        }
    }
}
