import 'package:flutter/material.dart';

import '../core/ui/app_page_route.dart';
import 'homeview/view.dart';

Route<void> buildHomePageRoute({int initialIndex = 0}) {
  return buildAppPageRoute<void>(
    builder: (_) => HomeviewPage(initialIndex: initialIndex),
  );
}
