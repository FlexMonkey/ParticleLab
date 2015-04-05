//
//  ParticleLab.swift
//  MetalParticles
//
//  Created by Simon Gladman on 04/04/2015.
//  Copyright (c) 2015 Simon Gladman. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
    
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>

import Metal
import UIKit

class ParticleLab: CAMetalLayer
{
    let imageSide: UInt = 1280
    let bytesPerRow: UInt
    let region: MTLRegion
    let blankBitmapRawData : [UInt8]
    
    private var kernelFunction: MTLFunction!
    private var pipelineState: MTLComputePipelineState!
    private var defaultLibrary: MTLLibrary! = nil
    private var metalDevice: MTLDevice! = nil
    private var commandQueue: MTLCommandQueue! = nil
    
    private var errorFlag:Bool = false
    
    private var particle_threadGroupCount:MTLSize!
    private var particle_threadGroups:MTLSize!
    
    let particleCount: Int = 524288 // 4194304 2097152   1048576  524288
    private var particlesMemory:UnsafeMutablePointer<Void> = nil
    let alignment:UInt = 0x4000
    let particlesMemoryByteSize:UInt
    private var particlesVoidPtr: COpaquePointer!
    private var particlesParticlePtr: UnsafeMutablePointer<Particle>!
    private var particlesParticleBufferPtr: UnsafeMutableBufferPointer<Particle>!

    private var gravityWellParticle = Particle(A: Vector4(x: 0, y: 0, z: 0, w: 0),
        B: Vector4(x: 0, y: 0, z: 0, w: 0),
        C: Vector4(x: 0, y: 0, z: 0, w: 0),
        D: Vector4(x: 0, y: 0, z: 0, w: 0))
    
    private var frameStartTime: CFAbsoluteTime!
    private var frameNumber = 0
    let particleSize = sizeof(Particle)
    
    let markerA = CAShapeLayer()
    let markerB = CAShapeLayer()
    let markerC = CAShapeLayer()
    let markerD = CAShapeLayer()
    
    var particleLabDelegate: ParticleLabDelegate?
    
    var particleColor = ParticleColor(R: 1, G: 1, B: 0.2, A: 1)
    
    override init()
    {
        bytesPerRow = 4 * imageSide
        region = MTLRegionMake2D(0, 0, Int(imageSide), Int(imageSide))
        blankBitmapRawData = [UInt8](count: Int(imageSide * imageSide * 4), repeatedValue: 0)
        particlesMemoryByteSize = UInt(particleCount) * UInt(sizeof(Particle))
        
        super.init()
        
        framebufferOnly = false
        drawableSize = CGSize(width: CGFloat(imageSide), height: CGFloat(imageSide));
        drawsAsynchronously = true
        
        setUpParticles()
        
        setUpMetal()
 
        markerA.strokeColor = UIColor.whiteColor().CGColor
        markerB.strokeColor = UIColor.whiteColor().CGColor
        markerC.strokeColor = UIColor.whiteColor().CGColor
        markerD.strokeColor = UIColor.whiteColor().CGColor
    }
    
    var showGravityWellPositions: Bool = false
    {
        didSet
        {
            if showGravityWellPositions
            {
                addSublayer(markerA)
                addSublayer(markerB)
                addSublayer(markerC)
                addSublayer(markerD)
            }
            else
            {
                markerA.removeFromSuperlayer()
                markerB.removeFromSuperlayer()
                markerC.removeFromSuperlayer()
                markerD.removeFromSuperlayer()
            }
        }
    }
    
    required init(coder aDecoder: NSCoder)
    {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setUpParticles()
    {
        posix_memalign(&particlesMemory, alignment, particlesMemoryByteSize)
        
        particlesVoidPtr = COpaquePointer(particlesMemory)
        particlesParticlePtr = UnsafeMutablePointer<Particle>(particlesVoidPtr)
        particlesParticleBufferPtr = UnsafeMutableBufferPointer(start: particlesParticlePtr, count: particleCount)
        
        func rand() -> Float32
        {
            return Float(drand48() - 0.5) * 0.005
        }
        
        let imageSideDouble = Double(imageSide)
        
        for index in particlesParticleBufferPtr.startIndex ..< particlesParticleBufferPtr.endIndex
        {
            var positionAX = Float(drand48() * imageSideDouble)
            var positionAY = Float(drand48() * imageSideDouble)
            
            var positionBX = Float(drand48() * imageSideDouble)
            var positionBY = Float(drand48() * imageSideDouble)
            
            var positionCX = Float(drand48() * imageSideDouble)
            var positionCY = Float(drand48() * imageSideDouble)
            
            var positionDX = Float(drand48() * imageSideDouble)
            var positionDY = Float(drand48() * imageSideDouble)
    
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

    private func setUpMetal()
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

    final private func step()
    {
        frameNumber++
        
        if frameNumber == 100
        {
            let frametime = (CFAbsoluteTimeGetCurrent() - frameStartTime) / 100
            // println(NSString(format: "%.1f", 1 / frametime) + "fps" )
            
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
        
        var inGravityWell = device.newBufferWithBytes(&gravityWellParticle, length: particleSize, options: nil)
        commandEncoder.setBuffer(inGravityWell, offset: 0, atIndex: 2)

        var colorBuffer = device.newBufferWithBytes(&particleColor, length: sizeof(ParticleColor), options: nil)
        commandEncoder.setBuffer(colorBuffer, offset: 0, atIndex: 3)
        
        if showGravityWellPositions
        {
            let scale = frame.width / CGFloat(imageSide)
            
            markerA.path = CGPathCreateWithEllipseInRect(CGRect(x: CGFloat(gravityWellParticle.A.x) * scale, y: CGFloat(gravityWellParticle.A.y) * scale, width: 10, height: 10), nil)
            markerB.path = CGPathCreateWithEllipseInRect(CGRect(x: CGFloat(gravityWellParticle.B.x) * scale, y: CGFloat(gravityWellParticle.B.y) * scale, width: 10, height: 10), nil)
            markerC.path = CGPathCreateWithEllipseInRect(CGRect(x: CGFloat(gravityWellParticle.C.x) * scale, y: CGFloat(gravityWellParticle.C.y) * scale, width: 10, height: 10), nil)
            markerD.path = CGPathCreateWithEllipseInRect(CGRect(x: CGFloat(gravityWellParticle.D.x) * scale, y: CGFloat(gravityWellParticle.D.y) * scale, width: 10, height: 10), nil)
        }
     
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
        
        particleLabDelegate?.particleLabDidUpdate()
        
        dispatch_async(dispatch_get_main_queue(),
            {
                self.step();
        })
    }

    final func setGravityWellProperties(#gravityWell: GravityWell, normalisedPositionX: Float, normalisedPositionY: Float, mass: Float, spin: Float)
    {
        let imageSideFloat = Float(imageSide)
        
        switch gravityWell
        {
        case .One:
            gravityWellParticle.A.x = imageSideFloat * normalisedPositionX
            gravityWellParticle.A.y = imageSideFloat * normalisedPositionY
            gravityWellParticle.A.z = mass
            gravityWellParticle.A.w = spin
            
        case .Two:
            gravityWellParticle.B.x = imageSideFloat * normalisedPositionX
            gravityWellParticle.B.y = imageSideFloat * normalisedPositionY
            gravityWellParticle.B.z = mass
            gravityWellParticle.B.w = spin
            
        case .Three:
            gravityWellParticle.C.x = imageSideFloat * normalisedPositionX
            gravityWellParticle.C.y = imageSideFloat * normalisedPositionY
            gravityWellParticle.C.z = mass
            gravityWellParticle.C.w = spin
            
        case .Four:
            gravityWellParticle.D.x = imageSideFloat * normalisedPositionX
            gravityWellParticle.D.y = imageSideFloat * normalisedPositionY
            gravityWellParticle.D.z = mass
            gravityWellParticle.D.w = spin
        }
    }
}

protocol ParticleLabDelegate
{
    func particleLabDidUpdate()
}

enum GravityWell
{
    case One
    case Two
    case Three
    case Four
}

struct ParticleColor
{
    var R: Float32 = 0
    var G: Float32 = 0
    var B: Float32 = 0
    var A: Float32 = 1
}

struct Particle // Matrix4x4
{
    var A: Vector4 = Vector4(x: 0, y: 0, z: 0, w: 0)
    var B: Vector4 = Vector4(x: 0, y: 0, z: 0, w: 0)
    var C: Vector4 = Vector4(x: 0, y: 0, z: 0, w: 0)
    var D: Vector4 = Vector4(x: 0, y: 0, z: 0, w: 0)
}

// regular particles use x and y for position and z and w for velocity
// gravity wells use x and y for position and z for mass and w for spin
struct Vector4
{
    var x: Float32 = 0
    var y: Float32 = 0
    var z: Float32 = 0
    var w: Float32 = 0
}
