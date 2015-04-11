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
import Social
import MessageUI

class ViewController: UIViewController, BrowseAndLoadDelegate
{
    
    let bitmapInfo = CGBitmapInfo(CGBitmapInfo.ByteOrder32Big.rawValue | CGImageAlphaInfo.None.rawValue)
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
    
    let metalLayer = CAMetalLayer()
    
    var region: MTLRegion!
  
    var errorFlag:Bool = false
 
    var particle_threadGroupCount:MTLSize!
    var particle_threadGroups:MTLSize!
    
    var glow_threadGroupCount:MTLSize!
    var glow_threadGroups: MTLSize!
    
    let particleCount: Int = 4096
    var particlesMemory:UnsafeMutablePointer<Void> = nil
    let alignment:Int = 0x4000
    let particlesMemoryByteSize:Int = 4096 * sizeof(Particle)
    var particlesVoidPtr: COpaquePointer!
    var particlesParticlePtr: UnsafeMutablePointer<Particle>!
    var particlesParticleBufferPtr: UnsafeMutableBufferPointer<Particle>!

    var frameStartTime = CFAbsoluteTimeGetCurrent()
    

    var particleBrightness: Float = 0.8
    
    var saveButtonItem: UIBarButtonItem!
    let toolbar = UIToolbar(frame: CGRectZero)
    var resetParticlesFlag = false
    
    var parameterWidgets = [ParameterWidget]()
    var speciesSegmentedControl = UISegmentedControl(items: ["Red", "Green", "Blue"])
    let fieldNames = ["Radius", "Cohesion", "Alignment", "Seperation", "Steering", "Pace Keeping", "Normal Speed"]

    let infoButton: UIButton = UIButton.buttonWithType(UIButtonType.InfoLight) as! UIButton
    
    var redGenome = SwarmGenome(radius: 0.6, c1_cohesion: 0.83, c2_alignment: 0.39, c3_seperation: 0.4, c4_steering: 0.93, c5_paceKeeping: 0.1, normalSpeed: 0.83)
    var greenGenome = SwarmGenome(radius: 0.29, c1_cohesion: 0.92, c2_alignment: 0.24, c3_seperation: 0.1, c4_steering: 0.32, c5_paceKeeping: 0.9, normalSpeed: 0.73)
    var blueGenome = SwarmGenome(radius: 0.83, c1_cohesion: 0.65, c2_alignment: 0.97, c3_seperation: 0.3, c4_steering: 0.41, c5_paceKeeping: 0.5, normalSpeed: 0.9)
    
    var gravityWell = CGPoint(x: -1, y: -1)
    
    var genomes: [SwarmGenome] = [SwarmGenome]()
    {
        didSet
        {
            redGenome = genomes[0]
            greenGenome = genomes[1]
            blueGenome = genomes[2]
        }
    }
    
    lazy var mailDelegate: MailDelegate = {return MailDelegate(viewController: self)}()
    lazy var coreDataDelegate: CoreDataDelegate = {return CoreDataDelegate(viewController: self)}()
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.darkGrayColor()

        speciesSegmentedControl.tintColor = UIColor.whiteColor()
        
        speciesSegmentedControl.addTarget(self, action: "speciesChangeHandler", forControlEvents: UIControlEvents.ValueChanged)
        view.addSubview(speciesSegmentedControl)
        
        for i in 0 ..< fieldNames.count
        {
            let parameterWidget = ParameterWidget(frame: CGRectZero)
            parameterWidget.fieldName = fieldNames[i]
            parameterWidget.addTarget(self, action: "parameterChangeHandler", forControlEvents: UIControlEvents.ValueChanged)
            parameterWidgets.append(parameterWidget)
            
            view.addSubview(parameterWidget)
        }
        
        view.layer.addSublayer(metalLayer)
        
        metalLayer.framebufferOnly = false
        metalLayer.drawableSize = CGSize(width: 800, height: 800)
        metalLayer.drawsAsynchronously = true
        
        let resetBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Refresh, target: self, action: "resetParticles")
        
        // let toggleTrailsButtonItem = UIBarButtonItem(title: "Trails", style: UIBarButtonItemStyle.Plain, target: self, action: "toggleTrails")
        
        let spacer = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.FlexibleSpace, target: nil, action: nil)
        

        saveButtonItem = UIBarButtonItem(title: "Save", style: UIBarButtonItemStyle.Plain, target: self, action: "saveRecipe")
     
        let loadButtonItem = UIBarButtonItem(title: "Load", style: UIBarButtonItemStyle.Plain, target: self, action: "loadRecipe")

        saveButtonItem.enabled = false
        
        if MFMailComposeViewController.canSendMail()
        {
            let mailButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Compose, target: self, action: "mailRecipe")
            
            toolbar.items = [resetBarButtonItem, spacer, mailButtonItem, spacer, saveButtonItem, spacer, loadButtonItem]
        }
        else
        {
            toolbar.items = [resetBarButtonItem, spacer, saveButtonItem, spacer, loadButtonItem]
        }
        
        view.addSubview(toolbar)

        infoButton.tintColor = UIColor.whiteColor()
        infoButton.addTarget(self, action: "showInfo", forControlEvents: UIControlEvents.TouchDown)
        view.addSubview(infoButton)
        
        if let previousState = NSUserDefaults.standardUserDefaults().URLForKey("swarmChemistryRecipe")
        {
            let loadedGenomes = URLUtils.createGenomesFromURL(previousState)!
            
            genomes = [loadedGenomes.red, loadedGenomes.green, loadedGenomes.blue]
        }
        else
        {
            genomes = [redGenome, greenGenome, blueGenome]
        }
        
        
        setUpParticles()
        
        setUpMetal()
        
        speciesSegmentedControl.selectedSegmentIndex = 0
        speciesChangeHandler()
        
        coreDataDelegate.browseAndLoadDelegate = self
    }
    
    var saveEnabled: Bool = false
    {
        didSet
        {
            saveButtonItem.enabled = saveEnabled
        }
    }
    
    override func touchesBegan(touches: Set<NSObject>, withEvent event: UIEvent)
    {
        let location = (event.allTouches()?.first as! UITouch).locationInView(self.view)
        
        positionGravityWell(location)
    }
    
    override func touchesMoved(touches: Set<NSObject>, withEvent event: UIEvent)
    {
        let location = (event.allTouches()?.first as! UITouch).locationInView(self.view)
        
        positionGravityWell(location)
    }
    
    override func touchesEnded(touches: Set<NSObject>, withEvent event: UIEvent)
    {
        gravityWell.x = -1
        gravityWell.y = -1
    }
    
    func positionGravityWell(location: CGPoint)
    {
        let imageScale = metalLayer.frame.width / CGFloat(imageSide)
        
        gravityWell.x = location.x / imageScale
        gravityWell.y = location.y / imageScale
    }
    
    func showInfo()
    {
        let alertController = UIAlertController(title: "Emergent v1.0\nSwarm Chemistry Simulation",
            message: "\nSimon Gladman | February 2015\n\nBased on work by Hiroki Sayama\n\nIcon created by Maurizio Fusillo from the Noun Project",
            preferredStyle: UIAlertControllerStyle.Alert)
        
        let okAction = UIAlertAction(title: "OK", style: .Default, handler: nil)
        let openSwarmChemistry = UIAlertAction(title: "Learn about Swarm Chemistry", style: .Default, handler: visitBinghamton)
        let openBlogAction = UIAlertAction(title: "Open Development Blog", style: .Default, handler: visitFlexMonkey)
        
        
        alertController.addAction(openSwarmChemistry)
        alertController.addAction(openBlogAction)
        alertController.addAction(okAction)
        
        if let viewController = UIApplication.sharedApplication().keyWindow!.rootViewController
        {
            viewController.presentViewController(alertController, animated: true, completion: nil)
        }
    }
    
    func visitBinghamton(value: UIAlertAction!)
    {
        UIApplication.sharedApplication().openURL(NSURL(string: "http://bingweb.binghamton.edu/~sayama/SwarmChemistry/")!)
    }
    
    func visitFlexMonkey(value: UIAlertAction!)
    {
        UIApplication.sharedApplication().openURL(NSURL(string: "http://flexmonkey.blogspot.co.uk/search/label/Swarm%20Chemistry")!)
    }
    
    func mailRecipe()
    {
        let recipeURL = URLUtils.createUrlFromGenomes(redGenome: redGenome, greenGenome: greenGenome, blueGenome: blueGenome)
        
        // mailDelegate.mailRecipe(recipeURL: recipeURL, image: imageView.image)
    }
    
    func saveRecipe()
    {
        let recipeURL = URLUtils.createUrlFromGenomes(redGenome: redGenome, greenGenome: greenGenome, blueGenome: blueGenome)
        // let thumbnailImage = resizeToBoundingSquare(imageView.image!, boundingSquareSideLength: 480)

        // coreDataDelegate.save(recipeURL.absoluteString!, thumbnailImage: thumbnailImage)
        
        saveEnabled = false
    }
    
    func loadRecipe()
    {
        coreDataDelegate.load()
        
        saveEnabled = false
    }
    
    func swarmChemistryRecipeSelected(swarmChemistryRecipe: NSURL)
    {
        let loadedGenomes = URLUtils.createGenomesFromURL(swarmChemistryRecipe)!
     
        genomes[0] = loadedGenomes.red
        genomes[1] = loadedGenomes.green
        genomes[2] = loadedGenomes.blue

        speciesChangeHandler()
    }
    
    func parameterChangeHandler()
    {
        saveEnabled = true
        
        genomes[speciesSegmentedControl.selectedSegmentIndex].radius = parameterWidgets[0].value
        genomes[speciesSegmentedControl.selectedSegmentIndex].c1_cohesion = parameterWidgets[1].value
        genomes[speciesSegmentedControl.selectedSegmentIndex].c2_alignment = parameterWidgets[2].value
        genomes[speciesSegmentedControl.selectedSegmentIndex].c3_seperation = parameterWidgets[3].value
        genomes[speciesSegmentedControl.selectedSegmentIndex].c4_steering = parameterWidgets[4].value
        genomes[speciesSegmentedControl.selectedSegmentIndex].c5_paceKeeping = parameterWidgets[5].value
        genomes[speciesSegmentedControl.selectedSegmentIndex].normalSpeed = parameterWidgets[6].value
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
        parameterWidgets[6].value = selectedGenome.normalSpeed
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
      
            glow_threadGroupCount = MTLSizeMake(16, 16, 1)
            glow_threadGroups = MTLSizeMake(Int(imageSide) / glow_threadGroupCount.width, Int(imageSide) / glow_threadGroupCount.height, 1)

            
            region = MTLRegionMake2D(0, 0, Int(imageSide), Int(imageSide))
            
            kernelFunction = defaultLibrary.newFunctionWithName("particleRendererShader")
            pipelineState = device.newComputePipelineStateWithFunction(kernelFunction!, error: nil)
            
            run()
        }
    }

    final func resetParticles()
    {
        resetParticlesFlag = true
    }

    var isRunning: Bool = false
    {
        didSet
        {
            if isRunning && oldValue != isRunning
            {
                self.run()
            }
            else
            {
                let recipeURL = URLUtils.createUrlFromGenomes(redGenome: redGenome, greenGenome: greenGenome, blueGenome: blueGenome)
                
                NSUserDefaults.standardUserDefaults().setURL(recipeURL, forKey: "swarmChemistryRecipe")
            }
        }
    }
    
    final func run()
    {
        if device == nil || !isRunning
        {
            return
        }
        
        let frametime = CFAbsoluteTimeGetCurrent() - frameStartTime
        println("frametime: " + (NSString(format: "%.1f", 1 / frametime) as String) + "fps" )
        
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

    
    final func applyShader()
    {
        // textureB.replaceRegion(self.region, mipmapLevel: 0, withBytes: blankBitmapRawData, bytesPerRow: Int(bytesPerRow))

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

        let particleBrightnessBuffer: MTLBuffer = device.newBufferWithBytes(&particleBrightness, length: sizeof(Float), options: nil)
        commandEncoder.setBuffer(particleBrightnessBuffer, offset: 0, atIndex: 5)
        
        var gravityWellX = Float(gravityWell.x)
        var inGravityWellXBuffer: MTLBuffer = device.newBufferWithBytes(&gravityWellX, length: sizeof(Float), options: nil)
        commandEncoder.setBuffer(inGravityWellXBuffer, offset: 0, atIndex: 6)
        
        var gravityWellY = Float(gravityWell.y)
        var inGravityWellYBuffer: MTLBuffer = device.newBufferWithBytes(&gravityWellY, length: sizeof(Float), options: nil)
        commandEncoder.setBuffer(inGravityWellYBuffer, offset: 0, atIndex: 7)


        let drawable = metalLayer.nextDrawable()
        
        drawable.texture.replaceRegion(self.region, mipmapLevel: 0, withBytes: blankBitmapRawData, bytesPerRow: Int(bytesPerRow))
        
        commandEncoder.setTexture(drawable.texture, atIndex: 0)
        
        commandEncoder.dispatchThreadgroups(particle_threadGroups, threadsPerThreadgroup: particle_threadGroupCount)
        
        commandEncoder.endEncoding()
        
        commandBuffer.presentDrawable(drawable)
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
   
  
    }
    


    override func viewDidLayoutSubviews()
    {
        if errorFlag
        {
            let alertController = UIAlertController(title: "Emergent v1.0\nParticle System Explorer", message: "\nSorry! Emergent requires an iPad with an A7 or later processor. It appears your device is earlier.", preferredStyle: UIAlertControllerStyle.Alert)
            
            presentViewController(alertController, animated: true, completion: nil)
            
            errorFlag = false
        }
        
        let imageSide = Int(view.frame.height - topLayoutGuide.length)
        
        metalLayer.frame = CGRect(x: 0 , y: Int(topLayoutGuide.length), width: imageSide, height: imageSide)
 
        let dialOriginY = Int(topLayoutGuide.length) + 5
        let dialWidth = Int(view.frame.width) - imageSide
        let dialOriginX = Int(view.frame.width) - dialWidth
        
        speciesSegmentedControl.frame = CGRect(x: dialOriginX, y: dialOriginY - 4, width: dialWidth - 30, height: 30).rectByInsetting(dx: 4, dy: 0)
        
        infoButton.frame = CGRect(x: Int(view.frame.width) - 30, y: dialOriginY - 4, width: 30, height: 30)
        
        for (idx: Int, parameterWidget: ParameterWidget) in enumerate(parameterWidgets)
        {
            parameterWidget.frame = CGRect(x: dialOriginX, y: 50 + dialOriginY + idx * 70, width: dialWidth, height: 55).rectByInsetting(dx: 4, dy: 1)
        }
        
        toolbar.frame = CGRect(x: dialOriginX, y: Int(view.frame.height) - 40, width: dialWidth, height: 40)

        speciesChangeHandler()
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




