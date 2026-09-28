import '../../data/event_filing_engine.dart';

enum PagesCollection {
  notes('Notes'),
  reminders('Reminders'),
  flows('Flows');

  const PagesCollection(this.label);
  final String label;
}

/// Read-only presentation of records owned by the existing filing authorities.
class PagesCollectionItem {
  const PagesCollectionItem({
    required this.id,
    required this.title,
    this.detail = '',
    this.color = 0xffd4af37,
    this.event,
    this.flowId,
  });
  final String id, title, detail;
  final int color;
  final FiledEvent? event;
  final int? flowId;
}

class PagesCollectionState {
  const PagesCollectionState({
    this.collection,
    this.items = const [],
    this.loading = false,
    this.failed = false,
    this.hasMore = false,
  });
  final PagesCollection? collection;
  final List<PagesCollectionItem> items;
  final bool loading, failed, hasMore;
}
