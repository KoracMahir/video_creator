import 'dart:ui';
import 'dart:core';
import 'package:flutter/material.dart';
import 'package:video_creator/ui/director/params.dart';

import '../../model/model.dart';
import '../../service/director_service.dart';
import '../../service_locator.dart';

class AssetSizer extends StatelessWidget {
  final directorService = locator.get<DirectorService>();
  final int layerIndex;
  final bool sizerEnd;

  AssetSizer(this.layerIndex, this.sizerEnd) : super();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
        stream: directorService.selected$,
        initialData: Selected(layerIndex: -1, assetIndex: -1),
        builder: (BuildContext context, AsyncSnapshot<Selected> selected) {
          Color color = Colors.transparent;
          double left = -50;
          IconData? iconData;
          if (selected.data!.layerIndex == layerIndex &&
              selected.data!.assetIndex != -1 &&
              !directorService.isDragging) {
            Asset asset = directorService
                .layers[layerIndex].assets[selected.data!.assetIndex];
            if (asset.type == AssetType.text || asset.type == AssetType.image) {
              left = asset.begin! * directorService.pixelsPerSecond / 1000.0;
              if (sizerEnd) {
                left +=
                    asset.duration! * directorService.pixelsPerSecond / 1000.0;
                if (directorService.isSizerDraggingEnd) {
                  left += directorService.dxSizerDrag;
                }
                if (left <
                    (asset.begin! + 1000) *
                        directorService.pixelsPerSecond /
                        1000.0) {
                  left = (asset.begin! + 1000) *
                      directorService.pixelsPerSecond /
                      1000.0;
                }
                iconData = Icons.arrow_right;
              } else {
                if (!directorService.isSizerDraggingEnd) {
                  left += directorService.dxSizerDrag;
                }
                if (left >
                    (asset.begin! + asset.duration! - 1000) *
                        directorService.pixelsPerSecond /
                        1000.0) {
                  left = (asset.begin! + asset.duration! - 1000) *
                      directorService.pixelsPerSecond /
                      1000.0;
                }
                if (left < 0) {
                  left = 0;
                }
                left -= 28;
                iconData = Icons.arrow_left;
              }

              if (directorService.dxSizerDrag == 0) {
                color = Colors.pinkAccent;
              } else {
                color = Colors.greenAccent;
              }
            }
          }

          return Positioned(
            left: MediaQuery.of(context).size.width / 2 + left,
            child: GestureDetector(
              child: Container(
                height: Params.getLayerHeight(
                    context, directorService.layers[layerIndex].type),
                width: 30,
                color: color,
                child: Icon(iconData, size: 30, color: Colors.white),
              ),
              onHorizontalDragStart: (detail) =>
                  directorService.sizerDragStart(sizerEnd),
              onHorizontalDragUpdate: (detail) =>
                  directorService.sizerDragUpdate(sizerEnd, detail.delta.dx),
              onHorizontalDragEnd: (detail) =>
                  directorService.sizerDragEnd(sizerEnd),
            ),
          );
        });
  }
}
