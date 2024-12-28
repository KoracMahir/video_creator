import 'package:flutter/foundation.dart';

enum AssetType {
  video,
  image,
  text,
  audio,
}

class Layer {
  /// Example: keep [type] non-nullable and required.
  final String type;

  /// Use a non-nullable list but provide a default value if not passed.
  final List<Asset> assets;

  /// If you want [volume] to be required, remove the default value and
  /// make it non-nullable. Here, we allow it to be optional with a default.
  final double volume;

  Layer({
    required this.type,
    List<Asset>? assets,
    double? volume,
  })  : assets = assets ?? <Asset>[],
        volume = volume ?? 1.0;

  /// Clone constructor
  Layer.clone(Layer layer)
      : type = layer.type,
        assets = layer.assets.map((asset) => Asset.clone(asset)).toList(),
        volume = layer.volume;

  /// Factory from JSON
  factory Layer.fromJson(Map<String, dynamic> map) {
    return Layer(
      type: map['type'] as String,
      assets: (map['assets'] as List<dynamic>)
          .map((json) => Asset.fromJson(json as Map<String, dynamic>))
          .toList(),
      volume: (map['volume'] as num?)?.toDouble(),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': type,
    'assets': assets.map((asset) => asset.toJson()).toList(),
    'volume': volume,
  };
}

class Asset {
  /// Since `getAssetTypeFromString` can return null, either:
  ///   1) Make [type] nullable and handle that in your logic, OR
  ///   2) Provide a fallback (e.g., AssetType.video) for unknown types.
  ///
  /// Here, we assume a fallback of `AssetType.video` to ensure non-null.
  final AssetType type;

  final String srcPath;
  String? thumbnailPath;
  String? thumbnailMedPath;
  String? title;
  int? duration;
  int? begin;
  int? cutFrom;

  int? kenBurnZSign;
  double? kenBurnXTarget;
  double? kenBurnYTarget;
  double? x;
  double? y;
  String? font;
  double? fontSize;
  int? fontColor;
  final double alpha;
  final double borderw;
  final int bordercolor;
  final int shadowcolor;
  final double shadowx;
  final double shadowy;
  final bool box;
  final double boxborderw;
  int? boxcolor;
  bool? deleted;

  Asset({
    required this.type,
    required this.srcPath,
    this.thumbnailPath,
    this.thumbnailMedPath,
    required this.title,
    required this.duration,
    required this.begin,
    this.cutFrom = 0,
    this.kenBurnZSign = 0,
    this.kenBurnXTarget = 0.5,
    this.kenBurnYTarget = 0.5,
    this.x = 0.1,
    this.y = 0.1,
    this.font = 'Lato/Lato-Regular.ttf',
    this.fontSize = 0.1,
    this.fontColor = 0xFFFFFFFF,
    this.alpha = 1.0,
    this.borderw = 0.0,
    this.bordercolor = 0xFFFFFFFF,
    this.shadowcolor = 0xFFFFFFFF,
    this.shadowx = 0.0,
    this.shadowy = 0.0,
    this.box = false,
    this.boxborderw = 0.0,
    this.boxcolor = 0x88000000,
    this.deleted = false,
  });

  /// Clone constructor
  Asset.clone(Asset asset)
      : type = asset.type,
        srcPath = asset.srcPath,
        thumbnailPath = asset.thumbnailPath,
        thumbnailMedPath = asset.thumbnailMedPath,
        title = asset.title,
        duration = asset.duration,
        begin = asset.begin,
        cutFrom = asset.cutFrom,
        kenBurnZSign = asset.kenBurnZSign,
        kenBurnXTarget = asset.kenBurnXTarget,
        kenBurnYTarget = asset.kenBurnYTarget,
        x = asset.x,
        y = asset.y,
        font = asset.font,
        fontSize = asset.fontSize,
        fontColor = asset.fontColor,
        alpha = asset.alpha,
        borderw = asset.borderw,
        bordercolor = asset.bordercolor,
        shadowcolor = asset.shadowcolor,
        shadowx = asset.shadowx,
        shadowy = asset.shadowy,
        box = asset.box,
        boxborderw = asset.boxborderw,
        boxcolor = asset.boxcolor,
        deleted = asset.deleted;

  /// Factory from JSON: provide fallback for each field where necessary.
  factory Asset.fromJson(Map<String, dynamic> map) {
    return Asset(
      type: getAssetTypeFromString(map['type'] as String?) ?? AssetType.video,
      srcPath: map['srcPath'] as String,
      thumbnailPath: map['thumbnailPath'] as String?,
      thumbnailMedPath: map['thumbnailMedPath'] as String?,
      title: map['title'] as String,
      duration: map['duration'] as int,
      begin: map['begin'] as int,
      cutFrom: (map['cutFrom'] as int?) ?? 0,
      kenBurnZSign: (map['kenBurnZSign'] as int?) ?? 0,
      kenBurnXTarget: (map['kenBurnXTarget'] as num?)?.toDouble() ?? 0.5,
      kenBurnYTarget: (map['kenBurnYTarget'] as num?)?.toDouble() ?? 0.5,
      x: (map['x'] as num?)?.toDouble() ?? 0.1,
      y: (map['y'] as num?)?.toDouble() ?? 0.1,
      font: map['font'] as String? ?? 'Lato/Lato-Regular.ttf',
      fontSize: (map['fontSize'] as num?)?.toDouble() ?? 0.1,
      fontColor: (map['fontColor'] as int?) ?? 0xFFFFFFFF,
      alpha: (map['alpha'] as num?)?.toDouble() ?? 1.0,
      borderw: (map['borderw'] as num?)?.toDouble() ?? 0.0,
      bordercolor: (map['bordercolor'] as int?) ?? 0xFFFFFFFF,
      shadowcolor: (map['shadowcolor'] as int?) ?? 0xFFFFFFFF,
      shadowx: (map['shadowx'] as num?)?.toDouble() ?? 0.0,
      shadowy: (map['shadowy'] as num?)?.toDouble() ?? 0.0,
      box: (map['box'] as bool?) ?? false,
      boxborderw: (map['boxborderw'] as num?)?.toDouble() ?? 0.0,
      boxcolor: (map['boxcolor'] as int?) ?? 0x88000000,
      deleted: (map['deleted'] as bool?) ?? false,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': type.toString(),
    'srcPath': srcPath,
    'thumbnailPath': thumbnailPath,
    'thumbnailMedPath': thumbnailMedPath,
    'title': title,
    'duration': duration,
    'begin': begin,
    'cutFrom': cutFrom,
    'kenBurnZSign': kenBurnZSign,
    'kenBurnXTarget': kenBurnXTarget,
    'kenBurnYTarget': kenBurnYTarget,
    'x': x,
    'y': y,
    'font': font,
    'fontSize': fontSize,
    'fontColor': fontColor,
    'alpha': alpha,
    'borderw': borderw,
    'bordercolor': bordercolor,
    'shadowcolor': shadowcolor,
    'shadowx': shadowx,
    'shadowy': shadowy,
    'box': box,
    'boxborderw': boxborderw,
    'boxcolor': boxcolor,
    'deleted': deleted,
  };

  /// Helper to parse AssetType from a string; returns `null` if not found.
  static AssetType? getAssetTypeFromString(String? assetTypeAsString) {
    if (assetTypeAsString == null) {
      return null;
    }
    for (final element in AssetType.values) {
      if (element.toString() == assetTypeAsString) {
        return element;
      }
    }
    return null;
  }
}

/// Example selected item in a timeline or layer
class Selected {
  final int layerIndex;
  final int assetIndex;

  double dragX;
  int closestAsset;
  double initScrollOffset;
  double incrScrollOffset;

  Selected({
    required this.layerIndex,
    required this.assetIndex,
    this.dragX = 0,
    this.closestAsset = -1,
    this.initScrollOffset = 0,
    this.incrScrollOffset = 0,
  });

  /// Simple helper method
  bool isSelected(int layerIndex, int assetIndex) {
    return layerIndex == this.layerIndex && assetIndex == this.assetIndex;
  }
}
