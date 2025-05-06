import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart' as rgv; // 导入 ReorderableGridView 并添加前缀
import '../components/terminalcontroller.dart'; // Import TerminalController

// 定义卡片类型枚举
enum DashboardCardType {
  running,
  total,
  runtime,
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Timer? _timer;
  // 维护卡片顺序的状态列表
  final List<DashboardCardType> _cardOrder = [
    DashboardCardType.running,
    DashboardCardType.total,
    DashboardCardType.runtime,
  ];

  @override
  void initState() {
    super.initState();
    // Start a timer to update the UI every second for runtime duration
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Check if mounted before calling setState
      if (mounted) {
        setState(() {
          // This empty setState call triggers a rebuild to update durations
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); // Cancel the timer when the widget is disposed
    super.dispose();
  }

  // Helper function to format duration
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  // --- 卡片构建函数 ---

  // 构建 "运行中" 卡片
  Widget _buildRunningCard(BuildContext context, TerminalController terminalController) {
    final colorScheme = Theme.of(context).colorScheme;
    final runningCount = terminalController.runningProcessIds.length;
    return _buildInfoCard(
      context: context,
      title: '运行中',
      value: runningCount.toString(),
      icon: Icons.play_circle_outline,
      color: colorScheme.primary,
    );
  }

  // 构建 "总服务数" 卡片
  Widget _buildTotalCard(BuildContext context, TerminalController terminalController) {
    final colorScheme = Theme.of(context).colorScheme;
    final totalCount = terminalController.services.length;
    return _buildInfoCard(
      context: context,
      title: '总服务数',
      value: totalCount.toString(),
      icon: Icons.list_alt,
      color: colorScheme.secondary,
    );
  }

  // 构建 "服务运行时长" 卡片
  Widget _buildRuntimeCard(BuildContext context, TerminalController terminalController) {
    final colorScheme = Theme.of(context).colorScheme;
    final runningServices = terminalController.runningProcessIds.map((id) {
      final name = terminalController.getServiceNameById(id);
      final startTime = terminalController.startTimes[id];
      final duration = startTime != null ? DateTime.now().difference(startTime) : Duration.zero;
      return {'name': name, 'duration': duration};
    }).toList();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      surfaceTintColor: colorScheme.surfaceTint,
      shadowColor: colorScheme.shadow.withAlpha(51),
      child: Container( // Container for padding
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Important for Wrap height
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timer_outlined, color: colorScheme.tertiary, size: 20),
                const SizedBox(width: 8),
                Text(
                  '服务运行时长',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (runningServices.isEmpty)
              Text(
                '无运行中的服务',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              )
            else
              // Use Column instead of ListView for Wrap compatibility if needed,
              // or keep ListView but ensure parent constraints are handled.
              // Wrap works better with intrinsic height, Column is safer here.
              Column(
                 mainAxisSize: MainAxisSize.min, // Keep column tight
                 children: runningServices.map((service) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            service['name'] as String,
                            style: TextStyle(color: colorScheme.onSurfaceVariant),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDuration(service['duration'] as Duration),
                          style: TextStyle(
                            color: colorScheme.tertiary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
              ),
              // Previous ListView.builder implementation:
              // ListView.builder(
              //   shrinkWrap: true, // Important inside Column
              //   physics: const NeverScrollableScrollPhysics(), // Disable scrolling within the card
              //   itemCount: runningServices.length,
              //   itemBuilder: (context, index) {
              //     final service = runningServices[index];
              //     return Padding(
              //       padding: const EdgeInsets.symmetric(vertical: 4.0),
              //       child: Row(
              //         mainAxisAlignment: MainAxisAlignment.spaceBetween,
              //         children: [
              //           Expanded(
              //             child: Text(
              //               service['name'] as String,
              //               style: TextStyle(color: colorScheme.onSurfaceVariant),
              //               overflow: TextOverflow.ellipsis,
              //               maxLines: 1,
              //             ),
              //           ),
              //           const SizedBox(width: 8),
              //           Text(
              //             _formatDuration(service['duration'] as Duration),
              //             style: TextStyle(
              //               color: colorScheme.tertiary,
              //               fontWeight: FontWeight.w500,
              //             ),
              //           ),
              //         ],
              //       ),
              //     );
              //   },
              // ),
          ],
        ),
      ),
    );
  }

  // Helper widget to build the simple info cards (reusable part)
  Widget _buildInfoCard({
    required BuildContext context,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      surfaceTintColor: colorScheme.surfaceTint,
      shadowColor: colorScheme.shadow.withAlpha(51),
      child: Container( // Container for padding
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Important for Wrap height
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Build Method ---
  @override
  Widget build(BuildContext context) {
    // Watch for changes in TerminalController
    final terminalController = context.watch<TerminalController>();
    final screenWidth = MediaQuery.of(context).size.width;
    const horizontalPadding = 16.0;
    const spacing = 16.0;
    // Calculate width for 4 columns, ensure minimum width if calculation is too small
    final calculatedWidth = (screenWidth - horizontalPadding * 2 - spacing * 3) / 4;
    final cardWidth = calculatedWidth > 50 ? calculatedWidth : 100.0; // Set a minimum width


    // Build the list of card widgets based on the current order
    final List<Widget> cards = _cardOrder.map((cardType) {
      Widget cardWidget;
      switch (cardType) {
        case DashboardCardType.running:
          cardWidget = _buildRunningCard(context, terminalController);
          break;
        case DashboardCardType.total:
          cardWidget = _buildTotalCard(context, terminalController);
          break;
        case DashboardCardType.runtime:
          cardWidget = _buildRuntimeCard(context, terminalController);
          break;
      }
      // Wrap each card in a SizedBox to control its width for the Wrap layout
      // Use a Key for ReorderableWrap
      return SizedBox(
        key: ValueKey(cardType), // Unique key for reordering
        width: cardWidth, // Apply calculated width
        child: cardWidget,
      );
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(horizontalPadding),
      // Use ReorderableWrap for drag-and-drop grid-like layout
      child: rgv.ReorderableGridView( // 使用 ReorderableGridView
        // Required grid delegate
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: cardWidth, // Use calculated card width
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          childAspectRatio: 1.0, // Adjust as needed for card aspect ratio
        ),
        // Required children delegate
        childrenDelegate: SliverChildListDelegate(cards),
        // Keep the onReorder callback
        onReorder: (int oldIndex, int newIndex) {
          setState(() {
            // Update the card order list
            final item = _cardOrder.removeAt(oldIndex);
            _cardOrder.insert(newIndex, item);
          });
        },
      ),
    );
  }
}