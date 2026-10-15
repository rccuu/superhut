import 'package:enhanced_future_builder/enhanced_future_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/widgets/app_form_fields.dart';
import '../../../core/ui/app_loading_indicator.dart';
import '../../../core/ui/app_snack_bar.dart';
import '../core/drink_home_tokens.dart';
import 'command.dart';

/// 798 登录页：单一浅色表面 + 顶部品牌带，手机号与短信码在同一页面内切换。
class DrinkLoginPage extends StatefulWidget {
  const DrinkLoginPage({super.key, this.command});

  final DrinkLoginCommand? command;

  static const double bandHeight = 168;
  static const double captchaImageWidth = 104;
  static const double captchaImageHeight = 52;

  @override
  State<DrinkLoginPage> createState() => _DrinkLoginPageState();
}

class _DrinkLoginPageState extends State<DrinkLoginPage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _captchaController = TextEditingController();
  final TextEditingController _smsCodeController = TextEditingController();
  late final DrinkLoginCommand _command;
  late final bool _ownsCommand;
  late final ValueNotifier<Future<Uint8List>> _captchaFutureNotifier;
  final ValueNotifier<bool> _isSending = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isSubmitting = ValueNotifier<bool>(false);
  bool _isCaptchaLoading = false;

  @override
  void initState() {
    super.initState();
    _command = widget.command ?? DrinkLoginCommand();
    _ownsCommand = widget.command == null;
    _captchaFutureNotifier = ValueNotifier<Future<Uint8List>>(_loadCaptcha());
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _captchaController.dispose();
    _smsCodeController.dispose();
    _captchaFutureNotifier.dispose();
    _isSending.dispose();
    _isSubmitting.dispose();
    if (_ownsCommand) {
      _command.dispose();
    }
    super.dispose();
  }

  Future<Uint8List> _loadCaptcha() async {
    _isCaptchaLoading = true;
    try {
      return await _command.getImageCaptcha();
    } finally {
      _isCaptchaLoading = false;
    }
  }

  void _refreshCaptcha() {
    if (_isCaptchaLoading) {
      return;
    }

    _command.resetCaptcha();
    _captchaFutureNotifier.value = _loadCaptcha();
  }

  Future<void> _sendMessageCode() async {
    if (_isSending.value) {
      return;
    }

    if (_phoneController.text.isEmpty || _captchaController.text.isEmpty) {
      showAppSnackBar(
        context,
        message: '请输入手机号和图形验证码',
        type: AppSnackBarType.warning,
      );
      return;
    }

    _setSending(_isSending, true);
    try {
      await _command.sendMessageCode(
        context,
        _phoneController.text,
        _captchaController.text,
      );
    } finally {
      _setSending(_isSending, false);
    }
  }

  Future<void> _submitLogin() async {
    if (_isSubmitting.value) {
      return;
    }

    if (_smsCodeController.text.isEmpty) {
      showAppSnackBar(
        context,
        message: '请输入短信验证码',
        type: AppSnackBarType.warning,
      );
      return;
    }

    _setSending(_isSubmitting, true);
    try {
      await _command.login(
        _command.submittedPhone.value,
        _smsCodeController.text,
        context,
      );
    } finally {
      _setSending(_isSubmitting, false);
    }
  }

  void _backToPhoneStep() {
    _command.resetToFirstStep();
    _refreshCaptcha();
  }

  void _setSending(ValueNotifier<bool> notifier, bool value) {
    if (!mounted || notifier.value == value) {
      return;
    }

    notifier.value = value;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scaffoldColor = theme.scaffoldBackgroundColor;

    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: DrinkLoginPage.bandHeight,
            child: DecoratedBox(
              key: const Key('loginBrandBand'),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    DrinkBrand.primary.withValues(alpha: 0.16),
                    scaffoldColor.withValues(alpha: 0),
                  ],
                ),
              ),
              child: const SizedBox.expand(),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const _DrinkLoginHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: ValueListenableBuilder<DrinkLoginStep>(
                      valueListenable: _command.step,
                      builder: (context, step, _) {
                        return switch (step) {
                          DrinkLoginStep.phone => _DrinkPhoneForm(
                            phoneController: _phoneController,
                            captchaController: _captchaController,
                            captchaFutureNotifier: _captchaFutureNotifier,
                            isSending: _isSending,
                            onRefreshCaptcha: _refreshCaptcha,
                            onSubmit: _sendMessageCode,
                          ),
                          DrinkLoginStep.sms => _DrinkSmsCodeForm(
                            smsCodeController: _smsCodeController,
                            submittedPhone: _command.submittedPhone,
                            isSubmitting: _isSubmitting,
                            onBack: _backToPhoneStep,
                            onSubmit: _submitLogin,
                          ),
                        };
                      },
                    ),
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

/// 顶部标题区压在渐隐带上，因此颜色必须走主题而不是硬编码白色。
class _DrinkLoginHeader extends StatelessWidget {
  const _DrinkLoginHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Row(
        children: [
          DecoratedBox(
            key: const Key('loginHeaderIconChip'),
            decoration: BoxDecoration(
              color: DrinkBrand.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Padding(
              padding: EdgeInsets.all(10),
              child: Icon(
                Icons.water_drop_rounded,
                color: DrinkBrand.primary,
                size: 28,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '慧生活798',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  '宿舍饮水服务，验证手机号后即可开始使用',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
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

class _DrinkPhoneForm extends StatelessWidget {
  const _DrinkPhoneForm({
    required this.phoneController,
    required this.captchaController,
    required this.captchaFutureNotifier,
    required this.isSending,
    required this.onRefreshCaptcha,
    required this.onSubmit,
  });

  final TextEditingController phoneController;
  final TextEditingController captchaController;
  final ValueNotifier<Future<Uint8List>> captchaFutureNotifier;
  final ValueNotifier<bool> isSending;
  final VoidCallback onRefreshCaptcha;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '登录',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '请输入手机号和图形验证码',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        AppTextField(
          key: const Key('phoneField'),
          controller: phoneController,
          label: '手机号',
          hintText: '请输入手机号',
          keyboardType: TextInputType.phone,
          maxLength: 11,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        _DrinkCaptchaRow(
          captchaController: captchaController,
          captchaFutureNotifier: captchaFutureNotifier,
          onRefreshCaptcha: onRefreshCaptcha,
        ),
        const SizedBox(height: 24),
        ValueListenableBuilder<bool>(
          valueListenable: isSending,
          builder: (context, isSending, _) {
            return AppPrimaryButton(
              onPressed: onSubmit,
              loading: isSending,
              child: const Text('获取验证码'),
            );
          },
        ),
        const SizedBox(height: 12),
        Text(
          '仅用于本次慧生活798登录验证。',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// 图形验证码：输入框与图片同行，图片高度由输入框约束，点击即换图。
class _DrinkCaptchaRow extends StatelessWidget {
  const _DrinkCaptchaRow({
    required this.captchaController,
    required this.captchaFutureNotifier,
    required this.onRefreshCaptcha,
  });

  final TextEditingController captchaController;
  final ValueNotifier<Future<Uint8List>> captchaFutureNotifier;
  final VoidCallback onRefreshCaptcha;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppFieldLabel('图形验证码'),
        const SizedBox(height: AppTextField.labelGap),
        Row(
          // 居中对齐让图片与输入框的中线严格重合；用 end 对齐时这个结论
          // 依赖字体度量，换字体就会悄悄偏移。
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: AppTextField(
                key: const Key('captchaField'),
                controller: captchaController,
                hintText: '请输入验证码',
                keyboardType: TextInputType.number,
                // 官方验证码以 5 位数字为主，这里保留 6 位余量，不做截断。
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textInputAction: TextInputAction.done,
                textAlign: TextAlign.center,
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 4,
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              key: const Key('captchaImage'),
              behavior: HitTestBehavior.opaque,
              onTap: onRefreshCaptcha,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(
                    AppTextField.cornerRadius,
                  ),
                  border: Border.all(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.38),
                  ),
                ),
                child: SizedBox(
                  width: DrinkLoginPage.captchaImageWidth,
                  height: DrinkLoginPage.captchaImageHeight,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Center(
                        child: ValueListenableBuilder<Future<Uint8List>>(
                          valueListenable: captchaFutureNotifier,
                          builder: (context, captchaFuture, _) {
                            return EnhancedFutureBuilder<Uint8List>(
                              future: captchaFuture,
                              rememberFutureResult: false,
                              whenDone: (snapshot) {
                                if (snapshot.isEmpty) {
                                  return const _DrinkCaptchaRefreshGlyph();
                                }
                                return Image.memory(
                                  snapshot,
                                  fit: BoxFit.contain,
                                );
                              },
                              whenError:
                                  (_) => const _DrinkCaptchaRefreshGlyph(),
                              whenNotDone: AppLoadingIndicator(
                                size: 18,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            );
                          },
                        ),
                      ),
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: Icon(
                          Icons.refresh_rounded,
                          size: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DrinkCaptchaRefreshGlyph extends StatelessWidget {
  const _DrinkCaptchaRefreshGlyph();

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.refresh_rounded,
      size: 20,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }
}

class _DrinkSmsCodeForm extends StatelessWidget {
  const _DrinkSmsCodeForm({
    required this.smsCodeController,
    required this.submittedPhone,
    required this.isSubmitting,
    required this.onBack,
    required this.onSubmit,
  });

  final TextEditingController smsCodeController;
  final ValueNotifier<String> submittedPhone;
  final ValueNotifier<bool> isSubmitting;
  final VoidCallback onBack;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DrinkBackButton(key: const Key('backFromSms'), onPressed: onBack),
        const SizedBox(height: 16),
        Text(
          '输入验证码',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        ValueListenableBuilder<String>(
          valueListenable: submittedPhone,
          builder: (context, phone, _) {
            return Text(
              '验证码已发送至 $phone',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        AppTextField(
          key: const Key('smsField'),
          controller: smsCodeController,
          label: '短信验证码',
          hintText: '______',
          keyboardType: TextInputType.number,
          maxLength: 6,
          autofocus: true,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textInputAction: TextInputAction.done,
          textAlign: TextAlign.center,
          textStyle: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 8,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '没有收到？',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            TextButton(onPressed: onBack, child: const Text('重新获取')),
          ],
        ),
        const SizedBox(height: 20),
        ValueListenableBuilder<bool>(
          valueListenable: isSubmitting,
          builder: (context, isSubmitting, _) {
            return AppPrimaryButton(
              onPressed: onSubmit,
              loading: isSubmitting,
              child: const Text('登录'),
            );
          },
        ),
      ],
    );
  }
}

class _DrinkBackButton extends StatelessWidget {
  const _DrinkBackButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return IconButton(
      onPressed: onPressed,
      tooltip: '返回上一步',
      style: IconButton.styleFrom(
        backgroundColor: colorScheme.onSurface.withValues(alpha: 0.06),
        foregroundColor: colorScheme.onSurface,
      ),
      icon: const Icon(Icons.arrow_back_rounded),
    );
  }
}
