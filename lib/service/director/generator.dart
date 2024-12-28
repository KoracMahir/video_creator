import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:ffmpeg_kit_flutter/statistics.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:async';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:typed_data';
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:logger/logger.dart';
import 'package:rxdart/rxdart.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../model/model.dart';
import '../../service_locator.dart';

class Generator {
  final logger = locator.get<Logger>();

  // Since ffmpeg_kit_flutter does not require “instance” objects,
  // we remove references to FlutterFFmpeg, FlutterFFprobe, etc.

  // Since we’re using null safety, the BehaviorSubject must be typed.
  // Also note that rxdart’s “Observable” has been deprecated in favor of “Stream”.
  final BehaviorSubject<FFmpegStat> _ffmpegStat =
  BehaviorSubject.seeded(FFmpegStat());

  // Expose as a Stream
  Stream<FFmpegStat> get ffmpegStat$ => _ffmpegStat.stream;

  // Synchronous getter for convenience
  FFmpegStat get ffmpegStat => _ffmpegStat.value;

  Future<int?> getVideoDuration(String path) async {
    final session = await FFprobeKit.getMediaInformation(path);
    final info = session.getMediaInformation();
    if (info == null) return null;

    final Map<dynamic, dynamic>? infoProps = info.getAllProperties();
    if (infoProps == null) return null;

    // 1) Check for format-based duration
    final formatMap = infoProps['format'] as Map<dynamic, dynamic>?;
    final formatDuration = formatMap?['duration']?.toString();
    if (formatDuration != null) {
      final parsed = double.tryParse(formatDuration);
      if (parsed != null) return parsed.toInt() * 1000;
    }

    // 2) Otherwise, check the first stream
    final streams = infoProps['streams'] as List<dynamic>?;
    if (streams != null && streams.isNotEmpty) {
      final streamMap = streams.first as Map<dynamic, dynamic>;
      final streamDuration = streamMap['duration']?.toString();
      if (streamDuration != null) {
        final parsed = double.tryParse(streamDuration);
        if (parsed != null) return parsed.toInt() * 1000;
      }
    }

    // If neither format nor streams have the duration, return null
    return null;
  }



  Future<String?> generateVideoThumbnail(
      String srcPath,
      String thumbnailPath,
      int pos,
      VideoResolution videoResolution,
      ) async {
    final size = _videoResolutionSize(videoResolution);
    final pathList = thumbnailPath.split('.');
    if (pathList.length < 2) {
      return null; // fallback if invalid
    }
    pathList[pathList.length - 2] += '_${size.width}x${size.height}';
    final path = pathList.join('.');

    final arguments = '-loglevel error -y -i "$srcPath" '
        '-ss ${pos / 1000} -vframes 1 -vf scale=-2:${size.height} "$path"';

    final resultPath = await _executeBlockingFFmpegCommand(arguments, path);
    return resultPath;
  }

  Future<String?> generateImageThumbnail(
      String srcPath,
      String thumbnailPath,
      VideoResolution videoResolution,
      ) async {
    final size = _videoResolutionSize(videoResolution);
    final pathList = thumbnailPath.split('.');
    if (pathList.length < 2) {
      return null;
    }
    pathList[pathList.length - 2] += '_${size.width}x${size.height}';
    final path = pathList.join('.');

    final arguments = '-loglevel error -y -r 1 -i "$srcPath" '
        '-ss 0 -vframes 1 -vf scale=-2:${size.height} "$path"';

    final resultPath = await _executeBlockingFFmpegCommand(arguments, path);
    return resultPath;
  }

  /// One-step generation example
  Future<String?> generateVideoAll(
      List<Layer> layers,
      VideoResolution videoResolution,
      ) async {
    // Clear cached images to free memory
    imageCache.clear();

    const String galleryDirPath = '/storage/emulated/0/Movies/OpenDirector';

    // Modern permission handler usage:
    final status = await Permission.storage.request();
    if (!status.isGranted) {
      // Return or handle the error
      return null;
    }

    await Directory(galleryDirPath).create(recursive: true);

    String arguments = _commandLogLevel('error');

    // Input: for images/videos in first layer
    arguments += _commandInputs(layers[0]);
    // Input: for audio layer (third layer)
    arguments += _commandInputs(layers[2]);

    // Start filter complex
    arguments += ' -filter_complex "';

    // Video filter: layer[0]
    arguments += _commandImageVideoFilters(layers[0], 0, videoResolution);

    // Audio filter: layer[2]
    arguments += _commandAudioFilters(layers[2], layers[0].assets.length);

    // Concatenate video streams
    arguments +=
        _commandConcatenateStreams(layers[0], 0, false);
    // Concatenate audio streams
    arguments += _commandConcatenateStreams(
      layers[2],
      layers[0].assets.length,
      true,
    );

    // Text overlay (layer[1])
    arguments += await _commandTextAssets(layers[1], videoResolution);

    // Remove trailing semicolon if present
    if (arguments.endsWith(';')) {
      arguments = arguments.substring(0, arguments.length - 1);
    }
    arguments += '"';

    // Codecs
    arguments += _commandCodecsAndFormat(CodecsAndFormat.H264AacMp4);

    final dateSuffix = dateTimeString(DateTime.now());
    final outputPath =
    p.join(galleryDirPath, 'Open_Director_$dateSuffix.mp4');

    // Output
    arguments += _commandOutputFile(
      outputPath,
      layers[2].assets.isNotEmpty,
      true,
    );

    final out = await executeCommand(
      arguments,
      finished: true,
      outputPath: outputPath,
    );
    return out;
  }

  /// Multi-step generation example
  Future<void> generateVideoBySteps(
      List<Layer> layers,
      VideoResolution videoResolution,
      ) async {
    // Clear cached images
    imageCache.clear();

    int? rc = await generateVideosForAssets(layers[0], videoResolution);
    if (rc != 0) return;

    rc = await concatVideos(layers, videoResolution);
    if (rc != 0) return;

    const String galleryDirPath = '/storage/emulated/0/Movies/OpenDirector';
    final status = await Permission.storage.request();
    if (!status.isGranted) {
      return;
    }
    await Directory(galleryDirPath).create(recursive: true);

    String arguments = _commandLogLevel('error');

    final extStorDir = await getExternalStorageDirectory();
    final extStorPath = extStorDir?.path ?? '/storage/emulated/0';

    final videoConcatenatedPath =
    p.join(extStorPath, 'temp', 'concanenated.mp4');

    arguments += _commandInput(videoConcatenatedPath);
    arguments += await _commandInputForAudios(layers[2]);

    // Start filter complex
    arguments += ' -filter_complex "';

    arguments += _commandAudioFilters(layers[2], 1);
    arguments += _commandConcatenateStreams(layers[2], 1, true);
    arguments += await _commandTextAssets(layers[1], videoResolution);

    if (arguments.endsWith(';')) {
      arguments = arguments.substring(0, arguments.length - 1);
    }
    arguments += '"';

    // Codecs
    arguments += _commandCodecsAndFormat(CodecsAndFormat.H264AacMp4);

    final dateSuffix = dateTimeString(DateTime.now());
    final outputPath =
    p.join(galleryDirPath, 'Open_Director_$dateSuffix.mp4');

    arguments += _commandOutputFile(
      outputPath,
      layers[2].assets.isNotEmpty,
      true,
    );

    await executeCommand(
      arguments,
      finished: true,
      outputPath: outputPath,
    );

    await _deleteTempDir();
  }

  /// Generate intermediate videos for each image/video asset in the first layer.
  Future<int> generateVideosForAssets(
      Layer layer,
      VideoResolution videoResolution,
      ) async {
    final extStorDir = await getExternalStorageDirectory();
    final extStorPath = extStorDir?.path ?? '/storage/emulated/0';

    await Directory(p.join(extStorPath, 'temp')).create(recursive: true);

    int fileNum = 1;
    for (int i = 0; i < layer.assets.length; i++) {
      final rc = await generateVideoForAsset(
        i,
        fileNum,
        layer.assets.length,
        layer.assets[i],
        videoResolution,
      );
      if (rc != 0) return rc;
      fileNum++;
    }
    return 0;
  }

  /// Generate a single intermediate video from one image/video asset.
  Future<int> generateVideoForAsset(
      int index,
      int fileNum,
      int totalFiles,
      Asset asset,
      VideoResolution videoResolution,
      ) async {
    String arguments = _commandLogLevel('error');
    arguments += _commandInput(asset.srcPath);

    // Start filter complex
    arguments += ' -filter_complex "';

    if (asset.type == AssetType.image) {
      arguments += _commandPadForAspectRatioFilter(videoResolution);
      arguments += _commandKenBurnsEffectFilter(videoResolution, asset);
    } else if (asset.type == AssetType.video) {
      arguments += _commandPadForAspectRatioFilter(videoResolution);
      arguments += _commandTrimFilter(asset, false);
    }

    arguments += _commandScaleFilter(videoResolution);

    if (arguments.endsWith(',')) {
      arguments = arguments.substring(0, arguments.length - 1);
    }
    arguments += '[v]"';

    arguments += _commandCodecsAndFormat(CodecsAndFormat.H264AacMp4);

    final extStorDir = await getExternalStorageDirectory();
    final extStorPath = extStorDir?.path ?? '/storage/emulated/0';

    final outputPath = p.join(extStorPath, 'temp', 'v$index.mp4');

    arguments += _commandOutputFile(outputPath, false, true);

    final result = await executeCommand(
      arguments,
      fileNum: fileNum,
      totalFiles: totalFiles,
    );

    return (result == null) ? 1 : 0;
  }

  /// Concatenate intermediate videos.
  Future<int> concatVideos(
      List<Layer> layers,
      VideoResolution videoResolution,
      ) async {
    String arguments = _commandLogLevel('error');
    final listPath = await _listForConcat(layers[0]);

    arguments += ' -f concat -safe 0 -i "$listPath" -c copy';

    final extStorDir = await getExternalStorageDirectory();
    final extStorPath = extStorDir?.path ?? '/storage/emulated/0';

    final outputPath = p.join(extStorPath, 'temp', 'concanenated.mp4');
    arguments += ' -y "$outputPath"';

    final result = await executeCommand(arguments);
    return (result == null) ? 1 : 0;
  }

  /// Generate a txt file listing the intermediate videos to concatenate.
  Future<String> _listForConcat(Layer layer) async {
    final extStorDir = await getExternalStorageDirectory();
    final extStorPath = extStorDir?.path ?? '/storage/emulated/0';

    final tempPath = p.join(extStorPath, 'temp');
    String list = '';
    for (int i = 0; i < layer.assets.length; i++) {
      list += "file '${p.join(tempPath, "v$i.mp4")}'\n";
    }
    final file = await File(p.join(tempPath, 'list.txt')).writeAsString(list);
    return file.path;
  }

  /// Delete temporary directory.
  Future<void> _deleteTempDir() async {
    final extStorDir = await getExternalStorageDirectory();
    final extStorPath = extStorDir?.path ?? '/storage/emulated/0';

    final tempPath = p.join(extStorPath, 'temp');
    if (await Directory(tempPath).exists()) {
      await Directory(tempPath).delete(recursive: true);
    }
  }

  /// Execute an FFmpeg command. If [finished] is true, we treat it as the final step.
  /// Returns [outputPath] on success, or `null` on error/cancel.
  Future<String?> executeCommand(
      String arguments, {
        String? outputPath,
        int? fileNum,
        int? totalFiles,
        bool finished = false,
      }) async {
    final completer = Completer<String?>();
    final initTime = DateTime.now();

    // Optionally enable a global statistics callback
    FFmpegKitConfig.enableStatisticsCallback((Statistics stats) {
      final time = stats.getTime();       // milliseconds
      final size = stats.getSize();       // bytes
      final bitrate = stats.getBitrate(); // kbit/s
      final speed = stats.getSpeed();     // (e.g. 1.23x)

      // You can update your BehaviorSubject here:
      // _ffmpegStat.add(FFmpegStat(time: time, size: size, ...));
    });

    // Execute (blocking style)
    final session = await FFmpegKit.execute(arguments);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      // Success
      final diffTime = DateTime.now().difference(initTime);
      logger.i('Generator.executeCommand() took $diffTime');
      // Mark as finished in your stats if desired
      completer.complete(outputPath);
    } else if (ReturnCode.isCancel(returnCode)) {
      // Canceled
      completer.complete(null);
    } else {
      // Error
      final logs = await session.getAllLogsAsString();
      logger.e('Generator.executeCommand() error logs:\n$logs');

      completer.complete(null);
    }

    // Clear the statistics callback
    FFmpegKitConfig.enableStatisticsCallback(null);
    return completer.future;
  }

  /// A small helper that executes a command in a purely blocking style,
  /// returning the [outputPath] if successful, null otherwise.
  Future<String?> _executeBlockingFFmpegCommand(
      String arguments,
      String outputPath,
      ) async {
    final session = await FFmpegKit.execute(arguments);
    final returnCode = await session.getReturnCode();
    if (ReturnCode.isSuccess(returnCode)) {
      return outputPath;
    }
    return null;
  }

  /// Cancel ffmpeg command and reset stats
  Future<void> finishVideoGeneration() async {
    _ffmpegStat.add(FFmpegStat());
    // Cancel all ongoing FFmpegKit sessions. (Alternatively, store a reference
    // to a specific FFmpegSession and call session.cancel() if you only want
    // to cancel one session.)
    await FFmpegKit.cancel();
  }

  // Helper for log level
  String _commandLogLevel(String level) => '-loglevel $level ';

  // Generate multiple -i inputs from all assets in a layer
  String _commandInputs(Layer layer) {
    if (layer.assets.isEmpty) return "";
    return layer.assets
        .map((asset) => _commandInput(asset.srcPath))
        .join('');
  }

  // Generate multiple -i inputs (async for usage in generateVideoBySteps)
  Future<String> _commandInputForAudios(Layer layer) async {
    var arguments = '';
    for (final asset in layer.assets) {
      arguments += _commandInput(asset.srcPath);
    }
    return arguments;
  }

  // Single -i input
  String _commandInput(String path) => ' -i "$path"';

  // For each asset in [layer], build the filter chain for image or video.
  String _commandImageVideoFilters(
      Layer layer,
      int startIndex,
      VideoResolution videoResolution,
      ) {
    var arguments = "";
    for (var i = 0; i < layer.assets.length; i++) {
      arguments += '[${startIndex + i}:v]';
      arguments += _commandPadForAspectRatioFilter(videoResolution);

      if (layer.assets[i].type == AssetType.image) {
        arguments += _commandKenBurnsEffectFilter(
          videoResolution,
          layer.assets[i],
        );
      } else if (layer.assets[i].type == AssetType.video) {
        arguments += _commandTrimFilter(layer.assets[i], false);
      }

      arguments += _commandScaleFilter(videoResolution);
      arguments += 'copy[v${startIndex + i}];';
    }
    return arguments;
  }

  // Build audio trim for each asset in layer
  String _commandAudioFilters(Layer layer, int startIndex) {
    var arguments = "";
    for (var i = 0; i < layer.assets.length; i++) {
      arguments += '[${startIndex + i}:a]'
          '${_commandTrimFilter(layer.assets[i], true)}'
          'acopy[a${startIndex + i}];';
    }
    return arguments;
  }

  // Trim filter for either audio or video
  String _commandTrimFilter(Asset asset, bool audio) {
    // from => [cutFrom, cutFrom+duration]
    final fromSec = asset.cutFrom! / 1000;
    final toSec = (asset.cutFrom! + asset.duration!) / 1000;
    // atrim/trim => x:y, setpts => resets timestamp to 0
    return '${audio ? "a" : ""}trim=$fromSec:$toSec,'
        '${audio ? "a" : ""}setpts=PTS-STARTPTS,';
  }

  // Pad for aspect ratio
  String _commandPadForAspectRatioFilter(VideoResolution videoResolution) {
    final size = _videoResolutionSize(videoResolution);
    return "pad="
        "w='max(ceil(ceil(ih/2)*2/${size.height / size.width}/2)*2,ceil(iw/2)*2)':"
        "h='max(ceil(ceil(iw/2)*2*${size.height / size.width}/2)*2,ceil(ih/2)*2)':"
        "x=(ow-iw)/2:y=(oh-ih)/2,";
  }

  // Scale to final resolution
  String _commandScaleFilter(VideoResolution videoResolution) {
    final size = _videoResolutionSize(videoResolution);
    return 'scale=${size.width}:${size.height}:force_original_aspect_ratio=decrease,'
        'setsar=1,';
  }

  // Choose the correct resolution sizes
  VideoResolutionSize _videoResolutionSize(VideoResolution videoResolution) {
    switch (videoResolution) {
      case VideoResolution.fullHd:
        return VideoResolutionSize(width: 1920, height: 1080);
      case VideoResolution.hd:
        return VideoResolutionSize(width: 1280, height: 720);
      case VideoResolution.mini:
        return VideoResolutionSize(width: 64, height: 36);
      case VideoResolution.sd:
      default:
        return VideoResolutionSize(width: 640, height: 360);
    }
  }

  // For UI display, if needed
  String videoResolutionString(VideoResolution videoResolution) {
    switch (videoResolution) {
      case VideoResolution.fullHd:
        return 'Full HD 1080px';
      case VideoResolution.hd:
        return 'HD 720px';
      case VideoResolution.mini:
        return 'Thumbnail 36px';
      case VideoResolution.sd:
      default:
        return 'SD 360px';
    }
  }

  // Ken Burns effect for images
  String _commandKenBurnsEffectFilter(
      VideoResolution videoResolution,
      Asset asset,
      ) {
    final size = _videoResolutionSize(videoResolution);
    // By default, framerate 25 in zoompan
    final double d = asset.duration! / 1000 * 25;
    final s = "${size.width}x${size.height}";

    // Zoom 20%
    final z = (asset.kenBurnZSign == 1)
        ? "'zoom+${0.2 / d}'"
        : (asset.kenBurnZSign == -1)
        ? "'if(eq(on,1),1.2,zoom-${0.2 / d})'"
        : "1.2";

    final x = (asset.kenBurnZSign != 0)
        ? "'${asset.kenBurnXTarget}*(iw-iw/zoom)'"
        : (asset.kenBurnXTarget == 1)
        ? "'(${asset.kenBurnXTarget}-on/$d)*(iw-iw/zoom)'"
        : (asset.kenBurnXTarget == 0)
        ? "'on/$d*(iw-iw/zoom)'"
        : "'(iw-iw/zoom)/2'";

    final y = (asset.kenBurnZSign != 0)
        ? "'${asset.kenBurnYTarget}*(ih-ih/zoom)'"
        : (asset.kenBurnYTarget == 1)
        ? "'(${asset.kenBurnYTarget}-on/$d)*(ih-ih/zoom)'"
        : (asset.kenBurnYTarget == 0)
        ? "'on/$d*(ih-ih/zoom)'"
        : "'(ih-ih/zoom)/2'";

    return "zoompan=d=$d:s=$s:z=$z:x=$x:y=$y,";
  }

  // Concatenate all streams for either video or audio
  String _commandConcatenateStreams(
      Layer layer,
      int startIndex,
      bool isAudio,
      ) {
    if (layer.assets.isEmpty) return "";
    var arguments = "";
    for (var i = startIndex; i < startIndex + layer.assets.length; i++) {
      arguments += '[${isAudio ? "a" : "v"}$i]';
    }
    arguments += 'concat='
        'n=${layer.assets.length}'
        ':v=${isAudio ? 0 : 1}'
        ':a=${isAudio ? 1 : 0}'
        '[${isAudio ? "a" : "vprev"}];';
    return arguments;
  }

  // Combine text assets
  Future<String> _commandTextAssets(
      Layer layer,
      VideoResolution videoResolution,
      ) async {
    // Start from the last video track => [vprev]
    // If there are no text assets, we just pass it through.
    String arguments = '[vprev]';
    for (int i = 0; i < layer.assets.length; i++) {
      if (layer.assets[i].title!.isNotEmpty) {
        arguments += await _commandDrawText(layer.assets[i], videoResolution);
      }
    }
    arguments += 'copy[v];';
    return arguments;
  }

  // Insert drawtext filter for a text-based Asset
  Future<String> _commandDrawText(
      Asset asset,
      VideoResolution videoResolution,
      ) async {
    // Font file path
    final fontFile = await _getFontPath(asset.font!);

    // Convert ARGB to RGBA for ffmpeg
    final fontColorHex = '0x${asset.fontColor!.toRadixString(16).substring(2)}';
    final size = _videoResolutionSize(videoResolution);

    final beginSec = asset.begin! / 1000;
    final endSec = (asset.begin! + asset.duration!) / 1000;

    return "drawtext="
        "enable='between(t,$beginSec,$endSec)':"
        "x=${asset.x! * size.width}:y=${asset.y! * size.height}:"
        "fontfile=$fontFile:"
        "fontsize=${asset.fontSize! * size.width}:"
        "fontcolor=$fontColorHex:alpha=${asset.alpha}:"
        "borderw=${asset.borderw}:bordercolor=${colorStr(asset.bordercolor)}:"
        "shadowcolor=${colorStr(asset.shadowcolor)}:"
        "shadowx=${asset.shadowx}:shadowy=${asset.shadowy}:"
        "box=${asset.box ? 1 : 0}:"
        "boxborderw=${asset.boxborderw}:"
        "boxcolor=${colorStr(asset.boxcolor!)}:"
        "line_spacing=0:"
        "text='${asset.title}',";
  }

  // Convert int color from ARGB to 0xRRGGBBAA for ffmpeg
  String colorStr(int colorInt) {
    final colorStr = colorInt.toRadixString(16).padLeft(8, '0');
    // ARGB -> RGBA
    final newColorStr = colorStr.substring(2) + colorStr.substring(0, 2);
    return '0x$newColorStr';
  }

  // Choose codecs and formats
  String _commandCodecsAndFormat(CodecsAndFormat codecsAndFormat) {
    switch (codecsAndFormat) {
      case CodecsAndFormat.VP9OpusWebm:
        return ' -c:v libvpx-vp9 -lossless 1 -c:a opus -f webm';
      case CodecsAndFormat.H264AacMp4:
        return ' -c:v libx264 -c:a aac -pix_fmt yuva420p -f mp4';
      case CodecsAndFormat.Xvid:
        return ' -c:v libxvid -c:a aac -f avi';
      case CodecsAndFormat.Mpeg4:
      default:
        return ' -c:v mpeg4 -qscale:v 1 -c:a aac -f mp4';
    }
  }

  // Map the final [v] (video) and possibly [a] (audio) to the output file
  String _commandOutputFile(String path, bool withAudio, bool overwrite) {
    return ' -map "[v]" ${withAudio ? "-map \"[a]\"" : ""} ${overwrite ? "-y" : ""} "$path"';
  }

  // Suffix for output file
  String dateTimeString(DateTime dateTime) {
    return '${dateTime.year.toString().padLeft(4, "0")}'
        '${dateTime.month.toString().padLeft(2, "0")}'
        '${dateTime.day.toString().padLeft(2, "0")}'
        '_${dateTime.hour.toString().padLeft(2, "0")}'
        '${dateTime.minute.toString().padLeft(2, "0")}'
        '${dateTime.second.toString().padLeft(2, "0")}';
  }

  // Extract font from assets folder to a writable location
  Future<String> _getFontPath(String relativePath) async {
    const String rootFontsPath = 'fonts';
    final fontFileByteData =
    await rootBundle.load(p.join(rootFontsPath, relativePath));
    final appDocDir = await getApplicationDocumentsDirectory();
    final fontPath = p.join(appDocDir.path, rootFontsPath, relativePath);

    // Ensure directories exist, then write
    final file = File(fontPath);
    file.createSync(recursive: true);
    file.writeAsBytesSync(
      fontFileByteData.buffer.asUint8List(
        fontFileByteData.offsetInBytes,
        fontFileByteData.lengthInBytes,
      ),
    );
    return fontPath;
  }
}

enum CodecsAndFormat {
  Mpeg4,
  Xvid,
  H264AacMp4,
  VP9OpusWebm,
}

enum VideoResolution {
  sd,
  hd,
  fullHd,
  mini,
}

class VideoResolutionSize {
  final int width;
  final int height;
  const VideoResolutionSize({
    required this.width,
    required this.height,
  });
}

class FFmpegStat {
  int time;
  int size;
  double bitrate;
  double speed;
  int videoFrameNumber;
  double videoQuality;
  double videoFps;
  bool finished;
  String? outputPath;
  bool error;
  int timeElapsed;
  int? fileNum;
  int? totalFiles;

  FFmpegStat({
    this.time = 0,
    this.size = 0,
    this.bitrate = 0.0,
    this.speed = 0.0,
    this.videoFrameNumber = 0,
    this.videoQuality = 0.0,
    this.videoFps = 0.0,
    this.finished = false,
    this.outputPath,
    this.error = false,
    this.timeElapsed = 0,
    this.fileNum,
    this.totalFiles,
  });
}
