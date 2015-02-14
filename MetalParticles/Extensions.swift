//
//  Extensions.swift
//  Emergent
//
//  Created by Simon Gladman on 09/02/2015.
//  Copyright (c) 2015 Simon Gladman. All rights reserved.
//

import Foundation
import UIKit

extension Float
{
    func decimalPartToString() -> String
    {
        let formatter = NSNumberFormatter()
        formatter.multiplier = 100
        formatter.allowsFloats = false
        formatter.formatWidth = 2
        formatter.paddingCharacter = "0"
        
        return formatter.stringFromNumber(self)!
    }
}

extension String
{
    subscript (r: Range<Int>) -> NSString
    {
        get
        {
            let startIndex = advance(self.startIndex, r.startIndex)
            let endIndex = advance(startIndex, r.endIndex - r.startIndex)
            
            return self[Range(start: startIndex, end: endIndex)]
        }
    }
}

extension UIImage
{
    func resizeToBoundingSquare(#boundingSquareSideLength : CGFloat) -> UIImage
    {
        let imgScale = self.size.width > self.size.height ? boundingSquareSideLength / self.size.width : boundingSquareSideLength / self.size.height
        let newWidth = self.size.width * imgScale
        let newHeight = self.size.height * imgScale
        let newSize = CGSize(width: newWidth, height: newHeight)
        
        UIGraphicsBeginImageContext(newSize)
        
        self.drawInRect(CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        
        UIGraphicsEndImageContext();
        
        return resizedImage
    }
    
}
