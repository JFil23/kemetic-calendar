/// Primary category labels used for events/notes/journal.
/// Stored in Supabase as plain text; keep flexible and optional.
class NoteCategory {
  static const body = 'Body';
  static const mind = 'Mind';
  static const spirit = 'Spirit';
  static const work = 'Work';
  static const home = 'Home';
  static const creation = 'Creation';
  static const connection = 'Connection';
  static const recovery = 'Recovery';

  /// Ordered list for pickers.
  static const all = [
    body,
    mind,
    spirit,
    work,
    home,
    creation,
    connection,
    recovery,
  ];
}
