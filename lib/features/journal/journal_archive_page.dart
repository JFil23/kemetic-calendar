// lib/features/journal/journal_archive_page.dart
// Journal Archive - Single page with list/detail views

import 'package:flutter/material.dart';
import '../../data/journal_repo.dart';
import 'journal_controller.dart';
import 'journal_v2_document_model.dart';
import 'journal_v2_drawing.dart';
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
  DrawingBlock? _editDrawingBlock;

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
    final drawingBlocks = doc.blocks.whereType<DrawingBlock>();

    setState(() {
      _selectedEntry = entry;
      _isEditing = false;
      _editingDocument = doc;
      _editDrawingBlock = drawingBlocks.isNotEmpty
          ? drawingBlocks.first
          : DrawingBlock(
              id: 'draw-${DateTime.now().millisecondsSinceEpoch}',
              strokes: [],
            );
      _editController.text = _getEntryText(entry);
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
      // Save the edited text + drawing as a document
      final paragraph = ParagraphBlock(
        id: 'p-${_selectedEntry!.gregDate.millisecondsSinceEpoch}',
        ops: [
          TextOp(insert: _editController.text.isEmpty ? '\n' : _editController.text),
        ],
      );

      final blocks = <JournalBlock>[
        paragraph,
        if (_editDrawingBlock != null) _editDrawingBlock!,
      ];

      final doc = JournalDocument(
        version: kJournalDocVersion,
        blocks: blocks,
        meta: const {},
      );

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
      // Check if it's a V2 document
      if (entry.body.startsWith('{') && entry.body.contains('"version"')) {
        final docJson = jsonDecode(entry.body) as Map<String, dynamic>;
        final doc = JournalDocument.fromJson(docJson);
        return doc.toPlainText();
      } else {
        // Plain text
        return entry.body;
      }
    } catch (e) {
      return entry.body;
    }
  }

  JournalDocument _entryToDocument(JournalEntry entry) {
    try {
      if (entry.body.startsWith('{') && entry.body.contains('"version"')) {
        final docJson = jsonDecode(entry.body) as Map<String, dynamic>;
        return JournalDocument.fromJson(docJson);
      }
    } catch (_) {
      // fall through to plain text
    }
    // fallback: plain text -> document with empty drawing block
    return JournalDocument(
      version: kJournalDocVersion,
      blocks: [
        ParagraphBlock(
          id: 'p-${DateTime.now().millisecondsSinceEpoch}',
          ops: [TextOp(insert: entry.body.isEmpty ? '\n' : entry.body)],
        ),
        DrawingBlock(
          id: 'draw-${DateTime.now().millisecondsSinceEpoch}',
          strokes: [],
        ),
      ],
      meta: const {},
    );
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
    final drawingBlocks = entryDoc.blocks.whereType<DrawingBlock>();
    final drawingBlock = drawingBlocks.isNotEmpty ? drawingBlocks.first : null;

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
                : _buildReadView(entryText, drawingBlock),
          ),
        ),
      ],
    );
  }

  Widget _buildReadView(String text, DrawingBlock? drawing) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.5,
            ),
          ),
          if (drawing != null && drawing.strokes.isNotEmpty) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 220,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0A0A),
                  border: Border.all(color: const Color(0xFF333333), width: 1),
                ),
                child: IgnorePointer(
                  child: DrawingCanvas(
                    initialBlock: drawing,
                    onChanged: (_) {},
                    currentTool: DrawingTool.pen,
                    currentColor: Colors.white,
                    currentWidth: 2.0,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEditView() {
    final drawing = _editDrawingBlock;

    return Column(
      children: [
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: TextField(
                  controller: _editController,
                  maxLines: null,
                  expands: true,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.5,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Write your journal entry...',
                    hintStyle: TextStyle(color: Color(0xFF666666)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (drawing != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 220,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A0A0A),
                      border: Border.all(color: const Color(0xFF333333), width: 1),
                    ),
                    child: DrawingCanvas(
                      initialBlock: drawing,
                      onChanged: (block) {
                        setState(() {
                          _editDrawingBlock = block;
                        });
                      },
                      currentTool: DrawingTool.pen,
                      currentColor: Colors.white,
                      currentWidth: 2.0,
                    ),
                  ),
                ),
            ],
          ),
        ),
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
