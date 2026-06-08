const String playerProbeHandlerName = 'musicPlayerProbe';

const String playerProbeScriptSource = r'''
(function() {
  if (window.__musicCarPlayerProbeInstalled) {
    return;
  }
  window.__musicCarPlayerProbeInstalled = true;

  var lastSignature = '';
  var lastSentAt = 0;

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
    var audio = document.querySelector('audio');
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

  function currentPlaylistSong() {
    try {
      var raw = window.localStorage.getItem('fm_player_playlist');
      if (!raw) {
        return null;
      }
      var state = JSON.parse(raw);
      var playlist = Array.isArray(state.playlist) ? state.playlist : [];
      var index = Number.isFinite(state.current_index) ? state.current_index : -1;
      if (index < 0 || index >= playlist.length) {
        return null;
      }
      var song = playlist[index];
      return song && typeof song === 'object' ? song : null;
    } catch (error) {
      return null;
    }
  }

  function collectPayload(reason) {
    var audioState = collectAudio() || {};
    var song = currentPlaylistSong() || {};
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
      playing: audioState.paused === false && audioState.ended !== true,
      muted: audioState.muted === true,
      volume: typeof audioState.volume === 'number' ? audioState.volume : null,
      readyState: audioState.readyState,
      networkState: audioState.networkState,
      observedAt: new Date().toISOString()
    };
  }

  function send(reason, force) {
    if (reason === 'audio:pause' && Date.now() < (window.__musicCarSuppressPauseUntil || 0)) {
      return;
    }
    var payload = collectPayload(reason);
    var signature = [
      payload.title,
      payload.artist,
      payload.coverUrl,
      payload.audioUrl,
      payload.playing,
      Math.floor(payload.currentTime)
    ].join('|');
    var now = Date.now();
    if (!force && signature === lastSignature && now - lastSentAt < 1200) {
      return;
    }
    lastSignature = signature;
    lastSentAt = now;

    var bridge = window.flutter_inappwebview;
    if (bridge && typeof bridge.callHandler === 'function') {
      bridge.callHandler('musicPlayerProbe', payload);
    } else {
      window.__musicCarLastPlayerProbe = payload;
    }
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
    document.querySelectorAll('audio').forEach(bindAudio);
    send(reason, false);
  }

  var observer = new MutationObserver(function() {
    scan('dom:mutation');
  });

  function start() {
    scan('probe:start');
    observer.observe(document.documentElement || document.body, {
      childList: true,
      subtree: true,
      attributes: true,
      attributeFilter: ['src', 'title', 'class', 'style']
    });
    window.setInterval(function() {
      scan('probe:interval');
    }, 2000);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', start, { once: true });
  } else {
    start();
  }
})();
''';
