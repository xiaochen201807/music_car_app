# UI 美化 Roadmap（性能优先）

> 目标：在功能稳定前提下提升质感，不引入明显性能回退。  
> 原则：**动效只服务状态变化，不为装饰而动。**  
> 状态：Phase 1–6 完成（可发布）  
> 最后更新：2026-07-17

---

## 0. 背景与现状

### 已有基础

- 统一 token：`AppColor` / `AppSpace` / `AppRadius` / `AppType`（BMW 蓝 + 深浅双主题）
- 性能开关：`GlassPerformanceMode`、`TickerMode`、`visualAnimationsEnabled`
- 分层缓存已落地，切源 / 切歌链路相对稳定
- 主 Tab（首页 / 搜索 / 音乐库 / 设置）与播放页结构已统一为「轻页头 + 描边 tile」方向

### 主要视觉短板

1. **信息层级偏平**：列表/卡片间距与字重接近，重点不够突出
2. **玻璃与描边混用**：有的页轻描边 tile，有的仍用厚 `GlassCard`，语言不统一
3. **播放页比例可再收**：唱片 / 歌词 / 进度条比例仍可更「产品化」
4. **空态 / 加载态普通**：功能有，缺统一骨架与过渡
5. **微交互不足**：选中态、按压反馈、列表入场节奏不一致

---

## 1. 性能红线（美化时必须遵守）

| 允许 | 避免 |
|---|---|
| 轻量 `AnimatedContainer` / color fade（≤150ms） | 大面积 `BackdropFilter` 叠层 |
| 前 6–8 项 staggered 入场 | 全列表逐项动画 |
| `RepaintBoundary` 包封面 / 迷你播放器 | 每帧重建渐变 / 阴影 |
| 静态渐变、1 层阴影 | 多层实时 blur + 粒子 |
| 主题色种子（封面取色结果复用） | 切歌时全页重算 palette |

明确不做：

- 全屏粒子 / 实时液体玻璃
- 每行歌曲独立 ImplicitlyAnimated 阴影
- 歌词逐字动画（车机 CPU 不划算）

---

## 2. 分阶段计划

### Phase 1 — 统一语言（1–2 天，低风险）✅ 当前

目标：先一致，再炫。

1. **组件规范**（本文档 + 代码落地）
   - 页头：轻标题 + 副文案
   - 列表行：统一 padding / 圆角 / 分割
   - 主按钮 / 次按钮 / pill chip 三态（default / selected / disabled）
2. **字重与颜色收紧**
   - 标题 `w800–w900`，正文 `w500–w600`，弱化信息用 `onSurfaceVariant`
   - 减少满屏 `w900`
3. **间距网格**
   - 区块间距统一 `xl / xl2`，列表 item 间距统一 `sm`
4. **去掉残留厚玻璃页头**
   - 设置分组可保留浅 `GlassCard`；列表页继续描边 tile

验收：四主 Tab 扫一眼像同一产品；热重载无性能回退。

### Phase 2 — 首页与发现（1–2 天）

1. 推荐歌单瀑布流：封面 scrim、骨架屏、源切换 ≤120ms
2. 快捷入口：「继续播放」突出封面缩略图
3. 热门 / 历史芯片：统一高度与按压色

验收：首屏 1 秒内首帧；源切换仍跟手。

### Phase 3 — 播放页精修（1–2 天）

1. 唱片 / 歌词 / 进度条比例微调
2. 封面 crossfade ≤300ms；背景 blur 仅封面层
3. 歌词当前行对比度；空态居中（已有）
4. 迷你播放器进度细线 + hit area ≥44

验收：中端机 60fps 歌词滚动；切歌无明显掉帧。

### Phase 4 — 列表与库（1 天）

1. 歌曲行封面 52–56、行高固定
2. 下载 / 收藏 icon 语义色
3. 队列当前曲指示
4. 空态统一 `PortraitMessageCard`

### Phase 5 — 设置 / 激活 / 分享（0.5–1 天）

1. 音质 / 音效选中 120ms 边框过渡
2. 激活页设备码等宽 + 主按钮权重
3. 分享二维码间距与安全区

### Phase 6 — 微动效（可选，0.5–1 天）

| 动效 | 规格 |
|---|---|
| 页面切换 | 保持 PageView，不加重 |
| 按钮按压 | BounceTouchable scale 0.96 |
| 列表入场 | 前 6 项 stagger，总 ≤400ms |
| 主题切换 | 全页 fade ≤200ms |

---

## 3. 组件规范（Phase 1 交付）

### 3.1 页头

```
[ 大标题 w900 / headlineMedium ]
[ 副文案 bodySmall / onSurfaceVariant ]
间距: 标题→副文案 xs；页头→下一块 lg~xl
```

### 3.2 区块标题

```
[ 区块标题 titleMedium / w900 ]
[ 可选副标题 bodySmall / onSurfaceVariant ]
[ 可选 trailing chip/pill ]
间距: 标题区底部 sm
```

### 3.3 列表行（歌曲 / 队列）

| Token | 值 |
|---|---|
| 圆角 | `AppRadius.tile` (16) |
| 内边距 | 水平 `md`，垂直 `sm` |
| 行间距 | `sm` |
| 封面 | 52–56，圆角 `control` |
| 标题 | titleSmall / w800 |
| 副标题 | bodySmall / onSurfaceVariant / w500 |

### 3.4 Pill / Chip

| 状态 | 表现 |
|---|---|
| default | surfaceContainer + outlineVariant 边框 |
| selected | primary 填充或 primary 描边 1.5 + primary 文字 |
| disabled | onSurfaceVariant + 降低 opacity |
| 动效 | ≤120–150ms `easeOutCubic` |

### 3.5 卡片

| 场景 | 组件 |
|---|---|
| 设置分组、表单块 | 浅 `GlassCard`（无重阴影） |
| 首页快捷入口、源 chip | 描边 tile（非玻璃） |
| 列表行 | `PortraitSurface` |

### 3.6 字重纪律

| 用途 | 字重 |
|---|---|
| 页主标题 | w900 |
| 区块标题 / 歌名 | w800 |
| 按钮 / 选中 chip | w800 |
| 正文 | w600–w700 |
| 次要说明 | w500–w600 |

避免：同一屏超过 3 处 w900。

---

## 4. 实施顺序

```text
Week 1
  Day 1–2  Phase 1 统一语言 + token / shared 组件收紧   ✅
  Day 3    Phase 2 首页   ✅
  Day 4    Phase 3 播放页精修   ✅
  Day 5    Phase 4–5 列表/设置 + 回归   ✅

可选
  Day 6    Phase 6 微动效 + 性能抽样
```

---

## 5. 每阶段回归清单

- [ ] 推荐源切换仍即时
- [ ] 切歌歌词 / 队列同步
- [ ] 播放 / 暂停 / 进度拖动
- [ ] 设置音质 / 音效选中跟手
- [ ] 激活闸门与分享二维码
- [ ] 中端机：首页滑动 + 播放页歌词滚动流畅

---

## 6. 进度日志

| 日期 | 阶段 | 内容 |
|---|---|---|
| 2026-07-17 | Plan | 文档落地，启动 Phase 1 |
| 2026-07-17 | Phase 1 | shared 组件字重/间距/选中态收紧；页头与 chip 规范对齐 |
| 2026-07-17 | Phase 1 | Song/Queue tile + Surface 统一；SegmentedTab ≤140ms 无阴影；次要 w900→w800 |
| 2026-07-17 | Phase 2 | 推荐卡片底部 scrim；加载骨架替代 demo 封面；继续播放封面缩略图 |
| 2026-07-17 | Phase 3 | 唱片/歌词比例；背景 blur 降本+280ms crossfade；歌词层级；迷你播放器顶栏进度+44 hit |
| 2026-07-17 | Phase 4 | 歌曲行 54 封面+固定双行；语义色 icon；队列当前曲指示条；MessageCard 字重/间距统一 |
| 2026-07-17 | Phase 5 | 音质/音效选中 120ms 描边过渡；激活页等宽设备码+主按钮 52；分享 QR 安全区/按钮 48 |
| 2026-07-17 | Phase 6 | BounceTouchable 0.96；Stagger 前6项 ≤400ms；主题切换 200ms fade |

---

## 7. 第一刀范围（Phase 1 代码）

1. `portrait_song_tile` / `portrait_queue_tile` / `portrait_surface`：统一间距与字重
2. `portrait_chip` / `portrait_segmented_tab`：选中态 ≤150ms
3. `portrait_section_header` / 首页页头：副文案弱化
4. 设置 / 库 / 搜索：去掉多余 w900 与不一致 padding
5. 文档：`docs/ui-polish-roadmap.md`（本文件）
