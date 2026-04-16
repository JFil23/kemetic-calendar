import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/shared/glossy_text.dart';
import '../calendar/calendar_page.dart';
import '../../data/share_repo.dart';
import '../../data/share_models.dart';

class SharePreviewPage extends StatefulWidget {
  final String shareId;
  final String? token;

  const SharePreviewPage({super.key, required this.shareId, this.token});

  @override
  State<SharePreviewPage> createState() => _SharePreviewPageState();
}

class _SharePreviewPageState extends State<SharePreviewPage> {
  final _repo = ShareRepo(Supabase.instance.client);

  bool _loading = true;
  bool _importing = false;
  String? _error;
  Map<String, dynamic>? _shareData;

  @override
  void initState() {
    super.initState();
    _loadShare();
  }

  Future<void> _loadShare() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await _repo.resolveShare(
        shareId: widget.shareId,
        token: widget.token,
      );

      setState(() {
        _shareData = Map<String, dynamic>.from(data);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _importFlow() async {
    final importData = _buildImportData();
    if (importData == null) return;

    setState(() => _importing = true);

    try {
      final flowId = await CalendarPage.importFlowFromShare(
        context,
        importData,
      );
      if (!mounted || flowId == null) return;

      await _repo.markImported(widget.shareId, isFlow: true);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Flow imported successfully!'),
          backgroundColor: KemeticGold.base,
        ),
      );

      context.go('/');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _importing = false);
      }
    }
  }

  void _closePreview() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    context.go('/');
  }

  Map<String, dynamic>? _resolvedFlowData() {
    final data = _shareData;
    if (data == null) return null;

    final flow = data['flow'];
    if (flow is Map) {
      return Map<String, dynamic>.from(flow);
    }

    if (data['name'] != null ||
        data['notes'] != null ||
        data['rules'] != null) {
      return Map<String, dynamic>.from(data);
    }

    return null;
  }

  Map<String, dynamic>? _resolvedSenderData() {
    final data = _shareData;
    if (data == null) return null;

    final sender = data['sender'];
    if (sender is Map) {
      return Map<String, dynamic>.from(sender);
    }

    final displayName =
        data['sender_name'] ??
        data['display_name'] ??
        data['sender_display_name'];
    final handle = data['sender_handle'] ?? data['handle'];
    final avatarUrl = data['sender_avatar'] ?? data['avatar_url'];
    final senderId = data['sender_id'];

    if (displayName == null &&
        handle == null &&
        avatarUrl == null &&
        senderId == null) {
      return null;
    }

    return <String, dynamic>{
      'id': senderId,
      'display_name': displayName,
      'handle': handle,
      'avatar_url': avatarUrl,
    };
  }

  Map<String, dynamic>? _resolvedScheduleData() {
    final data = _shareData;
    if (data == null) return null;

    final direct = data['suggested_schedule'];
    if (direct is Map) {
      return Map<String, dynamic>.from(direct);
    }

    final share = data['share'];
    if (share is Map && share['suggested_schedule'] is Map) {
      return Map<String, dynamic>.from(share['suggested_schedule'] as Map);
    }

    return null;
  }

  String? _resolvedImportedAt() {
    final data = _shareData;
    if (data == null) return null;

    final direct = data['imported_at'];
    if (direct is String && direct.isNotEmpty) return direct;

    final share = data['share'];
    if (share is Map) {
      final nested = share['imported_at'];
      if (nested is String && nested.isNotEmpty) return nested;
    }

    return null;
  }

  DateTime? _tryParseDateTime(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  String _flowName(Map<String, dynamic> flow) {
    final name = flow['name'] as String?;
    if (name != null && name.trim().isNotEmpty) {
      return name.trim();
    }
    return 'Untitled Flow';
  }

  String? _nullableString(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  List<dynamic> _coerceList(Object? raw) {
    if (raw is List) return raw;
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) return decoded;
      } catch (_) {}
    }
    return const [];
  }

  int _resolveColorValue(Object? raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) {
      final cleaned = raw.replaceFirst('#', '').trim();
      final rgb = int.tryParse(cleaned, radix: 16);
      if (rgb != null) {
        return cleaned.length <= 6 ? (0xFF000000 | rgb) : rgb;
      }
    }
    return 0xFF4DD0E1;
  }

  SuggestedSchedule? _buildSuggestedSchedule() {
    final raw = _resolvedScheduleData();
    if (raw == null) return null;
    final schedule = SuggestedSchedule.fromJson(Map<String, dynamic>.from(raw));
    if (schedule.normalizedStartDate == null && schedule.weekdays.isEmpty) {
      return null;
    }
    return schedule;
  }

  ImportFlowData? _buildImportData() {
    final flow = _resolvedFlowData();
    if (flow == null) return null;

    final sender = _resolvedSenderData();
    final schedule = _buildSuggestedSchedule();
    final rules = _coerceList(flow['rules']);
    final events = _coerceList(flow['events']);
    final color = _resolveColorValue(flow['color']);
    final originFlowId = switch (flow['id']) {
      int value => value,
      num value => value.toInt(),
      String value => int.tryParse(value),
      _ => null,
    };

    final share = InboxShareItem(
      shareId: widget.shareId,
      kind: InboxShareKind.flow,
      recipientId: (_shareData?['recipient_id'] as String?) ?? '',
      senderId:
          (_shareData?['sender_id'] as String?) ??
          (sender?['id'] as String?) ??
          '',
      senderHandle: sender?['handle'] as String?,
      senderName: sender?['display_name'] as String?,
      senderAvatar: sender?['avatar_url'] as String?,
      payloadId: (flow['id'] ?? widget.shareId).toString(),
      title: _flowName(flow),
      createdAt:
          _tryParseDateTime(_shareData?['created_at'] as String?) ??
          DateTime.now(),
      importedAt: _tryParseDateTime(_resolvedImportedAt()),
      suggestedSchedule: schedule,
      payloadJson: {
        'name': _flowName(flow),
        'color': color,
        if (_nullableString(flow['notes']) != null)
          'notes': _nullableString(flow['notes']),
        'rules': rules,
        if (events.isNotEmpty) 'events': events,
      },
    );

    return ImportFlowData(
      share: share,
      name: _flowName(flow),
      color: color,
      notes: _nullableString(flow['notes']),
      rules: rules,
      suggestedStartDate: schedule != null
          ? DateTime.tryParse(schedule.startDate)
          : null,
      originFlowId: originFlowId,
      rootFlowId: originFlowId,
      originType: 'share_import',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text('Shared Flow', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: KemeticGold.icon(Icons.close),
          onPressed: _closePreview,
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: KemeticGold.base),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Failed to load share',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadShare,
                style: ElevatedButton.styleFrom(
                  backgroundColor: KemeticGold.base,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final flow = _resolvedFlowData();
    if (flow == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'This share is missing flow data.',
            style: TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final sender = _resolvedSenderData();
    final schedule = _buildSuggestedSchedule();
    final importedAt = _resolvedImportedAt();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sender != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D0F),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: KemeticGold.base,
                    backgroundImage: sender['avatar_url'] != null
                        ? NetworkImage(sender['avatar_url'] as String)
                        : null,
                    child: sender['avatar_url'] == null
                        ? Text(
                            (sender['display_name'] as String? ?? 'U')[0]
                                .toUpperCase(),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sender['display_name'] as String? ?? 'Unknown',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '@${sender['handle'] ?? 'user'}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Flow details
          Text(
            'SHARED FLOW',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _flowName(flow),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          if (_nullableString(flow['notes']) != null) ...[
            const SizedBox(height: 12),
            Text(
              _nullableString(flow['notes'])!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 16,
              ),
            ),
          ],

          // Schedule info (if available)
          if (schedule != null) ...[
            const SizedBox(height: 24),
            Text(
              'Suggested Schedule',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D0F),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: KemeticGold.base.withValues(alpha: 0.3)),
              ),
              child: Text(
                _formatSchedule(schedule),
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ],

          const SizedBox(height: 32),

          // Import button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: importedAt != null || _importing ? null : _importFlow,
              style: ElevatedButton.styleFrom(
                backgroundColor: KemeticGold.base,
                foregroundColor: Colors.black,
                disabledBackgroundColor: Colors.grey.shade800,
                disabledForegroundColor: Colors.grey.shade600,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _importing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : Text(
                      importedAt != null
                          ? 'Already Imported'
                          : 'Import to My Calendar',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),

          // Close button
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              onPressed: _closePreview,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white, width: 1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Close',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatSchedule(SuggestedSchedule schedule) {
    final startDate = schedule.normalizedStartDate ?? 'unscheduled';
    final days = schedule.weekdayLabels.join(', ');
    if (days.isEmpty) {
      return 'Starting $startDate';
    }
    return 'Starting $startDate\n$days';
  }
}
