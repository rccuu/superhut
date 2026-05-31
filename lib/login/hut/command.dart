import 'package:flutter/material.dart';

import '../../core/ui/app_snack_bar.dart';
import '../../utils/hut_user_api.dart';

typedef HutLoginSubmitter =
    Future<bool> Function({required String username, required String password});

class HutLoginCommand {
  HutLoginCommand({HutLoginSubmitter? submitLogin})
    : _submitLogin =
          submitLogin ??
          (({required username, required password}) {
            return HutUserApi().userLogin(
              username: username,
              password: password,
            );
          });

  final HutLoginSubmitter _submitLogin;
  Future<void>? _loginSubmit;

  Future<void> loginToHuT(
    String username,
    String password,
    BuildContext context,
  ) {
    final inFlight = _loginSubmit;
    if (inFlight != null) {
      return inFlight;
    }

    late final Future<void> submit;
    submit = _runLoginSubmit(username, password, context, () => submit);
    _loginSubmit = submit;
    return submit;
  }

  Future<void> _runLoginSubmit(
    String username,
    String password,
    BuildContext context,
    Future<void> Function() currentSubmit,
  ) async {
    try {
      await _loginToHuT(username, password, context);
    } finally {
      if (identical(_loginSubmit, currentSubmit())) {
        _loginSubmit = null;
      }
    }
  }

  Future<void> _loginToHuT(
    String username,
    String password,
    BuildContext context,
  ) async {
    final value = await _submitLogin(username: username, password: password);
    if (!context.mounted) {
      return;
    }

    if (value) {
      showAppSnackBar(context, message: '登录成功', type: AppSnackBarType.success);
      Navigator.pop(context);
    } else {
      showAppSnackBar(context, message: '登录失败', type: AppSnackBarType.error);
    }
  }
}

final HutLoginCommand _defaultHutLoginCommand = HutLoginCommand();

Future<void> loginToHuT(
  String username,
  String password,
  BuildContext context,
) {
  return _defaultHutLoginCommand.loginToHuT(username, password, context);
}
