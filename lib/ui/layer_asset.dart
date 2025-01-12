import 'package:flutter/cupertino.dart';

import '../service/director_service.dart';
import '../service_locator.dart';
import 'asset.dart';
import 'director/asset_selection.dart';
import 'director/asset_sizer.dart';
import 'director/drag_closest.dart';
import 'director/params.dart';

class LayerAssets extends StatelessWidget {
  final directorService = locator.get<DirectorService>();
  final int layerIndex;
  LayerAssets(this.layerIndex) : super();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: const Alignment(0, 0),
      children: [
        Container(
          height: Params.getLayerHeight(
              context, directorService.layers[layerIndex].type),
          margin: EdgeInsets.all(1),
          child: Row(
            children: [
              // Half left screen in blank
              Container(width: MediaQuery.of(context).size.width / 2),

              Row(
                children: directorService.layers[layerIndex].assets
                    .asMap()
                    .map((assetIndex, asset) => MapEntry(
                  assetIndex,
                  VisualAsset(layerIndex, assetIndex),
                ))
                    .values
                    .toList(),
              ),
              Container(
                width: MediaQuery.of(context).size.width / 2 - 2,
              ),
            ],
          ),
        ),
        AssetSelection(layerIndex),
        AssetSizer(layerIndex, false),
        AssetSizer(layerIndex, true),
        (layerIndex != 1) ? DragClosest(layerIndex) : Container(),
      ],
    );
  }
}