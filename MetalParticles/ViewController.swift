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
    
    var useGlowAndTrails = false
    
    let toolbar = UIToolbar(frame: CGRectZero)
    var resetParticlesFlag = false
    
    var parameterWidgets = [ParameterWidget]()
    var speciesSegmentedControl = UISegmentedControl(items: ["Red", "Green", "Blue"])
    let fieldNames = ["Radius", "Cohesion", "Alignment", "Seperation", "Steering", "Pace Keeping"]

    var redGenome = SwarmGenome(radius: 0.4, c1_cohesion: 0.25, c2_alignment: 0.35, c3_seperation: 0.05, c4_steering: 0.35, c5_paceKeeping: 0.75)
    var greenGenome = SwarmGenome(radius: 0.5, c1_cohesion: 0.165, c2_alignment: 0.5, c3_seperation: 0.2, c4_steering: 0.25, c5_paceKeeping: 0.5)
    var blueGenome = SwarmGenome(radius: 0.2, c1_cohesion: 0.45, c2_alignment: 0.8, c3_seperation: 0.075, c4_steering: 0.9, c5_paceKeeping: 0.15)
    
    var genomes = [SwarmGenome]()
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.darkGrayColor()

        imageView.contentMode = UIViewContentMode.ScaleAspectFill
        imageView.backgroundColor = UIColor.blackColor()

        speciesSegmentedControl.tintColor = UIColor.whiteColor()
        
        speciesSegmentedControl.addTarget(self, action: "speciesChangeHandler", forControlEvents: UIControlEvents.ValueChanged)
        view.addSubview(speciesSegmentedControl)
        
        for i in 0 ... 5
        {
            let parameterWidget = ParameterWidget(frame: CGRectZero)
            parameterWidget.fieldName = fieldNames[i]
            parameterWidget.addTarget(self, action: "parameterChangeHandler", forControlEvents: UIControlEvents.ValueChanged)
            parameterWidgets.append(parameterWidget)
            
            view.addSubview(parameterWidget)
        }
        
        view.addSubview(imageView)
        
        let resetBarButtonItem = UIBarButtonItem(title: "Reset", style: UIBarButtonItemStyle.Plain, target: self, action: "resetParticles")
        let toggleTrailsButtonItem = UIBarButtonItem(title: "Trails", style: UIBarButtonItemStyle.Plain, target: self, action: "toggleTrails")
        
        toolbar.items = [resetBarButtonItem, toggleTrailsButtonItem]
        
        view.addSubview(toolbar)
        
        genomes = [redGenome, greenGenome, blueGenome]
        
        setUpParticles()
        
        setUpMetal()
        
        speciesSegmentedControl.selectedSegmentIndex = 0
        speciesChangeHandler()
    }
    
    func parameterChangeHandler()
    {
        genomes[speciesSegmentedControl.selectedSegmentIndex].radius = parameterWidgets[0].value
        genomes[speciesSegmentedControl.selectedSegmentIndex].c1_cohesion = parameterWidgets[1].value
        genomes[speciesSegmentedControl.selectedSegmentIndex].c2_alignment = parameterWidgets[2].value
        genomes[speciesSegmentedControl.selectedSegmentIndex].c3_seperation = parameterWidgets[3].value
        genomes[speciesSegmentedControl.selectedSegmentIndex].c4_steering = parameterWidgets[4].value
        genomes[speciesSegmentedControl.selectedSegmentIndex].c5_paceKeeping = parameterWidgets[5].value
        
        redGenome = genomes[0]
        greenGenome = genomes[1]
        blueGenome = genomes[2]
    }
    
    func speciesChangeHandler()
    {
        let selectedGenome = genomes[speciesSegmentedControl.selectedSegmentIndex]
        
        parameterWidgets[0].value = selectedGenome.radius
        parameterWidgets[1].value = selectedGenome.c1_cohesion
        parameterWidgets[2].value = selectedGenome.c2_alignment
        parameterWidgets[3].value = selectedGenome.c3_seperation
        parameterWidgets[4].value = selectedGenome.c4_steering
        parameterWidgets[5].value = selectedGenome.c5_paceKeeping
    }
    
    func setUpParticles()
    {
        posix_memalign(&particlesMemory, alignment, particlesMemoryByteSize)
        
        particlesVoidPtr = COpaquePointer(particlesMemory)
        particlesParticlePtr = UnsafeMutablePointer<Particle>(particlesVoidPtr)
        particlesParticleBufferPtr = UnsafeMutableBufferPointer(start: particlesParticlePtr, count: particleCount)
 
        populateParticles()
    }
    
    final func populateParticles()
    {
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

    final func resetParticles()
    {
        resetParticlesFlag = true
    }
    
    final func toggleTrails()
    {
        useGlowAndTrails = !useGlowAndTrails
    }
    
    final func run()
    {
        let frametime = CFAbsoluteTimeGetCurrent() - frameStartTime
        println("frametime: " + NSString(format: "%.6f", frametime) + " = " + NSString(format: "%.1f", 1 / frametime) + "fps" )
        
        frameStartTime = CFAbsoluteTimeGetCurrent()
        
        if resetParticlesFlag
        {
            resetParticlesFlag = false
            populateParticles()
        }
  
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
  
        let redBuffer: MTLBuffer = device.newBufferWithBytes(&redGenome, length: sizeof(SwarmGenome), options: nil)
        commandEncoder.setBuffer(redBuffer, offset: 0, atIndex: 2)
        
        let greenBuffer: MTLBuffer = device.newBufferWithBytes(&greenGenome, length: sizeof(SwarmGenome), options: nil)
        commandEncoder.setBuffer(greenBuffer, offset: 0, atIndex: 3)
        
        let blueBuffer: MTLBuffer = device.newBufferWithBytes(&blueGenome, length: sizeof(SwarmGenome), options: nil)
        commandEncoder.setBuffer(blueBuffer, offset: 0, atIndex: 4)
        
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
        let imageSide = Int(view.frame.height - topLayoutGuide.length)
        
        imageView.frame = CGRect(x: 0 , y: Int(topLayoutGuide.length), width: imageSide, height: imageSide)
 
        let dialOriginY = Int(topLayoutGuide.length) + 5
        let dialWidth = Int(view.frame.width) - imageSide
        let dialOriginX = Int(view.frame.width) - dialWidth
        
        speciesSegmentedControl.frame = CGRect(x: dialOriginX, y: dialOriginY, width: dialWidth, height: 30).rectByInsetting(dx: 4, dy: 0)
        
        for (idx: Int, parameterWidget: ParameterWidget) in enumerate(parameterWidgets)
        {
            parameterWidget.frame = CGRect(x: dialOriginX, y: 50 + dialOriginY + idx * 70, width: dialWidth, height: 55).rectByInsetting(dx: 4, dy: 1)
        }
        
        toolbar.frame = CGRect(x: dialOriginX, y: Int(view.frame.height) - 40, width: imageSide, height: 40)
    }
    
    override func supportedInterfaceOrientations() -> Int
    {
        return Int(UIInterfaceOrientationMask.Landscape.rawValue)
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

struct SwarmGenome
{
    var radius: Float = 0
    var c1_cohesion: Float = 0
    var c2_alignment: Float = 0
    var c3_seperation: Float = 0
    var c4_steering: Float = 0
    var c5_paceKeeping: Float = 0
}



