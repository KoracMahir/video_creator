import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'director/params.dart';

class LayerHeader extends StatelessWidget {
  final String type;
  LayerHeader(this.type) : super();

  @override
  Widget build(BuildContext context) {
    return Container(
        child: Icon(
          type == "raster"
              ? Icons.photo
              : type == "vector" ? Icons.text_fields : Icons.music_note,
          color: Colors.white,
          size: 16,
        ),
        height: Params.getLayerHeight(context, type),
        width: 28.0,
        margin: EdgeInsets.fromLTRB(0, 1, 1, 1),
        padding: const EdgeInsets.all(4.0),
        decoration: BoxDecoration(
          color: Colors.grey.shade800,
        ));
  }
}