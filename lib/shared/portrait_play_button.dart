import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import 'portrait_circle_button.dart'; // 引入 BounceTouchable

/// 高端主播放/暂停渐变发光按钮
class PortraitPlayButton extends StatelessWidget {
  const PortraitPlayButton({
    super.key,
    required this.playing,
    required this.onTap,
    this.size = 76,
    this.iconSize,
    this.tooltip,
  });

  final bool playing;
  final VoidCallback? onTap;
  final double size;
  final double? iconSize;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final double resolvedIconSize = iconSize ?? size * 0.55;
    final Widget button = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColor.accentGradient,
        border: Border.all(color: AppColor.strokeStrong),
        boxShadow: <BoxShadow>[AppShadow.controlPrimary],
      ),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    AppColor.textPrimary.withValues(alpha: 0.28),
                    Colors.transparent,
                    colors.shadow.withValues(alpha: 0.14),
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: Transform.translate(
              offset: playing ? Offset.zero : Offset(size * 0.03, 0),
              child: Icon(
                playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: resolvedIconSize,
                color: AppColor.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );

    return Tooltip(
      message: tooltip ?? (playing ? '暂停' : '播放'),
      child: BounceTouchable(onTap: onTap, child: button),
    );
  }
}
