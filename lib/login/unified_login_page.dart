import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:superhut/bridge/get_course_page.dart';
import 'package:superhut/core/services/app_logger.dart';
import 'package:superhut/generated/assets.dart';
import 'package:superhut/login/hut_cas_login_page.dart';
import 'package:superhut/login/webview_login_screen.dart';
import 'package:superhut/utils/hut_user_api.dart';

import '../core/services/app_auth_storage.dart';

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
    return Scaffold(
      backgroundColor: Theme.of(context).cardColor,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // 顶部背景
          Container(
            width: double.infinity,
            height: 400,
            color: Theme.of(context).secondaryHeaderColor,
            padding: const EdgeInsets.only(top: 200, right: 20, left: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "欢迎~",
                  style: TextStyle(
                    fontSize: 35,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                Text(
                  "选择登录方式",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
          ),

          // 主内容
          MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: ListView(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 200),
                  child: Stack(
                    children: [
                      // 登录卡片
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
                            // 标题
                            Text(
                              "登录",
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                            const SizedBox(height: 20),

                            Column(
                              children: [
                                // 账号输入框
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.fromLTRB(
                                    10,
                                    0,
                                    10,
                                    0,
                                  ),
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
                                      hintText: "手机号",
                                      border: InputBorder.none,
                                      counterText: '',
                                    ),
                                    controller: _userNoController,
                                  ),
                                ),
                                const SizedBox(height: 10),

                                // 密码输入框
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.fromLTRB(
                                    10,
                                    0,
                                    10,
                                    0,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(15),
                                    color: Theme.of(context).highlightColor,
                                  ),
                                  child: TextField(
                                    style: const TextStyle(fontSize: 18),
                                    maxLength: 40,
                                    decoration: const InputDecoration(
                                      filled: false,
                                      hintText: "密码",
                                      border: InputBorder.none,
                                      counterText: '',
                                    ),
                                    controller: _pwdController,
                                    obscureText: true,
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // 登录按钮
                                Row(
                                  children: [
                                    /*
                                    Expanded(
                                      child: FilledButton(
                                        onPressed: _loginWithCredentials,
                                        child: const Text('教务系统登录'),
                                      ),
                                    ),
                                    const SizedBox(width: 10),


                                     */
                                    Expanded(
                                      child: FilledButton(
                                        onPressed: _loginWithCAS,
                                        style: FilledButton.styleFrom(
                                          backgroundColor: Colors.orangeAccent,
                                        ),
                                        child:
                                            _isLoading
                                                ? const SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                        color: Colors.white,
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                                : const Text('工大平台登录'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Text(
                              '请使用智慧工大账号进行登录',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),

                      // 右上角装饰图标
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
    );
  }
}
