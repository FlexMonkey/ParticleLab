# ParticleLab - High Performance Particles in Swift and Metal
Particle system that's both calculated and rendered on the GPU using the Metal framework

![http://flexmonkey.co.uk/swift/IMG_0699.PNG](http://flexmonkey.co.uk/swift/IMG_0699.PNG)

This is the most highly optimised version of my Swift and Metal particles system; managing over 40 fps with four million particles and four gravity wells. It manages this by rendering to a MetalKit MTKView rather than converting a texture to a UIImage and by passing in four particle definitions per step with a float4x4 rather than a particle struct.

You can read about these recent changes at my blog:

* A First Look at Metal for OS X: http://flexmonkey.blogspot.co.uk/2015/06/a-first-look-at-metal-for-os-x-el.html
* CAMetalLayer work: http://flexmonkey.blogspot.co.uk/2015/03/swift-metal-four-million-particles-on.html
* Use of float4x4: http://flexmonkey.blogspot.co.uk/2015/03/mind-blowing-metal-four-million.html

This branch wraps up all the Metal code into one class so that it's easily implemented in other projects. To create a new particle system object, instantiate an instance of _ParticleLab_ specifying the dimensions and total number of particles (half, one, two or four million):

```
particleLab = ParticleLab(width: 1024, height: 768, numParticles: ParticleCount.TwoMillion)
```

...and when ready, add it  as a sublayer to your view:

```
view.addView(particleLab)
```

The class has four gravity wells with propeties such as position, mass and spin. These are set with the _setGravityWellProperties_ method:

```
particleLab.setGravityWellProperties(gravityWell: .One, normalisedPositionX: 0.3, normalisedPositionY: 0.3, mass: 11, spin: -4)
        
particleLab.setGravityWellProperties(gravityWell: .Two, normalisedPositionX: 0.7, normalisedPositionY: 0.3, mass: 7, spin: 3)
        
particleLab.setGravityWellProperties(gravityWell: .Three, normalisedPositionX: 0.3, normalisedPositionY: 0.7, mass: 7, spin: 3)
        
particleLab.setGravityWellProperties(gravityWell: .Four, normalisedPositionX: 0.7, normalisedPositionY: 0.7, mass: 11, spin: -4)
```

Classes can implement ```ParticleLabDelegate``` interface which includes ```particleLabDidUpdate```. This method is invoked with each particle step and can be used, for example, for updating the position of gravity wells.

# ParticleLab Features in Detail

## Setting Gravity Well Properties

ParticleLab supports up to four gravity wells that have properties for position, mass and spin. These properties are set through the ```setGravityWellProperties()``` method that either accepts a ```GravityWell``` enum or an index (0 through 3):

```
particleLab.setGravityWellProperties(gravityWell: .One, normalisedPositionX: 0.3, normalisedPositionY: 0.3, mass: 11, spin: -4)

particleLab.setGravityWellProperties(gravityWellIndex: 0, normalisedPositionX: 0.3, normalisedPositionY: 0.3, mass: 11, spin: -4)
```

Gravity wells can be cleared so that their mass and spin are set to zero and they have no effect on the particle field:

```
resetGravityWells()
```

ParticleLab can also return the normalised position of any gravity well:

```
getGravityWellNormalisedPosition(#gravityWell: GravityWell) -> (x: Float, y: Float)
```

The positions of each gravity well can be displayed by setting the value of ```showGravityWellPositions``` to true

## Setting Particle Properties and Behaviours

Particles are distributed across three classes which have slightly different masses. The ```particleColor``` property sets the base color and the other two particles colors use variations of it. For example, if ```particleColor``` is set to 0xFFAA00, the other two classes are colored 0x00FFAA and 0xAA00FF.

The ```dragFactor``` property defines how paricles decelerate. A value of one implies no deceleratation while a value of zero stops particles immediately. Typical values are between 0.8 and 1.0.

```respawnOutOfBoundsParticles``` respawns particles to the centre of the screen once they escape the bounds of the simulation. Respawned particles radiate outwards from the centre.

The particle field can be reset by ```resetParticles()```. This accepts a Boolean argument indicating whether the particles should appear at the edges of the simulation (default, true) or throughout the entire simualtion (false).

## ParticleLabDelegate

The ```ParticleLabDelegate``` protocol contains two methods.

* ```particleLabDidUpdate()``` is fired with each update
* ```particleLabMetalUnavailable``` is invoked if the target device doesn't support Metal
