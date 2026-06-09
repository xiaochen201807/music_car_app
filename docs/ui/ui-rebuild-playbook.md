# 车载音乐 · UI 重建施工单 (Playbook for AI)

> 配套文档:**所有数值以 [`design-spec.md`](./design-spec.md) 为准**,本文件不重复列值,
> 只给「按什么顺序改、改哪个类、怎么验收」。
>
> 这份文件是给执行 AI(GPT)看的工单。每个任务都写明:**目标 / 涉及代码位置 / 做法约束 / 完成判据**。
> 不允许跳过判据自评"完成"。每个任务结束必须跑 `flutter analyze` 且零新增告警。

## 全局铁律(违反即不合格)

1. 不引入新的颜色 / 圆角 / 间距 **字面量**。一律引用 `design_tokens.dart` 的 token。
   - 反例:`BorderRadius.circular(22)`、`Color(0xFFFF5C93)`、`withValues(alpha: 0.08)` 散落各处。
2. 所有卡片背景只能用统一的 `GlassCard`(含 `BackdropFilter` 模糊)。禁止再写 `Container + 半透明 color` 当卡片。
3. 高饱和粉/紫渐变只允许出现在 spec §0 第 1 条列出的 4 个位置。其余改为中性玻璃。
4. 改 UI 不改播放 / 队列 / API 逻辑。本轮纯视觉与布局,不动 `free_music_api.dart`、`music_audio_handler.dart`、`native_audio_controller.dart` 的行为。
5. 每完成一个任务,在 `docs/work-log.md` 追加一行:任务号 + 改了哪些类 + 自测结论。

---

## 任务执行顺序

```
T0 建 token 与基础组件  →  T1 修底部重影 bug  →  T2 全局换冷色板
   →  T3 玻璃模糊落地  →  T4 首页推荐网格重建  →  T5 封面缓存占位
   →  T6 圆角/间距统一收口  →  T7 四态(加载/空/错误)  →  T8 全量验收
```

T0 是地基,必须第一个做完且通过判据,后续任务才有 token 可引用。

---

## T0 — 建立 design_tokens.dart 与基础组件

**目标**:把 spec §1–§8 的值落成代码常量与可复用组件,后续所有任务只引用它们。

**新增文件**
- `lib/theme/design_tokens.dart`:按 spec §8 定义 `AppColor` / `AppSpace` / `AppRadius` / `AppText` / `AppShadow`。
- `lib/widgets/glass_card.dart`:实现 spec §3 的 `GlassCard`(必含 `BackdropFilter(ImageFilter.blur(...))` + tint + 1px 描边 + 圆角)。
- `lib/widgets/glass_card.dart` 内或同目录:`GlassPill`(药丸,给"歌词/顺序/标签/搜索框"复用)。

**做法约束**
- `GlassCard` 必须 `ClipRRect` 包裹再 `BackdropFilter`,否则模糊会溢出圆角。
- blur sigma、tint alpha、描边色、圆角全部取 spec §3 的值,不自创。
- 暂不替换现有 `_GlassCard`,先让新组件可独立编译。

**完成判据**
- `flutter analyze` 零新增告警。
- 写一个临时 demo 页(或在 widget test 里)渲染 `GlassCard`,肉眼确认有模糊。
- token 文件中不出现"魔法数字"注释缺失的值——每个 token 有用途注释。

---

## T1 — 修复底部控制栏「重影 / 幽灵圆」 (最高优先,功能性 bug)

**现象**:真机底部播放/上一首/下一首按钮背后有一圈半透明幽灵圆,按钮像叠了两层。

**根因定位(已查证,直接按此改)**
- 类:`_MiniTransportButton`(约 `lib/main.dart:4230` 起)。
- 它用 `IconButton` + `IconButton.styleFrom(fixedSize: Size.square(58/50), shape: CircleBorder(), backgroundColor: ...)`。
- 问题:`IconButton` 自带最小命中尺寸与内部 padding,`fixedSize` 与图标 padding 不匹配时,
  **背景圆 + Material 的 highlight/hover 圆 + 命中区**会渲染成两层不同半径的圆 → 视觉重影。
- 外层还套了 `Padding(left:10)`,导致三个按钮间距不均,加重"叠在一起"观感。

**做法约束**
- 重写 `_MiniTransportButton`:**不要用 `IconButton`**。改为 `GlassPill`/`Container(shape: circle)` + `InkWell`(或 `GestureDetector`),
  自行精确控制 `width/height = AppSpace` 中定义的命中尺寸,圆背景只画一层。
- splash/highlight 若保留,用 `InkWell` 且 `customBorder: CircleBorder()`,确保 ripple 半径 == 背景半径。
- 主按钮(播放/暂停)渐变取 spec §1 主色;次按钮(上一首/下一首)用中性玻璃,**不要粉色**。
- 按钮间距统一用 `AppSpace`,删掉 `Padding(left:10)` 这种局部偏移。

**完成判据**
- 真机/模拟器截图:三个按钮**只有一层圆**,无幽灵描边,间距均匀。
- 上一首/下一首为中性色,仅播放键为渐变。
- 点击 ripple 不超出按钮圆边界。

---

## T2 — 全局换冷色板(修"全屏热粉")

**目标**:把现有 `_AppColors`(`primary = 0xFFFF5C93` 亮粉、`accent = 0xFFFFB86B` 橙)整体替换为 spec §1 冷色板。

**涉及代码位置**
- `lib/main.dart:4835` 起的 `_AppColors` 类 → 用 `AppColor`(T0)替换,或让 `_AppColors` 内部引用 `AppColor` 做过渡别名。
- `MaterialApp.theme` 的 `ColorScheme.dark(...)`(约 `lib/main.dart:51`)→ 改用 spec §1 值。

**做法约束**
- 粉色不是全删,而是**降级为强调色**:仅 spec §0 第 1 条 4 个位置可用渐变 `accentGradient`。
- 搜索按钮"搜索"目前是实心亮粉(见真机图)→ 改为中性玻璃 `GlassPill`,文字/图标用 `textPrimary`;
  若要强调,最多用 1px 渐变描边,不要实心粉。
- 全局文字三级灰按 spec §1.3。

**完成判据**
- 全屏截图中**高饱和粉色面积 < 5%**,且只出现在允许位置。
- 背景呈深靛蓝→近黑的冷调径向渐变(对照原型 PNG)。
- `grep 0xFFFF5C93` 在 `lib/` 下应**为 0**(已迁移到 token)。

---

## T3 — 玻璃模糊落地(修"贴片不是玻璃")

**目标**:所有卡片/面板/药丸换成 T0 的 `GlassCard` / `GlassPill`,带真实 `BackdropFilter` 模糊。

**涉及代码位置**
- 现有 `_GlassCard`(约 `lib/main.dart:4740`)目前只是 `Container + boxShadow`,**无模糊**。
  → 替换其实现为引用 T0 `GlassCard`,或全量改用新组件并删除旧类。
- 检查所有手拼的 `Container(decoration: BoxDecoration(color: Colors.white.withValues(alpha: ...)))`
  当卡片背景用的地方,统一替换为 `GlassCard`/`GlassPill`。

**做法约束**
- 背景必须先有 `_AtmosphereBackground`(已存在,约 `lib/main.dart:1566`)的彩色光晕,玻璃模糊才看得出效果。光晕色改为 spec §1 的 `glowViolet`,不要用 `track.color` 的高饱和直出。
- 模糊层级:大面板 sigma 取 spec §3 大值,药丸取小值,避免全部一样导致发灰。

**完成判据**
- 卡片边缘能看到背景光晕被"磨砂"过的效果(放大截图可见模糊过渡)。
- 无 `BackdropFilter` 溢出圆角的硬边(说明 `ClipRRect` 包对了)。

---

## T4 — 首页推荐网格重建(修"推荐网格丢失")

**现象**:真机首页只有巨大搜索框 + 一个标签,原型里的"为你推荐"卡片网格整个没了。

**目标**:按 spec §6.1 重建首页推荐区——顶部标题行,下面是推荐歌单网格(对照原型:大卡 + 小卡的横向卡组)。

**涉及代码位置**
- 首页中心面板(`selectedTab == 0` 对应的 surface,装配在 `lib/main.dart:1442` 附近的 switch)。
- 数据已就绪:`_recommendedPlaylists`(已由 `_loadRecommendations()` 填充)。不要新建 API,直接用它渲染。

**做法约束**
- 用 spec §2 间距系统排栅格,卡片尺寸/圆角取 spec §6.1。
- 搜索框缩回 spec §6.1 指定尺寸,不要占满整行。
- 卡片背景用 `GlassCard`,封面用 T5 的缓存组件。
- 空/加载/错误三态走 T7。

**完成判据**
- 首页同屏可见:侧栏 + 标题 + 推荐网格(≥1 行多卡)+ 迷你播放器,布局密度接近原型,无大片空白。
- 卡片尺寸一致、圆角统一、间距来自 token。

---

## T5 — 封面缓存与占位(修"封面是字母块")

**目标**:网络封面统一走缓存 + 占位 + 圆角裁切 + 失败兜底。

**涉及代码位置**
- `_ArtworkView`(约 `lib/main.dart:4701`):目前用 `Image.network`,无 `loadingBuilder`,失败回退到字母块 `_ArtworkTile`。
- 现有依赖未含 `cached_network_image`(见 `pubspec.yaml`)。

**做法约束**
- 引入 `cached_network_image`(在 `pubspec.yaml` 加固定版本号,不要用 `^` 开放范围)。
- 封装一个 `Artwork` 组件:`CachedNetworkImage` + `placeholder`(玻璃骨架/模糊占位)+ `errorWidget`(回退现有字母块)+ `ClipRRect` 圆角(取 spec §6 卡片圆角刻度)。
- 加载中显示占位骨架,不要白闪。

**完成判据**
- 弱网/断网下封面区显示占位骨架或字母块,**不出现白/灰闪烁**。
- 同一封面二次进入秒显(命中缓存)。
- `pubspec.yaml` 中新依赖为固定版本。

---

## T6 — 圆角 / 间距统一收口

**目标**:消灭散落的 `BorderRadius.circular(18/22/24/26/28)` 与裸 `SizedBox(width/height: 任意数)`。

**做法约束**
- 全 `lib/` 搜 `BorderRadius.circular(` 与 `EdgeInsets`/`SizedBox` 的裸数字,逐一映射到 spec §2/§4 的刻度 token。
- 同类组件圆角必须一致(所有大卡片同一值,所有药丸同一值)。

**完成判据**
- `grep "circular(" lib/` 命中的参数应全部是 `AppRadius.*`,无裸数字。
- 间距值全部来自 `AppSpace.*`。

---

## T7 — 四态:加载 / 空 / 错误 / 局部数据

**目标**:推荐、搜索结果、队列、歌词、封面五处统一四态表现(spec §7)。

**做法约束**
- 加载:玻璃骨架占位(不是转圈占满屏)。
- 空:一句引导文案 + 可选操作,不是空白。
- 错误:文案 + 重试按钮,复用现有 `_xxxError` 字段。
- 局部数据:已加载部分正常显示,加载更多失败只在底部提示。

**完成判据**
- 手动断网进首页:推荐区显示错误态 + 重试,点重试能恢复。
- 搜索无结果:显示空态文案而非空白。

---

## T8 — 全量验收(对照原型逐项打勾)

逐条核对,全绿才算本轮完成:

- [ ] 整屏冷调,粉色面积 < 5% 且仅在允许位置(T2)
- [ ] 所有卡片有玻璃模糊,无硬边溢出(T3)
- [ ] 底部三按钮单层圆、间距均匀、无幽灵圆(T1)
- [ ] 首页推荐网格回归,密度接近原型(T4)
- [ ] 封面缓存 + 占位,无白闪(T5)
- [ ] 圆角/间距全 token 化,`grep` 无裸数字(T6)
- [ ] 五处四态完整(T7)
- [ ] `flutter analyze` 零告警
- [ ] `flutter test` 全过
- [ ] `docs/work-log.md` 记录每个任务的改动与自测

---

## 给执行 AI 的自检提示(每个任务收尾前问自己)

1. 我有没有新写裸字面量?(颜色/圆角/间距)
2. 这个卡片是不是用了统一 `GlassCard`?有没有真的模糊?
3. 我加的粉色,在 spec §0 允许的 4 个位置里吗?
4. 截图和原型 PNG 并排,气质像不像?不像的具体差在哪(色/密度/模糊/圆角)?
5. `flutter analyze` 和 `flutter test` 过了吗?work-log 记了吗?
