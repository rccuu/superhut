import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/utils/pwd.dart';

void main() {
  test('U keeps legacy object formatting while escaping unsafe keys', () {
    expect(
      U({
        'safeKey': 'value',
        'unsafe-key': ['x', 2],
        r'$ok': true,
        'space key': null,
      }),
      r'{safeKey: "value", "unsafe-key": {0: "x", 1: 2}, $ok: true, "space key": null}',
    );
  });

  test('encryptPassword keeps legacy AES output while padding short keys', () {
    expect(encryptPassword('password', sw), 'gd7BpphkXpEECSbjOASTxg==');
    expect(encryptPassword('password', 'short'), 'R7/tBP7TnmJVaQxy/74Xxg==');
  });
}
