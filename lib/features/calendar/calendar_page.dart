import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/kemetic_converter.dart';
import '../../data/local_events_repo.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});
  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final _conv = KemeticConverter();
  late DateTime _cursor; // local Gregorian date pointing at current Kemetic month

  // NEW: simple selection + inputs for the add-event sheet
  int? _selectedDay; // 1..30
  final _titleCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cursor = DateUtils.dateOnly(DateTime.now());
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kd = _conv.fromGregorian(_cursor);
    final title = kd.epagomenal ? 'Epagomenal' : '${kemeticMonths[kd.month]} Y${kd.year}';
    final subtitle = kd.season ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Kemetic Calendar')),
      body: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Row(
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      _cursor = _cursor.subtract(const Duration(days: 30));
                      _selectedDay = null; // reset selection when changing month
                    });
                  },
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    '$title${subtitle.isNotEmpty ? " • $subtitle" : ""}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _cursor = _cursor.add(const Duration(days: 30));
                      _selectedDay = null;
                    });
                  },
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),

          // Month grid (kept as-is except for onTap/onLongPress)
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 0.95,
              ),
              itemCount: 30,
              itemBuilder: (context, index) {
                final day = index + 1;

                final g = _conv.toGregorianMidnight(
                  KemeticDate(year: kd.year, month: kd.month, day: day, epagomenal: false),
                );

                final events = context.watch<LocalEventsRepo>()
                    .onKemeticDay(kd.year, kd.month, day);

                final isToday = DateUtils.isSameDay(g, DateTime.now());
                final isSelected = _selectedDay == day;

                return InkWell(
                  onTap: () => setState(() => _selectedDay = day),
                  onLongPress: () =>
                      context.read<LocalEventsRepo>().addSampleForDate(g),
                  child: Card(
                    elevation: isToday ? 2 : 0,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : (isToday ? Colors.black54 : Colors.transparent),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$day', style: const TextStyle(fontWeight: FontWeight.bold)),
                          if (events.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              margin: const EdgeInsets.only(bottom: 1),
                              decoration: BoxDecoration(
                                color: Colors.black12,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${events.length} event${events.length > 1 ? "s" : ""}',
                                style: const TextStyle(fontSize: 9),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Events list for the selected day (simple, fixed-height panel)
          if (_selectedDay != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Events for day $_selectedDay',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            SizedBox(
              height: 180,
              child: Consumer<LocalEventsRepo>(
                builder: (context, repo, _) {
                  final items = repo.onKemeticDay(kd.year, kd.month, _selectedDay!);
                  if (items.isEmpty) {
                    return const Center(child: Text('No events yet'));
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(8),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 8),
                    itemBuilder: (_, i) {
                      final e = items[i];
                      return ListTile(
                        dense: true,
                        title: Text(e.title),
                        subtitle: e.notes == null ? null : Text(e.notes!),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () =>
                              context.read<LocalEventsRepo>().removeEvent(e.id),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),

      // FAB appears only when a day is selected
      floatingActionButton: (_selectedDay == null)
          ? null
          : FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add event'),
        onPressed: () => _showAddEventSheet(context),
      ),
    );
  }

  Future<void> _showAddEventSheet(BuildContext context) async {
    _titleCtrl.clear();
    _notesCtrl.clear();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16, right: 16, top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('New event', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Title', border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)', border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      final kd = _conv.fromGregorian(_cursor);
                      final day = _selectedDay!;
                      final g = _conv.toGregorianMidnight(KemeticDate(
                        year: kd.year, month: kd.month, day: day, epagomenal: false,
                      ));

                      context.read<LocalEventsRepo>().addEvent(
                        startUtc: g.toUtc(),
                        kYear: kd.year,
                        kMonth: kd.month,
                        kDay: day,
                        title: _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim(),
                        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
                        allDay: true,
                      );

                      Navigator.pop(ctx);
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}
