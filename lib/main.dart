import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:superhut/pages/score/jump_to_score_page.dart';
import 'home/homeview/view.dart';
import 'core/services/app_auth_storage.dart';
import 'login/unified_login_page.dart';
import 'pages/drink/view/view.dart';
import 'pages/water/view.dart';
import 'pages/Electricitybill/electricity_page.dart';

abstract final class AppTheme {
  static const Color _brandBlue = Color(0xFF3B6EEA);
  static const Color _brandTeal = Color(0xFF3E9D97);
  static const Color _brandAmber = Color(0xFFE59A56);

  static final ColorScheme _lightScheme = ColorScheme.fromSeed(
    seedColor: _brandBlue,
    brightness: Brightness.light,
    primary: _brandBlue,
    secondary: _brandTeal,
    tertiary: _brandAmber,
    surface: const Color(0xFFF5F7FC),
  ).copyWith(
    primaryContainer: const Color(0xFFDFE8FF),
    secondaryContainer: const Color(0xFFDDF5F0),
    tertiaryContainer: const Color(0xFFFFE7CF),
    surfaceContainerLow: const Color(0xFFF8FAFE),
    surfaceContainerHigh: const Color(0xFFF1F4FB),
    outlineVariant: const Color(0xFFD9E1EE),
    shadow: const Color(0x1F16233C),
    surfaceTint: Colors.transparent,
  );

  static final ColorScheme _darkScheme = ColorScheme.fromSeed(
    seedColor: _brandBlue,
    brightness: Brightness.dark,
    primary: const Color(0xFFA9C1FF),
    secondary: const Color(0xFF89D8D0),
    tertiary: const Color(0xFFFFC88E),
    surface: const Color(0xFF0B111A),
  ).copyWith(
    primaryContainer: const Color(0xFF183161),
    secondaryContainer: const Color(0xFF163A38),
    tertiaryContainer: const Color(0xFF4E3317),
    surfaceContainerLow: const Color(0xFF111927),
    surfaceContainerHigh: const Color(0xFF182132),
    outlineVariant: const Color(0xFF2D3A4F),
    shadow: const Color(0x66000000),
    surfaceTint: Colors.transparent,
  );

  static ThemeData light = _buildTheme(_lightScheme);
  static ThemeData dark = _buildTheme(_darkScheme);

  static ThemeData _buildTheme(ColorScheme colorScheme) {
    final base = ThemeData(
      brightness: colorScheme.brightness,
      useMaterial3: true,
      colorScheme: colorScheme,
      cupertinoOverrideTheme: const CupertinoThemeData(applyThemeToAll: true),
      visualDensity: VisualDensity.standard,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
    final textTheme = _buildTextTheme(base.textTheme, colorScheme);
    final isDark = colorScheme.brightness == Brightness.dark;

    return base.copyWith(
      scaffoldBackgroundColor: colorScheme.surface,
      canvasColor: colorScheme.surface,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface.withValues(alpha: isDark ? 0.62 : 0.82),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shadowColor: colorScheme.shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.7),
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withValues(alpha: 0.72),
        thickness: 1,
        space: 1,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: colorScheme.surfaceContainerHighest,
        secondarySelectedColor: colorScheme.primaryContainer,
        selectedColor: colorScheme.primaryContainer,
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.8),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        labelStyle: textTheme.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.surfaceContainerHighest,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurface,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surface.withValues(alpha: isDark ? 0.18 : 0.72),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        prefixIconColor: colorScheme.primary,
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: textTheme.labelLarge,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.9),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.primary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface.withValues(
          alpha: isDark ? 0.92 : 0.96,
        ),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface.withValues(
          alpha: isDark ? 0.96 : 0.98,
        ),
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
    );
  }

  static TextTheme _buildTextTheme(TextTheme base, ColorScheme colorScheme) {
    return base
        .copyWith(
          displaySmall: base.displaySmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -1.2,
          ),
          headlineLarge: base.headlineLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.9,
          ),
          headlineMedium: base.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
          ),
          titleLarge: base.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
          titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          bodyLarge: base.bodyLarge?.copyWith(height: 1.4),
          bodyMedium: base.bodyMedium?.copyWith(height: 1.35),
        )
        .apply(
          bodyColor: colorScheme.onSurface,
          displayColor: colorScheme.onSurface,
        );
  }
}

WebViewEnvironment? webViewEnvironment;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
    final availableVersion = await WebViewEnvironment.getAvailableVersion();
    assert(
      availableVersion != null,
      'Failed to find an installed WebView2 Runtime or non-stable Microsoft Edge installation.',
    );

    webViewEnvironment = await WebViewEnvironment.create(
      settings: WebViewEnvironmentSettings(userDataFolder: 'YOUR_CUSTOM_PATH'),
    );
  }

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await InAppWebViewController.setWebContentsDebuggingEnabled(kDebugMode);
  }
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, // 全局状态栏颜色
      statusBarIconBrightness: Brightness.dark, // 图标颜色（根据背景调整）
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _hasSession = false;
  bool _isLoading = true;
  static const platform = MethodChannel(
    'com.superhut.rice.superhut/widget_actions',
  );
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _resolveStartupState();
    _setupWidgetActionHandler();
  }

  void _setupWidgetActionHandler() {
    platform.setMethodCallHandler((call) async {
      if (call.method == 'navigateToFunction') {
        final actionType = call.arguments as String;
        _handleWidgetAction(actionType);
      }
    });
  }

  void _handleWidgetAction(String actionType) {
    // 等待应用完全加载后再导航
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = navigatorKey.currentContext;
      if (context != null) {
        Widget? targetPage;

        switch (actionType) {
          case 'drink':
            targetPage = FunctionDrinkPage();
            break;
          case 'bath':
            targetPage = FunctionHotWaterPage();
            break;
          case 'electricity':
            targetPage = ElectricityPage();
            break;
          case 'score':
            targetPage = JumpToScorePage();
            break;
        }

        if (targetPage != null) {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (context) => targetPage!));
        }
      }
    });
  }

  Future<void> _resolveStartupState() async {
    final storage = AppAuthStorage.instance;
    final loginType = await storage.readLoginType();
    final jwxtToken = await storage.readJwxtToken();
    final hutToken = await storage.readHutToken();

    final hasSession = switch (loginType) {
      'jwxt' => jwxtToken.isNotEmpty,
      'hut' => hutToken.isNotEmpty || jwxtToken.isNotEmpty,
      _ => jwxtToken.isNotEmpty || hutToken.isNotEmpty,
    };
    if (!mounted) {
      return;
    }
    setState(() {
      _hasSession = hasSession;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
      locale: const Locale('zh', 'CN'),
      title: '超级包菜',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: _hasSession ? const HomeviewPage() : const UnifiedLoginPage(),
      builder: (context, child) {
        return ResponsiveBreakpoints.builder(
          breakpoints: [
            const Breakpoint(start: 0, end: 800, name: MOBILE),
            const Breakpoint(start: 801, end: 1920, name: DESKTOP),
            const Breakpoint(start: 1921, end: double.infinity, name: '4K'),
          ],
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
