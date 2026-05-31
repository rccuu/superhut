import 'package:flutter/material.dart';

import '../core/ui/app_loading_indicator.dart';
import '../core/ui/app_snack_bar.dart';
import '../home/home_route.dart';
import '../utils/course/coursemain.dart';
import '../utils/token.dart';

typedef CourseTokenLoader = Future<String> Function();

typedef CourseClassSaver =
    Future<CourseSyncResult> Function(String token, {BuildContext? context});

class Getcoursepage extends StatefulWidget {
  final bool renew;

  const Getcoursepage({
    super.key,
    required this.renew,
    this.loadToken,
    this.saveClass,
  });

  final CourseTokenLoader? loadToken;
  final CourseClassSaver? saveClass;

  @override
  State<Getcoursepage> createState() => _GetcoursepageState();
}

class _GetcoursepageState extends State<Getcoursepage> {
  final ValueNotifier<_CourseSyncPanelState> _panelState =
      ValueNotifier<_CourseSyncPanelState>(
        const _CourseSyncPanelState.loading(),
      );
  bool _isSyncInFlight = false;

  @override
  void initState() {
    super.initState();
    _loadClass();
  }

  @override
  void dispose() {
    _panelState.dispose();
    super.dispose();
  }

  Future<void> _loadClass() async {
    if (_isSyncInFlight) {
      return;
    }

    var didNavigate = false;
    _isSyncInFlight = true;
    _showLoadingIfNeeded();

    try {
      final token = await (widget.loadToken ?? getToken)();
      if (!mounted) {
        return;
      }
      final result = await (widget.saveClass ?? saveClassToLocal)(
        token,
        context: context,
      );
      if (!mounted) {
        return;
      }

      if (!result.success) {
        _showError(result.message);
        return;
      }

      showAppSnackBar(
        context,
        message: widget.renew ? '课表已刷新' : '课表已同步',
        type: AppSnackBarType.success,
      );
      didNavigate = true;
      Navigator.of(
        context,
      ).pushAndRemoveUntil(buildHomePageRoute(), (route) => false);
    } finally {
      _isSyncInFlight = false;
      if (!didNavigate) {
        _hideLoadingIfNeeded();
      }
    }
  }

  void _showLoadingIfNeeded() {
    if (!mounted || _panelState.value.isLoading) {
      return;
    }

    _panelState.value = const _CourseSyncPanelState.loading();
  }

  void _showError(String message) {
    final panelState = _panelState.value;
    if (!mounted ||
        (!panelState.isLoading && panelState.errorMessage == message)) {
      return;
    }

    _panelState.value = _CourseSyncPanelState.error(message);
  }

  void _hideLoadingIfNeeded() {
    if (!mounted || !_panelState.value.isLoading) {
      return;
    }

    _panelState.value = const _CourseSyncPanelState.error('发生未知错误');
  }

  void _goToHome() {
    Navigator.of(
      context,
    ).pushAndRemoveUntil(buildHomePageRoute(), (route) => false);
  }

  Widget _buildErrorState(BuildContext context, String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 56,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          const Text(
            '课表加载失败',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: _loadClass, child: const Text('重试')),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _goToHome,
              child: const Text('返回首页'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ValueListenableBuilder<_CourseSyncPanelState>(
        valueListenable: _panelState,
        builder: (context, panelState, _) {
          if (!panelState.isLoading) {
            return _buildErrorState(
              context,
              panelState.errorMessage ?? '发生未知错误',
            );
          }

          return SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppLoadingIndicator(
                  color: Theme.of(context).primaryColor,
                  size: 40,
                ),
                const SizedBox(height: 16),
                Text(widget.renew ? '正在刷新课表' : '正在同步课表'),
                Text(widget.renew ? '正在获取最新课表数据' : '正在获取本地尚未同步的课表数据'),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CourseSyncPanelState {
  const _CourseSyncPanelState._({
    required this.isLoading,
    required this.errorMessage,
  });

  const _CourseSyncPanelState.loading()
    : this._(isLoading: true, errorMessage: null);

  const _CourseSyncPanelState.error(String message)
    : this._(isLoading: false, errorMessage: message);

  final bool isLoading;
  final String? errorMessage;
}
