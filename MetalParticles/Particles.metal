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
};

kernel void particleRendererShader(texture2d<float, access::write> outTexture [[texture(0)]],
                                   const device Particle *inParticle [[ buffer(0) ]],
                                   device Particle *outParticle [[ buffer(1) ]],
                                   constant Particle &inGravityWell [[ buffer(2) ]],
                                   texture2d<float, access::read> inTexture [[texture(1)]],
                                   uint id [[thread_position_in_grid]])
{
    const uint2 particlePosition(inParticle[id].positionX, inParticle[id].positionY);
    
    const Particle thisParticle = inParticle[id];
    
    const int type = id % 3;
    
    const float3 thisColor = inTexture.read(particlePosition).rgb;
    const float4 outColor(thisColor.r + (type == 0 ? 0.25 : 0.0),
                          thisColor.g + (type == 1 ? 0.25 : 0.0),
                          thisColor.b + (type == 2 ? 0.25 : 0.0),
                          1.0);
    
    const float deltaX = thisParticle.positionX - inGravityWell.positionX;
    const float deltaY = thisParticle.positionY - inGravityWell.positionY;
    
    const float distSquared = (deltaX * deltaX + deltaY * deltaY);
    const float dist = distSquared < 1 ? 1 : fast::sqrt(distSquared + 1);
 
    const float factor = (1 / dist) * (type == 0 ? 0.1 : (type == 1 ? 0.125 : 0.15));
    
    float newVelocityX = (thisParticle.velocityX * 0.999) + (inGravityWell.positionX - thisParticle.positionX) * factor;
    float newVelocityY = (thisParticle.velocityY * 0.999) + (inGravityWell.positionY - thisParticle.positionY) * factor;
    
    outParticle[id].positionX = thisParticle.positionX + thisParticle.velocityX;
    outParticle[id].positionY = thisParticle.positionY + thisParticle.velocityY;
    
    outParticle[id].velocityX = newVelocityX;
    outParticle[id].velocityY = newVelocityY;
    
    uint2 textureCoordinate(fast::floor(id / 1024.0f),id % 1024);
    
    float4 accumColor = inTexture.read(textureCoordinate);
    
    for (int j = -1; j <= 1; j++)
    {
        for (int i = -1; i <= 1; i++)
        {
            uint2 kernelIndex(textureCoordinate.x + i, textureCoordinate.y + j);
            accumColor.rgb += inTexture.read(kernelIndex).rgb;
        }
    }
    
    accumColor.rgb = (accumColor.rgb / 10.75f);
    accumColor.a = 1.0f;
    
    outTexture.write(accumColor, textureCoordinate);

    outTexture.write(outColor, particlePosition);
}