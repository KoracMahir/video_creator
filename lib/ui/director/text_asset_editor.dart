import 'dart:core';
import 'package:flutter/material.dart';
import 'package:video_creator/ui/director/params.dart';
import 'package:video_creator/ui/director/text_form.dart';

import '../../model/model.dart';
import '../../service/director_service.dart';
import '../../service_locator.dart';

class TextAssetEditor extends StatelessWidget {
  final directorService = locator.get<DirectorService>();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
        stream: directorService.editingTextAsset$,
        initialData: null,
        builder: (BuildContext context, AsyncSnapshot<Asset?> editingTextAsset) {
          if (editingTextAsset.data == null) return Container();
          return Container(
            height: Params.getTimelineHeight(context),
            width: MediaQuery.of(context).size.width,
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              border: Border(
                top: BorderSide(width: 2, color: Colors.blue),
              ),
            ),
            child: TextForm(editingTextAsset.data),
          );
        });
  }
}
