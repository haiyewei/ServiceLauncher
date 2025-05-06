import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;

class ThemeManager extends ChangeNotifier {
  static const String _primaryColorKey = 'primary_color';
  static const String _darkModeKey = 'dark_mode';
  static const String _followSystemKey = 'follow_system';
  static const String _fixedSidebarKey = 'fixed_sidebar';
  static const String _minimizeToTrayKey = 'minimize_to_tray';
  static const String _askOnCloseKey = 'ask_on_close';
  static const String _successColorKey = 'success_color';
  static const String _warningColorKey = 'warning_color';
  static const String _infoColorKey = 'info_color';
  static const String _useMaterial3Key = 'use_material3';

  static const Color _defaultColor = Colors.blue;
  static const Color _defaultSuccessColor = Color(0xFF4CAF50); // 默认成功色：绿色
  static const Color _defaultWarningColor = Color(0xFFFF9800); // 默认警告色：橙色
  static const Color _defaultInfoColor = Color(0xFF2196F3); // 默认信息色：蓝色

  Color _primaryColor = _defaultColor;
  Color _successColor = _defaultSuccessColor;
  Color _warningColor = _defaultWarningColor;
  Color _infoColor = _defaultInfoColor;
  bool _isDarkMode = false;
  bool _followSystem = true;
  bool _fixedSidebar = true; // 默认桌面端侧边栏固定
  bool _minimizeToTray = false; // 默认不在后台运行
  bool _askOnClose = true; // 新增：默认在关闭时询问
  bool _useMaterial3 = true; // 默认使用Material Design 3

  Color get primaryColor => _primaryColor;
  Color get successColor => _successColor;
  Color get warningColor => _warningColor;
  Color get infoColor => _infoColor;
  bool get isDarkMode => _isDarkMode;
  bool get followSystem => _followSystem;
  bool get fixedSidebar => _fixedSidebar;
  bool get minimizeToTray => _minimizeToTray;
  bool get askOnClose => _askOnClose; // 新增：获取询问设置
  bool get useMaterial3 => _useMaterial3; // 获取是否使用Material Design 3

  ThemeManager() {
    loadSettings();
  }

  // 加载保存的设置
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final primaryColorValue = prefs.getInt(_primaryColorKey);
    final successColorValue = prefs.getInt(_successColorKey);
    final warningColorValue = prefs.getInt(_warningColorKey);
    final infoColorValue = prefs.getInt(_infoColorKey);
    final isDarkMode = prefs.getBool(_darkModeKey);
    final followSystem = prefs.getBool(_followSystemKey);
    final fixedSidebar = prefs.getBool(_fixedSidebarKey);
    final minimizeToTray = prefs.getBool(_minimizeToTrayKey);
    final askOnClose = prefs.getBool(_askOnCloseKey);
    final useMaterial3 = prefs.getBool(_useMaterial3Key);

    if (primaryColorValue != null) {
      _primaryColor = Color(primaryColorValue);
    }

    if (successColorValue != null) {
      _successColor = Color(successColorValue);
    }

    if (warningColorValue != null) {
      _warningColor = Color(warningColorValue);
    }

    if (infoColorValue != null) {
      _infoColor = Color(infoColorValue);
    }

    if (isDarkMode != null) {
      _isDarkMode = isDarkMode;
    }

    if (followSystem != null) {
      _followSystem = followSystem;
    }

    if (fixedSidebar != null) {
      _fixedSidebar = fixedSidebar;
    }

    if (minimizeToTray != null) {
      _minimizeToTray = minimizeToTray;
    }

    if (askOnClose != null) {
      _askOnClose = askOnClose;
    }

    if (useMaterial3 != null) {
      _useMaterial3 = useMaterial3;
    }

    notifyListeners();
  }

  // 设置主色调
  Future<void> setPrimaryColor(Color color) async {
    _primaryColor = color;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_primaryColorKey, color.toARGB32());

    notifyListeners();
  }

  // 设置成功色
  Future<void> setSuccessColor(Color color) async {
    _successColor = color;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_successColorKey, color.toARGB32());

    notifyListeners();
  }

  // 设置警告色
  Future<void> setWarningColor(Color color) async {
    _warningColor = color;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_warningColorKey, color.toARGB32());

    notifyListeners();
  }

  // 设置信息色
  Future<void> setInfoColor(Color color) async {
    _infoColor = color;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_infoColorKey, color.toARGB32());

    notifyListeners();
  }

  // 设置深色模式
  Future<void> setDarkMode(bool isDarkMode) async {
    _isDarkMode = isDarkMode;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, isDarkMode);

    notifyListeners();
  }

  // 设置是否跟随系统主题
  Future<void> setFollowSystem(bool followSystem) async {
    _followSystem = followSystem;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_followSystemKey, followSystem);

    notifyListeners();
  }

  // 设置侧边栏是否固定
  Future<void> setFixedSidebar(bool fixedSidebar) async {
    _fixedSidebar = fixedSidebar;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_fixedSidebarKey, fixedSidebar);

    notifyListeners();
  }

  // 设置是否最小化到托盘
  Future<void> setMinimizeToTray(bool minimizeToTray) async {
    _minimizeToTray = minimizeToTray;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_minimizeToTrayKey, minimizeToTray);

    notifyListeners();
  }

  // 新增：设置是否在关闭时询问
  Future<void> setAskOnClose(bool askOnClose) async {
    _askOnClose = askOnClose;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_askOnCloseKey, askOnClose);

    notifyListeners();
  }

  // 设置是否使用Material Design 3
  Future<void> setUseMaterial3(bool useMaterial3) async {
    _useMaterial3 = useMaterial3;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useMaterial3Key, useMaterial3);

    notifyListeners();
  }

  // 重置为默认色调
  Future<void> resetToDefault() async {
    _primaryColor = _defaultColor;
    _successColor = _defaultSuccessColor;
    _warningColor = _defaultWarningColor;
    _infoColor = _defaultInfoColor;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_primaryColorKey);
    await prefs.remove(_successColorKey);
    await prefs.remove(_warningColorKey);
    await prefs.remove(_infoColorKey);

    notifyListeners();
  }

  // 获取当前主题模式
  ThemeMode getThemeMode() {
    if (_followSystem) {
      return ThemeMode.system;
    } else {
      return _isDarkMode ? ThemeMode.dark : ThemeMode.light;
    }
  }

  // 根据主色调创建ColorScheme
  ColorScheme getColorScheme({required Brightness brightness}) {
    // 根据设置决定使用哪种颜色计算方式
    if (_useMaterial3) {
      // 使用Material Design 3的标准计算方式
      return ColorScheme.fromSeed(
        seedColor: _primaryColor,
        brightness: brightness,
      );
    } else {
      // 直接使用选择的主色调
      return ColorScheme(
        // 使用用户选择的主色作为primary
        primary: _primaryColor,
        // 其他基于亮度的颜色
        brightness: brightness,
        onPrimary: brightness == Brightness.dark ? Colors.black : Colors.white,
        secondary: _primaryColor,
        onSecondary:
            brightness == Brightness.dark ? Colors.black : Colors.white,
        error: Colors.red,
        onError: Colors.white,
        surface:
            brightness == Brightness.dark
                ? const Color(0xFF1E1E1E)
                : Colors.white,
        onSurface: brightness == Brightness.dark ? Colors.white : Colors.black,
        surfaceContainerHighest:
            brightness == Brightness.dark
                ? const Color(0xFF2D2D2D)
                : const Color(0xFFF0F0F0),
        onSurfaceVariant:
            brightness == Brightness.dark
                ? const Color(0xFFDADADA)
                : const Color(0xFF777777),
        outline:
            brightness == Brightness.dark
                ? const Color(0xFF595959)
                : const Color(0xFFBDBDBD),
        outlineVariant:
            brightness == Brightness.dark
                ? const Color(0xFF404040)
                : const Color(0xFFE0E0E0),
        shadow: Colors.black,
        scrim: Colors.black,
        surfaceTint: _primaryColor.withAlpha(26),
        inverseSurface:
            brightness == Brightness.dark
                ? Colors.white
                : const Color(0xFF121212),
        onInverseSurface:
            brightness == Brightness.dark ? Colors.black : Colors.white,
        inversePrimary:
            brightness == Brightness.dark
                ? _primaryColor.withAlpha(179)
                : HSLColor.fromColor(
                  _primaryColor,
                ).withLightness(0.3).toColor(),
        primaryContainer:
            brightness == Brightness.dark
                ? HSLColor.fromColor(
                  _primaryColor,
                ).withLightness(0.25).toColor()
                : HSLColor.fromColor(
                  _primaryColor,
                ).withLightness(0.9).toColor(),
        onPrimaryContainer:
            brightness == Brightness.dark
                ? HSLColor.fromColor(_primaryColor).withLightness(0.9).toColor()
                : HSLColor.fromColor(
                  _primaryColor,
                ).withLightness(0.1).toColor(),
        secondaryContainer:
            brightness == Brightness.dark
                ? HSLColor.fromColor(
                  _primaryColor,
                ).withLightness(0.25).withSaturation(0.4).toColor()
                : HSLColor.fromColor(
                  _primaryColor,
                ).withLightness(0.9).withSaturation(0.4).toColor(),
        onSecondaryContainer:
            brightness == Brightness.dark
                ? HSLColor.fromColor(_primaryColor).withLightness(0.9).toColor()
                : HSLColor.fromColor(
                  _primaryColor,
                ).withLightness(0.1).toColor(),
        tertiaryContainer:
            brightness == Brightness.dark
                ? HSLColor.fromColor(_primaryColor)
                    .withLightness(0.25)
                    .withSaturation(0.4)
                    .withHue((HSLColor.fromColor(_primaryColor).hue + 60) % 360)
                    .toColor()
                : HSLColor.fromColor(_primaryColor)
                    .withLightness(0.9)
                    .withSaturation(0.4)
                    .withHue((HSLColor.fromColor(_primaryColor).hue + 60) % 360)
                    .toColor(),
        onTertiaryContainer:
            brightness == Brightness.dark
                ? HSLColor.fromColor(_primaryColor).withLightness(0.9).toColor()
                : HSLColor.fromColor(
                  _primaryColor,
                ).withLightness(0.1).toColor(),
        tertiary:
            brightness == Brightness.dark
                ? HSLColor.fromColor(_primaryColor)
                    .withHue((HSLColor.fromColor(_primaryColor).hue + 60) % 360)
                    .toColor()
                : HSLColor.fromColor(_primaryColor)
                    .withHue((HSLColor.fromColor(_primaryColor).hue + 60) % 360)
                    .toColor(),
        onTertiary: brightness == Brightness.dark ? Colors.black : Colors.white,
        errorContainer:
            brightness == Brightness.dark
                ? const Color(0xFF5F1919)
                : const Color(0xFFFFDAD6),
        onErrorContainer:
            brightness == Brightness.dark
                ? const Color(0xFFFFB4AB)
                : const Color(0xFF410002),
      );
    }
  }

  // 获取扩展颜色 - 用于访问成功、警告和信息颜色
  Map<String, Color> getExtendedColors() {
    return {
      'success': _successColor,
      'warning': _warningColor,
      'info': _infoColor,
    };
  }

  // 创建TextTheme
  TextTheme getTextTheme(TextTheme baseTheme) {
    // 基于Material 3标准创建文本主题
    final fontFamily = getFontFamily();

    // 使用Material Design 3的字体设置
    return TextTheme(
      displayLarge: baseTheme.displayLarge?.copyWith(
        fontFamily: fontFamily,
        fontVariations: const [FontVariation('wght', 400)],
      ),
      displayMedium: baseTheme.displayMedium?.copyWith(
        fontFamily: fontFamily,
        fontVariations: const [FontVariation('wght', 400)],
      ),
      displaySmall: baseTheme.displaySmall?.copyWith(
        fontFamily: fontFamily,
        fontVariations: const [FontVariation('wght', 400)],
      ),
      headlineLarge: baseTheme.headlineLarge?.copyWith(
        fontFamily: fontFamily,
        fontVariations: const [FontVariation('wght', 500)],
      ),
      headlineMedium: baseTheme.headlineMedium?.copyWith(
        fontFamily: fontFamily,
        fontVariations: const [FontVariation('wght', 500)],
      ),
      headlineSmall: baseTheme.headlineSmall?.copyWith(
        fontFamily: fontFamily,
        fontVariations: const [FontVariation('wght', 500)],
      ),
      titleLarge: baseTheme.titleLarge?.copyWith(
        fontFamily: fontFamily,
        fontVariations: const [FontVariation('wght', 500)],
      ),
      titleMedium: baseTheme.titleMedium?.copyWith(
        fontFamily: fontFamily,
        fontVariations: const [FontVariation('wght', 500)],
      ),
      titleSmall: baseTheme.titleSmall?.copyWith(
        fontFamily: fontFamily,
        fontVariations: const [FontVariation('wght', 500)],
      ),
      bodyLarge: baseTheme.bodyLarge?.copyWith(
        fontFamily: fontFamily,
        fontVariations: const [FontVariation('wght', 400)],
      ),
      bodyMedium: baseTheme.bodyMedium?.copyWith(
        fontFamily: fontFamily,
        fontVariations: const [FontVariation('wght', 400)],
      ),
      bodySmall: baseTheme.bodySmall?.copyWith(
        fontFamily: fontFamily,
        fontVariations: const [FontVariation('wght', 400)],
      ),
      labelLarge: baseTheme.labelLarge?.copyWith(
        fontFamily: fontFamily,
        fontVariations: const [FontVariation('wght', 500)],
      ),
      labelMedium: baseTheme.labelMedium?.copyWith(
        fontFamily: fontFamily,
        fontVariations: const [FontVariation('wght', 500)],
      ),
      labelSmall: baseTheme.labelSmall?.copyWith(
        fontFamily: fontFamily,
        fontVariations: const [FontVariation('wght', 500)],
      ),
    );
  }

  // 获取ThemeData中的字体设置
  String getFontFamily() {
    if (kIsWeb) {
      return 'Roboto'; // Web平台使用默认字体
    }
    if (Platform.isWindows || Platform.isAndroid || Platform.isLinux) {
      // 对于Windows、Android和Linux平台
      return 'Microsoft YaHei';
    } else if (Platform.isMacOS || Platform.isIOS) {
      // 对于macOS和iOS平台
      return '.SF Pro Text';
    }
    return 'Roboto'; // 默认字体
  }

  // 判断当前是否使用中文
  bool isChineseLanguage() {
    // 检查系统语言
    final locale = ui.PlatformDispatcher.instance.locale;
    final languageCode = locale.languageCode;

    // 如果语言代码是zh则为中文
    if (languageCode == 'zh') {
      return true;
    }

    // 如果系统语言不是中文，但在中文环境的平台上，也返回中文字体
    if (Platform.isWindows || Platform.isAndroid || Platform.isLinux) {
      // 这些平台中文环境更常见，保险起见也使用中文字体
      return true;
    }

    return false;
  }

  // 检查是否在桌面平台运行
  bool isDesktop() {
    if (kIsWeb) {
      return false; // Web平台不被视为桌面平台
    }
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }
}

// 扩展Color类，添加withValues方法来替换现有代码中使用的方法
// 这样可以保持代码结构不变，同时修复移动端显示问题
extension ColorExtension on Color {
  Color withValues({int? red, int? green, int? blue, int? alpha}) {
    return Color.fromARGB(
      alpha ?? (a * 255).round(),
      red ?? (r * 255).round(),
      green ?? (g * 255).round(),
      blue ?? (b * 255).round(),
    );
  }

  // 用于转换为ARGB格式的整数值
  int toARGB32() {
    return toARGB32();
  }
}
