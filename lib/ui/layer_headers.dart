import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../service/director_service.dart';
import '../service_locator.dart';
import 'director/params.dart';
import 'layer_header.dart';

class LayerHeaders extends StatelessWidget {
  final directorService = locator.get<DirectorService>();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          height: Params.RULER_HEIGHT - 4,
          width: 33,
          color: Colors.transparent,
          margin: EdgeInsets.fromLTRB(0, 2, 0, 2),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: directorService.layers
              .asMap()
              .map((index, layer) => MapEntry(index, LayerHeader(layer.type)))
              .values
              .toList(),
        ),
      ],
    );
  }
}