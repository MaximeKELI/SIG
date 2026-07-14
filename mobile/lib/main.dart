import 'package:flutter/material.dart';
import 'package:video_player_media_kit/video_player_media_kit.dart';

import 'app/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // video_player natif ne couvre pas Linux : media_kit en backend.
  VideoPlayerMediaKit.ensureInitialized(
    android: false,
    iOS: false,
    macOS: true,
    windows: true,
    linux: true,
  );
  runApp(const SigSolsApp());
}
