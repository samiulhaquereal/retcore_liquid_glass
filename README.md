# Retcore Liquid Glass

A high-performance, physically accurate glass refraction package for Flutter. Built entirely with raw GLSL shaders, `retcore_liquid_glass` achieves the holy grail of modern UI design: real-time, interactive, incredibly realistic frosted and liquid glass effects that bend the light of widgets underneath them.

![Liquid Glass Example](https://images.unsplash.com/photo-1485470733090-0aae1788d5af?fm=jpg&q=60&w=3000&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8MXx8d2FsbHBhcGVyJTIwNGt8ZW58MHx8MHx8fDA%3D)

## Features

*   **Physically Accurate Optics:** Uses true Snell's Law calculations to bend light through the glass accurately. 
*   **Zero-Overhead Memory:** Uses pure integer handles to clone high-resolution textures directly to the GPU without leaking memory.
*   **Resolution Independent:** Perfectly scales its optics on 1.0x monitors up to 4.0x Retina displays without pixelation.
*   **Alignment API:** Position the glass using the standard Flutter `Alignment` system (e.g. `LiquidGlassPosition.center`).
*   **Web Safe:** Includes a unique CanvasKit crash-breaker to prevent memory loops if a Web Browser's strict CORS policy blocks an image.

## Getting Started

1. Add the package to your `pubspec.yaml`:
   ```yaml
   dependencies:
     retcore_liquid_glass: ^0.0.1
   ```
2. Wrap your entire background in a `LiquidGlassView`.
3. Add `LiquidLens` widgets wherever you want the glass cards to appear.

## Usage

```dart
import 'package:flutter/material.dart';
import 'package:retcore_liquid_glass/retcore_liquid_glass.dart';

class MyGlassApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LiquidGlassView(
        // Set realTime to true if your background has moving elements (like a video)
        realTime: false, 
        background: Image.network(
          'https://images.unsplash.com/photo-1485470733090-0aae1788d5af',
          fit: BoxFit.cover,
        ),
        lenses: [
          LiquidLens(
            // Position using alignments!
            position: LiquidGlassPosition.center,
            width: 300,
            height: 200,
            
            // True optical magnification (zoom) inside the glass
            magnification: 1.4,
            
            // Refraction distortion amount
            distortion: 0.15,
            
            // Optional child widget inside the glass
            child: Center(
              child: Text(
                "PREMIUM UI", 
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

## Advanced Properties

| Property | Description | Default |
|---|---|---|
| `refractionMode` | Toggle between `.shape` (rounded box) or `.radial` (circular) light bending. | `.shape` |
| `draggable` | Set to `true` to let the user drag the glass card around the screen. | `false` |
| `chromaticAberration` | Introduces an RGB split to simulate premium, thick lens edges. | `0.005` |
| `color` | Apply a subtle RGBA tint overlay to the glass. | `Colors.transparent` |
