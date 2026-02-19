import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/decan_reflection_repo.dart';
import '../../data/decan_reflection_model.dart';

class DecanReflectionDetailPage extends StatefulWidget {
  final String reflectionId;
  const DecanReflectionDetailPage({super.key, required this.reflectionId});

  @override
  State<DecanReflectionDetailPage> createState() => _DecanReflectionDetailPageState();
}

class _DecanReflectionDetailPageState extends State<DecanReflectionDetailPage> {
  final _repo = DecanReflectionRepo(Supabase.instance.client);
  DecanReflection? _reflection;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _repo.getById(widget.reflectionId);
    if (!mounted) return;
    setState(() {
      _reflection = data;
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
        title: Text(
          _reflection?.decanName ?? 'Decan Reflection',
          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Color(0xFFD4AF37)),
              ),
            )
          : _reflection == null
              ? Center(
                  child: Text(
                    'Reflection not found',
                    style: TextStyle(color: Colors.white.withOpacity(0.7)),
                  ),
                )
              : _buildBody(_reflection!),
    );
  }

  Widget _buildBody(DecanReflection reflection) {
    final dateRange =
        '${reflection.decanStart.toLocal().toIso8601String().split("T").first} → ${reflection.decanEnd.toLocal().toIso8601String().split("T").first}';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            reflection.decanName,
            style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          if (reflection.decanTheme != null && reflection.decanTheme!.isNotEmpty)
            Text(
              reflection.decanTheme!,
              style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          const SizedBox(height: 6),
          Text(
            dateRange,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Text(
            reflection.reflectionText,
            style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5),
          ),
        ],
      ),
    );
  }
}
