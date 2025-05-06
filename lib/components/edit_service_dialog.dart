import 'package:flutter/material.dart';
import '../components/terminalcontroller.dart'; // Import TerminalController (which includes Service)

class EditServiceDialog extends StatefulWidget {
  final Service service;

  const EditServiceDialog({super.key, required this.service});

  @override
  EditServiceDialogState createState() => EditServiceDialogState();
}

class EditServiceDialogState extends State<EditServiceDialog> {
  late String _serviceId; // Store the service ID
  late TextEditingController _nameController;
  late TextEditingController _pathController;
  late TextEditingController _preCommandController;
  late TextEditingController _preParametersController; // Add controller for preParameters
  late TextEditingController _postParametersController;
  late TextEditingController _programNameController;

  @override
  void initState() {
    super.initState();
    _serviceId = widget.service.id; // Get the ID from the widget
    _nameController = TextEditingController(text: widget.service.name);
    _pathController = TextEditingController(text: widget.service.path);
    _preCommandController = TextEditingController(text: widget.service.preCommand);
    _preParametersController = TextEditingController(text: widget.service.preParameters); // Initialize preParameters controller
    _postParametersController = TextEditingController(text: widget.service.postParameters);
    _programNameController = TextEditingController(text: widget.service.programName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pathController.dispose();
    _preCommandController.dispose();
    _preParametersController.dispose(); // Dispose preParameters controller
    _postParametersController.dispose();
    _programNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('编辑服务'), // Edit Service
      content: SizedBox( // Wrap content in SizedBox to control width
        width: MediaQuery.of(context).size.width * 0.6, // Set width to 60% of screen width
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 服务名称 (Service Name) - Required, but maybe not editable? Let's make it read-only for now.
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: '服务名称'), // Service Name
              ),
              const SizedBox(height: 16),

              // 服务路径 (Service Path) - Required
              TextField(
                controller: _pathController,
                decoration: const InputDecoration(labelText: '服务路径'), // Service Path
              ),
              const SizedBox(height: 16),

              // 前置命令 (Pre-command) - Optional
              TextField(
                controller: _preCommandController,
                decoration: const InputDecoration(labelText: '前置命令'), // Pre-command
              ),
              const SizedBox(height: 16),

              // 前置参数 (Pre-parameters) - Optional
              TextField(
                controller: _preParametersController, // Add TextField for preParameters
                decoration: const InputDecoration(labelText: '前置参数'), // Pre-parameters
              ),
              const SizedBox(height: 16),

              // 服务程序名称 (Service Program Name) - Optional
              TextField(
                controller: _programNameController,
                decoration: const InputDecoration(labelText: '服务程序名称'), // Service Program Name
              ),
              const SizedBox(height: 16),

              // 后置参数 (Post-parameters) - Optional
              TextField(
                controller: _postParametersController,
                decoration: const InputDecoration(labelText: '后置参数'), // Post-parameters
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(); // Cancel editing
          },
          child: const Text('取消编辑'), // Cancel Editing
        ),
        TextButton(
          onPressed: () {
            // Create an updated Service object
            final updatedService = Service(
              id: _serviceId, // Include the original ID
              name: _nameController.text, // Name is read-only
              type: widget.service.type, // Type is not editable
              path: _pathController.text,
              preCommand: _preCommandController.text,
              preParameters: _preParametersController.text, // Include preParameters
              postParameters: _postParametersController.text,
              programName: _programNameController.text,
            );
            Navigator.of(context).pop(updatedService); // Return the updated service
          },
          child: const Text('保存编辑'), // Save Editing
        ),
      ],
    );
  }
}