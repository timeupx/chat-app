import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_shaders/flutter_shaders.dart';

import '../shaders/beauty_shader.dart';

/// GPU beauty filter for live camera / video tiles.
///
/// Applies [kBeautyShaderAssetKey] (skin smoothing + whitening) via Flutter's
/// own fragment-shader runtime.
///
/// This does **not** re-sample every single video frame. An earlier version
/// used `flutter_shaders`' [AnimatedSampler] directly on the live video
/// widget, which snapshots its child via a *synchronous* `toImageSync` call
/// on every repaint — for a 24–30fps camera feed that's 24–30 blocking GPU
/// readbacks per second, which is what caused visible lag even after capping
/// the sampled resolution. Instead, this widget takes an **async**,
/// **throttled** snapshot of the video (via [RenderRepaintBoundary.toImage])
/// on a fixed low-rate timer, and paints that cached frame through the
/// shader. The beauty effect trails real motion by a beat (~90ms), which is
/// imperceptible for a skin-smoothing/whitening look, in exchange for a
/// large, consistent perf win.
///
/// (An earlier version also depended on the `gpu_image` package for a native
/// filter fallback, but that package is unmaintained and its Android build
/// no longer declares a `namespace`, which breaks builds on current AGP —
/// it has been dropped entirely; it wasn't needed for the shader path above.)
class GpuImageFilter extends StatefulWidget {
  final Widget child;

  /// Master switch — when false, [child] is shown unfiltered.
  final bool enabled;

  /// Beauty strength in `0.0 … 1.0`.
  final double intensity;

  const GpuImageFilter({
    super.key,
    required this.child,
    this.enabled = true,
    this.intensity = 0.55,
  });

  @override
  State<GpuImageFilter> createState() => _GpuImageFilterState();
}

class _GpuImageFilterState extends State<GpuImageFilter> {
  // ~5 snapshots/sec — enough for skin smooth without choking the decoder.
  static const _captureInterval = Duration(milliseconds: 200);

  final _boundaryKey = GlobalKey();
  Timer? _timer;
  ui.Image? _snapshot;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  @override
  void didUpdateWidget(covariant GpuImageFilter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      _restartTimer();
    }
  }

  void _restartTimer() {
    _timer?.cancel();
    // RepaintBoundary.toImage / findRenderObject is unreliable on Flutter
    // web (throws JSArray DiagnosticsNode cast errors). Skip the snapshot
    // loop there — child still gets ColorFiltered grading upstream.
    if (!widget.enabled || kIsWeb) return;
    // Fire an initial capture immediately so the beauty pass doesn't wait a
    // full interval before showing anything.
    WidgetsBinding.instance.addPostFrameCallback((_) => _capture());
    _timer = Timer.periodic(_captureInterval, (_) => _capture());
  }

  Future<void> _capture() async {
    if (_capturing || !mounted || !widget.enabled || kIsWeb) return;

    RenderRepaintBoundary? boundary;
    try {
      final ctx = _boundaryKey.currentContext;
      if (ctx == null || !ctx.mounted) return;
      final renderObject = ctx.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) return;
      // Not painted / zero size yet — wait for next tick.
      if (!renderObject.hasSize || renderObject.size.isEmpty) return;
      boundary = renderObject;
    } catch (_) {
      // Deactivated element / web diagnostics cast noise — retry next tick.
      return;
    }

    _capturing = true;
    try {
      final mq = MediaQuery.maybeOf(context);
      // Beauty doesn't need retina sampling — keep readbacks cheap.
      final dpr = (mq?.devicePixelRatio ?? 1.0).clamp(0.75, 1.0);
      final image = await boundary.toImage(pixelRatio: dpr);
      if (!mounted) {
        image.dispose();
        return;
      }
      final old = _snapshot;
      setState(() => _snapshot = image);
      old?.dispose();
    } catch (_) {
      // Boundary not painted yet / torn down mid-capture — safe to ignore,
      // the next timer tick retries.
    } finally {
      _capturing = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _snapshot?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final amount = widget.intensity.clamp(0.0, 1.0);
    // Web: never mount the GlobalKey'd capture path — toImage is broken /
    // noisy there and spam-throws in the console.
    if (kIsWeb || !widget.enabled || amount <= 0.001) {
      return widget.child;
    }

    final boundedChild = RepaintBoundary(key: _boundaryKey, child: widget.child);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        // Skip the GPU pass entirely on tiny/unbounded tiles (e.g. a small
        // grid thumbnail) — a skin-smoothing effect is imperceptible there.
        // `child` still carries the cheap ColorFiltered grading from
        // [FilteredVideoPreview], so the look doesn't just disappear.
        if (!size.width.isFinite ||
            !size.height.isFinite ||
            size.width * size.height < 140 * 140) {
          // Tiny tiles: no GPU timer work — show graded video only.
          if (_timer != null) {
            _timer?.cancel();
            _timer = null;
          }
          return widget.child;
        }

        // Resume capture if we previously paused for a tiny layout.
        if (_timer == null && widget.enabled && !kIsWeb) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _restartTimer();
          });
        }

        final snapshot = _snapshot;
        // `boundedChild` stays fully painted (needed to keep feeding the
        // periodic capture above) — it must NOT be wrapped in
        // `Opacity(opacity: 0)`, because `RenderOpacity.paint()` skips
        // painting its child entirely at alpha 0 (a documented Flutter fast
        // path). That would freeze the boundary's content on whatever it
        // last painted, so every future snapshot would just re-capture a
        // stale frame. Instead, once a snapshot exists, the opaque shaded
        // layer is painted *on top* of it in the same [Stack] and fully
        // covers it — the raw video keeps decoding underneath (unseen), and
        // there's never more than one mount of the GlobalKey'd boundary.
        return Stack(
          fit: StackFit.expand,
          children: [
            boundedChild,
            if (snapshot != null)
              ShaderBuilder(
                assetKey: kBeautyShaderAssetKey,
                (BuildContext context, FragmentShader shader, Widget? _) {
                  return CustomPaint(
                    size: size,
                    painter: _BeautyShaderPainter(
                      image: snapshot,
                      shader: shader,
                      intensity: amount,
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

class _BeautyShaderPainter extends CustomPainter {
  final ui.Image image;
  final FragmentShader shader;
  final double intensity;

  _BeautyShaderPainter({
    required this.image,
    required this.shader,
    required this.intensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    shader.setFloat(0, intensity);
    shader.setFloat(1, size.width);
    shader.setFloat(2, size.height);
    shader.setImageSampler(0, image);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant _BeautyShaderPainter oldDelegate) {
    return oldDelegate.image != image || oldDelegate.intensity != intensity;
  }
}

/// Compact sheet: Beauty ON/OFF + intensity slider.
Future<BeautyGpuSettings?> showGpuBeautyControls({
  required BuildContext context,
  required bool enabled,
  required double intensity,
}) {
  return showModalBottomSheet<BeautyGpuSettings>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _GpuBeautySheet(enabled: enabled, intensity: intensity),
  );
}

class BeautyGpuSettings {
  final bool enabled;
  final double intensity;

  const BeautyGpuSettings({required this.enabled, required this.intensity});
}

class _GpuBeautySheet extends StatefulWidget {
  final bool enabled;
  final double intensity;

  const _GpuBeautySheet({required this.enabled, required this.intensity});

  @override
  State<_GpuBeautySheet> createState() => _GpuBeautySheetState();
}

class _GpuBeautySheetState extends State<_GpuBeautySheet> {
  late bool _enabled = widget.enabled;
  late double _intensity = widget.intensity.clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: 16 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1C142E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(
                Icons.face_retouching_natural,
                color: Color(0xFF00D4C8),
                size: 22,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Beauty Filter',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Switch.adaptive(
                value: _enabled,
                activeThumbColor: const Color(0xFF00D4C8),
                onChanged: (v) => setState(() => _enabled = v),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Intensity  ${(_intensity * 100).round()}%',
            style: TextStyle(
              color: Colors.white.withValues(alpha: _enabled ? 0.85 : 0.35),
              fontSize: 13,
            ),
          ),
          Slider(
            value: _intensity,
            min: 0,
            max: 1,
            activeColor: const Color(0xFF00D4C8),
            inactiveColor: Colors.white24,
            onChanged: _enabled
                ? (v) => setState(() => _intensity = v)
                : null,
          ),
          const SizedBox(height: 4),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              BeautyGpuSettings(enabled: _enabled, intensity: _intensity),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF00D4C8),
              foregroundColor: Colors.black,
            ),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}
