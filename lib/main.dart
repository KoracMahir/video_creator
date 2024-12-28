import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:video_creator/service_locator.dart';
import 'package:video_creator/ui/project_list.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  //CustomImageCache(); // Disabled at this time
  //setupDevice(); // Disabled at this time
  setupAnalyticsAndCrashlytics();
  setupLocator();
  runApp(MyApp());
}

setupDevice() {
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  // Status bar disabled
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
}

setupAnalyticsAndCrashlytics() {
  // Set `enableInDevMode` to true to see reports while in debug mode
  // This is only to be used for confirming that reports are being
  // submitted as expected. It is not intended to be used for everyday
  // development.

  // Pass all uncaught errors from the framework to Crashlytics.
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Open Director',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        hintColor: Colors.blue,
        brightness: Brightness.dark,
        textTheme: TextTheme(
          labelLarge: TextStyle(color: Colors.white),
        ),
      ),
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: [
        const Locale('en', 'US'),
        const Locale('es', 'ES'),
      ],
      home: Scaffold(
        body: ProjectList(),
      ),
    );
  }
}

class CustomImageCache extends WidgetsFlutterBinding {
  @override
  ImageCache createImageCache() {
    ImageCache imageCache = super.createImageCache();
    imageCache.maximumSize = 5;
    return imageCache;
  }
}
