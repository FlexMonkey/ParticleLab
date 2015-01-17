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
};

kernel void particleRendererShader(texture2d<float, access::write> outTexture [[texture(0)]],
                                   const device Particle *particle [[ buffer(0) ]],
                                   uint id [[thread_position_in_grid]])
{
    const uint2 particlePosition(particle[id].positionX, particle[id].positionY);
    
    const float4 outColor(0.0, 0.0, 1.0, 1.0);
    
    outTexture.write(outColor, particlePosition);
}