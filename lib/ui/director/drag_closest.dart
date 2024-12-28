import 'dart:ui';
import 'dart:core';
import 'package:flutter/material.dart';
import 'package:video_creator/ui/director/params.dart';

import '../../model/model.dart';
import '../../service/director_service.dart';
import '../../service_locator.dart';


class DragClosest extends StatelessWidget {
  final directorService = locator.get<DirectorService>();
  final int layerIndex;

  DragClosest(this.layerIndex) : super();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
        stream: directorService.selected$,
        initialData: Selected(layerIndex: -1, assetIndex: -1),
        builder: (BuildContext context, AsyncSnapshot<Selected> selected) {
          Color color;
          double left;
          if (directorService.isDragging &&
              selected.data!.closestAsset != -1 &&
              selected.data!.layerIndex == layerIndex) {
            color = Colors.pink;
            Asset closestAsset = directorService
                .layers[layerIndex].assets[selected.data!.closestAsset];
            if (selected.data!.closestAsset <= selected.data!.assetIndex) {
              left =
                  closestAsset.begin! * directorService.pixelsPerSecond / 1000.0;
            } else {
              left = (closestAsset.begin! + closestAsset.duration!) *
                  directorService.pixelsPerSecond /
                  1000.0;
            }
          } else {
            color = Colors.transparent;
            left = -1;
          }

          return Positioned(
            left:  MediaQuery.of(context).size.width / 2 + left - 2,
            child: Container(
              height: Params.getLayerHeight(
                  context, directorService.layers[layerIndex].type),
              width: 3,
              color: color,
            ),
          );
        });
  }
}