import 'package:flutter/material.dart';

import '../models/video_filter_settings.dart';

/// Bottom sheet with Beauty Mode toggle, presets (Natural / Smooth /
/// Bright / Vivid / Cool), and sliders for beauty / brightness / contrast /
/// saturation. Host-only — opened from the Beauty button on [LiveRoomScreen].
Future<void> showVideoFilterControls({
  required BuildContext context,
  required VideoFilterSettings initial,
  required ValueChanged<VideoFilterSettings> onChanged,
  Color? initialLipColor,
  ValueChanged<Color?>? onLipColorChanged,
  Color? initialBlushColor,
  ValueChanged<Color?>? onBlushColorChanged,
  Color? initialUnderEyeColor,
  ValueChanged<Color?>? onUnderEyeColorChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _VideoFilterSheet(
      initial: initial,
      onChanged: onChanged,
      initialLipColor: initialLipColor,
      onLipColorChanged: onLipColorChanged,
      initialBlushColor: initialBlushColor,
      onBlushColorChanged: onBlushColorChanged,
      initialUnderEyeColor: initialUnderEyeColor,
      onUnderEyeColorChanged: onUnderEyeColorChanged,
    ),
  );
}

/// Lipstick shades offered in the makeup row.
const _lipShades = <Color>[
  Color(0xFFC62348),
  Color(0xFFE0455E),
  Color(0xFFFF6F91),
  Color(0xFF9B2242),
  Color(0xFFD9704F),
  Color(0xFF7A2E4A),
];

/// Soft cheek blush shades.
const _blushShades = <Color>[
  Color(0xFFE57373),
  Color(0xFFEF9A9A),
  Color(0xFFFFAB91),
  Color(0xFFF48FB1),
  Color(0xFFCE93D8),
  Color(0xFFD7A8A0),
];

/// Under-eye concealer — warm mid-tones (not bright cream; those glow in the dark).
const _underEyeShades = <Color>[
  Color(0xFFD9B5A5),
  Color(0xFFE2C0B0),
  Color(0xFFCFA894),
  Color(0xFFE8C9B8),
  Color(0xFFD4A99A),
  Color(0xFFC9A090),
];

class _VideoFilterSheet extends StatefulWidget {
  final VideoFilterSettings initial;
  final ValueChanged<VideoFilterSettings> onChanged;
  final Color? initialLipColor;
  final ValueChanged<Color?>? onLipColorChanged;
  final Color? initialBlushColor;
  final ValueChanged<Color?>? onBlushColorChanged;
  final Color? initialUnderEyeColor;
  final ValueChanged<Color?>? onUnderEyeColorChanged;

  const _VideoFilterSheet({
    required this.initial,
    required this.onChanged,
    this.initialLipColor,
    this.onLipColorChanged,
    this.initialBlushColor,
    this.onBlushColorChanged,
    this.initialUnderEyeColor,
    this.onUnderEyeColorChanged,
  });

  @override
  State<_VideoFilterSheet> createState() => _VideoFilterSheetState();
}

class _VideoFilterSheetState extends State<_VideoFilterSheet> {
  late VideoFilterSettings _settings = widget.initial;
  late Color? _lipColor = widget.initialLipColor;
  late Color? _blushColor = widget.initialBlushColor;
  late Color? _underEyeColor = widget.initialUnderEyeColor;

  void _update(VideoFilterSettings next) {
    setState(() => _settings = next);
    widget.onChanged(next);
  }

  void _updateLips(Color? color) {
    setState(() => _lipColor = color);
    widget.onLipColorChanged?.call(color);
  }

  void _updateBlush(Color? color) {
    setState(() => _blushColor = color);
    widget.onBlushColorChanged?.call(color);
  }

  void _updateUnderEye(Color? color) {
    setState(() => _underEyeColor = color);
    widget.onUnderEyeColorChanged?.call(color);
  }

  Widget _buildShadeRow({
    required String label,
    required IconData icon,
    required List<Color> shades,
    required Color? selected,
    required ValueChanged<Color?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.pinkAccent, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(width: 8),
            Text(
              'viewers see this',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 10,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _LipSwatch(
              color: null,
              selected: selected == null,
              onTap: () => onChanged(null),
            ),
            for (final shade in shades) ...[
              const SizedBox(width: 10),
              _LipSwatch(
                color: shade,
                selected: selected?.toARGB32() == shade.toARGB32(),
                onTap: () => onChanged(shade),
              ),
            ],
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: 20 + MediaQuery.paddingOf(context).bottom,
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
              const Icon(Icons.face_retouching_natural, color: Colors.pinkAccent, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Beauty & Filters',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                'Beauty Mode',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 6),
              Switch.adaptive(
                value: _settings.beautyModeEnabled,
                activeThumbColor: Colors.pinkAccent,
                onChanged: (v) => _update(_settings.copyWith(beautyModeEnabled: v)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: VideoFilterPreset.values.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final preset = VideoFilterPreset.values[index];
                final selected = _settings.preset == preset && _settings.beautyModeEnabled;
                return GestureDetector(
                  onTap: () => _update(_settings.withPreset(preset)),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? Colors.pinkAccent : Colors.white24,
                        width: selected ? 2 : 1,
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: selected
                            ? const [Color(0xFFFF6B9D), Color(0xFF7C4DFF)]
                            : const [Color(0xFF2A1F45), Color(0xFF1C142E)],
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(preset.icon, color: Colors.white, size: 22),
                        const SizedBox(height: 4),
                        Text(
                          preset.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          IgnorePointer(
            ignoring: !_settings.beautyModeEnabled,
            child: Opacity(
              opacity: _settings.beautyModeEnabled ? 1 : 0.4,
              child: Column(
                children: [
                  _FilterSlider(
                    label: 'Beauty',
                    icon: Icons.face_retouching_natural,
                    value: _settings.beauty,
                    min: 0,
                    max: 1,
                    onChanged: (v) => _update(
                      _settings.copyWith(beauty: v, preset: VideoFilterPreset.smooth),
                    ),
                  ),
                  _FilterSlider(
                    label: 'Brightness',
                    icon: Icons.brightness_6_outlined,
                    value: _settings.brightness,
                    min: -1,
                    max: 1,
                    onChanged: (v) => _update(_settings.copyWith(brightness: v)),
                  ),
                  _FilterSlider(
                    label: 'Contrast',
                    icon: Icons.contrast,
                    value: _settings.contrast,
                    min: -1,
                    max: 1,
                    onChanged: (v) => _update(_settings.copyWith(contrast: v)),
                  ),
                  _FilterSlider(
                    label: 'Saturation',
                    icon: Icons.water_drop_outlined,
                    value: _settings.saturation,
                    min: -1,
                    max: 1,
                    onChanged: (v) => _update(_settings.copyWith(saturation: v)),
                  ),
                ],
              ),
            ),
          ),
          if (widget.onLipColorChanged != null ||
              widget.onBlushColorChanged != null ||
              widget.onUnderEyeColorChanged != null) ...[
            const SizedBox(height: 10),
            if (widget.onLipColorChanged != null)
              _buildShadeRow(
                label: 'Lipstick',
                icon: Icons.brush_outlined,
                shades: _lipShades,
                selected: _lipColor,
                onChanged: _updateLips,
              ),
            if (widget.onBlushColorChanged != null) ...[
              const SizedBox(height: 12),
              _buildShadeRow(
                label: 'Blush',
                icon: Icons.face_retouching_natural,
                shades: _blushShades,
                selected: _blushColor,
                onChanged: _updateBlush,
              ),
            ],
            if (widget.onUnderEyeColorChanged != null) ...[
              const SizedBox(height: 12),
              _buildShadeRow(
                label: 'Under-eye',
                icon: Icons.visibility_outlined,
                shades: _underEyeShades,
                selected: _underEyeColor,
                onChanged: _updateUnderEye,
              ),
            ],
          ],
          const SizedBox(height: 4),
          TextButton(
            onPressed: () {
              _update(VideoFilterSettings.identity);
              if (widget.onLipColorChanged != null) _updateLips(null);
              if (widget.onBlushColorChanged != null) _updateBlush(null);
              if (widget.onUnderEyeColorChanged != null) _updateUnderEye(null);
            },
            child: const Text('Reset', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}

class _LipSwatch extends StatelessWidget {
  final Color? color;
  final bool selected;
  final VoidCallback onTap;

  const _LipSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color ?? Colors.transparent,
          border: Border.all(
            color: selected ? Colors.white : Colors.white24,
            width: selected ? 2 : 1,
          ),
        ),
        child: color == null
            ? const Icon(Icons.block, color: Colors.white54, size: 16)
            : null,
      ),
    );
  }
}

class _FilterSlider extends StatelessWidget {
  final String label;
  final IconData icon;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _FilterSlider({
    required this.label,
    required this.icon,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Row(
            children: [
              Icon(icon, color: Colors.white54, size: 16),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.pinkAccent,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
              overlayColor: Colors.pinkAccent.withValues(alpha: 0.2),
              trackHeight: 3,
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            value.toStringAsFixed(2),
            textAlign: TextAlign.end,
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
        ),
      ],
    );
  }
}
