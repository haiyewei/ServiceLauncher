import 'package:flutter/material.dart';
import 'dart:io';
// import 'dart:convert'; // No longer needed here
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart'; // Import provider

import '../components/edit_service_dialog.dart'; // Import the EditServiceDialog
import '../components/terminalcontroller.dart'; // Import TerminalController (which now includes Service)
import 'package:uuid/uuid.dart'; // Keep uuid for dialogs

// Helper function to recursively copy a directory (Keep for _addService logic)
Future<void> _copyDirectory(Directory source, Directory destination) async {
  // Create the destination directory if it doesn't exist
  if (!await destination.exists()) {
    await destination.create(recursive: true);
  }

  // Get all files and directories in the source directory
  await for (var entity in source.list(recursive: false)) {
    if (entity is Directory) {
      // If it's a directory, recursively copy it
      final newDirectory = Directory(
        p.join(destination.path, p.basename(entity.path)),
      );
      await _copyDirectory(entity, newDirectory);
    } else if (entity is File) {
      // If it's a file, copy it
      final newFile = File(p.join(destination.path, p.basename(entity.path)));
      await entity.copy(newFile.path);
    }
  }
}

class ServiceListPage extends StatefulWidget {
  const ServiceListPage({super.key});

  @override
  State<ServiceListPage> createState() => _ServiceListPageState();
}

class _ServiceListPageState extends State<ServiceListPage> {
  // Remove local _services list and related methods (_loadServices, _saveServices, _getServicesFilePath, initState)
  // State is now managed by TerminalController via Provider

  // Keep _copyDirectory helper as it's used in _addService dialog logic


  // 实现导入服务功能 (Implement import service function) - Modified to use TerminalController
  void _importService() async {
    final serviceNameController = TextEditingController();
    final servicePathController =
        TextEditingController(); // New controller for Service Path
    final preCommandController = TextEditingController();
    final preParametersController = TextEditingController(); // New controller for Pre-parameters
    final postParametersController = TextEditingController();
    final programNameController =
        TextEditingController(); // Controller for program name

    // Capture the Navigator *before* the async gap caused by showDialog
    final navigator = Navigator.of(context);
    // Capture ScaffoldMessenger *before* async gaps if needed for error messages
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    // Get TerminalController instance - needed for adding the service
    final terminalController = Provider.of<TerminalController>(context, listen: false);

    await showDialog(
      context: context, // Use the original context for the dialog
      builder:
          (dialogContext) => AlertDialog(
            // Use dialogContext inside builder
            title: const Text('导入服务'), // Import Service
            content: StatefulBuilder(
              // Use StatefulBuilder to update dialog content
              builder: (BuildContext context, StateSetter setStateDialog) {
                return SizedBox( // Wrap content in SizedBox to control width
                  width: MediaQuery.of(context).size.width * 0.6, // Set width to 60% of screen width
                  child: SingleChildScrollView(
                    // Use SingleChildScrollView to prevent overflow
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 服务名称 (Service Name) - Required
                        TextField(
                          controller: serviceNameController,
                          decoration: const InputDecoration(
                            labelText: '服务名称 (必填)',
                          ), // Service Name (Required)
                        ),
                        const SizedBox(height: 16),

                        // 服务路径 (Service Path) - Required, Directory Picker
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('服务路径 (必填)'), // Service Path (Required)
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: servicePathController,
                                    decoration: InputDecoration(
                                      hintText:
                                          '请选择服务路径', // Please select service path
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 12,
                                      ),
                                    ),
                                    readOnly:
                                        true, // Make it read-only as it's filled by the picker
                                    style: TextStyle(
                                      fontSize: 14,
                                      color:
                                          servicePathController.text.isNotEmpty
                                              ? Colors.black
                                              : Colors.red[700],
                                    ), // Indicate if required and missing
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () async {
                                    String? selectedDir =
                                        await FilePicker.platform
                                            .getDirectoryPath();
                                    if (selectedDir != null) {
                                      setStateDialog(() {
                                        servicePathController.text = selectedDir;
                                      });
                                    }
                                  },
                                  child: const Text('选择目录'), // Select Directory
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // 前置命令 (Pre-command) - Optional
                        TextField(
                          controller: preCommandController,
                          decoration: const InputDecoration(
                            labelText: '启动配置（不配置默认使用cmd/bash）',
                          ), // Pre-command (Optional)
                          ),
                        const SizedBox(height: 16),

                        // 前置参数 (Pre-parameters) - Optional
                        TextField(
                          controller: preParametersController,
                          decoration: const InputDecoration(
                            labelText: '前置参数 (可选)',
                          ), // Pre-parameters (Optional)
                          ),
                        const SizedBox(height: 16),

                        // 服务程序 (Service Program) - Optional, Text Input (store program name)
                        TextField(
                          controller: programNameController,
                          decoration: const InputDecoration(
                            labelText: '服务程序名称 (可选)',
                          ), // Service Program Name (Optional)
                          ),
                        const SizedBox(height: 16),

                        // 后置参数 (Post-parameters) - Optional
                        TextField(
                          controller: postParametersController,
                          decoration: const InputDecoration(
                            labelText: '后置参数 (可选)',
                          ), // Post-parameters (Optional)
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () {
                  // Use the captured navigator to pop
                  navigator.pop();
                },
                child: const Text('取消'), // Cancel
              ),
              TextButton(
                onPressed: () async {
                  // Capture the input values *before* await
                  final name = serviceNameController.text;
                  final servicePath =
                      servicePathController
                          .text; // Get value from new controller
                  final preCommand = preCommandController.text;
                  final preParameters = preParametersController.text; // Get value from new controller
                  final postParameters = postParametersController.text;
                  final programName =
                      programNameController
                          .text; // Get value from new controller

                  // Validation: Service name and Service Path are required
                  if (name.isNotEmpty && servicePath.isNotEmpty) {
                    final newService = Service(
                      id: const Uuid().v4(), // Generate a new ID for imported service
                      name: name,
                      type: '服务导入', // Service Import
                      path: servicePath, // Store the selected service directory
                      preCommand: preCommand,
                      preParameters: preParameters, // Include the new field
                      postParameters: postParameters,
                      programName: programName, // Store the program name
                    ); // Use Service from terminalcontroller.dart

                    // Add the service using TerminalController
                    // Check mounted *before* async call
                    if (!mounted) return;
                    await terminalController.addService(newService); // This handles saving and notifying

                    // Check mounted *before* using the navigator after await
                    if (!mounted) {
                      return;
                    }
                    navigator.pop(); // Use the captured navigator
                  } else {
                    // Show a message if required fields are empty
                    if (!mounted) {
                      return; // Check before potentially showing another dialog/snackbar
                    }
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text('请填写服务名称和服务路径'),
                      ), // Please fill in the service name and service path
                    );
                  }
                },
                child: const Text('导入'), // Import
              ),
            ],
          ),
    );
    // Dispose the controllers when the dialog is dismissed
    serviceNameController.dispose();
    servicePathController.dispose(); // Dispose the new controller
    preCommandController.dispose();
    preParametersController.dispose(); // Dispose the new controller
    postParametersController.dispose();
    programNameController.dispose(); // Dispose the new controller
  }

  // 实现添加服务功能 (Implement add service function) - Modified to use TerminalController
  void _addService() async {
    final serviceNameController = TextEditingController();
    final servicePathController =
        TextEditingController(); // New controller for Service Path
    final preCommandController = TextEditingController();
    final preParametersController = TextEditingController(); // New controller for Pre-parameters
    final postParametersController = TextEditingController();
    final programNameController =
        TextEditingController(); // Controller for program name

    // Capture the Navigator *before* the async gap caused by showDialog
    final navigator = Navigator.of(context);
    // Capture ScaffoldMessenger *before* async gaps if needed for error messages
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    // Get TerminalController instance - needed for adding the service
    final terminalController = Provider.of<TerminalController>(context, listen: false);


    await showDialog(
      context: context, // Use the original context for the dialog
      builder:
          (dialogContext) => AlertDialog(
            // Use dialogContext inside builder
            title: const Text('添加服务'), // Add Service
            content: StatefulBuilder(
              // Use StatefulBuilder to update dialog content
              builder: (BuildContext context, StateSetter setStateDialog) {
                return SizedBox( // Wrap content in SizedBox to control width
                  width: MediaQuery.of(context).size.width * 0.6, // Set width to 60% of screen width
                  child: SingleChildScrollView(
                    // Use SingleChildScrollView to prevent overflow
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 服务名称 (Service Name) - Required
                        TextField(
                          controller: serviceNameController,
                          decoration: const InputDecoration(
                            labelText: '服务名称 (必填)',
                          ), // Service Name (Required)
                        ),
                        const SizedBox(height: 16),

                        // 服务路径 (Service Path) - Required, Directory Picker
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('服务路径 (必填)'), // Service Path (Required)
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: servicePathController,
                                    decoration: InputDecoration(
                                      hintText:
                                          '请选择服务路径', // Please select service path
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 12,
                                      ),
                                    ),
                                    readOnly:
                                        true, // Make it read-only as it's filled by the picker
                                    style: TextStyle(
                                      fontSize: 14,
                                      color:
                                          servicePathController.text.isNotEmpty
                                              ? Colors.black
                                              : Colors.red[700],
                                    ), // Indicate if required and missing
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () async {
                                    String? selectedDir =
                                        await FilePicker.platform
                                            .getDirectoryPath();
                                    if (selectedDir != null) {
                                      setStateDialog(() {
                                        servicePathController.text = selectedDir;
                                      });
                                    }
                                  },
                                  child: const Text('选择目录'), // Select Directory
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // 前置命令 (Pre-command) - Optional
                        TextField(
                          controller: preCommandController,
                          decoration: const InputDecoration(
                            labelText: '启动配置（不配置默认使用cmd/bash）',
                          ), // Pre-command (Optional)
                          ),
                        const SizedBox(height: 16),

                        // 前置参数 (Pre-parameters) - Optional
                        TextField(
                          controller: preParametersController,
                          decoration: const InputDecoration(
                            labelText: '前置参数 (可选)',
                          ), // Pre-parameters (Optional)
                          ),
                        const SizedBox(height: 16),

                        // 服务程序 (Service Program) - Optional, Text Input (store program name)
                        TextField(
                          controller: programNameController,
                          decoration: const InputDecoration(
                            labelText: '服务程序名称 (可选)',
                          ), // Service Program Name (Optional)
                          ),
                        const SizedBox(height: 16),

                        // 后置参数 (Post-parameters) - Optional
                        TextField(
                          controller: postParametersController,
                          decoration: const InputDecoration(
                            labelText: '后置参数 (可选)',
                          ), // Post-parameters (Optional)
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () {
                  // Use the captured navigator to pop
                  navigator.pop();
                },
                child: const Text('取消'), // Cancel
              ),
              TextButton(
                onPressed: () async {
                  // Capture the input values *before* await
                  final name = serviceNameController.text;
                  final servicePath =
                      servicePathController
                          .text; // Get value from new controller
                  final preCommand = preCommandController.text;
                  final preParameters = preParametersController.text; // Get value from new controller
                  final postParameters = postParametersController.text;
                  final programName =
                      programNameController
                          .text; // Get value from new controller

                  // Validation: Service name and Service Path are required
                  if (name.isNotEmpty && servicePath.isNotEmpty) {
                    // --- Start of async operations ---
                    try {
                      // Get the application's installation directory
                      final executablePath = Platform.resolvedExecutable;
                      final installationDir = p.dirname(executablePath);

                      // Construct the destination directory path for the copied service folder
                      // This will be within the application's data/services directory
                      final destinationPath = p.join(
                        installationDir,
                        'data',
                        'services',
                        name,
                      );

                      final sourceDirectory = Directory(servicePath);
                      final destinationDirectory = Directory(destinationPath);

                      // Check if the source directory exists
                      if (!await sourceDirectory.exists()) {
                        if (!mounted) {
                          return;
                        }
                        scaffoldMessenger.showSnackBar(
                           SnackBar(
                            content: Text(
                              '源服务路径不存在: $servicePath',
                            ), // Source service path does not exist
                          ),
                        );
                        return; // Stop processing if source doesn't exist
                      }

                      // Copy the source directory to the destination
                      await _copyDirectory(
                        sourceDirectory,
                        destinationDirectory,
                      );

                      // Create the Service object with the NEW copied path and other details
                      final newService = Service(
                        id: const Uuid().v4(), // Generate a new ID for added service
                        name: name,
                        type: '服务添加', // Service Add
                        path: destinationPath, // Store the ABSOLUTE copied path
                        preCommand: preCommand,
                        preParameters: preParameters, // Include the new field
                        postParameters: postParameters,
                        programName: programName, // Store the program name
                      ); // Use Service from terminalcontroller.dart
  
                      // Add the service using TerminalController
                      // Check mounted *before* async call
                      if (!mounted) return;
                      await terminalController.addService(newService); // This handles saving and notifying
  
                      // Check mounted *before* using navigator after all awaits
                      if (!mounted) {
                        return;
                      }
                      navigator.pop(); // Use the captured navigator
                    } catch (e) {
                      // Handle errors during file operations
                      debugPrint('Error adding service: $e');
                      // Check mounted before showing error message
                      if (!mounted) {
                        return;
                      }
                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Text('添加服务失败: $e'),
                        ), // Failed to add service
                      );
                    }
                    // --- End of state updates and saving ---
                  } else {
                    // Show a message if required fields are empty
                    if (!mounted) {
                      return; // Check before showing message
                    }
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text('请填写服务名称和服务路径'),
                      ), // Please fill in the service name and service path
                    );
                  }
                },
                child: const Text('添加'), // Add
              ),
            ],
          ),
    );
    // Dispose the controllers when the dialog is dismissed
    serviceNameController.dispose();
    servicePathController.dispose(); // Dispose the new controller
    preCommandController.dispose();
    preParametersController.dispose(); // Dispose the new controller
    postParametersController.dispose();
    programNameController.dispose(); // Dispose the new controller
  }

  @override
  Widget build(BuildContext context) {
    // Get TerminalController instance from Provider
    final terminalController = Provider.of<TerminalController>(context);

    return Scaffold(
      // appBar: AppBar( // Optional AppBar
      //   title: const Text('服务列表'), // Service List
      // ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              // Use Row to place buttons at ends
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween, // Push items to the ends
              children: [
                Wrap(
                  // Keep Wrap for existing buttons for responsiveness
                  spacing: 16.0, // Horizontal space between buttons
                  runSpacing: 8.0, // Vertical space if buttons wrap
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.input), // Example Icon
                      onPressed: _importService,
                      label: const Text('导入服务'), // Import Service
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(
                        Icons.add_circle_outline,
                      ), // Example Icon
                      onPressed: _addService,
                      label: const Text('添加服务'), // Add Service
                    ),
                  ],
                ),
                // New Settings Button
                ElevatedButton.icon(
                  icon: const Icon(Icons.settings),
                  onPressed: () {
                    // TODO: Implement settings navigation
                    // Example: Navigator.pushNamed(context, '/settings');
                  },
                  label: const Text('设置'), // Settings
                ),
              ],
            ),
          ),
          const Divider(), // Add a visual separator
          Expanded(
            // Use terminalController.services instead of local _services
            child: terminalController.services.isEmpty
                ? const Center(
                  // Show a message when the list is empty
                  child: Text(
                        '暂无服务', // No services yet
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16.0), // Add padding around the grid
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 300, // Adjust for ~4 cards per row
                          mainAxisSpacing: 16.0,
                          crossAxisSpacing: 16.0,
                          childAspectRatio: 1.0, // Adjust aspect ratio if needed
                        ),
                        itemCount: terminalController.services.length, // Use length from controller
                        itemBuilder: (context, index) {
                          // Get service from controller
                          final service = terminalController.services[index];
                          final colorScheme = Theme.of(context).colorScheme;
                          final textTheme = Theme.of(context).textTheme;

                          // Determine if the service is currently running using TerminalController
                          final bool isRunning = terminalController.isServiceRunning(service.id);

                          return Card(
                            elevation: 2,
                            shadowColor: colorScheme.shadow.withAlpha((255 * 0.2).round()),
                            surfaceTintColor: colorScheme.surfaceTint,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start, // Align text left
                                children: [
                                  // Service Name
                                  Text(
                                    service.name,
                                    style: textTheme.titleLarge?.copyWith(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8.0),
                                  // Service Path
                                  Text(
                                    service.path,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    maxLines: 2, // Allow path to wrap slightly
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const Spacer(), // Push buttons to the bottom
                                  // Action Buttons
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end, // Align buttons to the right
                                    children: [
                                      // Terminal Icon Button
                                      if (isRunning) // Only show if running
                                        IconButton(
                                          icon: Icon(Icons.terminal, color: colorScheme.primary),
                                          tooltip: '查看终端', // View Terminal
                                          onPressed: () {
                                            _showTerminalOutput(service, terminalController);
                                          },
                                        )
                                      else
                                        const SizedBox(width: 48), // Placeholder to maintain alignment when not running
                                      // Merged Start/Stop Button
                                      IconButton(
                                        icon: Icon(
                                          isRunning ? Icons.stop : Icons.play_arrow,
                                          color: colorScheme.primary,
                                        ),
                                        tooltip: isRunning ? '关闭' : '开启', // Stop / Start
                                        onPressed: () async {
                                          if (isRunning) {
                                            await terminalController.stopService(service.id);
                                          } else {
                                            await terminalController.startService(service);
                                          }
                                          // State update is handled by Provider listener
                                        },
                                      ),
                                      // Settings Button
                                      IconButton(
                                        icon: Icon(Icons.settings, color: colorScheme.primary),
                                        tooltip: '设置', // Settings
                                        onPressed: () async {
                                          final updatedService = await showDialog<Service>(
                                            context: context,
                                            builder: (BuildContext context) {
                                              return EditServiceDialog(service: service);
                                            },
                                          );
                                          if (updatedService != null) {
                                            if (!mounted) return;
                                            await terminalController.updateService(updatedService);
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  // Delete function is now handled by TerminalController.deleteService
  // We might add a confirmation dialog here that calls terminalController.deleteService


  // Method to show terminal output in a dialog - Type should be correct now
  void _showTerminalOutput(Service service, TerminalController terminalController) {
    final outputNotifier = terminalController.getOutputNotifier(service.id);
    if (outputNotifier == null) {
      // Should not happen if the terminal icon is only shown when running, but good for safety
      debugPrint('No terminal output found for service ${service.name}');
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('${service.name} - 终端输出'), // Service Name - Terminal Output
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8, // 80% of screen width
            height: MediaQuery.of(context).size.height * 0.6, // 60% of screen height
            child: ValueListenableBuilder<String>(
              valueListenable: outputNotifier,
              builder: (context, output, child) {
                // Use a SingleChildScrollView and SelectableText for scrollable and selectable output
                return SingleChildScrollView(
                  child: SelectableText(
                    output,
                    style: const TextStyle(fontFamily: 'monospace'), // Use a monospace font
                  ),
                );
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('关闭'), // Close
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // No need for dispose method here anymore
}
