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

struct Particle
{
    float positionX;
    float positionY;
    float velocityX;
    float velocityY;
    
    float positionBX;
    float positionBY;
    float velocityBX;
    float velocityBY;
    
    float positionCX;
    float positionCY;
    float velocityCX;
    float velocityCY;
    
    float positionDX;
    float positionDY;
    float velocityDX;
    float velocityDY;
};

kernel void particleRendererShader(texture2d<float, access::write> outTexture [[texture(0)]],
                                   // texture2d<float, access::read> inTexture [[texture(1)]],
                                   
                                   const device Particle *inParticles [[ buffer(0) ]],
                                   device Particle *outParticles [[ buffer(1) ]],
                                   
                                   constant Particle &inGravityWell [[ buffer(2) ]],
                                   
                                   uint id [[thread_position_in_grid]])
{
    const float imageWidth = 1024;
    const Particle inParticle = inParticles[id];

    const int type = id % 3;

    // const float3 thisColor = float3(0,0,0); // inTexture.read(particlePosition).rgb;
    
    const float4 outColor((type == 0 ? 1 : 0.0),
                          (type == 1 ? 1 : 0.0),
                          (type == 2 ? 1 : 0.0),
                          1.0);
    
    const float massOne = (type == 0 ? 0.5 : (type == 1 ? 0.505 : 0.51));
    const float massTwo = (type == 0 ? 0.2 : (type == 1 ? 0.195 : 0.19));
    
    const uint2 particlePosition(inParticle.positionX, inParticle.positionY);
    
    if (particlePosition.x > 0 && particlePosition.y > 0 && particlePosition.x < imageWidth && particlePosition.y < imageWidth)
    {
        outTexture.write(outColor, particlePosition);
    }
   
    const float2 particlePositionFloat(inParticle.positionX, inParticle.positionY);
    
    const float dist = fast::distance(particlePositionFloat, float2(inGravityWell.positionX, inGravityWell.positionY));
    const float distTwo = fast::distance(particlePositionFloat, float2(inGravityWell.positionBX, inGravityWell.positionBY));
    
    const float factor = (1 / dist) * massOne;
    const float factorTwo = (1 / distTwo) * massTwo;

    // ---
    
    const uint2 particlePositionB(inParticle.positionBX, inParticle.positionBY);
    
    if (particlePositionB.x > 0 && particlePositionB.y > 0 && particlePositionB.x < imageWidth && particlePositionB.y < imageWidth)
    {
        outTexture.write(outColor, particlePositionB);
    }
    
    const float2 particlePositionBFloat(inParticle.positionBX, inParticle.positionBY);
    
    const float distB = fast::distance(particlePositionBFloat, float2(inGravityWell.positionX, inGravityWell.positionY));
    const float distBTwo = fast::distance(particlePositionBFloat, float2(inGravityWell.positionBX, inGravityWell.positionBY));
    
    const float factorB = (1 / distB) * massOne;
    const float factorBTwo = (1 / distBTwo) * massTwo;
    
    // ---

    
    const uint2 particlePositionC(inParticle.positionCX, inParticle.positionCY);
    
    if (particlePositionC.x > 0 && particlePositionC.y > 0 && particlePositionC.x < imageWidth && particlePositionC.y < imageWidth)
    {
        outTexture.write(outColor, particlePositionC);
    }
    
    const float2 particlePositionCFloat(inParticle.positionCX, inParticle.positionCY);
    
    const float distC = fast::distance(particlePositionCFloat, float2(inGravityWell.positionX, inGravityWell.positionY));
    const float distCTwo = fast::distance(particlePositionCFloat, float2(inGravityWell.positionBX, inGravityWell.positionBY));
    
    const float factorC = (1 / distC) * massOne;
    const float factorCTwo = (1 / distCTwo) * massTwo;
    
    // ---
    
    
    const uint2 particlePositionD(inParticle.positionDX, inParticle.positionDY);
    
    if (particlePositionD.x > 0 && particlePositionD.y > 0 && particlePositionD.x < imageWidth && particlePositionD.y < imageWidth)
    {
        outTexture.write(outColor, particlePositionD);
    }
    
    const float2 particlePositionDFloat(inParticle.positionDX, inParticle.positionDY);
    
    const float distD = fast::distance(particlePositionDFloat, float2(inGravityWell.positionX, inGravityWell.positionY));
    const float distDTwo = fast::distance(particlePositionDFloat, float2(inGravityWell.positionBX, inGravityWell.positionBY));
    
    const float factorD = (1 / distD) * massOne;
    const float factorDTwo = (1 / distDTwo) * massTwo;
    
    // ---

    
    outParticles[id] = Particle {
        
        .velocityX =  (inParticle.velocityX * 0.999) + ((inGravityWell.positionX - inParticle.positionX) * factor) + ((inGravityWell.positionBX - inParticle.positionX) * factorTwo),
        .velocityY =  (inParticle.velocityY * 0.999) + ((inGravityWell.positionY - inParticle.positionY) * factor) + ((inGravityWell.positionBY - inParticle.positionY) * factorTwo),
        .positionX =  inParticle.positionX + inParticle.velocityX,
        .positionY =  inParticle.positionY + inParticle.velocityY,
    
        .velocityBX =  (inParticle.velocityBX * 0.999) + ((inGravityWell.positionX - inParticle.positionBX) * factorB) + ((inGravityWell.positionBX - inParticle.positionBX) * factorBTwo),
        .velocityBY =  (inParticle.velocityBY * 0.999) + ((inGravityWell.positionY - inParticle.positionBY) * factorB) + ((inGravityWell.positionBY - inParticle.positionBY) * factorBTwo),
        .positionBX =  inParticle.positionBX + inParticle.velocityBX,
        .positionBY =  inParticle.positionBY + inParticle.velocityBY,
        
        .velocityCX =  (inParticle.velocityCX * 0.999) + ((inGravityWell.positionX - inParticle.positionCX) * factorC) + ((inGravityWell.positionBX - inParticle.positionCX) * factorCTwo),
        .velocityCY =  (inParticle.velocityCY * 0.999) + ((inGravityWell.positionY - inParticle.positionCY) * factorC) + ((inGravityWell.positionBY - inParticle.positionCY) * factorCTwo),
        .positionCX =  inParticle.positionCX + inParticle.velocityCX,
        .positionCY =  inParticle.positionCY + inParticle.velocityCY,
        
        .velocityDX =  (inParticle.velocityDX * 0.999) + ((inGravityWell.positionX - inParticle.positionDX) * factorD) + ((inGravityWell.positionBX - inParticle.positionDX) * factorDTwo),
        .velocityDY =  (inParticle.velocityDY * 0.999) + ((inGravityWell.positionY - inParticle.positionDY) * factorD) + ((inGravityWell.positionBY - inParticle.positionDY) * factorDTwo),
        .positionDX =  inParticle.positionDX + inParticle.velocityDX,
        .positionDY =  inParticle.positionDY + inParticle.velocityDY
        };
    
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