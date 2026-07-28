import 'package:flutter/material.dart';

import '../widgets/gpu_image_filter.dart';

/// Beauty / color grading settings for the host's local camera preview.
///
/// These affect the **local preview** (widgets that wrap the local
/// [VideoTrackRenderer] with [FilteredVideoPreview]). LiveKit's Flutter
/// SDK does not ship a ready-made face-beauty [TrackProcessor], so the
/// published WebRTC bitstream is not re-encoded with these matrices —
/// HD capture quality still applies to what viewers receive. When a real
/// processor is plugged in later, this same model can drive it.
class VideoFilterSettings {
  /// Soft-skin / beautify strength (0 = off, 1 = max).
  final double beauty;

  /// -1.0 … 1.0 (0 = unchanged)
  final double brightness;

  /// -1.0 … 1.0 (0 = unchanged)
  final double contrast;

  /// -1.0 … 1.0 (0 = unchanged)
  final double saturation;

  /// Master switch — when false, filters are identity / no blur.
  final bool beautyModeEnabled;

  final VideoFilterPreset preset;

  const VideoFilterSettings({
    this.beauty = 0.5,
    this.brightness = 0.08,
    this.contrast = 0.05,
    this.saturation = 0.1,
    this.beautyModeEnabled = true,
    this.preset = VideoFilterPreset.smooth,
  });

  static const identity = VideoFilterSettings(
    beauty: 0,
    brightness: 0,
    contrast: 0,
    saturation: 0,
    beautyModeEnabled: false,
    preset: VideoFilterPreset.natural,
  );

  VideoFilterSettings copyWith({
    double? beauty,
    double? brightness,
    double? contrast,
    double? saturation,
    bool? beautyModeEnabled,
    VideoFilterPreset? preset,
  }) {
    return VideoFilterSettings(
      beauty: beauty ?? this.beauty,
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      saturation: saturation ?? this.saturation,
      beautyModeEnabled: beautyModeEnabled ?? this.beautyModeEnabled,
      preset: preset ?? this.preset,
    );
  }

  /// Apply a named preset, replacing slider values.
  VideoFilterSettings withPreset(VideoFilterPreset preset) {
    switch (preset) {
      // Values bumped up across the board — the original set read as
      // near-invisible next to Bigo-style beauty cams. "Natural" now has a
      // real (if light) smoothing pass instead of being almost a no-op.
      case VideoFilterPreset.natural:
        return copyWith(
          preset: preset,
          beautyModeEnabled: true,
          beauty: 0.30,
          brightness: 0.04,
          contrast: 0,
          saturation: 0,
        );
      case VideoFilterPreset.smooth:
        return copyWith(
          preset: preset,
          beautyModeEnabled: true,
          beauty: 0.75,
          // Was 0.14 — combined with the shader's own skin-whitening this
          // made "Smooth" read as washed-out/too-white. Smoothing (beauty)
          // strength is unchanged, only the extra brightness lift.
          brightness: 0.06,
          contrast: -0.05,
          saturation: 0.05,
        );
      case VideoFilterPreset.bright:
        return copyWith(
          preset: preset,
          beautyModeEnabled: true,
          beauty: 0.55,
          brightness: 0.30,
          contrast: 0.08,
          saturation: 0.12,
        );
      case VideoFilterPreset.vivid:
        return copyWith(
          preset: preset,
          beautyModeEnabled: true,
          beauty: 0.45,
          brightness: 0.16,
          contrast: 0.18,
          saturation: 0.35,
        );
      case VideoFilterPreset.cool:
        return copyWith(
          preset: preset,
          beautyModeEnabled: true,
          beauty: 0.5,
          brightness: 0.10,
          contrast: 0.1,
          saturation: -0.12,
        );
    }
  }

  /// Maps a stored room [filterName] (from create-room / beauty sheet)
  /// onto a preset. Accepts preset labels and catalog names
  /// (e.g. "Sakura Glow").
  static VideoFilterSettings fromFilterName(String? name) {
    final key = (name ?? '').trim().toLowerCase();
    if (key.isEmpty) {
      return const VideoFilterSettings().withPreset(VideoFilterPreset.natural);
    }

    for (final preset in VideoFilterPreset.values) {
      if (preset.label.toLowerCase() == key || preset.name == key) {
        return const VideoFilterSettings().withPreset(preset);
      }
    }

    // Beauty sheet catalog aliases → nearest grading preset.
    const aliases = <String, VideoFilterPreset>{
      'sakura glow': VideoFilterPreset.bright,
      'sakura sheer': VideoFilterPreset.smooth,
      'peach ii': VideoFilterPreset.vivid,
      'golden muse': VideoFilterPreset.bright,
      'silver sire': VideoFilterPreset.cool,
      'rose kiss': VideoFilterPreset.vivid,
      'nude matte': VideoFilterPreset.natural,
      'soft skin': VideoFilterPreset.smooth,
      'soft glow': VideoFilterPreset.bright,
      'clear': VideoFilterPreset.natural,
      'porcelain': VideoFilterPreset.smooth,
      'cinema': VideoFilterPreset.cool,
      'warm day': VideoFilterPreset.bright,
      'fresh': VideoFilterPreset.vivid,
      'film': VideoFilterPreset.cool,
      'none': VideoFilterPreset.natural,
    };
    final mapped = aliases[key] ?? VideoFilterPreset.natural;
    return const VideoFilterSettings().withPreset(mapped);
  }

  bool get isActive =>
      beautyModeEnabled &&
      (beauty != 0 || brightness != 0 || contrast != 0 || saturation != 0);

  /// Soft blur sigma for the "smooth skin" look. Kept low — heavy blur is
  /// the main cause of preview lag on mid-range devices.
  double get softBlurSigma {
    if (!beautyModeEnabled) return 0;
    return (beauty * 0.35).clamp(0.0, 0.45);
  }

  Map<String, dynamic> toJson() => {
        'beauty': beauty,
        'brightness': brightness,
        'contrast': contrast,
        'saturation': saturation,
        'beautyModeEnabled': beautyModeEnabled,
        'preset': preset.name,
      };

  factory VideoFilterSettings.fromJson(Map<String, dynamic> json) {
    final presetName = json['preset'] as String?;
    final preset = VideoFilterPreset.values.firstWhere(
      (p) => p.name == presetName || p.label.toLowerCase() == (presetName ?? '').toLowerCase(),
      orElse: () => VideoFilterPreset.natural,
    );
    return VideoFilterSettings(
      beauty: (json['beauty'] as num?)?.toDouble() ?? 0.35,
      brightness: (json['brightness'] as num?)?.toDouble() ?? 0.05,
      contrast: (json['contrast'] as num?)?.toDouble() ?? 0.05,
      saturation: (json['saturation'] as num?)?.toDouble() ?? 0.1,
      beautyModeEnabled: json['beautyModeEnabled'] as bool? ?? true,
      preset: preset,
    );
  }

  /// Builds a 5×4 color matrix for [ColorFiltered].
  ColorFilter toColorFilter() {
    if (!beautyModeEnabled) {
      return const ColorFilter.matrix(<double>[
        1, 0, 0, 0, 0,
        0, 1, 0, 0, 0,
        0, 0, 1, 0, 0,
        0, 0, 0, 1, 0,
      ]);
    }

    // Contrast around mid-gray (128). Beauty only barely softens contrast —
    // at 0.15 a high-beauty preset flattened the whole frame.
    final contrastGain = (1.0 + contrast - beauty * 0.05).clamp(0.2, 2.5);

    // Brightness is exposure (a gain), not a flat offset. A flat offset
    // lifts the black level, which is what made every preset look faded;
    // scaling keeps blacks black while still opening up the mids.
    final exposure = (1.0 + brightness * 0.55 + beauty * 0.03).clamp(0.2, 2.5);

    final c = contrastGain * exposure;
    final t = 128.0 * exposure * (1.0 - contrastGain);

    // Saturation matrix (luma-preserving).
    final s = (1.0 + saturation).clamp(0.0, 2.5);
    const lr = 0.2126;
    const lg = 0.7152;
    const lb = 0.0722;
    final sr = (1 - s) * lr;
    final sg = (1 - s) * lg;
    final sb = (1 - s) * lb;

    final matrix = <double>[
      c * (sr + s), c * sg, c * sb, 0, t,
      c * sr, c * (sg + s), c * sb, 0, t,
      c * sr, c * sg, c * (sb + s), 0, t,
      0, 0, 0, 1, 0,
    ];

    // Warm lift for "beauty" (Bigo-like soft glow). Kept small: this is a
    // flat offset, so anything larger reads as haze over the whole frame.
    if (beauty > 0) {
      final warm = beauty * 3.0;
      matrix[4] += warm;
      matrix[9] += warm * 0.6;
      matrix[14] += warm * 0.2;
    }

    return ColorFilter.matrix(matrix);
  }
}

enum VideoFilterPreset { natural, smooth, bright, vivid, cool }

extension VideoFilterPresetLabel on VideoFilterPreset {
  String get label => switch (this) {
    VideoFilterPreset.natural => 'Natural',
    VideoFilterPreset.smooth => 'Smooth',
    VideoFilterPreset.bright => 'Bright',
    VideoFilterPreset.vivid => 'Vivid',
    VideoFilterPreset.cool => 'Cool',
  };

  IconData get icon => switch (this) {
    VideoFilterPreset.natural => Icons.face_retouching_natural,
    VideoFilterPreset.smooth => Icons.blur_on,
    VideoFilterPreset.bright => Icons.wb_sunny_outlined,
    VideoFilterPreset.vivid => Icons.palette_outlined,
    VideoFilterPreset.cool => Icons.ac_unit_outlined,
  };
}

/// Applies beauty / color grading on a video tile.
///
/// This is a **client-side** visual effect — LiveKit publishes the raw
/// camera track. GPU skin-smooth runs only when [enableBlur] is true
/// (local publisher preview). Remotes use cheap [ColorFiltered] only so
/// multi-seat rooms do not lag.
class FilteredVideoPreview extends StatelessWidget {
  final Widget child;
  final VideoFilterSettings settings;

  /// When true (local host/guest preview), run the GPU beauty shader.
  /// When false (remote tiles), skip GPU — ColorFiltered only.
  final bool enableBlur;

  const FilteredVideoPreview({
    super.key,
    required this.child,
    required this.settings,
    this.enableBlur = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!settings.beautyModeEnabled && !settings.isActive) return child;

    // Remotes / viewers: never snapshot video frames — that was the main lag.
    // Without the smoothing pass, beauty's brightening/warm lift has nothing
    // to soften and just reads as haze over an already soft remote stream, so
    // scale it back and keep only the preset's colour character.
    final gradeSource = enableBlur
        ? settings
        : settings.copyWith(beauty: settings.beauty * 0.3);

    final graded = ColorFiltered(
      colorFilter: gradeSource.toColorFilter(),
      child: child,
    );

    if (!enableBlur || !settings.beautyModeEnabled) return graded;

    final intensity = (0.08 +
            settings.beauty * 1.05 +
            settings.brightness.abs() * 0.2 +
            settings.saturation.abs() * 0.05 +
            0.05)
        .clamp(0.0, 1.0);

    if (intensity <= 0) return graded;

    return GpuImageFilter(
      enabled: true,
      intensity: intensity,
      child: graded,
    );
  }
}
