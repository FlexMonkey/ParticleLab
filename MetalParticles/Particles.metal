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


kernel void particleRendererShader(texture2d<float, access::write> outTexture [[texture(0)]],
                                   // texture2d<float, access::read> inTexture [[texture(1)]],
                                   
                                   const device float4x4 *inParticles [[ buffer(0) ]],
                                   device float4x4 *outParticles [[ buffer(1) ]],
                                   
                                   constant float4x4 &inGravityWell [[ buffer(2) ]],
                                   
                                   uint id [[thread_position_in_grid]])
{
    const float imageWidth = 1280;
    const float4x4 inParticle = inParticles[id];
    
    const int type = id % 3;
    
    const float4 outColor((type == 0 ? 1 : 0.0),
                          (type == 1 ? 1 : 0.0),
                          (type == 2 ? 1 : 0.0),
                          1.0);
    
    const float massOne = (type == 0 ? 0.121 : (type == 1 ? 0.120 : 0.119));
    
    const uint2 particlePositionA(inParticle[0].x, inParticle[0].y);
    
    if (particlePositionA.x > 0 && particlePositionA.y > 0 && particlePositionA.x < imageWidth && particlePositionA.y < imageWidth)
    {
        outTexture.write(outColor, particlePositionA);
    }
    
    const float2 particlePositionAFloat(inParticle[0].x, inParticle[0].y);
    
    const float distA = fast::distance(particlePositionAFloat, float2(inGravityWell[0].x, inGravityWell[0].y));
    const float distATwo = fast::distance(particlePositionAFloat, float2(inGravityWell[1].x, inGravityWell[1].y));
    const float distAThree = fast::distance(particlePositionAFloat, float2(inGravityWell[2].x, inGravityWell[2].y));
    const float distAFour = fast::distance(particlePositionAFloat, float2(inGravityWell[3].x, inGravityWell[3].y));
    
    const float factorA = (1 / distA) * massOne;
    const float factorATwo = (1 / distATwo) * massOne;
    const float factorAThree = (1 / distAThree) * massOne;
    const float factorAFour = (1 / distAFour) * massOne;
    
    // ---
    
    const uint2 particlePositionB(inParticle[1].x, inParticle[1].y);
    
    if (particlePositionB.x > 0 && particlePositionB.y > 0 && particlePositionB.x < imageWidth && particlePositionB.y < imageWidth)
    {
        outTexture.write(outColor, particlePositionB);
    }
    
    const float2 particlePositionBFloat(inParticle[1].x, inParticle[1].y);
    
    const float distB = fast::distance(particlePositionBFloat, float2(inGravityWell[0].x, inGravityWell[0].y));
    const float distBTwo = fast::distance(particlePositionBFloat, float2(inGravityWell[1].x, inGravityWell[1].y));
    const float distBThree = fast::distance(particlePositionBFloat, float2(inGravityWell[2].x, inGravityWell[2].y));
    const float distBFour = fast::distance(particlePositionBFloat, float2(inGravityWell[3].x, inGravityWell[3].y));
    
    const float factorB = (1 / distB) * massOne;
    const float factorBTwo = (1 / distBTwo) * massOne;
    const float factorBThree = (1 / distBThree) * massOne;
    const float factorBFour = (1 / distBFour) * massOne;
    
    // ---
    
    
    const uint2 particlePositionC(inParticle[2].x, inParticle[2].y);
    
    if (particlePositionC.x > 0 && particlePositionC.y > 0 && particlePositionC.x < imageWidth && particlePositionC.y < imageWidth)
    {
        outTexture.write(outColor, particlePositionC);
    }
    
    const float2 particlePositionCFloat(inParticle[2].x, inParticle[2].y);
    
    const float distC = fast::distance(particlePositionCFloat, float2(inGravityWell[0].x, inGravityWell[0].y));
    const float distCTwo = fast::distance(particlePositionCFloat, float2(inGravityWell[1].x, inGravityWell[1].y));
    const float distCThree = fast::distance(particlePositionCFloat, float2(inGravityWell[2].x, inGravityWell[2].y));
    const float distCFour = fast::distance(particlePositionCFloat, float2(inGravityWell[3].x, inGravityWell[3].y));
    
    const float factorC = (1 / distC) * massOne;
    const float factorCTwo = (1 / distCTwo) * massOne;
    const float factorCThree = (1 / distCThree) * massOne;
    const float factorCFour = (1 / distCFour) * massOne;
    
    // ---
    
    
    const uint2 particlePositionD(inParticle[3].x, inParticle[3].y);
    
    if (particlePositionD.x > 0 && particlePositionD.y > 0 && particlePositionD.x < imageWidth && particlePositionD.y < imageWidth)
    {
        outTexture.write(outColor, particlePositionD);
    }
    
    const float2 particlePositionDFloat(inParticle[3].x, inParticle[3].y);
    
    const float distD = fast::distance(particlePositionDFloat, float2(inGravityWell[0].x, inGravityWell[0].y));
    const float distDTwo = fast::distance(particlePositionDFloat, float2(inGravityWell[1].x, inGravityWell[1].y));
    const float distDThree = fast::distance(particlePositionDFloat, float2(inGravityWell[2].x, inGravityWell[2].y));
    const float distDFour = fast::distance(particlePositionDFloat, float2(inGravityWell[3].x, inGravityWell[3].y));
    
    const float factorD = (1 / distD) * massOne;
    const float factorDTwo = (1 / distDTwo) * massOne;
    const float factorDThree = (1 / distDThree) * massOne;
    const float factorDFour = (1 / distDFour) * massOne;
    
    
    // ---
    
    const float4 particleA = {
        inParticle[0].x + inParticle[0].z,
        inParticle[0].y + inParticle[0].w,
        (inParticle[0].z * 0.999) + ((inGravityWell[0].x - inParticle[0].x) * factorA) + ((inGravityWell[1].x - inParticle[0].x) * factorATwo) + ((inGravityWell[2].x - inParticle[0].x) * factorAThree) + ((inGravityWell[3].x - inParticle[0].x) * factorAFour),
        (inParticle[0].w * 0.999) + ((inGravityWell[0].y - inParticle[0].y) * factorA) + ((inGravityWell[1].y - inParticle[0].y) * factorATwo) + ((inGravityWell[2].y - inParticle[0].y) * factorAThree) + ((inGravityWell[3].y - inParticle[0].y) * factorAFour),
    };
    
    
    const float4 particleB = {
        inParticle[1].x + inParticle[1].z,
        inParticle[1].y + inParticle[1].w,
        (inParticle[1].z * 0.999) + ((inGravityWell[0].x - inParticle[1].x) * factorB) + ((inGravityWell[1].x - inParticle[1].x) * factorBTwo) + ((inGravityWell[2].x - inParticle[1].x) * factorBThree) + ((inGravityWell[3].x - inParticle[1].x) * factorBFour),
        (inParticle[1].w * 0.999) + ((inGravityWell[0].y - inParticle[1].y) * factorB) + ((inGravityWell[1].y - inParticle[1].y) * factorBTwo) + ((inGravityWell[2].y - inParticle[1].y) * factorBThree) + ((inGravityWell[3].y - inParticle[1].y) * factorBFour),
    };
    
    
    const float4 particleC = {
        inParticle[2].x + inParticle[2].z,
        inParticle[2].y + inParticle[2].w,
        (inParticle[2].z * 0.999) + ((inGravityWell[0].x - inParticle[2].x) * factorC) + ((inGravityWell[1].x - inParticle[2].x) * factorCTwo) + ((inGravityWell[2].x - inParticle[2].x) * factorCThree) + ((inGravityWell[3].x - inParticle[2].x) * factorCFour),
        (inParticle[2].w * 0.999) + ((inGravityWell[0].y - inParticle[2].y) * factorC) + ((inGravityWell[1].y - inParticle[2].y) * factorCTwo) + ((inGravityWell[2].y - inParticle[2].y) * factorCThree) + ((inGravityWell[3].y - inParticle[2].y) * factorCFour),
    };
    
    
    const float4 particleD = {
        inParticle[3].x + inParticle[3].z,
        inParticle[3].y + inParticle[3].w,
        (inParticle[3].z * 0.999) + ((inGravityWell[0].x - inParticle[3].x) * factorD) + ((inGravityWell[1].x - inParticle[3].x) * factorDTwo) + ((inGravityWell[2].x - inParticle[3].x) * factorDThree) + ((inGravityWell[3].x - inParticle[3].x) * factorDFour),
        (inParticle[3].w * 0.999) + ((inGravityWell[0].y - inParticle[3].y) * factorD) + ((inGravityWell[1].y - inParticle[3].y) * factorDTwo) + ((inGravityWell[2].y - inParticle[3].y) * factorDThree) + ((inGravityWell[3].y - inParticle[3].y) * factorDFour),
    };
    
    outParticles[id] = float4x4 (particleA, particleB, particleC, particleD);
 
    
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