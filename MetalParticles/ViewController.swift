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

import UIKit

class ViewController: UIViewController, ParticleLabDelegate
{
    let menuButton = UIButton()
    let statusLabel = UILabel()
    
    let floatPi = Float(M_PI)
    
    var particleLab: ParticleLab!
    
    var gravityWellAngle: Float = 0
    
    var demoMode = DemoModes.cloudChamber
    
    var currentTouches = Set<UITouch>()
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.blackColor()
        view.multipleTouchEnabled = true
        
        let numParticles = ParticleCount.FourMillion
        
        if view.frame.height < view.frame.width
        {
            particleLab = ParticleLab(width: UInt(view.frame.width),
                height: UInt(view.frame.height),
                numParticles: numParticles)
       
            particleLab.frame = CGRect(x: 0,
                y: 0,
                width: view.frame.width,
                height: view.frame.height)
        }
        else
        {
            particleLab = ParticleLab(width: UInt(view.frame.height),
                height: UInt(view.frame.width),
                numParticles: numParticles)
            
            particleLab.frame = CGRect(x: 0,
                y: 0,
                width: view.frame.height,
                height: view.frame.width)
        }
        
        particleLab.particleLabDelegate = self
        particleLab.dragFactor = 0.85
        
        view.addSubview(particleLab)
        
        menuButton.layer.borderColor = UIColor.lightGrayColor().CGColor
        menuButton.layer.borderWidth = 1
        menuButton.layer.cornerRadius = 5
        menuButton.layer.backgroundColor = UIColor.darkGrayColor().CGColor
        menuButton.showsTouchWhenHighlighted = true
        menuButton.imageView?.contentMode = UIViewContentMode.ScaleAspectFit
        menuButton.setImage(UIImage(named: "hamburger.png"), forState: UIControlState.Normal)
        menuButton.addTarget(self, action: "displayCallout", forControlEvents: UIControlEvents.TouchDown)
        
        view.addSubview(menuButton)
        
        statusLabel.text = "http://flexmonkey.blogspot.co.uk"
        statusLabel.textColor = UIColor.whiteColor()
        
        view.addSubview(statusLabel)
    }
    
    override func viewDidLayoutSubviews()
    {
        statusLabel.frame = CGRect(x: 5,
            y: view.frame.height - statusLabel.intrinsicContentSize().height,
            width: view.frame.width,
            height: statusLabel.intrinsicContentSize().height)
        
        // frame: CGRect(x: 5, y: 5, width: 30, height: 30)
        
        menuButton.frame = CGRect(x: view.frame.width - 35,
            y: view.frame.height - 35,
            width: 30,
            height: 30)
    }
    
    func particleLabMetalUnavailable()
    {
        // handle metal unavailable here
    }

    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?)
    {
        currentTouches = currentTouches.union(touches)
    }

    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?)
    {
        currentTouches = currentTouches.subtract(touches)
    }
    
    func displayCallout()
    {
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: UIAlertControllerStyle.ActionSheet)
        
        let cloudChamberAction = UIAlertAction(title: DemoModes.cloudChamber.rawValue, style: UIAlertActionStyle.Default, handler: calloutActionHandler)
        let orbitsAction = UIAlertAction(title: DemoModes.orbits.rawValue, style: UIAlertActionStyle.Default, handler: calloutActionHandler)
        let multiTouchAction = UIAlertAction(title: DemoModes.multiTouch.rawValue, style: UIAlertActionStyle.Default, handler: calloutActionHandler)
        let respawnAction = UIAlertAction(title: DemoModes.respawn.rawValue, style: UIAlertActionStyle.Default, handler: calloutActionHandler)
        
        alertController.addAction(cloudChamberAction)
        alertController.addAction(orbitsAction)
        alertController.addAction(multiTouchAction)
        alertController.addAction(respawnAction)
        
        if let popoverPresentationController = alertController.popoverPresentationController
        {
            let xx = menuButton.frame.origin.x
            let yy = menuButton.frame.origin.y
            
            popoverPresentationController.sourceRect = CGRect(x: xx, y: yy, width: menuButton.frame.width, height: menuButton.frame.height)
            popoverPresentationController.sourceView = view
        }
        
        presentViewController(alertController, animated: true, completion: nil)
    }
 
    func calloutActionHandler(value: UIAlertAction!) -> Void
    {
        demoMode = DemoModes(rawValue: value.title!) ?? DemoModes.cloudChamber
        
        switch demoMode
        {
        case .orbits:
            particleLab.dragFactor = 0.82
            particleLab.respawnOutOfBoundsParticles = true
            particleLab.resetParticles(false)
            
        case .cloudChamber:
            particleLab.dragFactor = 0.75
            particleLab.respawnOutOfBoundsParticles = false
            particleLab.resetParticles(true)
            
        case .multiTouch:
            particleLab.dragFactor = 0.95
            particleLab.respawnOutOfBoundsParticles = false
            particleLab.resetParticles(false)
            
        case .respawn:
            particleLab.dragFactor = 0.98
            particleLab.respawnOutOfBoundsParticles = true
            particleLab.resetParticles(true)
        }
    }
    
    func particleLabDidUpdate(status: String)
    {
        statusLabel.text = "http://flexmonkey.blogspot.co.uk  |  " + status
        
        particleLab.resetGravityWells()
        
        switch demoMode
        {
        case .orbits:
            orbitsStep()
            
        case .cloudChamber:
            cloudChamberStep()
            
        case .multiTouch:
            multiTouchStep()
            
        case .respawn:
            respawnStep()
        }
    }
    
    func respawnStep()
    {
        gravityWellAngle = gravityWellAngle + 0.02
        
        particleLab.setGravityWellProperties(gravityWell: .One,
            normalisedPositionX: 0.5 + 0.45 * sin(gravityWellAngle),
            normalisedPositionY: 0.5 + 0.15 * cos(gravityWellAngle),
            mass: 14,
            spin: 16)
        
        particleLab.setGravityWellProperties(gravityWell: .Two,
            normalisedPositionX: 0.5 + 0.25 * cos(gravityWellAngle * 1.3),
            normalisedPositionY: 0.5 + 0.6 * sin(gravityWellAngle * 1.3),
            mass: 8,
            spin: 10)
     
    }
    
    func multiTouchStep()
    {
        let currentTouchesArray = Array(currentTouches)
        
        for (i, currentTouch) in currentTouchesArray.enumerate() where i < 4
        {
            let touchMultiplier = currentTouch.force == 0 && currentTouch.maximumPossibleForce == 0
                ? 1
                : Float(currentTouch.force / currentTouch.maximumPossibleForce)
            
            particleLab.setGravityWellProperties(gravityWellIndex: i,
                normalisedPositionX: Float(currentTouch.locationInView(view).x / view.frame.width) ,
                normalisedPositionY: Float(currentTouch.locationInView(view).y / view.frame.height),
                mass: 40 * touchMultiplier,
                spin: 20 * touchMultiplier)
        }

        for var i = currentTouchesArray.count; i < 4; i++
        {
            particleLab.setGravityWellProperties(gravityWellIndex: i,
                normalisedPositionX: 0.5,
                normalisedPositionY: 0.5,
                mass: 0,
                spin: 0)
        }
        
    }
    
    func orbitsStep()
    {
        gravityWellAngle = gravityWellAngle + 0.0015
        
        particleLab.setGravityWellProperties(gravityWell: .One,
            normalisedPositionX: 0.5 + 0.002 * sin(gravityWellAngle * 43),
            normalisedPositionY: 0.5 + 0.002 * cos(gravityWellAngle * 43),
            mass: 10,
            spin: 24)
        
        let particleOnePosition = particleLab.getGravityWellNormalisedPosition(gravityWell: .One)
        
        particleLab.setGravityWellProperties(gravityWell: .Two,
            normalisedPositionX: particleOnePosition.x + 0.3 * sin(gravityWellAngle * 5),
            normalisedPositionY: particleOnePosition.y + 0.3 * cos(gravityWellAngle * 5),
            mass: 4,
            spin: 18)
        
        let particleTwoPosition = particleLab.getGravityWellNormalisedPosition(gravityWell: .Two)
        
        particleLab.setGravityWellProperties(gravityWell: .Three,
            normalisedPositionX: particleTwoPosition.x + 0.1 * sin(gravityWellAngle * 23),
            normalisedPositionY: particleTwoPosition.y + 0.1 * cos(gravityWellAngle * 23),
            mass: 6,
            spin: 17)
        
        let particleThreePosition = particleLab.getGravityWellNormalisedPosition(gravityWell: .Three)
        
        particleLab.setGravityWellProperties(gravityWell: .Four,
            normalisedPositionX: particleThreePosition.x + 0.03 * sin(gravityWellAngle * 37),
            normalisedPositionY: particleThreePosition.y + 0.03 * cos(gravityWellAngle * 37),
            mass: 8,
            spin: 15)
    }
    
    func cloudChamberStep()
    {
        gravityWellAngle = gravityWellAngle + 0.02
        
        particleLab.setGravityWellProperties(gravityWell: .One,
            normalisedPositionX: 0.5 + 0.1 * sin(gravityWellAngle + floatPi * 0.5),
            normalisedPositionY: 0.5 + 0.1 * cos(gravityWellAngle + floatPi * 0.5),
            mass: 11 * sin(gravityWellAngle / 1.9),
            spin: 23 * cos(gravityWellAngle / 2.1))
        
        particleLab.setGravityWellProperties(gravityWell: .Four,
            normalisedPositionX: 0.5 + 0.1 * sin(gravityWellAngle + floatPi * 1.5),
            normalisedPositionY: 0.5 + 0.1 * cos(gravityWellAngle + floatPi * 1.5),
            mass: 11 * sin(gravityWellAngle / 1.9),
            spin: 23 * cos(gravityWellAngle / 2.1))
        
        particleLab.setGravityWellProperties(gravityWell: .Two,
            normalisedPositionX: 0.5 + (0.35 + sin(gravityWellAngle * 2.7)) * cos(gravityWellAngle / 1.3),
            normalisedPositionY: 0.5 + (0.35 + sin(gravityWellAngle * 2.7)) * sin(gravityWellAngle / 1.3),
            mass: 26, spin: -19 * sin(gravityWellAngle * 1.5))
        
        particleLab.setGravityWellProperties(gravityWell: .Three,
            normalisedPositionX: 0.5 + (0.35 + sin(gravityWellAngle * 2.7)) * cos(gravityWellAngle / 1.3 + floatPi),
            normalisedPositionY: 0.5 + (0.35 + sin(gravityWellAngle * 2.7)) * sin(gravityWellAngle / 1.3 + floatPi),
            mass: 26, spin: -19 * sin(gravityWellAngle * 1.5))
    }
    
    
    override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask
    {
        return UIInterfaceOrientationMask.Landscape
    }
    
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle
    {
        return UIStatusBarStyle.LightContent
    }
    
    override func didReceiveMemoryWarning()
    {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
}


enum DemoModes: String
{
    case cloudChamber = "Cloud Chamber"
    case orbits = "Orbits"
    case multiTouch = "Multiple Touch"
    case respawn = "Respawning"
}




