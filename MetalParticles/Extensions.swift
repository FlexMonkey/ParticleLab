//
//  Extensions.swift
//  Emergent
//
//  Created by Simon Gladman on 09/02/2015.
//  Copyright (c) 2015 Simon Gladman. All rights reserved.
//

import Foundation
import UIKit
import CoreImage

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


func resizeToBoundingSquare(sourceImage: UIImage, #boundingSquareSideLength : CGFloat) -> UIImage
    {
        let ciContext = CIContext(options: nil)
        
        let imgScale = sourceImage.size.width > sourceImage.size.height ? boundingSquareSideLength / sourceImage.size.width : boundingSquareSideLength / sourceImage.size.height
        let newWidth = sourceImage.size.width * imgScale
        let newHeight = sourceImage.size.height * imgScale
        let newSize = CGSize(width: newWidth, height: newHeight)
        
        UIGraphicsBeginImageContext(newSize)
        
        sourceImage.drawInRect(CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        
        UIGraphicsEndImageContext();
        
        let gammaFilter = CIFilter(name: "CIGammaAdjust")
        gammaFilter.setValue(CIImage(image: resizedImage), forKey: "inputImage")
        gammaFilter.setValue(0.33, forKey: "inputPower")
        let outputImageData = gammaFilter.valueForKey("outputImage") as! CIImage!
        
        let filteredImageRef: CGImage = ciContext.createCGImage(outputImageData, fromRect: outputImageData.extent())
        
        
        return UIImage(CGImage: filteredImageRef)!
    }
    

