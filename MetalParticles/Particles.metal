//
//  Particles.metal
//  MetalParticles
//
//  Created by Simon Gladman on 17/01/2015.
//  Copyright (c) 2015 Simon Gladman. All rights reserved.
//
//  Thanks to: http://memkite.com/blog/2014/12/15/data-parallel-programming-with-metal-and-swift-for-iphoneipad-gpu/
//
//  Playing with Hiroki Sayama's Swarm Chemisty
//  See: http://bingweb.binghamton.edu/~sayama/SwarmChemistry/

#include <metal_stdlib>
using namespace metal;

struct Particle
{
    float positionX;
    float positionY;
    float velocityX;
    float velocityY;
    float velocityX2;
    float velocityY2;
    float type;
};

struct SwarmGenome
{
    float radius;
    float c1_cohesion;
    float c2_alignment;
    float c3_seperation;
    float c4_steering;
    float c5_paceKeeping;
};

struct NeighbourDistance
{
    float dist;
    float x;
    float y;
};

kernel void glowShader(texture2d<float, access::read> inTexture [[texture(0)]],
                       texture2d<float, access::write> outTexture [[texture(1)]],
                       texture2d<float, access::read> inTextureB [[texture(2)]],
                       uint2 gid [[thread_position_in_grid]])
{
    float4 accumColor(0,0,0,0);
    
    for (int j = -1; j <= 1; j++)
    {
        for (int i = -1; i <= 1; i++)
        {
            uint2 kernelIndex(gid.x + i, gid.y + j);
            accumColor += inTexture.read(kernelIndex).rgba;
        }
    }
    
    accumColor.rgb = (accumColor.rgb / 10.0f) + inTextureB.read(gid).rgb;
    accumColor.a = 1.0f;
    
    outTexture.write(accumColor, gid);
}

kernel void particleRendererShader(texture2d<float, access::write> outTexture [[texture(0)]],
                                    texture2d<float, access::read> inTexture [[texture(1)]],
                                   const device Particle *inParticles [[ buffer(0) ]],
                                   device Particle *outParticles [[ buffer(1) ]],
                         
                                   uint id [[thread_position_in_grid]])
{
    const SwarmGenome genomeOne = {
        .radius = 0.25f,
        .c1_cohesion = 0.25f,
        .c2_alignment = 0.25f,
        .c3_seperation = 0.05f,
        .c4_steering = 0.35f,
        .c5_paceKeeping = 0.75f
    };
    
    const SwarmGenome genomeTwo = {
        .radius = 0.50f,
        .c1_cohesion = 0.165f,
        .c2_alignment = 0.5f,
        .c3_seperation = 0.20f,
        .c4_steering = 0.25f,
        .c5_paceKeeping = 0.5f
    };
    
    const SwarmGenome genomeThree = {
        .radius = 0.65f,
        .c1_cohesion = 0.55f,
        .c2_alignment = 0.8f,
        .c3_seperation = 0.175f,
        .c4_steering = 0.85f,
        .c5_paceKeeping = 0.25f
    };
    
    Particle inParticle = inParticles[id];
    const uint2 particlePosition(inParticle.positionX, inParticle.positionY);
    
    const int type = int(inParticle.type);
    
    const float4 outColor((type == 0 ? 1 : 0.5),
                          (type == 1 ? 1 : 0.5),
                          (type == 2 ? 1 : 0.5),
                          1.0);

    float neigbourCount = 0;
    float localCentreX = 0;
    float localCentreY = 0;
    float localDx = 0;
    float localDy = 0;
    float tempAx = 0;
    float tempAy = 0;

    const SwarmGenome genome = type == 0 ? genomeOne : type == 1 ? genomeTwo : genomeThree;
    
    for (uint i = 0; i < 4096; i++)
    {
        if (i != id)
        {
            const Particle candidateNeighbour = inParticles[i];
 
            const float dist = fast::distance(float2(inParticle.positionX, inParticle.positionY), float2(candidateNeighbour.positionX, candidateNeighbour.positionY));
            
            if (dist < genome.radius * 100)
            {
                localCentreX = localCentreX + candidateNeighbour.positionX;
                localCentreY = localCentreY + candidateNeighbour.positionY;
                localDx = localDx + candidateNeighbour.velocityX;
                localDy = localDy + candidateNeighbour.velocityY;
                
                neigbourCount = neigbourCount + 1.0f;
                
                float foo = (dist < 1 ? 1 : dist) * genome.c3_seperation * 100.0f;
                
                tempAx = tempAx + (inParticle.positionX - candidateNeighbour.positionX) / foo;
                tempAy = tempAy + (inParticle.positionY - candidateNeighbour.positionY) / foo;
                
                const float randomThree = fast::abs(fast::cos(candidateNeighbour.velocityX + candidateNeighbour.velocityY));
                
                if (randomThree < genome.c4_steering)
                {
                    const int randomOne = fast::cos(candidateNeighbour.positionX + candidateNeighbour.velocityY);
                    const int randomTwo = fast::sin(candidateNeighbour.positionY + candidateNeighbour.velocityX);
                    
                    tempAx = tempAx + randomOne * 5;
                    tempAy = tempAy + randomTwo * 5 ;
                }
            }
        }
    }
    
    if (neigbourCount > 0)
    {
        localCentreX = localCentreX / neigbourCount;
        localCentreY = localCentreY / neigbourCount;
        localDx = localDx / neigbourCount;
        localDy = localDy / neigbourCount;
        
        tempAx = tempAx + (localCentreX - inParticle.positionX) * genome.c1_cohesion;
        tempAy = tempAy + (localCentreY - inParticle.positionY) * genome.c1_cohesion;
        
        tempAx = tempAx + (localDx - inParticle.velocityX) * genome.c2_alignment;
        tempAy = tempAy + (localDy - inParticle.velocityY) * genome.c2_alignment;
        
        inParticle.velocityX2 += tempAx;
        inParticle.velocityY2 += tempAy;
        
        const float d = fast::sqrt(inParticle.velocityX2 * inParticle.velocityX2 + inParticle.velocityY2 * inParticle.velocityY2);
        
        float accelerateMultiplier = (1.0f - d) / d * genome.c5_paceKeeping;
        
        inParticle.velocityX2 += inParticle.velocityX2 * accelerateMultiplier;
        inParticle.velocityY2 += inParticle.velocityY2 * accelerateMultiplier;
    }

    inParticle.velocityX = inParticle.velocityX2;
    inParticle.velocityY = inParticle.velocityY2;
    
    inParticle.positionX += inParticle.velocityX;
    inParticle.positionY += inParticle.velocityY;
 
    outParticles[id] = inParticle;

    if (outParticles[id].positionX <= 0)
    {
        outParticles[id].positionX = 800;
    }
    else if (outParticles[id].positionX >= 800)
    {
        outParticles[id].positionX = 0;
    }
    
    if (outParticles[id].positionY <= 0)
    {
        outParticles[id].positionY = 800;
    }
    else if (outParticles[id].positionX >= 800)
    {
        outParticles[id].positionY = 0;
    }
 
    const float4 inColor = inTexture.read(particlePosition).rgba;
    outTexture.write(inColor + outColor, particlePosition);
    
    const float4 inColor2 = inTexture.read(particlePosition - uint2(1, 1)).rgba;
    outTexture.write(inColor2 + outColor, particlePosition - uint2(1, 1));
    
    const float4 inColor3 = inTexture.read(particlePosition - uint2(0, 1)).rgba;
    outTexture.write(inColor3 + outColor, particlePosition - uint2(0, 1));
    
    const float4 inColor4 = inTexture.read(particlePosition - uint2(1, 0)).rgba;
    outTexture.write(inColor4 + outColor, particlePosition - uint2(1, 0));
 

}