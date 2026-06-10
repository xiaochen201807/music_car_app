import 'dart:math' as math;
import '../free_music_api.dart';

const Duration lyricHighlightLead = Duration(milliseconds: 700);

int activeLyricLineIndex(
  List<FreeMusicLyricLine> lines,
  Duration position, {
  Duration lead = Duration.zero,
}) {
  final Duration effectivePosition = position + lead;
  if (lines.isEmpty || effectivePosition < lines.first.time) {
    return -1;
  }
  int low = 0;
  int high = lines.length - 1;
  while (low <= high) {
    final int mid = low + ((high - low) >> 1);
    if (lines[mid].time <= effectivePosition) {
      low = mid + 1;
    } else {
      high = mid - 1;
    }
  }
  return math.max(0, high);
}
