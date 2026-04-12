import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/journal_repo.dart';
import '../../shared/glossy_text.dart';
import '../../data/insight_link_model.dart';
import '../../data/insight_link_repo.dart';
import '../../widgets/insight_link_text.dart';
import '../nodes/kemetic_node_library.dart';
import '../nodes/kemetic_node_reader_page.dart';

class JournalEntryDetailPage extends StatefulWidget {
  final String entryId;
  const JournalEntryDetailPage({super.key, required this.entryId});

  @override
  State<JournalEntryDetailPage> createState() => _JournalEntryDetailPageState();
}

class _JournalEntryDetailPageState extends State<JournalEntryDetailPage> {
  final _repo = JournalRepo(Supabase.instance.client);
  final _insightRepo = InsightLinkRepo();
  JournalEntry? _entry;
  List<InsightLink> _links = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? 'local';
    final entry = await _repo.getById(widget.entryId);
    final links = await _insightRepo.fetchLinks(userId);
    if (!mounted) return;
    setState(() {
      _entry = entry;
      if (entry != null) {
        final sourceId =
            'journal-${entry.gregDate.year}-${entry.gregDate.month.toString().padLeft(2, '0')}-${entry.gregDate.day.toString().padLeft(2, '0')}';
        _links = links
            .where((l) =>
                l.sourceType == InsightSourceType.journalEntry &&
                l.sourceId == sourceId)
            .toList();
      } else {
        _links = [];
      }
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: KemeticGold.icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
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
                  padding: const EdgeInsets.all(16.0),
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
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => KemeticNodeReaderPage(node: node),
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
