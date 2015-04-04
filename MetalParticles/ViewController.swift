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
    let particleLab = ParticleLab()
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.blackColor()
        
        view.layer.addSublayer(particleLab)
        
        particleLab.gravityWellParticle.A.x = 280
        particleLab.gravityWellParticle.A.y = 280
        particleLab.gravityWellParticle.A.z = 6
        particleLab.gravityWellParticle.A.w = -2
        
        particleLab.gravityWellParticle.B.x = 280
        particleLab.gravityWellParticle.B.y = 1000
        particleLab.gravityWellParticle.B.z = 6
        particleLab.gravityWellParticle.B.w = 2
        
        particleLab.gravityWellParticle.C.x = 1000
        particleLab.gravityWellParticle.C.y = 280
        particleLab.gravityWellParticle.C.z = 6
        particleLab.gravityWellParticle.C.w = 2
        
        particleLab.gravityWellParticle.D.x = 1000
        particleLab.gravityWellParticle.D.y = 1000
        particleLab.gravityWellParticle.D.z = 6
        particleLab.gravityWellParticle.D.w = -2
    }
    
    override func viewDidLayoutSubviews()
    {
        if view.frame.height > view.frame.width
        {
            let imageSide = view.frame.width
            
            particleLab.frame = CGRect(x: 0, y: view.frame.height / 2.0 - imageSide / 2, width: imageSide, height: imageSide).rectByInsetting(dx: -1, dy: 01)
        }
        else
        {
            let imageSide = view.frame.height
            
            particleLab.frame = CGRect(x: view.frame.width / 2.0 - imageSide / 2 , y: 0, width: imageSide, height: imageSide).rectByInsetting(dx: -1, dy: -1)
        }
    }
    
    override func didReceiveMemoryWarning()
    {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
}







