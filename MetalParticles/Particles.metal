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
    const float imageWidth = 1024;
    const float4x4 inParticle = inParticles[id];

    const int type = id % 3;

    // const float3 thisColor = float3(0,0,0); // inTexture.read(particlePosition).rgb;
    
    const float4 outColor((type == 0 ? 1 : 0.0),
                          (type == 1 ? 1 : 0.0),
                          (type == 2 ? 1 : 0.0),
                          1.0);
    
    const float massTwo = (type == 0 ? 0.45 : (type == 1 ? 0.46 : 0.47));
    const float massOne = (type == 0 ? 0.27 : (type == 1 ? 0.26 : 0.25));
    
    const uint2 particlePosition(inParticle[0].x, inParticle[0].y);
    
    if (particlePosition.x > 0 && particlePosition.y > 0 && particlePosition.x < imageWidth && particlePosition.y < imageWidth)
    {
        outTexture.write(outColor, particlePosition);
    }
   
    const float2 particlePositionFloat(inParticle[0].x, inParticle[0].y);
    
    const float dist = fast::distance(particlePositionFloat, float2(inGravityWell[0].x, inGravityWell[0].y));
    const float distTwo = fast::distance(particlePositionFloat, float2(inGravityWell[1].x, inGravityWell[1].y));
    
    const float factor = (1 / dist) * massOne;
    const float factorTwo = (1 / distTwo) * massTwo;

    // ---
    
    const uint2 particlePositionB(inParticle[1].x, inParticle[1].y);
    
    if (particlePositionB.x > 0 && particlePositionB.y > 0 && particlePositionB.x < imageWidth && particlePositionB.y < imageWidth)
    {
        outTexture.write(outColor, particlePositionB);
    }
    
    const float2 particlePositionBFloat(inParticle[1].x, inParticle[1].y);
    
    const float distB = fast::distance(particlePositionBFloat, float2(inGravityWell[0].x, inGravityWell[0].y));
    const float distBTwo = fast::distance(particlePositionBFloat, float2(inGravityWell[1].x, inGravityWell[1].y));
    
    const float factorB = (1 / distB) * massOne;
    const float factorBTwo = (1 / distBTwo) * massTwo;
    
    // ---

    
    const uint2 particlePositionC(inParticle[2].x, inParticle[2].y);
    
    if (particlePositionC.x > 0 && particlePositionC.y > 0 && particlePositionC.x < imageWidth && particlePositionC.y < imageWidth)
    {
        outTexture.write(outColor, particlePositionC);
    }
    
    const float2 particlePositionCFloat(inParticle[2].x, inParticle[2].y);
    
    const float distC = fast::distance(particlePositionCFloat, float2(inGravityWell[0].x, inGravityWell[0].y));
    const float distCTwo = fast::distance(particlePositionCFloat, float2(inGravityWell[1].x, inGravityWell[1].y));
    
    const float factorC = (1 / distC) * massOne;
    const float factorCTwo = (1 / distCTwo) * massTwo;
    
    // ---
    
    
    const uint2 particlePositionD(inParticle[3].x, inParticle[3].y);
    
    if (particlePositionD.x > 0 && particlePositionD.y > 0 && particlePositionD.x < imageWidth && particlePositionD.y < imageWidth)
    {
        outTexture.write(outColor, particlePositionD);
    }
    
    const float2 particlePositionDFloat(inParticle[3].x, inParticle[3].y);
    
    const float distD = fast::distance(particlePositionDFloat, float2(inGravityWell[0].x, inGravityWell[0].y));
    const float distDTwo = fast::distance(particlePositionDFloat, float2(inGravityWell[1].x, inGravityWell[1].y));
    
    const float factorD = (1 / distD) * massOne;
    const float factorDTwo = (1 / distDTwo) * massTwo;
    
    // ---

    const float4 particleA = {
                              inParticle[0].x + inParticle[0].z,
                              inParticle[0].y + inParticle[0].w,
                              (inParticle[0].z * 0.998) + ((inGravityWell[0].x - inParticle[0].x) * factor) + ((inGravityWell[1].x - inParticle[0].x) * factorTwo),
                              (inParticle[0].w * 0.998) + ((inGravityWell[0].y - inParticle[0].y) * factor) + ((inGravityWell[1].y - inParticle[0].y) * factorTwo)
    };
    
    
    const float4 particleB = {
                              inParticle[1].x + inParticle[1].z,
                              inParticle[1].y + inParticle[1].w,
                              (inParticle[1].z * 0.998) + ((inGravityWell[0].x - inParticle[1].x) * factorB) + ((inGravityWell[1].x - inParticle[1].x) * factorBTwo),
        (inParticle[1].w * 0.998) + ((inGravityWell[0].y - inParticle[1].y) * factorB) + ((inGravityWell[1].y - inParticle[1].y) * factorBTwo)
    };
    
    
    const float4 particleC = {
                              inParticle[2].x + inParticle[2].z,
                              inParticle[2].y + inParticle[2].w,
                              (inParticle[2].z * 0.998) + ((inGravityWell[0].x - inParticle[2].x) * factorC) + ((inGravityWell[1].x - inParticle[2].x) * factorCTwo),
                              (inParticle[2].w * 0.998) + ((inGravityWell[0].y - inParticle[2].y) * factorC) + ((inGravityWell[1].y - inParticle[2].y) * factorCTwo)
    };
    
    
    const float4 particleD = {
                              inParticle[3].x + inParticle[3].z,
                              inParticle[3].y + inParticle[3].w,
                              (inParticle[3].z * 0.998) + ((inGravityWell[0].x - inParticle[3].x) * factorD) + ((inGravityWell[1].x - inParticle[3].x) * factorDTwo),
                              (inParticle[3].w * 0.998) + ((inGravityWell[0].y - inParticle[3].y) * factorD) + ((inGravityWell[1].y - inParticle[3].y) * factorDTwo)
    };
    
    outParticles[id] = float4x4 (particleA, particleB, particleC, particleD);
    
    /*
    outParticles[id] = float4x4 {
        
        .velocityX =  (inParticle.velocityX * 0.998) + ((inGravityWell[0].x - inParticle[0].x) * factor) + ((inGravityWell[1].x - inParticle[0].x) * factorTwo),
        .velocityY =  (inParticle.velocityY * 0.998) + ((inGravityWell[0].y - inParticle[0].y) * factor) + ((inGravityWell[1].y - inParticle[0].y) * factorTwo),
        [0].x =  inParticle[0].x + inParticle.velocityX,
        [0].y =  inParticle[0].y + inParticle.velocityY,
    
        .velocityBX =  (inParticle.velocityBX * 0.998) + ((inGravityWell[0].x - inParticle[1].x) * factorB) + ((inGravityWell[1].x - inParticle[1].x) * factorBTwo),
        .velocityBY =  (inParticle.velocityBY * 0.998) + ((inGravityWell[0].y - inParticle[1].y) * factorB) + ((inGravityWell[1].y - inParticle[1].y) * factorBTwo),
        [1].x =  inParticle[1].x + inParticle.velocityBX,
        [1].y =  inParticle[1].y + inParticle.velocityBY,
        
        .velocityCX =  (inParticle.velocityCX * 0.998) + ((inGravityWell[0].x - inParticle[2].x) * factorC) + ((inGravityWell[1].x - inParticle[2].x) * factorCTwo),
        .velocityCY =  (inParticle.velocityCY * 0.998) + ((inGravityWell[0].y - inParticle[2].y) * factorC) + ((inGravityWell[1].y - inParticle[2].y) * factorCTwo),
        [2].x =  inParticle[2].x + inParticle.velocityCX,
        [2].y =  inParticle[2].y + inParticle.velocityCY,
        
        .velocityDX =  (inParticle.velocityDX * 0.998) + ((inGravityWell[0].x - inParticle[3].x) * factorD) + ((inGravityWell[1].x - inParticle[3].x) * factorDTwo),
        .velocityDY =  (inParticle.velocityDY * 0.998) + ((inGravityWell[0].y - inParticle[3].y) * factorD) + ((inGravityWell[1].y - inParticle[3].y) * factorDTwo),
        [3].x =  inParticle[3].x + inParticle.velocityDX,
        [3].y =  inParticle[3].y + inParticle.velocityDY
        };
     */
    
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