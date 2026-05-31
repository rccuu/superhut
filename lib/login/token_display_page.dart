// token_display_page.dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../home/home_route.dart';
import '../utils/token.dart';

typedef TokenDisplaySaver = Future<void> Function(String token);
typedef TokenDisplayHomeRouteBuilder = Route<void> Function({int initialIndex});

class TokenDisplayPage extends StatefulWidget {
  final String token;
  final bool renew;
  final TokenDisplaySaver? saveTokenOverride;
  final TokenDisplayHomeRouteBuilder? buildHomeRoute;

  const TokenDisplayPage({
    super.key,
    required this.token,
    required this.renew,
    this.saveTokenOverride,
    this.buildHomeRoute,
  });

  @override
  State<TokenDisplayPage> createState() => _TokenDisplayPageState();
}

class _TokenDisplayPageState extends State<TokenDisplayPage> {
  bool _hasScheduledHomeRedirect = false;

  @override
  void initState() {
    super.initState();
    unawaited(_saveTokenAndMaybeRedirect());
  }

  Future<void> _saveTokenAndMaybeRedirect() async {
    await (widget.saveTokenOverride ?? saveToken)(widget.token);
    if (widget.renew) {
      //  Navigator.pop(context,"200");
      return;
    }
    if (!mounted || _hasScheduledHomeRedirect) {
      return;
    }

    _hasScheduledHomeRedirect = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        (widget.buildHomeRoute ?? buildHomePageRoute)(initialIndex: 0),
        (route) => false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Token信息')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '获取到的Token:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(
                  widget.token,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
