import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'insight_link_model.dart';

/// Lightweight local persistence for insight links and node user content.
/// Uses SharedPreferences with user-aware keys so we can migrate to Supabase later.
class InsightLinkRepo {
  static const _linksKey = 'insight_links';
  static const _nodeTextKey = 'node_user_content';

  Future<List<InsightLink>> fetchLinks(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userScoped(_linksKey, userId));
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => InsightLink.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('[InsightLinkRepo] failed to decode links: $e');
      }
      return [];
    }
  }

  Future<void> saveLinks(String userId, List<InsightLink> links) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(links.map((e) => e.toJson()).toList());
    await prefs.setString(_userScoped(_linksKey, userId), jsonStr);
  }

  Future<List<NodeUserContent>> fetchNodeContent(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userScoped(_nodeTextKey, userId));
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => NodeUserContent.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('[InsightLinkRepo] failed to decode node user content: $e');
      }
      return [];
    }
  }

  Future<void> saveNodeContent(
    String userId,
    List<NodeUserContent> content,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(content.map((e) => e.toJson()).toList());
    await prefs.setString(_userScoped(_nodeTextKey, userId), jsonStr);
  }

  String _userScoped(String base, String userId) => '$base:$userId';
}
