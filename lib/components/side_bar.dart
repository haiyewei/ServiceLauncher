import 'dart:async'; // 导入 async
import 'package:flutter/material.dart';
import '../constants/app_info.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/notify/notify.dart';

class SideBar extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final bool isFixedSidebar;

  const SideBar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    this.isFixedSidebar = false,
  });

  @override
  State<SideBar> createState() => _SideBarState();
}

class _SideBarState extends State<SideBar> {
  final NotifyController _notifyController = NotifyController();
  final ScrollController _scrollController = ScrollController();
  StreamSubscription? _historySubscription; // 用于管理 Stream 订阅

  @override
  void initState() {
    super.initState();
    // 监听历史记录变化流
    _historySubscription = _notifyController.historyChangeStream.listen((_) {
      // 当历史记录变化时，调用 setState 重建 UI
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    // 取消 Stream 订阅
    _historySubscription?.cancel();
    super.dispose();
  }

  // 移除 _refreshNotifications 方法
  // 检查是否在移动平台运行 (需要 BuildContext 来访问 View)
  bool _isMobile(BuildContext context) {
    if (kIsWeb) {
      // 在Web平台上，使用 View.of(context) 获取视图信息
      final view = View.of(context);
      return view.physicalSize.width / view.devicePixelRatio < 600;
    }
    return Platform.isAndroid || Platform.isIOS;
  }

  @override
  Widget build(BuildContext context) {
    // 获取状态栏高度
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final colorScheme = Theme.of(context).colorScheme;

    // 不再使用 NotifyWidget 包裹，通知显示在下方的通知中心
    final sidebarContent = Column(
      children: [
        // 标题容器，考虑移动端状态栏高度
        Container(
          // 移动端需要增加状态栏高度
          height:
              _isMobile(context) // Pass context
                  ? kToolbarHeight + statusBarHeight
                  : kToolbarHeight,
          width: double.infinity,
          decoration: BoxDecoration(
            color: colorScheme.primary,
            // 添加微妙的阴影效果
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withAlpha(
                  (255 * 0.1).round(),
                ), // Use withAlpha
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          // 使用Stack和Positioned确保文本在正确的位置
          child: Stack(
            children: [
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: kToolbarHeight,
                child: Center(
                  child: Text(
                    AppInfo.appName,
                    style: TextStyle(
                      color: colorScheme.onPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(
              vertical: 8.0,
              horizontal: 12.0,
            ),
            children: [
              const SizedBox(height: 8),
              _buildNavItem(
                context,
                index: 0,
                title: '仪表盘',
                icon: Icons.dashboard,
              ),
              const SizedBox(height: 8),
_buildNavItem(
                context,
                index: 1, // 为服务列表页面分配 index 1
                title: '服务列表',
                icon: Icons.storage,
              ),
              const SizedBox(height: 8),

              _buildDivider(context),

              const SizedBox(height: 8),

              _buildNavItem(
                context,
                index: 2, // 更新系统设置的 index 为 2
                title: '系统设置',
                icon: Icons.settings,
              ),

              // 在系统设置下方添加分隔符
              const SizedBox(height: 8),
              _buildDivider(context),

              // 通知容器标题
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.notifications_none,
                      size: 18,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '通知中心',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              // 通知列表容器
              SizedBox(height: 300, child: _buildNotificationList(context)),
            ],
          ),
        ),
      ],
    );

    // 根据是否为固定侧边栏返回不同的容器
    if (widget.isFixedSidebar) {
      return Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          // 添加右侧阴影
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withAlpha(
                (255 * 0.1).round(),
              ), // Use withAlpha
              blurRadius: 4,
              offset: const Offset(2, 0),
            ),
          ],
        ),
        child: sidebarContent,
      );
    }

    // 移动端使用Drawer
    return Drawer(
      backgroundColor: colorScheme.surface,
      elevation: 0, // 移除Drawer自带的阴影，我们会自定义阴影
      child: sidebarContent,
    );
  }

  Widget _buildNotificationList(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final notifications = _notifyController.notifyHistory;

    if (notifications.isEmpty) {
      return Center(
        child: Text(
          '暂无通知',
          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        final notification = notifications[index];

        // 根据通知类型获取颜色和图标
        Color notifyColor;
        IconData notifyIcon;

        switch (notification.type) {
          case NotifyType.app:
            notifyColor = colorScheme.primary;
            notifyIcon = Icons.notifications;
            break;
          case NotifyType.mail:
            notifyColor = colorScheme.secondary;
            notifyIcon = Icons.email;
            break;
          case NotifyType.system:
            notifyColor = Colors.green;
            notifyIcon = Icons.info;
            break;
        }

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          elevation: 0,
          color: colorScheme.surfaceContainerHighest.withAlpha(
            (255 * 0.3).round(),
          ), // Use withAlpha
          child: InkWell(
            onTap: () {
              // 如果是应用通知
              if (notification.type == NotifyType.app) {
                // 执行通知自带的回调（如果有）
                notification.onTap?.call();
                // --- 修改：点击侧边栏 App 通知时立即删除，并取消计时器 ---
                _notifyController.dismissNotification(notification);
                // --- 修改结束 ---
                // Stream 监听会自动处理 UI 更新，无需 setState
              }
              // 对于其他类型的通知，点击可能没有预设行为，或者可以在这里添加
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    notification.icon ?? notifyIcon,
                    size: 16,
                    color: notifyColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          notification.message,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          // 使用 Row 并排放置时间和类型
                          children: [
                            Text(
                              _formatTime(notification.time),
                              style: TextStyle(
                                fontSize: 10,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 8), // 添加间距
                            // 添加类型标签
                            Text(
                              '(${_getNotifyTypeName(notification.type)})', // 调用辅助方法获取类型名称
                              style: TextStyle(
                                fontSize: 10,
                                color: notifyColor.withAlpha(
                                  (255 * 0.8).round(),
                                ), // Use withAlpha
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 0) {
      return '${difference.inDays}天前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}小时前';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}分钟前';
    } else {
      return '刚刚';
    }
  }

  // 辅助方法：根据 NotifyType 获取可读名称
  String _getNotifyTypeName(NotifyType type) {
    switch (type) {
      case NotifyType.app:
        return '应用';
      case NotifyType.mail:
        return '邮件';
      case NotifyType.system:
        return '系统';
    }
  }

  Widget _buildDivider(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Divider(
        height: 1,
        thickness: 1,
        color: colorScheme.outlineVariant.withAlpha(
          (255 * 0.5).round(),
        ), // Use withAlpha
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required int index,
    required String title,
    required IconData icon,
  }) {
    final isSelected = index == widget.selectedIndex;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: isSelected ? 1 : 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      color: isSelected ? colorScheme.primaryContainer : Colors.transparent,
      child: InkWell(
        onTap: () => widget.onItemSelected(index),
        splashColor: colorScheme.primary.withAlpha(
          (255 * 0.1).round(),
        ), // Use withAlpha
        highlightColor: colorScheme.primary.withAlpha(
          (255 * 0.05).round(),
        ), // Use withAlpha
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              Icon(
                icon,
                color: colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 16),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight:
                        isSelected ? FontWeight.w500 : FontWeight.normal,
                    color:
                        isSelected
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
