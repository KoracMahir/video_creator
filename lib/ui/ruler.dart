import 'package:flutter/cupertino.dart';
import 'package:video_creator/ui/ruler_painer.dart';

import '../service/director_service.dart';
import '../service_locator.dart';
import 'director/params.dart';

class Ruler extends StatelessWidget {
  final directorService = locator.get<DirectorService>();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: RulerPainter(context),
      child: Container(
        height: Params.RULER_HEIGHT - 4,
        width: MediaQuery.of(context).size.width +
            directorService.pixelsPerSecond * directorService.duration / 1000,
        margin: EdgeInsets.fromLTRB(0, 2, 0, 2),
      ),
    );
  }
}