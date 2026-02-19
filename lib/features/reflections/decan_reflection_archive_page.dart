import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/decan_reflection_repo.dart';
import '../../data/decan_reflection_model.dart';
import 'decan_reflection_detail_page.dart';

class DecanReflectionArchivePage extends StatefulWidget {
  const DecanReflectionArchivePage({super.key});

  @override
  State<DecanReflectionArchivePage> createState() => _DecanReflectionArchivePageState();
}

class _DecanReflectionArchivePageState extends State<DecanReflectionArchivePage> {
  final _repo = DecanReflectionRepo(Supabase.instance.client);
  List<DecanReflection> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _repo.listMine();
    if (!mounted) return;
    setState(() {
      _items = data;
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
        iconTheme: const IconThemeData(color: Color(0xFFD4AF37)),
        title: const Text(
          'Decan Reflections',
          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Color(0xFFD4AF37)),
              ),
            )
          : _items.isEmpty
              ? Center(
                  child: Text(
                    'No reflections yet',
                    style: TextStyle(color: Colors.white.withOpacity(0.7)),
                  ),
                )
              : ListView.separated(
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const Divider(color: Color(0xFF222222), height: 1),
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    final dateRange =
                        '${item.decanStart.toLocal().toIso8601String().split("T").first} → ${item.decanEnd.toLocal().toIso8601String().split("T").first}';
                    final preview = item.reflectionText.length > 120
                        ? '${item.reflectionText.substring(0, 120)}…'
                        : item.reflectionText;
                    return ListTile(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => DecanReflectionDetailPage(reflectionId: item.id),
                          ),
                        );
                      },
                      title: Text(
                        item.decanName,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            dateRange,
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            preview,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
