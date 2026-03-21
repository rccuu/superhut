import 'package:enhanced_future_builder/enhanced_future_builder.dart';
import 'package:flutter/material.dart';

import 'command.dart';
import 'widgets/login_widgets.dart';

class DrinkLoginPage extends StatefulWidget {
  const DrinkLoginPage({super.key});

  @override
  State<DrinkLoginPage> createState() => _DrinkLoginPageState();
}

class _DrinkLoginPageState extends State<DrinkLoginPage> {
  final TextEditingController _userNoController = TextEditingController();
  final TextEditingController _captchaController = TextEditingController();
  final DrinkLoginCommand _command = DrinkLoginCommand();
  bool _isSending = false;

  @override
  void dispose() {
    _userNoController.dispose();
    _captchaController.dispose();
    _command.dispose();
    super.dispose();
  }

  void _refreshCaptcha() {
    setState(_command.dispose);
  }

  Future<void> _sendMessageCode() async {
    if (_userNoController.text.isEmpty || _captchaController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入手机号和图形验证码')));
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      await _command.sendMessageCode(
        context,
        _userNoController.text,
        _captchaController.text,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DrinkLoginShell(
      headerTitle: '慧生活798',
      headerSubtitle: '宿舍饮水服务登录，验证手机号后即可开始使用。',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DrinkLoginFieldLabel(label: '手机号'),
          const SizedBox(height: 8),
          DrinkLoginInputField(
            controller: _userNoController,
            hintText: '请输入手机号',
            keyboardType: TextInputType.phone,
            maxLength: 13,
            prefixIcon: Icons.phone_iphone_rounded,
          ),
          const SizedBox(height: 14),
          const DrinkLoginFieldLabel(label: '图形验证码'),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _refreshCaptcha,
            child: Container(
              width: double.infinity,
              height: 74,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.8),
                ),
              ),
              child: EnhancedFutureBuilder(
                future: _command.getImageCaptcha(),
                rememberFutureResult: true,
                whenDone: (snapshot) {
                  if (snapshot.isNotEmpty) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.memory(snapshot, fit: BoxFit.contain),
                    );
                  }

                  return _CaptchaPlaceholder(onRefresh: _refreshCaptcha);
                },
                whenNotDone: _CaptchaPlaceholder(onRefresh: _refreshCaptcha),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _refreshCaptcha,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('看不清？点击刷新'),
            ),
          ),
          const SizedBox(height: 4),
          DrinkLoginInputField(
            controller: _captchaController,
            hintText: '请输入上方验证码',
            maxLength: 6,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: 4,
              color: colorScheme.onSurface,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _isSending ? null : _sendMessageCode,
              child:
                  _isSending
                      ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                      : const Text(
                        '发送验证码',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '仅用于本次慧生活798登录验证。',
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _CaptchaPlaceholder extends StatelessWidget {
  const _CaptchaPlaceholder({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '正在加载验证码',
            style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          TextButton(onPressed: onRefresh, child: const Text('重新加载')),
        ],
      ),
    );
  }
}
