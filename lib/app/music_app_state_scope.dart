import 'package:flutter/material.dart';

// 我们会在 main.dart 里将 _NativeMusicHomePageState 变为公开类 NativeMusicHomePageState。
// 并且在 main.dart 里 import 这个 scope 文件。
import '../main.dart';

/// 使用 InheritedWidget 构建的全局状态共享组件。
/// 使子视图（Home, Player, Search, Library, Settings）免去层层构造传参的痛苦，
/// 直接通过 context 订阅或调起全局播控动作。
class MusicAppStateScope extends InheritedWidget {
  const MusicAppStateScope({
    super.key,
    required this.state,
    required super.child,
  });

  final NativeMusicHomePageState state;

  /// 静态便捷获取主状态的方法。
  static NativeMusicHomePageState of(BuildContext context) {
    final MusicAppStateScope? result =
        context.dependOnInheritedWidgetOfExactType<MusicAppStateScope>();
    assert(result != null, 'No MusicAppStateScope found in context');
    return result!.state;
  }

  @override
  bool updateShouldNotify(MusicAppStateScope oldWidget) {
    // 这里始终返回 true 以确保状态字段发生变更时，订阅的子 Widget 能够重绘刷新
    return true;
  }
}
