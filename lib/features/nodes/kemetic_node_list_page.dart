import 'package:flutter/material.dart';
import '../../shared/glossy_text.dart';
import 'kemetic_node_library.dart';
import 'kemetic_node_model.dart';
import 'kemetic_node_reader_page.dart';
import 'widgets.dart';

class KemeticNodeListPage extends StatelessWidget {
  const KemeticNodeListPage({super.key});

  String _snippet(KemeticNode node) {
    final collapsed = node.body
        .replaceAll('\n', ' ')
        .replaceAll('  ', ' ')
        .trim();
    if (collapsed.length <= 140) return collapsed;
    return '${collapsed.substring(0, 140).trimRight()}…';
  }

  @override
  Widget build(BuildContext context) {
    final nodes = KemeticNodeLibrary.nodes;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 70,
        automaticallyImplyLeading: false,
        leadingWidth: 64,
        leading: GlyphBackButton(
          showLabel: false,
          showCloseIcon: true,
          onTap: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            KemeticGold.text(
              'sꜣt',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                fontFamily: 'GentiumPlus',
                fontFamilyFallback: [
                  'NotoSans',
                  'Roboto',
                  'Arial',
                  'sans-serif',
                ],
              ),
              overflow: TextOverflow.clip,
            ),
            const SizedBox(height: 2),
            ShaderMask(
              shaderCallback: (Rect bounds) =>
                  KemeticGold.gloss.createShader(bounds),
              blendMode: BlendMode.srcIn,
              child: const Text(
                '𓋴 𓄿 𓏏 𓂋',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white,
                  fontFamily: 'GentiumPlus',
                  fontFamilyFallback: [
                    'NotoSans',
                    'Roboto',
                    'Arial',
                    'sans-serif',
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemBuilder: (context, index) {
            final node = nodes[index];
            return _NodeCard(
              node: node,
              subtitle: _snippet(node),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => KemeticNodeReaderPage(node: node),
                  ),
                );
              },
            );
          },
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemCount: nodes.length,
        ),
      ),
    );
  }
}

class _NodeCard extends StatelessWidget {
  final KemeticNode node;
  final String subtitle;
  final VoidCallback onTap;

  const _NodeCard({
    required this.node,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final aliasChips = node.aliases.where((a) => a.isNotEmpty).toList();
    return Material(
      color: Colors.white.withOpacity(0.04),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        splashColor: KemeticGold.base.withOpacity(0.05),
        highlightColor: KemeticGold.base.withOpacity(0.08),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                  color: Colors.white.withOpacity(0.04),
                ),
                alignment: Alignment.center,
                child: ShaderMask(
                  shaderCallback: (Rect bounds) =>
                      KemeticGold.gloss.createShader(bounds),
                  blendMode: BlendMode.srcIn,
                  child: Text(
                    node.glyph,
                    style: const TextStyle(
                      fontSize: 26,
                      color: Colors.white,
                      fontFamily: 'GentiumPlus',
                      fontFamilyFallback: [
                        'NotoSans',
                        'Roboto',
                        'Arial',
                        'sans-serif',
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    KemeticGold.text(
                      node.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (aliasChips.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: aliasChips
                            .map(
                              (alias) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: Text(
                                  alias,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13.5,
                        height: 1.4,
                        fontFamily: 'GentiumPlus',
                        fontFamilyFallback: [
                          'NotoSans',
                          'Roboto',
                          'Arial',
                          'sans-serif',
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              KemeticGold.icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
