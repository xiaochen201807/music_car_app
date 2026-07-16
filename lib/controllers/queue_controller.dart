import 'dart:async';

import 'package:flutter/foundation.dart';

import '../free_music_api.dart';
import '../native_audio_controller.dart';
import '../utils/queue_entry_utils.dart';

class QueueSnapshot {
  const QueueSnapshot({
    required this.queue,
    required this.selectedIndex,
    required this.currentSong,
    required this.playbackMode,
  });

  final List<FreeMusicSong> queue;
  final int selectedIndex;
  final FreeMusicSong? currentSong;
  final NativePlaybackMode playbackMode;
}

class QueueRemovalResult {
  const QueueRemovalResult({
    required this.queue,
    required this.removedSong,
    required this.nextCurrentSong,
    required this.nextIndex,
  });

  final List<FreeMusicSong> queue;
  final FreeMusicSong removedSong;
  final FreeMusicSong nextCurrentSong;
  final int nextIndex;
}

class QueueReorderResult {
  const QueueReorderResult({
    required this.queue,
    required this.nextIndex,
    required this.currentSong,
  });

  final List<FreeMusicSong> queue;
  final int nextIndex;
  final FreeMusicSong? currentSong;
}

class QueueController extends ChangeNotifier {
  QueueController() : _idManager = QueueEntryIdManager();

  final QueueEntryIdManager _idManager;
  List<FreeMusicSong> _queue = const <FreeMusicSong>[];
  int _selectedIndex = 0;
  FreeMusicSong? _currentSong;
  NativePlaybackMode _playbackMode = NativePlaybackMode.repeatAll;
  Timer? _notifyTimer;

  @override
  void dispose() {
    _notifyTimer?.cancel();
    super.dispose();
  }

  void _notifyWithThrottle() {
    _notifyTimer?.cancel();
    // Coalesce bursty queue mutations into a single listener notify so the
    // shell does not rebuild thrice during a single skip / replace path.
    _notifyTimer = Timer(const Duration(milliseconds: 120), () {
      if (hasListeners) {
        notifyListeners();
      }
    });
  }

  List<FreeMusicSong> get queue => _queue;

  int get selectedIndex => _selectedIndex;

  FreeMusicSong? get currentSong => _currentSong;

  NativePlaybackMode get playbackMode => _playbackMode;

  bool get isEmpty => _queue.isEmpty;

  int get length => _queue.length;

  QueueSnapshot get snapshot {
    return QueueSnapshot(
      queue: _queue,
      selectedIndex: _selectedIndex,
      currentSong: _currentSong,
      playbackMode: _playbackMode,
    );
  }

  void setPlaybackMode(NativePlaybackMode mode) {
    if (_playbackMode == mode) {
      return;
    }
    _playbackMode = mode;
    _notifyWithThrottle();
  }

  bool isValidIndex(int index) {
    return index >= 0 && index < _queue.length;
  }

  bool isLastSong(FreeMusicSong song) {
    return _queue.isNotEmpty && _sameSong(_queue.last, song);
  }

  int indexOfSong(FreeMusicSong song) {
    return _queue.indexWhere((FreeMusicSong item) => _sameSong(item, song));
  }

  bool replace(List<FreeMusicSong> songs, int index) {
    if (index < 0 || index >= songs.length) {
      return false;
    }
    _queue = List<FreeMusicSong>.unmodifiable(_idManager.ensureIds(songs));
    _selectedIndex = index;
    _currentSong = _queue[index];
    _notifyWithThrottle();
    return true;
  }

  void restore(QueueSnapshot snapshot) {
    _queue = List<FreeMusicSong>.unmodifiable(snapshot.queue);
    _selectedIndex = snapshot.selectedIndex;
    _currentSong = snapshot.currentSong;
    _playbackMode = snapshot.playbackMode;
    _notifyWithThrottle();
  }

  bool appendToEnd(FreeMusicSong song) {
    final bool wasEmpty = _queue.isEmpty;
    final FreeMusicSong songWithId = _idManager.ensureId(song);
    _queue = List<FreeMusicSong>.unmodifiable(<FreeMusicSong>[
      ..._queue,
      songWithId,
    ]);
    if (wasEmpty) {
      _selectedIndex = 0;
      _currentSong = songWithId;
    }
    _notifyWithThrottle();
    return wasEmpty;
  }

  bool selectIndex(int index) {
    if (!isValidIndex(index)) {
      return false;
    }
    _selectedIndex = index;
    _currentSong = _queue[index];
    _notifyWithThrottle();
    return true;
  }

  bool syncCurrentFromExternalQueue(List<FreeMusicSong> queue, int index) {
    if (index < 0 || index >= queue.length) {
      return false;
    }
    _queue = List<FreeMusicSong>.unmodifiable(queue);
    _selectedIndex = index;
    _currentSong = _queue[index];
    _notifyWithThrottle();
    return true;
  }

  int selectedIndexForAppend() {
    if (_queue.isEmpty) {
      return 0;
    }
    return isValidIndex(_selectedIndex) ? _selectedIndex : 0;
  }

  bool reorder(int oldIndex, int newIndex) {
    final QueueReorderResult? result = previewReorder(oldIndex, newIndex);
    if (result == null) {
      return false;
    }
    _queue = result.queue;
    _selectedIndex = result.nextIndex;
    _currentSong = result.currentSong;
    _notifyWithThrottle();
    return true;
  }

  QueueReorderResult? previewReorder(int oldIndex, int newIndex) {
    if (_queue.isEmpty || !isValidIndex(oldIndex)) {
      return null;
    }
    final List<FreeMusicSong> list = List<FreeMusicSong>.from(_queue);
    int targetNewIndex = newIndex;
    if (oldIndex < newIndex) {
      targetNewIndex -= 1;
    }
    if (targetNewIndex < 0 || targetNewIndex > list.length - 1) {
      return null;
    }
    final FreeMusicSong song = list.removeAt(oldIndex);
    list.insert(targetNewIndex, song);

    int nextIndex = _selectedIndex;
    if (_selectedIndex == oldIndex) {
      nextIndex = targetNewIndex;
    } else if (oldIndex < _selectedIndex && targetNewIndex >= _selectedIndex) {
      nextIndex -= 1;
    } else if (oldIndex > _selectedIndex && targetNewIndex <= _selectedIndex) {
      nextIndex += 1;
    }

    final List<FreeMusicSong> nextQueue = List<FreeMusicSong>.unmodifiable(
      list,
    );
    return QueueReorderResult(
      queue: nextQueue,
      nextIndex: nextIndex,
      currentSong: nextIndex >= 0 && nextIndex < nextQueue.length
          ? nextQueue[nextIndex]
          : _currentSong,
    );
  }

  QueueRemovalResult? removeAt(int index) {
    final QueueRemovalResult? result = previewRemoveAt(index);
    if (result == null) {
      return null;
    }
    _queue = result.queue;
    _selectedIndex = result.nextIndex;
    _currentSong = result.nextCurrentSong;
    _notifyWithThrottle();
    return result;
  }

  QueueRemovalResult? previewRemoveAt(int index) {
    if (!isValidIndex(index) || _queue.length <= 1) {
      return null;
    }
    final List<FreeMusicSong> list = List<FreeMusicSong>.from(_queue);
    final FreeMusicSong removedSong = list.removeAt(index);
    int nextIndex = _selectedIndex;
    if (_selectedIndex == index) {
      nextIndex = index < list.length ? index : 0;
    } else if (index < _selectedIndex) {
      nextIndex -= 1;
    }

    final FreeMusicSong nextCurrentSong = list[nextIndex];
    return QueueRemovalResult(
      queue: List<FreeMusicSong>.unmodifiable(list),
      removedSong: removedSong,
      nextCurrentSong: nextCurrentSong,
      nextIndex: nextIndex,
    );
  }
}

bool _sameSong(FreeMusicSong left, FreeMusicSong right) {
  return left.id == right.id && left.source == right.source;
}
