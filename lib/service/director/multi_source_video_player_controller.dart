import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

/// Minimal container for a single media source in our playlist.
class _MediaSource {
  final String uri;
  final int startMs;
  final int endMs;
  final bool isAsset;

  _MediaSource({
    required this.uri,
    required this.startMs,
    required this.endMs,
    required this.isAsset,
  });
}

/// A custom multi-source video player controller that
/// wraps a standard [VideoPlayerController] internally.
///
/// - Supports adding/removing media sources.
/// - Manages a "current source index".
/// - Provides simple `play()`, `pause()`, `seekTo()`, etc.
class MultiSourceVideoPlayerController extends ValueNotifier<VideoPlayerValue>
    implements VideoPlayerController {
  /// Internal list of sources in this "playlist".
  final List<_MediaSource> _sources = [];

  /// The index of the currently playing source in [_sources].
  int _currentSourceIndex = 0;

  int get currentIndex => _currentSourceIndex;

  /// The wrapped standard [VideoPlayerController] for the active source.
  VideoPlayerController? _activeController;

  /// Tracks whether this controller has been disposed.
  bool _isDisposed = false;

  /// Construct an empty multi-source controller; a sources with [addMediaSource].
  MultiSourceVideoPlayerController() : super(VideoPlayerValue.uninitialized());

  // --------------------------------------------------------------------------
  // Add / Remove Sources
  // --------------------------------------------------------------------------

  /// Insert a media source at [index].
  ///
  /// [uri] can be a file path, network URL, or Flutter asset (see [isAsset]).
  /// [startMs] / [endMs] define the playable "window" in this media.
  Future<void> addMediaSource(
      int index,
      String uri,
      int startMs,
      int endMs, {
        bool isAsset = false,
      }) async {
    final clampedIndex = index.clamp(0, _sources.length);
    _sources.insert(
      clampedIndex,
      _MediaSource(
        uri: uri,
        startMs: startMs,
        endMs: endMs,
        isAsset: isAsset,
      ),
    );
  }

  /// Remove the media source at [index].
  ///
  /// If removing the currently active source, we must pause, dispose the
  /// current sub-controller, and reinitialize it with the new source list.
  Future<void> removeMediaSource(int index) async {
    if (index < 0 || index >= _sources.length) return;

    // If removing the currently playing source:
    if (index == _currentSourceIndex) {
      await pause();
      await _activeController?.dispose();
      _activeController = null;

      _sources.removeAt(index);

      // Adjust current index if needed
      if (_sources.isEmpty) {
        _currentSourceIndex = 0;
        // We have no sources left, so set uninitialized
        value = VideoPlayerValue.uninitialized();
        return;
      } else if (_currentSourceIndex >= _sources.length) {
        _currentSourceIndex = _sources.length - 1;
      }

      await _initializeActiveController();
    } else {
      // If removing some other source, just remove it:
      _sources.removeAt(index);
      if (index < _currentSourceIndex) {
        _currentSourceIndex -= 1;
      }
    }
  }

  // --------------------------------------------------------------------------
  // Initialization / Disposal
  // --------------------------------------------------------------------------

  @override
  Future<void> initialize() async {
    if (_isDisposed) return;
    if (_sources.isEmpty) {
      // No sources yet. You could throw an exception or just do nothing.
      return;
    }
    await _initializeActiveController();
  }

  /// Helper to clean up any old active controller, then create a new one
  /// for [_currentSourceIndex].
  Future<void> _initializeActiveController() async {
    if (_activeController != null) {
      await _activeController!.dispose();
      _activeController = null;
    }

    final activeSource = _sources[_currentSourceIndex];
    print("Initializing source $_currentSourceIndex: ${activeSource.uri} from ${activeSource.startMs} to ${activeSource.endMs}");

    final ctrl = activeSource.isAsset
        ? VideoPlayerController.asset(activeSource.uri)
        : VideoPlayerController.network(activeSource.uri);

    _activeController = ctrl..addListener(_onInnerValueChanged);

    await ctrl.initialize();
    print("Controller initialized for source $_currentSourceIndex");

    await ctrl.seekTo(Duration(milliseconds: activeSource.startMs));
    print("Controller seeked to ${activeSource.startMs} ms");

    value = ctrl.value;
  }

  /// Called when the wrapped (active) controller’s value changes.
  ///
  /// We mirror that to our own [value], and we check if we've passed
  /// the "endMs" boundary, in which case we pause or move to the next source.
  Future<void> _onInnerValueChanged() async {
    final ctrl = _activeController;
    if (ctrl == null) return;

    final subValue = ctrl.value;
    // Mirror the underlying value to this top-level controller
    value = subValue;

    // If not playing or uninitialized, skip checks
    if (!subValue.isInitialized || _isDisposed || !subValue.isPlaying) {
      return;
    }

    // Check if we've passed the end boundary
    final activeSource = _sources[_currentSourceIndex];
    final endMs = activeSource.endMs;
    final currentPosMs = subValue.position.inMilliseconds;
    if (currentPosMs >= endMs) {
      print("_sources ${_currentSourceIndex} ${_sources.length}");
      // We reached the end of our sub-window
      if (_currentSourceIndex < _sources.length - 1) {
        // Move to the next source
        _currentSourceIndex++;
        // Re-initialize the controller for the new source
        await _initializeActiveController();
        // Optionally auto-play the next source
        await play();
      } else {
        // No more sources left, so pause
        pause();
      }
    }

  }

  @override
  Future<void> dispose() async {
    _isDisposed = true;
    _activeController?.removeListener(_onInnerValueChanged);
    await _activeController?.dispose();
    _activeController = null;
    super.dispose();
  }

  // --------------------------------------------------------------------------
  // Core VideoPlayerController overrides
  // --------------------------------------------------------------------------

  @override
  Future<void> play() async {
    if (_isDisposed || _activeController == null) return;
    await _activeController!.play();
  }

  @override
  Future<void> pause() async {
    if (_isDisposed || _activeController == null) return;
    await _activeController!.pause();
  }

  @override
  Future<void> setVolume(double volume) async {
    if (_isDisposed || _activeController == null) return;
    await _activeController!.setVolume(volume);
  }

  @override
  Future<void> setLooping(bool looping) async {
    if (_isDisposed || _activeController == null) return;
    await _activeController!.setLooping(looping);
  }

  /// Basic seek within the *current* source.
  /// If you need to switch sources, call [seekToSource].
  @override
  Future<void> seekTo(Duration position) async {
    if (_isDisposed || _activeController == null) return;
    await _activeController!.seekTo(position);
  }

  /// Example method to switch to [sourceIndex] and then seek to [position].
  Future<void> seekToSource(int sourceIndex, Duration position) async {
    if (_isDisposed) return;
    if (sourceIndex < 0 || sourceIndex >= _sources.length) return;

    if (sourceIndex != _currentSourceIndex) {
      _currentSourceIndex = sourceIndex;
      await _initializeActiveController();
    }

    if (_activeController != null) {
      await _activeController!.seekTo(position);
    }
  }

  // --------------------------------------------------------------------------
  // Additional getters / setters
  // --------------------------------------------------------------------------

  /// In older `video_player`, there's no `videoFormat`. So we skip or return null.
  /// If your code calls `videoFormat`, define it yourself:
  VideoFormat? get videoFormat => null;

  /// Typically replaced by `value.isInitialized` in older or simpler usage.
  bool get dataSourceInitialized => value.isInitialized;

  /// Return the data source of the active controller (or empty).
  String get dataSource => _activeController?.dataSource ?? '';

  /// Return `true` if the active controller is fully initialized.
  bool get isInitialized => value.isInitialized;

  /// Indicate whether logging is enabled (stub here).
  bool get enableLog => false;
  set enableLog(bool enable) {
    // No-op or store in a field if you need to
  }

  /// The standard plugin doesn't have a direct 'muted' property.
  /// We'll define a custom getter:
  bool get muted => (_activeController?.value.volume ?? 0) == 0.0;

  // The below are optional overrides if your code needs them.

  @override
  Future<void> setPlaybackSpeed(double speed) async {
    if (_isDisposed || _activeController == null) return;
    await _activeController!.setPlaybackSpeed(speed);
  }



  @override
  Future<void> setClosedCaptionFile(Future<ClosedCaptionFile>? file) async {
    if (_isDisposed || _activeController == null) return;
    await _activeController!.setClosedCaptionFile(file);
  }

  @override
  Future<ClosedCaptionFile>? get closedCaptionFile {
    // Forward to the active controller if not null:
    if (_activeController == null) {
      return null;
    }
    return _activeController!.closedCaptionFile;
  }

  @override
  DataSourceType get dataSourceType {
    // Provide a fallback or forward to the active controller
    if (_activeController == null) return DataSourceType.network;
    return _activeController!.dataSourceType;
  }

  @override
  VideoFormat? get formatHint {
    // If your code doesn't rely on formatHint, you can return null
    if (_activeController == null) return null;
    return _activeController!.formatHint;
  }

  @override
  Map<String, String> get httpHeaders {
    // If you're using advanced network usage. Otherwise return {}
    if (_activeController == null) return {};
    return _activeController!.httpHeaders;
  }

  @override
  String? get package {
    // If using package-based assets. Otherwise, return null or forward
    return _activeController?.package;
  }

  @override
  void setCaptionOffset(Duration offset) {
    if (_isDisposed || _activeController == null) return;
    _activeController!.setCaptionOffset(offset);
  }

  @override
  int get textureId {
    // Some platforms require a texture ID to render the video.
    if (_activeController == null) {
      return -1; // or 0
    }
    return _activeController!.textureId;
  }

  @override
  VideoPlayerOptions? get videoPlayerOptions {
    return _activeController?.videoPlayerOptions;
  }

  @override
  Future<Duration?> get position async {
    // Forward to the active controller. If null, return 0.
    if (_activeController == null) return Duration.zero;
    return _activeController!.position;
  }

}
