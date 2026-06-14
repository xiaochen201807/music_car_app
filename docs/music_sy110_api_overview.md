# music.sy110.eu.org API 功能总览

## 🎉 所有核心功能已就绪！

### ✅ 完整的接口列表（12个核心功能）

| 功能 | 接口 | 说明 |
|------|------|------|
| 1. 登录认证 | `POST /api/v1/auth/login` | JWT token 认证 |
| 2. 搜索歌曲 | `GET /api/music/search/songs` | 支持 kuwo/netease |
| 3. 获取播放地址 | `GET /api/music/songs/url/{source}/{id}` | 支持多种音质 |
| 4. 获取歌词 | `GET /api/music/lyrics/discover` | ⭐ 支持逐字时间轴 |
| 5. 获取榜单列表 | `GET /api/music/charts` | kuwo/netease 榜单 |
| 6. 获取分类列表 | `GET /api/music/playlists/categories/{source}` | 4大平台分类 |
| 7. 获取分类歌单 | `GET /api/music/playlists/category/{source}/{id}` | 推荐歌单 |
| 8. 获取歌单歌曲 | `GET /api/music/playlists/songs/{source}/{id}` | 歌单详情 |
| 9. 播放历史 | `GET/POST /api/v1/music/recent_plays` | 历史同步 |
| 10. 收藏管理 | `GET/POST/DELETE /api/v1/music/favorites` | 收藏功能 |

### 🌟 特色功能

#### 1. 逐字歌词（Karaoke 效果）
```json
{
  "words": [
    {"startMs": 0, "endMs": 1005, "text": "涛"},
    {"startMs": 1005, "endMs": 2010, "text": "声"}
  ]
}
```

#### 2. 多平台推荐歌单
- 网易云音乐 (netease)
- 酷我音乐 (kuwo)
- QQ音乐 (qq)
- 酷狗音乐 (kugou)

#### 3. 统一的用户体系
- 跨设备数据同步
- 收藏和历史记录
- 个性化推荐

### 📊 完整功能对比

| 功能 | sy110 API | 现有方案 |
|------|-----------|----------|
| 搜索 | ✅ 2个源 | ✅ 网易云 |
| 播放 | ✅ 多源 | ✅ bugpk |
| 歌词 | ✅ **逐字时间轴** | ✅ bugpk 普通歌词 |
| 推荐 | ✅ **4大平台** | ✅ 酷狗 |
| 榜单 | ✅ 2个源 | ❌ 无 |
| 收藏 | ✅ 云端同步 | ❌ 仅本地 |
| 历史 | ✅ 云端同步 | ❌ 仅本地 |
| 用户系统 | ✅ 完整 | ❌ 无 |

### 🎯 推荐实现方案

**完全迁移到 sy110 API**

优势：
- ✅ 功能更完整（逐字歌词、榜单、多平台推荐）
- ✅ 统一接口管理
- ✅ 用户数据云端同步
- ✅ 更好的稳定性

可以替换的现有 API：
1. 网易云音乐搜索 API
2. 酷狗歌单 API
3. Bugpk 播放和歌词 API

### ⚠️ 已知限制

1. 热门搜索关键词 - 暂无接口
2. 歌手详情 - 暂无接口
3. 专辑详情 - 暂无接口

这些功能不影响核心音乐播放体验。

### 📝 实施优先级

**第一阶段：核心功能**
1. 实现登录和 token 管理
2. 替换搜索接口
3. 替换播放和歌词接口

**第二阶段：推荐功能**
4. 实现榜单展示
5. 实现分类歌单浏览
6. 实现歌单详情

**第三阶段：用户功能**
7. 实现收藏功能
8. 实现播放历史同步

---

详细接口文档：请查看 `music_sy110_api_summary.md`
