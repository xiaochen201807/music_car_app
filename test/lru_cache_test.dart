import 'package:flutter_test/flutter_test.dart';
import 'package:music_car_app/services/lru_cache.dart';

void main() {
  test('LruCache evicts least recently used entries', () {
    final LruCache<String, int> cache = LruCache<String, int>(capacity: 2);
    cache.put('a', 1);
    cache.put('b', 2);
    expect(cache.get('a'), 1); // a becomes most recent
    cache.put('c', 3); // evicts b
    expect(cache.containsKey('b'), isFalse);
    expect(cache.get('a'), 1);
    expect(cache.get('c'), 3);
  });
}
