import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:superhut/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'isFirstOpen': true});
  });

  testWidgets('shows onboarding on first launch', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('超级包菜'), findsOneWidget);
    expect(find.text('下一步'), findsOneWidget);
  });
}
