import 'package:flutter/material.dart';

import '../../../core/ui/app_loading_indicator.dart';
import '../../../core/ui/app_snack_bar.dart';
import 'command.dart';
import 'widgets/login_widgets.dart';

class DrinkLoginPage2 extends StatefulWidget {
  final String phoneNumber;
  final String doubleRandom;
  final String timestamp;
  final String imageCode;
  final DrinkLoginCommand? command;

  const DrinkLoginPage2({
    super.key,
    required this.phoneNumber,
    required this.doubleRandom,
    required this.timestamp,
    required this.imageCode,
    this.command,
  });

  @override
  State<DrinkLoginPage2> createState() => _DrinkLoginPage2State();
}

class _DrinkLoginPage2State extends State<DrinkLoginPage2> {
  final TextEditingController _codeController = TextEditingController();
  final ValueNotifier<bool> _isSubmitting = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isReturningForCode = ValueNotifier<bool>(false);
  late final DrinkLoginCommand _command;
  late final bool _ownsCommand;

  @override
  void initState() {
    super.initState();
    _command = widget.command ?? DrinkLoginCommand();
    _ownsCommand = widget.command == null;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _isSubmitting.dispose();
    _isReturningForCode.dispose();
    if (_ownsCommand) {
      _command.dispose();
    }
    super.dispose();
  }

  Future<void> _submitLogin() async {
    if (_isSubmitting.value) {
      return;
    }

    if (_codeController.text.isEmpty) {
      showAppSnackBar(
        context,
        message: '请输入短信验证码',
        type: AppSnackBarType.warning,
      );
      return;
    }

    _setSubmitting(true);

    try {
      await _command.login(widget.phoneNumber, _codeController.text, context);
    } finally {
      _setSubmitting(false);
    }
  }

  Future<void> _returnForCode() async {
    if (_isReturningForCode.value) {
      return;
    }

    _setReturningForCode(true);
    final didPop = await Navigator.maybePop(context);
    if (!didPop) {
      _setReturningForCode(false);
    }
  }

  void _setSubmitting(bool isSubmitting) {
    if (!mounted || _isSubmitting.value == isSubmitting) {
      return;
    }

    _isSubmitting.value = isSubmitting;
  }

  void _setReturningForCode(bool isReturningForCode) {
    if (!mounted || _isReturningForCode.value == isReturningForCode) {
      return;
    }

    _isReturningForCode.value = isReturningForCode;
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
            child: ValueListenableBuilder<bool>(
              valueListenable: _isReturningForCode,
              child: const Text('重新获取验证码'),
              builder: (context, isReturningForCode, label) {
                return TextButton(
                  onPressed: isReturningForCode ? null : _returnForCode,
                  child: label!,
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ValueListenableBuilder<bool>(
              valueListenable: _isSubmitting,
              child: const Text(
                '完成登录',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              builder: (context, isSubmitting, label) {
                return FilledButton(
                  onPressed: isSubmitting ? null : _submitLogin,
                  child:
                      isSubmitting
                          ? const AppLoadingIndicator(
                            size: 22,
                            color: Colors.white,
                          )
                          : label,
                );
              },
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
