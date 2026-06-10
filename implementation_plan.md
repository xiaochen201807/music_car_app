# Namida-Inspired 质感与可用性提升计划（底部导航与首页布局优化）

本计划旨在根据您的最新截图与使用反馈，优化应用的底部导航路径与首页的元素层级，让整体操作动线更符合日常与车载的使用直觉。

---

## Proposed Changes

### Component 5: 底部导航栏 Tab 调整与全屏播放跳转

#### [MODIFY] [portrait_player_view.dart](file:///Volumes/移动磁盘/bb/music_car_app/lib/features/player/portrait_player_view.dart)
* **Tab 路由跳转微调**：
  - 将底部导航 `PortraitBottomChrome` 的第四个 Tab 由 `'播放'` 替换为 `'设置'`（图标改为 `Icons.settings_rounded`）。
  - 当点击第四个 Tab 时，路由跳转到 `selectedTab = 5`（设置视图）。
  - 微调 `navigationIndex` 指向，使切换到设置页面时，第四个 Tab 能够被正确高亮。
* **MiniPlayer 触发全屏播放**：
  - 确认 `PortraitMiniPlayerBar` 上的点击行为持续映射为 `onSelectTab(4)`（跳转至全屏播放器），维持“点击上方迷你播放栏即可呼出播放器”的高效动线。

---

### Component 6: 首页布局调整与层级优化

#### [MODIFY] [portrait_home_view.dart](file:///Volumes/移动磁盘/bb/music_car_app/lib/features/home/portrait_home_view.dart)
* **移除冗余设置入口**：
  - 移除首页顶部 Header 旁边的“设置”齿轮按钮（因为设置已挪到最下方的导航 Tab 里）。
* **移除音乐源选择**：
  - 在搜索栏下方的芯片（Chip）列表中，移除“网易云音乐”、“酷我音乐”、“海屿你”等音乐源切换芯片，仅保留热搜词芯片，精简界面信息。
* **快捷卡片下沉**：
  - 将快捷卡片网格 `PortraitMetricGrid`（收藏、离线、队列、CarLife）移动到“推荐歌单”模块的下方，使其摆放在页面的最底部。

---

## Verification Plan

### Automated Tests
* 静态分析：执行 `flutter analyze lib test` 确保 0 errors, 0 warnings, 0 infos。
* 单元测试：执行 `flutter test` 确保无任何功能回归。

### Manual Verification
1. **导航动线测试**：
   - 点击底部导航栏的“设置”按钮，验证是否能顺畅切入设置页面，且底部的设置 Tab 呈现选中态。
   - 在播放音乐时，点击底部导航栏上方的迷你播放条（除按钮外的区域），验证能否向上滑出全屏播放器。
2. **首页布局测试**：
   - 打开首页，确认顶部标题右侧无多余设置按钮；搜索栏下方的音乐源切换已全部隐藏。
   - 滚动首页，确认“推荐歌单”处于上部，而“收藏、离线、队列、CarLife”四个卡片垫底显示在底部。
