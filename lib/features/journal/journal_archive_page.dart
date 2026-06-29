// lib/features/journal/journal_archive_page.dart
// Journal Archive - Single page with list/detail views

import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/insight_link_model.dart';
import '../../data/insight_link_repo.dart';
import '../../data/insight_link_utils.dart';
import '../../data/journal_repo.dart';
import '../../core/navigation_fallback.dart';
import '../../widgets/insight_link_text.dart';
import '../../widgets/keyboard_aware.dart';
import '../calendar/calendar_page.dart' show KemeticMath;
import '../calendar/kemetic_month_metadata.dart' show getMonthById;
import '../nodes/kemetic_node_library.dart';
import '../reflections/decan_reflection_skin.dart';
import 'package:mobile/shared/glossy_text.dart';
import 'journal_badge_utils.dart';
import 'journal_controller.dart';
import 'journal_empty_badge_glyph.dart';
import 'journal_event_badge.dart';
import 'journal_v2_document_model.dart';
import 'journal_v2_rich_text.dart';

const Key journalArchiveReflectionSkinKey = ValueKey<String>(
  'journal-archive-reflection-skin',
);
const Key journalArchiveDateModeToggleKey = ValueKey<String>(
  'journal-archive-date-mode-toggle',
);

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
  late ScrollController _badgeScrollController;
  final InsightLinkRepo _insightRepo = InsightLinkRepo();
  JournalDocument? _editingDocument;
  List<InsightLink> _entryLinks = [];
  String _entryPrevText = '';
  bool _useKemetic = true; // default to Kemetic

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController();
    _badgeScrollController = ScrollController();
    _loadEntries();
  }

  @override
  void dispose() {
    _editController.dispose();
    _badgeScrollController.dispose();
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
    final plainText = doc.toPlainText();

    setState(() {
      _selectedEntry = entry;
      _isEditing = false;
      _editingDocument = doc;
      _editController.text = plainText;
      _entryPrevText = plainText;
      _entryLinks = [];
    });
    _loadEntryLinks(entry);
  }

  void _closeEntry() {
    setState(() {
      _selectedEntry = null;
      _isEditing = false;
      _editingDocument = null;
      _entryLinks = [];
      _entryPrevText = '';
      _editController.clear();
    });
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
    });
  }

  String _entrySourceId(JournalEntry entry) {
    return journalInsightSourceId(entry.gregDate);
  }

  List<TextRange> _entryLinkRanges() {
    return _entryLinks
        .map((link) => TextRange(start: link.start, end: link.end))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  Future<void> _loadEntryLinks(JournalEntry entry) async {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? 'local';
    final links = await _insightRepo.fetchLinks(userId);
    if (!mounted || _selectedEntry?.id != entry.id) return;

    final sourceId = _entrySourceId(entry);
    setState(() {
      _entryLinks =
          links
              .where(
                (link) =>
                    link.sourceType == InsightSourceType.journalEntry &&
                    link.sourceId == sourceId,
              )
              .toList()
            ..sort((a, b) => a.start.compareTo(b.start));
    });
  }

  Future<void> _saveEntryLinks(JournalEntry entry) async {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? 'local';
    final all = await _insightRepo.fetchLinks(userId);
    final sourceId = _entrySourceId(entry);
    final filtered = all
        .where(
          (link) =>
              !(link.sourceType == InsightSourceType.journalEntry &&
                  link.sourceId == sourceId),
        )
        .toList();
    filtered.addAll(_entryLinks);
    await _insightRepo.saveLinks(userId, filtered);
  }

  Future<void> _handleEntryLinkTap(InsightLink link) async {
    if (link.targetType != InsightTargetType.node) return;
    final node = KemeticNodeLibrary.resolve(link.targetId);
    if (node == null || !mounted) return;

    unawaited(
      openDetailRoute<void>(context, '/nodes/${Uri.encodeComponent(node.id)}'),
    );
  }

  void _saveEntry() async {
    if (_selectedEntry == null) return;
    final messenger = ScaffoldMessenger.maybeOf(context);

    try {
      final selectedEntry = _selectedEntry!;
      // Save the edited document with badges + drawing
      JournalDocument doc =
          _editingDocument ??
          JournalDocument.fromPlainText(_editController.text);

      final blocks = List<JournalBlock>.from(doc.blocks);

      // Ensure paragraph block exists
      int paragraphIndex = blocks.indexWhere((b) => b is ParagraphBlock);
      if (paragraphIndex == -1) {
        blocks.insert(
          0,
          ParagraphBlock(
            id: 'p-${_selectedEntry!.gregDate.millisecondsSinceEpoch}',
            ops: [
              TextOp(
                insert: _editController.text.isEmpty
                    ? '\n'
                    : _editController.text,
              ),
            ],
          ),
        );
      }

      doc = JournalDocument(
        version: doc.version,
        blocks: blocks,
        meta: doc.meta,
      );
      doc = JournalBadgeUtils.normalizeDocument(doc);

      final body = jsonEncode(doc.toJson());

      await widget.repo.upsert(localDate: selectedEntry.gregDate, body: body);
      await _saveEntryLinks(selectedEntry);

      final refreshedEntry =
          await widget.repo.getByDate(selectedEntry.gregDate) ??
          JournalEntry(
            id: selectedEntry.id,
            userId: selectedEntry.userId,
            gregDate: selectedEntry.gregDate,
            body: body,
            meta: selectedEntry.meta,
            category: selectedEntry.category,
            createdAt: selectedEntry.createdAt,
            updatedAt: DateTime.now(),
          );
      final plainText = doc.toPlainText();
      if (!mounted) return;

      setState(() {
        _selectedEntry = refreshedEntry;
        _editingDocument = doc;
        _editController.text = plainText;
        _entryPrevText = plainText;
        _isEditing = false;
      });

      // Reload entries to reflect changes
      await _loadEntries();

      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Entry saved'),
          backgroundColor: KemeticGold.base,
        ),
      );
    } catch (e) {
      messenger?.showSnackBar(
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
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[date.weekday - 1];
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  String _formatArchiveDate(DateTime greg) {
    final dow = _getDayOfWeek(greg);
    if (_useKemetic) {
      final k = KemeticMath.fromGregorian(greg);
      final month = getMonthById(k.kMonth).displayFull;
      return '$dow, $month ${k.kDay}';
    }
    final month = _getMonthName(greg.month);
    return '$dow, $month ${greg.day}';
  }

  String _formatArchiveSection(DateTime greg) {
    if (_useKemetic) {
      final k = KemeticMath.fromGregorian(greg);
      return getMonthById(k.kMonth).displayFull;
    }
    return '${_getMonthName(greg.month)} ${greg.year}';
  }

  List<_JournalArchiveSection> _archiveSections() {
    final sections = <_JournalArchiveSection>[];
    var currentLabel = '';
    var currentEntries = <JournalEntry>[];

    void flush() {
      if (currentEntries.isEmpty) return;
      sections.add(
        _JournalArchiveSection(
          label: currentLabel,
          entries: List<JournalEntry>.unmodifiable(currentEntries),
        ),
      );
      currentEntries = <JournalEntry>[];
    }

    for (final entry in _entries) {
      final label = _formatArchiveSection(entry.gregDate);
      if (currentEntries.isNotEmpty && label != currentLabel) {
        flush();
      }
      currentLabel = label;
      currentEntries.add(entry);
    }
    flush();

    return sections;
  }

  TextStyle _modeToggleTextStyle({required bool selected}) {
    return DecanReflectionTokens.bridgeStyle.copyWith(
      color: selected ? DecanReflectionTokens.base : DecanReflectionTokens.gold,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    );
  }

  Widget _buildModeToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 282),
          child: CupertinoSegmentedControl<bool>(
            key: journalArchiveDateModeToggleKey,
            groupValue: _useKemetic,
            padding: const EdgeInsets.all(2),
            selectedColor: DecanReflectionTokens.goldDeep,
            unselectedColor: const Color.fromRGBO(212, 174, 67, 0.05),
            borderColor: const Color.fromRGBO(212, 174, 67, 0.34),
            pressedColor: const Color.fromRGBO(212, 174, 67, 0.14),
            children: {
              true: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 8,
                ),
                child: Text(
                  'Kemetic',
                  style: _modeToggleTextStyle(selected: _useKemetic),
                ),
              ),
              false: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 8,
                ),
                child: Text(
                  'Gregorian',
                  style: _modeToggleTextStyle(selected: !_useKemetic),
                ),
              ),
            },
            onValueChanged: (v) {
              setState(() => _useKemetic = v);
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showingEntry = _selectedEntry != null;
    return DecanReflectionSkinScaffold(
      key: journalArchiveReflectionSkinKey,
      navBar: DecanReflectionNavBar(
        title: showingEntry ? 'Journal Entry' : 'Journal Archive',
        leadingIcon: showingEntry ? Icons.chevron_left : Icons.close,
        leadingTooltip: showingEntry ? 'Back to archive' : 'Close archive',
        onBack: showingEntry ? _closeEntry : widget.onClose,
        rightWidth: showingEntry ? 76 : 48,
        right: showingEntry
            ? _JournalArchiveNavAction(
                label: _isEditing ? 'Save' : 'Edit',
                onPressed: _isEditing ? _saveEntry : _startEditing,
              )
            : null,
      ),
      child: showingEntry ? _buildEntryDetail() : _buildEntryList(),
    );
  }

  Widget _buildEntryList() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(DecanReflectionTokens.gold),
          strokeWidth: 2,
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
              size: 54,
              color: DecanReflectionTokens.inkLo,
            ),
            SizedBox(height: 16),
            Text(
              'No journal entries yet',
              textAlign: TextAlign.center,
              style: DecanReflectionTokens.emptyTitleStyle,
            ),
            SizedBox(height: 8),
            Text(
              'Start writing to see your entries here',
              textAlign: TextAlign.center,
              style: DecanReflectionTokens.emptyBodyStyle,
            ),
          ],
        ),
      );
    }

    final sections = _archiveSections();
    final bottomPadding =
        DecanReflectionTokens.scrollBottomPadding +
        MediaQuery.paddingOf(context).bottom;

    return Column(
      children: [
        _buildModeToggle(),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.only(top: 6, bottom: bottomPadding),
            itemCount: sections.length,
            itemBuilder: (context, sectionIndex) {
              final section = sections[sectionIndex];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DecanMonthHeader(label: section.label),
                  DecanTrack(
                    children: [
                      for (var i = 0; i < section.entries.length; i++)
                        _buildEntryCard(section.entries[i], addTopGap: i > 0),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEntryCard(JournalEntry entry, {bool addTopGap = false}) {
    final date = entry.gregDate;
    final header = _formatArchiveDate(date);
    final previewText = _getPreviewText(entry);
    final charCount = _getActualTextLength(entry);

    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: EdgeInsets.only(top: addTopGap ? 2 : 0),
        decoration: const BoxDecoration(
          color: Color.fromRGBO(104, 40, 35, 0.76),
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: const Icon(Icons.delete, color: DecanReflectionTokens.ink),
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
      child: _JournalArchiveEntryRow(
        dateLabel: header,
        preview: previewText,
        metadata: '$charCount characters',
        addTopGap: addTopGap,
        onTap: () {
          _openEntry(entry);
        },
      ),
    );
  }

  Widget _buildEntryDetail() {
    if (_selectedEntry == null) return const SizedBox.shrink();

    final entry = _selectedEntry!;
    final date = entry.gregDate;
    final header = _formatArchiveDate(date);
    final entryDoc = _entryToDocument(entry);
    final charCount = _getActualTextLength(entry);
    final keyboardVisible = keyboardInsetOf(context) > 0;
    const contentBottomPadding = 16.0;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 16),
          child: Column(
            children: [
              const Text(
                'ENTRY FOR',
                style: DecanReflectionTokens.riteEyebrowStyle,
              ),
              const SizedBox(height: 8),
              Text(
                header,
                style: DecanReflectionTokens.recordTitleStyle.copyWith(
                  fontSize: 24,
                  height: 1.25,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '$charCount characters',
                style: DecanReflectionTokens.folioDateStyle,
              ),
              const SizedBox(height: 16),
              const SizedBox(
                height: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: DecanReflectionTokens.mastheadRule,
                  ),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, contentBottomPadding),
            child: _isEditing
                ? _buildEditView(keyboardVisible: keyboardVisible)
                : _buildReadView(entryDoc),
          ),
        ),
      ],
    );
  }

  Widget _buildReadView(JournalDocument doc) {
    final visibleText = doc.toPlainText();
    final baseStyle = DecanReflectionTokens.bodyStyle.copyWith(fontSize: 19);

    final badges = JournalBadgeUtils.tokensFromDocument(doc);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: baseStyle,
              children: InsightLinkSpanBuilder.build(
                text: visibleText,
                links: _entryLinks,
                baseStyle: baseStyle,
                onTap: _handleEntryLinkTap,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildBadgeSection(badges),
        ],
      ),
    );
  }

  Widget _buildBadgeSection(List<EventBadgeToken> badges, {double? maxHeight}) {
    final badgeList = badges
        .map(
          (token) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: EventBadgeWidget(token: token),
          ),
        )
        .toList();

    Widget badgeBody;
    if (badges.isEmpty) {
      badgeBody = const JournalEmptyBadgeGlyph(size: 38);
    } else {
      if (maxHeight != null) {
        badgeBody = ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Scrollbar(
            thumbVisibility: true,
            controller: _badgeScrollController,
            child: SingleChildScrollView(
              controller: _badgeScrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: badgeList,
              ),
            ),
          ),
        );
      } else {
        badgeBody = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: badgeList,
        );
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(18, 15, 8, 0.70),
        border: Border.all(color: DecanReflectionTokens.hairline, width: 1),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      constraints: maxHeight != null
          ? BoxConstraints(maxHeight: maxHeight)
          : const BoxConstraints(),
      child: badgeBody,
    );
  }

  Widget _buildEditView({required bool keyboardVisible}) {
    // Use current document paragraph as initial block
    ParagraphBlock initialBlock;
    if (_editingDocument != null) {
      final paragraphs = _editingDocument!.blocks.whereType<ParagraphBlock>();
      if (paragraphs.isNotEmpty) {
        initialBlock = paragraphs.first;
      } else {
        initialBlock = ParagraphBlock(
          id: 'p-${DateTime.now().millisecondsSinceEpoch}',
          ops: [
            TextOp(
              insert: _editController.text.isEmpty
                  ? '\n'
                  : _editController.text,
            ),
          ],
        );
      }
    } else {
      initialBlock = ParagraphBlock(
        id: 'p-${DateTime.now().millisecondsSinceEpoch}',
        ops: [
          TextOp(
            insert: _editController.text.isEmpty ? '\n' : _editController.text,
          ),
        ],
      );
    }

    final badges = _editingDocument != null
        ? JournalBadgeUtils.tokensFromDocument(_editingDocument!)
        : <EventBadgeToken>[];

    return LayoutBuilder(
      builder: (context, constraints) {
        final badgeHeight = _editBadgeSectionHeight(
          keyboardVisible: keyboardVisible,
          hasBadges: badges.isNotEmpty,
          maxEditHeight: constraints.maxHeight,
        );
        final sectionGap = keyboardVisible ? 8.0 : 12.0;

        return Column(
          children: [
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(18, 15, 8, 0.52),
                  border: Border.all(color: DecanReflectionTokens.hairline),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: RichTextEditor(
                    initialBlock: initialBlock,
                    highlightedRanges: _entryLinkRanges(),
                    insightLinks: _entryLinks,
                    onInsightLinkTap: _handleEntryLinkTap,
                    textStyle: DecanReflectionTokens.bodyStyle.copyWith(
                      fontSize: 18,
                    ),
                    placeholderStyle: DecanReflectionTokens.emptyBodyStyle,
                    cursorColor: DecanReflectionTokens.gold,
                    transparentDecoration: true,
                    onChanged: (block) {
                      final previousText = _entryPrevText;
                      setState(() {
                        final doc =
                            _editingDocument ??
                            _entryToDocument(_selectedEntry!);
                        final blocks = List<JournalBlock>.from(doc.blocks);
                        final pIdx = blocks.indexWhere(
                          (b) => b is ParagraphBlock,
                        );
                        if (pIdx >= 0) {
                          blocks[pIdx] = block;
                        } else {
                          blocks.insert(0, block);
                        }
                        final nextDocument = JournalDocument(
                          version: doc.version,
                          blocks: blocks,
                          meta: doc.meta,
                        );
                        final nextText = nextDocument.toPlainText();

                        _editingDocument = nextDocument;
                        _editController.text = nextText;
                        if (previousText != nextText) {
                          _entryLinks = InsightLinkRangeUpdater.shiftRanges(
                            previous: previousText,
                            next: nextText,
                            links: _entryLinks,
                          );
                          _entryPrevText = nextText;
                        }
                      });
                    },
                  ),
                ),
              ),
            ),
            if (badgeHeight > 0) ...[
              SizedBox(height: sectionGap),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                height: badgeHeight,
                child: _buildBadgeSection(badges, maxHeight: badgeHeight),
              ),
            ],
            SizedBox(height: sectionGap),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final entry = _selectedEntry;
                      if (entry == null) return;
                      final originalDoc = _entryToDocument(entry);
                      final originalText = originalDoc.toPlainText();
                      setState(() {
                        _isEditing = false;
                        _editingDocument = originalDoc;
                        _editController.text = originalText;
                        _entryPrevText = originalText;
                      });
                      _loadEntryLinks(entry);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromRGBO(212, 174, 67, 0.06),
                      foregroundColor: DecanReflectionTokens.inkSoft,
                      side: const BorderSide(
                        color: DecanReflectionTokens.hairline,
                      ),
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
                      backgroundColor: DecanReflectionTokens.goldDeep,
                      foregroundColor: DecanReflectionTokens.base,
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
      },
    );
  }

  double _editBadgeSectionHeight({
    required bool keyboardVisible,
    required bool hasBadges,
    required double maxEditHeight,
  }) {
    if (keyboardVisible && !hasBadges) return 0;

    final targetHeight = keyboardVisible ? 88.0 : 220.0;
    if (!maxEditHeight.isFinite) return targetHeight;

    final minTextHeight = keyboardVisible ? 160.0 : 180.0;
    final actionHeight = 48.0;
    final gapHeight = keyboardVisible ? 16.0 : 24.0;
    final maxBadgeHeight =
        maxEditHeight - minTextHeight - actionHeight - gapHeight;

    if (maxBadgeHeight < 52) return 0;
    return targetHeight.clamp(52.0, maxBadgeHeight).toDouble();
  }
}

class _JournalArchiveSection {
  const _JournalArchiveSection({required this.label, required this.entries});

  final String label;
  final List<JournalEntry> entries;
}

class _JournalArchiveNavAction extends StatelessWidget {
  const _JournalArchiveNavAction({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: ButtonStyle(
        foregroundColor: const WidgetStatePropertyAll<Color>(
          DecanReflectionTokens.gold,
        ),
        padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
          EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
        minimumSize: const WidgetStatePropertyAll<Size>(Size(0, 0)),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        overlayColor: const WidgetStatePropertyAll<Color>(
          Color.fromRGBO(212, 174, 67, 0.08),
        ),
        shape: WidgetStatePropertyAll<OutlinedBorder>(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.fade,
        softWrap: false,
        style: DecanReflectionTokens.bridgeStyle.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _JournalArchiveEntryRow extends StatefulWidget {
  const _JournalArchiveEntryRow({
    required this.dateLabel,
    required this.preview,
    required this.metadata,
    required this.onTap,
    this.addTopGap = false,
  });

  final String dateLabel;
  final String preview;
  final String metadata;
  final VoidCallback onTap;
  final bool addTopGap;

  @override
  State<_JournalArchiveEntryRow> createState() =>
      _JournalArchiveEntryRowState();
}

class _JournalArchiveEntryRowState extends State<_JournalArchiveEntryRow> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  bool get _active => _hovered || _pressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: widget.addTopGap ? 2 : 0),
      child: Semantics(
        button: true,
        label: 'Open journal entry for ${widget.dateLabel}, ${widget.metadata}',
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: _focused
                ? Border.all(color: DecanReflectionTokens.gold, width: 2)
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              focusColor: Colors.transparent,
              hoverColor: Colors.transparent,
              highlightColor: Colors.transparent,
              splashColor: Colors.transparent,
              onTap: widget.onTap,
              onHover: (hovered) => setState(() => _hovered = hovered),
              onHighlightChanged: (pressed) =>
                  setState(() => _pressed = pressed),
              onFocusChange: (focused) => setState(() => _focused = focused),
              child: Stack(
                children: <Widget>[
                  Positioned(
                    left: 3,
                    top: 25,
                    child: _JournalArchiveTimelineNode(active: _active),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(30, 16, 20, 18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                widget.metadata,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: DecanReflectionTokens.dateStyle,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                widget.dateLabel,
                                style: DecanReflectionTokens.recordTitleStyle
                                    .copyWith(fontSize: 22, height: 1.34),
                              ),
                              const SizedBox(height: 6),
                              DecanPreviewText(text: widget.preview),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.chevron_right,
                          color: DecanReflectionTokens.inkLo.withValues(
                            alpha: 0.74,
                          ),
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _JournalArchiveTimelineNode extends StatelessWidget {
  const _JournalArchiveTimelineNode({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: active ? 1.18 : 1,
      duration: const Duration(milliseconds: 250),
      curve: Curves.ease,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.ease,
        width: 13,
        height: 13,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: DecanReflectionTokens.recordNodeFill,
          border: Border.all(color: DecanReflectionTokens.goldDeep, width: 1.5),
          boxShadow: <BoxShadow>[
            const BoxShadow(color: DecanReflectionTokens.base, spreadRadius: 4),
            if (active)
              const BoxShadow(
                color: Color.fromRGBO(212, 174, 67, 0.28),
                blurRadius: 14,
                spreadRadius: 2,
              ),
          ],
        ),
      ),
    );
  }
}
