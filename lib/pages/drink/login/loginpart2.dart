import 'package:flutter/material.dart';

import 'command.dart';
import 'widgets/login_widgets.dart';

class DrinkLoginPage2 extends StatefulWidget {
  final String phoneNumber;
  final String doubleRandom;
  final String timestamp;
  final String imageCode;

  const DrinkLoginPage2({
    super.key,
    required this.phoneNumber,
    required this.doubleRandom,
    required this.timestamp,
    required this.imageCode,
  });

  @override
  State<DrinkLoginPage2> createState() => _DrinkLoginPage2State();
}

class _DrinkLoginPage2State extends State<DrinkLoginPage2> {
  final TextEditingController _codeController = TextEditingController();
  final DrinkLoginCommand _command = DrinkLoginCommand();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    if (_codeController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入短信验证码')));
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _command.login(widget.phoneNumber, _codeController.text, context);
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DrinkLoginShell(
      headerTitle: '短信验证',
      headerSubtitle: '验证码已发送到 ${widget.phoneNumber}，输入后即可完成登录。',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DrinkLoginFieldLabel(label: '短信验证码'),
          const SizedBox(height: 8),
          DrinkLoginInputField(
            controller: _codeController,
            hintText: '请输入短信验证码',
            keyboardType: TextInputType.number,
            maxLength: 6,
            autofocus: true,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: 6,
              color: colorScheme.onSurface,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 18,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.maybePop(context),
              child: const Text('重新获取验证码'),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _isSubmitting ? null : _submitLogin,
              child:
                  _isSubmitting
                      ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                      : const Text(
                        '完成登录',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '若未收到短信，可返回上一页重新获取。',
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
