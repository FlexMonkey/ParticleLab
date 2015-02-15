//
//  SwarmGenome.swift
//  Emergent
//
//  Created by Simon Gladman on 09/02/2015.
//  Copyright (c) 2015 Simon Gladman. All rights reserved.
//

import Foundation

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

let SwarmGenomeZero = SwarmGenome()

struct SwarmGenome
{
    var radius: Float = 0
    var c1_cohesion: Float = 0
    var c2_alignment: Float = 0
    var c3_seperation: Float = 0
    var c4_steering: Float = 0
    var c5_paceKeeping: Float = 0
    var normalSpeed: Float = 0;
    
    func toString() -> String
    {
        return radius.decimalPartToString() + c1_cohesion.decimalPartToString() + c2_alignment.decimalPartToString() + c3_seperation.decimalPartToString() + c4_steering.decimalPartToString() + c5_paceKeeping.decimalPartToString() + normalSpeed.decimalPartToString()
    }
    
    static func fromString(value: String) -> SwarmGenome
    {
        let r = value[0...1].floatValue / 100.0
        let c1 = value[2...3].floatValue / 100.0
        let c2 = value[4...5].floatValue / 100.0
        let c3 = value[6...7].floatValue / 100.0
        let c4 = value[8...9].floatValue / 100.0
        let c5 = value[10...11].floatValue / 100.0
        let n = value[12...13].floatValue / 100.0
        
        return SwarmGenome(radius: r, c1_cohesion: c1, c2_alignment: c2, c3_seperation: c3, c4_steering: c4, c5_paceKeeping: c5, normalSpeed: n)
    }
}