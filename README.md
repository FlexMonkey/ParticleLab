# MetalParticles
Particle system that's both calculated and rendered on the GPU using the Metal framework

This is the most highly optimised version of my Swift and Metal particles system; managing over 40 fps with four million particles and four gravity wells. It manages this by rendering to a CAMetalLayer rather than converting a texture to a UIImage and by passing in four particle definitions per step with a float4x4 rather than a particle struct.

You can read about these recent changes at my blog:

* CAMetalLayer work: http://flexmonkey.blogspot.co.uk/2015/03/swift-metal-four-million-particles-on.html
* Use of float4x4: http://flexmonkey.blogspot.co.uk/2015/03/mind-blowing-metal-four-million.html
