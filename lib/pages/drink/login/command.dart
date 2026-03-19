import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:superhut/pages/drink/api/drink_api.dart';

import 'loginpart2.dart';

class DrinkLoginCommand {
  static final DrinkLoginCommand _instance = DrinkLoginCommand._internal();
  factory DrinkLoginCommand() => _instance;

  DrinkLoginCommand._internal() {
    _reset();
  }

  final DrinkApi api = DrinkApi();
  String _doubleRandom = "0";
  String _timestamp = "";
  bool _first = true;

  void _reset() {
    _doubleRandom = "0";
    _timestamp = DateTime.timestamp().millisecondsSinceEpoch.toString();
    _first = true;
  }

  Future<Uint8List> getImageCaptcha() async {
    if (_first) {
      _doubleRandom = Random().nextDouble().toString();
      final Uint8List data = await api.userCaptcha(
        doubleRandom: _doubleRandom,
        timestamp: _timestamp,
      );
      _first = false;
      return data;
    }
    return Uint8List(0);
  }

  void to2Login(BuildContext context, String phoneNumber, String imageCode) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => DrinkLoginPage2(
              phoneNumber: phoneNumber,
              doubleRandom: _doubleRandom,
              timestamp: _timestamp,
              imageCode: imageCode,
            ),
      ),
    );
  }

  Future<void> sendMessageCode(
    BuildContext context,
    String phoneNumber,
    String imageCode,
  ) async {
    final bool value = await api.userMessageCode(
      doubleRandom: _doubleRandom,
      photoCode: imageCode,
      phone: phoneNumber,
    );
    if (!context.mounted) {
      return;
    }

    if (value) {
      to2Login(context, phoneNumber, imageCode);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('验证码错误')));
    }
  }

  Future<void> login(
    String phoneNumber,
    String code,
    BuildContext context,
  ) async {
    final bool value = await api.userLogin(
      phone: phoneNumber,
      messageCode: code,
    );
    if (!context.mounted) {
      return;
    }

    if (value) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('成功')));
      Navigator.pop(context);
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('登录失败')));
    }
  }

  // 清理方法，在页面销毁时调用
  void dispose() {
    _reset();
  }
}
