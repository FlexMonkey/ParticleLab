//
//  ParticleLab.swift
//  MetalParticles
//
//  Created by Simon Gladman on 04/04/2015.
//  Copyright (c) 2015 Simon Gladman. All rights reserved.
//

import Metal
import UIKit

class ParticleLab: CAMetalLayer
{
    let imageSide: UInt = 1280
    let bytesPerRow: UInt
    let region: MTLRegion
    let blankBitmapRawData : [UInt8]
    
    var kernelFunction: MTLFunction!
    var pipelineState: MTLComputePipelineState!
    var defaultLibrary: MTLLibrary! = nil
    var metalDevice: MTLDevice! = nil
    var commandQueue: MTLCommandQueue! = nil
    
    var errorFlag:Bool = false
    
    var particle_threadGroupCount:MTLSize!
    var particle_threadGroups:MTLSize!
    
    let particleCount: Int = 524288 // 4194304 2097152   1048576  524288
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
    
    var frameStartTime: CFAbsoluteTime!
    var frameNumber = 0
    let particleSize = sizeof(Particle)
    
    override init()
    {
        bytesPerRow = 4 * imageSide
        region = MTLRegionMake2D(0, 0, Int(imageSide), Int(imageSide))
        blankBitmapRawData = [UInt8](count: Int(imageSide * imageSide * 4), repeatedValue: 0)
        particlesMemoryByteSize = UInt(particleCount) * UInt(sizeof(Particle))
        
        super.init()
        
        framebufferOnly = false
        drawableSize = CGSize(width: 1280, height: 1280);
        drawsAsynchronously = true
        
        setUpParticles()
        
        setUpMetal()
    }
    
    required init(coder aDecoder: NSCoder)
    {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setUpParticles()
    {
        posix_memalign(&particlesMemory, alignment, particlesMemoryByteSize)
        
        particlesVoidPtr = COpaquePointer(particlesMemory)
        particlesParticlePtr = UnsafeMutablePointer<Particle>(particlesVoidPtr)
        particlesParticleBufferPtr = UnsafeMutableBufferPointer(start: particlesParticlePtr, count: particleCount)
        
        func rand() -> Float32
        {
            return Float(drand48() - 0.5) * 0.2
        }
        
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

    func setUpMetal()
    {
        metalDevice = MTLCreateSystemDefaultDevice()
        
        device = device
        
        if device == nil
        {
            errorFlag = true
        }
        else
        {
            defaultLibrary = device.newDefaultLibrary()
            commandQueue = device.newCommandQueue()
            
            kernelFunction = defaultLibrary.newFunctionWithName("particleRendererShader")
            pipelineState = device.newComputePipelineStateWithFunction(kernelFunction!, error: nil)
            
            let threadExecutionWidth = pipelineState.threadExecutionWidth
            
            particle_threadGroupCount = MTLSize(width:threadExecutionWidth,height:1,depth:1)
            particle_threadGroups = MTLSize(width:(particleCount + threadExecutionWidth - 1) / threadExecutionWidth, height:1, depth:1)
            
            frameStartTime = CFAbsoluteTimeGetCurrent()
            
            step()
        }
    }

    final func step()
    {
        frameNumber++
        
        if frameNumber == 100
        {
            let frametime = (CFAbsoluteTimeGetCurrent() - frameStartTime) / 100
            println(NSString(format: "%.1f", 1 / frametime) + "fps" )
            
            frameStartTime = CFAbsoluteTimeGetCurrent()
            
            frameNumber = 0
        }
        
        let commandBuffer = commandQueue.commandBuffer()
        let commandEncoder = commandBuffer.computeCommandEncoder()
        
        commandEncoder.setComputePipelineState(pipelineState)
        
        let particlesBufferNoCopy = device.newBufferWithBytesNoCopy(particlesMemory, length: Int(particlesMemoryByteSize),
            options: nil, deallocator: nil)
        
        commandEncoder.setBuffer(particlesBufferNoCopy, offset: 0, atIndex: 0)
        commandEncoder.setBuffer(particlesBufferNoCopy, offset: 0, atIndex: 1)
        
        gravityWellAngle += 0.5
        
        let gravityWellAngleTwo = gravityWellAngle / 9
        
        gravityWellParticle.A.x = (640 + 250 * sin(gravityWellAngleTwo)) + 150 * cos(gravityWellAngle)
        gravityWellParticle.A.y = (640 + 250 * cos(gravityWellAngleTwo)) + 150 * sin(gravityWellAngle)
        
        gravityWellParticle.B.x = (640 + 250 * sin(gravityWellAngleTwo + Float(M_PI))) + 150 * cos(gravityWellAngle)
        gravityWellParticle.B.y = (640 + 250 * cos(gravityWellAngleTwo + Float(M_PI))) + 150 * sin(gravityWellAngle)
        
        gravityWellParticle.C.x = (640 + 500 * sin(gravityWellAngleTwo / 0.3 + Float(M_PI * 0.5))) + 50 * cos(gravityWellAngle * 2.5)
        gravityWellParticle.C.y = (640 + 500 * cos(gravityWellAngleTwo / 0.3 + Float(M_PI * 0.5))) + 50 * sin(gravityWellAngle * 2.5)
        
        gravityWellParticle.D.x = (640 + 500 * sin(gravityWellAngleTwo / 0.3 + Float(M_PI * 1.5))) + 50 * cos(gravityWellAngle * 2.5)
        gravityWellParticle.D.y = (640 + 500 * cos(gravityWellAngleTwo / 0.3 + Float(M_PI * 1.5))) + 50 * sin(gravityWellAngle * 2.5)
        
        var inGravityWell = device.newBufferWithBytes(&gravityWellParticle, length: particleSize, options: nil)
        commandEncoder.setBuffer(inGravityWell, offset: 0, atIndex: 2)

        if let drawable = nextDrawable()
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
                self.step();
        })
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
