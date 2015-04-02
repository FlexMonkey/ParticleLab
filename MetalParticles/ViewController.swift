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
    let imageSide: UInt = 1280
    
    let bytesPerRow = UInt(4 * 1280)
    
    var kernelFunction: MTLFunction!
    var pipelineState: MTLComputePipelineState!
    var defaultLibrary: MTLLibrary! = nil
    var device: MTLDevice! = nil
    var commandQueue: MTLCommandQueue! = nil
    
    let metalLayer = CAMetalLayer()
    
    var region: MTLRegion = MTLRegionMake2D(0, 0, Int(1280), Int(1280))
    
    let blankBitmapRawData = [UInt8](count: Int(1280 * 1280 * 4), repeatedValue: 0)
    
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
        metalLayer.drawableSize = CGSize(width: 1280, height: 1280);
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
            var positionAX = Float(drand48() * 1280)
            var positionAY = Float(drand48() * 1280)

            var positionBX = Float(drand48() * 1280)
            var positionBY = Float(drand48() * 1280)

            var positionCX = Float(drand48() * 1280)
            var positionCY = Float(drand48() * 1280)
            
            var positionDX = Float(drand48() * 1280)
            var positionDY = Float(drand48() * 1280)
            
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
            
            
            let particle = Particle(A: Vector4(x: positionAX, y: positionAY, z: rand(), w: rand()),
                B: Vector4(x: positionBX, y: positionBY, z: rand(), w: rand()),
                C: Vector4(x: positionCX, y: positionCY, z: rand(), w: rand()),
                D: Vector4(x: positionDX, y: positionDY, z: rand(), w: rand()))
            
            particlesParticleBufferPtr[index] = particle
        }
    }
    
    func rand() -> Float32
    {
        return Float(drand48() - 0.5) * 0.2
    }
    
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
        
        self.applyShader()
    }
    
    var imageBytes = [UInt8](count: Int(1280 * 1280 * 4), repeatedValue: 0)
    
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
        
        gravityWellAngle += 0.5
        
        let gravityWellAngleTwo = gravityWellAngle / 19
        
        gravityWellParticle.A.x = (640 + 250 * sin(gravityWellAngleTwo)) + 150 * cos(gravityWellAngle)
        gravityWellParticle.A.y = (640 + 250 * cos(gravityWellAngleTwo)) + 150 * sin(gravityWellAngle)
        
        gravityWellParticle.B.x = (640 + 250 * sin(gravityWellAngleTwo + Float(M_PI))) + 150 * cos(gravityWellAngle)
        gravityWellParticle.B.y = (640 + 250 * cos(gravityWellAngleTwo + Float(M_PI))) + 150 * sin(gravityWellAngle)

        gravityWellParticle.C.x = (640 + 500 * sin(gravityWellAngleTwo / 0.7 + Float(M_PI * 0.5))) + 25 * cos(gravityWellAngle * 0.7)
        gravityWellParticle.C.y = (640 + 500 * cos(gravityWellAngleTwo / 0.7 + Float(M_PI * 0.5))) + 25 * sin(gravityWellAngle * 0.7)
        
        gravityWellParticle.D.x = (640 + 500 * sin(gravityWellAngleTwo / 0.7 + Float(M_PI * 1.5))) + 25 * cos(gravityWellAngle * 0.7)
        gravityWellParticle.D.y = (640 + 500 * cos(gravityWellAngleTwo / 0.7 + Float(M_PI * 1.5))) + 25 * sin(gravityWellAngle * 0.7)
        
        var inGravityWell = device.newBufferWithBytes(&gravityWellParticle, length: particleSize, options: nil)
        commandEncoder.setBuffer(inGravityWell, offset: 0, atIndex: 2)
        
        let drawable = metalLayer.nextDrawable()
        
        if let drawable = drawable
        {
            drawable.texture.replaceRegion(self.region, mipmapLevel: 0, withBytes: blankBitmapRawData, bytesPerRow: Int(bytesPerRow))
            commandEncoder.setTexture(drawable.texture, atIndex: 0)
            
            commandEncoder.dispatchThreadgroups(particle_threadGroups, threadsPerThreadgroup: particle_threadGroupCount)
            
            commandEncoder.endEncoding()
            
            //commandBuffer.presentDrawable(drawable)
            
            commandBuffer.commit()
            
            // commandBuffer.waitUntilScheduled()
            
            drawable.present()
            
        }
        else
        {
            commandEncoder.endEncoding()
            
            println("metalLayer.nextDrawable() returned nil")
        }
        
        dispatch_async(dispatch_get_main_queue(),
        {
                self.run();
        })
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





