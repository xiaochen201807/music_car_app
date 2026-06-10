import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import 'portrait_circle_button.dart'; // 引入 BounceTouchable

/// 高端主播放/暂停渐变发光按钮
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
    Widget button = Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColor.accentGradient,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColor.accentVioletStart.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(
        playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
        size: 42,
        color: Colors.white,
      ),
    );

    return BounceTouchable(
      onTap: onTap,
      child: button,
    );
  }
}
