import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/journal_repo.dart';
import 'journal_skin_tokens.dart';
import 'journal_controller.dart';

/// One recovery action for every Journal entry, including decan contributions.
/// Recovery records are private account receipts, independent of device cache.
class JournalRecoveryAction extends StatelessWidget {
  const JournalRecoveryAction({super.key, required this.controller});
  final JournalController controller;
  @override
  Widget build(BuildContext context) {
    final conflict = controller.lastSyncError;
    if (conflict is! JournalRevisionConflict &&
        controller.recoveryDrafts.isEmpty) {
      return const SizedBox.shrink();
    }
    return TextButton(
      onPressed: () => showDialog<void>(
        context: context,
        builder: (_) => _RecoveryDialog(controller: controller),
      ),
      child: Text(
        conflict is JournalRevisionConflict
            ? 'Review both Journal versions'
            : 'Other saved drafts',
        style: JournalSkinTokens.savedLineStyle.copyWith(
          color: JournalSkinTokens.gold,
        ),
      ),
    );
  }
}

class _RecoveryDialog extends StatefulWidget {
  const _RecoveryDialog({required this.controller});
  final JournalController controller;
  @override
  State<_RecoveryDialog> createState() => _RecoveryDialogState();
}

class _RecoveryDialogState extends State<_RecoveryDialog> {
  StreamSubscription<String?>? _account;
  bool _busy = false;
  String? _notice;
  late final String? _identity = widget.controller.accountIdentity;
  @override
  void initState() {
    super.initState();
    _account = widget.controller.accountChanges.listen((id) {
      if (id != _identity && mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _account?.cancel();
    super.dispose();
  }

  Future<void> _resolve(
    JournalRevisionConflict conflict,
    bool keepDraft,
  ) async {
    setState(() => _busy = true);
    final ok = await widget.controller.resolveConflict(
      conflict,
      keepDraft: keepDraft,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _busy = false;
      _notice =
          'Could not finish saving. Both versions are kept. Review the current saved version and try again.';
    });
  }

  Widget _action(
    String label, {
    VoidCallback? onPressed,
    bool primary = false,
    bool busy = false,
  }) {
    final child = busy
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(label);
    return primary
        ? OutlinedButton(onPressed: onPressed, child: child)
        : TextButton(onPressed: onPressed, child: child);
  }

  Widget _words(String label, String body) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: JournalSkinTokens.savedLineStyle),
      const SizedBox(height: 10),
      SelectableText(
        body.trim().isEmpty ? 'No writing in this version.' : body,
        style: JournalSkinTokens.entryBodyStyle.copyWith(fontSize: 21),
      ),
      const SizedBox(height: 24),
    ],
  );
  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final conflict = c.lastSyncError;
    return Dialog(
      backgroundColor: JournalSkinTokens.black,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 620),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Your writing is kept',
                style: JournalSkinTokens.entryBodyStyle.copyWith(fontSize: 30),
              ),
              const SizedBox(height: 20),
              if (conflict is JournalRevisionConflict) ...[
                _words(
                  'Saved in Journal',
                  c
                      .documentFromBody(conflict.serverEntry?.body ?? '')
                      .toPlainText(),
                ),
                _words('Your draft', c.currentDocument?.toPlainText() ?? ''),
                Text(
                  'Choose the whole version to keep. Formatting and drawings stay with that version.',
                  style: JournalSkinTokens.savedLineStyle,
                ),
                _action(
                  'Keep this draft in Journal',
                  onPressed: _busy
                      ? null
                      : () => unawaited(_resolve(conflict, true)),
                  primary: true,
                  busy: _busy,
                ),
                _action(
                  'Use the saved version',
                  onPressed: _busy
                      ? null
                      : () => unawaited(_resolve(conflict, false)),
                ),
              ] else ...[
                Text(
                  'These drafts were preserved when another edit reached Journal first. Opening one lets you compare both versions before saving.',
                  style: JournalSkinTokens.savedLineStyle,
                ),
                for (final draft in c.recoveryDrafts) ...[
                  const SizedBox(height: 22),
                  _words(
                    'Preserved draft',
                    '${draft.characterCount} characters${draft.createdAt == null ? '' : ' · ${draft.createdAt!.toLocal().toString().substring(0, 16)}'}',
                  ),
                  _action(
                    'Compare this draft',
                    onPressed: _busy
                        ? null
                        : () async {
                            setState(() => _busy = true);
                            try {
                              await c.chooseRecoveredDraft(draft);
                            } catch (_) {
                              _notice =
                                  'Could not load the current version. This draft is still kept.';
                            }
                            if (mounted) setState(() => _busy = false);
                          },
                  ),
                ],
              ],
              if (_notice != null)
                Text(_notice!, style: JournalSkinTokens.savedLineStyle),
              _action(
                'Close',
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
