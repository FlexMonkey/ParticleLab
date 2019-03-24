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
    
    let floatPi = Float(Double.pi)
    
    let hiDPI = false
    
    var particleLab: ParticleLab!
    
    var gravityWellAngle: Float = 0
    
    var demoMode = DemoModes.cloudChamber
    
    var currentTouches = Set<UITouch>()
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.black
        
        print(UIScreen.main.scale)
    
        let numParticles = ParticleCount.EightMillion
        
        if hiDPI
        {
            particleLab = ParticleLab(width: UInt(view.frame.width * UIScreen.main.scale),
                                      height: UInt(view.frame.height * UIScreen.main.scale),
                numParticles: numParticles,
                hiDPI: true)
        }
        else
        {
            particleLab = ParticleLab(width: UInt(view.frame.width),
                height: UInt(view.frame.height),
                numParticles: numParticles,
                hiDPI: false)
        }
        
        particleLab.frame = CGRect(x: 0,
                                   y: 0,
                                   width: view.frame.width,
                                   height: view.frame.height)
        
        particleLab.particleLabDelegate = self
        particleLab.dragFactor = 0.5
        particleLab.clearOnStep = true
        particleLab.respawnOutOfBoundsParticles = false
        
        view.addSubview(particleLab)
        
        menuButton.layer.borderColor = UIColor.lightGray.cgColor
        menuButton.layer.borderWidth = 1
        menuButton.layer.cornerRadius = 5
        menuButton.layer.backgroundColor = UIColor.darkGray.cgColor
        menuButton.showsTouchWhenHighlighted = true
        menuButton.imageView?.contentMode = UIView.ContentMode.scaleAspectFit
        menuButton.setImage(UIImage(named: "hamburger.png"), for: .normal)
        menuButton.addTarget(self, action: #selector(ViewController.displayCallout), for: .touchDown)
        
        view.addSubview(menuButton)
        
        statusLabel.text = "http://flexmonkey.blogspot.co.uk"
        statusLabel.textColor = UIColor.darkGray
        
        view.addSubview(statusLabel)
    }
    
    override func viewDidLayoutSubviews()
    {
        statusLabel.frame = CGRect(x: 5,
                                   y: view.frame.height - statusLabel.intrinsicContentSize.height,
            width: view.frame.width,
            height: statusLabel.intrinsicContentSize.height)

        menuButton.frame = CGRect(x: view.frame.width - 35,
            y: view.frame.height - 35,
            width: 30,
            height: 30)
    }
    
    func particleLabMetalUnavailable()
    {
        // handle metal unavailable here
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        currentTouches = currentTouches.union(touches)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        currentTouches.subtract(touches)
    }
    
    @objc func displayCallout()
    {
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        let cloudChamberAction = UIAlertAction(title: DemoModes.cloudChamber.rawValue, style: .default, handler: calloutActionHandler)
        let orbitsAction = UIAlertAction(title: DemoModes.orbits.rawValue, style: .default, handler: calloutActionHandler)
        let multiTouchAction = UIAlertAction(title: DemoModes.multiTouch.rawValue, style: .default, handler: calloutActionHandler)
        let respawnAction = UIAlertAction(title: DemoModes.respawn.rawValue, style: .default, handler: calloutActionHandler)
        let iPadProAction = UIAlertAction(title: DemoModes.iPadProDemo.rawValue, style: .default, handler: calloutActionHandler)
        
        alertController.addAction(cloudChamberAction)
        alertController.addAction(orbitsAction)
        alertController.addAction(multiTouchAction)
        alertController.addAction(respawnAction)
        alertController.addAction(iPadProAction)
        
        if let popoverPresentationController = alertController.popoverPresentationController
        {
            let xx = menuButton.frame.origin.x
            let yy = menuButton.frame.origin.y
            
            popoverPresentationController.sourceRect = CGRect(x: xx, y: yy, width: menuButton.frame.width, height: menuButton.frame.height)
            popoverPresentationController.sourceView = view
        }
        
        particleLab.isPaused = true
        
        present(alertController, animated: true, completion: {self.particleLab.isPaused = false})
    }
 
    func calloutActionHandler(value: UIAlertAction!) -> Void
    {
        demoMode = DemoModes(rawValue: value.title!) ?? DemoModes.iPadProDemo
        
        switch demoMode
        {
        case .orbits:
            particleLab.dragFactor = 0.82
            particleLab.respawnOutOfBoundsParticles = true
            particleLab.clearOnStep = true
            particleLab.resetParticles(edgesOnly: false)
            
        case .cloudChamber:
            particleLab.dragFactor = 0.8
            particleLab.respawnOutOfBoundsParticles = false
            particleLab.clearOnStep = true
            particleLab.resetParticles(edgesOnly: true)
            
        case .multiTouch:
            particleLab.dragFactor = 0.95
            particleLab.respawnOutOfBoundsParticles = false
            particleLab.clearOnStep = true
            particleLab.resetParticles(edgesOnly: false)
            
        case .respawn:
            particleLab.dragFactor = 0.98
            particleLab.respawnOutOfBoundsParticles = true
            particleLab.clearOnStep = true
            particleLab.resetParticles(edgesOnly: true)
            
        case .iPadProDemo:
            particleLab.dragFactor = 0.5
            particleLab.respawnOutOfBoundsParticles = true
            particleLab.clearOnStep = false
            particleLab.resetParticles(edgesOnly: true)
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
            
        case .iPadProDemo:
            ipadProDemoStep()
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
        
        for (i, currentTouch) in currentTouchesArray.enumerated() where i < 4
        {
            let touchMultiplier = currentTouch.force == 0 && currentTouch.maximumPossibleForce == 0
                ? 1
                : Float(currentTouch.force / currentTouch.maximumPossibleForce)
            
            particleLab.setGravityWellProperties(gravityWellIndex: i,
                                                 normalisedPositionX: Float(currentTouch.location(in: view).x / view.frame.width) ,
                                                 normalisedPositionY: Float(currentTouch.location(in: view).y / view.frame.height),
                mass: 40 * touchMultiplier,
                spin: 20 * touchMultiplier)
        }
 
        for i in currentTouchesArray.count ..< 4
        {
            particleLab.setGravityWellProperties(gravityWellIndex: i,
                normalisedPositionX: 0.5,
                normalisedPositionY: 0.5,
                mass: 0,
                spin: 0)
        }
        
    }
    
    func ipadProDemoStep()
    {
        gravityWellAngle = gravityWellAngle + 0.004
        
        particleLab.setGravityWellProperties(gravityWell: .One,
            normalisedPositionX: 0.5 + 0.1 * sin(gravityWellAngle + floatPi * 0.5),
            normalisedPositionY: 0.5 + 0.1 * cos(gravityWellAngle + floatPi * 0.5),
            mass: 11 * sin(gravityWellAngle / 1.8),
            spin: 23 * cos(gravityWellAngle / 2.1))
        
        particleLab.setGravityWellProperties(gravityWell: .Two,
            normalisedPositionX: 0.5 + 0.1 * sin(gravityWellAngle + floatPi * 1.5),
            normalisedPositionY: 0.5 + 0.1 * cos(gravityWellAngle + floatPi * 1.5),
            mass: 11 * sin(gravityWellAngle / 0.9),
            spin: 23 * cos(gravityWellAngle / 1.05))
        
        particleLab.setGravityWellProperties(gravityWell: .Three,
            normalisedPositionX: 0.5 + (0.35 + sin(gravityWellAngle * 2.7)) * cos(gravityWellAngle / 1.3),
            normalisedPositionY: 0.5 + (0.35 + sin(gravityWellAngle * 2.7)) * sin(gravityWellAngle / 1.3),
            mass: 13, spin: 19 * sin(gravityWellAngle * 1.75))
        
        let particleOnePosition = particleLab.getGravityWellNormalisedPosition(gravityWell: .One)
        let particleTwoPosition = particleLab.getGravityWellNormalisedPosition(gravityWell: .Two)
        let particleThreePosition = particleLab.getGravityWellNormalisedPosition(gravityWell: .Three)
        
        particleLab.setGravityWellProperties(gravityWell: .Four,
            normalisedPositionX: (particleOnePosition.x + particleTwoPosition.x + particleThreePosition.x) / 3 + 0.03 * sin(gravityWellAngle),
            normalisedPositionY: (particleOnePosition.y + particleTwoPosition.y + particleThreePosition.y) / 3 + 0.03 * cos(gravityWellAngle),
            mass: 8 ,
            spin: 25 * sin(gravityWellAngle / 3 ))
    }
    
    func orbitsStep()
    {
        gravityWellAngle = gravityWellAngle + 0.0015
        
        particleLab.setGravityWellProperties(gravityWell: .One,
            normalisedPositionX: 0.5 + 0.006 * cos(gravityWellAngle * 43),
            normalisedPositionY: 0.5 + 0.006 * sin(gravityWellAngle * 43),
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
            normalisedPositionX: particleTwoPosition.x + 0.1 * cos(gravityWellAngle * 23),
            normalisedPositionY: particleTwoPosition.y + 0.1 * sin(gravityWellAngle * 23),
            mass: 6,
            spin: 17)
        
        let particleThreePosition = particleLab.getGravityWellNormalisedPosition(gravityWell: .Three)
        
        particleLab.setGravityWellProperties(gravityWell: .Four,
            normalisedPositionX: particleThreePosition.x + 0.03 * sin(gravityWellAngle * 37),
            normalisedPositionY: particleThreePosition.y + 0.03 * cos(gravityWellAngle * 37),
            mass: 8,
            spin: 25)
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
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscape
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func didReceiveMemoryWarning()
    {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
}


enum DemoModes: String
{
    case iPadProDemo = "iPad Pro Demo"
    case cloudChamber = "Cloud Chamber"
    case orbits = "Orbits"
    case multiTouch = "Multiple Touch"
    case respawn = "Respawning"
}




