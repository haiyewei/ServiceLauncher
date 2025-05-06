import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../components/top_bar.dart';
import '../components/side_bar.dart';
import '../themes/theme_manager.dart';
import 'dashboard_page.dart';
import 'settings_page.dart';
import 'service_list_page.dart'; // 导入服务列表页面

// 全局键，用于在任何位置获取HomePageState
final GlobalKey<HomePageState> homePageKey = GlobalKey<HomePageState>();

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  // 获取State实例的辅助方法
  static HomePageState? of(BuildContext context) {
    return homePageKey.currentState;
  }

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  // 跟踪侧边栏的折叠状态
  bool _isSidebarCollapsed = true;

  // 页面列表
  final List<Widget> _pages = [
    const DashboardPage(),
    ServiceListPage(), // 添加服务列表页面
    const SystemSettingsPage(), // Corrected class name for '系统设置'
  ];

  // 页面标题
  final List<String> _titles = ['仪表盘', '服务列表', '系统设置']; // 删除遗留标题

  @override
  void initState() {
    super.initState();
    // Initialization of _pages is now done directly, no need to call _initPages
  }

  // 获取BuildContext，供其他页面使用
  BuildContext? getContext() {
    return context;
  }

  // 检查是否在桌面平台运行
  bool _isDesktop() {
    if (kIsWeb) {
      return false; // Web平台视为非桌面平台
    }
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  void _onItemSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // 在移动设备上选择项目后关闭抽屉
    if (!_isDesktop() && (_scaffoldKey.currentState?.isDrawerOpen ?? false)) {
      Navigator.pop(context);
      setState(() {
        _isSidebarCollapsed = true;
      });
    }
  }

  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
    setState(() {
      _isSidebarCollapsed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 获取主题管理器
    final themeManager = Provider.of<ThemeManager>(context);
    // 判断是否为桌面平台
    final bool isDesktop = _isDesktop();
    // 获取是否固定侧边栏的设置
    final bool isFixedSidebar = isDesktop && themeManager.fixedSidebar;

    // 监听抽屉状态变化
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isFixedSidebar && _scaffoldKey.currentState != null) {
        final isDrawerOpen = _scaffoldKey.currentState!.isDrawerOpen;
        if (isDrawerOpen != !_isSidebarCollapsed) {
          setState(() {
            _isSidebarCollapsed = !isDrawerOpen;
          });
        }
      }
    });

    // 构建主体内容
    Widget bodyContent = _pages[_selectedIndex];

    // 如果是桌面平台且设置为固定侧边栏
    if (isFixedSidebar) {
      // 桌面平台布局：固定展开的侧边栏
      return Scaffold(
        body: Row(
          children: [
            // 固定侧边栏
            SizedBox(
              width: 280, // 适合桌面端的侧边栏宽度
              child: SideBar(
                selectedIndex: _selectedIndex,
                onItemSelected: _onItemSelected,
                isFixedSidebar: true, // 使用固定侧边栏
              ),
            ),
            // 内容区域
            Expanded(
              child: Scaffold(
                appBar: TopBar(
                  title: _titles[_selectedIndex],
                  onMenuPressed: null, // 桌面端不需要菜单按钮
                  showMenuButton: false, // 不显示菜单按钮
                  showTitle: false, // 不显示标题
                  isSidebarCollapsed: false, // 固定侧边栏模式下，侧边栏始终展开
                  isDesktopSidebarFixed: true, // 这是桌面端固定侧边栏模式
                ),
                body: bodyContent,
              ),
            ),
          ],
        ),
      );
    } else {
      // 移动平台或桌面平台未固定侧边栏：可收起的侧边栏
      return Scaffold(
        key: _scaffoldKey,
        appBar: TopBar(
          title: _titles[_selectedIndex],
          onMenuPressed: _openDrawer,
          showMenuButton: true, // 显示菜单按钮
          showTitle: false, // 不显示标题，由组件内部根据侧边栏状态决定
          isSidebarCollapsed: _isSidebarCollapsed, // 传递侧边栏状态
          isDesktopSidebarFixed: false,
        ),
        drawer: SideBar(
          selectedIndex: _selectedIndex,
          onItemSelected: _onItemSelected,
          isFixedSidebar: false, // 使用可收起侧边栏
        ),
        body: bodyContent,
        onDrawerChanged: (isOpened) {
          setState(() {
            _isSidebarCollapsed = !isOpened;
          });
        },
      );
    }
  }
}
