import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:superhut/core/services/app_logger.dart';
import 'package:superhut/generated/assets.dart';
import 'package:superhut/home/home_route.dart';
import 'package:superhut/login/hut/sms_command.dart';
import 'package:superhut/login/hut_cas_login_page.dart';
import 'package:superhut/login/hut_sms_login_enabled.dart';
import 'package:superhut/login/webview_login_screen.dart';
import 'package:superhut/utils/course/coursemain.dart';
import 'package:superhut/utils/hut_user_api.dart';

import '../core/services/app_auth_storage.dart';
import '../core/ui/app_loading_indicator.dart';
import '../core/ui/app_page_route.dart';
import '../core/ui/app_snack_bar.dart';
import '../core/ui/apple_glass.dart';

typedef UnifiedLoginHomeRouteBuilder = Route<void> Function({int initialIndex});
typedef UnifiedLoginAuthenticator =
    Future<bool> Function({required String username, required String password});
typedef UnifiedLoginJwxtCredentialLoader =
    Future<Map<String, String>?> Function(BuildContext context);
typedef UnifiedLoginSavedCredentialLoader =
    Future<({String username, String password})> Function();
typedef UnifiedLoginOfficialLoginOpener =
    Future<bool?> Function(
      BuildContext context, {
      required String username,
      required String password,
    });

enum _UnifiedLoginMode { password, sms }

class UnifiedLoginPage extends StatefulWidget {
  const UnifiedLoginPage({
    super.key,
    this.buildHomeRoute,
    this.loginWithHut,
    this.loadJwxtCredentials,
    this.loadSavedLoginCredentials,
    this.openOfficialLogin,
    this.smsCommand,
  });

  final UnifiedLoginHomeRouteBuilder? buildHomeRoute;
  final UnifiedLoginAuthenticator? loginWithHut;
  final UnifiedLoginJwxtCredentialLoader? loadJwxtCredentials;
  final UnifiedLoginSavedCredentialLoader? loadSavedLoginCredentials;
  final UnifiedLoginOfficialLoginOpener? openOfficialLogin;
  final HutSmsLoginCommand? smsCommand;

  static Route<bool?> route() {
    return buildAppPageRoute<bool?>(
      builder: (context) => const UnifiedLoginPage(),
      androidTransitionDuration: const Duration(milliseconds: 130),
      androidReverseTransitionDuration: const Duration(milliseconds: 110),
    );
  }

  @override
  State<UnifiedLoginPage> createState() => _UnifiedLoginPageState();
}

class _UnifiedLoginPageState extends State<UnifiedLoginPage> {
  final TextEditingController _userNoController = TextEditingController();
  final TextEditingController _pwdController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _smsCodeController = TextEditingController();
  final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier<bool>(false);

  late final HutSmsLoginCommand _smsCommand;
  _UnifiedLoginMode _mode = _UnifiedLoginMode.password;
  bool _mobilePrefillDone = false;
  bool _isOpeningOfficialLogin = false;
  bool _isContinuingAsGuest = false;

  bool get _isLoading => _isLoadingNotifier.value;
  bool get _smsModeEnabled => kHutSmsLoginEnabled;

  @override
  void initState() {
    super.initState();
    _smsCommand = widget.smsCommand ?? HutSmsLoginCommand();
    _smsCommand.onCountdownChanged = () {
      if (mounted) {
        setState(() {});
      }
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSavedCredentials();
      unawaited(_prefillMobile());
    });
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
    _isLoadingNotifier.dispose();
    _smsCommand.onCountdownChanged = null;
    _smsCommand.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCredentials() async {
    final initialUsername = _userNoController.text;
    final initialPassword = _pwdController.text;
    final ({String username, String password}) savedCredentials;
    try {
      savedCredentials = await _readSavedLoginCredentials();
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to load saved unified login credentials',
        error: error,
        stackTrace: stackTrace,
      );
      _showSnackBar('读取已保存账号失败，请手动输入', type: AppSnackBarType.warning);
      return;
    }
    if (!mounted) {
      return;
    }

    if (_userNoController.text == initialUsername &&
        savedCredentials.username.isNotEmpty) {
      _userNoController.text = savedCredentials.username;
    }
    if (_pwdController.text == initialPassword &&
        savedCredentials.password.isNotEmpty) {
      _pwdController.text = savedCredentials.password;
    }
  }

  Future<({String username, String password})>
  _readSavedLoginCredentials() async {
    final loader = widget.loadSavedLoginCredentials;
    if (loader != null) {
      return loader();
    }

    final storage = AppAuthStorage.instance;
    final savedUser = await storage.readJwxtUsername();
    final savedPassword = await storage.readJwxtPassword();
    return (username: savedUser, password: savedPassword);
  }

  void _showSnackBar(
    String message, {
    AppSnackBarType type = AppSnackBarType.info,
  }) {
    if (!mounted) {
      return;
    }

    showAppSnackBar(context, message: message, type: type);
  }

  void _setLoading(bool isLoading) {
    if (!mounted || _isLoading == isLoading) {
      return;
    }

    _isLoadingNotifier.value = isLoading;
  }

  void _finishLogin() {
    unawaited(ensureCourseScheduleFreshness());
    Navigator.of(
      context,
    ).pushAndRemoveUntil(_buildHomeRoute(initialIndex: 0), (route) => false);
  }

  Route<void> _buildHomeRoute({required int initialIndex}) {
    final builder = widget.buildHomeRoute ?? buildHomePageRoute;
    return builder(initialIndex: initialIndex);
  }

  Future<bool> _loginWithHut({
    required String username,
    required String password,
  }) {
    final login = widget.loginWithHut;
    if (login != null) {
      return login(username: username, password: password);
    }
    return HutUserApi().userLogin(username: username, password: password);
  }

  Future<HutAuthResult> _loginWithHutDetailed({
    required String username,
    required String password,
  }) {
    return HutUserApi().userLoginDetailed(
      username: username,
      password: password,
    );
  }

  Future<Map<String, String>?> _loadJwxtCredentials(BuildContext context) {
    final loader = widget.loadJwxtCredentials;
    if (loader != null) {
      return loader(context);
    }
    return HutCasTokenRetriever.getJwxtTokenAndCookie(context);
  }

  void _continueAsGuest() {
    if (_isContinuingAsGuest) {
      return;
    }

    _isContinuingAsGuest = true;
    try {
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop(false);
        return;
      }

      navigator.pushAndRemoveUntil(
        _buildHomeRoute(initialIndex: 1),
        (route) => false,
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to continue as guest',
        error: error,
        stackTrace: stackTrace,
      );
      _isContinuingAsGuest = false;
      _showSnackBar('无法进入游客模式，请稍后重试', type: AppSnackBarType.error);
    }
  }

  Future<bool> _tryOfficialJwxtLogin(String reason) async {
    if (_isOpeningOfficialLogin) {
      return false;
    }

    _isOpeningOfficialLogin = true;
    try {
      _showSnackBar(reason, type: AppSnackBarType.warning);

      if (!mounted) {
        return false;
      }

      final opener = widget.openOfficialLogin ?? _openOfficialLoginPage;
      final username =
          _mode == _UnifiedLoginMode.sms
              ? _mobileController.text.trim()
              : _userNoController.text.trim();
      final password =
          _mode == _UnifiedLoginMode.sms ? '' : _pwdController.text;
      final result = await opener(
        context,
        username: username,
        password: password,
      );
      return result == true;
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to open official JWXT login page',
        error: error,
        stackTrace: stackTrace,
      );
      _showSnackBar('无法打开教务系统官方登录页面，请稍后重试', type: AppSnackBarType.error);
      return false;
    } finally {
      _isOpeningOfficialLogin = false;
    }
  }

  Future<bool?> _openOfficialLoginPage(
    BuildContext context, {
    required String username,
    required String password,
  }) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder:
            (context) => WebViewLoginScreen(
              userNo: username,
              password: password,
              showText: '正在打开教务系统官方登录页面...',
              renew: false,
            ),
      ),
    );
  }

  Future<void> _completeAfterHutSuccess({
    required String username,
    required String password,
  }) async {
    if (!mounted) {
      return;
    }

    final result = await _loadJwxtCredentials(context);
    if (result == null || (result['token'] ?? '').isEmpty) {
      await _tryOfficialJwxtLogin('统一认证未返回教务凭据，正在切换到教务系统官方登录...');
      return;
    }

    await AppAuthStorage.instance.setFirstOpen(false);
    if (username.isNotEmpty && password.isNotEmpty) {
      await AppAuthStorage.instance.saveJwxtCredentials(
        username: username,
        password: password,
      );
    }

    if (!mounted) {
      return;
    }
    _finishLogin();
  }

  Future<void> _loginWithCAS() async {
    if (_isLoading) {
      return;
    }

    final username = _userNoController.text.trim();
    final password = _pwdController.text;

    if (username.isEmpty || password.isEmpty) {
      _showSnackBar('请输入学号/手机号和密码', type: AppSnackBarType.warning);
      return;
    }

    _setLoading(true);

    try {
      // Keep injected bool authenticator compatible; default path uses detailed.
      if (widget.loginWithHut != null) {
        final isLoginSuccess = await _loginWithHut(
          username: username,
          password: password,
        );
        if (!isLoginSuccess) {
          await _tryOfficialJwxtLogin('智慧工大登录失败，正在切换到教务系统官方登录...');
          return;
        }
      } else {
        final detailed = await _loginWithHutDetailed(
          username: username,
          password: password,
        );
        if (detailed.needMfa) {
          _showSnackBar(
            detailed.message.isNotEmpty ? detailed.message : '需要二次验证，请使用验证码登录',
            type: AppSnackBarType.warning,
          );
          return;
        }
        if (!detailed.success) {
          await _tryOfficialJwxtLogin('智慧工大登录失败，正在切换到教务系统官方登录...');
          return;
        }
      }

      await _completeAfterHutSuccess(username: username, password: password);
    } catch (error, stackTrace) {
      AppLogger.error(
        'Unified login failed unexpectedly',
        error: error,
        stackTrace: stackTrace,
      );
      await _tryOfficialJwxtLogin('登录过程异常，正在切换到教务系统官方登录...');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _requestSmsCode() async {
    if (_isLoading) {
      return;
    }

    final mobile = _mobileController.text.trim();
    if (mobile.isEmpty) {
      _showSnackBar('请输入手机号', type: AppSnackBarType.warning);
      return;
    }

    _setLoading(true);
    try {
      final result = await _smsCommand.requestCode(mobile);
      if (!mounted) {
        return;
      }
      if (result.success) {
        _showSnackBar(
          result.message.isEmpty ? '验证码已发送' : result.message,
          type: AppSnackBarType.success,
        );
      } else {
        _showSnackBar(
          result.message.isEmpty ? '获取验证码失败' : result.message,
          type: AppSnackBarType.error,
        );
      }
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _loginWithSms() async {
    if (_isLoading) {
      return;
    }

    final mobile = _mobileController.text.trim();
    final code = _smsCodeController.text.trim();
    if (mobile.isEmpty || code.isEmpty) {
      _showSnackBar('请输入手机号和验证码', type: AppSnackBarType.warning);
      return;
    }

    _setLoading(true);
    try {
      final result = await _smsCommand.login(mobile: mobile, smscode: code);
      if (!mounted) {
        return;
      }
      if (!result.success) {
        _showSnackBar(
          result.message.isEmpty ? '登录失败' : result.message,
          type: AppSnackBarType.error,
        );
        return;
      }

      await _completeAfterHutSuccess(username: mobile, password: '');
    } catch (error, stackTrace) {
      AppLogger.error(
        'Unified SMS login failed unexpectedly',
        error: error,
        stackTrace: stackTrace,
      );
      await _tryOfficialJwxtLogin('登录过程异常，正在切换到教务系统官方登录...');
    } finally {
      _setLoading(false);
    }
  }

  Widget _buildModeSwitcher(BuildContext context) {
    if (!_smsModeEnabled) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isPassword = _mode == _UnifiedLoginMode.password;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          TextButton(
            onPressed:
                isPassword
                    ? null
                    : () => setState(() => _mode = _UnifiedLoginMode.password),
            child: Text(
              '密码登录',
              style: TextStyle(
                fontWeight: isPassword ? FontWeight.bold : FontWeight.normal,
                color:
                    isPassword
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed:
                isPassword
                    ? () => setState(() => _mode = _UnifiedLoginMode.sms)
                    : null,
            child: Text(
              '验证码登录',
              style: TextStyle(
                fontWeight: !isPassword ? FontWeight.bold : FontWeight.normal,
                color:
                    !isPassword
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordFields(ThemeData theme) {
    return Column(
      children: [
        TextField(
          keyboardType: TextInputType.number,
          style: theme.textTheme.titleMedium,
          maxLength: 13,
          decoration: const InputDecoration(
            hintText: '学号 / 手机号',
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
      ],
    );
  }

  Widget _buildSmsFields(ThemeData theme) {
    final remaining = _smsCommand.remainingSeconds;
    final canRequest = remaining <= 0 && !_isLoading;

    return Column(
      children: [
        TextField(
          keyboardType: TextInputType.phone,
          style: theme.textTheme.titleMedium,
          maxLength: 13,
          decoration: const InputDecoration(
            hintText: '手机号',
            counterText: '',
            prefixIcon: Icon(Icons.phone_iphone_rounded),
          ),
          controller: _mobileController,
          onChanged: (_) {
            _mobilePrefillDone = true;
          },
        ),
        const SizedBox(height: 12),
        TextField(
          keyboardType: TextInputType.number,
          style: theme.textTheme.titleMedium,
          maxLength: 8,
          decoration: InputDecoration(
            hintText: '验证码',
            counterText: '',
            prefixIcon: const Icon(Icons.sms_outlined),
            suffixIcon: TextButton(
              onPressed: canRequest ? () => unawaited(_requestSmsCode()) : null,
              child: Text(remaining > 0 ? '${remaining}s' : '获取验证码'),
            ),
          ),
          controller: _smsCodeController,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final useLiteLayout = AppGlassPerformanceScope.shouldUseLiteLayoutOf(
      context,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: AppGlassBackground(
        style: AppGlassBackgroundStyle.soft,
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
                            '工大盒子',
                            style: theme.textTheme.headlineLarge?.copyWith(
                              letterSpacing: -1.0,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '登录后可按需同步课表；如果你只是想用慧生活798，也可以先不登录。',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    GlassPanel(
                      style: GlassPanelStyle.hero,
                      blur: useLiteLayout ? 0 : 24,
                      useBackdropFilter: !useLiteLayout,
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
                                      '支持智慧工大和教务系统账号登录',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              useLiteLayout
                                  ? GlassIconBadge(
                                    icon: Icons.login_rounded,
                                    tint: colorScheme.primary,
                                    size: 56,
                                  )
                                  : SvgPicture.asset(
                                    Assets.illustrationLogin,
                                    width: 92,
                                  ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          _buildModeSwitcher(context),
                          if (_mode == _UnifiedLoginMode.password)
                            _buildPasswordFields(theme)
                          else
                            _buildSmsFields(theme),
                          const SizedBox(height: 18),
                          ValueListenableBuilder<bool>(
                            valueListenable: _isLoadingNotifier,
                            builder: (context, isLoading, _) {
                              return Column(
                                children: [
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton(
                                      onPressed:
                                          isLoading
                                              ? null
                                              : () {
                                                if (_mode ==
                                                    _UnifiedLoginMode.sms) {
                                                  unawaited(_loginWithSms());
                                                } else {
                                                  unawaited(_loginWithCAS());
                                                }
                                              },
                                      child:
                                          isLoading
                                              ? const AppLoadingIndicator(
                                                size: 20,
                                                color: Colors.white,
                                              )
                                              : const Text('登录并继续'),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton(
                                      onPressed:
                                          isLoading ? null : _continueAsGuest,
                                      child: Text(
                                        Navigator.of(context).canPop()
                                            ? '暂不登录'
                                            : '先逛功能',
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 14),
                          Text(
                            '如智慧工大不可用，将自动切换到教务系统官方页面。课表同步改为在课表页手动触发。',
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
