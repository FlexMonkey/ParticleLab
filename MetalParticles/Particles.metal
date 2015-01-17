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
    
    const float4 outColor(0.0, 0.0, 1.0, 1.0);
    
    outParticle[id].positionX = inParticle[id].positionX + inParticle[id].velocityX;
    outParticle[id].positionY = inParticle[id].positionY + inParticle[id].velocityY;
    outParticle[id].velocityX = inParticle[id].velocityX;
    outParticle[id].velocityY = inParticle[id].velocityY;
    
    outTexture.write(outColor, particlePosition);
}