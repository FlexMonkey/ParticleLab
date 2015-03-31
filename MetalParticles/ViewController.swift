//
//  ViewController.swift
//  MetalParticles
//
//  Created by Simon Gladman on 17/01/2015.
//  Copyright (c) 2015 Simon Gladman. All rights reserved.
//
//  Reengineered based on technique from http://memkite.com/blog/2014/12/30/example-of-sharing-memory-between-gpu-and-cpu-with-swift-and-metal-for-ios8/
//
//  Thanks to https://twitter.com/atveit for tips - espewcially using float4x4!!!
//  Thanks to https://twitter.com/warrenm for examples, especially implemnting matrix 4x4 in Swift

import UIKit
import Metal
import QuartzCore
import CoreData

class ViewController: UIViewController
{
    let imageSide: UInt = 1024
    
    let bytesPerRow = UInt(4 * 1024)
    
    var kernelFunction: MTLFunction!
    var pipelineState: MTLComputePipelineState!
    var defaultLibrary: MTLLibrary! = nil
    var device: MTLDevice! = nil
    var commandQueue: MTLCommandQueue! = nil
    
    let metalLayer = CAMetalLayer()
    
    var region: MTLRegion = MTLRegionMake2D(0, 0, Int(1024), Int(1024))
    
    let blankBitmapRawData = [UInt8](count: Int(1024 * 1024 * 4), repeatedValue: 0)
    
    var errorFlag:Bool = false
    
    var particle_threadGroupCount:MTLSize!
    var particle_threadGroups:MTLSize!
    
    let particleCount: Int = 1048576 // 4194304 2097152   1048576  524288
    var particlesMemory:UnsafeMutablePointer<Void> = nil
    let alignment:UInt = 0x4000
    let particlesMemoryByteSize:UInt = UInt(1048576) * UInt(sizeof(Particle))
    var particlesVoidPtr: COpaquePointer!
    var particlesParticlePtr: UnsafeMutablePointer<Particle>!
    var particlesParticleBufferPtr: UnsafeMutableBufferPointer<Particle>!
    
    var gravityWellAngle: Float = 0.0
    
    var gravityWellParticle = Particle(A: Vector4(x: 0, y: 0, z: 0, w: 0),
        B: Vector4(x: 0, y: 0, z: 0, w: 0),
        C: Vector4(x: 0, y: 0, z: 0, w: 0),
        D: Vector4(x: 0, y: 0, z: 0, w: 0))
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.blackColor()
        
        view.layer.addSublayer(metalLayer)
        
        metalLayer.framebufferOnly = false
        metalLayer.drawableSize = CGSize(width: 1024, height: 1024);
        metalLayer.drawsAsynchronously = true
        
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
            var positionAX = Float(arc4random() % UInt32(imageSide))
            var positionAY = Float(arc4random() % UInt32(imageSide))
            let velocityAX = (Float(arc4random() % 10) - 5) / 10.0
            let velocityAY = (Float(arc4random() % 10) - 5) / 10.0
            
            var positionBX = Float(arc4random() % UInt32(imageSide))
            var positionBY = Float(arc4random() % UInt32(imageSide))
            let velocityBX = (Float(arc4random() % 10) - 5) / 10.0
            let velocityBY = (Float(arc4random() % 10) - 5) / 10.0
            
            var positionCX = Float(arc4random() % UInt32(imageSide))
            var positionCY = Float(arc4random() % UInt32(imageSide))
            let velocityCX = (Float(arc4random() % 10) - 5) / 10.0
            let velocityCY = (Float(arc4random() % 10) - 5) / 10.0
            
            var positionDX = Float(arc4random() % UInt32(imageSide))
            var positionDY = Float(arc4random() % UInt32(imageSide))
            let velocityDX = (Float(arc4random() % 10) - 5) / 10.0
            let velocityDY = (Float(arc4random() % 10) - 5) / 10.0
       
            let positionRule = Int(arc4random() % 4)
            
            if positionRule == 0
            {
                positionAX = 0
                positionBX = 0
                positionCX = 0
                positionDX = 0
            }
            else if positionRule == 1
            {
                positionAX = Float(imageSide)
                positionBX = Float(imageSide)
                positionCX = Float(imageSide)
                positionDX = Float(imageSide)
            }
            else if positionRule == 2
            {
                positionAY = 0
                positionBY = 0
                positionCY = 0
                positionDY = 0
            }
            else
            {
                positionAY = Float(imageSide)
                positionBY = Float(imageSide)
                positionCY = Float(imageSide)
                positionDY = Float(imageSide)
            }
            
            let particle = Particle(A: Vector4(x: positionAX, y: positionAY, z: velocityAX, w: velocityAY),
                B: Vector4(x: positionBX, y: positionBY, z: velocityBX, w: velocityBY),
                C: Vector4(x: positionCX, y: positionCY, z: velocityCX, w: velocityCY),
                D: Vector4(x: positionDX, y: positionDY, z: velocityDX, w: velocityDY))
            
            particlesParticleBufferPtr[index] = particle
        }
    }
    
    var copiedTexture: MTLTexture!
    
    func setUpMetal()
    {
        device = MTLCreateSystemDefaultDevice()
        
        metalLayer.device = device
        
        if device == nil
        {
            errorFlag = true
        }
        else
        {
            // let textureDescriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(MTLPixelFormat.BGRA8Unorm, width: Int(imageSide), height: Int(imageSide), mipmapped: false)
            
            // copiedTexture = device.newTextureWithDescriptor(textureDescriptor)
            // copiedTexture.framebufferOnly = false
            
            region = MTLRegionMake2D(0, 0, Int(imageSide), Int(imageSide))
            
            
            defaultLibrary = device.newDefaultLibrary()
            commandQueue = device.newCommandQueue()
            
            kernelFunction = defaultLibrary.newFunctionWithName("particleRendererShader")
            pipelineState = device.newComputePipelineStateWithFunction(kernelFunction!, error: nil)
            
            let threadExecutionWidth = pipelineState.threadExecutionWidth
            
            particle_threadGroupCount = MTLSize(width:threadExecutionWidth,height:1,depth:1)
            particle_threadGroups = MTLSize(width:(particleCount + threadExecutionWidth - 1) / threadExecutionWidth, height:1, depth:1)
            
            frameStartTime = CFAbsoluteTimeGetCurrent()
            
            run()
        }
    }
    
    var frameStartTime: CFAbsoluteTime!
    var frameNumber = 0
    
    final func run()
    {
        frameNumber++
        
        if frameNumber == 100
        {
            let frametime = (CFAbsoluteTimeGetCurrent() - frameStartTime) / 100
            println(NSString(format: "%.1f", 1 / frametime) + "fps" )
            
            frameStartTime = CFAbsoluteTimeGetCurrent()
            
            frameNumber = 0
        }
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0),
            {
                self.applyShader()
                dispatch_async(dispatch_get_main_queue(),
                    {
                        self.run();
                });
        });
    }
    
    var imageBytes = [UInt8](count: Int(1024 * 1024 * 4), repeatedValue: 0)
    
    let particleSize = sizeof(Particle)
    
    final func applyShader()
    {
        let commandBuffer = commandQueue.commandBuffer()
        let commandEncoder = commandBuffer.computeCommandEncoder()
        
        commandEncoder.setComputePipelineState(pipelineState)
        
        let particlesBufferNoCopy = device.newBufferWithBytesNoCopy(particlesMemory, length: Int(particlesMemoryByteSize),
            options: nil, deallocator: nil)
        
        commandEncoder.setBuffer(particlesBufferNoCopy, offset: 0, atIndex: 0)
        commandEncoder.setBuffer(particlesBufferNoCopy, offset: 0, atIndex: 1)
        
        gravityWellAngle += 0.06
        gravityWellParticle.A.x = 512 + 35 * sin(gravityWellAngle)
        gravityWellParticle.A.y = 512 + 35 * cos(gravityWellAngle)
        
        gravityWellParticle.B.x = gravityWellParticle.A.x + 35 * sin(0 - gravityWellAngle / 1.5)
        gravityWellParticle.B.y = gravityWellParticle.A.y + 35 * cos(0 - gravityWellAngle / 1.5)
        
        var inGravityWell = device.newBufferWithBytes(&gravityWellParticle, length: particleSize, options: nil)
        commandEncoder.setBuffer(inGravityWell, offset: 0, atIndex: 2)
        
        let drawable = metalLayer.nextDrawable()
        
        if let drawable = drawable
        {
            /*
            let blitCommandBuffer = commandQueue.commandBuffer()
            let blitCommandEncoder = blitCommandBuffer.blitCommandEncoder()
            blitCommandEncoder.copyFromTexture(drawable.texture, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0), sourceSize: MTLSize(width: 1024, height: 1024, depth: 1), toTexture: copiedTexture, destinationSlice: 0, destinationLevel: 0, destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
            
            blitCommandEncoder.endEncoding()
            */
            
            // works, but is slow - use blitCommandEncoder()
            /*
            drawable.texture.getBytes(&imageBytes, bytesPerRow: Int(bytesPerRow), fromRegion: region, mipmapLevel: 0)
            copiedTexture.replaceRegion(self.region, mipmapLevel: 0, withBytes: imageBytes, bytesPerRow: Int(bytesPerRow))
            */
            
            
            drawable.texture.replaceRegion(self.region, mipmapLevel: 0, withBytes: blankBitmapRawData, bytesPerRow: Int(bytesPerRow))
            commandEncoder.setTexture(drawable.texture, atIndex: 0)
            
            /*
            commandEncoder.setTexture(copiedTexture, atIndex: 1)
            */
            
            commandEncoder.dispatchThreadgroups(particle_threadGroups, threadsPerThreadgroup: particle_threadGroupCount)
            
            commandEncoder.endEncoding()
            
            commandBuffer.commit()
            
            // commandBuffer.waitUntilScheduled()
            
            drawable.present()
        }
        else
        {
            commandEncoder.endEncoding()
            
            println("metalLayer.nextDrawable() returned nil")
        }
        
    }
    
    override func viewDidLayoutSubviews()
    {
        if view.frame.height > view.frame.width
        {
            let imageSide = view.frame.width
            
            metalLayer.frame = CGRect(x: 0, y: view.frame.height / 2.0 - imageSide / 2, width: imageSide, height: imageSide).rectByInsetting(dx: -1, dy: 01)
        }
        else
        {
            let imageSide = view.frame.height
            
            metalLayer.frame = CGRect(x: view.frame.width / 2.0 - imageSide / 2 , y: 0, width: imageSide, height: imageSide).rectByInsetting(dx: -1, dy: -1)
        }
    }
    
    override func didReceiveMemoryWarning()
    {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
}

struct Particle // Matrix4x4
{
    var A: Vector4 = Vector4(x: 0, y: 0, z: 0, w: 0)
    var B: Vector4 = Vector4(x: 0, y: 0, z: 0, w: 0)
    var C: Vector4 = Vector4(x: 0, y: 0, z: 0, w: 0)
    var D: Vector4 = Vector4(x: 0, y: 0, z: 0, w: 0)
}

struct Vector4
{
    var x: Float32 = 0
    var y: Float32 = 0
    var z: Float32 = 0
    var w: Float32 = 0
}





