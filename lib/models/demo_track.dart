import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import '../utils/formatters.dart';

class DemoTrack {
  const DemoTrack({
    required this.title,
    required this.artist,
    required this.duration,
    required this.color,
    required this.mark,
  });

  final String title;
  final String artist;
  final Duration duration;
  final Color color;
  final String mark;

  String get durationText => formatDuration(duration);
}

const List<DemoTrack> demoQueue = <DemoTrack>[
  DemoTrack(
    title: 'Highway Morning',
    artist: 'Native Radio',
    duration: Duration(minutes: 3, seconds: 42),
    color: AppColor.glowViolet,
    mark: 'H',
  ),
  DemoTrack(
    title: 'City Lights',
    artist: 'Drive Session',
    duration: Duration(minutes: 4, seconds: 8),
    color: AppColor.glowCyan,
    mark: 'C',
  ),
  DemoTrack(
    title: 'Ocean Avenue',
    artist: 'Glass FM',
    duration: Duration(minutes: 3, seconds: 25),
    color: AppColor.textSecondary,
    mark: 'O',
  ),
  DemoTrack(
    title: 'Late Night Loop',
    artist: 'CarPlay Mix',
    duration: Duration(minutes: 5, seconds: 1),
    color: AppColor.textTertiary,
    mark: 'L',
  ),
  DemoTrack(
    title: 'Silent Dashboard',
    artist: 'iMusic Lab',
    duration: Duration(minutes: 2, seconds: 57),
    color: AppColor.glowViolet,
    mark: 'S',
  ),
];

const List<DemoTrack> recentTracks = <DemoTrack>[
  DemoTrack(
    title: 'Morning Pulse',
    artist: 'Daily Drive',
    duration: Duration(minutes: 3, seconds: 9),
    color: AppColor.glowCyan,
    mark: 'M',
  ),
  DemoTrack(
    title: 'Warm Start',
    artist: 'Engine Room',
    duration: Duration(minutes: 4, seconds: 12),
    color: AppColor.textTertiary,
    mark: 'W',
  ),
  DemoTrack(
    title: 'Signal Green',
    artist: 'Route 88',
    duration: Duration(minutes: 3, seconds: 33),
    color: AppColor.textSecondary,
    mark: 'G',
  ),
];
