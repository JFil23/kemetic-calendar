import 'dart:convert';
import '../../data/share_repo.dart';

/// Activity has no server row ID; retain its complete source identity.
String inboxActivityIdentity(InboxActivityItem item) => jsonEncode([
  item.type.name,
  item.actorId,
  item.flowPostId,
  item.createdAt.toUtc().toIso8601String(),
]);
