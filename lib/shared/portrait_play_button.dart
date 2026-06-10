import 'package:flutter/material.dart';

class PortraitPlayButton extends StatelessWidget {
  const PortraitPlayButton({
    super.key,
    required this.playing,
    required this.onTap,
  });

  final bool playing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      style: IconButton.styleFrom(
        fixedSize: const Size.square(76),
        elevation: 6,
      ),
      iconSize: 42,
      onPressed: onTap,
      icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
    );
  }
}
