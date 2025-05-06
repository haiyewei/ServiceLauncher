import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class TopBar extends StatefulWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final VoidCallback? onMenuPressed;
  final bool showMenuButton;
  final bool showTitle;
  final bool isSidebarCollapsed;
  final bool isDesktopSidebarFixed;

  const TopBar({
    super.key,
    required this.title,
    this.actions,
    this.onMenuPressed,
    this.showMenuButton = true,
    this.showTitle = false,
    this.isSidebarCollapsed = false,
    this.isDesktopSidebarFixed = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
  
  @override
  State<TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<TopBar> {
  @override
  Widget build(BuildContext context) {
    // 根据当前主题的亮度确定颜色
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDarkMode ? Colors.black : Colors.white;
    
    // 构建标题部分
    Widget? titleWidget;
    if (_shouldShowTitle()) {
      titleWidget = Text(widget.title);
    } else {
      titleWidget = null;
    }
    
    final appBar = AppBar(
      leading: widget.showMenuButton ? _buildLeadingWidget(context) : null,
      automaticallyImplyLeading: widget.showMenuButton,
      title: titleWidget,
      centerTitle: false,
      actions: widget.actions,
      elevation: 0,
      backgroundColor: Theme.of(context).colorScheme.primary,
      foregroundColor: titleColor,
    );

    // 在桌面平台上使用DragToMoveArea包装顶栏，使其可拖动
    if (_isDesktop()) {
      return Stack(
        children: [
          // 可拖动区域（整个顶栏）
          GestureDetector(
            onDoubleTap: () async {
              if (await windowManager.isMaximized()) {
                await windowManager.unmaximize();
              } else {
                await windowManager.maximize();
              }
            },
            child: DragToMoveArea(
              child: appBar,
            ),
          ),
          // 窗口控制按钮区域（右上角）
          if (_isDesktop())
            Positioned(
              top: 0,
              right: 0,
              height: kToolbarHeight,
              child: _buildWindowControlButtons(context),
            ),
        ],
      );
    }

    return appBar;
  }

  bool _shouldShowTitle() {
    // 在侧边栏收起时显示标题，除非是桌面端且侧边栏固定
    if (widget.isSidebarCollapsed && !widget.isDesktopSidebarFixed) {
      return true;
    }
    // 如果显式设置了showTitle为true
    return widget.showTitle;
  }

  Widget _buildLeadingWidget(BuildContext context) {
    // 如果侧边栏已收起，且不是桌面端固定侧边栏模式，显示标题而不是圆形按钮
    if (widget.isSidebarCollapsed && !widget.isDesktopSidebarFixed) {
      return IconButton(
        icon: Icon(Icons.menu),
        onPressed: widget.onMenuPressed,
      );
    }
    
    // 否则显示原来的圆形按钮
    return _buildCircleMenuButton(context);
  }

  Widget _buildCircleMenuButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: Center(
        child: ClipOval(
          child: Material(
            color: Theme.of(context).colorScheme.secondary,
            child: InkWell(
              onTap: widget.onMenuPressed,
              child: const SizedBox(
                width: 36,
                height: 36,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 构建窗口控制按钮（最小化、最大化、关闭）
  Widget _buildWindowControlButtons(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start, // 按钮靠近顶部
      children: [
        _buildWindowButton(
          icon: Icons.remove,
          tooltip: '最小化',
          onPressed: () async {
            await windowManager.minimize();
          },
          colorScheme: colorScheme,
        ),
        _buildWindowButton(
          icon: Icons.crop_square,
          tooltip: '最大化',
          onPressed: () async {
            if (await windowManager.isMaximized()) {
              await windowManager.unmaximize();
            } else {
              await windowManager.maximize();
            }
          },
          colorScheme: colorScheme,
        ),
        _buildWindowButton(
          icon: Icons.close,
          tooltip: '关闭',
          onPressed: () async {
            // 触发窗口关闭事件，但不实际关闭窗口
            // 这会被主应用中的windowManager.setPreventClose(true)拦截并交给onWindowClose处理
            try {
              await windowManager.close();
            } catch (e) {
              debugPrint('关闭窗口时出错: $e');
              // 出错时退回到简单的隐藏窗口
              await windowManager.hide();
            }
          },
          isCloseButton: true,
          colorScheme: colorScheme,
        ),
      ],
    );
  }

  // 构建单个窗口控制按钮
  Widget _buildWindowButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    required ColorScheme colorScheme,
    bool isCloseButton = false,
  }) {
    return SizedBox(
      width: 45, // 标准窗口按钮宽度
      height: 32, // 标准窗口按钮高度
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          hoverColor: isCloseButton ? Colors.red.withAlpha(26) : colorScheme.onSurface.withAlpha(26),
          onTap: onPressed,
          child: Tooltip(
            message: tooltip,
            child: Center(
              child: Icon(
                icon,
                size: 16,
                color: colorScheme.onPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _isDesktop() {
    if (kIsWeb) {
      return false;
    }
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }
} 