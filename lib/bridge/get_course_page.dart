import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:superhut/home/homeview/view.dart';

import '../utils/course/coursemain.dart';
import '../utils/token.dart';

class Getcoursepage extends StatefulWidget {
  final bool renew;

  const Getcoursepage({super.key, required this.renew});

  @override
  State<Getcoursepage> createState() => _GetcoursepageState();
}

class _GetcoursepageState extends State<Getcoursepage> {
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadClass();
  }

  Future<void> _loadClass() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final token = await getToken();
    if (!mounted) {
      return;
    }
    final result = await saveClassToLocal(token, context);
    if (!mounted) {
      return;
    }

    if (!result.success) {
      setState(() {
        _isLoading = false;
        _errorMessage = result.message;
      });
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(widget.renew ? '课表已刷新' : '课表已同步')));
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const HomeviewPage()),
      (route) => false,
    );
  }

  void _goToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const HomeviewPage()),
      (route) => false,
    );
  }

  Widget _buildErrorState(BuildContext context) {
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
            _errorMessage ?? '发生未知错误',
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
      body:
          _isLoading
              ? SizedBox(
                width: double.infinity,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    LoadingAnimationWidget.inkDrop(
                      color: Theme.of(context).primaryColor,
                      size: 40,
                    ),
                    const SizedBox(height: 16),
                    Text(widget.renew ? '正在刷新课表' : '正在同步课表'),
                    Text(widget.renew ? '正在获取最新课表数据' : '正在获取本地尚未同步的课表数据'),
                  ],
                ),
              )
              : _buildErrorState(context),
    );
  }
}
