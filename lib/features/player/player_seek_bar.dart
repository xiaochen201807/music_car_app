import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';
import '../../utils/formatters.dart';

class PlayerSeekBar extends StatefulWidget {
  const PlayerSeekBar({
    super.key,
    required this.position,
    required this.bufferedPosition,
    required this.duration,
    required this.busy,
    required this.onSeek,
  });

  final Duration position;
  final Duration bufferedPosition;
  final Duration duration;
  final bool busy;
  final ValueChanged<Duration>? onSeek;

  @override
  State<PlayerSeekBar> createState() => _PlayerSeekBarState();
}

class _PlayerSeekBarState extends State<PlayerSeekBar> {
  double? _dragValue;
  bool _isDragging = false;

  double _fractionFor(Duration value, int totalMs) {
    if (totalMs <= 0) {
      return 0.0;
    }
    return (value.inMilliseconds / totalMs).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool isLight = theme.brightness == Brightness.light;
    final int totalMs = widget.duration.inMilliseconds;
    final bool enabled = totalMs > 0 && widget.onSeek != null;
    final double playedValue = _isDragging
        ? (_dragValue ?? 0.0)
        : _fractionFor(widget.position, totalMs);
    final double bufferedValue = _fractionFor(widget.bufferedPosition, totalMs);
    final Duration previewPosition = Duration(
      milliseconds: (playedValue * totalMs).round(),
    );
    // Light: visible graphite track on paper. Dark: soft white glass track.
    final Color trackColor = isLight
        ? AppColor.paperInk.withValues(alpha: 0.10)
        : colors.surfaceContainerHighest.withValues(alpha: 0.28);
    final Color bufferedColor = isLight
        ? AppColor.paperInk.withValues(alpha: 0.16)
        : colors.onSurface.withValues(alpha: 0.18);

    return RepaintBoundary(
      child: Semantics(
        label: '播放进度',
        value:
            '${formatDuration(previewPosition)} / ${formatDuration(widget.duration)}',
        increasedValue: '快进',
        decreasedValue: '后退',
        child: SizedBox(
          height: kMinInteractiveDimension,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Positioned.fill(
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: SizedBox(
                      height: AppSpace.xs,
                      child: Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          DecoratedBox(
                            decoration: BoxDecoration(color: trackColor),
                          ),
                          FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: bufferedValue,
                            child: DecoratedBox(
                              decoration: BoxDecoration(color: bufferedColor),
                            ),
                          ),
                          FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: playedValue.clamp(0.0, 1.0),
                            child: const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: AppColor.accentGradient,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: AppSpace.xs,
                    activeTrackColor: Colors.transparent,
                    inactiveTrackColor: Colors.transparent,
                    disabledActiveTrackColor: Colors.transparent,
                    disabledInactiveTrackColor: Colors.transparent,
                    thumbColor: colors.primary,
                    disabledThumbColor: Colors.transparent,
                    thumbShape: RoundSliderThumbShape(
                      enabledThumbRadius: _isDragging
                          ? AppSpace.sm
                          : AppSpace.xs,
                    ),
                    overlayShape: RoundSliderOverlayShape(
                      overlayRadius: AppSpace.xl,
                    ),
                    trackShape: const _FullWidthTrackShape(),
                  ),
                  child: Slider(
                    value: playedValue.clamp(0.0, 1.0),
                    onChanged: enabled
                        ? (double value) {
                            setState(() {
                              _isDragging = true;
                              _dragValue = value;
                            });
                          }
                        : null,
                    onChangeStart: enabled
                        ? (double value) {
                            setState(() {
                              _isDragging = true;
                              _dragValue = value;
                            });
                          }
                        : null,
                    onChangeEnd: enabled
                        ? (double value) {
                            widget.onSeek?.call(
                              Duration(milliseconds: (value * totalMs).round()),
                            );
                            setState(() {
                              _isDragging = false;
                              _dragValue = null;
                            });
                          }
                        : null,
                  ),
                ),
              ),
              if (_isDragging || widget.busy)
                Positioned(
                  right: AppSpace.md,
                  bottom: AppSpace.xs,
                  child: Text(
                    widget.busy
                        ? '加载中'
                        : '${formatDuration(previewPosition)} / ${formatDuration(widget.duration)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FullWidthTrackShape extends SliderTrackShape with BaseSliderTrackShape {
  const _FullWidthTrackShape();

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isEnabled = false,
    bool isDiscrete = false,
    double additionalActiveTrackHeight = 0,
  }) {}

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final double trackHeight = sliderTheme.trackHeight ?? AppSpace.xs;
    final double trackTop =
        offset.dy + (parentBox.size.height - trackHeight) / 2;
    return Rect.fromLTWH(
      offset.dx,
      trackTop,
      parentBox.size.width,
      trackHeight,
    );
  }
}
