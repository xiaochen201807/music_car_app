import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_car_app/features/player/portrait_player_view.dart';
import 'package:music_car_app/free_music_api.dart';
import 'package:music_car_app/utils/lyrics_utils.dart';

void main() {
  const List<FreeMusicLyricLine> lines = <FreeMusicLyricLine>[
    FreeMusicLyricLine(time: Duration(seconds: 1), text: '第一句'),
    FreeMusicLyricLine(time: Duration(seconds: 5), text: '第二句'),
    FreeMusicLyricLine(time: Duration(seconds: 8), text: '第三句'),
  ];

  test('activeLyricLineIndex returns no line before first timestamp', () {
    expect(activeLyricLineIndex(lines, Duration.zero), -1);
    expect(
      activeLyricLineIndex(const <FreeMusicLyricLine>[], Duration.zero),
      -1,
    );
  });

  test('activeLyricLineIndex follows the latest elapsed lyric timestamp', () {
    expect(activeLyricLineIndex(lines, const Duration(seconds: 1)), 0);
    expect(activeLyricLineIndex(lines, const Duration(seconds: 4)), 0);
    expect(activeLyricLineIndex(lines, const Duration(seconds: 5)), 1);
    expect(activeLyricLineIndex(lines, const Duration(seconds: 7)), 1);
    expect(activeLyricLineIndex(lines, const Duration(seconds: 8)), 2);
    expect(activeLyricLineIndex(lines, const Duration(seconds: 99)), 2);
  });

  test(
    'activeLyricLineIndex can select the next lyric before its timestamp',
    () {
      expect(
        activeLyricLineIndex(
          lines,
          const Duration(milliseconds: 4300),
          lead: lyricHighlightLead,
        ),
        1,
      );
      expect(
        activeLyricLineIndex(
          lines,
          const Duration(milliseconds: 4299),
          lead: lyricHighlightLead,
        ),
        0,
      );
    },
  );

  testWidgets('PlayerLyricsView triggers onSeek when tapping a lyric line', (
    WidgetTester tester,
  ) async {
    final FreeMusicLyrics lyrics = FreeMusicLyrics(raw: 'raw', lines: lines);
    Duration? seekedDuration;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayerLyricsView(
            lyrics: lyrics,
            position: const Duration(seconds: 1),
            lyricsBusy: false,
            lyricsError: '',
            onSeek: (Duration duration) {
              seekedDuration = duration;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('第二句'));
    await tester.pumpAndSettle();

    expect(seekedDuration, const Duration(seconds: 5));
  });
}
