# ParticleLab - High Performance Particles in Swift and Metal
Particle system that's both calculated and rendered on the GPU using the Metal framework

![http://flexmonkey.co.uk/swift/IMG_0699.PNG](http://flexmonkey.co.uk/swift/IMG_0699.PNG)

This is the most highly optimised version of my Swift and Metal particles system; managing over 40 fps with four million particles and four gravity wells. It manages this by rendering to a CAMetalLayer rather than converting a texture to a UIImage and by passing in four particle definitions per step with a float4x4 rather than a particle struct.

You can read about these recent changes at my blog:

* CAMetalLayer work: http://flexmonkey.blogspot.co.uk/2015/03/swift-metal-four-million-particles-on.html
* Use of float4x4: http://flexmonkey.blogspot.co.uk/2015/03/mind-blowing-metal-four-million.html

This branch wraps up all the Metal code into one class so that it's easily implemented in other projects. To create a new particle system object, instantiate an instance of _ParticleLab_

```
let particleLab = ParticleLab()
```

...and when ready, add it  as a sublayer to your view:

```
view.layer.addSublayer(particleLab)
```

The class has four gravity wells with propeties such as position, mass and spin. These are set with the _setGravityWellProperties_ method:

```
particleLab.setGravityWellProperties(gravityWell: .One, normalisedPositionX: 0.3, normalisedPositionY: 0.3, mass: 11, spin: -4)
        
particleLab.setGravityWellProperties(gravityWell: .Two, normalisedPositionX: 0.7, normalisedPositionY: 0.3, mass: 7, spin: 3)
        
particleLab.setGravityWellProperties(gravityWell: .Three, normalisedPositionX: 0.3, normalisedPositionY: 0.7, mass: 7, spin: 3)
        
particleLab.setGravityWellProperties(gravityWell: .Four, normalisedPositionX: 0.7, normalisedPositionY: 0.7, mass: 11, spin: -4)
```

Gravity well positions can be displayed by setting the ```showGravityWellPositions``` property to _true_.
