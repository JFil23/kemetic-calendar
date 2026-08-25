import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../domain/sky_catalog.dart';

class SkyCatalogRepository {
  SkyCatalogRepository({
    this.assetPath = 'assets/follow_the_sky/sky_catalog_v2.json',
    String Function(String path)? assetLoader,
  }) : _assetLoader = assetLoader;

  final String assetPath;
  final String Function(String path)? _assetLoader;
  SkyCatalog? _cached;

  Future<SkyCatalog> load({bool forceReload = false}) async {
    if (!forceReload && _cached != null) return _cached!;
    final raw = _assetLoader != null
        ? _assetLoader(assetPath)
        : await rootBundle.loadString(assetPath);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final catalog = SkyCatalog.fromJson(json);
    _cached = catalog;
    return catalog;
  }

  /// Pure parse for tests / headless harness without Flutter binding.
  static SkyCatalog parseJsonString(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return SkyCatalog.fromJson(json);
  }
}
