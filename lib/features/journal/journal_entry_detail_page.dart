import '../../data/account_operation_fence.dart';
import 'journal_controller.dart';
import 'journal_archive_page.dart';
import '../../data/warm_state/warm_snapshot_store.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/navigation_fallback.dart';
import '../../data/journal_repo.dart';
import '../../shared/glossy_text.dart';
import '../../data/insight_link_model.dart';
import '../../data/insight_link_repo.dart';
import '../../widgets/insight_link_text.dart';
import '../nodes/kemetic_node_library.dart';

class JournalEntryDetailPage extends StatefulWidget {
  final String entryId;
  const JournalEntryDetailPage({super.key, required this.entryId});

  @override
  State<JournalEntryDetailPage> createState() => _JournalEntryDetailPageState();
}

class _JournalEntryDetailPageState extends State<JournalEntryDetailPage> {
  final _repo = JournalRepo(Supabase.instance.client);
  final _insightRepo = InsightLinkRepo();
  late final _controller = JournalController(
    Supabase.instance.client,
    repository: _repo,
  );
  JournalEntry? _entry;
  List<InsightLink> _links = [];
  bool _loading = true;
  late final _account = AccountOperationFence(Supabase.instance.client);
  StreamSubscription<AuthState>? _auth;

  @override
  void initState() {
    super.initState();
    _auth = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      if (mounted && !_account.isCurrent)
        setState(() {
          _entry = null;
          _links = [];
          _loading = false;
        });
    });
    _load();
  }

  Future<void> _load() async {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? 'local';
    if (_entry == null) {
      try {
        final local = await _repo.getById(widget.entryId, cachedOnly: true);
        if (!mounted || !_account.isCurrent) return;
        if (local != null) {
          await _controller.loadEntry(local);
          setState(() {
            _entry = local;
            _loading = false;
          });
        }
      } catch (_) {}
    }
    JournalEntry? entry;
    try {
      entry = await _repo.getById(widget.entryId, strict: true);
    } catch (error) {
      if (mounted && _account.isCurrent) {
        setState(() {
          if (error is WarmAccessDenied) {
            _entry = null;
          }
          _loading = false;
        });
      }
      return;
    }
    if (entry != null) await _controller.loadEntry(entry);
    if (!mounted || !_account.isCurrent) return;
    setState(() {
      _entry = entry;
      _loading = false;
    });
    final links = await _insightRepo.fetchLinks(userId);
    if (!mounted || !_account.isCurrent) return;
    setState(() {
      _entry = entry;
      if (entry != null) {
        final sourceId =
            'journal-${entry.gregDate.year}-${entry.gregDate.month.toString().padLeft(2, '0')}-${entry.gregDate.day.toString().padLeft(2, '0')}';
        _links = links
            .where(
              (l) =>
                  l.sourceType == InsightSourceType.journalEntry &&
                  l.sourceId == sourceId,
            )
            .toList();
      } else {
        _links = [];
      }
      _loading = false;
    });
  }

  @override
  void dispose() {
    _auth?.cancel();
    _account.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_account.isCurrent &&
        _entry != null &&
        _controller.currentDocument?.blocks.any(
              (b) => b.id.startsWith('decan_reflection:'),
            ) ==
            true) {
      return JournalArchivePage(
        repo: _repo,
        controller: _controller,
        isPortrait: MediaQuery.orientationOf(context) == Orientation.portrait,
        onClose: () => popOrGo(context, '/journal'),
        initialEntry: _entry,
      );
    }
    const bodyBottomPadding = 16.0;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: KemeticGold.icon(Icons.arrow_back),
          onPressed: () => popOrGo(context, '/journal'),
        ),
        title: const Text(
          'Journal Entry',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(KemeticGold.base),
              ),
            )
          : _entry == null
          ? const Center(
              child: Text(
                'Entry not found.',
                style: TextStyle(color: Colors.white70),
              ),
            )
          : Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, bodyBottomPadding),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.5,
                  ),
                  children: InsightLinkSpanBuilder.build(
                    text: _entry!.body,
                    links: _links,
                    baseStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.5,
                    ),
                    onTap: (link) {
                      final node = KemeticNodeLibrary.resolve(link.targetId);
                      if (node == null) return;
                      unawaited(
                        openDetailRoute<void>(
                          context,
                          '/nodes/${Uri.encodeComponent(node.id)}',
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
    );
  }
}
