import 'package:flutter/foundation.dart';

class Project {
  /// This field may be null if you haven't stored the Project yet (e.g., in a database).
  int? id;

  /// Required and non-nullable.
  String title;

  /// This can be nullable if it's optional.
  String? description;

  /// Required and non-nullable.
  DateTime date;

  /// Required and non-nullable.
  int duration;

  /// Can be nullable if it's optional.
  String? layersJson;

  /// Can be nullable if it's optional.
  String? imagePath;

  Project({
    this.id,
    required this.title,
    this.description,
    required this.date,
    required this.duration,
    this.layersJson,
    this.imagePath,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'title': title,
      'description': description,
      'date': date.millisecondsSinceEpoch,
      'duration': duration,
      'layersJson': layersJson,
      'imagePath': imagePath,
    };
    if (id != null) {
      map['_id'] = id;
    }
    return map;
  }

  factory Project.fromMap(Map<String, dynamic> map) {
    return Project(
      id: map['_id'] as int?,
      title: map['title'] as String,
      description: map['description'] as String?,
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      duration: map['duration'] as int,
      layersJson: map['layersJson'] as String?,
      imagePath: map['imagePath'] as String?,
    );
  }

  @override
  String toString() {
    return 'Project {'
        'id: $id, '
        'title: $title, '
        'description: $description, '
        'date: $date, '
        'duration: $duration, '
        'imagePath: $imagePath}';
  }
}
