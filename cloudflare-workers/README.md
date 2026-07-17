# Cloudflare Workers — Music Car 一机一码

见上级文档：[`../docs/device-auth.md`](../docs/device-auth.md)

## 快速部署

1. 创建 Worker + 绑定 KV 变量名 **`AUTH_DEVICES`**
2. 配置 Secrets：`ADMIN_KEY`、`SECRET_KEY`
3. 部署本目录 `index.js`
4. App 构建传入 `DEVICE_AUTH_BASE_URL`

## 计划枚举

| plan | 天数 |
|---|---|
| month | 30 |
| quarter | 90 |
| year | 365 |
| lifetime | 不过期 |
