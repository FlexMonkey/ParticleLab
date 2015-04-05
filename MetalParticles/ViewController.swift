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
    var particleLab: ParticleLab!
    
    var gravityWellAngle: Float = 0
    
    var frequency = Float(0.0);
    var amplitude = Float(0.0);
    
    let analyzer: AKAudioAnalyzer
    let microphone: Microphone
    
    override init() {
        microphone = Microphone()
        analyzer = AKAudioAnalyzer(audioSource: microphone.auxilliaryOutput)
        super.init()
    }
    
    required init(coder aDecoder: NSCoder) {
        microphone = Microphone()
        analyzer = AKAudioAnalyzer(audioSource: microphone.auxilliaryOutput)
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        AKOrchestra.addInstrument(microphone)
        AKOrchestra.addInstrument(analyzer)
        microphone.start()
        analyzer.start()
        
        view.backgroundColor = UIColor.blackColor()

        if view.frame.height < view.frame.width
        {
            particleLab = ParticleLab(width: UInt(view.frame.width), height: UInt(view.frame.height))
            particleLab.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: view.frame.height)
        }
        else
        {
            particleLab = ParticleLab(width: UInt(view.frame.height), height: UInt(view.frame.width))
            particleLab.frame = CGRect(x: 0, y: 0, width: view.frame.height, height: view.frame.width)
        }
        
        view.layer.addSublayer(particleLab)
 
        particleLab.showGravityWellPositions = false
        
        particleLab.particleLabDelegate = self

    }
    
    let floatPi = Float(M_PI)
    
    var gravityWellRadius: Float = 0

    func particleLabDidUpdate()
    {
        amplitude = analyzer.trackedAmplitude.value;
        frequency = analyzer.trackedFrequency.value
        
        let mass1 = amplitude + (frequency / 30)
        let spin1 = amplitude + (frequency / 40)
        let mass2 = -mass1 / 2
        let spin2 = -spin1 * 2
     
        gravityWellAngle = gravityWellAngle + 0.01 + amplitude
        
        let normalisedFrequency = CGFloat(frequency / 10000);
        let targetColors = UIColor(hue: normalisedFrequency, saturation: 1, brightness: 1, alpha: 1).getRGB()
          particleLab.particleColor = ParticleColor(
            R: (particleLab.particleColor.R * 19 + targetColors.redComponent) / 20,
            G: (particleLab.particleColor.G * 19 + targetColors.greenComponent) / 20,
            B: (particleLab.particleColor.B * 19 + targetColors.blueComponent) / 20,
            A: 1.0)
  
        if amplitude > gravityWellRadius
        {
            gravityWellRadius = amplitude
        }
        else
        {
            gravityWellRadius *= 0.9
        }
        
        let adjustedRadius = 0.05 + gravityWellRadius
        
        particleLab.setGravityWellProperties(gravityWell: .One,
            normalisedPositionX: 0.5 + adjustedRadius * 2 * sin(gravityWellAngle),
            normalisedPositionY: 0.5 + adjustedRadius * 2 * cos(gravityWellAngle),
            mass: mass1,
            spin: spin1
        )
        
        particleLab.setGravityWellProperties(gravityWell: .Two,
            normalisedPositionX: 0.5 + adjustedRadius * sin(gravityWellAngle + floatPi * 0.5),
            normalisedPositionY: 0.5 + adjustedRadius * cos(gravityWellAngle + floatPi * 0.5),
            mass: mass2,
            spin: spin2
        )
        
        particleLab.setGravityWellProperties(gravityWell: .Three,
            normalisedPositionX: 0.5 + adjustedRadius * 2 * sin(gravityWellAngle + floatPi),
            normalisedPositionY: 0.5 + adjustedRadius * 2 * cos(gravityWellAngle + floatPi),
            mass: mass1,
            spin: spin1
        )
        
        particleLab.setGravityWellProperties(gravityWell: .Four,
            normalisedPositionX: 0.5 + adjustedRadius * sin(gravityWellAngle + floatPi * 1.5),
            normalisedPositionY: 0.5 + adjustedRadius * cos(gravityWellAngle + floatPi * 1.5),
            mass: mass2,
            spin:spin2
        )
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







