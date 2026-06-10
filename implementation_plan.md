# 页面左右滑动切换实现方案

为竖屏模式下的主 Shell 添加左右滑动手势支持，使用户可以通过左右滑动在 **首页-搜索-音乐库-设置** 之间进行顺畅的切换，而无需频繁点击底栏。

## 用户审核要求

在当前的设计中，全屏播放器界面 `PortraitPlayerView` 同样属于导航项中的一环（`selectedTab == 4`）。我们将常规页面和全屏播放器解耦：
- 常规页面使用 `PageView` 组合并始终保存在底层，完美保留每个页面的滚动位置、输入内容等状态。
- 全屏播放器仅在打开时作为全屏覆盖层滑入。
- 该优化提升了应用整体的流畅度，并消除了状态丢失的问题。

> [!NOTE]
> 左右滑动切换只会发生在：**首页 (0) ↔ 搜索 (1) ↔ 音乐库 (2) ↔ 设置 (5)**。
> 全屏播放器页面本身有其切歌的左右滑动手势，因此将它排除在常规 Tab 滚动之外，防止手势冲突。

## 方案设计

### 1. 双向状态绑定与防死循环
引入 `PageController`，与全局 `appState.selectedTab` 建立双向映射：
- **从底栏点击或代码跳转（外部更新）**：`build` 方法检测到 `selectedTab` 变动，通过 `PageController.animateToPage` 以动画平滑滚动到对应页面。
- **从页面左右滑动（内部更新）**：`PageView.onPageChanged` 监听到滚动，调用 `appState.selectTab` 同步更新底栏状态。
- **死循环防止**：在通过代码触发滚动时，设置 `_isAnimatingToPage = true`，在此期间忽略 `onPageChanged` 对 `appState.selectTab` 的重复调用。

### 2. 状态保留与覆盖层设计
为了避免每次进入播放器都销毁常规 Tab 页面导致状态丢失，将架构优化为：
- `Stack` 底层：`PageView`（包含首页、搜索、音乐库、设置），通过 `IgnorePointer` 在播放器打开时禁用手势。
- `Stack` 顶层：`AnimatedSwitcher` 承载 `PortraitPlayerView`。

---

## 拟定修改

### 竖屏主 Shell 组件 (features/shell)

#### [MODIFY] [portrait_music_shell.dart](file:///Volumes/%E7%A7%BB%E5%8A%A8%E7%A3%81%E7%9B%98/bb/music_car_app/lib/features/shell/portrait_music_shell.dart)
- 将 `PortraitMusicScaffold` 从 `StatelessWidget` 重构为 `StatefulWidget`。
- 添加 `PageController` 成员变量，在 `didChangeDependencies` 进行基于当前 `selectedTab` 的初始化。
- 提取并重构 `_buildScaffold` 中的子页面构建逻辑。
- 将 `body` 替换为 `Stack`，结合 `PageView`（常规页）与 `AnimatedSwitcher + PortraitPlayerView`（全屏播放器覆盖层），并处理好 `IgnorePointer` 手势隔离。
- 实现双向绑定同步方法 `_onPageChanged`，以及在 `build` 周期内对 `selectedTab` 修改的后帧监测 (`addPostFrameCallback`) 与滚动同步。

---

## 验证计划

### 自动构建与静态检查
- 运行 `flutter analyze` 确保无 Lint 错误和编译警告。

### 手动测试流程
1. **常规滑动测试**：在首页向左滑动，看是否能平滑过渡到搜索页，同时底栏“搜索”图标被高亮激活。继续滑动直至“设置”页。
2. **底栏点击测试**：在“设置”页点击底栏的“首页”，看页面是否带有平滑滚动动画返回首页。
3. **按钮跳转测试**：在首页点击“收藏”或“离线”卡片，看是否能正确滑入“音乐库”或“设置”页，且底栏正确跟随。
4. **播放器交互与手势冲突测试**：
   - 点击迷你播放器打开全屏播放器，看播放器是否从底部正常滑入覆盖。
   - 在播放器中尝试左右滑动切歌，看是否与常规页面发生冲突（不应引起底页滚动）。
   - 关闭播放器，常规页面应该恢复，且恢复后原先的滚动进度、搜索框输入等状态依然保留。
