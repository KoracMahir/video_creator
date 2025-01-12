import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../service/director_service.dart';
import '../service_locator.dart';

class RulerPainter extends CustomPainter {
  final directorService = locator.get<DirectorService>();
  final BuildContext context;

  RulerPainter(this.context);

  getSecondsPerDivision(double pixPerSec) {
    if (pixPerSec > 40) {
      return 1;
    } else if (pixPerSec > 20) {
      return 2;
    } else if (pixPerSec > 10) {
      return 5;
    } else if (pixPerSec > 4) {
      return 10;
    } else if (pixPerSec > 1.5) {
      return 30;
    } else {
      return 60;
    }
  }

  getTimeText(int seconds) {
    return '${(seconds / 60).floor() < 10 ? '0' : ''}'
        '${(seconds / 60).floor()}'
        '.${seconds - (seconds / 60).floor() * 60 < 10 ? '0' : ''}'
        '${seconds - (seconds / 60).floor() * 60}';
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double width =
        directorService.duration / 1000 * directorService.pixelsPerSecond +
            MediaQuery.of(context).size.width;

    final paint = Paint();
    paint.color = Colors.grey.shade800;
    Rect rect = Rect.fromLTWH(0, 2, width, size.height - 4);
    canvas.drawRect(rect, paint);

    paint.color = Colors.grey.shade400;
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1;

    Path path = Path();
    path.moveTo(0, size.height - 2);
    path.relativeLineTo(width, 0);
    path.close();
    canvas.drawPath(path, paint);

    int secondsPerDivision =
    getSecondsPerDivision(directorService.pixelsPerSecond);
    final double pixelsPerDivision =
        secondsPerDivision * directorService.pixelsPerSecond;
    final int numberOfDivisions =
    ((width - MediaQuery.of(context).size.width / 2) / pixelsPerDivision)
        .floor();

    for (int i = 0; i <= numberOfDivisions; i++) {
      int seconds = i * secondsPerDivision;
      String text = getTimeText(seconds);

      final TextPainter textPainter = TextPainter(
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.left,
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 10,
          ),
        ),
      );

      textPainter.layout();
      double x = MediaQuery.of(context).size.width / 2 + i * pixelsPerDivision;
      textPainter.paint(canvas, Offset(x + 6, 6));

      Path path = Path();
      path.moveTo(x + 1, size.height - 4);
      path.relativeLineTo(0, -8);
      path.moveTo(x + 1 + 0.5 * pixelsPerDivision, size.height - 4);
      path.relativeLineTo(0, -2);
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}