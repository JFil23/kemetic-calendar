import 'package:flutter/material.dart';

import '../core/global_side_drawer_metrics.dart';
import '../shared/glossy_text.dart';
import 'inbox_icon_with_badge.dart';

const Key globalMenuBubbleKey = ValueKey<String>('global-menu-bubble');
const Key globalSideDrawerKey = ValueKey<String>('global-side-drawer');
const Key globalSideDrawerScrimKey = ValueKey<String>(
  'global-side-drawer-scrim',
);
const Duration globalSideDrawerTransitionDuration = Duration(milliseconds: 220);
const Curve globalSideDrawerTransitionCurve = Curves.easeOutCubic;

class GlobalSideDrawerItem {
  const GlobalSideDrawerItem({
    required this.label,
    required this.glyph,
    required this.onSelected,
    this.selected = false,
    this.showNotificationDot = false,
    this.glyphSize = 22,
  });

  final String label;
  final String glyph;
  final VoidCallback onSelected;
  final bool selected;
  final bool showNotificationDot;
  final double glyphSize;
}

class GlobalMenuBubble extends StatelessWidget {
  const GlobalMenuBubble({
    super.key = globalMenuBubbleKey,
    required this.visible,
    required this.open,
    required this.onPressed,
  });

  final bool visible;
  final bool open;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: globalMenuBubbleLeft(context),
      bottom: globalMenuBubbleBottom(context),
      width: kGlobalMenuBubbleSize,
      height: kGlobalMenuBubbleSize,
      child: IgnorePointer(
        ignoring: !visible,
        child: ExcludeSemantics(
          excluding: !visible,
          child: AnimatedScale(
            scale: visible ? 1 : 0.92,
            duration: globalSideDrawerTransitionDuration,
            curve: globalSideDrawerTransitionCurve,
            child: AnimatedOpacity(
              opacity: visible ? 1 : 0,
              duration: globalSideDrawerTransitionDuration,
              curve: globalSideDrawerTransitionCurve,
              child: Semantics(
                container: true,
                label: open ? 'Close navigation menu' : 'Open navigation menu',
                button: true,
                onTap: onPressed,
                child: ExcludeSemantics(
                  child: Material(
                    color: const Color(0xF6000000),
                    shape: const CircleBorder(),
                    elevation: 10,
                    shadowColor: const Color(0xB3000000),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onPressed,
                      child: Center(
                        child: InboxUnreadDotOverlay(
                          top: -1,
                          right: -1,
                          size: 7,
                          dotColor: const Color(0xFFFF3B30),
                          borderColor: const Color(0xFF07080A),
                          borderWidth: 1.1,
                          child: const GlossyGlyph(
                            glyph: '𓉹',
                            gradient: goldGloss,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GlobalSideDrawer extends StatelessWidget {
  const GlobalSideDrawer({
    super.key,
    required this.open,
    required this.items,
    required this.onDismiss,
  });

  final bool open;
  final List<GlobalSideDrawerItem> items;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final drawerWidth = globalSideDrawerWidth(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !open,
            child: ExcludeSemantics(
              excluding: !open,
              child: AnimatedOpacity(
                opacity: open ? 1 : 0,
                duration: globalSideDrawerTransitionDuration,
                curve: globalSideDrawerTransitionCurve,
                child: GestureDetector(
                  key: globalSideDrawerScrimKey,
                  behavior: HitTestBehavior.opaque,
                  onTap: onDismiss,
                  child: const ColoredBox(color: Color(0x73000000)),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: drawerWidth,
          child: IgnorePointer(
            ignoring: !open,
            child: ExcludeSemantics(
              excluding: !open,
              child: AnimatedSlide(
                offset: open ? Offset.zero : const Offset(-1, 0),
                duration: globalSideDrawerTransitionDuration,
                curve: globalSideDrawerTransitionCurve,
                child: AnimatedOpacity(
                  opacity: open ? 1 : 0,
                  duration: globalSideDrawerTransitionDuration,
                  curve: globalSideDrawerTransitionCurve,
                  child: Material(
                    key: globalSideDrawerKey,
                    color: const Color(0xF6000000),
                    elevation: 14,
                    shadowColor: const Color(0xB3000000),
                    child: SafeArea(
                      right: false,
                      bottom: false,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 18, 14, 18),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 4),
                        itemBuilder: (context, index) {
                          return _GlobalSideDrawerRow(item: items[index]);
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GlobalSideDrawerRow extends StatelessWidget {
  const _GlobalSideDrawerRow({required this.item});

  final GlobalSideDrawerItem item;

  @override
  Widget build(BuildContext context) {
    final color = item.selected
        ? const Color(0xFFFFE8A3)
        : const Color(0xFFE8E0D6);
    final background = item.selected
        ? const Color(0x24D4AF37)
        : Colors.transparent;
    final borderColor = item.selected
        ? const Color(0x59D4AF37)
        : Colors.white10;
    final glyph = GlossyGlyph(
      glyph: item.glyph,
      gradient: goldGloss,
      size: item.glyphSize,
    );

    return Semantics(
      button: true,
      selected: item.selected,
      label: item.label,
      child: ExcludeSemantics(
        child: InkWell(
          key: ValueKey<String>('global-side-drawer-item-${item.label}'),
          borderRadius: BorderRadius.circular(8),
          onTap: item.onSelected,
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 28,
                  child: Center(
                    child: item.showNotificationDot
                        ? InboxUnreadDotOverlay(
                            top: -2,
                            right: -2,
                            size: 7,
                            dotColor: const Color(0xFFFF3B30),
                            borderColor: const Color(0xFF07080A),
                            borderWidth: 1.1,
                            child: glyph,
                          )
                        : glyph,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 16,
                      fontWeight: item.selected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
