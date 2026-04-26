import 'package:flutter/material.dart';

import '../../data/profile_avatar_glyphs.dart';
import '../../widgets/profile_avatar.dart';
import '../../shared/glossy_text.dart';

Future<List<String>?> showProfileGlyphAvatarComposer(
  BuildContext context, {
  required String displayName,
  List<String> initialGlyphIds = const [],
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF000000),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      minChildSize: 0.72,
      maxChildSize: 0.97,
      builder: (context, scrollController) => _ProfileGlyphAvatarComposerSheet(
        displayName: displayName,
        initialGlyphIds: initialGlyphIds,
        scrollController: scrollController,
      ),
    ),
  );
}

class _ProfileGlyphAvatarComposerSheet extends StatefulWidget {
  const _ProfileGlyphAvatarComposerSheet({
    required this.displayName,
    required this.initialGlyphIds,
    required this.scrollController,
  });

  final String displayName;
  final List<String> initialGlyphIds;
  final ScrollController scrollController;

  @override
  State<_ProfileGlyphAvatarComposerSheet> createState() =>
      _ProfileGlyphAvatarComposerSheetState();
}

class _ProfileGlyphAvatarComposerSheetState
    extends State<_ProfileGlyphAvatarComposerSheet> {
  late List<String> _selectedGlyphIds;

  @override
  void initState() {
    super.initState();
    _selectedGlyphIds = normalizeProfileAvatarGlyphIds(widget.initialGlyphIds);
  }

  void _addGlyph(String id) {
    setState(() {
      if (_selectedGlyphIds.length >= kMaxProfileAvatarGlyphs) {
        return;
      }
      _selectedGlyphIds = [..._selectedGlyphIds, id];
    });
  }

  void _removeGlyphAt(int index) {
    if (index < 0 || index >= _selectedGlyphIds.length) return;
    setState(() {
      _selectedGlyphIds = [
        ..._selectedGlyphIds.take(index),
        ..._selectedGlyphIds.skip(index + 1),
      ];
    });
  }

  void _applyPreset(ProfileGlyphPhrasePreset preset) {
    setState(() {
      _selectedGlyphIds = normalizeProfileAvatarGlyphIds(preset.glyphIds);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final phraseGlyphs = profileGlyphPhraseGlyphs(_selectedGlyphIds);
    final phraseMeaning = profileGlyphPhraseMeaning(_selectedGlyphIds);
    final avatarHeaderExtent = phraseMeaning.isNotEmpty ? 224.0 : 176.0;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: CustomScrollView(
                controller: widget.scrollController,
                slivers: [
                  SliverToBoxAdapter(child: _buildSheetIntro()),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _PinnedComposerHeaderDelegate(
                      extent: avatarHeaderExtent,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildAvatarPreviewCard(
                          phraseGlyphs: phraseGlyphs,
                          phraseMeaning: phraseMeaning,
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(child: _buildSelectedGlyphsSection()),
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                  SliverToBoxAdapter(child: _buildStarterPhrasesSection()),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  SliverToBoxAdapter(
                    child: _buildCategorySection(
                      title: 'Essential ideograms',
                      subtitle: 'Core iconic glyphs for launch.',
                      tiles: profileGlyphTilesForCategory(
                        ProfileGlyphCategory.essential,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 18)),
                  SliverToBoxAdapter(
                    child: _buildCategorySection(
                      title: 'Sacred emblems',
                      subtitle: 'Launch emblems for Maat and Aset.',
                      tiles: profileGlyphTilesForCategory(
                        ProfileGlyphCategory.divinity,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 18)),
                  SliverToBoxAdapter(
                    child: _buildCategorySection(
                      title: 'Phrase glyphs',
                      subtitle:
                          'Compact spellings for short phrase parts such as I, me, my, receive, increase, and pure.',
                      tiles: profileGlyphTilesForCategory(
                        ProfileGlyphCategory.phrase,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 18)),
                  SliverToBoxAdapter(
                    child: _buildCategorySection(
                      title: 'Connector signs',
                      subtitle:
                          'Common bridge signs and sound helpers drawn from Allen’s uniliterals and core prepositions.',
                      tiles: profileGlyphTilesForCategory(
                        ProfileGlyphCategory.helper,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _selectedGlyphIds.isEmpty
                        ? null
                        : () => setState(() => _selectedGlyphIds = const []),
                    child: const Text('Clear'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: KemeticGold.base,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () =>
                        Navigator.of(context).pop(_selectedGlyphIds),
                    child: const Text('Apply Glyph Avatar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetIntro() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Build Glyph Avatar',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Combine up to $kMaxProfileAvatarGlyphs medu neter tiles. The key uses compact dictionary-backed clusters plus a small helper-sign set for connectors and sound support.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 13,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }

  Widget _buildAvatarPreviewCard({
    required String phraseGlyphs,
    required String phraseMeaning,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KemeticGold.base.withValues(alpha: 0.28)),
      ),
      child: Column(
        children: [
          ProfileAvatar(
            radius: 44,
            displayName: widget.displayName,
            avatarGlyphIds: _selectedGlyphIds,
            borderColor: KemeticGold.base,
            borderWidth: 1.6,
          ),
          const SizedBox(height: 12),
          Text(
            phraseGlyphs.isEmpty
                ? 'Tap tiles to add them in phrase order.'
                : phraseGlyphs,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: KemeticGold.base,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'GentiumPlus',
              fontFamilyFallback: [
                'Noto Sans Egyptian Hieroglyphs',
                'Apple Symbols',
                'Segoe UI Symbol',
                'Arial Unicode MS',
                'NotoSans',
              ],
            ),
          ),
          if (phraseMeaning.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              phraseMeaning,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectedGlyphsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Selected glyphs',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _selectedGlyphIds.isEmpty
              ? [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D0D0F),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Text(
                      'No glyphs selected yet.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ]
              : [
                  for (var index = 0; index < _selectedGlyphIds.length; index++)
                    InputChip(
                      label: Text(
                        '${kProfileGlyphTileById[_selectedGlyphIds[index]]?.glyph ?? _selectedGlyphIds[index]}  ${kProfileGlyphTileById[_selectedGlyphIds[index]]?.display ?? _selectedGlyphIds[index]}',
                      ),
                      labelStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      backgroundColor: const Color(0xFF0D0D0F),
                      side: BorderSide(
                        color: KemeticGold.base.withValues(alpha: 0.28),
                      ),
                      onDeleted: () => _removeGlyphAt(index),
                    ),
                ],
        ),
      ],
    );
  }

  Widget _buildStarterPhrasesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Starter phrases',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: kProfileGlyphPhrasePresets.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final preset = kProfileGlyphPhrasePresets[index];
              return ActionChip(
                label: Text(preset.label),
                backgroundColor: const Color(0xFF151518),
                side: BorderSide(
                  color: KemeticGold.base.withValues(alpha: 0.24),
                ),
                labelStyle: const TextStyle(color: Colors.white),
                onPressed: () => _applyPreset(preset),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySection({
    required String title,
    required String subtitle,
    required List<ProfileGlyphTile> tiles,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.64),
            fontSize: 13,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: tiles.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.55,
          ),
          itemBuilder: (context, index) {
            final tile = tiles[index];
            final selectionCount = _selectedGlyphIds
                .where((glyphId) => glyphId == tile.id)
                .length;
            final isSelected = selectionCount > 0;
            final isDisabled =
                _selectedGlyphIds.length >= kMaxProfileAvatarGlyphs;

            return InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: isDisabled ? null : () => _addGlyph(tile.id),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? KemeticGold.base.withValues(alpha: 0.16)
                      : const Color(0xFF0D0D0F),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? KemeticGold.base
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            tile.glyph,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: KemeticGold.base,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'GentiumPlus',
                              fontFamilyFallback: [
                                'Noto Sans Egyptian Hieroglyphs',
                                'Apple Symbols',
                                'Segoe UI Symbol',
                                'Arial Unicode MS',
                                'NotoSans',
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            tile.display,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tile.avatarMeaning,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      isSelected ? Icons.layers : Icons.add_circle_outline,
                      color: isSelected
                          ? KemeticGold.base
                          : Colors.white.withValues(
                              alpha: isDisabled ? 0.18 : 0.44,
                            ),
                    ),
                    if (selectionCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: KemeticGold.base.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: KemeticGold.base.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          'x$selectionCount',
                          style: const TextStyle(
                            color: KemeticGold.base,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _PinnedComposerHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _PinnedComposerHeaderDelegate({
    required this.extent,
    required this.child,
  });

  final double extent;
  final Widget child;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(color: const Color(0xFF000000), child: child);
  }

  @override
  bool shouldRebuild(covariant _PinnedComposerHeaderDelegate oldDelegate) {
    return oldDelegate.extent != extent || oldDelegate.child != child;
  }
}
