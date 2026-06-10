# 竖屏音乐体验重构 Playbook

本文档是 `codex/portrait-music-redesign` 分支的执行手册，用来承接另一个
AI 对竖屏工作的理解，并结合本仓库已经完成的实现状态继续推进。

它不是从零开始的产品方案，而是后续 AI/开发者继续重构时必须优先参考的
handoff 文档。

## 1. 当前基线

稳定横屏检查点：

- 分支：`codex/native-ios-music-ui`
- 标签：`v1.0.20`
- 提交：`ed708b8 feat: 实现本地收藏歌曲功能`

当前竖屏工作分支：

- 分支：`codex/portrait-music-redesign`
- 已推送提交：`11dff02 feat: add portrait music experience`
- 继续开发前先执行 `git status --short --branch`，确认仍在该分支且没有混入无关改动。

当前竖屏基础已经完成：

- 可见主界面已经切换为竖屏优先。
- App 方向限制为 `portraitUp` 和 `portraitDown`。
- Material 3 Light/Dark 主题已经接入 `ThemeMode`。
- 设置页已有主题模式切换入口。
- 当前播放封面通过 `palette_generator` 抽取主色，并作为竖屏界面的动态 seed color。
- 首页已有搜索 hero、热搜/音源 chips、推荐歌单网格、状态数据卡、播放时间线。
- 搜索页继续使用现有 `FreeMusicApi.searchSongs`。
- 媒体库页已有收藏和当前队列。
- 全屏播放器已有大封面、Hero 过渡、标题/艺人、波形 seekbar、竖向控制区、歌词预览、音质 chips。
- 底部 mini-player 与 `NavigationBar` 已在非全屏播放器页面启用。
- 现有 FreeMusic API、native queue、`audio_service`、收藏、本地播放路径和 CarLife 服务路径保持可用。
- Widget test 已覆盖竖屏首页、媒体库、播放器和设置页。

当前技术债：

- 第一版竖屏实现仍主要集中在 `lib/main.dart`，后续必须按功能拆分。
- 旧横屏 widget 还保留为兼容/回退代码，导致 `unused_element`；当前通过
  `// ignore_for_file: unused_element` 临时压制。
- `palette_generator 0.3.3+7` 在 pub 上标记为 discontinued。当前能通过分析和测试，
  但需要在后续主题硬化阶段评估替换或实现内部轻量采样器。
- 下载/离线缓存还未实现，目前设置页只有占位入口。
- 主题模式还未持久化。

## 2. 与现有设计契约的关系

`docs/ui/design-spec.md` 是上一阶段横屏车机玻璃拟态 UI 的数值契约，其中一部分
仍然是强约束，一部分需要由本 playbook 的竖屏规则覆盖。

继续保留的强约束：

- 颜色、间距、圆角、字体、阴影应优先来自 `lib/theme/design_tokens.dart`。
- 卡片、面板、pill 应逐步统一到共享玻璃组件，不要在 widget 内随手拼
  `Container + 半透明背景`。
- 网络封面必须走 `cached_network_image` 或 `CachedNetworkImageProvider`，
  禁止新增裸 `Image.network`。
- 高饱和强调色要克制使用，主要用于主播放按钮、进度条已播放段、激活导航、
  收藏激活态等关键状态。
- UI 必须具备加载、空、错误、重试、局部数据可用等状态，不允许只做静态好看页面。

由本 playbook 覆盖的部分：

- 旧设计契约中的 `1920x1080` 横屏布局、侧栏/右栏比例、横屏 mini-player 尺寸不再作为
  竖屏实现基准。
- 新基准是手机 portrait-first：优先保证 360x800、390x844、430x932 等常见竖屏尺寸
  不溢出，再扩展到平板竖屏和车机类大屏。
- 新主视觉参考 Namida 的 Material 3、动态封面主色、沉浸式播放页、竖向控制区和高密度媒体库。
- CarLife 继续支持，但 CarLife 入口不应该重新把首页变回车机 dashboard。

后续 UI 清理目标：

- 新增竖屏 widget 时不要扩大硬编码范围。
- 已经存在的第一版竖屏硬编码样式要在拆分组件时逐步迁移到 tokens。
- 最终要删除临时 `unused_element` ignore，而不是长期依赖它。

## 3. 不可破坏的边界

- 不引入新的外部音乐目录 API，例如 JioSaavn、YouTube、Spotify 或其他第三方歌库。
  在线音乐只能使用本项目已有 `FreeMusicApi` 和已审计后端服务。
- 不破坏 native queue 合约。搜索、歌单、收藏、media session、CarLife 都必须继续走同一套队列模型。
- 不移除或弱化 CarLife。可以调整入口位置，但不能删除 `CarLifeService`、
  播放上下文同步、原生 MethodChannel 回调处理。
- 不在本地运行 release 打包命令，除非用户明确要求。验证只跑格式化、静态分析、测试等轻量命令。
- 不把 UI 直接绑定到临时播放 URL。播放 URL 解析仍由现有播放/队列层负责。
- 不把 Flutter UI 层的 phone-local 文件路径直接传给 CarLife，除非后续已验证原生 SDK 明确支持。

## 4. 当前架构

必须保留并继续复用的核心层：

- `lib/free_music_api.dart`：FreeMusic 搜索、推荐、歌单、歌词、音质、播放 URL 等 API 客户端。
- `lib/native_audio_controller.dart`：native queue、URL 解析、播放模式、队列持久化、音源切换 fallback。
- `lib/music_audio_handler.dart`：`audio_service` media session、通知/耳机/媒体按钮控制。
- `lib/favorite_song_store.dart`：本地收藏歌曲持久化。
- `lib/services/carlife_service.dart`：Flutter 与 Android CarLife bridge 的 MethodChannel 封装。
- `lib/theme/design_tokens.dart`：旧设计系统和后续共享样式的 token 来源。
- `lib/widgets/glass_card.dart`：玻璃卡片/玻璃 pill 的共享实现。

建议目标目录：

```text
lib/
  app/
    app_theme.dart
    app_shell.dart
    orientation.dart
  features/
    home/
      portrait_home_view.dart
      portrait_playlist_card.dart
      portrait_timeline.dart
    search/
      portrait_search_view.dart
      portrait_search_result_tile.dart
    library/
      portrait_library_view.dart
      portrait_favorites_section.dart
      portrait_queue_section.dart
    player/
      portrait_player_view.dart
      portrait_mini_player.dart
      waveform_seekbar.dart
      portrait_lyrics_preview.dart
    settings/
      portrait_settings_view.dart
      carlife_settings_card.dart
    downloads/
      download_cache_service.dart
      download_cache_store.dart
      downloads_view.dart
  shared/
    portrait_artwork.dart
    portrait_surface.dart
    portrait_chip.dart
    portrait_song_tile.dart
```

拆分原则：

- 不为了目录好看一次性大搬家。
- 每次只移动一组清晰 widget，并同步移动/补充测试。
- 移动后保持 `flutter analyze` 和相关 widget test 通过。
- 旧横屏代码如果还需要保留，应隔离成 legacy 文件或明确 fallback，而不是继续混在主竖屏文件里。

## 5. 产品与视觉方向

主参考：Namida。

需要学习的重点：

- Material 3 的干净层次，而不是传统车机 dashboard。
- 根据当前封面提取动态主色，但背景仍要克制，避免整屏高饱和。
- 沉浸式全屏播放页：上方大封面，下方标题、波形进度、控制按钮、歌词/音质信息竖向堆叠。
- 首页高密度卡片：搜索入口、推荐网格、时间线、最近播放/当前队列。
- 动画要有音乐产品的流动感，例如 Hero、隐式动画、页面进入 stagger，而不是堆砌特效。

辅助参考：

- Hivefy：Spotify-like 卡片密度、底部播放栏节奏、移动端导航结构。
- Musify：在线流媒体、下载、离线状态和列表组织。
- BlackHole：搜索、播放列表、深色/强调色主题、下载入口和简洁操作。

实现要求：

- 使用 Flutter 原生 widgets、Material 3、`ThemeData`。
- 继续使用项目现有 API。
- 优先 portrait，兼顾响应式。
- 继续支持 CarLife。
- UI 代码要可拆分、可测试、可维护。

## 6. 页面执行标准

### 6.1 首页

必须包含：

- 竖屏顶部标题和状态摘要。
- 一手可操作的搜索 hero，直连 FreeMusic 搜索。
- 热搜 chips，来自现有 `/search/hot`。
- 音源 chips，来自现有 `/sources`。
- 推荐歌单网格，来自 `FreeMusicApi.fetchRecommendations`。
- 播放时间线，优先来自真实最近播放；当前可暂时回退到 native queue。
- 收藏、队列、CarLife、下载/缓存等状态卡。

已完成：

- 搜索 hero。
- 推荐网格。
- 热搜/音源 chips。
- 状态数据卡。
- 当前队列 timeline fallback。

下一步：

- 增加 staggered entry animation。
- 推荐卡片继续打磨封面、标题、创建者、来源、歌曲数的层次。
- 增加真实最近播放历史持久化，替代当前队列 fallback。
- 点击推荐歌单时优先打开竖屏歌单详情页，而不是旧 bottom sheet 体验。

### 6.2 搜索

必须包含：

- 适合单手输入的搜索栏。
- 热门关键词快速填充。
- 搜索结果 tile 支持播放、收藏、加入队列。
- 加载、空、错误、重试、分页加载状态。

已完成：

- 使用 `FreeMusicApi.searchSongs`。
- 结果行可播放、收藏、加入队列。

下一步：

- 如果现有 API 覆盖专辑/艺术家/歌单搜索，则增加分组结果。
- 结果进入列表时增加轻量动画。
- 保留分页加载，不要回退到只加载第一页。

### 6.3 媒体库

必须包含：

- 收藏歌曲。
- 当前队列。
- 下载/离线 section，等待缓存服务完成后接入。
- 后续可接入歌单、专辑、艺术家，但必须以现有 API 能力为前提。

已完成：

- 收藏 section。
- 队列 section。

下一步：

- 收藏和队列较长时改为 tabs 或 segmented controls。
- 增加下载 section。
- 歌单详情改为竖屏 page。

### 6.4 播放器

必须包含：

- 沉浸式全屏 surface。
- 从 mini-player 到全屏的大封面 Hero 过渡。
- 根据封面主色生成动态背景。
- 标题/艺人居中展示。
- 波形 seekbar，支持拖动 seek。
- 播放模式、上一首、播放/暂停、下一首、歌词、收藏。
- 下载按钮和离线状态，等待缓存服务完成后接入。
- 歌词预览，后续升级为同步滚动歌词。
- 音质 chips 来自现有 qualities API。

已完成：

- 全屏竖屏播放器。
- Hero artwork。
- 动态 seed 背景。
- 波形 seekbar 已连接 `audio_service.seek`。
- 歌词预览。
- 音质 chips。
- 收藏控制。

下一步：

- 增加完整歌词滚动同步。
- 当前波形是生成式视觉 bars；如果后续有后端或本地分析数据，再替换为真实 waveform。
- 增加下载按钮和本地缓存状态。
- 评估 shared-axis/container transform，避免牺牲流畅度。

### 6.5 设置

必须包含：

- Light/Dark/System 主题模式。
- CarLife 状态、打开、同步入口。
- 更新检查。
- 下载/缓存管理入口。
- 调试信息，后续可包含 palette/cache 状态。

已完成：

- 主题模式切换。
- CarLife card。
- 更新检查。
- 缓存管理占位 card。

下一步：

- 持久化主题选择。
- 增加真实缓存管理页。
- 增加 palette 提取失败/缓存命中等诊断信息。

## 7. 主题与动态颜色计划

当前实现：

- `MusicCarApp` 持有 `ThemeMode`。
- `ThemeData` 使用 Material 3 和 `ColorScheme.fromSeed`。
- `_NativeMusicHomePageState` 从当前封面抽取 seed color。
- `_PortraitMusicScaffold` 使用当前 seed color 生成局部动态 `ColorScheme`。

下一步顺序：

1. 使用 `SharedPreferences` 持久化 `ThemeMode`。
2. 将主题状态提取到 `lib/app/app_theme.dart` 或轻量 controller。
3. 按 artwork URL 缓存 palette 结果，避免重复抽取。
4. 对坏封面 URL、慢网络、抽色失败做非阻塞 fallback。
5. 评估是否替换 `palette_generator`。
6. 如果加入 Android Material You 系统动态色，必须明确和封面动态色的优先级，不能互相打架。

动态颜色约束：

- 封面 seed color 可以影响局部背景、按钮、slider、chip，但必须降低饱和度或混入中性色。
- 不允许因为一张粉色/红色封面导致整屏高饱和。
- 收藏激活态仍可使用明确红心，不要让动态色影响收藏语义。

## 8. 下载与离线缓存计划

不要新增歌库 API。下载流程必须复用现有解析路径：

1. 使用 `FreeMusicApi.resolveSongUrl(song)` 或现有播放控制层解析可播放 URL。
2. 将解析后的音频文件下载到 app 管理目录。
3. 使用稳定 key 存储 metadata，优先复用 `favoriteSongKey(song)` 或统一的
   `songKey(source, id)`。
4. 播放前先查本地缓存。
5. 命中有效缓存时播放本地文件。
6. 未命中或文件损坏时回退到现有在线解析。
7. CarLife metadata 和队列仍保持 `source/songId` 模型。

建议数据模型：

```dart
class CachedTrack {
  const CachedTrack({
    required this.songKey,
    required this.localPath,
    required this.bytes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String songKey;
  final String localPath;
  final int bytes;
  final DateTime createdAt;
  final DateTime updatedAt;
}

enum DownloadTaskStatus {
  queued,
  running,
  completed,
  failed,
  canceled,
}
```

建议服务形态：

```dart
abstract class DownloadCacheStore {
  Future<CachedTrack?> lookup(FreeMusicSong song);
  Future<List<CachedTrack>> list();
  Future<void> remove(FreeMusicSong song);
  Future<void> clear();
}

abstract class DownloadService {
  Stream<DownloadTaskSnapshot> get snapshots;
  Future<void> enqueue(FreeMusicSong song);
  Future<void> cancel(FreeMusicSong song);
}
```

缓存优先播放要放在播放/队列层，而不是页面 widget 层。UI 只展示状态和触发下载。

CarLife 注意事项：

- 不要直接把手机本地文件路径传给 CarLife，除非 Android bridge 已验证 SDK 支持。
- CarLife 仍同步歌曲 ID、来源、标题、艺人、封面、队列索引、播放状态等 metadata。
- 如果后续 CarLife 需要音频 bytes 或 stream，应在 Android bridge 中适配，而不是在 Flutter UI widget 中硬塞。

## 9. CarLife 回归要求

每次改动播放器、队列、缓存、下载、页面导航时，都要检查 CarLife 边界。

代码层必须保持：

- `CarLifeService` 仍可初始化、查询状态、打开 App、同步 playback context。
- 搜索播放、歌单播放、收藏播放、队列切歌后仍触发上下文同步。
- `selectQueueItem`、next、previous、play/pause 等原生回调路径不被 UI 重构切断。
- Android MethodChannel payload 字段名保持兼容，除非同步修改并测试 Android 端。

真实设备待验证：

- CarLife-capable 设备或车机发现 App。
- 当前队列能同步到 CarLife。
- CarLife 侧选择歌曲能驱动手机端 native queue 播放。
- 播放/暂停/上一首/下一首行为符合当前 SDK 能力边界。

## 10. 实施阶段

### Phase A：竖屏基础

状态：基本完成。

- `[x]` 创建 `codex/portrait-music-redesign` 分支。
- `[x]` 切换 portrait orientation。
- `[x]` 接入 Material 3 Light/Dark。
- `[x]` 接入封面主色抽取。
- `[x]` 首页竖屏 shell。
- `[x]` 搜索页竖屏体验。
- `[x]` 媒体库页。
- `[x]` 全屏播放器。
- `[x]` 波形 seekbar。
- `[x]` CarLife 保持可达。
- `[x]` 更新 widget test。

### Phase B：拆分与架构清理

状态：待做，下一优先级。

- `[ ]` 将首页相关 widget 移出 `lib/main.dart`。
- `[ ]` 将播放器、mini-player、waveform seekbar 移出 `lib/main.dart`。
- `[ ]` 将搜索、媒体库、设置页移出 `lib/main.dart`。
- `[ ]` 建立共享 portrait artwork/surface/chip/song tile。
- `[ ]` 隔离或删除旧横屏 legacy widget。
- `[ ]` 删除 `ignore_for_file: unused_element`。
- `[ ]` 拆分过程中保持测试通过。

### Phase C：竖屏视觉打磨

状态：待做。

- `[ ]` 添加页面进入和列表 stagger 动画。
- `[ ]` 打磨推荐网格密度和封面层次。
- `[ ]` 增加真实最近播放历史。
- `[ ]` 将歌单详情 bottom sheet 改为竖屏 page。
- `[ ]` 播放器增加完整歌词同步滚动。
- `[ ]` 在 360x800、390x844、430x932、tablet portrait 宽度验证无 overflow。

### Phase D：下载与离线缓存

状态：待做。

- `[ ]` 选择 app-managed storage 路径方案。
- `[ ]` 添加缓存 metadata store。
- `[ ]` 添加下载任务服务。
- `[ ]` 播放层实现 cache-first resolution。
- `[ ]` 设置页接入下载/缓存管理页。
- `[ ]` 播放器、搜索结果、收藏、歌单行展示下载状态。
- `[ ]` 增加缓存命中、未命中、删除、下载失败测试。

### Phase E：主题持久化与 palette 硬化

状态：待做。

- `[ ]` 持久化 theme mode。
- `[ ]` 缓存 palette 结果。
- `[ ]` 处理坏图和慢网络。
- `[ ]` 决定保留或替换 `palette_generator`。
- `[ ]` 增加主题切换 widget test。

### Phase F：CarLife 回归验证

状态：待做。

- `[ ]` 搜索结果播放后同步 CarLife，确认 metadata 和队列。
- `[ ]` 收藏歌曲播放后同步 CarLife，确认 metadata 和队列。
- `[ ]` 歌单歌曲播放后同步 CarLife，确认队列范围。
- `[ ]` CarLife 侧选择队列项后手机端播放正确歌曲。
- `[ ]` 确认下载/缓存不会改变 CarLife metadata 合约。
- `[ ]` 有设备时做真实 CarLife-capable 车机验证。

## 11. 验证命令

每个有意义的代码增量后执行：

```powershell
dart format lib test
flutter analyze
flutter test
```

文档-only 改动至少执行：

```powershell
git status --short --branch
git diff --check
```

禁止在未明确要求时执行：

```powershell
flutter build apk
flutter build appbundle
flutter build ipa
```

## 12. Definition Of Done

一个竖屏 UI 增量完成时必须满足：

- `flutter analyze` 通过。
- `flutter test` 通过。
- 未运行本地 release packaging，除非用户明确要求。
- 现有 API 调用保持不变。
- native queue 合约保持不变。
- CarLife 编译路径、入口、上下文同步和回调路径保持可用。
- 小竖屏尺寸无明显 overflow。
- 网络封面使用 cached image。
- 新增 UI 不扩大硬编码颜色/圆角/间距债务。
- 行为或架构变化已同步到 `docs/work-log.md` 和 `docs/development-roadmap.md`。

## 13. 后续建议提交策略

建议按以下顺序小步提交：

1. `refactor: split portrait player widgets`
2. `refactor: split portrait home widgets`
3. `feat: persist theme mode`
4. `feat: add download cache store`
5. `feat: prefer cached tracks during playback`
6. `feat: add portrait downloads manager`
7. `test: add carlife portrait regression coverage`

每个提交只做一类事，避免把 UI 拆分、缓存能力、CarLife 修复混在一起。

## 14. 参考项目

- Namida: https://github.com/namidaco/namida
- Hivefy: https://github.com/Harish-Srinivas-07/hivefy
- Musify: https://github.com/gokadzev/Musify
- BlackHole: https://github.com/Sangwan5688/BlackHole
- Material 3: https://m3.material.io/
