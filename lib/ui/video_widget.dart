import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:video_creator/ui/text_player.dart';
import 'package:video_player/video_player.dart';

import '../model/model.dart';
import '../service/director_service.dart';
import '../service_locator.dart';
import 'director/params.dart';
import 'image_player.dart';

class Video extends StatelessWidget {
  final directorService = locator.get<DirectorService>();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
        stream: directorService.position$,
        builder: (BuildContext context, AsyncSnapshot<int> position) {
          var backgroundContainer = Container(
            color: Colors.black,
            height: Params.getPlayerHeight(context),
            width: Params.getPlayerWidth(context),
          );
          if (directorService.layerPlayers == null ||
              directorService.layerPlayers.length == 0) {
            return backgroundContainer;
          }
          int assetIndex = directorService.layerPlayers[0]!.currentAssetIndex;
          if (assetIndex == -1 ||
              assetIndex >= directorService.layers[0].assets.length) {
            return backgroundContainer;
          }
          AssetType type = directorService.layers[0].assets[assetIndex].type;
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                height: Params.getPlayerHeight(context),
                width: Params.getPlayerWidth(context),
                child: Stack(
                  children: [
                    backgroundContainer,
                    (type == AssetType.video)
                        ? VideoPlayer(
                        directorService.layerPlayers[0]!.videoController)
                        : ImagePlayer(
                        directorService.layers[0].assets[assetIndex]),
                    TextPlayer(),
                  ],
                ),
              ),
            ],
          );
        });
  }
}