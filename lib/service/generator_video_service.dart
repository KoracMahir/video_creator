import 'dart:io';
import 'package:rxdart/rxdart.dart';

import '../dao/project_dao.dart';
import '../model/generator_video.dart';
import '../service_locator.dart';

class GeneratedVideoService {
  final ProjectDao projectDao = locator.get<ProjectDao>();

  /// Holds the current list of generated videos for a given project.
  List<GeneratedVideo> generatedVideoList = [];

  /// The project ID associated with the current list. It can be null if not set yet.
  int? projectId;

  /// BehaviorSubject to notify listeners when the generated video list changes.
  final BehaviorSubject<bool> _generatedVideoListChanged =
  BehaviorSubject<bool>.seeded(false);

  /// Stream that others can listen to for changes.
  Stream<bool> get generatedVideoListChanged$ => _generatedVideoListChanged.stream;

  /// Returns the current value of the subject.
  bool get generatedVideoListChanged => _generatedVideoListChanged.value;

  GeneratedVideoService() {
    open();
  }

  /// Clean up any streams or resources.
  void dispose() {
    _generatedVideoListChanged.close();
  }

  /// Opens the data source (e.g., a database).
  Future<void> open() async {
    await projectDao.open();
  }

  /// Refreshes the generated video list for a given [projectId].
  Future<void> refresh(int projectId) async {
    this.projectId = projectId;
    generatedVideoList = [];
    _generatedVideoListChanged.add(true);

    generatedVideoList = await projectDao.findAllGeneratedVideo(projectId);
    _generatedVideoListChanged.add(true);
  }

  /// Checks if the file at [index] exists on disk.
  bool fileExists(int index) {
    return File(generatedVideoList[index].path).existsSync();
  }

  /// Deletes the generated video at [index] and removes it from the data source.
  Future<void> delete(int index) async {
    if (fileExists(index)) {
      File(generatedVideoList[index].path).deleteSync();
    }
    await projectDao.deleteGeneratedVideo(generatedVideoList[index].id!);

    // If we still have a valid projectId, refresh the list
    if (projectId != null) {
      await refresh(projectId!);
    }
  }
}
