import 'package:flutter/foundation.dart';

class GeneratedVideo {
  late int? id;           // May be null if not set yet.
  final int projectId;
  final String path;
  final DateTime date;
  final String? resolution;  // Nullable if not specified.
  final String? thumbnail;   // Nullable if not specified.

  GeneratedVideo({
    required this.projectId,
    required this.path,
    required this.date,
    this.resolution,
    this.thumbnail,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      if (id != null) '_id': id,
      'projectId': projectId,
      'path': path,
      'date': date.millisecondsSinceEpoch,
      'resolution': resolution,
      'thumbnail': thumbnail,
    };
  }

  factory GeneratedVideo.fromMap(Map<String, dynamic> map) {
    return GeneratedVideo(
      projectId: map['projectId'] as int,
      path: map['path'] as String,
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      resolution: map['resolution'] as String?,
      thumbnail: map['thumbnail'] as String?,
    );
  }

  @override
  String toString() {
    return 'GeneratedVideo {'
        'id: $id, '
        'projectId: $projectId, '
        'path: $path, '
        'date: $date, '
        'resolution: $resolution, '
        'thumbnail: $thumbnail}';
  }
}
