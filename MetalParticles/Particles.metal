//
//  Particles.metal
//  MetalParticles
//
//  Created by Simon Gladman on 17/01/2015.
//  Copyright (c) 2015 Simon Gladman. All rights reserved.
//
//  Thanks to: http://memkite.com/blog/2014/12/15/data-parallel-programming-with-metal-and-swift-for-iphoneipad-gpu/

#include <metal_stdlib>
using namespace metal;

constant float4 colors[] = {float4(1.0, 0.0 , 0.0 , 1.0), float4(0.0, 1.0, 0.0, 1.0), float4(0.0, 0.0, 1.0, 1.0)};

constant float masses[] = {0.121, 0.120, 0.119};

constant uint imageWidth = 1280;

kernel void particleRendererShader(texture2d<float, access::write> outTexture [[texture(0)]],
                                   // texture2d<float, access::read> inTexture [[texture(1)]],
                                   
                                   const device float4x4 *inParticles [[ buffer(0) ]],
                                   device float4x4 *outParticles [[ buffer(1) ]],
                                   
                                   constant float4x4 &inGravityWell [[ buffer(2) ]],
                                   
                                   uint id [[thread_position_in_grid]])
{
    const float4x4 inParticle = inParticles[id];
    
    const uint type = id % 3;
    
    const float4 outColor = colors[type];
    const float massOne = masses[type];
    
    // ---
    
    const uint2 particlePositionA(inParticle[0].x, inParticle[0].y);
    
    if (particlePositionA.x > 0 && particlePositionA.y > 0 && particlePositionA.x < imageWidth && particlePositionA.y < imageWidth)
    {
        outTexture.write(outColor, particlePositionA);
    }
    
    const float2 particlePositionAFloat(inParticle[0].x, inParticle[0].y);
    
    const float factorA = (1 / (fast::distance(particlePositionAFloat, float2(inGravityWell[0].x, inGravityWell[0].y)))) * massOne;
    const float factorATwo = (1 / (fast::distance(particlePositionAFloat, float2(inGravityWell[1].x, inGravityWell[1].y)))) * massOne;
    const float factorAThree = (1 / (fast::distance(particlePositionAFloat, float2(inGravityWell[2].x, inGravityWell[2].y)))) * massOne;
    const float factorAFour = (1 / (fast::distance(particlePositionAFloat, float2(inGravityWell[3].x, inGravityWell[3].y)))) * massOne;
    
    // ---
    
    const uint2 particlePositionB(inParticle[1].x, inParticle[1].y);
    
    if (particlePositionB.x > 0 && particlePositionB.y > 0 && particlePositionB.x < imageWidth && particlePositionB.y < imageWidth)
    {
        outTexture.write(outColor, particlePositionB);
    }
    
    const float2 particlePositionBFloat(inParticle[1].x, inParticle[1].y);
    
    const float factorB = (1 / (fast::distance(particlePositionBFloat, float2(inGravityWell[0].x, inGravityWell[0].y)))) * massOne;
    const float factorBTwo = (1 / (fast::distance(particlePositionBFloat, float2(inGravityWell[1].x, inGravityWell[1].y)))) * massOne;
    const float factorBThree = (1 / (fast::distance(particlePositionBFloat, float2(inGravityWell[2].x, inGravityWell[2].y)))) * massOne;
    const float factorBFour = (1 / (fast::distance(particlePositionBFloat, float2(inGravityWell[3].x, inGravityWell[3].y)))) * massOne;
    
    // ---
    
    
    const uint2 particlePositionC(inParticle[2].x, inParticle[2].y);
    
    if (particlePositionC.x > 0 && particlePositionC.y > 0 && particlePositionC.x < imageWidth && particlePositionC.y < imageWidth)
    {
        outTexture.write(outColor, particlePositionC);
    }
    
    const float2 particlePositionCFloat(inParticle[2].x, inParticle[2].y);
    
    const float factorC = (1 / (fast::distance(particlePositionCFloat, float2(inGravityWell[0].x, inGravityWell[0].y)))) * massOne;
    const float factorCTwo = (1 / (fast::distance(particlePositionCFloat, float2(inGravityWell[1].x, inGravityWell[1].y)))) * massOne;
    const float factorCThree = (1 / (fast::distance(particlePositionCFloat, float2(inGravityWell[2].x, inGravityWell[2].y)))) * massOne;
    const float factorCFour = (1 / (fast::distance(particlePositionCFloat, float2(inGravityWell[3].x, inGravityWell[3].y)))) * massOne;
    
    // ---
    
    
    const uint2 particlePositionD(inParticle[3].x, inParticle[3].y);
    
    if (particlePositionD.x > 0 && particlePositionD.y > 0 && particlePositionD.x < imageWidth && particlePositionD.y < imageWidth)
    {
        outTexture.write(outColor, particlePositionD);
    }
    
    const float2 particlePositionDFloat(inParticle[3].x, inParticle[3].y);
    
    const float factorD = (1 / (fast::distance(particlePositionDFloat, float2(inGravityWell[0].x, inGravityWell[0].y)))) * massOne;
    const float factorDTwo = (1 / (fast::distance(particlePositionDFloat, float2(inGravityWell[1].x, inGravityWell[1].y)))) * massOne;
    const float factorDThree = (1 / (fast::distance(particlePositionDFloat, float2(inGravityWell[2].x, inGravityWell[2].y)))) * massOne;
    const float factorDFour = (1 / (fast::distance(particlePositionDFloat, float2(inGravityWell[3].x, inGravityWell[3].y)))) * massOne;
    
    
    // ---
    
    float4x4 outParticle;
    
    outParticle[0] = {
        inParticle[0].x + inParticle[0].z,
        inParticle[0].y + inParticle[0].w,
        (inParticle[0].z * 0.999) +
            ((inGravityWell[0].x - inParticle[0].x) * factorA) +
            ((inGravityWell[1].x - inParticle[0].x) * factorATwo) +
            ((inGravityWell[2].x - inParticle[0].x) * factorAThree) +
            ((inGravityWell[3].x - inParticle[0].x) * factorAFour),
        (inParticle[0].w * 0.999) +
            ((inGravityWell[0].y - inParticle[0].y) * factorA) +
            ((inGravityWell[1].y - inParticle[0].y) * factorATwo) +
            ((inGravityWell[2].y - inParticle[0].y) * factorAThree) +
            ((inGravityWell[3].y - inParticle[0].y) * factorAFour),
    };
    
    
    outParticle[1] = {
        inParticle[1].x + inParticle[1].z,
        inParticle[1].y + inParticle[1].w,
        (inParticle[1].z * 0.999) +
            ((inGravityWell[0].x - inParticle[1].x) * factorB) +
            ((inGravityWell[1].x - inParticle[1].x) * factorBTwo) +
            ((inGravityWell[2].x - inParticle[1].x) * factorBThree) +
            ((inGravityWell[3].x - inParticle[1].x) * factorBFour),
        (inParticle[1].w * 0.999) +
            ((inGravityWell[0].y - inParticle[1].y) * factorB) +
            ((inGravityWell[1].y - inParticle[1].y) * factorBTwo) +
            ((inGravityWell[2].y - inParticle[1].y) * factorBThree) +
            ((inGravityWell[3].y - inParticle[1].y) * factorBFour),
    };
    
    
    outParticle[2] = {
        inParticle[2].x + inParticle[2].z,
        inParticle[2].y + inParticle[2].w,
        (inParticle[2].z * 0.999) +
            ((inGravityWell[0].x - inParticle[2].x) * factorC) +
            ((inGravityWell[1].x - inParticle[2].x) * factorCTwo) +
            ((inGravityWell[2].x - inParticle[2].x) * factorCThree) +
            ((inGravityWell[3].x - inParticle[2].x) * factorCFour),
        (inParticle[2].w * 0.999) +
            ((inGravityWell[0].y - inParticle[2].y) * factorC) +
            ((inGravityWell[1].y - inParticle[2].y) * factorCTwo) +
            ((inGravityWell[2].y - inParticle[2].y) * factorCThree) +
            ((inGravityWell[3].y - inParticle[2].y) * factorCFour),
    };
    
    
    outParticle[3] = {
        inParticle[3].x + inParticle[3].z,
        inParticle[3].y + inParticle[3].w,
        (inParticle[3].z * 0.999) +
            ((inGravityWell[0].x - inParticle[3].x) * factorD) +
            ((inGravityWell[1].x - inParticle[3].x) * factorDTwo) +
            ((inGravityWell[2].x - inParticle[3].x) * factorDThree) +
            ((inGravityWell[3].x - inParticle[3].x) * factorDFour),
        (inParticle[3].w * 0.999) +
            ((inGravityWell[0].y - inParticle[3].y) * factorD) +
            ((inGravityWell[1].y - inParticle[3].y) * factorDTwo) +
            ((inGravityWell[2].y - inParticle[3].y) * factorDThree) +
            ((inGravityWell[3].y - inParticle[3].y) * factorDFour),
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