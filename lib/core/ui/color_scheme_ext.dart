import 'package:flutter/material.dart';

extension AppColorSchemeX on ColorScheme {
  bool get isDarkMode => brightness == Brightness.dark;

  Color get success =>
      isDarkMode ? const Color(0xFF79DBAE) : const Color(0xFF18794E);

  Color get successContainerSoft =>
      isDarkMode ? const Color(0xFF163726) : const Color(0xFFDDF4E5);

  Color get onSuccessContainerSoft =>
      isDarkMode ? const Color(0xFFE3F8EA) : const Color(0xFF10311F);

  Color get warning =>
      isDarkMode ? const Color(0xFFFFC98A) : const Color(0xFF9A5B00);

  Color get warningContainerSoft =>
      isDarkMode ? const Color(0xFF443116) : const Color(0xFFFFE5C5);

  Color get onWarningContainerSoft =>
      isDarkMode ? const Color(0xFFFFEBD2) : const Color(0xFF3A2500);

  Color get floatingSurface =>
      surface.withValues(alpha: isDarkMode ? 0.74 : 0.92);

  Color get floatingSurfaceStrong =>
      surfaceContainerHighest.withValues(alpha: isDarkMode ? 0.80 : 0.96);

  Color get overlayScrim =>
      Colors.black.withValues(alpha: isDarkMode ? 0.46 : 0.28);

  Color get overlayScrimStrong =>
      Colors.black.withValues(alpha: isDarkMode ? 0.72 : 0.56);

  Color get subtleBorder =>
      outlineVariant.withValues(alpha: isDarkMode ? 0.82 : 0.92);
}
