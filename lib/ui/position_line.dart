import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'director/params.dart';

class PositionLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
        width: 2,
        height: Params.getTimelineHeight(context) - 4,
        margin: EdgeInsets.fromLTRB(0, 2, 0, 2),
        color: Colors.grey.shade100);
  }
}