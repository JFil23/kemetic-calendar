class AppHapticResult {
  const AppHapticResult({
    required this.backend,
    required this.status,
    required this.detail,
    this.accepted,
  });

  final String backend;
  final String status;
  final String detail;
  final bool? accepted;

  String get debugSummary {
    final buffer = StringBuffer('$backend:$status');
    if (accepted != null) {
      buffer.write(' accepted=$accepted');
    }
    if (detail.trim().isNotEmpty) {
      buffer.write(' - $detail');
    }
    return buffer.toString();
  }
}
