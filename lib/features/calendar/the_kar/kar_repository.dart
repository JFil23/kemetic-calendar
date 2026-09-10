import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'the_kar_models.dart';

abstract interface class KarRepository {
  Future<KarShrine> loadOrCreate(KarNetjer netjer);
  Future<KarShrine> save(KarShrine shrine);
}

class KarRevisionConflict implements Exception {
  const KarRevisionConflict();

  @override
  String toString() => 'This Kꜣr changed elsewhere. Reload before saving.';
}

class SupabaseKarRepository implements KarRepository {
  SupabaseKarRepository(this._client);

  final SupabaseClient _client;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null || id.trim().isEmpty) {
      throw StateError('Sign in to keep a private Kꜣr.');
    }
    return id;
  }

  @override
  Future<KarShrine> loadOrCreate(KarNetjer netjer) async {
    final userId = _userId;
    final existing = await _client
        .from('kar_shrines')
        .select()
        .eq('user_id', userId)
        .eq('netjer_key', netjer.key)
        .maybeSingle();
    if (existing != null) return KarShrine.fromRow(existing);

    try {
      final inserted = await _client
          .from('kar_shrines')
          .insert(<String, dynamic>{
            'id': const Uuid().v4(),
            'user_id': userId,
            'netjer_key': netjer.key,
            'state': const <String, dynamic>{
              'schema_version': 1,
              'active_cycle_id': null,
              'cycles': <dynamic>[],
              'drafts': <String, dynamic>{},
            },
          })
          .select()
          .single();
      return KarShrine.fromRow(inserted);
    } on PostgrestException catch (error) {
      // A second client may have created the permanent user/netjer row first.
      if (error.code != '23505') rethrow;
      final raced = await _client
          .from('kar_shrines')
          .select()
          .eq('user_id', userId)
          .eq('netjer_key', netjer.key)
          .single();
      return KarShrine.fromRow(raced);
    }
  }

  @override
  Future<KarShrine> save(KarShrine shrine) async {
    final updated = await _client
        .from('kar_shrines')
        .update(<String, dynamic>{
          'state': shrine.toStateJson(),
          'revision': shrine.revision + 1,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', shrine.id)
        .eq('user_id', _userId)
        .eq('revision', shrine.revision)
        .select()
        .maybeSingle();
    if (updated == null) throw const KarRevisionConflict();
    return KarShrine.fromRow(updated);
  }
}

class MemoryKarRepository implements KarRepository {
  MemoryKarRepository({Map<KarNetjer, KarShrine>? initial})
    : _shrines = {...?initial};

  final Map<KarNetjer, KarShrine> _shrines;

  @override
  Future<KarShrine> loadOrCreate(KarNetjer netjer) async {
    return _shrines.putIfAbsent(
      netjer,
      () => KarShrine(
        id: 'memory-${netjer.key}',
        netjer: netjer,
        revision: 0,
        cycles: const [],
      ),
    );
  }

  @override
  Future<KarShrine> save(KarShrine shrine) async {
    final current = _shrines[shrine.netjer];
    if (current != null && current.revision != shrine.revision) {
      throw const KarRevisionConflict();
    }
    final saved = shrine.copyWith(revision: shrine.revision + 1);
    _shrines[shrine.netjer] = saved;
    return saved;
  }
}
