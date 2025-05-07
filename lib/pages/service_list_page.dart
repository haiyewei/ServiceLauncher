import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert'; // Needed for JSON operations
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart'; // Import provider

import '../components/edit_service_dialog.dart'; // Import the EditServiceDialog
import '../components/terminalcontroller.dart'; // Import TerminalController (which now includes Service)
import 'package:uuid/uuid.dart'; // Keep uuid for dialogs
import '../services/notify/notify.dart'; // Import NotifyController

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
  bool _isDeleteModeActive = false;
  final Set<String> _selectedServiceIds = {}; // To keep track of selected service IDs for deletion

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

  Future<void> _performDeleteSelectedServices(TerminalController terminalController) async {
    if (_selectedServiceIds.isEmpty) {
      // Removed SnackBar per user request
      return;
    }

    final servicesToDelete = terminalController.services
        .where((s) => _selectedServiceIds.contains(s.id))
        .toList();

    if (servicesToDelete.isEmpty) {
      // Removed SnackBar per user request
      // This case should ideally not be hit if _selectedServiceIds is not empty
      // and services are correctly loaded in terminalController.
      debugPrint("Warning: _selectedServiceIds is not empty but no services found to delete.");
      return;
    }

    // --- Read, Remove, Write services.json ---
    try {
      // Get the application's installation directory for data/services.json
      final executablePath = Platform.resolvedExecutable;
      final installationDir = p.dirname(executablePath);
      final dataDir = Directory(p.join(installationDir, 'data'));
      if (!await dataDir.exists()) {
        await dataDir.create(recursive: true); // Ensure 'data' directory exists
      }
      final servicesFile = File(p.join(dataDir.path, 'services.json'));

      List<dynamic> servicesJsonList = [];
      if (await servicesFile.exists()) {
        final content = await servicesFile.readAsString();
        if (content.isNotEmpty) {
          try {
            servicesJsonList = jsonDecode(content) as List<dynamic>;
          } catch (e) {
            debugPrint("Error decoding services.json: $e. Initializing with empty list.");
            // If JSON is malformed, treat as empty or handle error appropriately
          }
        }
      }

      // Remove selected services from the list
      servicesJsonList.removeWhere((serviceData) {
        // Ensure serviceData is a Map and contains 'id'
        if (serviceData is Map && serviceData.containsKey('id')) {
          return _selectedServiceIds.contains(serviceData['id'] as String?);
        }
        return false; // If not a map or no id, don't remove (or log error)
      });
      
      // Write the updated list back to the file
      await servicesFile.writeAsString(jsonEncode(servicesJsonList));

      // Update UI by removing services from TerminalController
      // This assumes TerminalController.deleteService handles UI refresh (e.g., via notifyListeners)
      // and also updates its internal state from the now modified services.json or by direct removal.
      // A more robust way would be for TerminalController to reload its services from services.json
      // after this operation, or for deleteService to also handle the file system removal.
      // For now, we'll call deleteService for each, assuming it updates the UI.
      for (final serviceId in _selectedServiceIds) {
        await terminalController.deleteService(serviceId);
      }
      
      if (!mounted) return;
      // Show success notification using NotifyController
      final notifyController = NotifyController();
      final deletedServiceNames = servicesToDelete.map((s) => s.name).join(', ');
      notifyController.showNotify(
        NotifyData(
          message: '成功删除服务: $deletedServiceNames',
          type: NotifyType.app,
          time: DateTime.now(),
          icon: Icons.check_circle, // Optional: an icon for success
        ),
      );
      // Optionally, keep the SnackBar or remove it if the app notification is sufficient
      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(content: Text('选中的服务已删除')),
      // );

    } catch (e) {
      if (!mounted) return;
      // Removed SnackBar per user request, using NotifyController for error
      debugPrint('Error deleting services: $e');
      final notifyController = NotifyController();
      notifyController.showNotify(
        NotifyData(
          message: '删除服务失败: $e',
          type: NotifyType.app,
          time: DateTime.now(),
          icon: Icons.error_outline,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDeleteModeActive = false;
          _selectedServiceIds.clear(); // Clear selection after deletion attempt
        });
      }
    }
  }

  void _handleDeleteIconTap(TerminalController terminalController) {
    setState(() {
      if (_isDeleteModeActive) {
        // User clicked "Done/Cancel"
        _isDeleteModeActive = false;
        // _selectedServiceIds.clear(); // Optionally clear selection when exiting delete mode without confirming
      } else {
        // User clicked "Delete" to enter delete mode
        _isDeleteModeActive = true;
        if (_selectedServiceIds.isNotEmpty) {
          _showConfirmDeleteDialog(terminalController);
        }
      }
    });
  }

  void _showConfirmDeleteDialog(TerminalController terminalController) {
    final selectedServicesNames = terminalController.services
        .where((s) => _selectedServiceIds.contains(s.id))
        .map((s) => s.name)
        .join(', ');

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确认删除选中的服务：[$selectedServicesNames] 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop(); // Close dialog first
              await _performDeleteSelectedServices(terminalController);
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    // Get TerminalController instance from Provider
    final terminalController = Provider.of<TerminalController>(context);

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Wrap(
                  spacing: 16.0,
                  runSpacing: 8.0,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.input),
                      onPressed: _isDeleteModeActive ? null : _importService, // Disable in delete mode
                      label: const Text('导入服务'),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: _isDeleteModeActive ? null : _addService, // Disable in delete mode
                      label: const Text('添加服务'),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Visibility(
                      visible: _isDeleteModeActive,
                      child: IconButton(
                        icon: const Icon(Icons.delete_forever, color: Colors.red),
                        tooltip: '确认删除选中的服务',
                        onPressed: () {
                           if (_selectedServiceIds.isEmpty) {
                            // Removed SnackBar per user request
                            // Optionally, provide a different non-SnackBar feedback or do nothing.
                            // For now, doing nothing as per "不允许出现底部通知".
                            debugPrint("Attempted to confirm delete with no services selected.");
                          } else {
                            _showConfirmDeleteDialog(terminalController);
                          }
                        },
                      ),
                    ),
                    IconButton(
                      icon: Icon(_isDeleteModeActive ? Icons.check_circle_outline : Icons.delete_outline,
                                 color: _isDeleteModeActive ? Theme.of(context).colorScheme.primary : null,
                      ),
                      tooltip: _isDeleteModeActive ? '完成/取消删除模式' : '批量删除服务',
                      onPressed: () => _handleDeleteIconTap(terminalController),
                    ),
                  ],
                )
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: terminalController.services.isEmpty
                ? const Center(
                    child: Text(
                      '暂无服务',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16.0),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 300, // Keep this for card size
                      mainAxisSpacing: 16.0,
                      crossAxisSpacing: 16.0,
                      childAspectRatio: 0.9, // Adjusted for checkbox visibility
                    ),
                    itemCount: terminalController.services.length,
                    itemBuilder: (context, index) {
                      final service = terminalController.services[index];
                      final colorScheme = Theme.of(context).colorScheme;
                      final textTheme = Theme.of(context).textTheme;
                      final bool isRunning = terminalController.isServiceRunning(service.id);
                      final bool isSelected = _selectedServiceIds.contains(service.id);

                      return GestureDetector(
                        onTap: _isDeleteModeActive
                            ? () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedServiceIds.remove(service.id);
                                  } else {
                                    _selectedServiceIds.add(service.id);
                                  }
                                });
                              }
                            : null, // No action if not in delete mode
                        child: Card(
                          elevation: _isDeleteModeActive && isSelected ? 6 : 2,
                          color: _isDeleteModeActive && isSelected
                              ? colorScheme.primaryContainer.withAlpha((255 * 0.4).round())
                              : colorScheme.surface,
                          shadowColor: colorScheme.shadow.withAlpha((255 * (_isDeleteModeActive && isSelected ? 0.4 : 0.2)).round()),
                          surfaceTintColor: colorScheme.surfaceTint,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: _isDeleteModeActive && isSelected
                                ? BorderSide(color: colorScheme.primary, width: 2.5)
                                : BorderSide(color: colorScheme.outlineVariant.withAlpha((255 * 0.5).round()), width: 1),
                          ),
                          child: Stack(
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16,16,16,10), // Adjusted padding
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Top section with Name and Checkbox (if in delete mode)
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            service.name,
                                            style: textTheme.titleLarge?.copyWith(
                                              color: colorScheme.primary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (_isDeleteModeActive)
                                          SizedBox( // Constrain checkbox size
                                            width: 24,
                                            height: 24,
                                            child: Checkbox(
                                              value: isSelected,
                                              onChanged: (bool? value) {
                                                setState(() {
                                                  if (value == true) {
                                                    _selectedServiceIds.add(service.id);
                                                  } else {
                                                    _selectedServiceIds.remove(service.id);
                                                  }
                                                });
                                              },
                                              activeColor: colorScheme.primary,
                                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 6.0),
                                    Text(
                                      service.path,
                                      style: textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const Spacer(),
                                    // Bottom action buttons
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        if (isRunning && !_isDeleteModeActive)
                                          IconButton(
                                            icon: Icon(Icons.terminal, color: colorScheme.secondary),
                                            tooltip: '查看终端',
                                            onPressed: () => _showTerminalOutput(service, terminalController),
                                          )
                                        else if (!_isDeleteModeActive) // Placeholder if not running and not in delete mode
                                          const SizedBox(width: 48),

                                        if (!_isDeleteModeActive) // Start/Stop button
                                          IconButton(
                                            icon: Icon(
                                              isRunning ? Icons.stop_circle_outlined : Icons.play_circle_outline,
                                              color: isRunning ? Colors.redAccent : colorScheme.primary,
                                            ),
                                            tooltip: isRunning ? '关闭' : '开启',
                                            onPressed: () async {
                                              if (isRunning) {
                                                await terminalController.stopService(service.id);
                                              } else {
                                                await terminalController.startService(service);
                                              }
                                            },
                                          ),
                                        if (!_isDeleteModeActive) // Settings button
                                          IconButton(
                                            icon: Icon(Icons.settings_outlined, color: colorScheme.secondary),
                                            tooltip: '设置',
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
                                        // If in delete mode, these buttons are hidden, Spacer takes up space or it's empty
                                        if (_isDeleteModeActive) const Expanded(child: SizedBox()),
                                      ],
                                    ),
                                  ],
                                ),
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
