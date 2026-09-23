import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/flow_post_model.dart';
import '../../utils/detail_sanitizer.dart';
import '../../widgets/keyboard_aware.dart';
import '../sharing/share_flow_sheet.dart';
import 'package:mobile/shared/glossy_text.dart';

enum _FlowPostShareChoice { copyLink, inbox, elsewhere }

abstract final class FlowPostShareActions {
  static Uri linkFor(FlowPost post) {
    final current = Uri.base;
    final base = current.scheme == 'http' || current.scheme == 'https'
        ? current.replace(path: '/', query: null, fragment: null)
        : Uri.parse('https://maat.app/');
    return base.resolve('flow-post/${Uri.encodeComponent(post.id)}');
  }

  static String shareTextFor(FlowPost post) {
    final caption = post.sharedNote?.trim();
    final title = cleanFlowTitle(post.name);
    return <String>[
      if (caption != null && caption.isNotEmpty) caption,
      title.isEmpty ? 'A flow from Hꜣw' : title,
      linkFor(post).toString(),
    ].join('\n\n');
  }

  static Future<void> open(BuildContext context, FlowPost post) async {
    final choice = await showModalBottomSheet<_FlowPostShareChoice>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        top: false,
        child: Material(
          color: const Color(0xFF0A0907),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.26),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 14),
                ListTile(
                  leading: KemeticGold.icon(Icons.link_rounded),
                  title: const Text(
                    'Copy link',
                    style: TextStyle(color: Color(0xFFF2ECE0)),
                  ),
                  onTap: () =>
                      Navigator.of(context).pop(_FlowPostShareChoice.copyLink),
                ),
                ListTile(
                  leading: KemeticGold.icon(Icons.inbox_outlined),
                  title: const Text(
                    'Send in Inbox',
                    style: TextStyle(color: Color(0xFFF2ECE0)),
                  ),
                  onTap: () =>
                      Navigator.of(context).pop(_FlowPostShareChoice.inbox),
                ),
                ListTile(
                  leading: KemeticGold.icon(Icons.ios_share_rounded),
                  title: const Text(
                    'Share elsewhere',
                    style: TextStyle(color: Color(0xFFF2ECE0)),
                  ),
                  onTap: () =>
                      Navigator.of(context).pop(_FlowPostShareChoice.elsewhere),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (choice == null || !context.mounted) return;

    final text = shareTextFor(post);
    switch (choice) {
      case _FlowPostShareChoice.copyLink:
        await Clipboard.setData(ClipboardData(text: linkFor(post).toString()));
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Flow post link copied')));
        return;
      case _FlowPostShareChoice.inbox:
        await showEditableModalBottomSheet<bool>(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (context) => ShareFlowSheet(
            flowId: null,
            flowTitle: cleanFlowTitle(post.name),
            noteShareText: text,
            sendTextInInbox: true,
          ),
        );
        return;
      case _FlowPostShareChoice.elsewhere:
        await Share.share(text);
        return;
    }
  }
}
