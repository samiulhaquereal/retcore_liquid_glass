import 'package:flutter/material.dart';
import 'package:retcore_liquid_glass/retcore_liquid_glass.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Liquid Glass',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: const LiquidLensDemo(),
    );
  }
}

class LiquidLensDemo extends StatefulWidget {
  const LiquidLensDemo({super.key});

  @override
  State<LiquidLensDemo> createState() => _LiquidLensDemoState();
}

class _LiquidLensDemoState extends State<LiquidLensDemo> {
  Offset _lensPos = const Offset(160, 160);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LiquidGlassView(
        realTime: true,
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Wrapped with a CORS proxy so Flutter Web's CanvasKit can safely
            // read the pixels without crashing the browser!
            Image.network(
              'https://wsrv.nl/?url=https://images.unsplash.com/photo-1485470733090-0aae1788d5af?fm=jpg&q=60&w=3000&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8MXx8d2FsbHBhcGVyJTIwNGt8ZW58MHx8MHx8fDA%3D',
              fit: BoxFit.cover,
            ),
            // (Removed GridView pattern)
            // ── Faint background text (to show distortion clearly) ──────
            const Align(
              alignment: Alignment(0, -0.2),
              child: Text(
                'LIQUID GLASS',
                style: TextStyle(
                  fontSize: 54,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 14,
                  color: Colors.white24,
                ),
              ),
            ),
          ],
        ),
        lenses: [
          // ── Shape Refraction Lens (Centered) ──────────────────────
          LiquidLens(
            position: LiquidGlassPosition.center,
            width: 260,
            height: 260,
            draggable: true,
            refractionMode: LiquidRefractionMode.shape,
            distortion: 0.18,
            magnification: 1.4,
            chromaticAberration: 0.008,
            child: const Center(
              child: Icon(Icons.api_rounded, color: Colors.white, size: 72),
            ),
          ),

          // ── Radial Refraction Lens (Bottom Right) ─────────────────
          LiquidLens(
            position: const LiquidGlassPosition.alignment(
              Alignment.bottomRight,
            ),
            width: 200,
            height: 200,
            draggable: true,
            refractionMode: LiquidRefractionMode.radial,
            distortion: 0.25,
            magnification: 1.2,
            chromaticAberration: 0.012,
            child: const Center(
              child: Icon(Icons.blur_on, color: Colors.white, size: 72),
            ),
          ),
        ],
      ),
    );
  }
}
