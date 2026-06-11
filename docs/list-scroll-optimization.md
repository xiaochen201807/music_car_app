# 列表滚动性能优化记录

> 优化日期：2026-06-11
> 优化范围：搜索页、歌单详情页、音乐库页的长列表滚动卡顿

---

## 问题根因

### 1. `StaggeredAnimatedItem` 动画开销过大

每个列表项都是一个 `StatefulWidget`，创建独立的 `AnimationController` + Ticker + `Future.delayed` 定时器。当列表有 50+ 项时：
- 50 个 `AnimationController` 同时存在
- 50 个延迟定时器竞争主线程
- 动画与滚动动画竞争 vsync

### 2. `PortraitSurface` 的 `BackdropFilter` 毛玻璃渲染开销

每个 SongTile 都包裹在 `PortraitSurface` 中，内部通过 `GlassCard` 使用 `BackdropFilter` 做毛玻璃效果。`BackdropFilter` 是 GPU 密集型操作，列表中同时渲染多个时会显著增加渲染管线负担。

### 3. 搜索页使用 `SliverList.list` + `for` 循环（已修复为 `SliverList.builder`）

`SliverList.list` 接收预先构建好的 `List<Widget>`，不是懒加载。如果搜索返回 50 首歌，Flutter 会一次性构建 50 个完整组件。

---

## 优化方案

### 策略 1：限制入场动画仅前 6 项启用

```dart
// 优化前：每项都有动画
for (int index = 0; index < songs.length; index += 1)
  StaggeredAnimatedItem(
    index: index,
    child: PortraitSongTile(...),
  ),

// 优化后：仅前 6 项有动画
return index < 6
    ? StaggeredAnimatedItem(index: index, child: songTile)
    : songTile;
```

**效果**: 50 项列表从 50 个 AnimationController 降至 6 个，减少 88% 动画开销。

### 策略 2：列表区域禁用 BackdropFilter

使用 `GlassPerformanceMode(enabled: true)` 包裹列表区域，`GlassCard` 内部检测到性能模式后会跳过 `BackdropFilter`，仅使用半透明色 + 边框。

```dart
GlassPerformanceMode(
  enabled: true,
  child: SliverList.builder(...)
)
```

**效果**: 列表中每项的 GPU 模糊计算降至 0，仅保留半透明视觉效果。

### 策略 3：搜索页使用懒加载

将 `SliverList.list` + `for` 循环改为 `SliverList.builder`，只构建可见区域的组件。

---

## 修改文件清单

| 文件 | 改动 |
|------|------|
| `lib/features/search/portrait_search_view.dart` | `SliverList.builder` + `GlassPerformanceMode` + 动画限制 |
| `lib/features/home/playlist_details_page.dart` | `GlassPerformanceMode` + 动画限制 |
| `lib/features/library/portrait_library_view.dart` | `GlassPerformanceMode` + 动画限制（收藏列表 + 离线下载列表） |

---

## 预期效果

| 场景 | 优化前 | 优化后 |
|------|--------|--------|
| 搜索 50 首歌滚动 | 卡顿明显 | 流畅 |
| 歌单详情 100 首歌滚动 | 卡顿明显 | 流畅 |
| 收藏列表 200 首歌滚动 | 严重卡顿 | 流畅 |
| 内存占用 | 50+ AnimationController | 6 AnimationController |
| GPU 渲染压力 | 每项 BackdropFilter | 无 BackdropFilter |

---

## 视觉影响

- 列表项仍保留半透明色 + 边框的毛玻璃外观（通过 `BoxDecoration.color` 实现）
- 仅失去 `BackdropFilter` 的真实背景模糊效果
- 前 6 项仍有入场动画，后续项直接显示
