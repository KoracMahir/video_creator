import 'package:sqflite/sqflite.dart';

import '../model/generator_video.dart';
import '../model/project.dart';

class ProjectDao {
  /// We mark [db] as `late` to ensure it will be initialized before use.
  late Database db;

  /// SQL scripts that will run sequentially when the database version upgrades.
  final List<String> migrationScripts = [
    '''
    CREATE TABLE project (
      _id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      description TEXT,
      date INTEGER NOT NULL,
      duration INTEGER NOT NULL,
      layersJson TEXT,
      imagePath TEXT
    )
    ''',
    '''
    CREATE TABLE generatedVideo (
      _id INTEGER PRIMARY KEY AUTOINCREMENT,
      projectId INTEGER NOT NULL,
      path TEXT NOT NULL,
      date INTEGER NOT NULL,
      resolution TEXT,
      thumbnail TEXT
    )
    ''',
  ];

  /// Opens (and creates/updates) the database.
  Future<void> open() async {
    db = await openDatabase(
      'project',
      version: migrationScripts.length,
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        for (var i = oldVersion; i < newVersion; i++) {
          await db.execute(migrationScripts[i]);
        }
      },
    );
  }

  /// Inserts a new [Project] and returns it with its newly generated ID.
  Future<Project> insert(Project project) async {
    final id = await db.insert('project', project.toMap());
    project.id = id;
    return project;
  }

  /// Inserts a new [GeneratedVideo] and returns it with its newly generated ID.
  Future<GeneratedVideo> insertGeneratedVideo(GeneratedVideo generatedVideo) async {
    final id = await db.insert('generatedVideo', generatedVideo.toMap());
    generatedVideo.id = id;
    return generatedVideo;
  }

  /// Retrieves one [Project] by its [id]. Returns `null` if not found.
  Future<Project?> get(int id) async {
    final List<Map<String, Object?>> maps = await db.query(
      'project',
      columns: [
        '_id',
        'title',
        'description',
        'date',
        'duration',
        'layersJson',
        'imagePath',
      ],
      where: '_id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Project.fromMap(maps.first);
    }
    return null;
  }

  /// Returns all [Project] records from the database.
  Future<List<Project>> findAll() async {
    final List<Map<String, Object?>> maps = await db.query(
      'project',
      columns: [
        '_id',
        'title',
        'description',
        'date',
        'duration',
        'layersJson',
        'imagePath',
      ],
    );
    return maps.map((m) => Project.fromMap(m)).toList();
  }

  /// Returns all [GeneratedVideo] records for a given [projectId], ordered descending by `_id`.
  Future<List<GeneratedVideo>> findAllGeneratedVideo(int projectId) async {
    final List<Map<String, Object?>> maps = await db.query(
      'generatedVideo',
      columns: [
        '_id',
        'projectId',
        'path',
        'date',
        'resolution',
        'thumbnail',
      ],
      where: 'projectId = ?',
      whereArgs: [projectId],
      orderBy: '_id DESC',
    );
    return maps.map((m) => GeneratedVideo.fromMap(m)).toList();
  }

  /// Deletes a [Project] by its [id]. Returns the count of rows affected.
  Future<int> delete(int id) async {
    return await db.delete('project', where: '_id = ?', whereArgs: [id]);
  }

  /// Deletes a [GeneratedVideo] by its [id]. Returns the count of rows affected.
  Future<int> deleteGeneratedVideo(int id) async {
    return await db.delete('generatedVideo', where: '_id = ?', whereArgs: [id]);
  }

  /// Deletes *all* records from the [project] table. Returns the count of rows affected.
  Future<int> deleteAll() async {
    return await db.delete('project');
  }

  /// Updates an existing [Project]. Returns the count of rows affected.
  Future<int> update(Project project) async {
    return await db.update(
      'project',
      project.toMap(),
      where: '_id = ?',
      whereArgs: [project.id],
    );
  }

  /// Closes the database connection.
  Future<void> close() async {
    await db.close();
  }
}
