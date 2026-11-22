import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/utils/hut_user_api.dart';

void main() {
  test('stores and returns a value within the ttl', () {
    var now = DateTime(2026, 11, 22, 12);
    final cache = ExpiringValueCache<String>(ttl: const Duration(minutes: 10), now: () => now);

    expect(cache.readValid(), isNull);

    cache.store('session');
    expect(cache.readValid(), 'session');

    now = now.add(const Duration(minutes: 9));
    expect(cache.readValid(), 'session');
  });

  test('expires values older than the ttl', () {
    var now = DateTime(2026, 11, 22, 12);
    final cache = ExpiringValueCache<String>(ttl: const Duration(minutes: 10), now: () => now);

    cache.store('session');
    now = now.add(const Duration(minutes: 10));
    expect(cache.readValid(), isNull);
  });

  test('invalidate drops the value immediately', () {
    final cache = ExpiringValueCache<String>(now: () => DateTime(2026, 11, 22, 12));
    cache.store('session');
    cache.invalidate();
    expect(cache.readValid(), isNull);
  });

  test('overwriting a value refreshes its timestamp', () {
    var now = DateTime(2026, 11, 22, 12);
    final cache = ExpiringValueCache<String>(ttl: const Duration(minutes: 10), now: () => now);

    cache.store('old');
    now = now.add(const Duration(minutes: 8));
    cache.store('new');
    now = now.add(const Duration(minutes: 8));
    expect(cache.readValid(), 'new');
  });
}
