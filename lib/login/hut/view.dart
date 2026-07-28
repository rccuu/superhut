import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../generated/assets.dart';
import '../../core/services/app_auth_storage.dart';
import '../../core/ui/app_snack_bar.dart';
import '../hut_sms_login_enabled.dart';
import 'command.dart';
import 'sms_command.dart';

enum _HutLoginMode { password, sms }

class HutLoginPage extends StatefulWidget {
  const HutLoginPage({super.key, this.command, this.smsCommand});

  final HutLoginCommand? command;
  final HutSmsLoginCommand? smsCommand;

  @override
  State<HutLoginPage> createState() => _HutLoginPageState();
}

class _HutLoginPageState extends State<HutLoginPage> {
  final TextEditingController _userNoController = TextEditingController();
  final TextEditingController _pwdController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _smsCodeController = TextEditingController();

  late final HutLoginCommand _command;
  late final HutSmsLoginCommand _smsCommand;

  _HutLoginMode _mode = _HutLoginMode.password;
  bool _mobilePrefillDone = false;
  bool _smsBusy = false;

  @override
  void initState() {
    super.initState();
    _command = widget.command ?? HutLoginCommand();
    _smsCommand = widget.smsCommand ?? HutSmsLoginCommand();
    _smsCommand.onCountdownChanged = () {
      if (mounted) {
        setState(() {});
      }
    };
    unawaited(_prefillMobile());
  }

  Future<void> _prefillMobile() async {
    final mobile = await AppAuthStorage.instance.readHutMobile();
    if (!mounted || mobile.isEmpty || _mobilePrefillDone) {
      return;
    }
    if (_mobileController.text.isEmpty) {
      _mobileController.text = mobile;
    }
    _mobilePrefillDone = true;
  }

  @override
  void dispose() {
    _userNoController.dispose();
    _pwdController.dispose();
    _mobileController.dispose();
    _smsCodeController.dispose();
    _smsCommand.onCountdownChanged = null;
    _smsCommand.dispose();
    super.dispose();
  }

  Future<void> _requestSmsCode() async {
    final mobile = _mobileController.text.trim();
    if (mobile.isEmpty) {
      showAppSnackBar(
        context,
        message: '请输入手机号',
        type: AppSnackBarType.warning,
      );
      return;
    }

    setState(() => _smsBusy = true);
    try {
      final result = await _smsCommand.requestCode(mobile);
      if (!mounted) {
        return;
      }
      if (result.success) {
        showAppSnackBar(
          context,
          message: result.message.isEmpty ? '验证码已发送' : result.message,
          type: AppSnackBarType.success,
        );
      } else {
        showAppSnackBar(
          context,
          message: result.message.isEmpty ? '获取验证码失败' : result.message,
          type: AppSnackBarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _smsBusy = false);
      }
    }
  }

  Future<void> _loginWithSms() async {
    final mobile = _mobileController.text.trim();
    final code = _smsCodeController.text.trim();
    if (mobile.isEmpty || code.isEmpty) {
      showAppSnackBar(
        context,
        message: '请输入手机号和验证码',
        type: AppSnackBarType.warning,
      );
      return;
    }

    setState(() => _smsBusy = true);
    try {
      final result = await _smsCommand.login(mobile: mobile, smscode: code);
      if (!mounted) {
        return;
      }
      if (result.success) {
        showAppSnackBar(
          context,
          message: '登录成功',
          type: AppSnackBarType.success,
        );
        Navigator.pop(context);
      } else {
        showAppSnackBar(
          context,
          message: result.message.isEmpty ? '登录失败' : result.message,
          type: AppSnackBarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _smsBusy = false);
      }
    }
  }

  Widget _buildModeSwitcher(BuildContext context) {
    if (!kHutSmsLoginEnabled) {
      return const SizedBox.shrink();
    }

    final isPassword = _mode == _HutLoginMode.password;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          TextButton(
            onPressed: isPassword
                ? null
                : () => setState(() => _mode = _HutLoginMode.password),
            child: Text(
              '密码登录',
              style: TextStyle(
                fontWeight: isPassword ? FontWeight.bold : FontWeight.normal,
                color: isPassword
                    ? Theme.of(context).primaryColor
                    : Theme.of(context).hintColor,
              ),
            ),
          ),
          TextButton(
            onPressed: isPassword
                ? () => setState(() => _mode = _HutLoginMode.sms)
                : null,
            child: Text(
              '验证码登录',
              style: TextStyle(
                fontWeight: !isPassword ? FontWeight.bold : FontWeight.normal,
                color: !isPassword
                    ? Theme.of(context).primaryColor
                    : Theme.of(context).hintColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 400,
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            color: Theme.of(context).highlightColor,
          ),
          child: TextField(
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 18),
            maxLength: 13,
            decoration: const InputDecoration(
              filled: false,
              hintText: '学号/手机号',
              border: InputBorder.none,
              counterText: '',
            ),
            controller: _userNoController,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: 400,
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            color: Theme.of(context).highlightColor,
          ),
          child: Flex(
            direction: Axis.horizontal,
            children: [
              Expanded(
                child: TextField(
                  style: const TextStyle(fontSize: 18),
                  maxLength: 40,
                  decoration: const InputDecoration(
                    filled: false,
                    hintText: '密码',
                    border: InputBorder.none,
                    counterText: '',
                  ),
                  controller: _pwdController,
                  obscureText: false,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Flex(
          direction: Axis.horizontal,
          children: [
            Expanded(
              child: FilledButton(
                onPressed: () {
                  if (_userNoController.text.isEmpty ||
                      _pwdController.text.isEmpty) {
                    showAppSnackBar(
                      context,
                      message: '请输入学号/手机号和密码',
                      type: AppSnackBarType.warning,
                    );
                    return;
                  }
                  unawaited(
                    _command.loginToHuT(
                      _userNoController.text,
                      _pwdController.text,
                      context,
                    ),
                  );
                },
                child: const Text('登录并继续'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSmsForm(BuildContext context) {
    final remaining = _smsCommand.remainingSeconds;
    final canRequest = remaining <= 0 && !_smsBusy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 400,
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            color: Theme.of(context).highlightColor,
          ),
          child: TextField(
            keyboardType: TextInputType.phone,
            style: const TextStyle(fontSize: 18),
            maxLength: 13,
            decoration: const InputDecoration(
              filled: false,
              hintText: '手机号',
              border: InputBorder.none,
              counterText: '',
            ),
            controller: _mobileController,
            onChanged: (_) {
              _mobilePrefillDone = true;
            },
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: 400,
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            color: Theme.of(context).highlightColor,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 18),
                  maxLength: 8,
                  decoration: const InputDecoration(
                    filled: false,
                    hintText: '验证码',
                    border: InputBorder.none,
                    counterText: '',
                  ),
                  controller: _smsCodeController,
                ),
              ),
              TextButton(
                onPressed: canRequest ? () => unawaited(_requestSmsCode()) : null,
                child: Text(remaining > 0 ? '${remaining}s' : '获取验证码'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Flex(
          direction: Axis.horizontal,
          children: [
            Expanded(
              child: FilledButton(
                onPressed: _smsBusy ? null : () => unawaited(_loginWithSms()),
                child: const Text('登录并继续'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).cardColor,
      resizeToAvoidBottomInset: true,
      body: Padding(
        padding: const EdgeInsets.all(0),
        child: Stack(
          children: [
            Container(
              width: 1000,
              height: 400,
              color: Theme.of(context).secondaryHeaderColor,
              padding: const EdgeInsets.only(top: 200, right: 20, left: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '智慧工大登录',
                    style: TextStyle(
                      fontSize: 35,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  Text(
                    '使用智慧工大账号继续',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: ListView(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 200),
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20),
                            ),
                          ),
                          margin: const EdgeInsets.only(top: 100),
                          padding: const EdgeInsets.only(
                            top: 40,
                            right: 20,
                            left: 20,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '账号登录',
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _buildModeSwitcher(context),
                              if (_mode == _HutLoginMode.password)
                                _buildPasswordForm(context)
                              else
                                _buildSmsForm(context),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.only(right: 20),
                          alignment: Alignment.topRight,
                          margin: const EdgeInsets.only(top: 0),
                          child: SvgPicture.asset(
                            Assets.illustrationLogin,
                            width: 150,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
