import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:provider/provider.dart';
import 'dart:io' show Platform, File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'pages/home_page.dart';
import 'constants/app_info.dart';
import 'themes/theme_manager.dart';
import 'services/system_tray_service.dart';
import 'components/terminalcontroller.dart'; // Import TerminalController
import 'components/start_up.dart'; // Import StartupService
 
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 设置沉浸式系统导航栏 - 使用更强的设置
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  // 创建主题管理器
  final themeManager = ThemeManager();
  // 加载设置
  await themeManager.loadSettings();

  // 初始化窗口管理器和托盘管理器（仅在桌面平台）
  if (isDesktop()) {
    try {
      await windowManager.ensureInitialized();
      // trayManager不需要初始化

      // 设置窗口关闭前的拦截动作
      windowManager.setPreventClose(true);

      WindowOptions windowOptions = WindowOptions(
        size: const Size(1280, 720),
        center: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.hidden,
        title: AppInfo.appName,
      );

      // 设置任务栏/Dock图标
      await _setAppWindowIcon();

      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });

      // 设置托盘图标和菜单
      // 使用TrayService类而不是直接在这里设置
      final systemTrayService = SystemTrayService();
      await systemTrayService.init();
    } catch (e) {
      debugPrint('初始化窗口或托盘管理器时出错: $e');
    }
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeManager()),
        ChangeNotifierProvider(create: (context) => TerminalController()), // Provide TerminalController
      ],
      child: const ServiceLauncherAPP(),
    ),
  );
}

// 设置应用窗口图标
Future<void> _setAppWindowIcon() async {
  try {
    if (Platform.isWindows) {
      // Windows平台设置窗口图标
      String iconPath = 'assets/icon/app_icon.ico';
      if (await File(iconPath).exists()) {
        debugPrint('设置Windows应用图标: $iconPath');
      }
    } else if (Platform.isMacOS) {
      // macOS平台不需要额外设置，使用Info.plist配置
      debugPrint('macOS平台使用应用自带图标');
    } else if (Platform.isLinux) {
      // Linux平台设置窗口图标
      String iconPath = 'assets/icon/app_icon.png';
      if (await File(iconPath).exists()) {
        debugPrint('设置Linux应用图标: $iconPath');
      }
    }
  } catch (e) {
    debugPrint('设置应用窗口图标时出错: $e');
  }
}

// 检查是否在桌面平台运行
bool isDesktop() {
  if (kIsWeb) {
    return false; // Web平台不被视为桌面平台
  }
  return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
}

class ServiceLauncherAPP extends StatefulWidget {
  const ServiceLauncherAPP({super.key});

  @override
  State<ServiceLauncherAPP> createState() => _ServiceLauncherAPPState();
}

class _ServiceLauncherAPPState extends State<ServiceLauncherAPP> with WindowListener {
  @override
  void initState() {
    super.initState();
    if (isDesktop()) {
      windowManager.addListener(this);
    }
    _performStartupRecovery();
  }

  Future<void> _performStartupRecovery() async {
    // Ensure TerminalController is initialized before proceeding
    final terminalController = Provider.of<TerminalController>(context, listen: false);
    await terminalController.initializationComplete; // Wait for TC to be ready

    final startupService = StartupService();
    // It's important that TerminalController is fully initialized before this call,
    // especially its _services list and initial _servicePids from its own _loadRunningState.
    await startupService.checkAndRecoverServices(terminalController);
    // After recovery, TerminalController might have updated its state (e.g., started services, updated PIDs).
    // A final notifyListeners from TerminalController (if state changed) or here might be needed
    // if checkAndRecoverServices doesn't trigger it appropriately.
    // However, startServiceById in TerminalController already calls notifyListeners.
  }
 
  @override
  void dispose() {
    if (isDesktop()) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  // 实现WindowListener的onWindowClose方法
  @override
  void onWindowClose() async {
    final themeManager = Provider.of<ThemeManager>(context, listen: false);

    // 无论设置如何，都直接根据minimizeToTray设置决定行为
    // 避免使用任何对话框，因为在窗口关闭事件中可能导致问题
    if (themeManager.minimizeToTray) {
      // 如果设置了后台存活，则最小化到托盘
      await windowManager.minimize();
      await windowManager.setSkipTaskbar(true); // 最小化到托盘时隐藏任务栏图标
    } else {
      // 如果没有设置后台存活，则完全退出应用
      await windowManager.destroy();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        // 如果系统支持动态颜色，我们可以提供用户选择是否使用
        // 这里我们总是使用用户在设置页面选择的颜色
        ColorScheme lightColorScheme = themeManager.getColorScheme(
          brightness: Brightness.light,
        );
        ColorScheme darkColorScheme = themeManager.getColorScheme(
          brightness: Brightness.dark,
        );

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: AppInfo.appName,
          themeMode: themeManager.getThemeMode(),
          theme: ThemeData(
            colorScheme: lightColorScheme,
            useMaterial3: true,
            fontFamily: themeManager.getFontFamily(),
            textTheme: themeManager.getTextTheme(ThemeData.light().textTheme),
            appBarTheme: const AppBarTheme(
              systemOverlayStyle: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.dark,
                systemNavigationBarIconBrightness: Brightness.dark,
              ),
            ),
          ),
          darkTheme: ThemeData(
            colorScheme: darkColorScheme,
            useMaterial3: true,
            fontFamily: themeManager.getFontFamily(),
            textTheme: themeManager.getTextTheme(ThemeData.dark().textTheme),
            appBarTheme: const AppBarTheme(
              systemOverlayStyle: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.light,
                systemNavigationBarIconBrightness: Brightness.light,
              ),
            ),
          ),
          home: const HomePage(),
        );
      },
    );
  }
}
