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
                                   uint id [[thread_position_in_grid]])
{
    const uint2 particlePosition(inParticle[id].positionX, inParticle[id].positionY);
    
    const Particle thisParticle = inParticle[id];
    
    const float4 outColor(0.0, 0.0, 1.0, 1.0);
    
    const float distanceSquared = ((thisParticle.positionX - 320) * (thisParticle.positionX - 320)) +  ((thisParticle.positionY - 320) * (thisParticle.positionY - 320));
    const float distance = distanceSquared < 1 ? 1 : sqrt(distanceSquared);
    const float factor = (1 / distance) * 0.01;
    
    float newVelocityX = (thisParticle.velocityX * 0.9999) + (320 - thisParticle.positionX) * factor;
    float newVelocityY = (thisParticle.velocityY * 0.9999) + (320 - thisParticle.positionY) * factor;
    
    outParticle[id].positionX = thisParticle.positionX + thisParticle.velocityX;
    outParticle[id].positionY = thisParticle.positionY + thisParticle.velocityY;
  
    outParticle[id].velocityX = newVelocityX;
    outParticle[id].velocityY = newVelocityY;
    
    outTexture.write(outColor, particlePosition);
}