class HistoryEntry {
  const HistoryEntry({
    this.id,
    required this.title,
    required this.content,
    required this.success,
    this.error,
    required this.createdAt,
  });

  final int? id;
  final String title;
  final String content; // نص DSL النهائي بعد تعويض المتغيرات
  final bool success;
  final String? error;
  final DateTime createdAt;

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'title': title,
        'content': content,
        'status': success ? 'success' : 'failed',
        'error': error,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory HistoryEntry.fromMap(Map<String, Object?> m) => HistoryEntry(
        id: m['id'] as int?,
        title: m['title'] as String,
        content: m['content'] as String,
        success: m['status'] == 'success',
        error: m['error'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
      );
}
