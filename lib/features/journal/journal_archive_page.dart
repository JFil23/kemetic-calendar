// lib/features/journal/journal_archive_page.dart
// Journal Archive - Single page with list/detail views

import 'package:flutter/material.dart';
import '../../data/journal_repo.dart';
import 'journal_controller.dart';
import 'journal_v2_document_model.dart';
import 'journal_v2_rich_text.dart';
import 'journal_badge_utils.dart';
import 'journal_event_badge.dart';
import 'dart:convert';

class JournalArchivePage extends StatefulWidget {
  final JournalRepo repo;
  final JournalController controller;
  final bool isPortrait;
  final VoidCallback onClose;

  const JournalArchivePage({
    super.key,
    required this.repo,
    required this.controller,
    required this.isPortrait,
    required this.onClose,
  });

  @override
  State<JournalArchivePage> createState() => _JournalArchivePageState();
}

class _JournalArchivePageState extends State<JournalArchivePage> {
  List<JournalEntry> _entries = [];
  bool _loading = true;
  JournalEntry? _selectedEntry;
  bool _isEditing = false;
  late TextEditingController _editController;
  JournalDocument? _editingDocument;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController();
    _loadEntries();
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  Future<void> _loadEntries() async {
    setState(() => _loading = true);
    
    try {
      final entries = await widget.repo.listRecent(days: 90);
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _openEntry(JournalEntry entry) {
    final doc = _entryToDocument(entry);

    setState(() {
      _selectedEntry = entry;
      _isEditing = false;
      _editingDocument = doc;
      _editController.text = doc.toPlainText();
    });
  }

  void _closeEntry() {
    setState(() {
      _selectedEntry = null;
      _isEditing = false;
    });
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
    });
  }

  void _saveEntry() async {
    if (_selectedEntry == null) return;
    
    try {
      // Save the edited document with badges + drawing
      JournalDocument doc = _editingDocument ??
          JournalDocument.fromPlainText(_editController.text);

      final blocks = List<JournalBlock>.from(doc.blocks);

      // Ensure paragraph block exists
      int paragraphIndex = blocks.indexWhere((b) => b is ParagraphBlock);
      if (paragraphIndex == -1) {
        blocks.insert(
          0,
          ParagraphBlock(
            id: 'p-${_selectedEntry!.gregDate.millisecondsSinceEpoch}',
            ops: [TextOp(insert: _editController.text.isEmpty ? '\n' : _editController.text)],
          ),
        );
      }

      doc = JournalDocument(version: doc.version, blocks: blocks, meta: doc.meta);
      doc = JournalBadgeUtils.normalizeDocument(doc);

      final body = jsonEncode(doc.toJson());

      await widget.repo.upsert(
        localDate: _selectedEntry!.gregDate,
        body: body,
      );
      
      setState(() {
        _isEditing = false;
      });
      
      // Reload entries to reflect changes
      await _loadEntries();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Entry saved'),
          backgroundColor: Color(0xFFD4AF37),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _getEntryText(JournalEntry entry) {
    try {
      final doc = _entryToDocument(entry);
      return doc.toPlainText();
    } catch (e) {
      return JournalBadgeUtils.stripBadgesFromPlainText(entry.body);
    }
  }

  JournalDocument _entryToDocument(JournalEntry entry) {
    JournalDocument doc;
    try {
      if (entry.body.startsWith('{') && entry.body.contains('"version"')) {
        final docJson = jsonDecode(entry.body) as Map<String, dynamic>;
        doc = JournalDocument.fromJson(docJson);
      } else {
        doc = JournalDocument.fromPlainText(entry.body);
      }
    } catch (_) {
      // fall through to plain text
      doc = JournalDocument(
        version: kJournalDocVersion,
        blocks: [
          ParagraphBlock(
            id: 'p-${DateTime.now().millisecondsSinceEpoch}',
            ops: [TextOp(insert: entry.body.isEmpty ? '\n' : entry.body)],
          ),
        ],
        meta: const {},
      );
    }

    return JournalBadgeUtils.normalizeDocument(doc);
  }

  String _getPreviewText(JournalEntry entry) {
    final text = _getEntryText(entry);
    if (text.length <= 80) return text;
    return '${text.substring(0, 80)}...';
  }

  int _getActualTextLength(JournalEntry entry) {
    return _getEntryText(entry).length;
  }

  String _getDayOfWeek(DateTime date) {
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    return days[date.weekday - 1];
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            _selectedEntry != null ? Icons.arrow_back : Icons.close,
            color: const Color(0xFFD4AF37),
          ),
          onPressed: _selectedEntry != null ? _closeEntry : widget.onClose,
        ),
        title: Text(
          _selectedEntry != null ? 'Journal Entry' : 'Journal Archive',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: _selectedEntry != null ? [
          if (!_isEditing)
            TextButton(
              onPressed: _startEditing,
              child: const Text(
                'Edit',
                style: TextStyle(
                  color: Color(0xFFD4AF37),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveEntry,
              child: const Text(
                'Save',
                style: TextStyle(
                  color: Color(0xFFD4AF37),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ] : null,
      ),
      body: _selectedEntry != null ? _buildEntryDetail() : _buildEntryList(),
    );
  }

  Widget _buildEntryList() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFD4AF37),
        ),
      );
    }

    if (_entries.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.book_outlined,
              size: 64,
              color: Color(0xFF666666),
            ),
            SizedBox(height: 16),
            Text(
              'No journal entries yet',
              style: TextStyle(
                color: Color(0xFF666666),
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Start writing to see your entries here',
              style: TextStyle(
                color: Color(0xFF666666),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _entries.length,
      separatorBuilder: (context, index) => const Divider(
        color: Color(0xFF333333),
        height: 1,
      ),
      itemBuilder: (context, index) {
        final entry = _entries[index];
        return _buildEntryCard(entry);
      },
    );
  }

  Widget _buildEntryCard(JournalEntry entry) {
    final date = entry.gregDate;
    final dayOfWeek = _getDayOfWeek(date);
    final monthName = _getMonthName(date.month);
    final previewText = _getPreviewText(entry);
    final charCount = _getActualTextLength(entry);

    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red.withOpacity(0.8),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) async {
        await widget.repo.deleteByDate(entry.gregDate);
        setState(() {
          _entries.remove(entry);
          if (_selectedEntry?.id == entry.id) {
            _selectedEntry = null;
            _isEditing = false;
          }
        });
      },
      child: InkWell(
        onTap: () {
          _openEntry(entry);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date header
                    Text(
                      '$dayOfWeek, $monthName ${date.day}',
                      style: const TextStyle(
                        color: Color(0xFFD4AF37),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    
                    // Preview text
                    Text(
                      previewText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    
                    // Character count
                    Text(
                      '$charCount characters',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Icon(
                Icons.chevron_right,
                color: Colors.white.withOpacity(0.3),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEntryDetail() {
    if (_selectedEntry == null) return const SizedBox.shrink();
    
    final entry = _selectedEntry!;
    final date = entry.gregDate;
    final dayOfWeek = _getDayOfWeek(date);
    final monthName = _getMonthName(date.month);
    final entryText = _getEntryText(entry);
    final entryDoc = _entryToDocument(entry);

    return Column(
      children: [
        // Date header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Color(0xFF0D0D0F),
            border: Border(
              bottom: BorderSide(color: Color(0xFF333333), width: 1),
            ),
          ),
          child: Text(
            '$dayOfWeek, $monthName ${date.day}',
            style: const TextStyle(
              color: Color(0xFFD4AF37),
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        
        // Content
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _isEditing
                ? _buildEditView()
                : _buildReadView(entryDoc),
          ),
        ),
      ],
    );
  }

  Widget _buildReadView(JournalDocument doc) {
    final paragraphs = doc.blocks.whereType<ParagraphBlock>();
    final baseStyle = const TextStyle(
      color: Colors.white,
      fontSize: 16,
      height: 1.5,
    );

    final badges = JournalBadgeUtils.tokensFromDocument(doc);
    final spans = <InlineSpan>[];
    if (paragraphs.isNotEmpty) {
      for (final p in paragraphs) {
        for (final op in p.ops) {
          spans.addAll(JournalBadgeSpanBuilder.build(
            text: op.insert,
            style: baseStyle,
            expansionState: null,
            onToggle: null,
            compact: false,
            renderBadgesInline: false,
          ));
        }
        spans.add(const TextSpan(text: '\n'));
      }
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(text: TextSpan(style: baseStyle, children: spans)),
          const SizedBox(height: 16),
          _buildBadgeSection(badges),
        ],
      ),
    );
  }

  Widget _buildBadgeSection(List<EventBadgeToken> badges) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        border: Border.all(color: const Color(0xFF333333), width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: badges.isEmpty
          ? const Text(
              'No badges for this entry',
              style: TextStyle(color: Color(0xFF666666)),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: badges.map((token) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: EventBadgeWidget(token: token),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildEditView() {
    // Use current document paragraph as initial block
    ParagraphBlock initialBlock;
    if (_editingDocument != null) {
      final paragraphs = _editingDocument!.blocks.whereType<ParagraphBlock>();
      if (paragraphs.isNotEmpty) {
        initialBlock = paragraphs.first;
      } else {
        initialBlock = ParagraphBlock(
          id: 'p-${DateTime.now().millisecondsSinceEpoch}',
          ops: [TextOp(insert: _editController.text.isEmpty ? '\n' : _editController.text)],
        );
      }
    } else {
      initialBlock = ParagraphBlock(
        id: 'p-${DateTime.now().millisecondsSinceEpoch}',
        ops: [TextOp(insert: _editController.text.isEmpty ? '\n' : _editController.text)],
      );
    }

    final badges = _editingDocument != null
        ? JournalBadgeUtils.tokensFromDocument(_editingDocument!)
        : <EventBadgeToken>[];

    return Column(
      children: [
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: RichTextEditor(
                  initialBlock: initialBlock,
                  onChanged: (block) {
                    setState(() {
                      final doc = _editingDocument ?? _entryToDocument(_selectedEntry!);
                      final blocks = List<JournalBlock>.from(doc.blocks);
                      final pIdx = blocks.indexWhere((b) => b is ParagraphBlock);
                      if (pIdx >= 0) {
                        blocks[pIdx] = block;
                      } else {
                        blocks.insert(0, block);
                      }
                      _editingDocument = JournalDocument(
                        version: doc.version,
                        blocks: blocks,
                        meta: doc.meta,
                      );
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildBadgeSection(badges),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isEditing = false;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[800],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _saveEntry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
