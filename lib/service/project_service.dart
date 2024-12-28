import 'dart:io';

import 'package:rxdart/rxdart.dart';

import '../dao/project_dao.dart';
import '../model/project.dart';
import '../service_locator.dart';

class ProjectService {
  final ProjectDao projectDao = locator.get<ProjectDao>();

  /// List of projects, initially empty.
  List<Project> projectList = [];

  /// A single project reference. Nullable if not set.
  Project? project;

  /// We use a BehaviorSubject to track whether the project list has changed.
  final BehaviorSubject<bool> _projectListChanged =
  BehaviorSubject<bool>.seeded(false);

  /// Expose a stream to listen for changes.
  Stream<bool> get projectListChanged$ => _projectListChanged.stream;

  /// Convenient getter to get the latest value.
  bool get projectListChanged => _projectListChanged.value;

  ProjectService() {
    load();
  }

  /// Clean up resources.
  void dispose() {
    _projectListChanged.close();
  }

  /// Open the database and load projects.
  Future<void> load() async {
    await projectDao.open();
    await refresh();
  }

  /// Refresh the in-memory list of projects from the database.
  Future<void> refresh() async {
    projectList = await projectDao.findAll();
    _projectListChanged.add(true);
    checkSomeFileNotExists();
  }

  /// Check if a file no longer exists, and reset its path if not found.
  void checkSomeFileNotExists() {
    for (var proj in projectList) {
      final imagePath = proj.imagePath;
      if (imagePath != null && !File(imagePath).existsSync()) {
        print('$imagePath does not exist');
        proj.imagePath = null;
      }
    }
  }

  /// Create a new project with default values.
  Project createNew() {
    return Project(
      title: '',
      duration: 0,
      date: DateTime.now(),
    );
  }

  /// Insert a new project into the database, then refresh the list.
  Future<void> insert(Project newProject) async {
    newProject.date = DateTime.now();
    await projectDao.insert(newProject);
    await refresh();
  }

  /// Update an existing project in the database, then refresh the list.
  Future<void> update(Project updatedProject) async {
    await projectDao.update(updatedProject);
    await refresh();
  }

  /// Delete a project by its index in the current list, then refresh.
  Future<void> delete(int index) async {
    final projectId = projectList[index].id;
    if (projectId != null) {
      await projectDao.delete(projectId);
      await refresh();
    }
  }
}
