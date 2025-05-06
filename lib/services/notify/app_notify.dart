import 'dart:async';
import 'package:logging/logging.dart';
import 'notify.dart'; // Import core notify components

// Logger for App Notify Handler
final Logger _appNotifyLogger = Logger('Notify.AppHandler');

/// Handles specific logic for App notifications, like auto-dismiss timers.
class AppNotifyHandler {
  static final AppNotifyHandler _instance = AppNotifyHandler._internal();
  factory AppNotifyHandler() => _instance;

  AppNotifyHandler._internal();

  // Map to store auto-dismiss timers for App notifications
  final Map<NotifyData, Timer> _appDismissTimers = {};

  /// Starts the auto-dismiss timer for a given App notification.
  void startAppAutoDismissTimer(NotifyData targetNotify) {
    // Ensure it's an app notification
    if (targetNotify.type != NotifyType.app) return;

    // Cancel any existing timer for this notification first
    cancelAppAutoDismissTimer(targetNotify);

    _appNotifyLogger.fine('Starting 5-second auto-dismiss timer for App Notify: "${targetNotify.message}"');
    final timer = Timer(const Duration(seconds: 5), () {
      _appNotifyLogger.fine('Auto-dismiss timer expired for App Notify: "${targetNotify.message}"');
      // Use the NotifyController singleton to dismiss the notification
      NotifyController().dismissNotification(targetNotify);
      // Timer is automatically removed from map inside dismissNotification -> cancelAppAutoDismissTimer
    });
    // Store the timer
    _appDismissTimers[targetNotify] = timer;
  }

  /// Cancels the auto-dismiss timer for a given App notification, if it exists.
  void cancelAppAutoDismissTimer(NotifyData targetNotify) {
     // Ensure it's an app notification
    if (targetNotify.type != NotifyType.app) return;

    if (_appDismissTimers.containsKey(targetNotify)) {
      _appNotifyLogger.fine('Cancelling auto-dismiss timer for App Notify: "${targetNotify.message}"');
      _appDismissTimers[targetNotify]?.cancel();
      _appDismissTimers.remove(targetNotify);
    }
  }

  /// Cancels all active auto-dismiss timers.
  void cancelAllAppAutoDismissTimers() {
    _appNotifyLogger.info('Cancelling all active App Notify auto-dismiss timers.');
    _appDismissTimers.forEach((_, timer) => timer.cancel());
    _appDismissTimers.clear();
  }
}

// Optional: Keep extension methods if they are still desired for convenience,
// but they now call NotifyController directly, which internally uses AppNotifyHandler.
// If these extensions are not used elsewhere, they can be removed.
/*
extension AppNotifyExtension on BuildContext {
  /// Shows a standard app notification.
  void showAppNotify(String message, {VoidCallback? onTap}) {
    NotifyController().showNotify(NotifyData(
      message: message,
      type: NotifyType.app,
      time: DateTime.now(),
      onTap: onTap,
      icon: Icons.info_outline,
    ));
  }

  /// Shows a success app notification.
  void showAppSuccessNotify(String message, {VoidCallback? onTap}) {
     NotifyController().showNotify(NotifyData(
      message: message,
      type: NotifyType.app,
      time: DateTime.now(),
      onTap: onTap,
      icon: Icons.check_circle_outline,
    ));
  }

  /// Shows an error app notification.
  void showAppErrorNotify(String message, {VoidCallback? onTap}) {
     NotifyController().showNotify(NotifyData(
      message: message,
      type: NotifyType.app,
      time: DateTime.now(),
      onTap: onTap,
      icon: Icons.error_outline,
    ));
  }

  /// Shows a warning app notification.
  void showAppWarningNotify(String message, {VoidCallback? onTap}) {
     NotifyController().showNotify(NotifyData(
      message: message,
      type: NotifyType.app,
      time: DateTime.now(),
      onTap: onTap,
      icon: Icons.warning_amber_outlined,
    ));
  }
}
*/