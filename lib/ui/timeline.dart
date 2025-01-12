import 'package:flutter/cupertino.dart';
import 'package:video_creator/ui/ruler.dart';

import '../service/director_service.dart';
import '../service_locator.dart';
import 'director/params.dart';
import 'layer_asset.dart';

class TimeLine extends StatelessWidget {
  final directorService = locator.get<DirectorService>();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
        stream: directorService.layersChanged$,
        initialData: false,
        builder: (BuildContext context, AsyncSnapshot<bool> layersChanged) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            controller: directorService.scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Ruler(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: directorService.layers
                      .asMap()
                      .map((index, layer) =>
                      MapEntry(index, LayerAssets(index)))
                      .values
                      .toList(),
                ),
                Container(
                  height: Params.getLayerBottom(context),
                ),
              ],
            ),
          );
        });
  }
}