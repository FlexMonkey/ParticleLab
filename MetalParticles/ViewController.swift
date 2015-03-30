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
    
    let particleCount: Int = 524288 // 4194304 2097152   1048576  524288
    var particlesMemory:UnsafeMutablePointer<Void> = nil
    let alignment:UInt = 0x4000
    let particlesMemoryByteSize:UInt = UInt(524288) * UInt(sizeof(Particle))
    var particlesVoidPtr: COpaquePointer!
    var particlesParticlePtr: UnsafeMutablePointer<Particle>!
    var particlesParticleBufferPtr: UnsafeMutableBufferPointer<Particle>!
    
    var gravityWellAngle: Float = 0.0
    
    var gravityWellParticle = Particle(positionX: 512, positionY: 512, velocityX: 0, velocityY: 0,
        positionBX: 512, positionBY: 512, velocityBX: 0, velocityBY: 0,
        positionCX: 512, positionCY: 512, velocityCX: 0, velocityCY: 0,
        positionDX: 512, positionDY: 512, velocityDX: 0, velocityDY: 0)
    
    var gravityWellParticleTwo = Particle(positionX: 512, positionY: 512, velocityX: 0, velocityY: 0,
        positionBX: 512, positionBY: 512, velocityBX: 0, velocityBY: 0,
        positionCX: 512, positionCY: 512, velocityCX: 0, velocityCY: 0,
        positionDX: 512, positionDY: 512, velocityDX: 0, velocityDY: 0)
    
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
            var positionX = Float(arc4random() % UInt32(imageSide))
            var positionY = Float(arc4random() % UInt32(imageSide))
            let velocityX = (Float(arc4random() % 10) - 5) / 10.0
            let velocityY = (Float(arc4random() % 10) - 5) / 10.0
            
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
                positionX = 0
                positionBX = 0
                positionCX = 0
                positionDX = 0
            }
            else if positionRule == 1
            {
                positionX = Float(imageSide)
                positionBX = Float(imageSide)
                positionCX = Float(imageSide)
                positionDX = Float(imageSide)
            }
            else if positionRule == 2
            {
                positionY = 0
                positionBY = 0
                positionCY = 0
                positionDY = 0
            }
            else
            {
                positionY = Float(imageSide)
                positionBY = Float(imageSide)
                positionCY = Float(imageSide)
                positionDY = Float(imageSide)
            }
            
            let particle = Particle(positionX: positionX, positionY: positionY,velocityX: velocityX, velocityY: velocityY,
                positionBX: positionBX, positionBY: positionBY, velocityBX: velocityBX, velocityBY: velocityBY,
                positionCX: positionCX, positionCY: positionCY, velocityCX: velocityCX, velocityCY: velocityCY,
                positionDX: positionDX, positionDY: positionDY, velocityDX: velocityDX, velocityDY: velocityDY)
            
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
            
            particle_threadGroupCount = MTLSize(width:32,height:1,depth:1)
            particle_threadGroups = MTLSize(width:(particleCount + 31) / 32, height:1, depth:1)
            
            kernelFunction = defaultLibrary.newFunctionWithName("particleRendererShader")
            pipelineState = device.newComputePipelineStateWithFunction(kernelFunction!, error: nil)
            
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
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
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
        gravityWellParticle.positionX = 512 + 65 * sin(gravityWellAngle)
        gravityWellParticle.positionY = 512 + 65 * cos(gravityWellAngle)
        
        gravityWellParticle.positionX = 512 + 15 * sin(0 - gravityWellAngle / 2)
        gravityWellParticleTwo.positionY = 512 + 15 * cos(0 - gravityWellAngle / 2)
        
        var inGravityWell = device.newBufferWithBytes(&gravityWellParticle, length: particleSize, options: nil)
        commandEncoder.setBuffer(inGravityWell, offset: 0, atIndex: 2)
        
        var inGravityWellTwo = device.newBufferWithBytes(&gravityWellParticleTwo, length: particleSize, options: nil)
        commandEncoder.setBuffer(inGravityWellTwo, offset: 0, atIndex: 3)
        
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
            
            commandBuffer.waitUntilScheduled()
            
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

struct Particle
{
    var positionX: Float = 0
    var positionY: Float = 0
    var velocityX: Float = 0
    var velocityY: Float = 0
    
    var positionBX: Float = 0
    var positionBY: Float = 0
    var velocityBX: Float = 0
    var velocityBY: Float = 0
    
    var positionCX: Float = 0
    var positionCY: Float = 0
    var velocityCX: Float = 0
    var velocityCY: Float = 0
    
    var positionDX: Float = 0
    var positionDY: Float = 0
    var velocityDX: Float = 0
    var velocityDY: Float = 0
}

