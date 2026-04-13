import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mobile/features/rhythm/rhythm_add_flow.dart';
import 'package:mobile/features/rhythm/rhythm_telemetry.dart';
import 'package:mobile/features/rhythm/rhythm_user_messages.dart';
import 'package:mobile/shared/glossy_text.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/rhythm_repo.dart';
import '../models/rhythm_models.dart';
import '../theme/rhythm_theme.dart';
import '../widgets/alignment_item_row.dart';
import '../widgets/rhythm_section_card.dart';
import '../widgets/rhythm_states.dart';
import '../widgets/rhythm_todo_row.dart';

class TodaysAlignmentPage extends StatefulWidget {
  const TodaysAlignmentPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<TodaysAlignmentPage> createState() => _TodaysAlignmentPageState();
}

class _TodaysAlignmentPageState extends State<TodaysAlignmentPage> {
  final RhythmRepo _repo = RhythmRepo(Supabase.instance.client);
  late Future<void> _future;
  final TextEditingController _commitmentInputController =
      TextEditingController();
  final TextEditingController _noteInputController = TextEditingController();
  final PageController _notePageController = PageController(
    viewportFraction: 0.9,
  );
  PageController? _fullscreenPageController;

  List<RhythmItem> _alignmentItems = [];
  List<RhythmTodo> _todos = [];
  List<RhythmNote> _notes = [];
  int _activeNoteIndex = 0;
  RhythmNote? _fullscreenNote;
  bool _isSyncingNotePages = false;
  bool _missingTables = false;
  String? _friendlyError;
  bool _notesLocalOnly = false;
  bool _notesLocalNoticeShown = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
    unawaited(_loadNotes());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        RhythmTelemetry.trackScreen(
          Supabase.instance.client,
          'today_alignment',
        ),
      );
    });
  }

  @override
  void dispose() {
    _commitmentInputController.dispose();
    _noteInputController.dispose();
    _notePageController.dispose();
    _fullscreenPageController?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final items = await _repo.fetchTodaysAlignment();
      final todos = await _repo.fetchTodos();
      if (!mounted) return;
      setState(() {
        _missingTables = items.missingTables || todos.missingTables;
        final repoErr = items.friendlyError ?? todos.friendlyError;
        _friendlyError = repoErr != null
            ? RhythmUserMessages.loadFailedTodayAlignment
            : null;
        _alignmentItems = items.data;
        _todos = todos.data;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _missingTables = false;
        _friendlyError = RhythmUserMessages.loadFailedTodayAlignment;
        _alignmentItems = [];
        _todos = [];
      });
    }
  }

  void _updateAlignment(int index, RhythmItemState state) {
    setState(() {
      _alignmentItems = [
        for (int i = 0; i < _alignmentItems.length; i++)
          i == index
              ? _alignmentItems[i].copyWith(state: state)
              : _alignmentItems[i],
      ];
    });
  }

  Future<void> _persistTodoState(int index, RhythmItemState state) async {
    final id = _todos[index].id;
    if (id.isEmpty) return;
    final prev = _todos[index].state;
    setState(() {
      _todos = [
        for (int i = 0; i < _todos.length; i++)
          if (i == index)
            RhythmTodo(
              id: _todos[i].id,
              title: _todos[i].title,
              notes: _todos[i].notes,
              dueDate: _todos[i].dueDate,
              dueTime: _todos[i].dueTime,
              isChecklist: _todos[i].isChecklist,
              isCalendar: _todos[i].isCalendar,
              state: state,
            )
          else
            _todos[i],
      ];
    });
    final result = await _repo.updateTodoState(id, state);
    if (!mounted) return;
    if (result.friendlyError != null || result.missingTables) {
      setState(() {
        _todos = [
          for (int i = 0; i < _todos.length; i++)
            if (i == index)
              RhythmTodo(
                id: _todos[i].id,
                title: _todos[i].title,
                notes: _todos[i].notes,
                dueDate: _todos[i].dueDate,
                dueTime: _todos[i].dueTime,
                isChecklist: _todos[i].isChecklist,
                isCalendar: _todos[i].isCalendar,
                state: prev,
              )
            else
              _todos[i],
        ];
      });
      final msg = result.missingTables
          ? 'To-do storage is not available in this environment yet.'
          : (result.friendlyError ?? 'Could not update task.');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _commitNewTodo() async {
    final text = _commitmentInputController.text;
    final result = await _repo.insertTodaysCommitment(text);
    if (!mounted) return;
    if (result.friendlyError != null || result.missingTables) {
      final msg = result.missingTables
          ? 'To-do storage is not available in this environment yet.'
          : (result.friendlyError ?? 'Could not add task.');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
    }
    if (!result.data) return;
    _commitmentInputController.clear();
    setState(() {
      _future = _load();
    });
  }

  String _prefsKeyForUser(String? uid) =>
      'today_alignment_notes${uid == null ? '' : '_$uid'}';

  String? get _currentUserId =>
      Supabase.instance.client.auth.currentUser?.id;

  int _clampNoteIndex(int length, [int? desired]) {
    if (length == 0) return 0;
    final target = desired ?? _activeNoteIndex;
    if (target < 0) return 0;
    if (target >= length) return length - 1;
    return target;
  }

  Future<List<RhythmNote>> _loadNotesFromPrefs([String? uid]) async {
    final userKey = _prefsKeyForUser(uid ?? _currentUserId);
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(userKey) ?? [];
    return [
      for (int i = 0; i < stored.length; i++)
        () {
          // Try JSON payload first.
          try {
            final decoded = jsonDecode(stored[i]);
            if (decoded is Map<String, dynamic>) {
              return RhythmNote(
                id: (decoded['id'] as String?) ?? 'local_$i',
                text: (decoded['text'] as String?) ?? '',
                position: (decoded['position'] as num?)?.toInt() ?? i,
                createdAt: DateTime.tryParse(decoded['createdAt'] as String? ?? '') ??
                    DateTime.now(),
              );
            }
          } catch (_) {
            // Fall through to legacy format.
          }
          // Legacy: text only.
          return RhythmNote(
            id: 'local_$i',
            text: stored[i],
            position: i,
            createdAt: DateTime.now(),
          );
        }(),
    ];
  }

  Future<void> _saveNotesToPrefs(
    List<RhythmNote> notes, {
    String? uid,
  }) async {
    final userKey = _prefsKeyForUser(uid ?? _currentUserId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      userKey,
      notes
          .map(
            (n) => jsonEncode({
              'id': n.id,
              'text': n.text,
              'position': n.position,
              'createdAt': n.createdAt.toIso8601String(),
            }),
          )
          .toList(),
    );
  }

  void _showLocalNotesWarningOnce() {
    if (_notesLocalNoticeShown || !mounted) return;
    _notesLocalNoticeShown = true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Planner notes are saved only on this device. Cloud sync is unavailable.',
        ),
        duration: Duration(seconds: 4),
        backgroundColor: Colors.orangeAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  bool _isLocalNote(RhythmNote note) => note.id.startsWith('local_');

  List<RhythmNote> _withPositions(List<RhythmNote> notes) {
    return [
      for (int i = 0; i < notes.length; i++) notes[i].copyWith(position: i),
    ];
  }

  Future<void> _loadNotes() async {
    final result = await _repo.fetchAlignmentNotes();
    final uid = _currentUserId;
    if (!mounted) return;

    final cached = await _loadNotesFromPrefs(uid);

    final useLocalOnly =
        result.missingTables || result.friendlyError != null || uid == null;
    if (useLocalOnly) {
      _showLocalNotesWarningOnce();
      if (!mounted) return;
      setState(() {
        _notesLocalOnly = true;
        _notes = cached;
        _activeNoteIndex = _clampNoteIndex(cached.length);
        _fullscreenNote = null;
      });
      return;
    }

    var notes = result.data;
    if (notes.isEmpty && cached.any(_isLocalNote)) {
      final inserted = <RhythmNote>[];
      for (int i = 0; i < cached.length; i++) {
        final res = await _repo.insertAlignmentNote(
          cached[i].text,
          position: i,
        );
        if (res.data != null) {
          inserted.add(res.data!);
        }
      }
      if (inserted.isNotEmpty) {
        notes = inserted;
      } else {
        notes = cached;
      }
    } else if (notes.isEmpty && cached.isNotEmpty) {
      // Remote empty but cached reflects previously synced notes; show cached
      // without re-inserting.
      notes = cached;
    } else if (notes.isNotEmpty && cached.any(_isLocalNote)) {
      final offlineAdds = cached.where(_isLocalNote).toList();
      final inserted = <RhythmNote>[];
      for (int i = 0; i < offlineAdds.length; i++) {
        final res = await _repo.insertAlignmentNote(
          offlineAdds[i].text,
          position: notes.length + i,
        );
        if (res.data != null) {
          inserted.add(res.data!);
        }
      }
      if (inserted.isNotEmpty) {
        notes = [...notes, ...inserted];
      }
    }

    await _saveNotesToPrefs(notes, uid: uid);
    if (!mounted) return;
    setState(() {
      _notesLocalOnly = false;
      _notes = notes;
      _activeNoteIndex = _clampNoteIndex(notes.length);
      _fullscreenNote = null;
    });
  }

  Future<void> _addNote() async {
    final text = _noteInputController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Write a note first.')));
      return;
    }

    final result = await _repo.insertAlignmentNote(
      text,
      position: _notes.length,
    );
    if (!mounted) return;

    if (result.missingTables) {
      _showLocalNotesWarningOnce();
      final fallback = RhythmNote(
        id: 'local_${DateTime.now().millisecondsSinceEpoch}',
        text: text,
        position: _notes.length,
        createdAt: DateTime.now(),
      );
      final updated = [..._notes, fallback];
      _noteInputController.clear();
      setState(() {
        _notesLocalOnly = true;
        _notes = updated;
        _activeNoteIndex = updated.length - 1;
        _fullscreenNote = null;
      });
      await _saveNotesToPrefs(updated);
      return;
    }

    if (result.friendlyError != null || result.data == null) {
      final msg = result.friendlyError ?? 'Could not save note.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
    }

    final note = result.data!;
    final updated = [..._notes, note];
    _noteInputController.clear();
    setState(() {
      _notesLocalOnly = false;
      _notes = updated;
      _activeNoteIndex = updated.length - 1;
      _fullscreenNote = null;
    });
    await _saveNotesToPrefs(updated);
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_notePageController.hasClients) return;
      _notePageController.animateToPage(
        _activeNoteIndex,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _showNotePicker() async {
    if (_notes.isEmpty) return;
    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    KemeticGold.text(
                      'Your notes',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'GentiumPlus',
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 360,
                    minHeight: 180,
                  ),
                  child: ReorderableListView.builder(
                    shrinkWrap: true,
                    proxyDecorator: (child, index, animation) =>
                        Material(color: Colors.transparent, child: child),
                    itemCount: _notes.length,
                    onReorder: (oldIndex, newIndex) =>
                        unawaited(_reorderNotes(oldIndex, newIndex)),
                    itemBuilder: (context, index) {
                      final note = _notes[index];
                      return ListTile(
                        key: ValueKey('note_$index'),
                        contentPadding: EdgeInsets.zero,
                        leading: ReorderableDragStartListener(
                          index: index,
                          child: const Icon(
                            Icons.drag_handle,
                            color: Colors.white54,
                          ),
                        ),
                        title: Text(
                          note.text,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: RhythmTheme.subheading,
                        ),
                        trailing: index == _activeNoteIndex
                            ? const Icon(
                                Icons.visibility,
                                color: Colors.white70,
                                size: 18,
                              )
                            : null,
                        onTap: () => Navigator.of(context).pop(index),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || selected == null) return;
    await _jumpToNote(selected, fromOverlay: _fullscreenNote != null);
    if (_fullscreenNote != null &&
        _fullscreenPageController?.hasClients == true) {
      _fullscreenPageController!.jumpToPage(selected);
    }
  }

  Future<void> _jumpToNote(int index, {bool fromOverlay = false}) async {
    if (_notes.isEmpty) return;
    final clamped = index.clamp(0, _notes.length - 1);
    setState(() {
      _activeNoteIndex = clamped;
      if (_fullscreenNote != null) {
        _fullscreenNote = _notes[clamped];
      }
    });

    if (fromOverlay) {
      if (_notePageController.hasClients) {
        _isSyncingNotePages = true;
        await _notePageController.animateToPage(
          clamped,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
        _isSyncingNotePages = false;
      }
    } else {
      if (_fullscreenPageController?.hasClients == true) {
        _fullscreenPageController!.jumpToPage(clamped);
      }
    }
  }

  void _enterFullscreen([int? noteIndex]) {
    if (_notes.isEmpty) return;
    final target = (noteIndex ?? _activeNoteIndex).clamp(0, _notes.length - 1);
    _fullscreenPageController?.dispose();
    _fullscreenPageController = PageController(initialPage: target);
    setState(() {
      _activeNoteIndex = target;
      _fullscreenNote = _notes[target];
    });
  }

  void _closeFullscreen() {
    setState(() {
      _fullscreenNote = null;
    });
    _fullscreenPageController?.dispose();
    _fullscreenPageController = null;
  }

  Future<void> _syncNotes(
    List<RhythmNote> updated, {
    int? activeIndex,
    bool persistOrder = false,
  }) async {
    final clampedIndex = _clampNoteIndex(updated.length, activeIndex);
    setState(() {
      _notes = updated;
      _activeNoteIndex = clampedIndex;
      if (updated.isEmpty) {
        _fullscreenNote = null;
      } else if (_fullscreenNote != null) {
        _fullscreenNote = updated[clampedIndex];
      }
    });

    await _saveNotesToPrefs(updated);

    if (persistOrder) {
      final remote = <RhythmNote>[];
      for (int i = 0; i < updated.length; i++) {
        final note = updated[i];
        if (_isLocalNote(note)) continue;
        remote.add(note.copyWith(position: i));
      }
      if (remote.isNotEmpty) {
        final result = await _repo.reorderAlignmentNotes(remote);
        if (result.missingTables) {
          _showLocalNotesWarningOnce();
          if (mounted) {
            setState(() {
              _notesLocalOnly = true;
            });
          }
        } else if (result.friendlyError != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.friendlyError!)),
          );
        } else if (mounted) {
          setState(() {
            _notesLocalOnly = false;
          });
        }
      }
    }

    if (_notePageController.hasClients && updated.isNotEmpty) {
      unawaited(
        _notePageController.animateToPage(
          clampedIndex,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        ),
      );
    }
    if (_fullscreenPageController?.hasClients == true &&
        updated.isNotEmpty) {
      _fullscreenPageController!.jumpToPage(clampedIndex);
    }
  }

  Future<void> _editNote(int index) async {
    if (index < 0 || index >= _notes.length) return;
    final original = _notes[index];
    final controller = TextEditingController(text: original.text);
    final updatedText = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.black87,
          title: const Text('Edit note', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
            maxLines: 4,
            minLines: 2,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Update your note',
              hintStyle: TextStyle(color: Colors.white54),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white54),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (updatedText == null) return;
    if (updatedText.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Note cannot be empty.')));
      return;
    }

    if (!_isLocalNote(original)) {
      final result = await _repo.updateAlignmentNote(original.id, updatedText);
      if (result.missingTables) {
        // fall through to local persistence
        _showLocalNotesWarningOnce();
        if (mounted) {
          setState(() {
            _notesLocalOnly = true;
          });
        }
      } else if (result.friendlyError != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(result.friendlyError!)));
        return;
      } else if (mounted) {
        setState(() {
          _notesLocalOnly = false;
        });
      }
    }

    final updated = [..._notes]
      ..[index] = original.copyWith(text: updatedText);
    await _syncNotes(updated, activeIndex: index);
  }

  Future<void> _deleteNote(int index) async {
    if (index < 0 || index >= _notes.length) return;
    final note = _notes[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black87,
        title: const Text(
          'Delete note?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    if (!_isLocalNote(note)) {
      final result = await _repo.deleteAlignmentNote(note.id);
      if (result.missingTables) {
        // Fall back to local deletion below.
        _showLocalNotesWarningOnce();
        if (mounted) {
          setState(() {
            _notesLocalOnly = true;
          });
        }
      } else if (result.friendlyError != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(result.friendlyError!)));
        return;
      } else if (mounted) {
        setState(() {
          _notesLocalOnly = false;
        });
      }
    }

    final updated = [..._notes]..removeAt(index);
    final reindexed = _withPositions(updated);
    await _syncNotes(
      reindexed,
      activeIndex: reindexed.isEmpty ? 0 : (index - 1),
      persistOrder: true,
    );
  }

  Future<void> _reorderNotes(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex -= 1;
    if (oldIndex == newIndex) return;
    final updated = [..._notes];
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);

    var newActive = _activeNoteIndex;
    if (_activeNoteIndex == oldIndex) {
      newActive = newIndex;
    } else {
      if (_activeNoteIndex > oldIndex && _activeNoteIndex <= newIndex) {
        newActive -= 1;
      } else if (_activeNoteIndex < oldIndex && _activeNoteIndex >= newIndex) {
        newActive += 1;
      }
    }

    final reindexed = _withPositions(updated);
    await _syncNotes(
      reindexed,
      activeIndex: newActive,
      persistOrder: true,
    );
  }

  Widget _noteCard(
    BuildContext context,
    RhythmNote note, {
    required int index,
    bool fullscreen = false,
  }) {
    final size = MediaQuery.of(context).size;
    final card = Container(
      width: fullscreen ? size.width - 24 : null,
      constraints: fullscreen
          ? BoxConstraints(
              minHeight: size.height * 0.35,
              maxHeight: size.height * 0.8,
            )
          : null,
      padding: fullscreen ? const EdgeInsets.all(24) : const EdgeInsets.all(18),
      margin: fullscreen
          ? null
          : const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: RhythmTheme.aurora.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 18,
            spreadRadius: 2,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: fullscreen
          ? LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 10,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Center(
                      child: KemeticGold.text(
                        note.text,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'GentiumPlus',
                          height: 1.15,
                        ),
                        maxLines: null,
                        softWrap: true,
                      ),
                    ),
                  ),
                );
              },
            )
          : Center(
              child: KemeticGold.text(
                note.text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'GentiumPlus',
                  height: 1.15,
                ),
                maxLines: 6,
                softWrap: true,
              ),
            ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: fullscreen ? null : () => _enterFullscreen(index),
      onLongPress: _showNotePicker,
      child: Stack(
        children: [
          card,
          Positioned(
            top: 4,
            right: 4,
            child: PopupMenuButton<String>(
              color: Colors.black87,
              icon: const Icon(Icons.more_vert, color: Colors.white70),
              onSelected: (value) {
                if (value == 'edit') {
                  unawaited(_editNote(index));
                } else if (value == 'delete') {
                  unawaited(_deleteNote(index));
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: Text('Edit', style: TextStyle(color: Colors.white)),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return RhythmSectionCard(
      title: 'Notes',
      subtitle: 'Affirmations to keep front-of-mind. Double-tap to spotlight.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_notesLocalOnly)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.orangeAccent.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.cloud_off, color: Colors.orangeAccent, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Planner notes are saved only on this device. Cloud sync is unavailable.',
                      style: RhythmTheme.subheading.copyWith(
                        color: Colors.orangeAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Stack(
            children: [
              TextField(
                controller: _noteInputController,
                minLines: 2,
                maxLines: 4,
                style: RhythmTheme.subheading,
                decoration: InputDecoration(
                  hintText: 'Write a note, affirmation, or reminder',
                  hintStyle: RhythmTheme.subheading.copyWith(
                    color: Colors.white38,
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: RhythmTheme.aurora.withValues(alpha: 0.6),
                    ),
                  ),
                  contentPadding: const EdgeInsets.fromLTRB(14, 14, 70, 14),
                ),
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.newline,
                onSubmitted: (_) => unawaited(_addNote()),
              ),
              Positioned(
                right: 8,
                bottom: 8,
                child: FloatingActionButton.small(
                  heroTag:
                      widget.embedded ? null : 'today_alignment_add_note',
                  backgroundColor: RhythmTheme.aurora,
                  foregroundColor: Colors.black,
                  onPressed: () => unawaited(_addNote()),
                  child: const Icon(Icons.add, size: 22),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_notes.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Text(
                'No notes yet. Add a quick reminder to keep it in your field today.',
                style: RhythmTheme.subheading,
              ),
            )
          else
            Column(
              children: [
                SizedBox(
                  height: 200,
                  child: PageView.builder(
                    controller: _notePageController,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _notes.length,
                    onPageChanged: (index) {
                      if (_isSyncingNotePages) {
                        setState(() {
                          _activeNoteIndex = index;
                          if (_fullscreenNote != null) {
                            _fullscreenNote = _notes[index];
                          }
                        });
                        return;
                      }
                      unawaited(_jumpToNote(index));
                    },
                    itemBuilder: (context, index) {
                      return _noteCard(context, _notes[index], index: index);
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int i = 0; i < _notes.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        width: _activeNoteIndex == i ? 18 : 8,
                        decoration: BoxDecoration(
                          color: _activeNoteIndex == i
                              ? RhythmTheme.aurora
                              : Colors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    IconButton(
                      onPressed: _showNotePicker,
                      icon: const Icon(
                        Icons.list_alt,
                        color: Colors.white70,
                        size: 20,
                      ),
                      tooltip: 'See all notes',
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _fullscreenOverlay() {
    if (_fullscreenNote == null || _notes.isEmpty)
      return const SizedBox.shrink();
    _fullscreenPageController ??= PageController(initialPage: _activeNoteIndex);
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _closeFullscreen,
        child: Container(
          color: Colors.black.withValues(alpha: 0.92),
          child: SafeArea(
            child: Stack(
              children: [
                PageView.builder(
                  controller: _fullscreenPageController,
                  itemCount: _notes.length,
                  physics: const PageScrollPhysics(),
                  onPageChanged: (index) {
                    unawaited(_jumpToNote(index, fromOverlay: true));
                  },
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 28,
                      ),
                      child: _noteCard(
                        context,
                        _notes[index],
                        index: index,
                        fullscreen: true,
                      ),
                    );
                  },
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: IconButton(
                    onPressed: _closeFullscreen,
                    icon: const Icon(Icons.close, color: Colors.white70),
                    tooltip: 'Close',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _plannerContent(String dateLabel, {bool embedded = false}) {
    final content = FutureBuilder<void>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: RhythmLoadingShell(),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: RhythmErrorStateCard(
              title: 'The day is still forming',
              message: RhythmUserMessages.loadInterrupted,
              onRetry: () {
                setState(() {
                  _future = _load();
                });
              },
            ),
          );
        }

        if (_missingTables) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: RhythmErrorStateCard(
              title: 'Today’s Alignment isn’t ready yet.',
              message:
                  'This environment is missing the rhythm tables. You can retry after migrations run.',
              onRetry: () {
                setState(() {
                  _future = _load();
                });
              },
            ),
          );
        }

        if (_friendlyError != null) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: RhythmErrorStateCard(
              title: 'The day is still forming',
              message: _friendlyError!,
              onRetry: () {
                setState(() {
                  _future = _load();
                });
              },
            ),
          );
        }

        final progress = _progress();

        final list = ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            RhythmSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  KemeticGold.text(
                    'Planner',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'GentiumPlus',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Move through today with clarity and grace.',
                    style: RhythmTheme.subheading,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: RhythmTheme.frostSurface(),
                        child: KemeticGold.icon(
                          Icons.wb_sunny_rounded,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(dateLabel, style: RhythmTheme.subheading),
                            const SizedBox(height: 6),
                            LinearProgressIndicator(
                              value: progress,
                              minHeight: 8,
                              backgroundColor: Colors.white12,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                RhythmTheme.aurora,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${(progress * 100).round()}% aligned so far',
                              style: RhythmTheme.subheading.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _buildNotesSection(),
            const SizedBox(height: 14),
            RhythmSectionCard(
              title: 'To Do',
              subtitle: 'Add what you want to move today. Tap below to add.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _commitmentInputController,
                    style: RhythmTheme.subheading,
                    decoration: InputDecoration(
                      hintText: 'Type a commitment, then press return',
                      hintStyle: RhythmTheme.subheading.copyWith(
                        color: Colors.white38,
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.06),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: RhythmTheme.aurora.withValues(alpha: 0.6),
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      isDense: true,
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => unawaited(_commitNewTodo()),
                  ),
                  if (_todos.isNotEmpty) const SizedBox(height: 14),
                  for (int i = 0; i < _todos.length; i++) ...[
                    RhythmTodoRow(
                      todo: _todos[i],
                      onStateChanged: (state) =>
                          unawaited(_persistTodoState(i, state)),
                    ),
                    if (i != _todos.length - 1)
                      const Divider(
                        height: 18,
                        thickness: 0.6,
                        color: Colors.white12,
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            RhythmSectionCard(
              title: 'Completed',
              subtitle: 'Moments you already honored.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _completed().isEmpty
                    ? [
                        Text(
                          'Nothing checked off yet. Start small; one step brings momentum.',
                          style: RhythmTheme.subheading,
                        ),
                      ]
                    : _completed()
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6.0),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.greenAccent,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item.title,
                                    style: RhythmTheme.subheading,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
              ),
            ),
          ],
        );

        return Stack(children: [list, _fullscreenOverlay()]);
      },
    );

    return Container(
      color: Colors.black,
      child: SafeArea(
        top: !embedded,
        bottom: true,
        left: true,
        right: true,
        child: content,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('EEEE · MMM d, yyyy').format(DateTime.now());
    final content = _plannerContent(dateLabel, embedded: widget.embedded);

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: KemeticGold.text(
          'Planner',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            fontFamily: 'GentiumPlus',
          ),
        ),
      ),
      body: content,
    );
  }

  double _progress() {
    // Primary progress is driven by To Do list completion.
    if (_todos.isNotEmpty) {
      final totalTodos = _todos.length.toDouble();
      final doneTodos = _todos
          .where((t) => t.state == RhythmItemState.done)
          .length;
      final partialTodos = _todos
          .where((t) => t.state == RhythmItemState.partial)
          .length;
      return (doneTodos + partialTodos * 0.5) / totalTodos;
    }

    // Fallback: use alignment items if no to-dos exist.
    if (_alignmentItems.isEmpty) return 0;
    final totalAlignment = _alignmentItems.length.toDouble();
    final doneAlignment = _alignmentItems
        .where((i) => i.state == RhythmItemState.done)
        .length;
    final partialAlignment = _alignmentItems
        .where((i) => i.state == RhythmItemState.partial)
        .length;
    return (doneAlignment + partialAlignment * 0.5) / totalAlignment;
  }

  List<RhythmItem> _completed() {
    final doneAlignment = _alignmentItems.where(
      (i) => i.state == RhythmItemState.done,
    );
    final doneTodos = _todos
        .where((t) => t.state == RhythmItemState.done)
        .map(
          (t) => RhythmItem(
            title: t.title,
            summary: t.notes ?? 'Completed',
            chips: const [RhythmChipKind.alignment],
            state: RhythmItemState.done,
          ),
        );
    return [...doneAlignment, ...doneTodos];
  }
}
