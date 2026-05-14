import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/global_bottom_menu_metrics.dart';
import '../../core/navigation_fallback.dart';
import '../../shared/glossy_text.dart';

import '../../data/decan_reflection_repo.dart';
import '../../data/decan_reflection_model.dart';

class DecanReflectionArchivePage extends StatefulWidget {
  const DecanReflectionArchivePage({super.key});

  @override
  State<DecanReflectionArchivePage> createState() =>
      _DecanReflectionArchivePageState();
}

class _DecanReflectionArchivePageState
    extends State<DecanReflectionArchivePage> {
  final _repo = DecanReflectionRepo(Supabase.instance.client);
  List<DecanReflection> _items = const [];
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    final result = await _repo.listMineResult();
    if (!mounted) return;
    setState(() {
      _items = result.data;
      _errorMessage = result.errorMessage;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final listBottomPadding = bottomPaddingAboveGlobalMenu(context, 16);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: KemeticGold.icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => popOrGo(context, '/'),
        ),
        iconTheme: const IconThemeData(color: KemeticGold.base),
        title: const Text(
          'Decan Reflections',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(KemeticGold.base),
              ),
            )
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Reflections could not load',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 18),
                    OutlinedButton.icon(
                      onPressed: _load,
                      icon: KemeticGold.icon(Icons.refresh, size: 18),
                      label: KemeticGold.text(
                        'Try again',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : _items.isEmpty
          ? Center(
              child: Text(
                'No reflections yet',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
            )
          : ListView.separated(
              padding: EdgeInsets.fromLTRB(0, 0, 0, listBottomPadding),
              itemCount: _items.length,
              separatorBuilder: (_, _) =>
                  const Divider(color: Color(0xFF222222), height: 1),
              itemBuilder: (context, index) {
                final item = _items[index];
                final dateRange =
                    '${item.decanStart.toLocal().toIso8601String().split("T").first} → ${item.decanEnd.toLocal().toIso8601String().split("T").first}';
                final preview = item.reflectionText.length > 120
                    ? '${item.reflectionText.substring(0, 120)}…'
                    : item.reflectionText;
                return ListTile(
                  onTap: () => context.go(
                    '/reflections/${Uri.encodeComponent(item.id)}',
                  ),
                  title: Text(
                    item.decanName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        dateRange,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
