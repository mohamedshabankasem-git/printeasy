class TemplateModel {
  const TemplateModel({
    this.id,
    required this.name,
    this.type = 'dsl',
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final String name;
  final String type; // dsl أو visual
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  TemplateModel copyWith({String? name, String? content, DateTime? updatedAt}) => TemplateModel(
        id: id,
        name: name ?? this.name,
        type: type,
        content: content ?? this.content,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'type': type,
        'content': content,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  factory TemplateModel.fromMap(Map<String, Object?> m) => TemplateModel(
        id: m['id'] as int?,
        name: m['name'] as String,
        type: (m['type'] as String?) ?? 'dsl',
        content: m['content'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(m['updated_at'] as int),
      );
}
