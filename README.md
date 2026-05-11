# Liquid Glass for Flutter 🌊✨

A premium, iOS-inspired Liquid Glass effect for Flutter. This package uses high-performance fragment shaders to create a stunning, flowing liquid glass look with real-time refraction, specular highlights, and backdrop blurring.

## Features 🚀

- **Fluid Animation**: Multi-layered noise shaders create a realistic liquid flow.
- **Dynamic Refraction**: Real-time background distortion that follows the liquid motion.
- **Specular Highlights**: Glassy reflections that give a 3D feel.
- **Customizable**: Easy control over intensity, blur, colors, and border radius.
- **High Performance**: GPU-accelerated rendering using Flutter's FragmentShader API.

## Installation 📦

Add `glass` to your `pubspec.yaml`:

```yaml
dependencies:
  glass:
    path: ./ # Or your package location
```

Ensure your `pubspec.yaml` includes the shader:

```yaml
flutter:
  shaders:
    - shaders/liquid_noise.frag
```

## Usage 🛠️

```dart
import 'package:glass/glass.dart';

LiquidGlass(
  width: 300,
  height: 200,
  blur: 20,
  intensity: 0.5,
  borderRadius: BorderRadius.circular(24),
  child: Center(
    child: Text('Hello Liquid Glass!'),
  ),
)
```

## Parameters ⚙️

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `blur` | `double` | `20.0` | Backdrop blur intensity. |
| `intensity` | `double` | `0.5` | Strength of the liquid effect and distortion. |
| `color1` | `Color` | `Color(0x80FFFFFF)` | First color of the liquid gradient. |
| `color2` | `Color` | `Color(0x33FFFFFF)` | Second color of the liquid gradient. |
| `borderRadius` | `BorderRadius` | `null` | Corner radius of the glass panel. |

## Credits 🙌

Inspired by the premium glass effects found in iOS and modern UI designs.

---
Built with ❤️ by Antigravity AI
