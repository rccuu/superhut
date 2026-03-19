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
  @override
  void initState() {
    super.initState();
    _jumpToScorePage();
  }

  Future<void> _jumpToScorePage() async {
    final navigator = Navigator.of(context);
    await renewToken(context);
    if (!mounted) {
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
      body: Center(
        child: LoadingAnimationWidget.inkDrop(
          color: Theme.of(context).primaryColor,
          size: 40,
        ),
      ),
    );
  }
}
