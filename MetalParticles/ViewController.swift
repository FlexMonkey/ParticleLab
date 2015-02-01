//
//  ViewController.swift
//  MetalParticles
//
//  Created by Simon Gladman on 17/01/2015.
//  Copyright (c) 2015 Simon Gladman. All rights reserved.
//
//  Reengineered based on technique from http://memkite.com/blog/2014/12/30/example-of-sharing-memory-between-gpu-and-cpu-with-swift-and-metal-for-ios8/

import UIKit
import Metal
import QuartzCore
import CoreData

class ViewController: UIViewController
{
    
    let bitmapInfo = CGBitmapInfo(CGBitmapInfo.ByteOrder32Big.rawValue | CGImageAlphaInfo.PremultipliedLast.rawValue)
    let renderingIntent = kCGRenderingIntentDefault
    
    let imageSide: UInt = 800
    let imageSize = CGSize(width: Int(800), height: Int(800))
    let imageByteCount = Int(800 * 800 * 4)
    
    let bytesPerPixel = UInt(4)
    let bitsPerComponent = UInt(8)
    let bitsPerPixel:UInt = 32
    let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
    
    let bytesPerRow = UInt(4 * 800)
    let bytesPerRowInt = Int(4 * 800)
    let providerLength = Int(800 * 800 * 4) * sizeof(UInt8)
    var imageBytes = [UInt8](count: Int(800 * 800 * 4), repeatedValue: 0)
    let blankBitmapRawData = [UInt8](count: Int(800 * 800 * 4), repeatedValue: 0)
    
    var kernelFunction: MTLFunction!
    var pipelineState: MTLComputePipelineState!
    var defaultLibrary: MTLLibrary! = nil
    var device: MTLDevice! = nil
    var commandQueue: MTLCommandQueue! = nil
    
    let imageView =  UIImageView(frame: CGRectZero)
    
    var region: MTLRegion!
    // var particlesTexture: MTLTexture!
    
    var textureA: MTLTexture!
    var textureB: MTLTexture!

    var errorFlag:Bool = false
 
    var particle_threadGroupCount:MTLSize!
    var particle_threadGroups:MTLSize!
    
    var glow_threadGroupCount:MTLSize!
    var glow_threadGroups: MTLSize!
    
    let particleCount: Int = 4096
    var particlesMemory:UnsafeMutablePointer<Void> = nil
    let alignment:UInt = 0x4000
    let particlesMemoryByteSize:UInt = UInt(4096) * UInt(sizeof(Particle))
    var particlesVoidPtr: COpaquePointer!
    var particlesParticlePtr: UnsafeMutablePointer<Particle>!
    var particlesParticleBufferPtr: UnsafeMutableBufferPointer<Particle>!

    var frameStartTime = CFAbsoluteTimeGetCurrent()
    
    let useGlowAndTrails = false

    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.blackColor()

        imageView.contentMode = UIViewContentMode.ScaleAspectFill

        view.addSubview(imageView)
        
        setUpParticles()
        
        setUpMetal()
    }
    
    func setUpParticles()
    {
        posix_memalign(&particlesMemory, alignment, particlesMemoryByteSize)
        
        particlesVoidPtr = COpaquePointer(particlesMemory)
        particlesParticlePtr = UnsafeMutablePointer<Particle>(particlesVoidPtr)
        particlesParticleBufferPtr = UnsafeMutableBufferPointer(start: particlesParticlePtr, count: particleCount)
 
        for index in particlesParticleBufferPtr.startIndex ..< particlesParticleBufferPtr.endIndex
        {
            var positionX = Float(arc4random_uniform(UInt32(imageSide)))
            var positionY = Float(arc4random_uniform(UInt32(imageSide)))
            let velocityX: Float = 0.0
            let velocityY: Float = 0.0

            let particle = Particle(positionX: positionX, positionY: positionY, velocityX: velocityX, velocityY: velocityY, velocityX2: velocityX, velocityY2: velocityY, type: Float(index % 3))
    
            particlesParticleBufferPtr[index] = particle
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
   
            particle_threadGroupCount = MTLSize(width:32,height:1,depth:1)
            particle_threadGroups = MTLSize(width:(particleCount + 31) / 32, height:1, depth:1)
      
            glow_threadGroupCount = MTLSizeMake(16, 16, 1)
            glow_threadGroups = MTLSizeMake(Int(imageSide) / glow_threadGroupCount.width, Int(imageSide) / glow_threadGroupCount.height, 1)

            
            setUpTexture()
            
            kernelFunction = defaultLibrary.newFunctionWithName("particleRendererShader")
            pipelineState = device.newComputePipelineStateWithFunction(kernelFunction!, error: nil)
            
            run()
        }
    }

    final func run()
    {
        let frametime = CFAbsoluteTimeGetCurrent() - frameStartTime
        println("frametime: " + NSString(format: "%.6f", frametime) + " = " + NSString(format: "%.1f", 1 / frametime) + "fps" )
        
        frameStartTime = CFAbsoluteTimeGetCurrent()
  
        Async.background()
        {
            self.applyShader()
        }
        .main
        {
            self.run();
        }
    }
    
    final func glowTexture()
    {
        commandQueue = device.newCommandQueue()
        
        kernelFunction = defaultLibrary.newFunctionWithName("glowShader")
        pipelineState = device.newComputePipelineStateWithFunction(kernelFunction!, error: nil)
        
        let commandBuffer = commandQueue.commandBuffer()
        let commandEncoder = commandBuffer.computeCommandEncoder()
        
        commandEncoder.setComputePipelineState(pipelineState)
        
        commandEncoder.setTexture(textureA, atIndex: 0)
        commandEncoder.setTexture(textureA, atIndex: 1)
        commandEncoder.setTexture(textureB, atIndex: 2)
        
        commandEncoder.dispatchThreadgroups(glow_threadGroups, threadsPerThreadgroup: glow_threadGroupCount)
        
        commandEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
    }
    
    final func applyShader()
    {
        textureB.replaceRegion(self.region, mipmapLevel: 0, withBytes: blankBitmapRawData, bytesPerRow: Int(bytesPerRow))

        kernelFunction = defaultLibrary.newFunctionWithName("particleRendererShader")
        pipelineState = device.newComputePipelineStateWithFunction(kernelFunction!, error: nil)
        
        let commandBuffer = commandQueue.commandBuffer()
        let commandEncoder = commandBuffer.computeCommandEncoder()
        
        commandEncoder.setComputePipelineState(pipelineState)

        let particlesBufferNoCopy = device.newBufferWithBytesNoCopy(particlesMemory, length: Int(particlesMemoryByteSize),
            options: nil, deallocator: nil)
        
        commandEncoder.setBuffer(particlesBufferNoCopy, offset: 0, atIndex: 0)
        commandEncoder.setBuffer(particlesBufferNoCopy, offset: 0, atIndex: 1)
  
        commandEncoder.setTexture(textureB, atIndex: 0)
        commandEncoder.setTexture(textureB, atIndex: 1)
        
        commandEncoder.dispatchThreadgroups(particle_threadGroups, threadsPerThreadgroup: particle_threadGroupCount)
        
        commandEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        if useGlowAndTrails
        {
            glowTexture()
            textureA.getBytes(&imageBytes, bytesPerRow: bytesPerRowInt, fromRegion: region, mipmapLevel: 0)
        }
        else
        {
            textureB.getBytes(&imageBytes, bytesPerRow: bytesPerRowInt, fromRegion: region, mipmapLevel: 0)
        }
        
        var imageRef: CGImage?
        
        Async.background()
        {
            let providerRef = CGDataProviderCreateWithCFData(NSData(bytes: &self.imageBytes, length: self.providerLength))
            
            imageRef = CGImageCreate(self.imageSide, self.imageSide, self.bitsPerComponent, self.bitsPerPixel, self.bytesPerRow, self.rgbColorSpace, self.bitmapInfo, providerRef, nil, false, self.renderingIntent)
        }
        .main
        {
            self.imageView.image = UIImage(CGImage: imageRef)!
        }
  
    }
    
    func setUpTexture()
    {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(MTLPixelFormat.RGBA8Unorm, width: Int(imageSide), height: Int(imageSide), mipmapped: false)
        
        textureA = device.newTextureWithDescriptor(textureDescriptor)
        textureB = device.newTextureWithDescriptor(textureDescriptor)
        
       region = MTLRegionMake2D(0, 0, Int(imageSide), Int(imageSide))
    }


    override func viewDidLayoutSubviews()
    {
        if view.frame.height > view.frame.width
        {
           let imageSide = view.frame.width
            
           imageView.frame = CGRect(x: 0, y: view.frame.height / 2.0 - imageSide / 2, width: imageSide, height: imageSide).rectByInsetting(dx: -1, dy: 01)
        }
        else
        {
            let imageSide = view.frame.height
            
            imageView.frame = CGRect(x: view.frame.width / 2.0 - imageSide / 2 , y: 0, width: imageSide, height: imageSide).rectByInsetting(dx: -1, dy: -1)
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
    var velocityX2: Float = 0
    var velocityY2: Float = 0
    var type: Float = 0
}

