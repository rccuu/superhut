import 'dart:convert';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as encrypt;

// 密钥
final String sw = "qzkj1kjghd=876&*";
final RegExp _unsafeObjectKeyPattern = RegExp(r'[^\w$]');

// 模拟 U 函数
String U(dynamic data) {
  if (data is Map) {
    final result = <String>[];
    for (final entry in data.entries) {
      final key = entry.key;
      final value = entry.value;
      String processedKey;
      if (key is String && _unsafeObjectKeyPattern.hasMatch(key)) {
        processedKey = jsonEncode(key);
      } else {
        processedKey = key.toString();
      }
      result.add('$processedKey: ${U(value)}');
    }
    return "{${result.join(", ")}}";
  } else if (data is List) {
    final result = <String>[];
    for (int i = 0; i < data.length; i++) {
      result.add('$i: ${U(data[i])}');
    }
    return "{${result.join(", ")}}";
  } else if (data is String) {
    return jsonEncode(data);
  } else if (data is num) {
    return data.toString();
  } else if (data is bool) {
    return data ? 'true' : 'false';
  } else if (data == null) {
    return 'null';
  } else {
    return jsonEncode(data);
  }
}

// 加密函数
String encryptPassword(String password, String key) {
  // 处理密钥
  final sourceKeyBytes = utf8.encode(key);
  final keyBytes = Uint8List(16);
  final copyLength =
      sourceKeyBytes.length < keyBytes.length
          ? sourceKeyBytes.length
          : keyBytes.length;
  for (var index = 0; index < copyLength; index++) {
    keyBytes[index] = sourceKeyBytes[index];
  }
  final encryptKey = encrypt.Key(keyBytes);

  // 处理密码
  final processedPassword = U(password);

  // 创建加密器
  final aes = encrypt.Encrypter(
    encrypt.AES(encryptKey, mode: encrypt.AESMode.ecb, padding: 'PKCS7'),
  );

  // 加密数据
  final encrypted = aes.encryptBytes(
    utf8.encode(processedPassword),
    iv: encrypt.IV.fromLength(16),
  );

  // 修正这里：添加.bytes获取实际字节
  return base64Encode(encrypted.bytes);
}
