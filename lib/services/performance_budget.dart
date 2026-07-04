class PerformanceBudget {
  const PerformanceBudget({
    required this.name,
    required this.maxDuration,
    required this.owner,
    required this.description,
  });

  final String name;
  final Duration maxDuration;
  final String owner;
  final String description;
}

class PerformanceBudgetResult {
  const PerformanceBudgetResult({
    required this.budget,
    required this.actualDuration,
  });

  final PerformanceBudget budget;
  final Duration actualDuration;

  bool get passed => actualDuration <= budget.maxDuration;

  int get overByMs =>
      actualDuration.inMilliseconds - budget.maxDuration.inMilliseconds;
}

const List<PerformanceBudget> musicCarPerformanceBudgets = <PerformanceBudget>[
  PerformanceBudget(
    name: 'app_start_to_interactive',
    maxDuration: Duration(milliseconds: 2500),
    owner: 'startup',
    description: '冷启动到首页可交互',
  ),
  PerformanceBudget(
    name: 'search_first_page',
    maxDuration: Duration(milliseconds: 2500),
    owner: 'search',
    description: '输入搜索词到首屏结果返回',
  ),
  PerformanceBudget(
    name: 'play_request_to_ready',
    maxDuration: Duration(milliseconds: 3500),
    owner: 'playback',
    description: '点歌到播放器完成 URL 解析并开始播放',
  ),
  PerformanceBudget(
    name: 'lyrics_load',
    maxDuration: Duration(milliseconds: 2000),
    owner: 'lyrics',
    description: '当前歌曲歌词加载完成',
  ),
  PerformanceBudget(
    name: 'playlist_first_page',
    maxDuration: Duration(milliseconds: 3000),
    owner: 'playlist',
    description: '歌单首屏歌曲列表加载完成',
  ),
];

PerformanceBudget? findPerformanceBudget(String name) {
  for (final PerformanceBudget budget in musicCarPerformanceBudgets) {
    if (budget.name == name) {
      return budget;
    }
  }
  return null;
}

PerformanceBudgetResult? evaluatePerformanceBudget(
  String name,
  Duration actualDuration,
) {
  final PerformanceBudget? budget = findPerformanceBudget(name);
  if (budget == null) {
    return null;
  }
  return PerformanceBudgetResult(
    budget: budget,
    actualDuration: actualDuration,
  );
}
