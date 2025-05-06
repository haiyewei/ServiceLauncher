import 'package:flutter/material.dart';
import 'notify.dart';

/// 系统通知类（暂时留空）
class SystemNotify {
  static final SystemNotify _instance = SystemNotify._internal();
  
  factory SystemNotify() {
    return _instance;
  }
  
  SystemNotify._internal();
  
  /// 显示系统通知
  void show(BuildContext context, String message, {VoidCallback? onTap}) {
    final controller = NotifyController();
    
    controller.showNotify(
      NotifyData(
        message: message,
        type: NotifyType.system,
        time: DateTime.now(),
        onTap: onTap,
        icon: Icons.system_update_outlined,
      ),
    );
  }
}

// 后续将在此处添加更多系统通知相关功能 