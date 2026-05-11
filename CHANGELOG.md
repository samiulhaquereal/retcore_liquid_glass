## 0.0.1

* **Initial Release**: High-performance, physically accurate Liquid Glass effect.
* Implemented `LiquidGlassView` for real-time background capture and throttling.
* Implemented GLSL fragment shader (`liquid_lens.frag`) with Snell's Law refraction, chromatic aberration, and Schlick Fresnel approximations.
* Supported `LiquidRefractionMode.shape` and `LiquidRefractionMode.radial`.
* Rebuilt with Web CanvasKit CORS security breakers and memory loop optimizations.
* Added standard `Alignment` API for highly flexible glass positioning.
