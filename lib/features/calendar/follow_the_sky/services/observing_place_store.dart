import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/observing_place.dart';

class ObservingPlaceStore {
  const ObservingPlaceStore();

  static const String _key = 'haw:observing_place:v1';

  Future<ObservingPlace?> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return ObservingPlace.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } on Object {
      return null;
    }
  }

  Future<void> save(ObservingPlace place) async {
    await (await SharedPreferences.getInstance()).setString(
      _key,
      jsonEncode(place.toJson()),
    );
  }

  Future<void> clear() async {
    await (await SharedPreferences.getInstance()).remove(_key);
  }
}
