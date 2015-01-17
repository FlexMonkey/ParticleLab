//
//  ViewController.swift
//  MetalParticles
//
//  Created by Simon Gladman on 17/01/2015.
//  Copyright (c) 2015 Simon Gladman. All rights reserved.
//

import UIKit
import Metal
import QuartzCore
import CoreData

class ViewController: UIViewController
{
    
    let bitmapInfo = CGBitmapInfo(CGBitmapInfo.ByteOrder32Big.rawValue | CGImageAlphaInfo.PremultipliedLast.rawValue)
    let renderingIntent = kCGRenderingIntentDefault
    
    let imageSide: UInt = 640
    let imageSize = CGSize(width: Int(640), height: Int(640))
    let imageByteCount = Int(640 * 640 * 4)
    
    let bytesPerPixel = UInt(4)
    let bitsPerComponent = UInt(8)
    let bitsPerPixel:UInt = 32
    let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
    
    let bytesPerRow = UInt(4 * 640)
    let providerLength = Int(640 * 640 * 4) * sizeof(UInt8)
    var imageBytes = [UInt8](count: Int(640 * 640 * 4), repeatedValue: 0)
    
    var pipelineState: MTLComputePipelineState!
    var defaultLibrary: MTLLibrary! = nil
    var device: MTLDevice! = nil
    var commandQueue: MTLCommandQueue! = nil
    
    let imageView =  UIImageView(frame: CGRectZero)
    let markerWidget = MarkerWidget(frame: CGRectZero)
    
    var region: MTLRegion!
    var textureA: MTLTexture!
    
    var image:UIImage!
    var errorFlag:Bool = false
    
    var threadGroupCount:MTLSize!
    var threadGroups: MTLSize!
    
    let particleCount: Int = 250_000
    var particles = [Particle]()
    
    var gravityWell = CGPoint(x: 320, y: 320)
    let blankBitmapRawData = [UInt8](count: Int(640 * 640 * 4), repeatedValue: 0)

    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.blackColor()

        imageView.contentMode = UIViewContentMode.ScaleAspectFit

        markerWidget.alpha = 0
    
        view.addSubview(imageView)
        view.addSubview(markerWidget)
        
        setUpParticles()
        
        setUpMetal()
    }
    
    override func touchesBegan(touches: NSSet, withEvent event: UIEvent)
    {
        let location = event.allTouches()?.anyObject()?.locationInView(imageView)
        
        if let _location = location
        {
            positionGravityWell(_location)
        }
    }
    
    override func touchesMoved(touches: NSSet, withEvent event: UIEvent)
    {
        let location = event.allTouches()?.anyObject()?.locationInView(imageView)
        
        if let _location = location
        {
            positionGravityWell(_location)
        }
    }
    
    func positionGravityWell(location: CGPoint)
    {
        if markerWidget.alpha == 0
        {
            UIView.animateWithDuration(0.25, animations: {self.markerWidget.alpha = 1})
        }
        
        let imageScale = imageView.frame.width / CGFloat(imageSide)
        
        gravityWell.x = location.x / imageScale
        gravityWell.y = location.y / imageScale
        
        markerWidget.frame = CGRect(x: imageView.frame.origin.x + location.x, y: imageView.frame.origin.y + location.y, width: 0, height: 0)
    }
    
    override func touchesEnded(touches: NSSet, withEvent event: UIEvent)
    {
        UIView.animateWithDuration(1.0, delay: 2.0, options: nil, animations: {self.markerWidget.alpha = 0}, completion: nil)
    }
    
    func setUpParticles()
    {
        for _ in 0 ..< particleCount
        {
            var positionX = Float(arc4random() % UInt32(imageSide))
            var positionY = Float(arc4random() % UInt32(imageSide))
            let velocityX = (Float(arc4random() % 10) - 5) / 10.0
            let velocityY = (Float(arc4random() % 10) - 5) / 10.0
         
            let positionRule = Int(arc4random() % 4)
            
            if positionRule == 0
            {
                positionX = 0
            }
            else if positionRule == 1
            {
                positionX = Float(imageSide)
            }
            else if positionRule == 2
            {
                positionY = 0
            }
            else
            {
                positionY = Float(imageSide)
            }
            
            let particle = Particle(positionX: positionX, positionY: positionY, velocityX: velocityX, velocityY: velocityY)
    
            particles.append(particle)
        }
    }
    
    func setUpMetal()
    {
        device = MTLCreateSystemDefaultDevice()
 
        if device == nil
        {
            errorFlag = true
        }
        else
        {
            defaultLibrary = device.newDefaultLibrary()
            commandQueue = device.newCommandQueue()
            
            let kernelFunction = defaultLibrary.newFunctionWithName("particleRendererShader")
            pipelineState = device.newComputePipelineStateWithFunction(kernelFunction!, error: nil)
            
            threadGroupCount = MTLSizeMake(32, 32, 1)
            threadGroups = MTLSizeMake(Int(imageSide) / threadGroupCount.width, Int(imageSide) / threadGroupCount.height, 1)
            
            setUpTexture()
            
            run()
        }
    }
    
    func run()
    {
        Async.background()
            {
                self.applyShader()
            }
            .main
            {
                self.imageView.image = self.image
                
                self.textureA.replaceRegion(self.region, mipmapLevel: 0, withBytes: self.blankBitmapRawData, bytesPerRow: Int(self.bytesPerRow))
                
                self.run();
        }
    }
    
    
    
    func applyShader()
    {
        commandQueue = device.newCommandQueue()
        
        let kernelFunction = defaultLibrary.newFunctionWithName("particleRendererShader")
        pipelineState = device.newComputePipelineStateWithFunction(kernelFunction!, error: nil)
        
        let commandBuffer = commandQueue.commandBuffer()
        let commandEncoder = commandBuffer.computeCommandEncoder()
        
        commandEncoder.setComputePipelineState(pipelineState)
        
        let particleVectorByteLength = particles.count*sizeofValue(particles[0])
        
        var buffer: MTLBuffer = device.newBufferWithBytes(&particles, length: particleVectorByteLength, options: nil)
        commandEncoder.setBuffer(buffer, offset: 0, atIndex: 0)
        
        var inVectorBuffer = device.newBufferWithBytes(&particles, length: particleVectorByteLength, options: nil)
        commandEncoder.setBuffer(inVectorBuffer, offset: 0, atIndex: 0)
 
        var resultdata = [Particle](count:particles.count, repeatedValue: Particle(positionX: 0, positionY: 0, velocityX: 0, velocityY: 0))
        var outVectorBuffer = device.newBufferWithBytes(&resultdata, length: particleVectorByteLength, options: nil)
        commandEncoder.setBuffer(outVectorBuffer, offset: 0, atIndex: 1)
      
        var gravityWellParticle = Particle(positionX: Float(gravityWell.x), positionY: Float(gravityWell.y), velocityX: 0, velocityY: 0)
        
        var inGravityWell = device.newBufferWithBytes(&gravityWellParticle, length: sizeofValue(gravityWellParticle), options: nil)
        commandEncoder.setBuffer(inGravityWell, offset: 0, atIndex: 2)
        
        commandEncoder.setTexture(textureA, atIndex: 0)
        
        var threadsPerGroup = MTLSize(width:32,height:1,depth:1)
        var numThreadgroups = MTLSize(width:(particles.count+31)/32, height:1, depth:1)
        commandEncoder.dispatchThreadgroups(numThreadgroups, threadsPerThreadgroup: threadsPerGroup)
        
        commandEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        var data = NSData(bytesNoCopy: outVectorBuffer.contents(),
            length: particles.count*sizeof(Particle), freeWhenDone: false)
        var finalResultArray = [Particle](count: particles.count, repeatedValue: Particle(positionX: 0, positionY: 0, velocityX: 0, velocityY: 0))
        data.getBytes(&finalResultArray, length:particles.count * sizeof(Particle))
        
        particles = finalResultArray
     
        textureA.getBytes(&imageBytes, bytesPerRow: Int(bytesPerRow), fromRegion: region, mipmapLevel: 0)
        
        let providerRef = CGDataProviderCreateWithCFData(NSData(bytes: &imageBytes, length: providerLength))
        
        let imageRef = CGImageCreate(UInt(imageSize.width), UInt(imageSize.height), bitsPerComponent, bitsPerPixel, bytesPerRow, rgbColorSpace, bitmapInfo, providerRef, nil, false, renderingIntent)
        
        image =  UIImage(CGImage: imageRef)!
    }

    func setUpTexture()
    {
        var rawData = [UInt8](count: Int(imageSide * imageSide * 4), repeatedValue: 0)
        
        let context = CGBitmapContextCreate(&rawData, imageSide, imageSide, bitsPerComponent, bytesPerRow, rgbColorSpace, bitmapInfo)
        
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(MTLPixelFormat.RGBA8Unorm, width: Int(imageSide), height: Int(imageSide), mipmapped: false)
        
        textureA = device.newTextureWithDescriptor(textureDescriptor)
        
       region = MTLRegionMake2D(0, 0, Int(imageSide), Int(imageSide))
    }


    override func viewDidLayoutSubviews()
    {
        if view.frame.height > view.frame.width
        {
           let imageSide = view.frame.width
            
           imageView.frame = CGRect(x: 0, y: view.frame.height / 2.0 - imageSide / 2, width: imageSide, height: imageSide)
        }
        else
        {
            let imageSide = view.frame.height
            
            imageView.frame = CGRect(x: view.frame.width / 2.0 - imageSide / 2 , y: 0, width: imageSide, height: imageSide)
        }
        
        
    }
    
    override func didReceiveMemoryWarning()
    {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

struct Particle
{
    var positionX: Float = 0
    var positionY: Float = 0
    var velocityX: Float = 0
    var velocityY: Float = 0
}

