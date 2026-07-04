# 车载音乐 · 设计系统契约 (Design Spec)

> 这份文档是 PNG 原型 (`docs/ui/native-ios-music-app-design.png`) 与代码之间缺失的"中间层"。
> 原型是图,本文件是**可执行的数值契约**。所有 UI 实现必须引用本文件的 token，不允许在
> widget 里手写颜色 / 圆角 / 间距字面量。
>
> 设计目标关键词:**深、冷、克制、豪华车机、精密玻璃拟态**。
> 当前实现的主要偏差:① 全屏热粉、② 无玻璃模糊、③ 首页推荐网格丢失、④ 底部控制栏重影、
> ⑤ 圆角/间距随手填、⑥ 封面无缓存占位。本文件逐项给出目标值。

---

## 0. 设计原则 (出现分歧时按此裁决)

1. **Spotify 深色 + BMW 浅色**:深色模式遵循 `awesome-design-md/design-md/spotify`
   的近黑沉浸式音乐界面,主播放、进度、激活态使用 Spotify Green。浅色模式遵循
   `awesome-design-md/design-md/bmw` 的白/浅灰企业车机画布,BMW Blue 承担导航、
   设置和次级 CTA。高饱和粉/紫不再作为产品主风格。
2. **一个 GlassCard 统治所有卡片**:任何卡片/面板/药丸背景都来自同一个 `GlassCard` 组件,
   不允许各处自己拼 `Container + 半透明 color`。玻璃必须含 `BackdropFilter` 模糊。
3. **token 化**:颜色、间距、圆角、字阶、阴影全部来自 `lib/theme/design_tokens.dart`(见 §8)。
   Widget 内出现裸字面量(如 `BorderRadius.circular(22)`、`Color(0xFF...)`)视为不合格。
4. **横屏车机优先**:基准画布 `1920×1080` 逻辑像素的等比缩放;最小适配高度 600。尺寸偏大、
   触控区 ≥ 44。
5. **真实数据状态先行**:每个列表/卡片区都要有 加载 / 空 / 错误 / 局部数据 四态,再谈好看。

---

## 1. 颜色 Token (Color)

### 1.1 背景与表面

| Token | Hex / 值 | 用途 |
| --- | --- | --- |
| `bgBase` | `#121212` | Spotify 近黑主背景 |
| `bgDeep` | `#000000` | 背景最深层 |
| `glowViolet` | `#1F1F1F` | 深色环境层(保留旧 token 名) |
| `glowCyan` | `#252525` | 深色抬升层(保留旧 token 名) |
| `glassTint` | `#181818` | Spotify 深色卡片/面板底色 |

### 1.1.1 浅色 BMW 画布

| Token | Hex / 值 | 用途 |
| --- | --- | --- |
| `paperBase` | `#FFFFFF` | 浅色主画布 |
| `paperWarm` | `#F7F7F7` | 浅色顶部柔和表面 |
| `paperCool` | `#EBEBEB` | 浅色底部抬升/分区 |
| `paperGlassTint` | `#FAFAFA` | 浅色玻璃卡片底色 |
| `paperStrokeHairline` | `#E6E6E6` | 浅色卡片描边 |
| `paperInk` | `#262626` | 浅色主文字 |
| `paperMuted` | `#6B6B6B` | 浅色次级文字 |
| `paperFaint` | `#9A9A9A` | 浅色弱化文字 |

### 1.2 描边 / 分隔

| Token | 值 | 用途 |
| --- | --- | --- |
| `strokeHairline` | `#FFFFFF` @ 0.12 (`0x1FFFFFFF`) | 卡片 1px 描边、分隔线 |
| `strokeStrong` | `#FFFFFF` @ 0.18 (`0x2EFFFFFF`) | 高亮态描边 |
| `sheenTop` | `#FFFFFF` @ 0.10 (`0x1AFFFFFF`) | 玻璃顶部高光渐变起点(→透明) |

### 1.3 点缀色 (受 §0 规则 1 严格约束使用范围)

| Token | 值 | **仅允许用于** |
| --- | --- | --- |
| `spotifyGreen` | `#1ED760` | 深色模式主播放、进度、激活态、主 CTA |
| `spotifyGreenPressed` | `#1DB954` | Spotify Green 按下/渐变终点 |
| `bmwBlue` | `#1C69D4` | 浅色模式导航、设置、次级 CTA |
| `bmwBlueActive` | `#0653B6` | BMW Blue 按下态 |
| `accentSteelStart` / `accentPlatinumEnd` | 兼容别名 | 旧字段保留,实际指向 Spotify Green |
| `accentGradient` | `LinearGradient(topLeft→bottomRight, [spotifyGreen, spotifyGreenPressed])` | 主播放按钮、进度条、深色激活态 |
| `carlife` | `#539DF5` | 仅 CarLife 入口/状态 |

> ⚠️ 删除当前的 `primary = #FF5C93` / `accent = #FFB86B` 全局暖色。深色模式不要把绿色当装饰背景,
> 只用于播放、进度、激活态和主 CTA。浅色模式不要使用米黄/纸张纹理,保持 BMW 式白灰画布。

### 1.4 中性填充(玻璃内控件)

| Token | 值 | 用途 |
| --- | --- | --- |
| `fillNeutral` | `#FFFFFF` @ 0.08 (`0x14FFFFFF`) | 次级按钮、药丸、输入框背景 |
| `fillNeutralHover` | `#FFFFFF` @ 0.14 | 悬停/按下 |

### 1.5 文字

| Token | 值 | 用途 |
| --- | --- | --- |
| `textPrimary` | `#FFFFFF` | 深色标题、主文案 |
| `textSecondary` | `#B3B3B3` | 深色副标题、艺人名 |
| `textTertiary` | `#7C7C7C` | 深色时间戳、占位、禁用 |

---

## 2. 间距 Token (Spacing)

固定刻度,**只允许**取这些值:

```
space.xs = 4    space.sm = 8     space.md = 12    space.lg = 16
space.xl = 20   space.2xl = 24   space.3xl = 32   space.4xl = 40
```

- 屏幕外边距(SafeArea 内 padding):`space.2xl` (24)
- 卡片内边距:`space.xl` (20)
- 卡片之间间隙:`space.lg` (16)
- 图标与文字间隙:`space.sm` (8)

---

## 3. 圆角 Token (Radius)

**统一,杜绝当前 18/22/24/26/28 混用**:

| Token | 值 | 用途 |
| --- | --- | --- |
| `radius.pill` | 999 | 药丸、进度条、圆按钮 |
| `radius.panel` | 28 | 大面板(正在播放卡、侧栏容器、迷你播放器) |
| `radius.card` | 22 | 推荐卡、队列容器 |
| `radius.tile` | 16 | 封面缩略图、小卡 |
| `radius.control` | 14 | 输入框、药丸按钮内部 |

> 规则:同一层级的卡片必须用同一个 radius token。封面图圆角 = 容器圆角 −(padding),
> 一般封面用 `radius.tile`。

---

## 4. 字阶 Token (Type)

字体 `fontFamily: sans`(沿用)。横屏车机偏大。

| Token | size / weight | 用途 |
| --- | --- | --- |
| `type.display` | 40 / w800 | 全屏正在播放 歌名 |
| `type.h1` | 30 / w800 | 页面主标题(车载音乐) |
| `type.h2` | 20 / w700 | 区块标题(为你推荐 / 在线曲库) |
| `type.cardTitle` | 17 / w700 | 卡片/列表项 主文案 |
| `type.body` | 15 / w500 | 正文 |
| `type.caption` | 13 / w600 | 艺人名、标签 |
| `type.micro` | 11 / w600 | 时间戳、角标 |

行高统一 1.2;主标题字间距 0;数字(时间)用等宽对齐感(`FontFeature.tabularFigures`)。

> 当前代码大量 `FontWeight.w900` 偏重,统一降到上表(最重 w800)。

---

## 5. 玻璃配方 (Glass Recipe) —— 全局唯一组件 `GlassCard`

当前最大质感缺失:**全代码无 `BackdropFilter`**。必须补。

### 5.1 标准卡片(推荐卡、队列、迷你播放器、药丸容器)

```
ClipRRect(borderRadius: radius.card)
└ BackdropFilter(filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18))
  └ Container(
      decoration: BoxDecoration(
        color: glassTint @ 0.35,            // 0x590E1426
        borderRadius: radius.card,
        border: Border.all(color: strokeHairline, width: 1),
        boxShadow: [shadow.card],
      ),
      // 可选顶部高光:子层 gradient sheenTop→transparent 覆盖顶部 ~50%
    )
```

### 5.2 英雄卡片(正在播放大卡、全屏播放)

- `radius.panel` (28),`blur sigma 28`,其余同上。

### 5.3 阴影 Token

| Token | 值 |
| --- | --- |
| `shadow.card` | `BoxShadow(color: #000 @ 0.35, blurRadius: 40, offset: (0, 20))` |
| `shadow.controlPrimary` | `BoxShadow(color: accentSteelStart @ 0.22, blurRadius: 18, offset: (0, 8))` —— 仅主播放键 |

> ⚠️ **关于底部重影 bug**:阴影/发光不得叠加在带半透明背景的圆按钮"下面又一层圆"。
> 详见 playbook 的 Bug #0,根因在 `_MiniTransportButton`。

---

## 6. 环境背景 (Atmosphere)

保留径向渐变思路,**改为冷色**:

```
RadialGradient(
  center: Alignment(-0.62, -0.74),   // 左上
  radius: 1.35,
  colors: [ glowViolet @ 0.30, bgBase, bgDeep ],
  stops: [0, 0.52, 1],
)
```

- 可叠加右下角第二层柔光 `glowCyan @ 0.22` 增加纵深。
- 现有 `_NoiseRibbonPainter` 丝带保留,但颜色改用 `glowViolet`,alpha ≤ 0.14,避免抢戏。
- 背景色调可随当前歌曲主色微调,但**饱和度封顶**(混入 50% bgBase),禁止再现"全屏粉"。

---

## 7. 组件与画面规格 (Layout Spec)

基准 `1920×1080`。整体结构:`SafeArea > Padding(24) > Column[ Expanded(Row[侧栏 | 主区 | 正在播放]) , MiniPlayer ]`。

### 7.1 侧栏导航 `_SideNavigationRail`

- 宽 96(compact 高度<620 时 84),`radius.panel`,GlassCard 背景。
- 顶部 Logo 方块:56×56,`radius.tile`。**Logo 用中性玻璃或品牌固定色,不用点缀粉。**
- 导航项(首页/搜索/队列/正在播放/设置):图标 26 + 文字 `type.micro`。
- **激活态**:仅激活项用 `accentGradient` 描边或左侧 3px 指示条 + 图标变 `textPrimary`;
  未激活 `textTertiary`。一次只有一个激活项。
- 项间距 `space.xl`。

### 7.2 首页 / 推荐(当前实现丢失,必须补回)

参考原型 panel 1。主区从上到下:

1. **顶部行**:左 `车载音乐`(`type.h1`)+ 副标题(`type.caption`,`textSecondary`);
   右侧 `搜索音乐` 入口药丸(`radius.pill`,`fillNeutral`,放大镜图标 + 占位文字)。
2. **区块"为你推荐"**(`type.h2`)。
3. **英雄卡横向行**:3 张大卡,等宽,高 150,`radius.card`。
   - 内容:封面图铺满 + 底部由透明→`#000 @ 0.7` 的渐变 scrim + 左下标题(`type.cardTitle`)。
   - 卡间距 `space.lg`。响应式:用可用宽度三等分减间隙。
4. **区块"近期播放 / 推荐歌单"**:一行 5 个方形小卡,边长约 96,`radius.tile`,
   封面 + 下方标题(`type.caption`,1 行省略)。卡间距 `space.lg`。

> 严禁出现当前那种"一个巨大搜索框占半屏"的失衡。搜索框是顶部一个药丸,不是主体。

### 7.3 正在播放(右栏窄版 `_NowPlayingPanel`)

参考原型 panel 1 右侧。`flex: 5`(主区 `flex: 7`)。英雄 GlassCard,`radius.panel`,内含:

- 顶部小标题 `正在播放`(`type.caption`,`textSecondary`)。
- 封面图 正方形,占卡片宽度,`radius.card`,`shadow.card`。
- 歌名 `type.cardTitle`→可放大、艺人 `type.caption`。
- 进度条:`radius.pill`,已播放段 `accentGradient`,底槽 `#FFF @ 0.12`,高 5;两端时间 `type.micro`。
- 控制行:上一首/播放/下一首,见 §7.6 控件规格。

### 7.4 正在播放(全屏 `_NowPlayingFullScreenPanel`)

参考原型 panel 2。居中大封面 + `type.display` 歌名 + 歌词预览(当前行高亮用 `accentPlatinumEnd`,
其余 `textSecondary`)+ 大进度条 + 一排 5 个控件(随机/上一首/播放/下一首/循环)。

### 7.5 播放队列 `_QueuePanel`

参考原型 panel 3。GlassCard 容器,列表项:
- 左序号或当前播放指示、封面缩略 40×40 `radius.tile`、歌名+艺人两行、右侧时长 `type.micro`。
- **当前播放项**:整行 `fillNeutral` 高亮 + 左侧 3px `accentGradient` 指示条 + 跳动音波图标。
- 行高 64,行间分隔用 `strokeHairline`。

### 7.6 控件规格 (Transport Controls) —— 统一

| 控件 | 尺寸 | 背景 | 图标 |
| --- | --- | --- | --- |
| 主播放/暂停 | 直径 76(全屏)/ 64(面板)/ 58(迷你) | `accentGradient` + `shadow.controlPrimary` | 42/34/30,白 |
| 次级(上一/下一/随机/循环) | 直径 56 / 50(迷你) | `fillNeutral` + `strokeHairline` 1px | 30,`textPrimary` |
| 模式药丸 / 歌词药丸 | 高 42 | `fillNeutral`(激活时才微染 accent @ 0.18) | 20 + `type.caption` |

> **关键统一**:所有圆按钮使用**同一个** `_CircleControlButton` 组件(`Container + shape.circle +
> InkWell`),**不要**用 `IconButton.styleFrom(fixedSize:...)`(这是重影 bug 来源,见 playbook Bug #0)。
> 次级按钮**无 boxShadow**;只有主键有 `shadow.controlPrimary`,且 blur 不超过按钮直径,避免溢出成"幽灵圆"。

### 7.7 迷你播放器 `_MiniPlayerBar`

参考原型底部条。高 76,GlassCard `radius.panel`,横向:
`封面50(radius.tile) | 歌名+艺人(宽~210) | 弹性进度条+两端时间 | 上一/播放/下一 | 模式药丸 | 歌词药丸`。
- 进度条已播放段用 `accentGradient`(这是允许的点缀场景)。
- 控件全部走 §7.6 的 `_CircleControlButton`。

---

## 8. Token 落地:`lib/theme/design_tokens.dart`(GPT 需新建)

GPT 应据本文件 §1–§5 生成此文件,作为唯一可信源。结构建议:

```dart
import 'dart:ui';
import 'package:flutter/material.dart';

class AppColor {
  static const bgBase = Color(0xFF121212);
  static const bgDeep = Color(0xFF000000);
  static const glowViolet = Color(0xFF1F1F1F);
  static const glowCyan = Color(0xFF252525);
  static const glassTint = Color(0xFF181818);
  static const paperBase = Color(0xFFFFFFFF);
  static const paperWarm = Color(0xFFF7F7F7);
  static const paperCool = Color(0xFFEBEBEB);
  static const paperGlassTint = Color(0xFFFAFAFA);
  static const paperStrokeHairline = Color(0xFFE6E6E6);
  static const paperInk = Color(0xFF262626);
  static const paperMuted = Color(0xFF6B6B6B);
  static const strokeHairline = Color(0x1FFFFFFF);
  static const strokeStrong = Color(0x2EFFFFFF);
  static const sheenTop = Color(0x1AFFFFFF);
  static const spotifyGreen = Color(0xFF1ED760);
  static const spotifyGreenPressed = Color(0xFF1DB954);
  static const bmwBlue = Color(0xFF1C69D4);
  static const bmwBlueActive = Color(0xFF0653B6);
  static const accentSteelStart = spotifyGreen;
  static const accentPlatinumEnd = spotifyGreenPressed;
  static const accentVioletStart = accentSteelStart;
  static const accentRoseEnd = accentPlatinumEnd;
  static const carlife = Color(0xFF539DF5);
  static const fillNeutral = Color(0x14FFFFFF);
  static const fillNeutralHover = Color(0x24FFFFFF);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFB3B3B3);
  static const textTertiary = Color(0xFF7C7C7C);

  static const accentGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [accentSteelStart, accentPlatinumEnd],
  );
}

class AppSpace {
  static const xs = 4.0, sm = 8.0, md = 12.0, lg = 16.0;
  static const xl = 20.0, xl2 = 24.0, xl3 = 32.0, xl4 = 40.0;
}

class AppRadius {
  static const pill = 999.0, panel = 28.0, card = 22.0, tile = 16.0, control = 14.0;
}

class AppType {
  static const display = TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: AppColor.textPrimary, height: 1.2);
  static const h1 = TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppColor.textPrimary, height: 1.2);
  static const h2 = TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColor.textPrimary, height: 1.2);
  static const cardTitle = TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColor.textPrimary);
  static const body = TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColor.textPrimary);
  static const caption = TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColor.textSecondary);
  static const micro = TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColor.textTertiary);
}

class AppShadow {
  static const card = BoxShadow(color: Color(0x59000000), blurRadius: 40, offset: Offset(0, 20));
  static BoxShadow get controlPrimary => BoxShadow(
    color: AppColor.accentSteelStart.withValues(alpha: 0.22), blurRadius: 18, offset: const Offset(0, 8));
}
```

> 数值是设计基线。GPT 可对照原型 PNG 用肉眼**仅微调 alpha**(±0.05),色相/结构不得改。

---

## 9. 图片规则 (Artwork)

- 网络封面统一走 `cached_network_image`(需加依赖),**禁止**裸 `Image.network`。
- 每张封面必须有:`placeholder`(玻璃底 + 居中音符图标)、`errorWidget`(同 placeholder)、
  `fit: BoxFit.cover`、外层 `ClipRRect(radius.tile)`。
- 占位/错误态复用 `_ArtworkTile` 的渐变兜底即可,但圆角、尺寸由调用方 token 决定。
- 加载淡入 200ms。

---

## 10. 验收基线 (Definition of Done — 视觉)

实现完成需逐条满足(playbook 里有勾选清单):
- [ ] 全代码 `grep` 不到裸 `Color(0xFF`(除 design_tokens.dart)。
- [ ] 全代码 `grep` 不到 `primary = 0xFFFF5C93` 等旧暖色。
- [ ] 至少一处 `BackdropFilter` 生效,卡片有真实模糊。
- [ ] 首页推荐网格(3 英雄卡 + 5 小卡)按 §7.2 呈现。
- [ ] 高饱和点缀仅出现在 §0 规则 1 列出的 4 处。
- [ ] 底部控制栏无重影(Bug #0 关闭)。
- [ ] 圆角只取 §3 的 5 个 token。
- [ ] 封面全部经 `cached_network_image` + 占位。
