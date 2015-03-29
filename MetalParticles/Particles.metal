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
                                   // texture2d<float, access::read> inTexture [[texture(1)]],
                                   
                                   const device Particle *inParticles [[ buffer(0) ]],
                                   device Particle *outParticles [[ buffer(1) ]],
                                   
                                   constant Particle &inGravityWell [[ buffer(2) ]],
                                   constant Particle &inGravityWellTwo [[ buffer(3) ]],
                                   
                                   uint id [[thread_position_in_grid]])
{
    const float imageWidth = 1024;
    const Particle inParticle = inParticles[id];
    const uint2 particlePosition(inParticle.positionX, inParticle.positionY);
    
    const int type = id % 3;

    const float3 thisColor = float3(0,0,0); // inTexture.read(particlePosition).rgb;
    
    const float4 outColor(thisColor.r + (type != 0 ? 1 : 0.0),
                          thisColor.g +  (type != 1 ? 1 : 0.0),
                          thisColor.b + (type != 2 ? 1 : 0.0),
                          1.0);
    
    if (particlePosition.x > 0 && particlePosition.y > 0 && particlePosition.x < imageWidth && particlePosition.y < imageWidth)
    {
        outTexture.write(outColor, particlePosition);
    }
   
    const float dist = fast::distance(float2(inParticle.positionX, inParticle.positionY), float2(inGravityWell.positionX, inGravityWell.positionY));
    const float distTwo = fast::distance(float2(inParticle.positionX, inParticle.positionY), float2(inGravityWellTwo.positionX, inGravityWellTwo.positionY));
    
    const float factor = (1 / dist) * (type == 0 ? 0.4 : (type == 1 ? 0.39 : 0.38));
    const float factorTwo = (1 / distTwo) * (type == 0 ? 0.2 : (type == 1 ? 0.19 : 0.18));
   
    outParticles[id] = Particle {
        .velocityX =  (inParticle.velocityX * 0.998) + ((inGravityWell.positionX - inParticle.positionX) * factor) - ((inGravityWellTwo.positionX - inParticle.positionX) * factorTwo),
        .velocityY =  (inParticle.velocityY * 0.998) + ((inGravityWell.positionY - inParticle.positionY) * factor) - ((inGravityWellTwo.positionY - inParticle.positionY) * factorTwo),
        .positionX =  inParticle.positionX + inParticle.velocityX,
        .positionY =  inParticle.positionY + inParticle.velocityY};
    
    
    
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