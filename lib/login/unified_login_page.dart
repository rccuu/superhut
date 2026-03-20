import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:superhut/bridge/get_course_page.dart';
import 'package:superhut/core/services/app_logger.dart';
import 'package:superhut/generated/assets.dart';
import 'package:superhut/login/hut_cas_login_page.dart';
import 'package:superhut/login/webview_login_screen.dart';
import 'package:superhut/utils/hut_user_api.dart';

import '../core/services/app_auth_storage.dart';
import '../core/ui/apple_glass.dart';

class UnifiedLoginPage extends StatefulWidget {
  const UnifiedLoginPage({super.key});

  @override
  State<UnifiedLoginPage> createState() => _UnifiedLoginPageState();
}

class _UnifiedLoginPageState extends State<UnifiedLoginPage> {
  final TextEditingController _userNoController = TextEditingController();
  final TextEditingController _pwdController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    _userNoController.dispose();
    _pwdController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCredentials() async {
    final storage = AppAuthStorage.instance;
    final savedUser = await storage.readJwxtUsername();
    final savedPassword = await storage.readJwxtPassword();
    if (!mounted) {
      return;
    }

    _userNoController.text = savedUser;
    _pwdController.text = savedPassword;
  }

  void _showSnackBar(String message, {Color? backgroundColor}) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: backgroundColor),
    );
  }

  Future<bool> _tryOfficialJwxtLogin(String reason) async {
    _showSnackBar(reason);

    if (!mounted) {
      return false;
    }

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder:
            (context) => WebViewLoginScreen(
              userNo: _userNoController.text.trim(),
              password: _pwdController.text,
              showText: '正在通过教务系统官方页面登录...',
              renew: false,
            ),
      ),
    );
    return result == true;
  }

  Future<void> _loginWithCAS() async {
    final username = _userNoController.text.trim();
    final password = _pwdController.text;

    if (username.isEmpty || password.isEmpty) {
      _showSnackBar('请输入账号和密码');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final isLoginSuccess = await HutUserApi().userLogin(
        username: username,
        password: password,
      );
      if (!isLoginSuccess) {
        await _tryOfficialJwxtLogin('智慧工大接口登录失败，正在切换到教务系统官方登录...');
        return;
      }

      if (!mounted) {
        return;
      }

      final result = await HutCasTokenRetriever.getJwxtTokenAndCookie(context);
      if (result == null || (result['token'] ?? '').isEmpty) {
        await _tryOfficialJwxtLogin('统一认证未返回教务凭据，正在切换到教务系统官方登录...');
        return;
      }

      await AppAuthStorage.instance.setFirstOpen(false);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const Getcoursepage(renew: false),
        ),
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'Unified login failed unexpectedly',
        error: error,
        stackTrace: stackTrace,
      );
      await _tryOfficialJwxtLogin('登录过程异常，正在切换到教务系统官方登录...');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: AppGlassBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                24,
                20,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '超级包菜',
                            style: theme.textTheme.headlineLarge?.copyWith(
                              letterSpacing: -1.0,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '使用智慧工大账号继续，快速进入课表与校园服务。',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    GlassPanel(
                      blur: 24,
                      borderRadius: BorderRadius.circular(34),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '登录',
                                      style: theme.textTheme.headlineMedium,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '请使用智慧工大账号进行登录',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Opacity(
                                opacity: 0.92,
                                child: SvgPicture.asset(
                                  Assets.illustrationLogin,
                                  width: 92,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          TextField(
                            keyboardType: TextInputType.number,
                            style: theme.textTheme.titleMedium,
                            maxLength: 13,
                            decoration: const InputDecoration(
                              hintText: '手机号',
                              counterText: '',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                            controller: _userNoController,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            style: theme.textTheme.titleMedium,
                            maxLength: 40,
                            decoration: const InputDecoration(
                              hintText: '密码',
                              counterText: '',
                              prefixIcon: Icon(Icons.lock_outline_rounded),
                            ),
                            controller: _pwdController,
                            obscureText: true,
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _isLoading ? null : _loginWithCAS,
                              child:
                                  _isLoading
                                      ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : const Text('工大平台登录'),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            '若平台接口异常，将自动切换到教务系统官方登录。',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
