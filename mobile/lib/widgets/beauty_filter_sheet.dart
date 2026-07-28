import 'package:flutter/material.dart';

import '../models/video_filter_settings.dart';

/// One selectable look in the Bigo-style beauty sheet.
class BeautyFilterItem {
  final String id;
  final String name;
  final String tab; // Presets | Beauty | Make up | Filter
  final String sub; // New | Basic | Favorites | …
  final VideoFilterPreset preset;
  final List<Color> thumbColors;

  const BeautyFilterItem({
    required this.id,
    required this.name,
    required this.tab,
    required this.sub,
    required this.preset,
    required this.thumbColors,
  });
}

/// Catalog shown in [BeautyFilterSheet]. Names are what we persist as
/// `filterName`; [preset] drives the actual color grading.
class BeautyFilterCatalog {
  static const tabs = ['Presets', 'Beauty', 'Make up', 'Filter'];

  static const items = <BeautyFilterItem>[
    // ── Presets ──────────────────────────────────────────────────────────
    BeautyFilterItem(
      id: 'natural',
      name: 'Natural',
      tab: 'Presets',
      sub: 'Basic',
      preset: VideoFilterPreset.natural,
      thumbColors: [Color(0xFFE8D5C4), Color(0xFFC4A484)],
    ),
    BeautyFilterItem(
      id: 'smooth',
      name: 'Smooth',
      tab: 'Presets',
      sub: 'Basic',
      preset: VideoFilterPreset.smooth,
      thumbColors: [Color(0xFFF5D0C5), Color(0xFFE8A0A0)],
    ),
    BeautyFilterItem(
      id: 'bright',
      name: 'Bright',
      tab: 'Presets',
      sub: 'New',
      preset: VideoFilterPreset.bright,
      thumbColors: [Color(0xFFFFE5B4), Color(0xFFFFCBA4)],
    ),
    BeautyFilterItem(
      id: 'vivid',
      name: 'Vivid',
      tab: 'Presets',
      sub: 'New',
      preset: VideoFilterPreset.vivid,
      thumbColors: [Color(0xFFFFB6C1), Color(0xFFFF69B4)],
    ),
    BeautyFilterItem(
      id: 'cool',
      name: 'Cool',
      tab: 'Presets',
      sub: 'Basic',
      preset: VideoFilterPreset.cool,
      thumbColors: [Color(0xFFB8D4E8), Color(0xFF7EB6D9)],
    ),

    // ── Beauty ───────────────────────────────────────────────────────────
    BeautyFilterItem(
      id: 'soft_skin',
      name: 'Soft Skin',
      tab: 'Beauty',
      sub: 'New',
      preset: VideoFilterPreset.smooth,
      thumbColors: [Color(0xFFFADADD), Color(0xFFE8B4B8)],
    ),
    BeautyFilterItem(
      id: 'glow',
      name: 'Soft Glow',
      tab: 'Beauty',
      sub: 'New',
      preset: VideoFilterPreset.bright,
      thumbColors: [Color(0xFFFFF0D4), Color(0xFFFFDAB9)],
    ),
    BeautyFilterItem(
      id: 'clear',
      name: 'Clear',
      tab: 'Beauty',
      sub: 'Basic',
      preset: VideoFilterPreset.natural,
      thumbColors: [Color(0xFFF0E6D8), Color(0xFFD4C4B0)],
    ),
    BeautyFilterItem(
      id: 'porcelain',
      name: 'Porcelain',
      tab: 'Beauty',
      sub: 'Basic',
      preset: VideoFilterPreset.smooth,
      thumbColors: [Color(0xFFFFF5EE), Color(0xFFE8D5C4)],
    ),

    // ── Make up ──────────────────────────────────────────────────────────
    BeautyFilterItem(
      id: 'sakura_glow',
      name: 'Sakura Glow',
      tab: 'Make up',
      sub: 'New',
      preset: VideoFilterPreset.bright,
      thumbColors: [Color(0xFFFFB7C5), Color(0xFFFF69B4)],
    ),
    BeautyFilterItem(
      id: 'sakura_sheer',
      name: 'Sakura Sheer',
      tab: 'Make up',
      sub: 'New',
      preset: VideoFilterPreset.smooth,
      thumbColors: [Color(0xFFFFC0CB), Color(0xFFFF91A4)],
    ),
    BeautyFilterItem(
      id: 'peach_ii',
      name: 'Peach II',
      tab: 'Make up',
      sub: 'New',
      preset: VideoFilterPreset.vivid,
      thumbColors: [Color(0xFFFFDAB9), Color(0xFFFF7F50)],
    ),
    BeautyFilterItem(
      id: 'golden_muse',
      name: 'Golden Muse',
      tab: 'Make up',
      sub: 'New',
      preset: VideoFilterPreset.bright,
      thumbColors: [Color(0xFFFFE4B5), Color(0xFFDAA520)],
    ),
    BeautyFilterItem(
      id: 'silver_sire',
      name: 'Silver Sire',
      tab: 'Make up',
      sub: 'New',
      preset: VideoFilterPreset.cool,
      thumbColors: [Color(0xFFE8E8E8), Color(0xFFA8B5C4)],
    ),
    BeautyFilterItem(
      id: 'rose_kiss',
      name: 'Rose Kiss',
      tab: 'Make up',
      sub: 'Basic',
      preset: VideoFilterPreset.vivid,
      thumbColors: [Color(0xFFFFB6C1), Color(0xFFDC143C)],
    ),
    BeautyFilterItem(
      id: 'nude_matte',
      name: 'Nude Matte',
      tab: 'Make up',
      sub: 'Basic',
      preset: VideoFilterPreset.natural,
      thumbColors: [Color(0xFFE8D5C4), Color(0xFFC4A484)],
    ),

    // ── Filter ───────────────────────────────────────────────────────────
    BeautyFilterItem(
      id: 'cinema',
      name: 'Cinema',
      tab: 'Filter',
      sub: 'New',
      preset: VideoFilterPreset.cool,
      thumbColors: [Color(0xFF4A5568), Color(0xFF2D3748)],
    ),
    BeautyFilterItem(
      id: 'warm',
      name: 'Warm Day',
      tab: 'Filter',
      sub: 'New',
      preset: VideoFilterPreset.bright,
      thumbColors: [Color(0xFFFFE4B5), Color(0xFFFFA07A)],
    ),
    BeautyFilterItem(
      id: 'fresh',
      name: 'Fresh',
      tab: 'Filter',
      sub: 'Basic',
      preset: VideoFilterPreset.vivid,
      thumbColors: [Color(0xFF98D8C8), Color(0xFF6BB3A8)],
    ),
    BeautyFilterItem(
      id: 'film',
      name: 'Film',
      tab: 'Filter',
      sub: 'Basic',
      preset: VideoFilterPreset.cool,
      thumbColors: [Color(0xFFB8A99A), Color(0xFF8B7355)],
    ),
  ];

  static BeautyFilterItem? byName(String? name) {
    if (name == null || name.isEmpty) return null;
    final key = name.toLowerCase();
    for (final item in items) {
      if (item.name.toLowerCase() == key || item.id == key) return item;
    }
    return null;
  }

  static List<String> subsForTab(String tab) {
    final set = <String>{};
    for (final item in items) {
      if (item.tab == tab) set.add(item.sub);
    }
    // Stable order matching the reference sheet.
    const preferred = ['Favorites', 'New', 'Globe Soccer', 'Basic', 'ID'];
    final ordered = [
      for (final s in preferred)
        if (set.contains(s)) s,
      for (final s in set)
        if (!preferred.contains(s)) s,
    ];
    return ordered;
  }
}

/// Result of picking a look in [BeautyFilterSheet].
class BeautyFilterSelection {
  final String name;
  final VideoFilterPreset preset;

  const BeautyFilterSelection({required this.name, required this.preset});
}

/// Bigo-style beauty / makeup / filter picker.
Future<BeautyFilterSelection?> showBeautyFilterSheet({
  required BuildContext context,
  String? selectedName,
  VideoFilterPreset? selectedPreset,
}) {
  return showModalBottomSheet<BeautyFilterSelection>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => BeautyFilterSheet(
      selectedName: selectedName,
      selectedPreset: selectedPreset,
    ),
  );
}

class BeautyFilterSheet extends StatefulWidget {
  final String? selectedName;
  final VideoFilterPreset? selectedPreset;

  const BeautyFilterSheet({
    super.key,
    this.selectedName,
    this.selectedPreset,
  });

  @override
  State<BeautyFilterSheet> createState() => _BeautyFilterSheetState();
}

class _BeautyFilterSheetState extends State<BeautyFilterSheet> {
  late String _tab;
  late String _sub;
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    final match = BeautyFilterCatalog.byName(widget.selectedName);
    if (match != null) {
      _tab = match.tab;
      _sub = match.sub;
      _selectedId = match.id;
    } else {
      _tab = 'Make up';
      final subs = BeautyFilterCatalog.subsForTab(_tab);
      _sub = subs.contains('New') ? 'New' : (subs.isNotEmpty ? subs.first : 'Basic');
      final byPreset = BeautyFilterCatalog.items.where(
        (i) => i.preset == widget.selectedPreset,
      );
      _selectedId = byPreset.isNotEmpty ? byPreset.first.id : null;
    }
  }

  List<BeautyFilterItem> get _visibleItems => BeautyFilterCatalog.items
      .where((i) => i.tab == _tab && i.sub == _sub)
      .toList();

  @override
  Widget build(BuildContext context) {
    final subs = BeautyFilterCatalog.subsForTab(_tab);

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.82),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              _buildTabs(),
              const SizedBox(height: 12),
              _buildSubs(subs),
              const SizedBox(height: 14),
              SizedBox(
                height: 118,
                child: _visibleItems.isEmpty
                    ? const Center(
                        child: Text(
                          'No filters here',
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        itemCount: _visibleItems.length + 1,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return _noneTile();
                          }
                          final item = _visibleItems[index - 1];
                          return _filterTile(item);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          for (final tab in BeautyFilterCatalog.tabs) ...[
            if (tab != BeautyFilterCatalog.tabs.first) const SizedBox(width: 18),
            GestureDetector(
              onTap: () {
                setState(() {
                  _tab = tab;
                  final subs = BeautyFilterCatalog.subsForTab(tab);
                  _sub = subs.contains('New')
                      ? 'New'
                      : (subs.isNotEmpty ? subs.first : _sub);
                });
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (tab == 'Presets') ...[
                    Icon(
                      Icons.auto_awesome,
                      size: 14,
                      color: _tab == tab
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.45),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    tab,
                    style: TextStyle(
                      color: _tab == tab
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.45),
                      fontSize: 15,
                      fontWeight:
                          _tab == tab ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubs(List<String> subs) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          _subChip(
            child: Icon(
              Icons.block,
              size: 18,
              color: _selectedId == null
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.45),
            ),
            selected: _selectedId == null,
            onTap: () {
              Navigator.pop(
                context,
                const BeautyFilterSelection(
                  name: 'Natural',
                  preset: VideoFilterPreset.natural,
                ),
              );
            },
          ),
          const SizedBox(width: 14),
          ...subs.map((sub) {
            final selected = sub == _sub;
            return Padding(
              padding: const EdgeInsets.only(right: 16),
              child: _subChip(
                child: Text(
                  sub,
                  style: TextStyle(
                    color: selected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.45),
                    fontSize: 13,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                selected: selected,
                onTap: () => setState(() => _sub = sub),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _subChip({
    required Widget child,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          child,
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 2,
            width: selected ? 18 : 0,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _noneTile() {
    final selected = _selectedId == null;
    return GestureDetector(
      onTap: () {
        Navigator.pop(
          context,
          const BeautyFilterSelection(
            name: 'Natural',
            preset: VideoFilterPreset.natural,
          ),
        );
      },
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Colors.white.withValues(alpha: 0.08),
                border: Border.all(
                  color: selected
                      ? const Color(0xFF00D4C8)
                      : Colors.white.withValues(alpha: 0.2),
                  width: selected ? 2 : 1,
                ),
              ),
              child: Icon(
                Icons.block,
                color: Colors.white.withValues(alpha: 0.7),
                size: 28,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'None',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterTile(BeautyFilterItem item) {
    final selected = item.id == _selectedId;
    return GestureDetector(
      onTap: () {
        Navigator.pop(
          context,
          BeautyFilterSelection(name: item.name, preset: item.preset),
        );
      },
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: item.thumbColors,
                ),
                border: Border.all(
                  color: selected
                      ? const Color(0xFF00D4C8)
                      : Colors.white.withValues(alpha: 0.15),
                  width: selected ? 2.2 : 1,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: const Color(0xFF00D4C8).withValues(alpha: 0.35),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Soft vignette so tiles feel like portrait previews.
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(13),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.18),
                          Colors.black.withValues(alpha: 0.25),
                        ],
                      ),
                    ),
                  ),
                  Center(
                    child: Icon(
                      Icons.face_retouching_natural,
                      color: Colors.white.withValues(alpha: 0.85),
                      size: 30,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
