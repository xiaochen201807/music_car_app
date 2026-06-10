import 'package:flutter/material.dart';
import '../features/shell/portrait_music_shell.dart';

/// Legacy NativeMusicScaffold, previously used for the car dashboard UI.
/// Now acts as a deprecated wrapper forwarding to PortraitMusicScaffold.
class NativeMusicScaffold extends StatelessWidget {
  const NativeMusicScaffold({super.key});

  @override
  Widget build(BuildContext context) {
    return const PortraitMusicScaffold();
  }
}
