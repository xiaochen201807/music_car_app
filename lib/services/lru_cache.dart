import 'dart:collection';

/// Tiny generic LRU map used for hot metadata (lyrics, resolved audio URLs).
///
/// Spotify-style transient caches: keep recently used entries, drop the rest
/// when capacity is exceeded. Not for durable offline downloads.
class LruCache<K, V> {
  LruCache({this.capacity = 64}) : assert(capacity > 0);

  final int capacity;
  final LinkedHashMap<K, V> _map = LinkedHashMap<K, V>();

  int get length => _map.length;

  Iterable<K> get keys => _map.keys;

  V? get(K key) {
    if (!_map.containsKey(key)) {
      return null;
    }
    final V value = _map.remove(key) as V;
    _map[key] = value;
    return value;
  }

  void put(K key, V value) {
    if (_map.containsKey(key)) {
      _map.remove(key);
    }
    _map[key] = value;
    while (_map.length > capacity) {
      _map.remove(_map.keys.first);
    }
  }

  bool containsKey(K key) => _map.containsKey(key);

  void remove(K key) {
    _map.remove(key);
  }

  void clear() {
    _map.clear();
  }
}
