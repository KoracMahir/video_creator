import 'dart:ui';
import 'dart:core';
import 'package:flutter/material.dart';
import 'package:video_creator/ui/position_line.dart';
import 'package:video_creator/ui/position_marker.dart';
import 'package:video_creator/ui/timeline.dart';
import 'package:video_creator/ui/video_widget.dart';
import 'dart:async';
import '../../service_locator.dart';
import '../../service/director_service.dart';
import '../../model/project.dart';
import '../../ui/director/params.dart';
import '../../ui/director/app_bar.dart';
import '../../ui/director/text_asset_editor.dart';
import '../../ui/director/color_editor.dart';
import '../../ui/common/animated_dialog.dart';
import 'layer_headers.dart';

class DirectorScreen extends StatefulWidget {
  final Project project;
  const DirectorScreen(this.project);

  @override
  _DirectorScreen createState() => _DirectorScreen(project);
}

class _DirectorScreen extends State<DirectorScreen>
    with WidgetsBindingObserver {
  final directorService = locator.get<DirectorService>();
  StreamSubscription<bool> _dialogFilesNotExistSubscription;

  _DirectorScreen(Project project)
      : _dialogFilesNotExistSubscription = locator
      .get<DirectorService>()
      .filesNotExist$
      .listen((val) {
    if (val) {
      // ... your dialog code ...
    }
  }) {
    directorService.setProject(project);

    _dialogFilesNotExistSubscription =
        directorService.filesNotExist$.listen((val) {
          if (val) {
            // Delayed because widgets are building
            Future.delayed(Duration(milliseconds: 100), () {
              AnimatedDialog.show(
                context,
                title: 'Some assets have been deleted',
                child: Text(
                    'To continue you must recover deleted assets in your device '
                        'or remove them from the timeline (marked in red).'),
                button2Text: 'OK',
                onPressedButton2: () {
                  Navigator.of(context).pop();
                },
              );
            });
          }
        });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dialogFilesNotExistSubscription.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      Params.fixHeight = true;
    } else if (state == AppLifecycleState.resumed) {
      Params.fixHeight = false;
    }
  }

  @override
  void didHaveMemoryPressure() {
    super.didHaveMemoryPressure();
    // To release memory
    imageCache.clear();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (directorService.editingColor != null) {
          directorService.editingColor = null;
          return false;
        }
        if (directorService.editingTextAsset != null) {
          directorService.editingTextAsset = null;
          return false;
        }
        bool exit = await directorService.exitAndSaveProject();
        if (exit) Navigator.pop(context);
        return false;
      },
      child: Material(
        color: Colors.grey.shade900,
        child: SafeArea(
          child: GestureDetector(
            onTap: () {
              if (directorService.editingTextAsset == null) {
                directorService.select(-1, -1);
              }
              // Hide keyboard
              FocusScope.of(context).requestFocus(new FocusNode());
            },
            child: Container(
              color: Colors.grey.shade900,
              child: _Director(),
            ),
          ),
        ),
      ),
    );
  }
}

class _Director extends StatelessWidget {
  final directorService = locator.get<DirectorService>();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: <Widget>[
          Container(
            height: Params.getPlayerHeight(context) +
                (MediaQuery.of(context).orientation == Orientation.landscape
                    ? 0
                    : Params.APP_BAR_HEIGHT * 2),
            child: MediaQuery.of(context).orientation == Orientation.landscape
                ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  AppBar1(),
                  Video(),
                  AppBar2(),
                ])
                : Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  AppBar1(),
                  Video(),
                  AppBar2(),
                ]),
          ),
          Stack(
            alignment: const Alignment(0, -1),
            children: <Widget>[
              SingleChildScrollView(
                child: Stack(
                  alignment: const Alignment(-1, -1),
                  children: <Widget>[
                    Container(
                      child: GestureDetector(
                        child: NotificationListener<ScrollNotification>(
                          onNotification: (ScrollNotification scrollState) {
                            if (scrollState is ScrollEndNotification) {
                              directorService.endScroll();
                            }
                            return false;
                          },
                          child: TimeLine(),
                        ),
                        onScaleStart: (ScaleStartDetails details) {
                          directorService.scaleStart();
                        },
                        onScaleUpdate: (ScaleUpdateDetails details) {
                          directorService.scaleUpdate(details.horizontalScale);
                        },
                        onScaleEnd: (ScaleEndDetails details) {
                          directorService.scaleEnd();
                        },
                      ),
                    ),
                    LayerHeaders(),
                  ],
                ),
              ),
              PositionLine(),
              PositionMarker(),
              TextAssetEditor(),
              ColorEditor(),
            ],
          ),
        ],
      ),
    );
  }
}
















