import 'package:flutter/foundation.dart'; // Import for defaultTargetPlatform
import 'package:betrayal/betrayal.dart'; // Import betrayal library
import 'package:window_manager/window_manager.dart';
import 'package:contextual_menu/contextual_menu.dart'
    as cm; // Import with alias

class SystemTrayService {
  late final TrayIcon _trayIcon;

  SystemTrayService();

  Future<void> init() async {
    // Initialize betrayal (accessing instance initializes it)
    _trayIcon = TrayIcon(); // Create TrayIcon instance
    await _initSystemTray();
  }

  Future<void> _initSystemTray() async {
    final iconPath = _getTrayIconPath(); // Get icon path
    // Convert path string to Uri for setImage
    // Use TrayIconImageDelegate based on the path
    if (iconPath.isNotEmpty) {
      try {
        final imageDelegate = TrayIconImageDelegate.fromAsset(iconPath);
        await _trayIcon.setImage(delegate: imageDelegate);
        debugPrint("Tray icon image set using delegate: $iconPath");
      } catch (e) {
        debugPrint("Error setting tray icon from asset '$iconPath': $e");
        // Optionally set a fallback icon or handle the error
      }
    } else {
      debugPrint(
        "Warning: No valid tray icon path determined for the current platform.",
      );
    }

    // Set tooltip
    _trayIcon.setTooltip("ServiceLauncher"); // Set a tooltip

    // Set click handlers
    _trayIcon.onTap = (_) => _onTrayIconTap();
    _trayIcon.onSecondaryTap = (_) => _showContextMenu();

    // Show the icon
    await _trayIcon.show();
    debugPrint("System tray icon initialized and shown.");
  }

  String _getTrayIconPath() {
    // Return paths declared in pubspec.yaml assets
    if (defaultTargetPlatform == TargetPlatform.windows) {
      return 'assets/icons/app_icon.ico'; // Path declared in pubspec.yaml
    } else if (defaultTargetPlatform == TargetPlatform.macOS) {
      // macOS might use .png from assets if specified, or handle differently.
      // Let's use the declared .png for consistency.
      return 'assets/icons/app_icon.png'; // Path declared in pubspec.yaml
    } else if (defaultTargetPlatform == TargetPlatform.linux) {
      return 'assets/icons/app_icon.png'; // Path declared in pubspec.yaml
    } else {
      // Fallback for other platforms or web (though tray usually not applicable)
      return '';
    }
  }

  // Handler for left-click (show window)
  void _onTrayIconTap() async {
    // Use WindowManager.instance
    await WindowManager.instance.show();
    await WindowManager.instance.focus();
    await WindowManager.instance.setSkipTaskbar(false);
    debugPrint("Tray icon tapped, showing window.");
  }

  // Handler for right-click (show context menu)
  void _showContextMenu() {
    // Create the menu using contextual_menu package
    // Use alias 'cm' for contextual_menu items
    final menu = cm.Menu(
      items: [
        cm.MenuItem(
          label: 'Show Window',
          onClick: (_) => _onTrayIconTap(), // Reuse left-click handler
        ),
        cm.MenuItem.separator(), // Add a separator
        cm.MenuItem(
          label: 'Exit',
          onClick: (_) async {
            debugPrint("Exit menu item clicked.");
            // Use WindowManager.instance
            await WindowManager.instance.destroy(); // Close the window and exit
          },
        ),
      ],
    );

    // Show the menu using alias 'cm'
    cm.popUpContextualMenu(
      menu,
      placement: cm.Placement.bottomLeft, // Adjust placement as needed
    );
    debugPrint("Context menu shown.");
  }

  // Dispose method to clean up the tray icon
  void dispose() {
    _trayIcon.dispose();
    debugPrint("System tray service disposed.");
  }
}
