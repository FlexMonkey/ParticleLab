//
//  Particles.metal
//  MetalParticles
//
//  Created by Simon Gladman on 17/01/2015.
//  Copyright (c) 2015 Simon Gladman. All rights reserved.
//
//  Thanks to: http://memkite.com/blog/2014/12/15/data-parallel-programming-with-metal-and-swift-for-iphoneipad-gpu/
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

#include <metal_stdlib>
using namespace metal;

kernel void particleRendererShader(texture2d<float, access::write> outTexture [[texture(0)]],
                                   // texture2d<float, access::read> inTexture [[texture(1)]],
                                   
                                   const device float4x4 *inParticles [[ buffer(0) ]],
                                   device float4x4 *outParticles [[ buffer(1) ]],
                                   
                                   constant float4x4 &inGravityWell [[ buffer(2) ]],
                                   
                                   constant float3 &particleColor [[ buffer(3) ]],
                                   
                                   constant float &imageWidth [[ buffer(4) ]],
                                   constant float &imageHeight [[ buffer(5) ]],
                                   
                                   uint id [[thread_position_in_grid]])
{
    const float4x4 inParticle = inParticles[id];
    
    const uint type = id % 3;
    
    const float4 colors[] = {
        float4(particleColor.r, particleColor.g , particleColor.b , 1.0),
        float4(particleColor.b, particleColor.r, particleColor.g, 1.0),
        float4(particleColor.g, particleColor.b, particleColor.r, 1.0)};
    
    const float4 outColor = colors[type];
    
    // ---
    
    const float2 gravityWellZeroPosition =  float2(inGravityWell[0].x, inGravityWell[0].y);
    const float2 gravityWellOnePosition =   float2(inGravityWell[1].x, inGravityWell[1].y);
    const float2 gravityWellTwoPosition =   float2(inGravityWell[2].x, inGravityWell[2].y);
    const float2 gravityWellThreePosition = float2(inGravityWell[3].x, inGravityWell[3].y);
    
    const float gravityWellZeroMass = inGravityWell[0].z + type;
    const float gravityWellOneMass = inGravityWell[1].z + type;
    const float gravityWellTwoMass = inGravityWell[2].z + type;
    const float gravityWellThreeMass = inGravityWell[3].z + type;
    
    const float gravityWellZeroSpin = inGravityWell[0].w + type;
    const float gravityWellOneSpin = inGravityWell[1].w + type;
    const float gravityWellTwoSpin = inGravityWell[2].w + type;
    const float gravityWellThreeSpin = inGravityWell[3].w + type;
    
    // ---
    
    const uint2 particlePositionA(inParticle[0].x, inParticle[0].y);
    
    if (particlePositionA.x > 0 && particlePositionA.y > 0 && particlePositionA.x < imageWidth && particlePositionA.y < imageHeight)
    {
        outTexture.write(outColor, particlePositionA);
    }
    
    const float2 particlePositionAFloat(inParticle[0].x, inParticle[0].y);
    
    const float factorAZero =   (gravityWellZeroMass / fast::pow(fast::distance(particlePositionAFloat, gravityWellZeroPosition),2));
    const float factorAOne =    (gravityWellOneMass / fast::pow(fast::distance(particlePositionAFloat, gravityWellOnePosition),2));
    const float factorATwo =    (gravityWellTwoMass / fast::pow(fast::distance(particlePositionAFloat, gravityWellTwoPosition),2));
    const float factorAThree =  (gravityWellThreeMass / fast::pow(fast::distance(particlePositionAFloat, gravityWellThreePosition),2));
    
    const float spinAZero =   (gravityWellZeroSpin / fast::pow(fast::distance(particlePositionAFloat, gravityWellZeroPosition),2));
    const float spinAOne =    (gravityWellOneSpin / fast::pow(fast::distance(particlePositionAFloat, gravityWellOnePosition),2));
    const float spinATwo =    (gravityWellTwoSpin / fast::pow(fast::distance(particlePositionAFloat, gravityWellTwoPosition),2));
    const float spinAThree =  (gravityWellThreeSpin / fast::pow(fast::distance(particlePositionAFloat, gravityWellThreePosition),2));
    
    // ---
    
    const uint2 particlePositionB(inParticle[1].x, inParticle[1].y);
    
    if (particlePositionB.x > 0 && particlePositionB.y > 0 && particlePositionB.x < imageWidth && particlePositionB.y < imageHeight)
    {
        outTexture.write(outColor, particlePositionB);
    }
    
    const float2 particlePositionBFloat(inParticle[1].x, inParticle[1].y);
    
    const float factorBZero =   (gravityWellZeroMass / fast::pow(fast::distance(particlePositionBFloat, gravityWellZeroPosition),2));
    const float factorBOne =    (gravityWellOneMass / fast::pow(fast::distance(particlePositionBFloat, gravityWellOnePosition),2));
    const float factorBTwo =    (gravityWellTwoMass / fast::pow(fast::distance(particlePositionBFloat, gravityWellTwoPosition),2));
    const float factorBThree =  (gravityWellThreeMass / fast::pow(fast::distance(particlePositionBFloat, gravityWellThreePosition),2));
    
    const float spinBZero =   (gravityWellZeroSpin / fast::pow(fast::distance(particlePositionBFloat, gravityWellZeroPosition),2));
    const float spinBOne =    (gravityWellOneSpin / fast::pow(fast::distance(particlePositionBFloat, gravityWellOnePosition),2));
    const float spinBTwo =    (gravityWellTwoSpin / fast::pow(fast::distance(particlePositionBFloat, gravityWellTwoPosition),2));
    const float spinBThree =  (gravityWellThreeSpin / fast::pow(fast::distance(particlePositionBFloat, gravityWellThreePosition),2));
    
    // ---
    
    
    const uint2 particlePositionC(inParticle[2].x, inParticle[2].y);
    
    if (particlePositionC.x > 0 && particlePositionC.y > 0 && particlePositionC.x < imageWidth && particlePositionC.y < imageHeight)
    {
        outTexture.write(outColor, particlePositionC);
    }
    
    const float2 particlePositionCFloat(inParticle[2].x, inParticle[2].y);
    
    const float factorCZero =   (gravityWellZeroMass / fast::pow(fast::distance(particlePositionCFloat, gravityWellZeroPosition),2));
    const float factorCOne =    (gravityWellOneMass / fast::pow(fast::distance(particlePositionCFloat, gravityWellOnePosition),2));
    const float factorCTwo =    (gravityWellTwoMass / fast::pow(fast::distance(particlePositionCFloat, gravityWellTwoPosition),2));
    const float factorCThree =  (gravityWellThreeMass / fast::pow(fast::distance(particlePositionCFloat, gravityWellThreePosition),2));
    
    const float spinCZero =   (gravityWellZeroSpin / fast::pow(fast::distance(particlePositionCFloat, gravityWellZeroPosition),2));
    const float spinCOne =    (gravityWellOneSpin / fast::pow(fast::distance(particlePositionCFloat, gravityWellOnePosition),2));
    const float spinCTwo =    (gravityWellTwoSpin / fast::pow(fast::distance(particlePositionCFloat, gravityWellTwoPosition),2));
    const float spinCThree =  (gravityWellThreeSpin / fast::pow(fast::distance(particlePositionCFloat, gravityWellThreePosition),2));
    
    // ---
    
    
    const uint2 particlePositionD(inParticle[3].x, inParticle[3].y);
    
    if (particlePositionD.x > 0 && particlePositionD.y > 0 && particlePositionD.x < imageWidth && particlePositionD.y < imageHeight)
    {
        outTexture.write(outColor, particlePositionD);
    }
    
    const float2 particlePositionDFloat(inParticle[3].x, inParticle[3].y);
    
    const float factorDZero =   (gravityWellZeroMass / fast::pow(fast::distance(particlePositionDFloat, gravityWellZeroPosition),2));
    const float factorDOne =    (gravityWellOneMass / fast::pow(fast::distance(particlePositionDFloat, gravityWellOnePosition),2));
    const float factorDTwo =    (gravityWellTwoMass / fast::pow(fast::distance(particlePositionDFloat, gravityWellTwoPosition),2));
    const float factorDThree =  (gravityWellThreeMass / fast::pow(fast::distance(particlePositionDFloat, gravityWellThreePosition),2));
    
    const float spinDZero =   (gravityWellZeroSpin / fast::pow(fast::distance(particlePositionDFloat, gravityWellZeroPosition),2));
    const float spinDOne =    (gravityWellOneSpin / fast::pow(fast::distance(particlePositionDFloat, gravityWellOnePosition),2));
    const float spinDTwo =    (gravityWellTwoSpin / fast::pow(fast::distance(particlePositionDFloat, gravityWellTwoPosition),2));
    const float spinDThree =  (gravityWellThreeSpin / fast::pow(fast::distance(particlePositionDFloat, gravityWellThreePosition),2));
    // ---
 
    float4x4 outParticle;
    
    outParticle[0] = {
        inParticle[0].x + inParticle[0].z,
        inParticle[0].y + inParticle[0].w,
        
        (inParticle[0].z * 0.97) +
            ((inGravityWell[0].x - inParticle[0].x) * factorAZero) +
            ((inGravityWell[1].x - inParticle[0].x) * factorAOne) +
            ((inGravityWell[2].x - inParticle[0].x) * factorATwo) +
            ((inGravityWell[3].x - inParticle[0].x) * factorAThree) +
        
            ((inGravityWell[0].y - inParticle[0].y) * spinAZero) +
            ((inGravityWell[1].y - inParticle[0].y) * spinAOne) +
            ((inGravityWell[2].y - inParticle[0].y) * spinATwo) +
            ((inGravityWell[3].y - inParticle[0].y) * spinAThree),
        
        (inParticle[0].w * 0.97) +
            ((inGravityWell[0].y - inParticle[0].y) * factorAZero) +
            ((inGravityWell[1].y - inParticle[0].y) * factorAOne) +
            ((inGravityWell[2].y - inParticle[0].y) * factorATwo) +
            ((inGravityWell[3].y - inParticle[0].y) * factorAThree)+
        
            ((inGravityWell[0].x - inParticle[0].x) * -spinAZero) +
            ((inGravityWell[1].x - inParticle[0].x) * -spinAOne) +
            ((inGravityWell[2].x - inParticle[0].x) * -spinATwo) +
            ((inGravityWell[3].x - inParticle[0].x) * -spinAThree),
    };
    
    
    outParticle[1] = {
        inParticle[1].x + inParticle[1].z,
        inParticle[1].y + inParticle[1].w,
        
        (inParticle[1].z * 0.97) +
            ((inGravityWell[0].x - inParticle[1].x) * factorBZero) +
            ((inGravityWell[1].x - inParticle[1].x) * factorBOne) +
            ((inGravityWell[2].x - inParticle[1].x) * factorBTwo) +
            ((inGravityWell[3].x - inParticle[1].x) * factorBThree) +
        
            ((inGravityWell[0].y - inParticle[1].y) * spinBZero) +
            ((inGravityWell[1].y - inParticle[1].y) * spinBOne) +
            ((inGravityWell[2].y - inParticle[1].y) * spinBTwo) +
            ((inGravityWell[3].y - inParticle[1].y) * spinBThree),
        
        (inParticle[1].w * 0.97) +
            ((inGravityWell[0].y - inParticle[1].y) * factorBZero) +
            ((inGravityWell[1].y - inParticle[1].y) * factorBOne) +
            ((inGravityWell[2].y - inParticle[1].y) * factorBTwo) +
            ((inGravityWell[3].y - inParticle[1].y) * factorBThree) +
        
            ((inGravityWell[0].x - inParticle[1].x) * -spinBZero) +
            ((inGravityWell[1].x - inParticle[1].x) * -spinBOne) +
            ((inGravityWell[2].x - inParticle[1].x) * -spinBTwo) +
            ((inGravityWell[3].x - inParticle[1].x) * -spinBThree),
    };
    
    
    outParticle[2] = {
        inParticle[2].x + inParticle[2].z,
        inParticle[2].y + inParticle[2].w,
        
        (inParticle[2].z * 0.97) +
            ((inGravityWell[0].x - inParticle[2].x) * factorCZero) +
            ((inGravityWell[1].x - inParticle[2].x) * factorCOne) +
            ((inGravityWell[2].x - inParticle[2].x) * factorCTwo) +
            ((inGravityWell[3].x - inParticle[2].x) * factorCThree) +
        
            ((inGravityWell[0].y - inParticle[2].y) * spinCZero) +
            ((inGravityWell[1].y - inParticle[2].y) * spinCOne) +
            ((inGravityWell[2].y - inParticle[2].y) * spinCTwo) +
            ((inGravityWell[3].y - inParticle[2].y) * spinCThree),
        
        (inParticle[2].w * 0.97) +
            ((inGravityWell[0].y - inParticle[2].y) * factorCZero) +
            ((inGravityWell[1].y - inParticle[2].y) * factorCOne) +
            ((inGravityWell[2].y - inParticle[2].y) * factorCTwo) +
            ((inGravityWell[3].y - inParticle[2].y) * factorCThree) +
        
            ((inGravityWell[0].x - inParticle[2].x) * -spinCZero) +
            ((inGravityWell[1].x - inParticle[2].x) * -spinCOne) +
            ((inGravityWell[2].x - inParticle[2].x) * -spinCTwo) +
            ((inGravityWell[3].x - inParticle[2].x) * -spinCThree),
    };
    
    
    outParticle[3] = {
        inParticle[3].x + inParticle[3].z,
        inParticle[3].y + inParticle[3].w,
        
        (inParticle[3].z * 0.97) +
            ((inGravityWell[0].x - inParticle[3].x) * factorDZero) +
            ((inGravityWell[1].x - inParticle[3].x) * factorDOne) +
            ((inGravityWell[2].x - inParticle[3].x) * factorDTwo) +
            ((inGravityWell[3].x - inParticle[3].x) * factorDThree) +
        
            ((inGravityWell[0].y - inParticle[3].y) * spinDZero) +
            ((inGravityWell[1].y - inParticle[3].y) * spinDOne) +
            ((inGravityWell[2].y - inParticle[3].y) * spinDTwo) +
            ((inGravityWell[3].y - inParticle[3].y) * spinDThree),
        
        (inParticle[3].w * 0.97) +
            ((inGravityWell[0].y - inParticle[3].y) * factorDZero) +
            ((inGravityWell[1].y - inParticle[3].y) * factorDOne) +
            ((inGravityWell[2].y - inParticle[3].y) * factorDTwo) +
            ((inGravityWell[3].y - inParticle[3].y) * factorDThree) +
        
            ((inGravityWell[0].x - inParticle[3].x) * -spinDZero) +
            ((inGravityWell[1].x - inParticle[3].x) * -spinDOne) +
            ((inGravityWell[2].x - inParticle[3].x) * -spinDTwo) +
            ((inGravityWell[3].x - inParticle[3].x) * -spinDThree),
    };
    
    outParticles[id] = outParticle;
 
    
    // ----
    /*
     uint2 textureCoordinate(fast::floor(id / imageWidth),id % int(imageWidth));
     
     if (textureCoordinate.x < imageWidth && textureCoordinate.y < imageWidth)
     {
     float4 accumColor = inTexture.read(textureCoordinate);
     
     accumColor.rgb = (accumColor.rgb * 0.9f);
     accumColor.a = 1.0f;
     
     outTexture.write(accumColor, textureCoordinate);
     }
     */
    
}