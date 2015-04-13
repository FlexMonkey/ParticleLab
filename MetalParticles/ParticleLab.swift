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
    let imageWidth: UInt
    let imageHeight: UInt
    
    private var imageWidthFloatBuffer: MTLBuffer!
    private var imageHeightFloatBuffer: MTLBuffer!
    
    let bytesPerRow: UInt
    let region: MTLRegion
    let blankBitmapRawData : [UInt8]
    
    private var kernelFunction: MTLFunction!
    private var pipelineState: MTLComputePipelineState!
    private var defaultLibrary: MTLLibrary! = nil
    private var commandQueue: MTLCommandQueue! = nil
    
    private var errorFlag:Bool = false
    
    private var particle_threadGroupCount:MTLSize!
    private var particle_threadGroups:MTLSize!
    
    let particleCount: Int
    let alignment:Int = 0x4000
    let particlesMemoryByteSize:Int
    
    private var particlesMemory:UnsafeMutablePointer<Void> = nil
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
    
    weak var particleLabDelegate: ParticleLabDelegate?
    
    var particleColor = ParticleColor(R: 1, G: 0.5, B: 0.2, A: 1)
    var dragFactor: Float = 0.97
    
    init(width: UInt, height: UInt, numParticles: ParticleCount)
    {
        particleCount = numParticles.rawValue
        
        imageWidth = width
        imageHeight = height
        
        bytesPerRow = 4 * imageWidth
        
        region = MTLRegionMake2D(0, 0, Int(imageWidth), Int(imageHeight))
        blankBitmapRawData = [UInt8](count: Int(imageWidth * imageHeight * 4), repeatedValue: 0)
        particlesMemoryByteSize = particleCount * sizeof(Particle)
        
        super.init()
        
        framebufferOnly = false
        drawableSize = CGSize(width: CGFloat(imageWidth), height: CGFloat(imageHeight));
        drawsAsynchronously = true
        
        setUpParticles()
        
        setUpMetal()
        
        markerA.strokeColor = UIColor.whiteColor().CGColor
        markerB.strokeColor = UIColor.whiteColor().CGColor
        markerC.strokeColor = UIColor.whiteColor().CGColor
        markerD.strokeColor = UIColor.whiteColor().CGColor
    }
    
    required init(coder aDecoder: NSCoder)
    {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit
    {
        free(particlesMemory)
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
    
    private func setUpParticles()
    {
        posix_memalign(&particlesMemory, alignment, particlesMemoryByteSize)
        
        particlesVoidPtr = COpaquePointer(particlesMemory)
        particlesParticlePtr = UnsafeMutablePointer<Particle>(particlesVoidPtr)
        particlesParticleBufferPtr = UnsafeMutableBufferPointer(start: particlesParticlePtr, count: particleCount)
        
        resetParticles()
    }
    
    func resetGravityWells()
    {
        setGravityWellProperties(gravityWell: .One, normalisedPositionX: 0.5, normalisedPositionY: 0.5, mass: 0, spin: 0)
        setGravityWellProperties(gravityWell: .Two, normalisedPositionX: 0.5, normalisedPositionY: 0.5, mass: 0, spin: 0)
        setGravityWellProperties(gravityWell: .Three, normalisedPositionX: 0.5, normalisedPositionY: 0.5, mass: 0, spin: 0)
        setGravityWellProperties(gravityWell: .Four, normalisedPositionX: 0.5, normalisedPositionY: 0.5, mass: 0, spin: 0)
    }
    
    func resetParticles(edgesOnly: Bool = true)
    {
        func rand() -> Float32
        {
            return Float(drand48() - 0.5) * 0.005
        }
        
        let imageWidthDouble = Double(imageWidth)
        let imageHeightDouble = Double(imageHeight)
        
        for index in particlesParticleBufferPtr.startIndex ..< particlesParticleBufferPtr.endIndex
        {
            var positionAX = Float(drand48() * imageWidthDouble)
            var positionAY = Float(drand48() * imageHeightDouble)
            
            var positionBX = Float(drand48() * imageWidthDouble)
            var positionBY = Float(drand48() * imageHeightDouble)
            
            var positionCX = Float(drand48() * imageWidthDouble)
            var positionCY = Float(drand48() * imageHeightDouble)
            
            var positionDX = Float(drand48() * imageWidthDouble)
            var positionDY = Float(drand48() * imageHeightDouble)
            
            if edgesOnly
            {
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
                    positionAX = Float(imageWidth)
                    positionBX = Float(imageWidth)
                    positionCX = Float(imageWidth)
                    positionDX = Float(imageWidth)
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
                    positionAY = Float(imageHeight)
                    positionBY = Float(imageHeight)
                    positionCY = Float(imageHeight)
                    positionDY = Float(imageHeight)
                }
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
        device = MTLCreateSystemDefaultDevice()
        
        if device == nil
        {
            errorFlag = true
            
            particleLabDelegate?.particleLabMetalUnavailable()
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
    
            var imageWidthFloat = Float(imageWidth)
            var imageHeightFloat = Float(imageHeight)
            
            imageWidthFloatBuffer =  device.newBufferWithBytes(&imageWidthFloat, length: sizeof(Float), options: nil)
            imageHeightFloatBuffer = device.newBufferWithBytes(&imageHeightFloat, length: sizeof(Float), options: nil)
            
            step()
        }
    }
    
    final private func step()
    {
        frameNumber++
        
        if frameNumber == 100
        {
            let frametime = (CFAbsoluteTimeGetCurrent() - frameStartTime) / 100
            // println((NSString(format: "%.1f", 1 / frametime) as String) + "fps" )
            
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
        
        commandEncoder.setBuffer(imageWidthFloatBuffer, offset: 0, atIndex: 4)
        commandEncoder.setBuffer(imageHeightFloatBuffer, offset: 0, atIndex: 5)
        
        var dragFactorBuffer = device.newBufferWithBytes(&dragFactor, length: sizeof(Float), options: nil)
        commandEncoder.setBuffer(dragFactorBuffer, offset: 0, atIndex: 6)
        
        if showGravityWellPositions
        {
            let scale = frame.width / CGFloat(imageWidth)
            
            markerA.path = CGPathCreateWithEllipseInRect(CGRect(x: CGFloat(gravityWellParticle.A.x) * scale - 5, y: CGFloat(gravityWellParticle.A.y - 5) * scale, width: 10, height: 10), nil)
            markerB.path = CGPathCreateWithEllipseInRect(CGRect(x: CGFloat(gravityWellParticle.B.x) * scale - 5, y: CGFloat(gravityWellParticle.B.y - 5) * scale, width: 10, height: 10), nil)
            markerC.path = CGPathCreateWithEllipseInRect(CGRect(x: CGFloat(gravityWellParticle.C.x) * scale - 5, y: CGFloat(gravityWellParticle.C.y - 5) * scale, width: 10, height: 10), nil)
            markerD.path = CGPathCreateWithEllipseInRect(CGRect(x: CGFloat(gravityWellParticle.D.x) * scale - 5, y: CGFloat(gravityWellParticle.D.y - 5) * scale, width: 10, height: 10), nil)
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
    
    final func getGravityWellNormalisedPosition(#gravityWell: GravityWell) -> (x: Float, y: Float)
    {
        let returnPoint: (x: Float, y: Float)
        
        let imageWidthFloat = Float(imageWidth)
        let imageHeightFloat = Float(imageHeight)

        switch gravityWell
        {
        case .One:
            returnPoint = (x: gravityWellParticle.A.x / imageWidthFloat, y: gravityWellParticle.A.y / imageHeightFloat)
            
        case .Two:
            returnPoint = (x: gravityWellParticle.B.x / imageWidthFloat, y: gravityWellParticle.B.y / imageHeightFloat)
            
        case .Three:
            returnPoint = (x: gravityWellParticle.C.x / imageWidthFloat, y: gravityWellParticle.C.y / imageHeightFloat)
            
        case .Four:
            returnPoint = (x: gravityWellParticle.D.x / imageWidthFloat, y: gravityWellParticle.D.y / imageHeightFloat)
        }

        return returnPoint
    }
    
    final func setGravityWellProperties(#gravityWellIndex: Int, normalisedPositionX: Float, normalisedPositionY: Float, mass: Float, spin: Float)
    {
        switch gravityWellIndex
        {
        case 1:
            setGravityWellProperties(gravityWell: .Two, normalisedPositionX: normalisedPositionX, normalisedPositionY: normalisedPositionY, mass: mass, spin: spin)
            
        case 2:
            setGravityWellProperties(gravityWell: .Three, normalisedPositionX: normalisedPositionX, normalisedPositionY: normalisedPositionY, mass: mass, spin: spin)

        case 3:
            setGravityWellProperties(gravityWell: .Four, normalisedPositionX: normalisedPositionX, normalisedPositionY: normalisedPositionY, mass: mass, spin: spin)
            
        default:
            setGravityWellProperties(gravityWell: .One, normalisedPositionX: normalisedPositionX, normalisedPositionY: normalisedPositionY, mass: mass, spin: spin)
        }
    }
    
    final func setGravityWellProperties(#gravityWell: GravityWell, normalisedPositionX: Float, normalisedPositionY: Float, mass: Float, spin: Float)
    {
        let imageWidthFloat = Float(imageWidth)
        let imageHeightFloat = Float(imageHeight)
        
        switch gravityWell
        {
        case .One:
            gravityWellParticle.A.x = imageWidthFloat * normalisedPositionX
            gravityWellParticle.A.y = imageHeightFloat * normalisedPositionY
            gravityWellParticle.A.z = mass
            gravityWellParticle.A.w = spin
            
        case .Two:
            gravityWellParticle.B.x = imageWidthFloat * normalisedPositionX
            gravityWellParticle.B.y = imageHeightFloat * normalisedPositionY
            gravityWellParticle.B.z = mass
            gravityWellParticle.B.w = spin
            
        case .Three:
            gravityWellParticle.C.x = imageWidthFloat * normalisedPositionX
            gravityWellParticle.C.y = imageHeightFloat * normalisedPositionY
            gravityWellParticle.C.z = mass
            gravityWellParticle.C.w = spin
            
        case .Four:
            gravityWellParticle.D.x = imageWidthFloat * normalisedPositionX
            gravityWellParticle.D.y = imageHeightFloat * normalisedPositionY
            gravityWellParticle.D.z = mass
            gravityWellParticle.D.w = spin
        }
    }
}

protocol ParticleLabDelegate: NSObjectProtocol
{
    func particleLabDidUpdate()
    func particleLabMetalUnavailable()
}

enum GravityWell
{
    case One
    case Two
    case Three
    case Four
}

//  Since each Particle instance defines four particles, the visible particle count
//  in the API is four times the number we need to create.
enum ParticleCount: Int
{
    case HalfMillion = 131072
    case OneMillion =  262144
    case TwoMillion =  524288
    case FourMillion = 1048576
}

//  Paticles are split into three classes. The supplied particle color defines one
//  third of the rendererd particles, the other two thirds use the supplied particle
//  color components but shifted to BRG and GBR
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

// Regular particles use x and y for position and z and w for velocity
// gravity wells use x and y for position and z for mass and w for spin
struct Vector4
{
    var x: Float32 = 0
    var y: Float32 = 0
    var z: Float32 = 0
    var w: Float32 = 0
}

