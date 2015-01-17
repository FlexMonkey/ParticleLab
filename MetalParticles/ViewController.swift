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
    
    var region: MTLRegion!
    var textureA: MTLTexture!
    // var textureB: MTLTexture!
    
    var image:UIImage!
    var errorFlag:Bool = false
    
    var threadGroupCount:MTLSize!
    var threadGroups: MTLSize!
    
    let particleCount: Int = 100000
    var particles = [Particle]()

    override func viewDidLoad()
    {
        super.viewDidLoad()

        imageView.contentMode = UIViewContentMode.ScaleAspectFit
        
        view.addSubview(imageView)
        
        setUpParticles()
        
        setUpMetal()
    }
    
    func setUpParticles()
    {
        for _ in 0 ..< particleCount
        {
            let positionX = Float(arc4random() % 640)
            let positionY = Float(arc4random() % 640)
            let velocityX = (Float(arc4random() % 10) - 5) / 10.0
            let velocityY = (Float(arc4random() % 10) - 5) / 10.0
         
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
                // self.image = self.applyFilter()
                
                self.applyShader()
            }
            .main
            {
                self.imageView.image = self.image
                
                self.textureA.replaceRegion(self.region, mipmapLevel: 0, withBytes: self.blankBitmapRawData, bytesPerRow: Int(self.bytesPerRow))
                
                self.run();
        }
    }
    
    let blankBitmapRawData = [UInt8](count: Int(640 * 640 * 4), repeatedValue: 0)
    
    func applyShader()
    {
        let commandBuffer = commandQueue.commandBuffer()
        let commandEncoder = commandBuffer.computeCommandEncoder()
        
        commandEncoder.setComputePipelineState(pipelineState)
        
        var particleVectorByteLength = particles.count*sizeofValue(particles[0])
        
        var buffer: MTLBuffer = device.newBufferWithBytes(&particles, length: particleVectorByteLength, options: nil)
        commandEncoder.setBuffer(buffer, offset: 0, atIndex: 0)
        
        var inVectorBuffer = device.newBufferWithBytes(&particles, length: particleVectorByteLength, options: nil)
        commandEncoder.setBuffer(inVectorBuffer, offset: 0, atIndex: 0)
        
        
        
        var resultdata = [Particle](count:particles.count, repeatedValue: Particle(positionX: 0, positionY: 0, velocityX: 0, velocityY: 0))
        var outVectorBuffer = device.newBufferWithBytes(&resultdata, length: particleVectorByteLength, options: nil)
        commandEncoder.setBuffer(outVectorBuffer, offset: 0, atIndex: 1)
      
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
        
       region = MTLRegionMake2D(0, 0, Int(640), Int(640))
    }


    override func viewDidLayoutSubviews()
    {
        imageView.frame = CGRect(x: 0, y: 0, width: 640, height: 640)
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

