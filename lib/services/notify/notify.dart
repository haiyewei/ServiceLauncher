import 'dart:async'; // 导入 async
import 'package:flutter/material.dart';
import 'package:logging/logging.dart'; // 导入 logging 包
// 导出其他通知类
export 'app_notify.dart'; // 

export 'system_notify.dart';
import 'app_notify.dart'; // Import the new handler

// 创建通知系统专用的 Logger
final Logger _notifyLogger = Logger('Notify');

// 初始化日志系统
void initNotifyLogger() {
  // 设置日志级别（可根据需要调整）
  Logger.root.level = Level.ALL;
  
  // 添加日志监听器
  Logger.root.onRecord.listen((record) {
    // 格式化日志输出
    debugPrint('${record.time}: [${record.level.name}] [${record.loggerName}] ${record.message}');
    if (record.error != null) {
      debugPrint('Error: ${record.error}');
    }
    if (record.stackTrace != null) {
      debugPrint('Stack trace: ${record.stackTrace}');
    }
  });
  
  _notifyLogger.info('通知日志系统初始化完成');
}

/// 通知类型枚举
enum NotifyType {
  app,    // 应用通知
  mail,   // 邮件通知
  system, // 系统通知
}

/// 通知数据模型
class NotifyData {
  final String message;
  final NotifyType type;
  final DateTime time;
  final VoidCallback? onTap;
  final IconData? icon;
  
  const NotifyData({
    required this.message,
    required this.type,
    required this.time,
    this.onTap,
    this.icon,
  });
}

/// 通知控制器 - 用于全局管理通知
class NotifyController {
  static final NotifyController _instance = NotifyController._internal();


  // 用于通知历史记录变化的 StreamController
  final _historyChangeStreamController = StreamController<void>.broadcast();
  Stream<void> get historyChangeStream => _historyChangeStreamController.stream;

  // App notification specific logic is handled by AppNotifyHandler
  final AppNotifyHandler _appNotifyHandler = AppNotifyHandler();


 factory NotifyController() {
    return _instance;
  }
  
  NotifyController._internal() {
    // 确保日志系统初始化
    initNotifyLogger();
    _notifyLogger.config('NotifyController 初始化');
  }
  
  // 通知队列 (历史记录)
  final List<NotifyData> _notifyQueue = [];
  List<NotifyData> get notifyHistory => List.unmodifiable(_notifyQueue);
  
  // 添加通知到历史记录
  void showNotify(NotifyData notify) {
    _notifyLogger.fine('Adding new notification to history: ${notify.type.name} - "${notify.message.substring(0, notify.message.length > 50 ? 50 : notify.message.length)}${notify.message.length > 50 ? "..." : ""}"');

    // 添加到队列 (历史记录)
    _notifyQueue.add(notify);
    // 通知历史记录已更改
    _historyChangeStreamController.add(null);

    // If it's an app notification, delegate timer start to the handler
    if (notify.type == NotifyType.app) {
      _appNotifyHandler.startAppAutoDismissTimer(notify);
    }
    _notifyLogger.fine('Notification added to history, current history length: ${_notifyQueue.length}');
  }

  // 清空所有通知
  void clearAllNotifications() {
    _notifyLogger.info('清空所有通知，当前队列长度: ${_notifyQueue.length}');
    _notifyQueue.clear();
    // 通知历史记录已更改
    _historyChangeStreamController.add(null);
    // Delegate cancelling all app timers to the handler
    _appNotifyHandler.cancelAllAppAutoDismissTimers();
  }

  // 获取分页通知列表
  List<NotifyData> getPagedNotifications(int offset, int limit) {
    _notifyLogger.fine('获取分页通知列表：offset=$offset, limit=$limit');
    
    // 确保队列不为空
    if (_notifyQueue.isEmpty) {
      return [];
    }
    
    // 确保不越界
    if (offset >= _notifyQueue.length) {
      return [];
    }
    
    // 计算实际结束位置
    final end = (offset + limit) > _notifyQueue.length
        ? _notifyQueue.length
        : offset + limit;
    
    // 提取并返回子列表
    return _notifyQueue.sublist(offset, end);
  }
  
  // 删除指定通知
  void dismissNotification(NotifyData notification) {
    _notifyLogger.fine('删除指定通知');
    
    // 从队列 (历史记录) 中查找并移除
    final index = _notifyQueue.indexOf(notification);
    if (index != -1) {
      // Delegate cancelling the specific app timer to the handler
      _appNotifyHandler.cancelAppAutoDismissTimer(notification);
     _notifyQueue.removeAt(index);
      // 通知历史记录已更改
      _historyChangeStreamController.add(null);
      _notifyLogger.fine('成功删除通知，剩余队列长度: ${_notifyQueue.length}');
    } else {
      _notifyLogger.warning('尝试从历史记录中删除不存在的通知');
    }
  }

  // 标记应用通知已读
 void markAppNotificationRead(NotifyData notification) {
    _notifyLogger.fine('标记应用通知已读');
    
    // 仅处理应用通知
    if (notification.type == NotifyType.app) {
      dismissNotification(notification);
    }
  }
  // 添加 dispose 方法关闭 StreamController
  void dispose() {
    _historyChangeStreamController.close();
    // Also ensure all app timers are cancelled on dispose
    _appNotifyHandler.cancelAllAppAutoDismissTimers();
    _notifyLogger.config('NotifyController disposed');
  }


}


// NotifyWidget class and its shortcut methods have been removed.
// 注意: mail_notify.dart 和 system_notify.dart 文件目前未被直接使用，
// 但被保留作为未来实现邮件和系统特定通知功能的占位符。