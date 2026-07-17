export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const method = request.method;

    // CORS 跨域请求头
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS, DELETE',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Admin-Key',
    };

    if (method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    try {
      // 路由 1：获取可视化管理后台 HTML 页面
      if (url.pathname === '/admin' && method === 'GET') {
        return new Response(getAdminHtmlPage(), {
          headers: { 'Content-Type': 'text/html; charset=utf-8' }
        });
      }

      // 路由 2：设备在线授权校验
      if (url.pathname === '/verify' && method === 'POST') {
        const { deviceId, authCode } = await request.json();
        if (!deviceId) {
          return new Response(JSON.stringify({ success: false, msg: '参数缺失: deviceId 为必填项' }), {
            status: 400,
            headers: { 'Content-Type': 'application/json', ...corsHeaders }
          });
        }

        // 1. 优先从 Cloudflare KV (AUTH_DEVICES) 中查询授权状态
        if (env.AUTH_DEVICES) {
          const authDataStr = await env.AUTH_DEVICES.get(deviceId);
          if (authDataStr) {
            const authData = JSON.parse(authDataStr);
            // 校验时间是否过期
            const isExpired = authData.expires_at != null && Date.now() > authData.expires_at;
            if (authCode && authData.authorized && authData.auth_code === authCode && !isExpired) {
              // 认证成功，如果待授权列表里有该记录，顺手将其清除
              await env.AUTH_DEVICES.delete('pending:' + deviceId);

              return new Response(JSON.stringify({
                success: true,
                msg: '设备授权成功 (在线认证)',
                plan: authData.plan || 'custom',
                expiresAt: authData.expires_at || null,
                username: authData.username || ''
              }), {
                headers: { 'Content-Type': 'application/json', ...corsHeaders }
              });
            }
          }
          
          // 注意：如果绑定了 KV，且在 KV 里没查到或已过期，则直接拦截！
          // 不再允许通过算法兜底，以保证“注销/删除/拉黑设备”功能绝对有效。
          if (env.AUTH_DEVICES) {
            // 记录失败的设备 ID 到待授权列表中
            await env.AUTH_DEVICES.put('pending:' + deviceId, Date.now().toString(), { expirationTtl: 604800 });
            
            return new Response(JSON.stringify({ success: false, msg: '设备未认证或已被注销' }), {
              status: 403,
              headers: { 'Content-Type': 'application/json', ...corsHeaders }
            });
          }
        }

        // 2. 离线/哈希算法验证 (仅在未绑定 KV 时，作为简易无数据库方案放行)
        const secretKey = env.SECRET_KEY || 'music-car-default-secret-key';
        
        let isValid = false;
        const parts = authCode.split('-');
        if (parts.length === 3 && parts[0] === 'AUTH') {
          // 新格式 AUTH-SALT-HASH
          const salt = parts[1];
          const expectedCode = await generateHMACCode(deviceId, secretKey, salt);
          isValid = (authCode === expectedCode);
        } else if (parts.length === 2 && parts[0] === 'AUTH') {
          // 旧格式 AUTH-HASH
          const expectedCode = await generateHMACCodeOld(deviceId, secretKey);
          isValid = (authCode === expectedCode);
        }

        if (isValid) {
          return new Response(JSON.stringify({ success: true, msg: '设备授权成功 (算法匹配)' }), {
            headers: { 'Content-Type': 'application/json', ...corsHeaders }
          });
        }

        return new Response(JSON.stringify({ success: false, msg: '设备未认证或激活码无效' }), {
          status: 403,
          headers: { 'Content-Type': 'application/json', ...corsHeaders }
        });
      }

      // 路由 3：管理员录入授权 (写入 KV)
      if (url.pathname === '/admin/authorize' && method === 'POST') {
        const adminKey = request.headers.get('X-Admin-Key') || url.searchParams.get('adminKey');
        if (!adminKey || adminKey !== env.ADMIN_KEY) {
          return new Response(JSON.stringify({ success: false, msg: '管理员身份认证失败' }), {
            status: 401,
            headers: { 'Content-Type': 'application/json', ...corsHeaders }
          });
        }

        const body = await request.json();
        const deviceId = body.deviceId;
        const username = body.username;
        const plan = normalizePlan(body.plan || body.durationPlan || 'year');
        if (!deviceId || !username) {
          return new Response(JSON.stringify({ success: false, msg: '参数缺失 (deviceId, username 为必填项)' }), {
            status: 400,
            headers: { 'Content-Type': 'application/json', ...corsHeaders }
          });
        }

        const secretKey = env.SECRET_KEY || 'music-car-default-secret-key';
        const authCode = await generateHMACCode(deviceId, secretKey);

        // 授权粒度：month / quarter / year / lifetime（也可传 durationDays 覆盖）
        let days;
        if (body.durationDays != null && body.durationDays !== '') {
          days = parseInt(body.durationDays, 10);
        } else {
          days = planDays(plan);
        }
        const expiresAt = days == null ? null : (Date.now() + days * 24 * 60 * 60 * 1000);

        const authValue = {
          auth_code: authCode,
          username: username,
          authorized: true,
          plan: plan,
          expires_at: expiresAt
        };

        if (env.AUTH_DEVICES) {
          await env.AUTH_DEVICES.put(deviceId, JSON.stringify(authValue));
          // 授权成功后，从待授权列表中清除该设备 ID
          await env.AUTH_DEVICES.delete('pending:' + deviceId);
        }

        return new Response(JSON.stringify({
          success: true,
          msg: '设备授权成功已记录',
          data: {
            deviceId,
            username,
            authCode,
            plan,
            expiresAt: expiresAt == null ? null : new Date(expiresAt).toISOString()
          }
        }), {
          headers: { 'Content-Type': 'application/json', ...corsHeaders }
        });
      }

      // 路由 4：获取已授权和待授权设备列表
      if (url.pathname === '/admin/list' && method === 'GET') {
        const adminKey = request.headers.get('X-Admin-Key') || url.searchParams.get('adminKey');
        if (!adminKey || adminKey !== env.ADMIN_KEY) {
          return new Response(JSON.stringify({ success: false, msg: '管理员身份认证失败' }), {
            status: 401,
            headers: { 'Content-Type': 'application/json', ...corsHeaders }
          });
        }

        const authorizedDevices = [];
        const pendingDevices = [];

        if (env.AUTH_DEVICES) {
          const list = await env.AUTH_DEVICES.list();
          for (const key of list.keys) {
            const valStr = await env.AUTH_DEVICES.get(key.name);
            if (valStr) {
              if (key.name.startsWith('pending:')) {
                const devId = key.name.substring('pending:'.length);
                const reqTimestamp = parseInt(valStr) || Date.now();
                pendingDevices.push({
                  deviceId: devId,
                  requestedAt: reqTimestamp
                });
              } else {
                try {
                  const parsed = JSON.parse(valStr);
                  authorizedDevices.push({
                    deviceId: key.name,
                    ...parsed
                  });
                } catch (_) {}
              }
            }
          }
        }

        // 对待授权设备按时间倒序排列
        pendingDevices.sort((a, b) => b.requestedAt - a.requestedAt);

        return new Response(JSON.stringify({ 
          success: true, 
          authorized: authorizedDevices, 
          pending: pendingDevices 
        }), {
          headers: { 'Content-Type': 'application/json', ...corsHeaders }
        });
      }

      // 路由 5：注销/删除设备授权
      if (url.pathname === '/admin/revoke' && method === 'DELETE') {
        const adminKey = request.headers.get('X-Admin-Key') || url.searchParams.get('adminKey');
        if (!adminKey || adminKey !== env.ADMIN_KEY) {
          return new Response(JSON.stringify({ success: false, msg: '管理员身份认证失败' }), {
            status: 401,
            headers: { 'Content-Type': 'application/json', ...corsHeaders }
          });
        }

        const { deviceId } = await request.json();
        if (!deviceId) {
          return new Response(JSON.stringify({ success: false, msg: '参数缺失: deviceId' }), {
            status: 400,
            headers: { 'Content-Type': 'application/json', ...corsHeaders }
          });
        }

        if (env.AUTH_DEVICES) {
          await env.AUTH_DEVICES.delete(deviceId);
          await env.AUTH_DEVICES.delete('pending:' + deviceId);
        }

        return new Response(JSON.stringify({ success: true, msg: '已注销该设备授权' }), {
          headers: { 'Content-Type': 'application/json', ...corsHeaders }
        });
      }

      // 路由 6：手动忽略/删除待授权列表中的某台设备
      if (url.pathname === '/admin/dismiss-pending' && method === 'DELETE') {
        const adminKey = request.headers.get('X-Admin-Key') || url.searchParams.get('adminKey');
        if (!adminKey || adminKey !== env.ADMIN_KEY) {
          return new Response(JSON.stringify({ success: false, msg: '管理员身份认证失败' }), {
            status: 401,
            headers: { 'Content-Type': 'application/json', ...corsHeaders }
          });
        }

        const { deviceId } = await request.json();
        if (!deviceId) {
          return new Response(JSON.stringify({ success: false, msg: '参数缺失: deviceId' }), {
            status: 400,
            headers: { 'Content-Type': 'application/json', ...corsHeaders }
          });
        }

        if (env.AUTH_DEVICES) {
          await env.AUTH_DEVICES.delete('pending:' + deviceId);
        }

        return new Response(JSON.stringify({ success: true, msg: '已从待授权列表中移除' }), {
          headers: { 'Content-Type': 'application/json', ...corsHeaders }
        });
      }

      // 未匹配路由：返回 Nginx 经典 404 蜜罐页面
      return new Response(getNginx404Page(), {
        status: 404,
        headers: { 'Content-Type': 'text/html; charset=utf-8' }
      });

    } catch (error) {
      return new Response(JSON.stringify({ success: false, msg: '系统内部错误: ' + error.message }), {
        status: 500,
        headers: { 'Content-Type': 'application/json', ...corsHeaders }
      });
    }
  }
};


function normalizePlan(plan) {
  const p = String(plan || 'year').toLowerCase().trim();
  if (['month', 'quarter', 'year', 'lifetime', 'custom'].includes(p)) return p;
  // Chinese aliases from admin UI
  if (p === '月' || p === '1m') return 'month';
  if (p === '季' || p === '3m') return 'quarter';
  if (p === '年' || p === '12m') return 'year';
  if (p === '终身' || p === 'forever' || p === 'permanent') return 'lifetime';
  return 'year';
}

/** @returns {number|null} days; null means lifetime */
function planDays(plan) {
  switch (normalizePlan(plan)) {
    case 'month': return 30;
    case 'quarter': return 90;
    case 'year': return 365;
    case 'lifetime': return null;
    default: return 365;
  }
}

// 兼容旧版：计算 HMAC-SHA256 并生成简短激活码
async function generateHMACCodeOld(message, secret) {
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey(
    'raw',
    enc.encode(secret),
    { name: 'HMAC', hash: { name: 'SHA-256' } },
    false,
    ['sign']
  );
  
  const signature = await crypto.subtle.sign(
    'HMAC',
    key,
    enc.encode(message)
  );

  const hashArray = Array.from(new Uint8Array(signature));
  const hashHex = hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
  return 'AUTH-' + hashHex.substring(0, 12).toUpperCase();
}

// 升级版：计算加入随机 4 位 Salt 因子的 HMAC-SHA256 授权码
async function generateHMACCode(deviceId, secret, salt = null) {
  if (!salt) {
    // 随机生成 2 字节（4位十六进制）盐值
    const rawSalt = new Uint8Array(2);
    crypto.getRandomValues(rawSalt);
    salt = Array.from(rawSalt).map(b => b.toString(16).padStart(2, '0')).join('').toUpperCase();
  }
  const message = deviceId + ":" + salt;

  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey(
    'raw',
    enc.encode(secret),
    { name: 'HMAC', hash: { name: 'SHA-256' } },
    false,
    ['sign']
  );
  
  const signature = await crypto.subtle.sign(
    'HMAC',
    key,
    enc.encode(message)
  );

  const hashArray = Array.from(new Uint8Array(signature));
  const hashHex = hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
  const hashPart = hashHex.substring(0, 12).toUpperCase();
  
  return `AUTH-${salt}-${hashPart}`;
}

// 经典的 Nginx 404 伪装页面
function getNginx404Page() {
  return `<html>
<head><title>404 Not Found</title></head>
<body>
<center><h1>404 Not Found</h1></center>
<hr><center>nginx</center>
</body>
</html>`;
}

// 可视化网页的 HTML + TailwindCSS
function getAdminHtmlPage() {
  return `
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Music Car 一机一码授权</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <style>
        body {
            background-color: #0f172a;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
        }
        .backdrop-glass {
            background: rgba(30, 41, 59, 0.7);
            backdrop-filter: blur(16px);
            border: 1px solid rgba(255, 255, 255, 0.08);
        }
    </style>
</head>
<body class="text-slate-200 min-h-screen pb-12">
    <div class="max-w-5xl mx-auto px-4 pt-8">
        
        <!-- Header -->
        <div class="flex flex-col md:flex-row md:items-center md:justify-between pb-6 mb-8 border-b border-slate-800">
            <div>
                <h1 class="text-2xl font-bold tracking-tight text-white flex items-center gap-2">
                    🛡️ <span class="bg-clip-text text-transparent bg-gradient-to-r from-blue-400 to-indigo-400">Music Car 一机一码授权</span>
                </h1>
                <p class="text-slate-400 text-sm mt-1">受管控的移动端应用防乱用授权中心</p>
            </div>
            
            <div class="mt-4 md:mt-0 flex items-center gap-2">
                <!-- 鉴权状态徽章 -->
                <button onclick="promptAdminKey()" id="authBadge" class="px-4 py-2 rounded-xl text-xs font-semibold tracking-wider transition flex items-center gap-2 shadow-lg">
                    <span id="authBadgeDot" class="w-2 h-2 rounded-full animate-pulse"></span>
                    <span id="authBadgeText">检测中...</span>
                </button>
            </div>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
            
            <!-- 左侧：新建授权 -->
            <div class="lg:col-span-1">
                <div class="backdrop-glass rounded-2xl p-6 shadow-xl">
                    <h2 class="text-lg font-semibold text-white mb-4 flex items-center gap-2">
                        ➕ 新建设备授权
                    </h2>
                    
                    <div class="space-y-4">
                        <div>
                            <label class="block text-xs font-semibold uppercase text-slate-400 mb-1">设备 ID (Unique Device ID)</label>
                            <input type="text" id="newDeviceId" placeholder="双击或从右侧列表中点击快捷填入" 
                                   class="w-full bg-slate-900 border border-slate-800 px-3.5 py-2.5 rounded-xl text-slate-100 placeholder-slate-600 focus:outline-none focus:border-blue-500 text-sm">
                        </div>
                        
                        <div>
                            <label class="block text-xs font-semibold uppercase text-slate-400 mb-1">使用者姓名 (Username)</label>
                            <input type="text" id="newUsername" placeholder="例如: 卜泽晨" 
                                   class="w-full bg-slate-900 border border-slate-800 px-3.5 py-2.5 rounded-xl text-slate-100 placeholder-slate-600 focus:outline-none focus:border-blue-500 text-sm">
                        </div>
                        
                        <div>
                            <label class="block text-xs font-semibold uppercase text-slate-400 mb-1">授权期限 (Duration)</label>
                            <select id="authPlan" class="w-full bg-slate-900 border border-slate-800 px-3.5 py-2.5 rounded-xl text-slate-100 focus:outline-none focus:border-blue-500 text-sm">
                                <option value="month">月卡 (30 天)</option>
                                <option value="quarter">季卡 (90 天)</option>
                                <option value="year" selected>年卡 (365 天)</option>
                                <option value="lifetime">终身</option>
                            </select>
                        </div>

                        <button onclick="createAuthorization()" class="w-full bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-500 hover:to-indigo-500 text-white font-medium py-3 rounded-xl transition shadow-lg shadow-blue-900/20 text-sm">
                            生成激活码并写入白名单
                        </button>
                    </div>

                    <!-- 结果展示 -->
                    <div id="resultBox" class="mt-6 p-4 rounded-xl bg-emerald-950/30 border border-emerald-500/20 hidden">
                        <span class="text-xs font-semibold text-emerald-400 block mb-1">生成成功</span>
                        <div class="flex items-center justify-between bg-slate-900 p-2 rounded-lg border border-slate-800">
                            <code id="generatedCode" class="text-emerald-400 font-mono text-sm select-all">AUTH-XXXXXX</code>
                            <button onclick="copyGeneratedCode()" class="text-slate-400 hover:text-white text-xs px-2 py-1">复制</button>
                        </div>
                        <p class="text-slate-400 text-xs mt-2">请复制激活码发送给用户，在 App 认证页面输入即可。</p>
                    </div>
                </div>
            </div>

            <!-- 右侧：授权列表与待授权列表 -->
            <div class="lg:col-span-2 space-y-8">
                
                <!-- 待授权设备列表 -->
                <div class="backdrop-glass rounded-2xl p-6 shadow-xl border border-rose-500/10">
                    <div class="flex justify-between items-center mb-6">
                        <h2 class="text-lg font-semibold text-rose-400 flex items-center gap-2">
                            ⏳ 近期请求授权的设备 (待授权)
                        </h2>
                        <span class="bg-rose-950/40 text-rose-400 border border-rose-500/20 text-xs font-semibold px-2 py-0.5 rounded-full" id="pendingCount">0</span>
                    </div>

                    <div class="overflow-x-auto max-h-64 overflow-y-auto">
                        <table class="w-full text-left text-sm">
                            <thead>
                                <tr class="border-b border-slate-800 text-slate-400 text-xs uppercase font-semibold">
                                    <th class="py-2.5 px-4">请求设备 ID</th>
                                    <th class="py-2.5 px-4">请求时间</th>
                                    <th class="py-2.5 px-4 text-right">操作</th>
                                </tr>
                            </thead>
                            <tbody id="pendingTableBody" class="divide-y divide-slate-800/40">
                                <tr>
                                    <td colspan="3" class="py-6 text-center text-slate-500">暂无待授权的请求。 (未授权的手机打开App后会自动记录在此)</td>
                                </tr>
                            </tbody>
                        </table>
                    </div>
                </div>

                <!-- 已授权设备列表 -->
                <div class="backdrop-glass rounded-2xl p-6 shadow-xl">
                    <div class="flex justify-between items-center mb-6">
                        <h2 class="text-lg font-semibold text-white flex items-center gap-2">
                            📋 已授权设备列表
                        </h2>
                        <button onclick="fetchDeviceList()" class="text-sm text-blue-400 hover:text-blue-300 font-medium">
                            🔄 刷新列表
                        </button>
                    </div>

                    <div class="overflow-x-auto max-h-96 overflow-y-auto">
                        <table class="w-full text-left text-sm">
                            <thead>
                                <tr class="border-b border-slate-800 text-slate-400 text-xs uppercase font-semibold">
                                    <th class="py-3 px-4">使用者</th>
                                    <th class="py-3 px-4">设备 ID</th>
                                    <th class="py-3 px-4">授权激活码</th>
                                    <th class="py-3 px-4">计划</th>
                                    <th class="py-3 px-4">有效期至</th>
                                    <th class="py-3 px-4 text-right">操作</th>
                                </tr>
                            </thead>
                            <tbody id="deviceTableBody" class="divide-y divide-slate-800/40">
                                <tr>
                                    <td colspan="6" class="py-8 text-center text-slate-500">正在获取列表... (请确保已保存正确的 ADMIN_KEY)</td>
                                </tr>
                            </tbody>
                        </table>
                    </div>
                </div>

            </div>

        </div>
    </div>

    <script>
        // 页面启动初始化
        document.addEventListener('DOMContentLoaded', () => {
            // 1. 尝试从 URL 查询参数中获取 key 或 adminKey
            const urlParams = new URLSearchParams(window.location.search);
            const urlKey = urlParams.get('key') || urlParams.get('adminKey');
            if (urlKey) {
                localStorage.setItem('music-car_admin_key', urlKey.trim());
                // 擦除 URL 中的敏感参数
                const cleanUrl = window.location.protocol + "//" + window.location.host + window.location.pathname;
                window.history.replaceState({ path: cleanUrl }, '', cleanUrl);
            }

            // 2. 更新状态徽章并加载列表
            updateAuthBadge();
            fetchDeviceList();
        });

        function getAdminKey() {
            return localStorage.getItem('music-car_admin_key') || '';
        }

        // 更新鉴权徽章状态
        function updateAuthBadge() {
            const key = getAdminKey();
            const badge = document.getElementById('authBadge');
            const dot = document.getElementById('authBadgeDot');
            const text = document.getElementById('authBadgeText');
            
            if (key) {
                badge.className = "bg-emerald-950/50 border border-emerald-500/30 text-emerald-400 px-4 py-2 rounded-xl text-xs font-medium transition flex items-center gap-2 hover:bg-emerald-900/40 shadow-lg shadow-emerald-950/20 cursor-pointer";
                dot.className = "w-2 h-2 rounded-full bg-emerald-400";
                text.innerText = "已保存密钥 (点击更换)";
            } else {
                badge.className = "bg-rose-950/50 border border-rose-500/30 text-rose-400 px-4 py-2 rounded-xl text-xs font-medium transition flex items-center gap-2 hover:bg-rose-900/40 shadow-lg shadow-rose-950/20 cursor-pointer animate-pulse";
                dot.className = "w-2 h-2 rounded-full bg-rose-400";
                text.innerText = "未保存密钥 (点击录入)";
            }
        }

        // 弹窗录入、修改密钥
        function promptAdminKey() {
            const currentKey = getAdminKey();
            const key = prompt("请输入您的管理员密钥 (ADMIN_KEY):", currentKey);
            if (key !== null) {
                const trimmedKey = key.trim();
                if (trimmedKey) {
                    localStorage.setItem('music-car_admin_key', trimmedKey);
                } else {
                    localStorage.removeItem('music-car_admin_key');
                }
                updateAuthBadge();
                fetchDeviceList();
            }
        }

        // 获取授权列表与待授权列表
        async function fetchDeviceList() {
            const key = getAdminKey();
            const body = document.getElementById('deviceTableBody');
            const pendingBody = document.getElementById('pendingTableBody');
            
            if (!key) {
                body.innerHTML = '<tr><td colspan="6" class="py-8 text-center text-rose-400 font-medium">请先点击右上角“未保存密钥”录入管理员密钥(ADMIN_KEY)！</td></tr>';
                pendingBody.innerHTML = '<tr><td colspan="3" class="py-6 text-center text-rose-400 font-medium">请点击右上角录入并保存管理员密钥。</td></tr>';
                return;
            }

            try {
                const response = await fetch('/admin/list', {
                    headers: { 'X-Admin-Key': key }
                });
                
                if (!response.ok) {
                    if (response.status === 401) {
                        localStorage.removeItem('music-car_admin_key');
                        updateAuthBadge();
                    }
                    throw new Error('未授权或密钥失效');
                }

                const res = await response.json();
                if (res.success) {
                    // 1. 渲染已授权列表
                    if (res.authorized.length === 0) {
                        body.innerHTML = '<tr><td colspan="6" class="py-8 text-center text-slate-500">暂无任何已授权的设备。</td></tr>';
                    } else {
                        body.innerHTML = res.authorized.map(device => {
                            const date = new Date(device.expires_at).toLocaleDateString('zh-CN');
                            const isExpired = Date.now() > device.expires_at;
                            return \`
                                <tr class="hover:bg-slate-800/20 transition-colors">
                                    <td class="py-3.5 px-4 font-medium text-white">\${device.username}</td>
                                    <td class="py-3.5 px-4 font-mono text-xs text-slate-400">\${device.deviceId}</td>
                                    <td class="py-3.5 px-4"><code class="bg-slate-900 border border-slate-800 px-2 py-1 rounded text-emerald-400 text-xs font-mono">\${device.auth_code}</code></td>
                                    <td class="py-3.5 px-4 text-xs \${isExpired ? 'text-rose-500' : 'text-slate-400'}">
                                        \${date} \${isExpired ? '(已过期)' : ''}
                                    </td>
                                    <td class="py-3.5 px-4 text-right">
                                        <button onclick="revokeAuthorization('\${device.deviceId}')" class="text-xs text-rose-500 hover:text-rose-400 font-medium transition">
                                            注销授权
                                        </button>
                                    </td>
                                </tr>
                            \`;
                        }).join('');
                    }

                    // 2. 渲染待授权列表
                    document.getElementById('pendingCount').innerText = res.pending.length;
                    if (res.pending.length === 0) {
                        pendingBody.innerHTML = '<tr><td colspan="3" class="py-6 text-center text-slate-500">暂无待授权的请求。 (未授权手机访问后会自动出现在这)</td></tr>';
                    } else {
                        pendingBody.innerHTML = res.pending.map(device => {
                            const timeStr = new Date(device.requestedAt).toLocaleString('zh-CN');
                            return \`
                                <tr class="hover:bg-slate-800/20 transition-colors">
                                    <td class="py-2.5 px-4 font-mono text-xs text-rose-300 font-medium">\${device.deviceId}</td>
                                    <td class="py-2.5 px-4 text-xs text-slate-400">\${timeStr}</td>
                                    <td class="py-2.5 px-4 text-right flex gap-3 justify-end">
                                        <button onclick="quickAuth('\${device.deviceId}')" class="text-xs text-blue-400 hover:text-blue-300 font-semibold transition">
                                            ⚡ 快速授权
                                        </button>
                                        <button onclick="dismissPending('\${device.deviceId}')" class="text-xs text-slate-500 hover:text-slate-400 transition">
                                            忽略
                                        </button>
                                    </td>
                                </tr>
                            \`;
                        }).join('');
                    }
                }
            } catch (error) {
                body.innerHTML = \`<tr><td colspan="6" class="py-8 text-center text-rose-500">列表拉取失败: \${error.message}</td></tr>\`;
                pendingBody.innerHTML = \`<tr><td colspan="3" class="py-6 text-center text-rose-500">获取待授权设备失败</td></tr>\`;
            }
        }

        // 快速填入设备 ID 并聚焦
        function quickAuth(deviceId) {
            document.getElementById('newDeviceId').value = deviceId;
            document.getElementById('newUsername').focus();
        }

        // 忽略待授权设备
        async function dismissPending(deviceId) {
            const key = getAdminKey();
            try {
                const response = await fetch('/admin/dismiss-pending', {
                    method: 'DELETE',
                    headers: {
                        'Content-Type': 'application/json',
                        'X-Admin-Key': key
                    },
                    body: JSON.stringify({ deviceId })
                });
                const res = await response.json();
                if (res.success) {
                    fetchDeviceList();
                }
            } catch (error) {
                alert('操作失败: ' + error.message);
            }
        }

        // 创建新授权
        async function createAuthorization() {
            const key = getAdminKey();
            if (!key) {
                alert('请先输入并保存管理员密钥！');
                return;
            }

            const deviceId = document.getElementById('newDeviceId').value.trim();
            const username = document.getElementById('newUsername').value.trim();
            const plan = document.getElementById('authPlan').value;

            if (!deviceId || !username) {
                alert('请填写完整的设备 ID 和姓名！');
                return;
            }

            try {
                const response = await fetch('/admin/authorize', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        'X-Admin-Key': key
                    },
                    body: JSON.stringify({ deviceId, username, plan })
                });

                const res = await response.json();
                if (res.success) {
                    document.getElementById('generatedCode').innerText = res.data.authCode;
                    document.getElementById('resultBox').classList.remove('hidden');
                    
                    // 清空输入框并刷新列表
                    document.getElementById('newDeviceId').value = '';
                    document.getElementById('newUsername').value = '';
                    fetchDeviceList();
                } else {
                    alert('授权失败: ' + res.msg);
                }
            } catch (error) {
                alert('系统异常: ' + error.message);
            }
        }

        // 注销授权
        async function revokeAuthorization(deviceId) {
            if (!confirm('您确定要注销设备 ' + deviceId + ' 的授权吗？注销后该设备将无法正常使用应用。')) {
                return;
            }

            const key = getAdminKey();
            try {
                const response = await fetch('/admin/revoke', {
                    method: 'DELETE',
                    headers: {
                        'Content-Type': 'application/json',
                        'X-Admin-Key': key
                    },
                    body: JSON.stringify({ deviceId })
                });

                const res = await response.json();
                if (res.success) {
                    alert('注销成功！');
                    fetchDeviceList();
                } else {
                    alert('注销失败: ' + res.msg);
                }
            } catch (error) {
                alert('系统异常: ' + error.message);
            }
        }

        // 复制代码
        function copyGeneratedCode() {
            const text = document.getElementById('generatedCode').innerText;
            navigator.clipboard.writeText(text).then(() => {
                alert('激活码已成功复制到剪贴板！');
            });
        }
    </script>
</body>
</html>
  `;
}
