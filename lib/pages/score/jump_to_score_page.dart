import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:superhut/pages/score/scorepage.dart';

import '../../utils/token.dart';

class JumpToScorePage extends StatefulWidget {
  const JumpToScorePage({super.key});

  @override
  State<JumpToScorePage> createState() => _JumpToScorePageState();
}

class _JumpToScorePageState extends State<JumpToScorePage> {
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _jumpToScorePage();
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _jumpToScorePage() async {
    final navigator = Navigator.of(context);
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    final renewed = await renewToken(context);
    if (!mounted) {
      return;
    }
    if (!renewed) {
      setState(() {
        _isLoading = false;
        _errorMessage = '成绩页暂时无法打开，请重新登录后重试';
      });
      _showSnackBar('成绩页登录状态已失效，请重新登录后重试');
      return;
    }

    navigator.pushReplacement(
      MaterialPageRoute(builder: (context) => const ScorePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("正在跳转")),
      body:
          _isLoading
              ? Center(
                child: LoadingAnimationWidget.inkDrop(
                  color: Theme.of(context).primaryColor,
                  size: 40,
                ),
              )
              : Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_errorMessage ?? '成绩页暂时无法打开'),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _jumpToScorePage,
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}
