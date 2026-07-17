# Music Car 一机一码激活

## 策略

- **未激活：完全不能用**（启动硬闸门，不进入音乐主界面）
- **授权粒度**：月卡 / 季卡 / 年卡 / 终身
- **离线宽限**：上次在线校验成功后 7 天内可离线使用；超期必须联网
- **注销**：管理后台删除 KV 后，下次在线校验会 403 并清本地授权

## 组件

| 路径 | 作用 |
|---|---|
| `cloudflare-workers/index.js` | Cloudflare Worker：`/verify`、`/admin/*`、计划授权 |
| `lib/services/device_auth_service.dart` | 客户端校验、本地缓存、离线宽限 |
| `lib/features/activation/device_activation_gate.dart` | 全屏激活页 |
| Android `music_car_app/device_auth` | `Settings.Secure.ANDROID_ID` |
| iOS `music_car_app/device_auth` | 安装级 UUID（UserDefaults） |

## 部署 Worker

1. Cloudflare → Create Worker（建议名 `music-car-auth`）
2. Bindings：
   - KV：`AUTH_DEVICES` → 新建独立命名空间（勿与 bbtotal 共用）
   - Secrets：`ADMIN_KEY`、`SECRET_KEY`（强随机）
3. 粘贴 `cloudflare-workers/index.js` → Deploy
4. 构建 App 时注入：
   ```bash
   flutter build apk --dart-define=DEVICE_AUTH_BASE_URL=https://你的worker.workers.dev
   ```

## 授权 API

```http
POST /admin/authorize
X-Admin-Key: <ADMIN_KEY>
{
  "deviceId": "…",
  "username": "张三",
  "plan": "month" | "quarter" | "year" | "lifetime"
}
```

也可用 `durationDays` 覆盖计划天数。`lifetime` 的 `expires_at` 为 `null`。

管理页：`https://你的worker.workers.dev/admin`  
健康检查：`https://你的worker.workers.dev/health`  
根路径 `/` 会 302 跳到 `/admin`。

当前生产域名：
- 管理后台：`https://music.yosyou.com/admin`
- 健康检查：`https://music.yosyou.com/health`
- Worker 默认域名（备用）：`https://music119.xiaoguan1649.workers.dev`

GitHub Actions 构建会注入  
`--dart-define=DEVICE_AUTH_BASE_URL=https://music.yosyou.com`  
（可用仓库变量/密钥 `DEVICE_AUTH_BASE_URL` 覆盖）。

## App 流程

1. 启动 `ensureActivated()`
2. 无本地激活码 → 显示激活页（设备码可复制；空校验写入 pending）
3. 用户输入激活码 → `/verify`
4. 成功写入本地并进入主界面
5. 设置 → 授权：状态 / 复制设备码 / 重新在线验证

## 默认 Base URL

代码默认：`https://music.yosyou.com`  
可用 `--dart-define=DEVICE_AUTH_BASE_URL=...` 覆盖。
