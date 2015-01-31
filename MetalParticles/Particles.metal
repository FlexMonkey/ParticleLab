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

// http://www.reedbeta.com/blog/2013/01/12/quick-and-easy-gpu-random-numbers-in-d3d11/
uint wang_hash(uint seed)
{
    seed = (seed ^ 61) ^ (seed >> 16);
    seed *= 9;
    seed = seed ^ (seed >> 4);
    seed *= 0x27d4eb2d;
    seed = seed ^ (seed >> 15);
    return seed;
}

kernel void particleRendererShader(texture2d<float, access::write> outTexture [[texture(0)]],
                                   
                                   const device Particle *inParticles [[ buffer(0) ]],
                                   device Particle *outParticles [[ buffer(1) ]],
                         
                                   uint id [[thread_position_in_grid]])
{
    const SwarmGenome genomeOne = {
        .radius = 25.0f,
        .c1_cohesion = 0.25f,
        .c2_alignment = 0.25f,
        .c3_seperation = 75.0f,
        .c4_steering = 0.35f,
        .c5_paceKeeping = 0.75f
    };
    
    const SwarmGenome genomeTwo = {
        .radius = 50.0f,
        .c1_cohesion = 0.165f,
        .c2_alignment = 1.0f,
        .c3_seperation = 35.0f,
        .c4_steering = 0.25f,
        .c5_paceKeeping = 0.5f
    };
    
    const SwarmGenome genomeThree = {
        .radius = 65.0f,
        .c1_cohesion = 0.75f,
        .c2_alignment = 0.8f,
        .c3_seperation = 25,
        .c4_steering = 0.15f,
        .c5_paceKeeping = 0.25f
    };
    
    Particle inParticle = inParticles[id];
    const uint2 particlePosition(inParticle.positionX, inParticle.positionY);
    
    const int type = id % 3;
    
    const float4 outColor((type == 0 || type == 2 ? 1 : 0.0),
                          (type == 1 ? 1 : 0.0),
                          (type == 2 ? 1 : 0.0),
                          1.0);
    
    float velocityX = inParticle.velocityX;
    float velocityY = inParticle.velocityY;
    
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
            
            if (dist < genome.radius && dist > 0.001)
            {
                // const float factor = (1 / (dist < 1 ? 1 : dist)) * (type == 0 ? 0.0001 : (type == 1 ? 0.000125 : 0.00015));
                
                // velocityX =  velocityX + (otherParticle.positionX - inParticle.positionX) * factor;
                // velocityY =  velocityY + (otherParticle.positionY - inParticle.positionY) * factor;
                
                localCentreX = localCentreX + candidateNeighbour.positionX;
                localCentreY = localCentreY + candidateNeighbour.positionY;
                localDx = localDx + candidateNeighbour.velocityX;
                localDy = localDy + candidateNeighbour.velocityY;
                
                neigbourCount = neigbourCount + 1.0f;
                
                float foo = (dist < 1 ? 1 : dist) * genome.c3_seperation;
                
                tempAx = tempAx + (inParticle.positionX - candidateNeighbour.positionX) / foo;
                tempAy = tempAy + (inParticle.positionY - candidateNeighbour.positionY) / foo;
                
                const int randomOne = int(candidateNeighbour.positionX) % 3;
                const int randomTwo = int(candidateNeighbour.positionY) % 3;
                const int randomThree = int(candidateNeighbour.velocityY) % 3;
                
                if ((randomThree < 1.0) < (genome.c4_steering * 1.0f))
                {
                    tempAx = tempAx + (randomOne) - 1;
                    tempAy = tempAy + (randomTwo) - 1;
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
        
        const float d = sqrt(inParticle.velocityX2 * inParticle.velocityX2 + inParticle.velocityY2 * inParticle.velocityY2);
        
        float accelerateMultiplier = (1.0f - d) / d * genome.c5_paceKeeping;
        
        inParticle.velocityX2 += inParticle.velocityX2 * accelerateMultiplier;
        inParticle.velocityY2 += inParticle.velocityY2 * accelerateMultiplier;
    }

    inParticle.velocityX = inParticle.velocityX2;
    inParticle.velocityY = inParticle.velocityY2;
    
    inParticle.positionX += inParticle.velocityX;
    inParticle.positionY += inParticle.velocityY;
 
    outParticles[id] = inParticle;

    if (outParticles[id].positionX < 0)
    {
        outParticles[id].positionX = 640;
    }
    else if (outParticles[id].positionX > 640)
    {
        outParticles[id].positionX = 0;
    }
    
    if (outParticles[id].positionY < 0)
    {
        outParticles[id].positionY = 640;
    }
    else if (outParticles[id].positionX > 640)
    {
        outParticles[id].positionY = 0;
    }
 
    
    if (particlePosition.x > 0 && particlePosition.y > 0 && particlePosition.x < 1024 && particlePosition.y < 1024)
    {
        outTexture.write(outColor, particlePosition);
    }
   
 

}