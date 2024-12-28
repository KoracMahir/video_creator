import 'package:video_player/video_player.dart'; // For VideoPlayerValue, etc.
import '../../model/model.dart';
import 'multi_source_video_player_controller.dart';
// ^ Import your custom class here.

class LayerPlayer {
  /// The layer this player is responsible for.
  final Layer layer;

  /// The index of the currently playing asset in [layer.assets], or -1 if none.
  int currentAssetIndex = -1;

  /// Cache of the "global" position in milliseconds (across all assets).
  int? _newPosition;

  /// Our custom multi-source video player controller.
  late final MultiSourceVideoPlayerController _videoController;
  MultiSourceVideoPlayerController get videoController => _videoController;

  /// Optional callbacks
  void Function(int)? _onMove;
  void Function()? _onJump;
  void Function()? _onEnd;

  LayerPlayer(this.layer);

  ///
  /// Initialize the [MultiSourceVideoPlayerController] and add each media source
  /// from the layer's assets.
  ///
  Future<void> initialize() async {
    // Create the custom multi-source controller
    _videoController = MultiSourceVideoPlayerController();
    await _videoController.initialize();

    // Add each asset to the controller as a media source
    for (int i = 0; i < layer.assets.length; i++) {
      await addMediaSource(i, layer.assets[i]);
    }
  }

  ///
  /// Preview the video at the given global [pos] (in milliseconds).
  /// Plays briefly at volume 0, then pauses.
  ///
  Future<void> preview(int pos) async {
    currentAssetIndex = getAssetByPosition(pos);
    if (currentAssetIndex == -1) return;

    // Only preview if the asset is actually a video.
    if (layer.assets[currentAssetIndex].type != AssetType.video) return;

    _newPosition = pos - layer.assets[currentAssetIndex].begin!;

    // Mute preview
    await _videoController.setVolume(0);

    // Seek to the correct source index and position
    await _videoController.seekToSource(
      currentAssetIndex,
      Duration(milliseconds: _newPosition!),
    );

    await _videoController.play();
    await _videoController.pause();
  }


  ///
  /// Play from a given global [pos]. Optionally provide callbacks:
  /// - [onMove] is called with the latest global position in ms.
  /// - [onJump] is called when we jump to a new asset in the playlist.
  /// - [onEnd] is called when playback finishes.
  ///
  Future<void> play(
      int pos, {
        void Function(int)? onMove,
        void Function()? onJump,
        void Function()? onEnd,
      }) async {
    _onMove = onMove;
    _onJump = onJump;
    _onEnd = onEnd;

    // Find the asset index to play based on position.
    currentAssetIndex = getAssetByPosition(pos);
    if (currentAssetIndex == -1) return;

    // Set volume for this layer.
    await _videoController.setVolume(layer.volume);

    _newPosition = pos - layer.assets[currentAssetIndex].begin!;
    print("_newPosition ${_newPosition}");

    // Seek to the correct source index and position
    await _videoController.seekToSource(
      currentAssetIndex,
      Duration(milliseconds: _newPosition!),
    );

    await _videoController.play();

    // Attach a listener to track position changes and detect end-of-playback
    _videoController.addListener(_multiSourceListener);
  }

  ///
  /// Returns the asset index in [layer.assets] that corresponds to the global
  /// position [pos], or -1 if none fits.
  ///
  int getAssetByPosition(int? pos) {
    if (pos == null) return -1;
    for (int i = 0; i < layer.assets.length; i++) {
      final assetEnd = layer.assets[i].begin! + layer.assets[i].duration! - 1;
      if (assetEnd >= pos) {
        return i;
      }
    }
    return -1;
  }

  ///
  /// Listener attached to the [MultiSourceVideoPlayerController].
  /// Updates global position, detects asset changes, calls callbacks, etc.
  ///
  void _multiSourceListener() {
    final v = _videoController.value;

    // If there's no valid "source index" concept in your MultiSource controller,
    // you might implement it yourself. For example, if you track the current
    // source index internally, you can expose it via a getter:
    final windowIndex = _currentSourceIndexOfController();

    // Convert from local position in the current asset to global position.
    final currentPosMs = v.position.inMilliseconds;
    final beginOfAsset = layer.assets[windowIndex].begin;
    _newPosition = currentPosMs + beginOfAsset!;

    // onMove callback
    if (_onMove != null && _newPosition != null) {
      _onMove!(_newPosition!);
    }

    // If we jumped to another asset in the multi-source playlist
    if (currentAssetIndex != windowIndex) {
      currentAssetIndex = windowIndex;
      if (_onJump != null) {
        _onJump!();
      }
    }

    // If we are done playing the current asset
    final assetDuration = layer.assets[windowIndex].duration;
    final isAtEnd = (!v.isPlaying &&
        v.position.inMilliseconds >= (assetDuration! - 100));

    if (isAtEnd) {
      stop().then((_) {
        currentAssetIndex = -1;

        // Possibly a 'jump' to nothing
        if (_onJump != null) {
          _onJump!();
        }
        if (_onEnd != null) {
          _onEnd!();
        }
      });
    }
  }

  ///
  /// Stop playback. Removes the listener and pauses the video.
  ///
  Future<void> stop() async {
    _videoController.removeListener(_multiSourceListener);
    await _videoController.pause();
  }

  ///
  /// Adds a media source to the underlying controller at [index],
  /// covering the time span from [asset.cutFrom] to [asset.cutFrom + asset.duration].
  ///
  Future<void> addMediaSource(int index, Asset asset) async {
    if (asset.type == AssetType.image) {
      // Insert a blank video for an image-based asset
      await _videoController.addMediaSource(
        index,
        'assets/blank-1h.mp4',
        asset.cutFrom!,
        asset.cutFrom! + asset.duration!,
        isAsset: true,
      );
    } else {
      // Normal video or audio
      await _videoController.addMediaSource(
        index,
        asset.deleted! ? 'assets/blank-1h.mp4' : asset.srcPath,
        asset.cutFrom!,
        asset.cutFrom! + asset.duration!,
        isAsset: false,
      );
    }
  }

  ///
  /// Removes a media source at [index] from the underlying controller.
  ///
  Future<void> removeMediaSource(int index) async {
    await _videoController.removeMediaSource(index);
  }

  ///
  /// Release any held resources.
  ///
  Future<void> dispose() async {
    _videoController.removeListener(_multiSourceListener);
    await _videoController.dispose();
  }

  /// Example helper if your MultiSourceVideoPlayerController
  /// has an internal notion of the "current source index."
  /// If not, you may implement logic to determine it by matching positions or
  /// store it within the multi-source controller itself.
  int _currentSourceIndexOfController() {
    // If your custom controller exposes something like:
    //    int get currentIndex => ...
    // Then just do: return _videoController.currentIndex;
    //
    // Otherwise, you might approximate by looking at your own currentAssetIndex:
    return _videoController.currentIndex;
  }
}
