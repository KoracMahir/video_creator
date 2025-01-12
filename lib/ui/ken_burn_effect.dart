import 'dart:io';

import 'package:flutter/cupertino.dart';

import 'director/params.dart';

class KenBurnEffect extends StatelessWidget {
  final String path;
  final double ratio;
  // Effect configuration
  final int zSign;
  final double xTarget;
  final double yTarget;

  KenBurnEffect(
      this.path,
      this.ratio, {
        this.zSign = 0, // Options: {-1, 0, +1}
        this.xTarget = 0, // Options: {0, 0.5, 1}
        this.yTarget = 0, // Options; {0, 0.5, 1}
      }) : super();

  @override
  Widget build(BuildContext context) {
    // Start and end positions
    double xStart = (zSign == 1) ? 0 : (0.5 - xTarget);
    double xEnd =
    (zSign == 1) ? (0.5 - xTarget) : ((zSign == -1) ? 0 : (xTarget - 0.5));
    double yStart = (zSign == 1) ? 0 : (0.5 - yTarget);
    double yEnd =
    (zSign == 1) ? (0.5 - yTarget) : ((zSign == -1) ? 0 : (yTarget - 0.5));
    double zStart = (zSign == 1) ? 0 : 1;
    double zEnd = (zSign == -1) ? 0 : 1;

    // Interpolation
    double x = xStart * (1 - ratio) + xEnd * ratio;
    double y = yStart * (1 - ratio) + yEnd * ratio;
    double z = zStart * (1 - ratio) + zEnd * ratio;

    return LayoutBuilder(builder: (context, constraints) {
      return ClipRect(
        child: Transform.translate(
          offset: Offset(x * 0.2 * Params.getPlayerWidth(context),
              y * 0.2 * Params.getPlayerHeight(context)),
          child: Transform.scale(
            scale: 1 + z * 0.2,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(File(path)),
              ],
            ),
          ),
        ),
      );
    });
  }
}