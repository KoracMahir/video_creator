import 'package:flutter/cupertino.dart';

import '../model/model.dart';
import '../service/director_service.dart';
import '../service_locator.dart';
import 'director/params.dart';
import 'director/text_form.dart';
import 'director/text_player_editor.dart';

class TextPlayer extends StatelessWidget {
  final directorService = locator.get<DirectorService>();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
        stream: directorService.editingTextAsset$,
        initialData: null,
        builder: (BuildContext context, AsyncSnapshot<Asset?> editingTextAsset) {
          Asset? _asset = editingTextAsset.data;
          if (_asset == null) {
            _asset = directorService.getAssetByPosition(1);
          }
          if (_asset == null || _asset.type != AssetType.text) {
            return Container();
          }
          Font font = Font.getByPath(_asset.font!);
          return Positioned(
            left: _asset.x! * Params.getPlayerWidth(context),
            top: _asset.y! * Params.getPlayerHeight(context),
            child: Container(
              child: (directorService.editingTextAsset == null)
                  ? Text(
                _asset.title!,
                /*strutStyle: StrutStyle(
                        fontSize: _asset.fontSize *
                            Params.getPlayerWidth(context) /
                            MediaQuery.of(context).textScaleFactor,
                        fontStyle: font.style,
                        fontFamily: font.family,
                        fontWeight: font.weight,
                        height: 1,
                        leading: 0.0,
                      ),*/
                style: TextStyle(
                  height: 1,
                  fontSize: _asset.fontSize! *
                      Params.getPlayerWidth(context) /
                      MediaQuery.of(context).textScaleFactor,
                  fontStyle: font.style,
                  fontFamily: font.family,
                  fontWeight: font.weight,
                  color: Color(_asset.fontColor!),
                  backgroundColor: Color(_asset.boxcolor!),
                ),
              )
                  : TextPlayerEditor(editingTextAsset.data!),
            ),
          );
        });
  }
}