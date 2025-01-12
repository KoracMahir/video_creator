import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../model/model.dart';
import '../service/director_service.dart';
import '../service_locator.dart';
import 'director/params.dart';

class VisualAsset extends StatelessWidget {
  final directorService = locator.get<DirectorService>();
  final int layerIndex;
  final int assetIndex;
  VisualAsset(this.layerIndex, this.assetIndex) : super();
  @override
  Widget build(BuildContext context) {
    Asset asset = directorService.layers[layerIndex].assets[assetIndex];
    Color backgroundColor = Colors.transparent;
    Color borderColor = Colors.transparent;
    Color textColor = Colors.transparent;
    Color backgroundTextColor = Colors.transparent;
    if (asset.deleted!) {
      backgroundColor = Colors.red.shade200;
      borderColor = Colors.red;
      textColor = Colors.red.shade900;
    } else if (layerIndex == 0) {
      backgroundColor = Colors.blue.shade200;
      borderColor = Colors.blue;
      textColor = Colors.white;
      backgroundTextColor = Colors.black.withOpacity(0.5);
    } else if (layerIndex == 1 && asset.title != '') {
      backgroundColor = Colors.blue.shade200;
      borderColor = Colors.blue;
      textColor = Colors.blue.shade900;
    } else if (layerIndex == 2) {
      backgroundColor = Colors.orange.shade200;
      borderColor = Colors.orange;
      textColor = Colors.orange.shade900;
    }
    return GestureDetector(
      child: Container(
        height: Params.getLayerHeight(
            context, directorService.layers[layerIndex].type),
        child: Text(
          "$assetIndex\n${asset.begin}\n${asset.cutFrom}",
          style: TextStyle(
              color: textColor,
              fontSize: 12,
              backgroundColor: backgroundTextColor,
              shadows: <Shadow>[
                Shadow(
                    color: Colors.black,
                    offset: (layerIndex == 0) ? Offset(1, 1) : Offset(0, 0))
              ]),
        ),
        width: asset.duration! * directorService.pixelsPerSecond / 1000.0,
        padding: const EdgeInsets.fromLTRB(4, 3, 4, 3),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border(
            top: BorderSide(width: 2, color: borderColor),
            bottom: BorderSide(width: 2, color: borderColor),
            left: BorderSide(
                width: (assetIndex == 0) ? 1 : 0, color: borderColor),
            right: BorderSide(width: 1, color: borderColor),
          ),
          image: (!asset.deleted! &&
              asset.thumbnailPath != null &&
              !directorService.isGenerating)
              ? DecorationImage(
            image: FileImage(File(asset.thumbnailPath!)),
            fit: BoxFit.cover,
            alignment: Alignment.topLeft,
            //repeat: ImageRepeat.repeatX // Doesn't work with fitHeight
          )
              : null,
        ),
      ),
      onTap: () => directorService.select(layerIndex, assetIndex),
      onLongPressStart: (LongPressStartDetails details) {
        directorService.dragStart(layerIndex, assetIndex);
      },
      onLongPressMoveUpdate: (LongPressMoveUpdateDetails details) {
        directorService.dragSelected(layerIndex, assetIndex,
            details.offsetFromOrigin.dx, MediaQuery.of(context).size.width);
      },
      onLongPressEnd: (LongPressEndDetails details) {
        directorService.dragEnd();
      },
    );
  }
}