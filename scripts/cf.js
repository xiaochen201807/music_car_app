const MAIN_ORIGIN = "https://ios.25pan.com";
const MAIN_HOST = "ios.25pan.com";
const MEDIA_PROXY_PATH = "/__media";

const PROXY_HOST_SUFFIXES = [
    ".kuwo.cn",
    ".kuwo.com",
    ".lvkuwo.cn",        // 新增
    ".kw-er.kuwo.cn",    // 酷我音乐新域名
    ".music.126.net",
    ".126.net",
    ".163.com",
    ".douyinpic.com",    // 抖音图片CDN
    ".gtimg.cn",         // QQ音乐图片CDN
    ".qq.com",           // QQ音乐主域
    ".y.qq.com",         // QQ音乐音频CDN
];

const TEXT_TYPES = [
    "text/html",
    "text/css",
    "application/javascript",
    "application/x-javascript",
    "application/ecmascript",
    "text/ecmascript",
    "text/javascript",
    "module",
    "application/json",
    "application/manifest+json",
    "application/xml",
    "text/xml",
    "text/plain",
];

const AUDIO_EXTENSIONS = [".mp3", ".m4a", ".flac", ".wav", ".ogg", ".aac"];
const IMAGE_EXTENSIONS = [".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp"];

export default {
    async fetch(request) {
        const incomingUrl = new URL(request.url);

        if (request.method === "OPTIONS") {
            return handleOptions(request);
        }

        if (incomingUrl.pathname === MEDIA_PROXY_PATH) {
            return proxyMedia(request, incomingUrl);
        }

        return proxyMainSite(request, incomingUrl);
    },
};

async function proxyMainSite(request, incomingUrl) {
    const targetUrl = new URL(incomingUrl.pathname + incomingUrl.search, MAIN_ORIGIN);

    const requestHeaders = new Headers(request.headers);

    requestHeaders.set("Host", MAIN_HOST);
    requestHeaders.set("Origin", MAIN_ORIGIN);
    requestHeaders.set("Referer", `${MAIN_ORIGIN}/music`);
    requestHeaders.set("Accept-Encoding", "identity");

    // 清理 Cloudflare 相关头
    requestHeaders.delete("cf-connecting-ip");
    requestHeaders.delete("cf-ipcountry");
    requestHeaders.delete("cf-ray");
    requestHeaders.delete("x-forwarded-for");
    requestHeaders.delete("x-real-ip");

    const method = request.method.toUpperCase();

    const upstream = await fetch(targetUrl.toString(), {
        method,
        headers: requestHeaders,
        body: method === "GET" || method === "HEAD" ? undefined : request.body,
        redirect: "manual",
    });

    const responseHeaders = new Headers(upstream.headers);

    rewriteLocation(responseHeaders, incomingUrl);
    rewriteCookies(upstream.headers, responseHeaders);
    fixProxyResponseHeaders(responseHeaders, incomingUrl);

    const contentType = responseHeaders.get("content-type") || "";
    if (contentType.toLowerCase().includes("text/html")) {
        responseHeaders.set("clear-site-data", '"cache"');
    }

    if (shouldRewriteText(contentType)) {
        let text = await upstream.text();
        text = rewriteText(text, incomingUrl, contentType);

        responseHeaders.delete("content-length");
        responseHeaders.delete("content-encoding");

        return new Response(text, {
            status: upstream.status,
            statusText: upstream.statusText,
            headers: responseHeaders,
        });
    }

    return new Response(upstream.body, {
        status: upstream.status,
        statusText: upstream.statusText,
        headers: responseHeaders,
    });
}

async function proxyMedia(request, incomingUrl) {
    const rawTarget = incomingUrl.searchParams.get("u");
    if (!rawTarget) return textResponse("Missing media url", 400);

    let targetUrl = parseTargetUrl(rawTarget);
    if (!targetUrl) return textResponse(`Invalid media url: ${rawTarget}`, 400);

    targetUrl = unwrapNestedMediaUrl(targetUrl, incomingUrl);

    if (targetUrl.protocol !== "https:" && targetUrl.protocol !== "http:") {
        return textResponse(`Media protocol is not allowed: ${targetUrl.protocol}`, 403);
    }

    if (!isPublicHost(targetUrl.hostname)) {
        return textResponse(`Media host is not allowed: ${targetUrl.hostname}`, 403);
    }

    const requestHeaders = new Headers();
    ["range", "if-range", "if-none-match", "if-modified-since", "user-agent", "accept", "accept-language", "cookie"]
        .forEach(name => copyHeader(request.headers, requestHeaders, name));

    requestHeaders.set("Accept-Encoding", "identity");
    requestHeaders.set("Referer", mediaRefererFor(targetUrl));

    const upstream = await fetch(targetUrl.toString(), {
        method: request.method === "HEAD" ? "HEAD" : "GET",
        headers: requestHeaders,
        redirect: "follow",
    });

    const responseHeaders = new Headers(upstream.headers);
    fixMediaResponseHeaders(responseHeaders);

    const contentType = responseHeaders.get("content-type") || "";
    if (request.method !== "HEAD" && shouldRewriteText(contentType)) {
        let text = await upstream.text();
        text = rewriteText(text, incomingUrl, contentType);

        responseHeaders.delete("content-length");
        responseHeaders.delete("content-encoding");

        return new Response(text, {
            status: upstream.status,
            statusText: upstream.statusText,
            headers: responseHeaders,
        });
    }

    return new Response(upstream.body, {
        status: upstream.status,
        statusText: upstream.statusText,
        headers: responseHeaders,
    });
}

// ==================== 核心重写逻辑（重点优化部分） ====================
function rewriteText(text, incomingUrl, contentType = "") {
    const lowerContentType = contentType.toLowerCase();
    const publicOrigin = incomingUrl.origin;
    const publicHost = incomingUrl.hostname;

    // Do not rewrite JavaScript source. The music app contains URL-looking
    // regex literals such as /http:\/\/img.../g; turning those into proxy URLs
    // corrupts the module and prevents the whole SPA from booting. Dynamic
    // media requests are handled by the injected runtime hooks instead.
    if (isJavaScriptContent(lowerContentType)) {
        return text;
    }

    let rewritten = rewriteMainOriginText(text, incomingUrl, publicOrigin);

    if (lowerContentType.includes("text/html") || shouldRewriteEmbeddedUrls(lowerContentType)) {
        rewritten = rewriteAbsoluteUrls(rewritten, publicOrigin, publicHost);
        rewritten = rewriteEscapedAbsoluteUrls(rewritten, publicOrigin, publicHost);
        rewritten = rewriteProtocolRelativeUrls(rewritten, publicOrigin, publicHost);
    }

    if (lowerContentType.includes("text/html")) {
        return injectRuntimeProxy(rewritten, publicOrigin);
    }

    return rewritten;
}

function isJavaScriptContent(contentType) {
    return contentType.includes("javascript") ||
        contentType.includes("ecmascript") ||
        contentType.includes("text/js") ||
        contentType.includes("module");
}

function shouldRewriteEmbeddedUrls(contentType) {
    return contentType.includes("json") ||
        contentType.includes("xml") ||
        contentType.includes("text/plain") ||
        contentType.includes("text/css") ||
        contentType.includes("manifest");
}

function rewriteMainOriginText(text, incomingUrl, publicOrigin) {
    return text
        .replaceAll("https://ios.25pan.com", publicOrigin)
        .replaceAll("http://ios.25pan.com", publicOrigin)
        .replaceAll("//ios.25pan.com", `//${incomingUrl.host}`)
        .replaceAll("ios.25pan.com", incomingUrl.host);
}

function rewriteAbsoluteUrls(text, publicOrigin, publicHost) {
    return text.replace(/\bhttps?:\/\/[^\s"'<>\\]+/gi, (rawUrl) => {
        return rewriteUrlToken(rawUrl, publicOrigin, publicHost);
    });
}

function rewriteEscapedAbsoluteUrls(text, publicOrigin, publicHost) {
    return text.replace(/\bhttps?:\\\/\\\/(?:\\\/|[^\s"'<>\\])+/gi, (rawUrl) => {
        const unescaped = rawUrl.replace(/\\\//g, "/");
        const proxied = rewriteUrlToken(unescaped, publicOrigin, publicHost);
        return proxied === unescaped ? rawUrl : proxied.replace(/\//g, "\\/");
    });
}

function rewriteProtocolRelativeUrls(text, publicOrigin, publicHost) {
    return text.replace(/(^|[\s"'(=:{\[,])\/\/[^\s"'<>\\)]+/gi, (match, prefix) => {
        const rawUrl = match.slice(prefix.length);
        const proxied = rewriteUrlToken(`https:${rawUrl}`, publicOrigin, publicHost);
        return proxied === `https:${rawUrl}` ? match : `${prefix}${proxied}`;
    });
}

function rewriteUrlToken(rawUrl, publicOrigin, publicHost) {
    const { urlPart, suffix } = splitTrailingUrlPunctuation(rawUrl);
    if (!shouldProxyUrl(urlPart, publicHost)) return rawUrl;
    return `${toMediaProxyUrl(urlPart, publicOrigin)}${suffix}`;
}

function splitTrailingUrlPunctuation(rawUrl) {
    let urlPart = rawUrl;
    let suffix = "";
    while (/[),.;\]}]/.test(urlPart.slice(-1))) {
        const last = urlPart.slice(-1);
        if (last === ")" && (urlPart.match(/\(/g) || []).length < (urlPart.match(/\)/g) || []).length) {
            suffix = last + suffix;
            urlPart = urlPart.slice(0, -1);
            continue;
        }
        if (last !== ")") {
            suffix = last + suffix;
            urlPart = urlPart.slice(0, -1);
            continue;
        }
        break;
    }
    return { urlPart, suffix };
}

function injectRuntimeProxy(html, publicOrigin) {
    if (html.includes("__musicCarMediaProxyInstalled")) return html;

    const script = `<script>
(function () {
  try {
  if (window.__musicCarMediaProxyInstalled) return;
  window.__musicCarMediaProxyInstalled = true;
  var MEDIA_PROXY_ORIGIN = ${JSON.stringify(publicOrigin)};
  var MAIN_HOST = ${JSON.stringify(MAIN_HOST)};
  function isPublicHost(host) {
    host = String(host || "").toLowerCase();
    return !!host &&
      host !== "localhost" &&
      !host.endsWith(".localhost") &&
      host !== "127.0.0.1" &&
      !host.startsWith("127.") &&
      !host.startsWith("10.") &&
      !host.startsWith("192.168.") &&
      !/^172\\.(1[6-9]|2\\d|3[0-1])\\./.test(host) &&
      host !== "0.0.0.0" &&
      host !== "::1" &&
      host !== "[::1]";
  }
  function proxyUrl(value) {
    if (typeof value !== "string" || !value) return value;
    try {
      var url = new URL(value, location.href);
      if ((url.protocol !== "http:" && url.protocol !== "https:") ||
          url.hostname === location.hostname ||
          url.hostname === MAIN_HOST ||
          url.pathname === ${JSON.stringify(MEDIA_PROXY_PATH)} ||
          !isPublicHost(url.hostname)) {
        return value;
      }
      return MEDIA_PROXY_ORIGIN + ${JSON.stringify(MEDIA_PROXY_PATH + "?u=")} + encodeURIComponent(url.href);
    } catch (_) {
      return value;
    }
  }
  window.__musicCarProxyUrl = proxyUrl;

  var nativeFetch = window.fetch;
  if (nativeFetch) {
    window.fetch = function (input, init) {
      if (input instanceof Request) {
        var proxiedRequestUrl = proxyUrl(input.url);
        if (proxiedRequestUrl !== input.url) {
          input = new Request(proxiedRequestUrl, input);
        }
      } else {
        input = proxyUrl(input);
      }
      return nativeFetch.call(this, input, init);
    };
  }

  var nativeOpen = typeof XMLHttpRequest !== "undefined" && XMLHttpRequest.prototype.open;
  if (nativeOpen) {
    XMLHttpRequest.prototype.open = function (method, url) {
      arguments[1] = proxyUrl(url);
      return nativeOpen.apply(this, arguments);
    };
  }

  if (typeof Element !== "undefined" && Element.prototype && Element.prototype.setAttribute) {
    var nativeSetAttribute = Element.prototype.setAttribute;
    Element.prototype.setAttribute = function (name, value) {
      var attr = String(name || "").toLowerCase();
      if (attr === "src" || attr === "href" || attr === "poster") {
        value = proxyUrl(value);
      } else if (attr === "srcset") {
        value = rewriteSrcset(value);
      }
      return nativeSetAttribute.call(this, name, value);
    };
  }

  function rewriteSrcset(value) {
    if (typeof value !== "string") return value;
    return value.split(",").map(function (part) {
      var trimmed = part.trim();
      var pieces = trimmed.split(/\\s+/);
      if (!pieces[0]) return part;
      pieces[0] = proxyUrl(pieces[0]);
      return pieces.join(" ");
    }).join(", ");
  }

  function patchUrlProperty(proto, prop, transformer) {
    var descriptor = Object.getOwnPropertyDescriptor(proto, prop);
    if (!descriptor || !descriptor.set || !descriptor.get) return;
    Object.defineProperty(proto, prop, {
      configurable: true,
      enumerable: descriptor.enumerable,
      get: descriptor.get,
      set: function (value) {
        return descriptor.set.call(this, transformer(value));
      }
    });
  }

  [
    [typeof HTMLImageElement !== "undefined" && HTMLImageElement.prototype, "src", proxyUrl],
    [typeof HTMLImageElement !== "undefined" && HTMLImageElement.prototype, "srcset", rewriteSrcset],
    [typeof HTMLMediaElement !== "undefined" && HTMLMediaElement.prototype, "src", proxyUrl],
    [typeof HTMLSourceElement !== "undefined" && HTMLSourceElement.prototype, "src", proxyUrl],
    [typeof HTMLSourceElement !== "undefined" && HTMLSourceElement.prototype, "srcset", rewriteSrcset],
    [typeof HTMLLinkElement !== "undefined" && HTMLLinkElement.prototype, "href", proxyUrl],
    [typeof HTMLScriptElement !== "undefined" && HTMLScriptElement.prototype, "src", proxyUrl]
  ].forEach(function (item) {
    if (item[0]) patchUrlProperty(item[0], item[1], item[2]);
  });

  if (window.Audio) {
    var NativeAudio = window.Audio;
    window.Audio = function (src) {
      return new NativeAudio(src ? proxyUrl(src) : src);
    };
    window.Audio.prototype = NativeAudio.prototype;
  }
  } catch (error) {
    try { console.warn("[music-proxy] runtime proxy install failed", error); } catch (_) {}
  }
})();
</script>`;

    if (/<head[^>]*>/i.test(html)) {
        return html.replace(/<head[^>]*>/i, (head) => `${head}${script}`);
    }
    if (/<html[^>]*>/i.test(html)) {
        return html.replace(/<html[^>]*>/i, (tag) => `${tag}${script}`);
    }
    return `${script}${html}`;
}

function shouldProxyUrl(rawUrl, publicHost) {
    let url;
    try {
        url = new URL(rawUrl);
    } catch {
        return false;
    }

    const host = url.hostname.toLowerCase();
    const currentHost = publicHost.toLowerCase();

    // 不代理自己和 /__media 路径
    if (host === currentHost || url.pathname === "/__media") {
        return false;
    }

    // 不代理主站域名
    if (host === MAIN_HOST.toLowerCase()) {
        return false;
    }

    // 只要是公网地址，就代理（不再检查白名单）
    return isPublicHost(host);
}

function toMediaProxyUrl(rawUrl, publicOrigin) {
    const cleaned = rawUrl
        .replaceAll("&amp;", "&")
        .replaceAll("\\u0026", "&")
        .replaceAll("\\/", "/");

    let targetUrl;
    try {
        targetUrl = new URL(cleaned);
    } catch {
        return rawUrl;
    }

    if (targetUrl.hostname === MAIN_HOST) return rawUrl;

    return `${publicOrigin}/__media?u=${encodeURIComponent(targetUrl.toString())}`;
}

// ==================== 其他辅助函数 ====================
function parseTargetUrl(rawTarget) {
    const candidates = [
        rawTarget,
        safeDecodeURIComponent(rawTarget),
        safeDecodeURIComponent(safeDecodeURIComponent(rawTarget)),
    ];

    for (const candidate of candidates) {
        if (!candidate) continue;
        try {
            return new URL(candidate);
        } catch { }
    }
    return null;
}

function unwrapNestedMediaUrl(targetUrl, incomingUrl) {
    let current = targetUrl;
    for (let i = 0; i < 5; i++) {
        if (current.hostname !== incomingUrl.hostname || current.pathname !== "/__media") {
            return current;
        }
        const inner = current.searchParams.get("u");
        if (!inner) return current;
        const parsed = parseTargetUrl(inner);
        if (!parsed) return current;
        current = parsed;
    }
    return current;
}

function safeDecodeURIComponent(value) {
    try { return decodeURIComponent(value); } catch { return value; }
}

function isProxyAllowedHost(hostname) {
    const host = hostname.toLowerCase();
    return PROXY_HOST_SUFFIXES.some(suffix =>
        host === suffix.slice(1) || host.endsWith(suffix)
    );
}

function isPublicHost(hostname) {
    const host = hostname.toLowerCase();
    return !(
        host === "localhost" || host.endsWith(".localhost") ||
        host === "127.0.0.1" || host.startsWith("127.") ||
        host.startsWith("10.") || host.startsWith("192.168.") ||
        /^172\.(1[6-9]|2\d|3[0-1])\./.test(host) ||
        host === "0.0.0.0" || host === "::1" || host === "[::1]"
    );
}

function mediaRefererFor(targetUrl) {
    const host = targetUrl.hostname.toLowerCase();

    if (host === "kuwo.cn" || host.endsWith(".kuwo.cn") || host.endsWith(".kuwo.com") || host.endsWith(".lvkuwo.cn")) {
        return "https://www.kuwo.cn/";
    }
    if (host === "music.126.net" || host.endsWith(".music.126.net") || host.endsWith(".163.com")) {
        return "https://music.163.com/";
    }
    if (host === "y.qq.com" || host.endsWith(".qq.com") || host.endsWith(".gtimg.cn")) {
        return "https://y.qq.com/";
    }
    if (host.endsWith(".douyinpic.com")) {
        return "https://www.douyin.com/";
    }

    return `${MAIN_ORIGIN}/music`;
}

function shouldRewriteText(contentType) {
    return TEXT_TYPES.some(type => contentType.toLowerCase().includes(type));
}

function rewriteLocation(headers, incomingUrl) {
    const location = headers.get("location");
    if (!location) return;
    try {
        const locationUrl = new URL(location, MAIN_ORIGIN);
        if (locationUrl.hostname === MAIN_HOST) {
            locationUrl.protocol = incomingUrl.protocol;
            locationUrl.host = incomingUrl.host;
            headers.set("location", locationUrl.toString());
        }
    } catch { }
}

function rewriteCookies(sourceHeaders, targetHeaders) {
    const cookies = readSetCookies(sourceHeaders);
    if (!cookies.length) return;

    targetHeaders.delete("set-cookie");
    for (const cookie of cookies) {
        targetHeaders.append("set-cookie", rewriteCookie(cookie));
    }
}

function readSetCookies(headers) {
    if (typeof headers.getSetCookie === "function") {
        return headers.getSetCookie();
    }

    if (typeof headers.getAll === "function") {
        return headers.getAll("set-cookie");
    }

    const value = headers.get("set-cookie");
    if (!value) return [];
    return splitSetCookie(value);
}

function splitSetCookie(value) {
    return value.split(/,(?=\s*[^;,=\s]+=[^;,]+)/g).map((item) => item.trim());
}

function rewriteCookie(cookie) {
    let rewritten = cookie;
    rewritten = rewritten.replace(/;\s*Domain=\.?ios\.25pan\.com/gi, "");
    rewritten = rewritten.replace(/;\s*Domain=[^;]+/gi, "");
    rewritten = rewritten.replace(/;\s*Path=[^;]*/gi, "; Path=/");

    if (!/;\s*Path=/i.test(rewritten)) {
        rewritten += "; Path=/";
    }

    if (!/;\s*Secure/i.test(rewritten)) {
        rewritten += "; Secure";
    }

    return rewritten;
}

function fixProxyResponseHeaders(headers, incomingUrl) {
    headers.delete("content-security-policy");
    headers.delete("content-security-policy-report-only");
    headers.delete("x-frame-options");
    headers.delete("permissions-policy");

    headers.set("access-control-allow-origin", incomingUrl.origin);
    headers.set("access-control-allow-credentials", "true");
    headers.set("access-control-allow-methods", "GET,POST,PUT,PATCH,DELETE,OPTIONS");
    headers.set(
        "access-control-allow-headers",
        "Authorization,Content-Type,Accept,Origin,Referer,X-Requested-With,Range,If-Range"
    );
    headers.set("cache-control", "no-store, no-cache, must-revalidate");
    headers.set("pragma", "no-cache");
    headers.set("expires", "0");
}

function fixMediaResponseHeaders(headers) {
    headers.set("access-control-allow-origin", "*");
    headers.set("access-control-allow-methods", "GET,HEAD,OPTIONS");
    headers.set(
        "access-control-allow-headers",
        "Range,If-Range,If-None-Match,If-Modified-Since,Content-Type,Accept"
    );
    headers.set(
        "access-control-expose-headers",
        "Content-Length,Content-Range,Accept-Ranges,ETag,Last-Modified,Content-Type"
    );

    headers.delete("content-security-policy");
    headers.delete("content-security-policy-report-only");
    headers.delete("x-frame-options");
}

function handleOptions(request) {
    const origin = request.headers.get("origin") || "*";

    return new Response(null, {
        status: 204,
        headers: {
            "access-control-allow-origin": origin,
            "access-control-allow-credentials": "true",
            "access-control-allow-methods": "GET,POST,PUT,PATCH,DELETE,OPTIONS",
            "access-control-allow-headers":
                "Authorization,Content-Type,Accept,Origin,Referer,X-Requested-With,Range,If-Range,If-None-Match,If-Modified-Since",
            "access-control-max-age": "86400",
        },
    });
}

function copyHeader(from, to, name) {
    const value = from.get(name);
    if (value) {
        to.set(name, value);
    }
}

function textResponse(text, status) {
    return new Response(text, {
        status,
        headers: {
            "content-type": "text/plain; charset=utf-8",
            "access-control-allow-origin": "*",
        },
    });
}
