const String playerProbeHandlerName = 'musicPlayerProbe';

const String playerProbeScriptSource = r'''
(function() {
  if (window.__musicCarPlayerProbeInstalled) {
    return;
  }
  window.__musicCarPlayerProbeInstalled = true;

  var lastSignature = '';
  var lastSentAt = 0;
  var pendingPayloads = [];

  function getAudioNodes() {
    return Array.prototype.slice.call(document.querySelectorAll('audio'));
  }

  function textFromSelectors(selectors) {
    for (var i = 0; i < selectors.length; i += 1) {
      var node = document.querySelector(selectors[i]);
      if (!node) {
        continue;
      }
      var text = (node.getAttribute('title') || node.textContent || '').trim();
      if (text) {
        return text;
      }
    }
    return '';
  }

  function imageFromSelectors(selectors) {
    for (var i = 0; i < selectors.length; i += 1) {
      var node = document.querySelector(selectors[i]);
      if (!node) {
        continue;
      }
      var value = node.currentSrc || node.src || node.getAttribute('src') || '';
      if (value) {
        return value;
      }
    }
    return '';
  }

  function normalizeUrl(value) {
    if (!value) {
      return '';
    }
    try {
      return new URL(value, window.location.href).href;
    } catch (error) {
      return String(value);
    }
  }

  function collectAudio() {
    var audio = getAudioNodes()[0];
    if (!audio) {
      return null;
    }
    var source = audio.currentSrc || audio.src || '';
    if (!source) {
      var sourceNode = audio.querySelector('source[src]');
      source = sourceNode ? sourceNode.getAttribute('src') || '' : '';
    }
    return {
      audioUrl: normalizeUrl(source),
      currentTime: Number.isFinite(audio.currentTime) ? audio.currentTime : 0,
      duration: Number.isFinite(audio.duration) ? audio.duration : 0,
      paused: audio.paused,
      ended: audio.ended,
      muted: audio.muted,
      volume: audio.volume,
      readyState: audio.readyState,
      networkState: audio.networkState
    };
  }

  function localStorageValue(key) {
    try {
      return window.localStorage.getItem(key) || '';
    } catch (error) {
      return '';
    }
  }

  function currentPlaylistState() {
    try {
      var raw = window.localStorage.getItem('fm_player_playlist');
      if (!raw) {
        return { playlist: [], currentIndex: -1, song: null };
      }
      var state = JSON.parse(raw);
      var playlist = Array.isArray(state.playlist) ? state.playlist : [];
      var index = Number.isFinite(state.current_index) ? state.current_index : -1;
      var song = index >= 0 && index < playlist.length ? playlist[index] : null;
      return {
        playlist: playlist.filter(function(item) {
          return item && typeof item === 'object';
        }),
        currentIndex: index,
        song: song && typeof song === 'object' ? song : null
      };
    } catch (error) {
      return { playlist: [], currentIndex: -1, song: null };
    }
  }

  function collectPayload(reason) {
    var audioState = collectAudio() || {};
    var playlistState = currentPlaylistState();
    var song = playlistState.song || {};
    var audioNodes = getAudioNodes();
    return {
      reason: reason,
      href: window.location.href,
      id: song.id || '',
      source: song.source || '',
      title: textFromSelectors([
        '[data-testid*="title" i]',
        '[class*="song" i][class*="name" i]',
        '[class*="music" i][class*="name" i]',
        '[class*="track" i][class*="title" i]',
        '.aplayer-title',
        '.song-name',
        '.music-name',
        '.track-title'
      ]) || song.name || '',
      artist: textFromSelectors([
        '[data-testid*="artist" i]',
        '[class*="artist" i]',
        '[class*="singer" i]',
        '.aplayer-author',
        '.song-artist',
        '.music-artist'
      ]) || song.artist || '',
      coverUrl: normalizeUrl(imageFromSelectors([
        '[class*="cover" i] img',
        '[class*="album" i] img',
        '.aplayer-pic img',
        'img[alt*="cover" i]'
      ]) || song.cover || '',
      audioUrl: audioState.audioUrl || '',
      currentTime: audioState.currentTime || 0,
      duration: audioState.duration || song.duration || 0,
      playlist: playlistState.playlist,
      currentIndex: playlistState.currentIndex,
      playing: audioState.paused === false && audioState.ended !== true,
      muted: audioState.muted === true,
      volume: typeof audioState.volume === 'number' ? audioState.volume : null,
      readyState: audioState.readyState,
      networkState: audioState.networkState,
      diagnostic: {
        audioCount: audioNodes.length,
        hasFlutterBridge: !!(window.flutter_inappwebview && typeof window.flutter_inappwebview.callHandler === 'function'),
        hasPlaylistStorage: !!localStorageValue('fm_player_playlist'),
        playlistLength: playlistState.playlist.length,
        currentIndex: playlistState.currentIndex,
        firstAudioSrc: audioNodes[0] ? normalizeUrl(audioNodes[0].src || '') : '',
        firstAudioCurrentSrc: audioNodes[0] ? normalizeUrl(audioNodes[0].currentSrc || '') : '',
        readyState: audioState.readyState,
        networkState: audioState.networkState,
        documentReadyState: document.readyState
      },
      observedAt: new Date().toISOString()
    };
  }

  function sendPayload(payload) {
    var bridge = window.flutter_inappwebview;
    if (bridge && typeof bridge.callHandler === 'function') {
      bridge.callHandler('musicPlayerProbe', payload);
      return true;
    }
    pendingPayloads.push(payload);
    if (pendingPayloads.length > 8) {
      pendingPayloads.shift();
    }
    window.__musicCarLastPlayerProbe = payload;
    return false;
  }

  function flushPending() {
    if (!pendingPayloads.length) {
      return false;
    }
    var bridge = window.flutter_inappwebview;
    if (!bridge || typeof bridge.callHandler !== 'function') {
      return false;
    }
    while (pendingPayloads.length) {
      bridge.callHandler('musicPlayerProbe', pendingPayloads.shift());
    }
    return true;
  }

  function send(reason, force) {
    if (reason === 'audio:pause' && Date.now() < (window.__musicCarSuppressPauseUntil || 0)) {
      return null;
    }
    var payload = collectPayload(reason);
    var signature = [
      payload.title,
      payload.artist,
      payload.coverUrl,
      payload.audioUrl,
      payload.playing,
      payload.currentIndex,
      payload.playlist.length,
      Math.floor(payload.currentTime)
    ].join('|');
    var now = Date.now();
    if (!force && signature === lastSignature && now - lastSentAt < 1200) {
      return payload;
    }
    lastSignature = signature;
    lastSentAt = now;

    if (flushPending()) {
      payload.diagnostic.flushedPending = true;
    }
    sendPayload(payload);
    return payload;
  }

  window.__musicCarCollectPlayerPayload = function(reason) {
    return send(reason || 'flutter:pull', true);
  };

  window.__musicCarFlushPlayerProbe = function() {
    if (flushPending()) {
      return true;
    }
    return !!send('flutter:flush', true);
  };

  window.__musicCarPlayerProbeStatus = function() {
    var payload = collectPayload('flutter:status');
    return {
      installed: true,
      pending: pendingPayloads.length,
      diagnostic: payload.diagnostic,
      title: payload.title,
      artist: payload.artist,
      audioUrl: payload.audioUrl,
      playlistLength: payload.playlist.length,
      currentIndex: payload.currentIndex
    };
  };

  function sendConsoleProbe(reason) {
    var payload = collectPayload(reason);
    try {
      console.info('[music-car-probe]', JSON.stringify({
        reason: reason,
        audio: payload.diagnostic.audioCount,
        queue: payload.diagnostic.playlistLength,
        index: payload.currentIndex,
        bridge: payload.diagnostic.hasFlutterBridge,
        url: payload.audioUrl || payload.diagnostic.firstAudioCurrentSrc || payload.diagnostic.firstAudioSrc,
        title: payload.title
      }));
    } catch (error) {
      console.info('[music-car-probe]', reason);
    }
    return payload;
  }

  function sendInstalled() {
    var payload = sendConsoleProbe('probe:installed');
    sendPayload(payload);
  }

  function bindAudio(audio) {
    if (!audio || audio.__musicCarProbeBound) {
      return;
    }
    audio.__musicCarProbeBound = true;
    [
      'loadstart',
      'loadedmetadata',
      'canplay',
      'play',
      'pause',
      'ended',
      'durationchange',
      'volumechange',
      'timeupdate'
    ].forEach(function(eventName) {
      audio.addEventListener(eventName, function() {
        send('audio:' + eventName, eventName !== 'timeupdate');
      }, true);
    });
  }

  function scan(reason) {
    getAudioNodes().forEach(bindAudio);
    send(reason, false);
  }

  var observer = new MutationObserver(function() {
    scan('dom:mutation');
  });

  function start() {
    sendInstalled();
    scan('probe:start');
    observer.observe(document.documentElement || document.body, {
      childList: true,
      subtree: true,
      attributes: true,
      attributeFilter: ['src', 'title', 'class', 'style']
    });
    window.setInterval(function() {
      flushPending();
      scan('probe:interval');
    }, 2000);
    window.setInterval(function() {
      send('probe:diagnostic', true);
    }, 5000);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', start, { once: true });
  } else {
    start();
  }
})();
''';
