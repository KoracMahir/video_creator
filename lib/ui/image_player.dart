import 'dart:io';

import 'package:flutter/cupertino.dart';

import '../model/model.dart';
import '../service/director_service.dart';
import '../service_locator.dart';

class ImagePlayer extends StatelessWidget {
  final directorService = locator.get<DirectorService>();
  final Asset asset;

  ImagePlayer(this.asset) : super();

  @override
  Widget build(BuildContext context) {
    // If the asset is marked deleted, return an empty container.
    if (asset.deleted!) return Container();

    return StreamBuilder<int>(
      stream: directorService.position$,
      initialData: 0,
      builder: (BuildContext context, AsyncSnapshot<int> positionSnapshot) {
        // Get the current asset index (if needed for other logic)
        int assetIndex = directorService.layerPlayers[0]!.currentAssetIndex;

        // If you do not need timeline-based logic anymore, you can remove these lines:
        double ratio = (directorService.position -
            directorService.layers[0].assets[assetIndex].begin!) /
            directorService.layers[0].assets[assetIndex].duration!;
        if (ratio < 0) ratio = 0;
        if (ratio > 1) ratio = 1;

        // Instead of using the KenBurnEffect, we display the image directly.
        // This keeps it static (i.e., no zoom or pan).
        return Image.file(
          File(asset.thumbnailMedPath ?? asset.srcPath),
          fit: BoxFit.fitWidth,
        );
      },
    );
  }
}
