# Cloudflare Workers — Music Car 一机一码

见上级文档：[`../docs/device-auth.md`](../docs/device-auth.md)

## 快速部署

1. 创建 Worker + 绑定 KV 变量名 **`AUTH_DEVICES`**
2. 配置变量/密钥：`ADMIN_KEY`、`SECRET_KEY`
3. 把本目录 `index.js` 完整粘贴到 Worker 编辑器 → **部署**
4. 验证：
   - `https://<worker>.workers.dev/health` 应返回 JSON `ok: true`
   - `https://<worker>.workers.dev/admin` 打开管理后台
   - `https://<worker>.workers.dev/` 会跳转到 `/admin`
5. App / GitHub Actions 默认使用 `https://music.yosyou.com`，也可用  
   `--dart-define=DEVICE_AUTH_BASE_URL=...` 或仓库变量 `DEVICE_AUTH_BASE_URL` 覆盖

### 常见问题：打开域名只有 nginx 404

- 访问根路径时旧脚本会**故意伪装** nginx 404；请打开 **`/admin`**。
- 自定义域名（如 `music.yosyou.com`）若未在 Worker「域」里绑定，请求会打到源站 nginx，仍是真 404。  
  正确做法：Cloudflare Dashboard → 该 Worker → **域** → 添加自定义域名。

## 计划枚举

| plan | 天数 |
|---|---|
| month | 30 |
| quarter | 90 |
| year | 365 |
| lifetime | 不过期 |
