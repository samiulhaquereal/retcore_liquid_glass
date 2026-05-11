import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

// ── Controller ──────────────────────────────────────────────────────────────

/// Manages background capture for [LiquidGlassView].
class LiquidGlassController extends ChangeNotifier {
  ui.Image? _backgroundImage;
  
  /// Returns a clone of the current background image.
  /// The caller is responsible for disposing the returned clone.
  ui.Image? getBackgroundImageClone() => _backgroundImage?.clone();

  final GlobalKey _boundaryKey = GlobalKey();
  GlobalKey get boundaryKey => _boundaryKey;

  bool _capturing = false;
  bool _disposed = false;
  bool _hasCaptureError = false;
  Size? bgLogicalSize;

  Future<void> capture({double pixelRatio = 1.0}) async {
    // If the browser security previously crashed the capture, stop trying!
    if (_capturing || _disposed || _hasCaptureError) return;

    final boundary = _boundaryKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null || boundary.debugNeedsPaint) return;

    _capturing = true;
    try {
      // On Web, adding a tiny delay prevents the engine from blocking
      await Future.delayed(Duration.zero);
      
      final img = await boundary.toImage(pixelRatio: pixelRatio);
      
      if (_disposed) {
        img.dispose();
        return;
      }

      final old = _backgroundImage;
      _backgroundImage = img; 
      bgLogicalSize = boundary.size;
      
      // Memory Optimization: Discard immediately instead of delaying 100ms!
      // This eliminates the ~15-20MB memory spike per frame.
      old?.dispose();
      
      notifyListeners();
    } catch (e) {
      _hasCaptureError = true; // Engage Crash Breaker!
      debugPrint('[LiquidGlass] CAPTURE DISABLED: Web CORS Security triggered a crash.');
      debugPrint('[LiquidGlass] Error details: $e');
    } finally {
      _capturing = false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _backgroundImage?.dispose();
    _backgroundImage = null;
    super.dispose();
  }
}

// ── LiquidGlassView ─────────────────────────────────────────────────────────

/// Wraps a background widget and a list of [LiquidLens] overlays.
///
/// The background is captured each frame and fed to every lens as a texture.
class LiquidGlassView extends StatefulWidget {
  /// The widget rendered behind all lenses. This is what gets captured.
  /// Defaults to a solid black background if null.
  final Widget? background;

  /// The [LiquidLens] widgets placed over the background.
  final List<Widget> lenses;

  /// When `true` the background is re-captured every frame (~30 fps).
  /// Set to `false` for static backgrounds.
  final bool realTime;

  /// Pixel ratio used when capturing the background (default 1.0).
  /// Lower values improve performance; 1.0 gives native sharpness.
  final double capturePixelRatio;

  const LiquidGlassView({
    super.key,
    this.background,
    required this.lenses,
    this.realTime = true,
    this.capturePixelRatio = 1.0,
  });

  @override
  State<LiquidGlassView> createState() => _LiquidGlassViewState();
}

class _LiquidGlassViewState extends State<LiquidGlassView>
    with SingleTickerProviderStateMixin {
  late final LiquidGlassController _controller = LiquidGlassController();
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      if (!widget.realTime || !mounted) return;
      
      // Throttle to ~30 FPS to prevent crashing the Web engine
      final ms = elapsed.inMilliseconds;
      if (ms % 33 < 16) { // Rough 30fps throttle
        _doSafeCapture();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _doSafeCapture();
      if (widget.realTime) _ticker.start();
    });
  }

  void _doSafeCapture() {
    if (!mounted) return;
    try {
      // OVER-SAMPLING: To prevent magnification pixelation on standard monitors,
      // we ensure the capture is always at least 2.0x (Retina) density.
      double baseDpr = View.maybeOf(context)?.devicePixelRatio ?? 1.0;
      if (baseDpr < 2.0) baseDpr = 2.0;

      final finalDpr = widget.capturePixelRatio == 1.0 
          ? baseDpr 
          : widget.capturePixelRatio;

      _controller.capture(pixelRatio: finalDpr);
    } catch (e) {
      // Silently handle if view isn't ready
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RepaintBoundary(
          key: _controller.boundaryKey,
          child: widget.background ?? const ColoredBox(color: Colors.black),
        ),
        ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            // Only show lenses once we have a valid background capture
            if (getBackgroundImageClone() == null) return const SizedBox.shrink();
            
            return Stack(
              children: widget.lenses,
            );
          },
        ),
      ],
    );
  }

  ui.Image? getBackgroundImageClone() => _controller.getBackgroundImageClone();
}

/// Refraction styles for [LiquidLens].
enum LiquidRefractionMode {
  /// Refracts light based on the underlying sphere geometry (physically accurate).
  shape,

  /// Refracts light radially from the center (stylized circular distortion).
  radial,
}

/// A position for the [LiquidLens], which can be an absolute [Offset]
/// or a relative [Alignment].
class LiquidGlassPosition {
  final Offset? _offset;
  final Alignment? _alignment;

  const LiquidGlassPosition.offset(Offset offset)
      : _offset = offset,
        _alignment = null;

  const LiquidGlassPosition.alignment(Alignment alignment)
      : _alignment = alignment,
        _offset = null;

  /// Shorthand for Alignment.center.
  static const center = LiquidGlassPosition.alignment(Alignment.center);

  /// Resolves the position to an absolute Offset based on the container size.
  Offset resolve(Size containerSize, Size lensSize) {
    if (_offset != null) return _offset;
    if (_alignment != null) {
      // Calculate center of the container
      final centerX = containerSize.width / 2;
      final centerY = containerSize.height / 2;

      // Calculate the alignment offset from the center
      final shiftX = (containerSize.width / 2) * _alignment.x;
      final shiftY = (containerSize.height / 2) * _alignment.y;

      // Top-left of the lens to center it on the alignment point
      return Offset(
        centerX + shiftX - (lensSize.width / 2),
        centerY + shiftY - (lensSize.height / 2),
      );
    }
    return Offset.zero;
  }
}

/// A glass lens that refracts, magnifies, and distorts the background.
class LiquidLens extends StatefulWidget {
  /// Width of the lens.
  final double width;

  /// Height of the lens.
  final double height;

  /// Zoom factor inside the glass. `1.0` = no zoom.
  final double magnification;

  /// Edge distortion strength.
  final double distortion;

  /// The style of distortion applied to the lens.
  final LiquidRefractionMode refractionMode;

  /// RGB channel split amount.
  final double chromaticAberration;

  /// Colour tint applied on top of the refracted background.
  final Color color;

  /// Initial position of the lens.
  final LiquidGlassPosition position;

  /// If true, the lens can be dragged around by the user.
  final bool draggable;

  /// Optional widget rendered inside the lens (e.g. icons, text).
  final Widget? child;

  const LiquidLens({
    super.key,
    this.width = 200,
    this.height = 200,
    this.magnification = 1.0,
    this.distortion = 0.125,
    this.refractionMode = LiquidRefractionMode.shape,
    this.chromaticAberration = 0.005,
    this.color = Colors.transparent,
    required this.position,
    this.draggable = false,
    this.child,
  });

  @override
  State<LiquidLens> createState() => _LiquidLensState();
}

class _LiquidLensState extends State<LiquidLens> {
  ui.FragmentProgram? _program;
  ui.Image? _localImageClone;
  Offset? _currentPos;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _loadShader();
  }

  @override
  void didUpdateWidget(LiquidLens oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.position != widget.position) {
      _initialized = false;
    }
  }

  @override
  void dispose() {
    _localImageClone?.dispose();
    super.dispose();
  }

  Future<void> _loadShader() async {
    try {
      final prog = await ui.FragmentProgram.fromAsset(
          'packages/glass/shaders/liquid_lens.frag');
      if (mounted) setState(() => _program = prog);
    } catch (e) {
      debugPrint('[LiquidGlass] shader load error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewState =
        context.findAncestorStateOfType<_LiquidGlassViewState>();
    
    // Determine the initial position based on context size if not yet set
    if (!_initialized) {
      final Size size = MediaQuery.sizeOf(context);
      _currentPos = widget.position.resolve(size, Size(widget.width, widget.height));
      _initialized = true;
    }

    // Get a fresh clone if the background changed
    final controller = viewState?._controller;
    if (controller != null) {
      final newImg = controller.getBackgroundImageClone();
      if (newImg != null) {
        _localImageClone?.dispose();
        _localImageClone = newImg;
      }
    }

    Widget content = SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        children: [
          // ── Lens effect ───────────────────────────────────────────
          if (_program != null && _localImageClone != null)
            CustomPaint(
              painter: _LensPainter(
                shader: _program!.fragmentShader(),
                image: _localImageClone!,
                refraction: widget.distortion,
                refractionMode: widget.refractionMode,
                magnification: widget.magnification,
                chromatic: widget.chromaticAberration,
                tint: widget.color,
                lensPos: _currentPos ?? Offset.zero,
                bgLogicalSize: controller?.bgLogicalSize ?? MediaQuery.sizeOf(context),
                dpr: View.of(context).devicePixelRatio,
              ),
              size: Size(widget.width, widget.height),
            ),
          // ── Child overlay ─────────────────────────────────────────
          if (widget.child != null)
            Positioned.fill(child: widget.child!),
        ],
      ),
    );

    if (widget.draggable) {
      content = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (d) => setState(() => _currentPos = (_currentPos ?? Offset.zero) + d.delta),
        child: content,
      );
    }

    return Positioned(
      left: _currentPos?.dx ?? 0,
      top: _currentPos?.dy ?? 0,
      child: content,
    );
  }
}

// ── Painter ──────────────────────────────────────────────────────────────────

class _LensPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final ui.Image image;
  final double refraction;
  final LiquidRefractionMode refractionMode;
  final double magnification;
  final double chromatic;
  final Color tint;
  final Offset lensPos;
  final Size bgLogicalSize;
  final double dpr;

  const _LensPainter({
    required this.shader,
    required this.image,
    required this.refraction,
    required this.refractionMode,
    required this.magnification,
    required this.chromatic,
    required this.tint,
    required this.lensPos,
    required this.bgLogicalSize,
    required this.dpr,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Uniform layout (must match liquid_lens.frag declaration order):
    // vec2 uSize         -> 0, 1
    // sampler2D uTexture -> sampler 0
    // float uRefraction  -> 2
    // float uMagnification -> 3
    // float uChromatic     -> 4
    // vec4 uTint           -> 5, 6, 7, 8
    // vec2 uBgSize         -> 9, 10
    // vec2 uLensPos        -> 11, 12
    // float uTime          -> 13
    // float uMode          -> 14
    
    shader.setFloat(0, size.width * dpr);
    shader.setFloat(1, size.height * dpr);
    shader.setImageSampler(0, image);
    shader.setFloat(2, refraction);
    shader.setFloat(3, magnification);
    shader.setFloat(4, chromatic);
    shader.setFloat(5, tint.r);
    shader.setFloat(6, tint.g);
    shader.setFloat(7, tint.b);
    shader.setFloat(8, tint.a);
    // Normalized background coordinates (0.0 to 1.0)
    final bgW = bgLogicalSize.width == 0 ? 1.0 : bgLogicalSize.width;
    final bgH = bgLogicalSize.height == 0 ? 1.0 : bgLogicalSize.height;
    
    shader.setFloat(9, size.width / bgW);
    shader.setFloat(10, size.height / bgH);
    shader.setFloat(11, lensPos.dx / bgW);
    shader.setFloat(12, lensPos.dy / bgH);
    
    shader.setFloat(13, refractionMode == LiquidRefractionMode.shape ? 0.0 : 1.0);

    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant _LensPainter old) =>
      old.image != image || old.lensPos != lensPos ||
      old.refraction != refraction || old.refractionMode != refractionMode ||
      old.magnification != magnification || old.chromatic != chromatic ||
      old.tint != tint || old.bgLogicalSize != bgLogicalSize || old.dpr != dpr;
}

// ── LiquidGlass (noise background widget) ────────────────────────────────────

/// A widget that applies a flowing liquid-noise background effect.
///
/// Uses a GLSL shader for GPU-accelerated animation.
class LiquidGlass extends StatefulWidget {
  final Widget?       child;
  final double        blur;
  final double        intensity;
  final Color         color1;
  final Color         color2;
  final BorderRadius? borderRadius;
  final double?       width;
  final double?       height;

  const LiquidGlass({
    super.key,
    this.child,
    this.blur        = 20.0,
    this.intensity   = 0.5,
    this.color1      = const Color(0x80FFFFFF),
    this.color2      = const Color(0x33FFFFFF),
    this.borderRadius,
    this.width,
    this.height,
  });

  @override
  State<LiquidGlass> createState() => _LiquidGlassState();
}

class _LiquidGlassState extends State<LiquidGlass>
    with SingleTickerProviderStateMixin {
  ui.FragmentProgram? _program;
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 10),
  )..repeat();

  @override
  void initState() {
    super.initState();
    _loadShader();
  }

  Future<void> _loadShader() async {
    try {
      final prog = await ui.FragmentProgram.fromAsset(
          'packages/glass/shaders/liquid_noise.frag');
      if (mounted) setState(() => _program = prog);
    } catch (e) {
      debugPrint('[LiquidGlass] noise shader load error: $e');
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: ClipRRect(
        borderRadius: widget.borderRadius ?? BorderRadius.zero,
        child: Stack(
          fit: StackFit.expand,
          children: [
            BackdropFilter(
              filter: ui.ImageFilter.blur(
                  sigmaX: widget.blur, sigmaY: widget.blur),
              child: const SizedBox.expand(),
            ),
            if (_program != null)
              AnimatedBuilder(
                animation: _ctrl,
                builder: (_, __) => CustomPaint(
                  painter: _NoisePainter(
                    shader:    _program!.fragmentShader(),
                    time:      _ctrl.value * 10,
                    intensity: widget.intensity,
                    color1:    widget.color1,
                    color2:    widget.color2,
                  ),
                  size: Size.infinite,
                ),
              ),
            if (widget.child != null)
              Positioned.fill(child: widget.child!),
          ],
        ),
      ),
    );
  }
}

class _NoisePainter extends CustomPainter {
  final ui.FragmentShader shader;
  final double time;
  final double intensity;
  final Color  color1;
  final Color  color2;

  const _NoisePainter({
    required this.shader,
    required this.time,
    required this.intensity,
    required this.color1,
    required this.color2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, time);
    shader.setFloat(3, intensity);
    shader.setFloat(4,  color1.red   / 255.0);
    shader.setFloat(5,  color1.green / 255.0);
    shader.setFloat(6,  color1.blue  / 255.0);
    shader.setFloat(7,  color1.alpha / 255.0);
    shader.setFloat(8,  color2.red   / 255.0);
    shader.setFloat(9,  color2.green / 255.0);
    shader.setFloat(10, color2.blue  / 255.0);
    shader.setFloat(11, color2.alpha / 255.0);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant _NoisePainter old) => old.time != time;
}
