import 'package:flutter/material.dart';

import '../../free_music_api.dart';
import '../../services/lyric_offset_store.dart';

class LyricOffsetAdjuster extends StatefulWidget {
  const LyricOffsetAdjuster({
    super.key,
    required this.song,
    required this.currentOffset,
    required this.onOffsetChanged,
  });

  final FreeMusicSong song;
  final Duration currentOffset;
  final ValueChanged<Duration> onOffsetChanged;

  @override
  State<LyricOffsetAdjuster> createState() => _LyricOffsetAdjusterState();
}

class _LyricOffsetAdjusterState extends State<LyricOffsetAdjuster> {
  late Duration _offset;
  final LyricOffsetStore _store = LyricOffsetStore();

  @override
  void initState() {
    super.initState();
    _offset = widget.currentOffset;
  }

  void _adjust(Duration delta) {
    setState(() {
      _offset += delta;
    });
    widget.onOffsetChanged(_offset);
    _store.setOffset(widget.song, _offset);
  }

  void _reset() {
    setState(() {
      _offset = Duration.zero;
    });
    widget.onOffsetChanged(Duration.zero);
    _store.clearOffset(widget.song);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '歌词偏移调整',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '当前偏移: ${_offset.inMilliseconds > 0 ? '+' : ''}${(_offset.inMilliseconds / 1000).toStringAsFixed(1)}秒',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildButton(context, '-1秒', const Duration(seconds: -1)),
              _buildButton(context, '-0.5秒', const Duration(milliseconds: -500)),
              _buildButton(context, '+0.5秒', const Duration(milliseconds: 500)),
              _buildButton(context, '+1秒', const Duration(seconds: 1)),
            ],
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _reset,
            child: const Text('重置'),
          ),
        ],
      ),
    );
  }

  Widget _buildButton(BuildContext context, String label, Duration delta) {
    return OutlinedButton(
      onPressed: () => _adjust(delta),
      child: Text(label),
    );
  }
}
