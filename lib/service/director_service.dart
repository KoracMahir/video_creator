import 'dart:io';
import 'dart:math' as math;
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:rxdart/rxdart.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:video_creator/service/project_service.dart';

import '../dao/project_dao.dart';
import '../model/generator_video.dart';
import '../model/model.dart';
import '../model/project.dart';
import '../service_locator.dart';
import 'director/generator.dart';
import 'director/layer_player.dart';

class DirectorService {
  /// The currently open [Project]. Nullable until set in [setProject].
  Project? project;

  final logger = locator.get<Logger>();
  final projectService = locator.get<ProjectService>();
  final generator = locator.get<Generator>();
  final projectDao = locator.get<ProjectDao>();

  /// The top-level list of layers in this project. Non-nullable and
  /// initialized to an empty list, then replaced in [setProject].
  List<Layer> layers = [];

  // ---------------------------------------------------------------------------
  // Flags for concurrency
  // ---------------------------------------------------------------------------
  bool isEntering = false;
  bool isExiting = false;
  bool isPlaying = false;
  bool isPreviewing = false;
  bool isDragging = false;
  bool isSizerDragging = false;
  bool isCutting = false;
  bool isScaling = false;
  bool isAdding = false;
  bool isDeleting = false;
  bool isGenerating = false;

  /// Determines if any "operation" is in progress.
  bool get isOperating =>
      (isEntering ||
          isExiting ||
          isPlaying ||
          isPreviewing ||
          isDragging ||
          isSizerDragging ||
          isCutting ||
          isScaling ||
          isAdding ||
          isDeleting ||
          isGenerating);

  double? _pixelsPerSecondOnInitScale;
  double? _scrollOffsetOnInitScale;
  double dxSizerDrag = 0;
  bool isSizerDraggingEnd = false;

  // ---------------------------------------------------------------------------
  // Not-exist files flag
  // ---------------------------------------------------------------------------
  final BehaviorSubject<bool> _filesNotExist = BehaviorSubject<bool>.seeded(false);
  Stream<bool> get filesNotExist$ => _filesNotExist.stream;
  bool get filesNotExist => _filesNotExist.value;

  // ---------------------------------------------------------------------------
  // Layer players
  // ---------------------------------------------------------------------------
  /// List of layer players, which can contain `null` for placeholders (e.g. layer 1).
  List<LayerPlayer?> layerPlayers = [];

  // ---------------------------------------------------------------------------
  // Scroll controller
  // ---------------------------------------------------------------------------
  final ScrollController scrollController = ScrollController();

  // ---------------------------------------------------------------------------
  // Layers changed
  // ---------------------------------------------------------------------------
  final BehaviorSubject<bool> _layersChanged = BehaviorSubject<bool>.seeded(false);
  Stream<bool> get layersChanged$ => _layersChanged.stream;
  bool get layersChanged => _layersChanged.value;

  // ---------------------------------------------------------------------------
  // Selected
  // ---------------------------------------------------------------------------
  final BehaviorSubject<Selected> _selected =
  BehaviorSubject<Selected>.seeded(Selected(layerIndex: -1, assetIndex: -1));
  Stream<Selected> get selected$ => _selected.stream;
  Selected get selected => _selected.value;

  /// Returns the currently selected asset, or `null` if none is valid.
  Asset? get assetSelected {
    if (selected.layerIndex == -1 || selected.assetIndex == -1) return null;
    return layers[selected.layerIndex].assets[selected.assetIndex];
  }

  // ---------------------------------------------------------------------------
  // Pixels-per-second (zoom factor on timeline)
  // ---------------------------------------------------------------------------
  static const double DEFAULT_PIXELS_PER_SECONDS = 100.0 / 5.0;

  final BehaviorSubject<double> _pixelsPerSecond =
  BehaviorSubject<double>.seeded(DEFAULT_PIXELS_PER_SECONDS);
  Stream<double> get pixelsPerSecond$ => _pixelsPerSecond.stream;
  double get pixelsPerSecond => _pixelsPerSecond.value;

  // ---------------------------------------------------------------------------
  // AppBar refresh
  // ---------------------------------------------------------------------------
  final BehaviorSubject<bool> _appBar = BehaviorSubject<bool>.seeded(false);
  Stream<bool> get appBar$ => _appBar.stream;

  // ---------------------------------------------------------------------------
  // Position
  // ---------------------------------------------------------------------------
  final BehaviorSubject<int> _position = BehaviorSubject<int>.seeded(0);
  Stream<int> get position$ => _position.stream;
  int get position => _position.value;

  // ---------------------------------------------------------------------------
  // Editing text asset
  // ---------------------------------------------------------------------------
  final BehaviorSubject<Asset?> _editingTextAsset =
  BehaviorSubject<Asset?>.seeded(null);
  Stream<Asset?> get editingTextAsset$ => _editingTextAsset.stream;
  Asset? get editingTextAsset => _editingTextAsset.value;
  set editingTextAsset(Asset? value) {
    _editingTextAsset.add(value);
    _appBar.add(true);
  }

  // ---------------------------------------------------------------------------
  // Editing color
  // ---------------------------------------------------------------------------
  final BehaviorSubject<String?> _editingColor =
  BehaviorSubject<String?>.seeded(null);
  Stream<String?> get editingColor$ => _editingColor.stream;
  String? get editingColor => _editingColor.value;
  set editingColor(String? value) {
    _editingColor.add(value);
    _appBar.add(true);
  }

  // ---------------------------------------------------------------------------
  // Constructor and Disposal
  // ---------------------------------------------------------------------------
  DirectorService() {
    scrollController.addListener(_listenerScrollController);

    /// Save the project whenever layers change
    _layersChanged.listen((_) => _saveProject());
  }

  void dispose() {
    _layersChanged.close();
    _selected.close();
    _pixelsPerSecond.close();
    _position.close();
    _appBar.close();
    _editingTextAsset.close();
    _editingColor.close();
    _filesNotExist.close();
  }

  // ---------------------------------------------------------------------------
  // Time getters
  // ---------------------------------------------------------------------------
  String get positionMinutes {
    final minutes = (position / 1000 / 60).floor();
    return (minutes < 10) ? '0$minutes' : minutes.toString();
  }

  String get positionSeconds {
    final minutes = (position / 1000 / 60).floor();
    final seconds = (((position / 1000) - minutes * 60) * 10).floor() / 10;
    return (seconds < 10) ? '0$seconds' : seconds.toString();
  }

  /// Returns the total duration across all layers, ignoring blank text-only items.
  int get duration {
    var maxDuration = 0;
    for (int i = 0; i < layers.length; i++) {
      for (int j = layers[i].assets.length - 1; j >= 0; j--) {
        if (!(i == 1 && layers[i].assets[j].title == '')) {
          final dur = layers[i].assets[j].begin! + layers[i].assets[j].duration!;
          maxDuration = math.max(maxDuration, dur);
          break;
        }
      }
    }
    return maxDuration;
  }

  // ---------------------------------------------------------------------------
  // Project management
  // ---------------------------------------------------------------------------
  Future<void> setProject(Project newProject) async {
    isEntering = true;

    // Reset relevant streams
    _position.add(0);
    _selected.add(Selected(layerIndex: -1, assetIndex: -1));
    editingTextAsset = null;
    _editingColor.add(null);
    _pixelsPerSecond.add(DEFAULT_PIXELS_PER_SECONDS);
    _appBar.add(true);

    // If it's a different project, load layers, etc.
    if (project != newProject) {
      project = newProject;

      // If no layers JSON, create a default set
      if (project!.layersJson == null) {
        layers = [
          Layer(type: 'raster', volume: 0.1),
          Layer(type: 'vector'),
          Layer(type: 'audio', volume: 1.0),
        ];
      } else {
        layers = (json.decode(project!.layersJson!) as List)
            .map((layerMap) => Layer.fromJson(layerMap))
            .toList();
        _filesNotExist.add(checkSomeFileNotExists());
      }
      _layersChanged.add(true);

      // Initialize layer players
      layerPlayers = <LayerPlayer?>[];
      for (int i = 0; i < layers.length; i++) {
        if (i == 1) {
          // Possibly a placeholder for text layer
          layerPlayers.add(null);
        } else {
          final layerPlayer = LayerPlayer(layers[i]);
          await layerPlayer.initialize(); // Ensure this is awaited
          layerPlayers.add(layerPlayer);
        }
      }

      for (final layerPlayer in layerPlayers) {
        if (layerPlayer != null) {
          for (final asset in layerPlayer.layer.assets) {
            if (asset.type == AssetType.video) {
              await layerPlayer.preview(asset.begin!);
            }
          }
        }
      }
    }

    isEntering = false;
    await _previewOnPosition(); // Ensure previews are triggered after initialization
  }

  /// Returns `true` if any file no longer exists on disk.
  bool checkSomeFileNotExists() {
    var someFileNotExists = false;
    for (final layer in layers) {
      for (final asset in layer.assets) {
        if (asset.srcPath.isNotEmpty && !File(asset.srcPath).existsSync()) {
          asset.deleted = true;
          someFileNotExists = true;
          print('${asset.srcPath} does not exist');
        }
      }
    }
    return someFileNotExists;
  }

  /// Exits the project by stopping playback, saving, disposing players, etc.
  Future<bool> exitAndSaveProject() async {
    if (isPlaying) await stop();
    if (isOperating) return false;
    isExiting = true;
    _saveProject();

    Future.delayed(const Duration(milliseconds: 500), () {
      project = null;
      for (var layerPlayer in layerPlayers) {
        layerPlayer?.dispose();
      }
      layerPlayers.clear();
      isExiting = false;
    });

    _deleteThumbnailsNotUsed();
    return true;
  }

  /// Saves the current project, including updated layers JSON and thumbnail.
  void _saveProject() {
    // If layers are uninitialized, do nothing.
    if (layers.isEmpty || project == null) return;

    project!.layersJson = json.encode(layers);
    project!.imagePath = layers.isNotEmpty && layers[0].assets.isNotEmpty
        ? getFirstThumbnailMedPath()
        : null;
    projectService.update(project!);
  }

  /// Returns the first non-null, existing medium thumbnail from the first layer.
  String? getFirstThumbnailMedPath() {
    for (final asset in layers[0].assets) {
      final path = asset.thumbnailMedPath;
      if (path != null && File(path).existsSync()) {
        return path;
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Scroll / Preview
  // ---------------------------------------------------------------------------
  void _listenerScrollController() async {
    // If playing, position is driven by video players, do nothing
    if (isPlaying) return;

    // Otherwise, sync position with manual scrolling
    final newPosition =
    ((scrollController.offset / pixelsPerSecond) * 1000).floor();
    _position.sink.add(newPosition);

    // Delay a bit for fluidity
    await Future.delayed(const Duration(milliseconds: 10));
    await _previewOnPosition();
  }

  Future<void> endScroll() async {
    final newPosition =
    ((scrollController.offset / pixelsPerSecond) * 1000).floor();
    _position.add(newPosition);

    // Delay for the position to settle
    await Future.delayed(const Duration(milliseconds: 200));
    await _previewOnPosition();
  }

  Future<void> _previewOnPosition() async {
    if (filesNotExist) return;
    if (isOperating) return;
    isPreviewing = true;
    scrollController.removeListener(_listenerScrollController);

    // Preview on the first layer (e.g., the main video layer).
    final firstPlayer = layerPlayers.isNotEmpty ? layerPlayers[0] : null;
    if (firstPlayer != null) {
      await firstPlayer.preview(position);
    }
    _position.add(position);

    scrollController.addListener(_listenerScrollController);
    isPreviewing = false;
  }

  // ---------------------------------------------------------------------------
  // Playback
  // ---------------------------------------------------------------------------
  Future<void> play() async {
    if (filesNotExist) {
      _filesNotExist.add(true);
      return;
    }
    if (isOperating) return;
    if (position >= duration) return;
    logger.i('DirectorService.play()');
    isPlaying = true;
    scrollController.removeListener(_listenerScrollController);
    _appBar.add(true);
    _selected.add(Selected(layerIndex: -1, assetIndex: -1));

    final mainLayer = mainLayerForConcurrency();
    if (mainLayer == -1 || mainLayer >= layers.length) {
      logger.e('Invalid main layer for playback.');
      isPlaying = false;
      _appBar.add(true);
      return;
    }

    final mainPlayer = layerPlayers[mainLayer];
    if (mainPlayer == null) {
      logger.e('Main layer player is null.');
      isPlaying = false;
      _appBar.add(true);
      return;
    }

    // Attach callbacks only to the main layer
    await mainPlayer.play(
      position,
      onMove: (newPosition) {
        _position.add(newPosition);
        scrollController.animateTo(
          (300 + newPosition) / 1000 * pixelsPerSecond,
          duration: const Duration(milliseconds: 300),
          curve: Curves.linear,
        );
        // Update all other layers based on the new position
        _syncOtherLayers(newPosition);
      },
      onEnd: () {
        isPlaying = false;
        _appBar.add(true);
        // Optionally stop all other layers
        _stopAllLayers();
      },
    );

    // Start playback for other layers without awaiting
    for (int i = 0; i < layers.length; i++) {
      if (i == mainLayer || i == 1) continue; // Skip main and text layers
      final player = layerPlayers[i];
      if (player == null) continue;
      player.play(position); // Consider handling errors
    }
  }

  void _syncOtherLayers(int newPosition) {
    for (int i = 0; i < layers.length; i++) {
      if (i == mainLayerForConcurrency() || i == 1) continue; // Skip main and text layers
      final player = layerPlayers[i];
      if (player == null) continue;
      player.preview(newPosition); // Implement a seek method in LayerPlayer
    }
  }

  void _stopAllLayers() {
    for (int i = 0; i < layers.length; i++) {
      if (i == 1) continue; // Skip text layers
      final player = layerPlayers[i];
      if (player == null) continue;
      player.stop(); // Implement a stop method in LayerPlayer
    }
  }


  Future<void> stop() async {
    if ((isOperating && !isPlaying) || !isPlaying) return;
    print('>> DirectorService.stop()');

    for (int i = 0; i < layers.length; i++) {
      if (i == 1) continue;
      final player = layerPlayers[i];
      if (player != null) {
        await player.stop();
      }
    }
    isPlaying = false;
    scrollController.addListener(_listenerScrollController);
    _appBar.add(true);
  }

  int mainLayerForConcurrency() {
    var mainLayer = 0;
    var mainLayerDuration = 0;
    for (int i = 0; i < layers.length; i++) {
      if (i == 1 || layers[i].assets.isEmpty) continue;
      final lastAsset = layers[i].assets.last;
      final end = lastAsset.begin! + lastAsset.duration!;
      if (end > mainLayerDuration) {
        mainLayer = i;
        mainLayerDuration = end;
      }
    }
    return mainLayer;
  }

  // ---------------------------------------------------------------------------
  // Adding assets
  // ---------------------------------------------------------------------------
  Future<void> add(AssetType assetType) async {
    if (isOperating) return;
    isAdding = true;
    print('>> DirectorService.add($assetType)');

    Map<String, String>? filePaths;

    if (assetType == AssetType.video) {
      // 1. Pick files and store the result
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: true,
      );

      // 2. Check for null or empty selection
      if (result == null || result.files.isEmpty) {
        isAdding = false;
        return;
      }

      // 3. Convert the files into a Map<filename, path>
      final filePaths = {
        for (final file in result.files)
          file.name: file.path ?? '', // path might be null on some platforms
      };

      // 4. (Optional) Sort your files by date or any desired criteria
      final fileList = _sortFilesByDate(filePaths);

      // 5. Process each file
      for (final file in fileList) {
        await _addAssetToLayer(0, AssetType.video, file.path);
        await _generateAllVideoThumbnails(layers[0].assets);
      }
    } else if (assetType == AssetType.image) {
      // 1. Pick files and store the result
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );

      // 2. Check for null or empty selection
      if (result == null || result.files.isEmpty) {
        isAdding = false;
        return;
      }

      // 3. Convert the files into a Map<filename, path>
      final filePaths = {
        for (final file in result.files)
          file.name: file.path ?? '', // path might be null on some platforms
      };

      // 4. (Optional) Sort your files by date or any desired criteria
      final fileList = _sortFilesByDate(filePaths);

      // 5. Process each file
      for (final file in fileList) {
        await _addAssetToLayer(0, AssetType.image, file.path);
        _generateKenBurnEffects(layers[0].assets.last);
        await _generateAllImageThumbnails(layers[0].assets);
      }
    } else if (assetType == AssetType.text) {
      editingTextAsset = Asset(
        type: AssetType.text,
        begin: 0,
        duration: 5000,
        title: '',
        srcPath: '',
      );
    } else if (assetType == AssetType.audio) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final Map<String, String> nameToPath = {
          for (final file in result.files)
            file.name: file.path ?? '',
        };

        // Now you can iterate over the Map
        nameToPath.forEach((name, path) {
          print('$name -> $path');
        });
        if (nameToPath == null || nameToPath.isEmpty) {
          isAdding = false;
          return;
        }
        final fileList = _sortFilesByDate(nameToPath);
        for (final file in fileList) {
          await _addAssetToLayer(2, AssetType.audio, file.path);
        }
      }
    }
    isAdding = false;
  }

  /// Sort the file map by last modified date ascending.
  List<File> _sortFilesByDate(Map<String, String> filePaths) {
    final fileList = filePaths.values.map((path) => File(path)).toList();
    fileList.sort((f1, f2) => f1.lastModifiedSync().compareTo(f2.lastModifiedSync()));
    return fileList;
  }

  void _generateKenBurnEffects(Asset asset) {
    asset.kenBurnZSign = math.Random().nextInt(2) - 1;
    asset.kenBurnXTarget = (math.Random().nextInt(2) / 2).toDouble();
    asset.kenBurnYTarget = (math.Random().nextInt(2) / 2).toDouble();
    if (asset.kenBurnZSign == 0 &&
        asset.kenBurnXTarget == 0.5 &&
        asset.kenBurnYTarget == 0.5) {
      asset.kenBurnZSign = 1;
    }
  }

  Future<void> _generateAllVideoThumbnails(List<Asset> assets) async {
    await _generateVideoThumbnails(assets, VideoResolution.mini);
    await _generateVideoThumbnails(assets, VideoResolution.sd);
  }

  Future<void> _generateVideoThumbnails(
      List<Asset> assets,
      VideoResolution resolution,
      ) async {
    final appDocDir = await getApplicationDocumentsDirectory();
    await Directory(p.join(appDocDir.path, 'thumbnails')).create();
    for (final asset in assets) {
      // If already has a thumb or is deleted, skip
      if ((resolution == VideoResolution.mini && asset.thumbnailPath != null) ||
          asset.thumbnailMedPath != null ||
          asset.deleted!) {
        continue;
      }
      final thumbnailFileName =
          '${p.setExtension(asset.srcPath, '').split('/').last}_pos_${asset.cutFrom}.jpg';
      String? thumbnailPath = p.join(appDocDir.path, 'thumbnails', thumbnailFileName);

      thumbnailPath = await generator.generateVideoThumbnail(
        asset.srcPath,
        thumbnailPath,
        asset.cutFrom!,
        resolution,
      );

      if (resolution == VideoResolution.mini) {
        asset.thumbnailPath = thumbnailPath;
      } else {
        asset.thumbnailMedPath = thumbnailPath;
      }
      _layersChanged.add(true);
    }
  }

  Future<void> _generateAllImageThumbnails(List<Asset> assets) async {
    await _generateImageThumbnails(assets, VideoResolution.mini);
    await _generateImageThumbnails(assets, VideoResolution.sd);
  }

  Future<void> _generateImageThumbnails(
      List<Asset> assets,
      VideoResolution resolution,
      ) async {
    final appDocDir = await getApplicationDocumentsDirectory();
    await Directory(p.join(appDocDir.path, 'thumbnails')).create();
    for (final asset in assets) {
      // If already has a thumb or is deleted, skip
      if ((resolution == VideoResolution.mini && asset.thumbnailPath != null) ||
          asset.thumbnailMedPath != null ||
          asset.deleted!) {
        continue;
      }
      final thumbnailFileName =
          '${p.setExtension(asset.srcPath, '').split('/').last}_min.jpg';
      String? thumbnailPath = p.join(appDocDir.path, 'thumbnails', thumbnailFileName);

      thumbnailPath = await generator.generateImageThumbnail(
        asset.srcPath,
        thumbnailPath,
        resolution,
      );

      if (resolution == VideoResolution.mini) {
        asset.thumbnailPath = thumbnailPath;
      } else {
        asset.thumbnailMedPath = thumbnailPath;
      }
      _layersChanged.add(true);
    }
  }

  // ---------------------------------------------------------------------------
  // Text editing
  // ---------------------------------------------------------------------------
  void editTextAsset() {
    final asset = assetSelected;
    if (asset == null) return;
    if (asset.type != AssetType.text) return;
    editingTextAsset = Asset.clone(asset);
    scrollController.animateTo(
      asset.begin! / 1000 * pixelsPerSecond,
      duration: const Duration(milliseconds: 300),
      curve: Curves.linear,
    );
  }

  void saveTextAsset() {
    if (editingTextAsset == null) return;
    if (editingTextAsset!.title == '') {
      editingTextAsset!.title = 'No title';
    }
    if (assetSelected == null) {
      editingTextAsset!.begin = position;
      layers[1].assets.add(editingTextAsset!);
      reorganizeTextAssets(1);
    } else {
      layers[1].assets[selected.assetIndex] = editingTextAsset!;
    }
    _layersChanged.add(true);
    editingTextAsset = null;
  }

  void reorganizeTextAssets(int layerIndex) {
    if (layers[layerIndex].assets.isEmpty) return;

    // First pass: sort by "begin" ascending.
    layers[layerIndex].assets.sort((a, b) => a.begin! - b.begin!);

    // Merge or adjust overlapping blank segments
    for (int i = 1; i < layers[layerIndex].assets.length; i++) {
      final asset = layers[layerIndex].assets[i];
      final prevAsset = layers[layerIndex].assets[i - 1];

      if (prevAsset.title!.isEmpty && asset.title!.isEmpty) {
        asset.begin = prevAsset.begin;
        asset.duration = asset.duration! + prevAsset.duration!;
        prevAsset.duration = 0; // mark for removal
      } else if (prevAsset.title!.isEmpty && asset.title!.isNotEmpty) {
        prevAsset.duration = asset.begin! - prevAsset.begin!;
      } else if (prevAsset.title!.isNotEmpty! && asset.title!.isEmpty!) {
        final needed =
            prevAsset.begin! + prevAsset.duration! - asset.begin!;
        asset.duration = math.max(asset.duration! - needed, 0);
        asset.begin = prevAsset.begin! + prevAsset.duration!;
      }
      // else both have titles: do nothing
    }
    // Remove zero-duration
    layers[layerIndex].assets.removeWhere((x) => x.duration! <= 0);

    // Insert blank spaces if needed
    for (int i = 1; i < layers[layerIndex].assets.length; i++) {
      final asset = layers[layerIndex].assets[i];
      final prevAsset = layers[layerIndex].assets[i - 1];
      final gap = asset.begin! - (prevAsset.begin! + prevAsset.duration!);
      if (gap > 0) {
        final blank = Asset(
          type: AssetType.text,
          begin: prevAsset.begin! + prevAsset.duration!,
          duration: gap,
          title: '',
          srcPath: '',
        );
        layers[layerIndex].assets.insert(i, blank);
        i++; // skip the newly inserted item
      } else {
        // Overlap or contiguous
        asset.begin = prevAsset.begin! + prevAsset.duration!;
      }
    }

    // Leading space
    if (layers[layerIndex].assets.isNotEmpty &&
        layers[layerIndex].assets[0].begin! > 0) {
      final firstAsset = layers[layerIndex].assets[0];
      final blank = Asset(
        type: AssetType.text,
        begin: 0,
        duration: firstAsset.begin,
        title: '',
        srcPath: '',
      );
      layers[layerIndex].assets.insert(0, blank);
    }

    // Trailing space
    final lastAsset = layers[layerIndex].assets.last;
    if (lastAsset.title!.isEmpty) {
      lastAsset.duration = duration - lastAsset.begin!;
    } else {
      final asset = Asset(
        type: AssetType.text,
        begin: lastAsset.begin! + lastAsset.duration!,
        duration: duration - (lastAsset.begin! + lastAsset.duration!),
        title: '',
        srcPath: '',
      );
      layers[layerIndex].assets.add(asset);
    }
  }

  // ---------------------------------------------------------------------------
  // Asset insertion
  // ---------------------------------------------------------------------------
  Future<void> _addAssetToLayer(int layerIndex, AssetType type, String srcPath) async {
    print('_addAssetToLayer: $srcPath');

    int? assetDuration;
    if (type == AssetType.video || type == AssetType.audio) {
      assetDuration = await generator.getVideoDuration(srcPath);
    } else {
      assetDuration = 5000;
    }

    final newAsset = Asset(
      type: type,
      srcPath: srcPath,
      title: p.basename(srcPath),
      duration: assetDuration ?? 0,
      begin: layers[layerIndex].assets.isEmpty
          ? 0
          : layers[layerIndex].assets.last.begin! +
          layers[layerIndex].assets.last.duration!,
    );

    layers[layerIndex].assets.add(newAsset);

    final player = layerPlayers[layerIndex];
    player?.addMediaSource(layers[layerIndex].assets.length - 1, newAsset);

    _layersChanged.add(true);
    _appBar.add(true);
  }

  // ---------------------------------------------------------------------------
  // Selection / dragging
  // ---------------------------------------------------------------------------
  void select(int layerIndex, int assetIndex) {
    if (isOperating) return;
    if (layerIndex == 1 && layers[layerIndex].assets[assetIndex].title!.isEmpty) {
      _selected.add(Selected(layerIndex: -1, assetIndex: -1));
    } else {
      _selected.add(Selected(layerIndex: layerIndex, assetIndex: assetIndex));
    }
    _appBar.add(true);
  }

  void dragStart(int layerIndex, int assetIndex) {
    if (isOperating) return;
    if (layerIndex == 1 && layers[layerIndex].assets[assetIndex].title!.isEmpty) {
      return;
    }
    isDragging = true;
    final sel = Selected(layerIndex: layerIndex, assetIndex: assetIndex);
    sel.initScrollOffset = scrollController.offset;
    _selected.add(sel);
    _appBar.add(true);
  }

  void dragSelected(
      int layerIndex,
      int assetIndex,
      double dragX,
      double scrollWidth,
      ) {
    if (layerIndex == 1 && layers[layerIndex].assets[assetIndex].title!.isEmpty) {
      return;
    }
    final assetSel = layers[layerIndex].assets[assetIndex];
    var closest = assetIndex;
    var pos = assetSel.begin! +
        ((dragX + scrollController.offset - selected.initScrollOffset) /
            pixelsPerSecond *
            1000)
            .floor();

    if (dragX + scrollController.offset - selected.initScrollOffset < 0) {
      closest = getClosestAssetIndexLeft(layerIndex, assetIndex, pos);
    } else {
      pos += assetSel.duration!;
      closest = getClosestAssetIndexRight(layerIndex, assetIndex, pos);
    }
    updateScrollOnDrag(pos, scrollWidth);

    final sel = Selected(assetIndex: assetIndex, layerIndex: layerIndex,
        dragX: dragX,
        closestAsset: closest,
        initScrollOffset: selected.initScrollOffset,
        incrScrollOffset: scrollController.offset - selected.initScrollOffset);
    _selected.add(sel);
  }

  void updateScrollOnDrag(int pos, double scrollWidth) {
    final outOfScrollRight =
        pos * pixelsPerSecond / 1000 - scrollController.offset - scrollWidth / 2;
    final outOfScrollLeft = scrollController.offset -
        pos * pixelsPerSecond / 1000 -
        scrollWidth / 2 +
        32; // layer header offset

    if (outOfScrollRight > 0 && outOfScrollLeft < 0) {
      scrollController.animateTo(
        scrollController.offset + math.min(outOfScrollRight, 50),
        duration: const Duration(milliseconds: 100),
        curve: Curves.linear,
      );
    }
    if (outOfScrollRight < 0 && outOfScrollLeft > 0) {
      scrollController.animateTo(
        scrollController.offset - math.min(outOfScrollLeft, 50),
        duration: const Duration(milliseconds: 100),
        curve: Curves.linear,
      );
    }
  }

  int getClosestAssetIndexLeft(int layerIndex, int assetIndex, int pos) {
    var closest = assetIndex;
    var distance = (pos - layers[layerIndex].assets[assetIndex].begin!).abs();
    if (assetIndex < 1) return assetIndex;
    for (int i = assetIndex - 1; i >= 0; i--) {
      final d = (pos - layers[layerIndex].assets[i].begin!).abs();
      if (d < distance) {
        closest = i;
        distance = d;
      }
    }
    return closest;
  }

  int getClosestAssetIndexRight(int layerIndex, int assetIndex, int pos) {
    var closest = assetIndex;
    final endAsset = layers[layerIndex].assets[assetIndex].begin! +
        layers[layerIndex].assets[assetIndex].duration!;
    var distance = (pos - endAsset).abs();
    if (assetIndex >= layers[layerIndex].assets.length - 1) return assetIndex;
    for (int i = assetIndex + 1; i < layers[layerIndex].assets.length; i++) {
      final end = layers[layerIndex].assets[i].begin! +
          layers[layerIndex].assets[i].duration!;
      final d = (pos - end).abs();
      if (d < distance) {
        closest = i;
        distance = d;
      }
    }
    return closest;
  }

  Future<void> dragEnd() async {
    if (selected.layerIndex != 1) {
      await exchange();
    } else {
      moveTextAsset();
    }
    isDragging = false;
    _appBar.add(true);
  }

  Future<void> exchange() async {
    final layerIndex = selected.layerIndex;
    final assetIndex1 = selected.assetIndex;
    final assetIndex2 = selected.closestAsset;

    // Reset selection
    _selected.add(Selected(assetIndex: -1, layerIndex: -1));

    if (layerIndex == -1 ||
        assetIndex1 == -1 ||
        assetIndex2 == -1 ||
        assetIndex1 == assetIndex2) {
      return;
    }

    final asset1 = layers[layerIndex].assets[assetIndex1];

    layers[layerIndex].assets.removeAt(assetIndex1);
    await layerPlayers[layerIndex]?.removeMediaSource(assetIndex1);

    layers[layerIndex].assets.insert(assetIndex2, asset1);
    await layerPlayers[layerIndex]?.addMediaSource(assetIndex2, asset1);

    refreshCalculatedFieldsInAssets(layerIndex, 0);
    _layersChanged.add(true);

    // Delay to let media sources update
    await Future.delayed(const Duration(milliseconds: 100));
    await _previewOnPosition();
  }

  void moveTextAsset() {
    final layerIndex = selected.layerIndex;
    final assetIndex = selected.assetIndex;
    if (layerIndex == -1 || assetIndex == -1) return;

    final asset = assetSelected;
    if (asset == null) return;

    final pos = asset.begin! +
        ((selected.dragX +
            scrollController.offset -
            selected.initScrollOffset) /
            pixelsPerSecond *
            1000)
            .floor();

    _selected.add(Selected(assetIndex: -1, layerIndex: -1));

    layers[layerIndex].assets[assetIndex].begin = math.max(pos, 0);
    reorganizeTextAssets(layerIndex);
    _layersChanged.add(true);
    _previewOnPosition();
  }

  // ---------------------------------------------------------------------------
  // Cutting / Deleting
  // ---------------------------------------------------------------------------
  Future<void> cutVideo() async {
    if (isOperating) return;
    if (selected.layerIndex == -1 || selected.assetIndex == -1) return;
    print('>> DirectorService.cutVideo()');

    final assetAfter = layers[selected.layerIndex].assets[selected.assetIndex];
    final diff = position - assetAfter.begin!;

    if (diff <= 0 || diff >= assetAfter.duration!) return;
    isCutting = true;

    final assetBefore = Asset.clone(assetAfter);
    assetBefore.duration = diff;
    assetBefore.cutFrom = assetAfter.cutFrom ?? 0;

    // Insert assetBefore before assetAfter
    layers[selected.layerIndex].assets.insert(selected.assetIndex, assetBefore);

    // Update assetAfter's properties
    assetAfter.begin = assetBefore.begin! + assetBefore.duration!;
    assetAfter.cutFrom = assetBefore.cutFrom! + diff;
    assetAfter.duration = assetAfter.duration! - diff;

    // Ensure assetAfter's duration remains positive
    if (assetAfter.duration! <= 0) {
      layers[selected.layerIndex].assets.removeAt(selected.assetIndex + 1);
      await layerPlayers[selected.layerIndex]?.removeMediaSource(selected.assetIndex + 1);
    } else {
      // Rebuild the media sources
      layerPlayers[selected.layerIndex]?.removeMediaSource(selected.assetIndex);
      await layerPlayers[selected.layerIndex]?.addMediaSource(selected.assetIndex, assetBefore);
      await layerPlayers[selected.layerIndex]?.addMediaSource(selected.assetIndex + 1, assetAfter);
    }

    _layersChanged.add(true);

    if (assetAfter.type == AssetType.video) {
      assetAfter.thumbnailPath = null;
      await _generateAllVideoThumbnails(layers[selected.layerIndex].assets);
    }

    _selected.add(Selected(assetIndex: -1, layerIndex: -1));
    _appBar.add(true);

    // Delay to let media sources update
    await Future.delayed(const Duration(milliseconds: 300));
    isCutting = false;
  }


  void delete() {
    if (isOperating) return;
    if (selected.layerIndex == -1 || selected.assetIndex == -1) return;
    print('>> DirectorService.delete()');
    isDeleting = true;

    final layerIndex = selected.layerIndex;
    final assetIndex = selected.assetIndex;
    final assetType = assetSelected?.type;

    layers[layerIndex].assets.removeAt(assetIndex);
    layerPlayers[layerIndex]?.removeMediaSource(assetIndex);

    if (assetType != AssetType.text) {
      refreshCalculatedFieldsInAssets(layerIndex, assetIndex);
    } else {
      reorganizeTextAssets(layerIndex); // Use dynamic layer index
    }

    _layersChanged.add(true);

    _selected.add(Selected(assetIndex: -1, layerIndex: -1));

    _filesNotExist.add(checkSomeFileNotExists());

    isDeleting = false;

    if (position > duration) {
      _position.add(duration);
      scrollController.jumpTo(duration / 1000 * pixelsPerSecond);
    }
    _layersChanged.add(true);
    _appBar.add(true);

    // Delay to let media sources update
    Future.delayed(const Duration(milliseconds: 100), () {
      _previewOnPosition();
    });
  }


  void refreshCalculatedFieldsInAssets(int layerIndex, int assetIndex) {
    for (int i = assetIndex; i < layers[layerIndex].assets.length; i++) {
      final prevDuration = i == 0
          ? 0
          : (layers[layerIndex].assets[i - 1].begin! +
          layers[layerIndex].assets[i - 1].duration!);
      layers[layerIndex].assets[i].begin = prevDuration;
    }
  }

  // ---------------------------------------------------------------------------
  // Timeline scaling
  // ---------------------------------------------------------------------------
  void scaleStart() {
    if (isOperating) return;
    isScaling = true;
    _selected.add(Selected(assetIndex: -1, layerIndex: -1));
    _pixelsPerSecondOnInitScale = pixelsPerSecond;
    _scrollOffsetOnInitScale = scrollController.offset;
  }

  void scaleUpdate(double scale) {
    if (!isScaling || _pixelsPerSecondOnInitScale == null) return;
    double pixPerSecond = _pixelsPerSecondOnInitScale! * scale;
    pixPerSecond = math.min(pixPerSecond, 100);
    pixPerSecond = math.max(pixPerSecond, 1);
    _pixelsPerSecond.add(pixPerSecond);
    _layersChanged.add(true);

    scrollController.jumpTo(
      _scrollOffsetOnInitScale! * pixPerSecond / _pixelsPerSecondOnInitScale!,
    );
  }

  void scaleEnd() {
    isScaling = false;
    _layersChanged.add(true);
  }

  // ---------------------------------------------------------------------------
  // Position-based asset retrieval
  // ---------------------------------------------------------------------------
  Asset? getAssetByPosition(int layerIndex) {
    // If you need to handle position = null, you'd do checks here.
    for (final asset in layers[layerIndex].assets) {
      final end = asset.begin! + asset.duration! - 1;
      if (end >= position) {
        return asset;
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Trimming / Sizing handles
  // ---------------------------------------------------------------------------
  void sizerDragStart(bool sizerEnd) {
    if (isOperating) return;
    isSizerDragging = true;
    isSizerDraggingEnd = sizerEnd;
    dxSizerDrag = 0;
  }

  void sizerDragUpdate(bool sizerEnd, double dx) {
    dxSizerDrag += dx;
    _selected.add(selected); // Force UI refresh
  }

  Future<void> sizerDragEnd(bool sizerEnd) async {
    await executeSizer(sizerEnd);
    _selected.add(selected); // Refresh UI
    dxSizerDrag = 0;
    isSizerDragging = false;
  }

  Future<void> executeSizer(bool sizerEnd) async {
    final asset = assetSelected;
    if (asset == null) return;

    if (asset.type == AssetType.text || asset.type == AssetType.image) {
      var dxSizerDragMillis = (dxSizerDrag / pixelsPerSecond * 1000).floor();

      if (!isSizerDraggingEnd) {
        // Left handle
        if (asset.begin! + dxSizerDragMillis < 0) {
          dxSizerDragMillis = -asset.begin!;
        }
        if (asset.duration! - dxSizerDragMillis < 1000) {
          dxSizerDragMillis = asset.duration! - 1000;
        }
        asset.begin = asset.begin! + dxSizerDragMillis;
        asset.duration = asset.duration! - dxSizerDragMillis;
      } else {
        // Right handle
        if (asset.duration! + dxSizerDragMillis < 1000) {
          dxSizerDragMillis = -asset.duration! + 1000;
        }
        asset.duration = asset.duration! + dxSizerDragMillis;
      }

      if (asset.type == AssetType.text) {
        reorganizeTextAssets(1);
      } else if (asset.type == AssetType.image) {
        refreshCalculatedFieldsInAssets(selected.layerIndex, selected.assetIndex);
        await layerPlayers[selected.layerIndex]
            ?.removeMediaSource(selected.assetIndex);
        await layerPlayers[selected.layerIndex]
            ?.addMediaSource(selected.assetIndex, asset);
      }
      _selected.add(Selected(assetIndex: -1, layerIndex: -1));
    }

    _layersChanged.add(true);
  }

  // ---------------------------------------------------------------------------
  // Video generation
  // ---------------------------------------------------------------------------
  Future<bool> generateVideo(List<Layer> layers, VideoResolution resolution,
      {int? framerate}) async {
    if (filesNotExist) {
      _filesNotExist.add(true);
      return false;
    }
    isGenerating = true;

    // Possibly hide images for memory reasons
    _layersChanged.add(true);

    final outputFile = await generator.generateVideoAll(layers, resolution);
    if (outputFile != null) {
      final date = DateTime.now();
      final dateStr = generator.dateTimeString(date);
      final resolutionStr = generator.videoResolutionString(resolution);

      final appDocDir = await getApplicationDocumentsDirectory();
      String? thumbPath = p.join(appDocDir.path, 'thumbnails', 'generated-$dateStr.jpg');
      thumbPath = await generator.generateVideoThumbnail(
        outputFile,
        thumbPath,
        0,
        VideoResolution.sd,
      );

      await projectDao.insertGeneratedVideo(GeneratedVideo(
        projectId: project?.id ?? -1,
        path: outputFile,
        date: date,
        resolution: resolutionStr,
        thumbnail: thumbPath,
      ));
    }
    isGenerating = false;

    // Show images again if you had hidden them
    _layersChanged.add(true);
    return true;
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------
  Future<void> _deleteThumbnailsNotUsed() async {
    // TODO: pending to implement
    final appDocDir = await getApplicationDocumentsDirectory();
    final fontsDir = Directory(p.join(appDocDir.parent.path, 'code_cache'));

    final entityList = fontsDir.listSync(recursive: true, followLinks: false);
    for (final entity in entityList) {
      final isDir = !await FileSystemEntity.isFile(entity.path);
      if (isDir &&
          entity.path.split('/').last.startsWith('open_director')) {
        // ...
      }
      // print(entity.path);
    }
  }
}
