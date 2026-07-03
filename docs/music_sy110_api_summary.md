# music.sy110.eu.org API 接口测试总结

测试时间: 2026-06-14

## 1. 认证方式

### 登录接口
- **URL**: `POST https://music.sy110.eu.org/api/v1/auth/login`
- **请求体**:
```json
{
  "username": "<SY110_USERNAME>",
  "password": "<SY110_PASSWORD>"
}
```
- **返回**:
```json
{
  "code": 0,
  "message": "登录成功",
  "data": {
    "access_token": "...",
    "expires_in": 7200,
    "refresh_token": "...",
    "roles": ["user"],
    "token": "...",
    "user": { ... }
  }
}
```

### 鉴权方式
所有接口需要在请求头中添加 Cookie:
```
Cookie: access_token={token}; refresh_token={refresh_token}; session_id=1004
```

## 2. 已确认可用的接口

### 2.1 搜索歌曲 ⭐ NEW
- **URL**: `GET https://music.sy110.eu.org/api/music/search/songs`
- **需要鉴权**: ✅
- **参数**:
  - `q`: 搜索关键词（必需）
  - `source`: 音乐源（kuwo/netease，必需）
  - `page`: 页码（默认1）
  - `page_size`: 每页数量（默认20）
- **返回示例**:
```json
{
  "code": 0,
  "message": "success",
  "data": {
    "list": [
      {
        "source": "kuwo",
        "id": "228908",
        "name": "晴天",
        "artists": [{"source": "kuwo", "id": "", "name": "周杰伦"}],
        "album": {
          "source": "kuwo",
          "id": "",
          "name": "叶惠美",
          "cover": "https://music.sy110.eu.org/__media?u=..."
        },
        "durationMs": 269000,
        "cover": "https://music.sy110.eu.org/__media?u=...",
        "qualityTags": [
          {"code": "320k", "name": "320K", "bitrateKbps": 320},
          {"code": "flac", "name": "FLAC", "bitrateKbps": 1411, "lossless": true}
        ],
        "playable": true
      }
    ]
  }
}
```

### 2.2 获取播放地址 ⭐ NEW
- **URL**: `GET https://music.sy110.eu.org/api/music/songs/url/{source}/{id}`
- **需要鉴权**: ✅
- **路径参数**:
  - `source`: 音乐源（kuwo/netease）
  - `id`: 歌曲ID
- **查询参数**:
  - `name`: 歌曲名称
  - `artist`: 歌手
  - `duration_ms`: 时长（毫秒）
  - `quality`: 音质（320k/flac等，可选）
- **返回示例**:
```json
{
  "code": 0,
  "message": "success",
  "data": {
    "source": "kuwo",
    "provider": "kuwo",
    "songId": "228908",
    "url": "https://music.sy110.eu.org/__media?u=...",
    "quality": "320kmp3",
    "bitrateKbps": 320,
    "format": "mp3",
    "playable": true
  }
}
```

### 2.3 获取最近播放记录
- **URL**: `GET https://music.sy110.eu.org/api/v1/music/recent_plays`
- **需要鉴权**: ✅
- **返回示例**:
```json
{
  "code": 0,
  "message": "success",
  "data": {
    "plays": [
      {
        "id": "3390296151",
        "source": "netease",
        "name": "浮 游 (Ephemera)",
        "artist": "凌晨一点的莱茵猫",
        "album": "浮 游 (Ephemera)",
        "cover": "https://music.sy110.eu.org/__media?u=...",
        "duration": 104,
        "playable": true
      }
    ]
  }
}
```

### 2.4 添加播放记录
- **URL**: `POST https://music.sy110.eu.org/api/v1/music/recent_plays`
- **需要鉴权**: ✅
- **请求体**:
```json
{
  "id": "歌曲ID",
  "source": "音乐源（netease/kuwo等）",
  "name": "歌曲名称",
  "artist": "歌手",
  "duration": 时长（秒）,
  "album": "专辑",
  "cover": "封面URL"
}
```

### 2.5 获取收藏列表
- **URL**: `GET https://music.sy110.eu.org/api/v1/music/favorites`
- **需要鉴权**: ✅
- **返回示例**:
```json
{
  "code": 0,
  "message": "success",
  "data": {
    "col_name": "我喜欢的音乐",
    "songs": []
  }
}
```

### 2.6 添加收藏 ⭐ NEW
- **URL**: `POST https://music.sy110.eu.org/api/v1/music/favorites`
- **需要鉴权**: ✅
- **请求体**:
```json
{
  "id": "228908",
  "source": "kuwo",
  "name": "晴天",
  "artist": "周杰伦"
}
```
- **返回示例**:
```json
{
  "code": 0,
  "message": "success",
  "data": {
    "status": "ok"
  }
}
```

### 2.7 删除收藏 ⭐ NEW
- **URL**: `DELETE https://music.sy110.eu.org/api/v1/music/favorites/{id}?source={source}`
- **需要鉴权**: ✅
- **路径参数**:
  - `id`: 歌曲ID
- **查询参数**:
  - `source`: 音乐源（kuwo/netease）

### 2.8 获取歌词（带逐字时间轴）⭐ NEW
- **URL**: `GET https://music.sy110.eu.org/api/music/lyrics/discover`
- **需要鉴权**: ✅
- **查询参数**:
  - `id`: 歌曲ID（必需）
  - `source`: 音乐源（kuwo/netease，必需）
  - `name`: 歌曲名称（必需）
  - `artist`: 歌手（必需）
  - `duration_ms`: 时长（毫秒，必需）
  - `need_word`: 是否需要逐字时间轴（true/false，可选）
  - `t`: 时间戳（毫秒，可选，用于缓存刷新）
- **返回示例**:
```json
{
  "code": 0,
  "message": "success",
  "data": {
    "input": {
      "source": "netease",
      "id": "5266711",
      "name": "涛声依旧",
      "artist": "毛宁",
      "durationMs": 275000,
      "needWord": true
    },
    "selected": {
      "source": "kuwo",
      "provider": "kuwo",
      "songId": "647171",
      "name": "涛声依旧",
      "artist": "毛宁",
      "format": "lrc",
      "raw": "[00:00.000]<0,1005>涛<1005,1005>声...",
      "lines": [
        {
          "startMs": 0,
          "endMs": 9045,
          "text": "涛声依旧 - 毛宁",
          "words": [
            {
              "startMs": 0,
              "endMs": 1005,
              "text": "涛"
            },
            {
              "startMs": 1005,
              "endMs": 2010,
              "text": "声"
            }
          ]
        }
      ]
    }
  }
}
```
**特性**:
- ✅ 支持逐字时间轴（karaoke 效果）
- ✅ 自动匹配最佳歌词源
- ✅ 返回原始 LRC 格式和解析后的结构化数据

### 2.9 获取榜单列表 ⭐ NEW
- **URL**: `GET https://music.sy110.eu.org/api/music/charts`
- **需要鉴权**: ✅
- **查询参数**:
  - `source`: 音乐源（kuwo/netease，必需）
- **返回示例**:
```json
{
  "code": 0,
  "message": "success",
  "data": [
    {
      "source": "kuwo",
      "id": "16",
      "name": "酷我热歌榜",
      "description": "今日更新",
      "cover": "https://music.sy110.eu.org/__media?u=...",
      "group": "官方",
      "official": true
    },
    {
      "source": "netease",
      "id": "19723756",
      "name": "飙升榜",
      "description": "刚刚更新",
      "cover": "https://music.sy110.eu.org/__media?u=...",
      "group": "官方榜",
      "official": true,
      "tracks": [
        {
          "name": "Баллада",
          "artist": "Xcho/МОТ"
        }
      ]
    }
  ]
}
```
**特性**:
- ✅ 支持酷我和网易云音乐榜单
- ✅ 网易云音乐榜单会返回前几首歌曲预览
- ✅ 包含榜单封面、描述和更新时间

### 2.10 获取歌单分类 ⭐ NEW
- **URL**: `GET https://music.sy110.eu.org/api/music/playlists/categories/{source}`
- **需要鉴权**: ✅
- **路径参数**:
  - `source`: 音乐源（netease/kuwo/qq/kugou）
- **返回示例**:
```json
{
  "code": 0,
  "message": "success",
  "data": [
    {
      "id": "流行",
      "name": "流行",
      "parentId": "风格"
    },
    {
      "id": "2189:10000",
      "name": "抖音",
      "parentId": "主题"
    }
  ]
}
```

### 2.11 获取分类下的歌单列表 ⭐ NEW
- **URL**: `GET https://music.sy110.eu.org/api/music/playlists/category/{source}/{categoryId}`
- **需要鉴权**: ✅
- **路径参数**:
  - `source`: 音乐源（netease/kuwo/qq/kugou）
  - `categoryId`: 分类ID（"全部"表示所有分类，或具体分类ID如"流行"、"34"）
- **查询参数**:
  - `page`: 页码（默认1）
  - `page_size`: 每页数量（默认20）
- **返回示例**:
```json
{
  "code": 0,
  "message": "success",
  "data": {
    "list": [
      {
        "source": "kugou",
        "id": "636158",
        "name": "抖音歌曲最火的歌【持续更新】",
        "description": "超热门，超全面的抖音热歌盘点...",
        "cover": "https://imge.kugou.com/...",
        "creator": "泪已成海",
        "trackCount": 505,
        "playCount": "4294967295",
        "link": {
          "source": "kugou",
          "id": "636158",
          "url": "https://www.kugou.com/yy/special/single/636158.html"
        }
      }
    ]
  }
}
```

### 2.12 获取歌单内的歌曲 ⭐ NEW
- **URL**: `GET https://music.sy110.eu.org/api/music/playlists/songs/{source}/{playlistId}`
- **需要鉴权**: ✅
- **路径参数**:
  - `source`: 音乐源（netease/kuwo/qq/kugou）
  - `playlistId`: 歌单ID
- **查询参数**:
  - `page`: 页码（默认1）
  - `page_size`: 每页数量（默认50）
- **返回示例**:
```json
{
  "code": 0,
  "message": "success",
  "data": {
    "list": [
      {
        "source": "kugou",
        "id": "323D5A30B6872C2E538C25F2E4002D40",
        "name": "MoonlitNight",
        "artists": [{"source": "kugou", "id": "", "name": "East Root"}],
        "album": {
          "source": "kugou",
          "id": "14514155",
          "name": "",
          "cover": "https://imge.kugou.com/..."
        },
        "durationMs": 211000,
        "cover": "https://imge.kugou.com/...",
        "qualityTags": [
          {"code": "128k", "name": "128K", "bitrateKbps": 128}
        ],
        "playable": false
      }
    ]
  }
}
```

## 3. 不可用或未找到的接口

以下接口返回空或 404：
- `/api/v1/user/profile` - 用户信息（404）
- `/api/music/search/hot` - 热门搜索关键词（返回空）
- `/api/music/artists/{source}/{id}` - 获取歌手信息（404）
- `/api/music/albums/{source}/{id}` - 获取专辑信息（404）

## 4. 集成建议

### 核心功能已全部可用！✅

music.sy110.eu.org 现在提供了**完整的音乐服务**，所有功能都已就绪：
1. ✅ **搜索** - 支持酷狗和网易云音乐搜索
2. ✅ **播放** - 获取播放地址，支持多种音质
3. ✅ **歌词** - 支持逐字时间轴（Karaoke 效果）
4. ✅ **榜单** - 获取酷狗和网易云音乐榜单列表
5. ✅ **推荐歌单** - 四大音乐平台（网易/酷我/QQ/酷狗）分类歌单
6. ✅ **歌单详情** - 获取歌单内的完整歌曲列表
7. ✅ **收藏** - 添加/删除/获取收藏列表
8. ✅ **历史** - 播放记录同步
9. ✅ **用户** - 登录和鉴权体系

### 推荐歌单功能完整流程

1. **获取分类列表** → `/api/music/playlists/categories/{source}`
   - 支持4个音乐源：netease, kuwo, qq, kugou
   
2. **获取分类下的歌单** → `/api/music/playlists/category/{source}/{categoryId}`
   - categoryId 可以是"全部"或具体分类ID
   - 支持分页：page, page_size
   
3. **获取歌单内的歌曲** → `/api/music/playlists/songs/{source}/{playlistId}`
   - 支持分页，最多50首/页

### ⚠️ 功能限制

1. **热门搜索关键词** - 暂无热门搜索接口
2. **歌手/专辑详情** - 暂无歌手和专辑详情接口

### 推荐的集成方案

#### 完全迁移到 sy110 API（强烈推荐）⭐⭐⭐

**所有核心功能都已具备，可以完全替换现有API！**

**优势**：
- 统一的接口管理
- 用户数据与音乐服务完全集成
- 更好的稳定性和可控性
- 支持多音乐源切换（kuwo/netease/qq/kugou）
- **歌词支持逐字时间轴，可实现 Karaoke 效果**
- **推荐歌单支持4大平台，选择更丰富**

**实现步骤**：
1. 添加登录流程：使用 `/api/v1/auth/login`
2. 替换搜索接口：使用 `/api/music/search/songs`
3. 替换播放接口：使用 `/api/music/songs/url/{source}/{id}`
4. 替换歌词接口：使用 `/api/music/lyrics/discover`（支持逐字时间轴）
5. 实现推荐首页：
   - 展示榜单：`/api/music/charts`
   - 展示推荐歌单：`/api/music/playlists/category/{source}/全部`
6. 集成收藏功能：使用 `/api/v1/music/favorites` 系列接口
7. 集成播放历史：使用 `/api/v1/music/recent_plays` 系列接口

**可以完全替换的现有 API**：
- ❌ 网易云音乐搜索 `https://music.163.com/api/search/get/web` 
- ❌ 酷狗歌单 `http://m.kugou.com/plist/`
- ❌ Bugpk 播放和歌词 `https://api.bugpk.com/api/music`

**全部替换为 sy110 统一接口！**

### 需要注意的问题
1. ✅ 所有接口都需要鉴权（Cookie 中的 access_token）
2. ✅ Token 有效期为 7200 秒（2小时），需要使用 refresh_token 刷新
3. ✅ 歌词接口支持逐字时间轴，可实现卡拉 OK 效果
4. ✅ 播放地址是代理地址（`/__media?u=...`），可以直接使用
5. ⚠️ 播放列表、歌手、专辑等功能暂时不可用

## 5. 下一步实现计划

### 第一阶段：登录和鉴权
1. 创建登录界面
2. 实现 token 存储和管理
3. 实现 token 自动刷新机制
4. 添加全局请求拦截器（自动添加 Cookie）

### 第二阶段：替换核心接口
1. 将搜索接口替换为 sy110 API
2. 将播放地址获取替换为 sy110 API
3. 保留歌词获取使用 bugpk（sy110 暂无歌词接口）

### 第三阶段：集成用户功能
1. 实现收藏功能（添加/删除/列表）
2. 实现播放历史自动同步
3. 从服务器加载播放历史到本地

### 代码文件需要修改的清单
1. **lib/free_music_api.dart** - 核心 API 封装
2. **lib/services/** - 可能需要添加 auth_service.dart
3. **lib/models/** - 添加 User 模型和 Token 模型
4. **lib/features/** - 添加登录功能相关页面

需要我帮你开始实现吗？建议从登录和鉴权开始。
