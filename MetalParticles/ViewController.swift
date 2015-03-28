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
    
    let particleCount: Int = 4194304 // 4194304 2097152   1048576
    var particlesMemory:UnsafeMutablePointer<Void> = nil
    let alignment:UInt = 0x4000
    let particlesMemoryByteSize:UInt = UInt(4194304) * UInt(sizeof(Particle))
    var particlesVoidPtr: COpaquePointer!
    var particlesParticlePtr: UnsafeMutablePointer<Particle>!
    var particlesParticleBufferPtr: UnsafeMutableBufferPointer<Particle>!
    
    var gravityWellAngle: Float = 0.0
    var gravityWellParticle = Particle(positionX: 512, positionY: 512, velocityX: 0, velocityY: 0)
    
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
    
            particlesParticleBufferPtr[index] = particle
        }
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
        gravityWellParticle.positionX = 512 + 100 * sin(gravityWellAngle)
        gravityWellParticle.positionY = 512 + 100 * cos(gravityWellAngle)
        
        var inGravityWell = device.newBufferWithBytes(&gravityWellParticle, length: sizeofValue(gravityWellParticle), options: nil)
        commandEncoder.setBuffer(inGravityWell, offset: 0, atIndex: 2)

        let drawable = metalLayer.nextDrawable()
        
        if let drawable = drawable
        {
            drawable.texture.replaceRegion(self.region, mipmapLevel: 0, withBytes: blankBitmapRawData, bytesPerRow: Int(bytesPerRow))
            
            commandEncoder.setTexture(drawable.texture, atIndex: 0)
                    
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
}

