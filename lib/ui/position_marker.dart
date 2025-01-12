import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../service/director_service.dart';
import '../service_locator.dart';
import 'director/params.dart';

class PositionMarker extends StatelessWidget {
  final directorService = locator.get<DirectorService>();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: Params.RULER_HEIGHT - 4,
      margin: EdgeInsets.fromLTRB(0, 2, 0, 2),
      color: Colors.blue,
      child: StreamBuilder(
          stream: directorService.position$,
          initialData: 0,
          builder: (BuildContext context, AsyncSnapshot<int> position) {
            return Center(
                child: Text(
                    '${directorService.positionMinutes}:${directorService.positionSeconds}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    )));
          }),
    );
  }
}