import 'dart:io';
import 'dart:async'; // Import for Completer
import 'dart:convert'; // Import for utf8
import 'package:flutter/material.dart'; // For ValueNotifier and ChangeNotifier
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart'; // Import uuid package
// No longer need to import from service_list_page as Service class is moved here
import '../services/notify/notify.dart'; // Import NotifyController and related classes
import 'package:collection/collection.dart'; // Import for firstWhereOrNull


// --- Service Class Definition Moved Here ---
class Service {
  final String id; // Unique identifier for the service
  final String name;
  final String type; // "服务导入" (Import Service) or "服务添加" (Add Service)
  final String path; // This will now store the directory for "服务程序"
  final String preCommand; // 前置命令
  final String preParameters; // 前置参数
  final String postParameters; // 后置参数
  final String programName; // 服务程序名称
  final String? logFilePath; // 可选的日志文件路径

  Service({
    required this.id, // ID is now required
    required this.name,
    required this.type,
    required this.path,
    this.preCommand = '', // Default to empty string
    this.preParameters = '', // Default to empty string for new field
    this.postParameters = '', // Default to empty string
    this.programName = '', // Default to empty string
    this.logFilePath, // Initialize logFilePath
  });

  // 从 JSON 创建 Service 对象 (Create Service object from JSON)
  factory Service.fromJson(Map<String, dynamic> json) {
    // Generate a new ID if it doesn't exist (for backward compatibility)
    final String id = json['id'] ?? const Uuid().v4();
    return Service(
      id: id,
      name: json['name'] ?? 'Unknown Service', // Add default name
      type: json['type'] ?? 'Unknown Type', // Add default type
      path: json['path'] ?? '', // Add default path
      preCommand:
          json['preCommand'] ?? '', // Handle potential null or missing field
      preParameters:
          json['preParameters'] ?? '', // Handle potential null or missing field for new field
      postParameters:
          json['postParameters'] ??
          '', // Handle potential null or missing field
      programName:
          json['programName'] ?? '', // Handle potential null or missing field
      logFilePath: json['logFilePath'] as String?, // Add logFilePath from JSON
    );
  }

  // 将 Service 对象转换为 JSON (Convert Service object to JSON)
  Map<String, dynamic> toJson() {
    return {
      'id': id, // Include the ID in JSON
      'name': name,
      'type': type,
      'path': path,
      'preCommand': preCommand,
      'preParameters': preParameters, // Include the new field in JSON
      'postParameters': postParameters,
      'programName': programName,
      'logFilePath': logFilePath, // Include logFilePath in JSON
    };
  }
}
// --- End of Service Class Definition ---

// --- PersistedServiceRunState Class Definition ---
class PersistedServiceRunState {
  String desiredState; // "running" or "stopped"
  int? lastKnownPid;
  bool intentionallyStopped;
  bool autoStartPreference; // User's preference for this service to auto-start

  PersistedServiceRunState({
    required this.desiredState,
    this.lastKnownPid,
    required this.intentionallyStopped,
    required this.autoStartPreference,
  });

  factory PersistedServiceRunState.fromJson(Map<String, dynamic> json) {
    return PersistedServiceRunState(
      desiredState: json['desiredState'] as String? ?? json['desired_state'] as String? ?? 'stopped',
      lastKnownPid: json['lastKnownPid'] as int? ?? json['last_known_pid'] as int?,
      intentionallyStopped: json['intentionallyStopped'] as bool? ?? json['intentionally_stopped'] as bool? ?? false,
      autoStartPreference: json['autoStartPreference'] as bool? ?? json['auto_start_preference'] as bool? ?? true, // Default to true
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'desiredState': desiredState,
      'lastKnownPid': lastKnownPid,
      'intentionallyStopped': intentionallyStopped,
      'autoStartPreference': autoStartPreference,
    };
  }

  // Helper for creating a default state for a new service
  factory PersistedServiceRunState.defaultState({bool autoStart = true}) {
    return PersistedServiceRunState(
      desiredState: 'stopped',
      lastKnownPid: null,
      intentionallyStopped: false,
      autoStartPreference: autoStart,
    );
  }
}
// --- End of PersistedServiceRunState Class Definition ---

class TerminalController extends ChangeNotifier {
  // Extend ChangeNotifier
  // Map to store running processes, keyed by service ID
  // final Map<String, Process> _runningProcesses = {}; // Replaced
  final Map<String, PersistedServiceRunState> _serviceRunStates = {}; // Stores serviceId to its run state
  final Map<String, Process> _activeProcesses = {}; // Stores serviceId to actual Process object

  // Map to store terminal output for each service, keyed by service ID
  final Map<String, ValueNotifier<String>> _terminalOutput = {};
  // Map to store start times for each service, keyed by service ID
  final Map<String, DateTime> _startTimes = {};
  // Notifier for the auto-scroll feature state
  final ValueNotifier<bool> autoScrollToEnd = ValueNotifier<bool>(true);
 
  // List to store all configured services
  List<Service> _services = [];
  // Getter to access the services list from outside
  List<Service> get services => _services;
  // Getter for running process IDs (service IDs that are considered running)
  Set<String> get runningProcessIds => _serviceRunStates.entries
      .where((entry) => entry.value.desiredState == 'running' && entry.value.lastKnownPid != null)
      .map((entry) => entry.key)
      .toSet();
  // Getter for start times map
  Map<String, DateTime> get startTimes => _startTimes;

  final Completer<void> _initializedCompleter = Completer<void>();
  Future<void> get initializationComplete => _initializedCompleter.future;

  // Getter for a specific service's PID
  int? getServicePid(String serviceId) {
    return _serviceRunStates[serviceId]?.lastKnownPid;
  }

  // Getter for a specific service's full run state
  PersistedServiceRunState? getServiceRunState(String serviceId) {
    return _serviceRunStates[serviceId];
  }
  
  // Path for storing running state
  String _getRunningStateFilePath() {
    // Get the directory of the executable.
    final executablePath = Platform.resolvedExecutable;
    // Get the parent directory of the executable.
    final executableDir = File(executablePath).parent.path;
    // Construct the path to data/running.json relative to the executable directory.
    return p.join(executableDir, 'data', 'running.json');
  }
  
  // Save the current running state (_servicePids) to running.json
  Future<void> _saveRunningState() async {
    final filePath = _getRunningStateFilePath();
    try {
      final file = File(filePath);
      final dataDir = Directory(p.dirname(filePath));
      if (!await dataDir.exists()) {
        await dataDir.create(recursive: true);
        debugPrint('Created directory: ${dataDir.path}');
      }
      // Convert Map<String, PersistedServiceRunState> to Map<String, dynamic> for jsonEncode
      final Map<String, dynamic> jsonMap = _serviceRunStates.map(
        (key, value) => MapEntry(key, value.toJson()),
      );
      await file.writeAsString(jsonEncode(jsonMap));
      debugPrint('Running state saved to $filePath');
    } catch (e) {
      debugPrint('Error saving running state to $filePath: $e');
      // Optionally notify user, but avoid if it's too noisy
    }
  }
  
  // Helper method to set up logging for a running service
  Future<void> _setupLoggingForRunningService(String serviceId, Service serviceDefinition, int pid, String baseMessage) async {
    if (!_terminalOutput.containsKey(serviceId) || _terminalOutput[serviceId] == null) {
      _terminalOutput[serviceId] = ValueNotifier<String>('');
    }
    _terminalOutput[serviceId]!.value = baseMessage; // Start with the base message
  
    if (serviceDefinition.logFilePath != null && serviceDefinition.logFilePath!.isNotEmpty) {
      final logFile = File(serviceDefinition.logFilePath!);
      try {
        if (await logFile.exists()) {
          _terminalOutput[serviceId]!.value += '[Tailing log file: ${serviceDefinition.logFilePath} for service \'${serviceDefinition.name}\' (PID: $pid)]\n';
          
          const int maxLines = 200;
          const int maxBytes = 4 * 1024; // 4KB
          final lines = await _readLastLines(logFile, maxLines, maxBytes);
          _terminalOutput[serviceId]!.value += lines.join('\n') + (lines.isNotEmpty ? '\n' : '');
  
          _watchLogFile(serviceId, logFile); // This method already appends a "watching" message
          debugPrint('Service ${serviceDefinition.name} (ID: $serviceId) PID $pid. Tailing log: ${serviceDefinition.logFilePath}');
        } else {
          _terminalOutput[serviceId]!.value += '[Log file specified (${serviceDefinition.logFilePath}) but not found. Live output may be unavailable.]\n';
          debugPrint('Service ${serviceDefinition.name} (ID: $serviceId) PID $pid. Log file not found: ${serviceDefinition.logFilePath}');
        }
      } catch (e) {
        _terminalOutput[serviceId]!.value += '[Error accessing log file (${serviceDefinition.logFilePath}): $e. Live output may be unavailable.]\n';
        debugPrint('Error accessing log file for ${serviceDefinition.name} (PID $pid): $e');
      }
    } else {
      _terminalOutput[serviceId]!.value += '[Service \'${serviceDefinition.name}\' (PID: $pid). Live output capture requires a configured log file, which is not specified or accessible.]\n';
      debugPrint('Service ${serviceDefinition.name} (ID: $serviceId) PID $pid. No log file configured.');
    }
  }
  
  // Load running state from running.json
  Future<void> _loadRunningState() async {
    final filePath = _getRunningStateFilePath();
    try {
      final file = File(filePath);
      if (await file.exists()) {
        final contents = await file.readAsString();
        if (contents.isEmpty) {
          debugPrint('Running state file $filePath is empty.');
          // Ensure all configured services have a default run state entry if file is empty
          for (var service in _services) { // This loop might be redundant if _loadServices hasn't run yet, or if _services is empty.
                                          // It's safer to do this after _loadServices.
            if (!_serviceRunStates.containsKey(service.id)) {
              _serviceRunStates[service.id] = PersistedServiceRunState.defaultState();
            }
          }
          return;
        }
        final Map<String, dynamic> loadedJson = jsonDecode(contents);
        
        // Use a for...of loop to allow await inside
        for (final entry in loadedJson.entries) {
          final serviceId = entry.key;
          final stateJson = entry.value;

          if (stateJson is Map<String, dynamic>) {
            // We need to ensure _services is loaded before this, or handle serviceDefinition being null
            final serviceDefinition = _services.firstWhereOrNull((s) => s.id == serviceId);
            if (serviceDefinition != null) { // Only process states for known services
              _serviceRunStates[serviceId] = PersistedServiceRunState.fromJson(stateJson);
              
              // Logging setup for recovered running services
              final currentLoadedState = _serviceRunStates[serviceId];
              if (currentLoadedState?.desiredState == 'running' && currentLoadedState?.lastKnownPid != null) {
                 _startTimes[serviceId] = DateTime.now(); // Placeholder for recovered start time
                 String recoveryMessage = 'Service \'${serviceDefinition.name}\' (PID: ${currentLoadedState?.lastKnownPid}) state loaded from ${p.basename(filePath)}.\nAttempting to re-attach or verify...\n';
                 // Call _setupLoggingForRunningService here
                 if (currentLoadedState?.lastKnownPid != null) { // Check lastKnownPid again for safety, though outer condition implies it
                    await _setupLoggingForRunningService(serviceId, serviceDefinition, currentLoadedState!.lastKnownPid!, recoveryMessage);
                 } else {
                    // Fallback if PID is somehow null despite desiredState being running
                    if (!_terminalOutput.containsKey(serviceId) || _terminalOutput[serviceId] == null) {
                        _terminalOutput[serviceId] = ValueNotifier<String>('');
                    }
                    _terminalOutput[serviceId]!.value = '$recoveryMessage[Error: Recovered with running state but PID is null. Cannot tail logs.]\n';
                 }
                 debugPrint('Service ${serviceDefinition.name} (ID: $serviceId) state loaded from ${p.basename(filePath)}: desiredState=${currentLoadedState?.desiredState}, pid=${currentLoadedState?.lastKnownPid}');
              }
            } else {
              debugPrint('Service ID "$serviceId" from ${p.basename(filePath)} not found in current service configurations. Its persisted state will be ignored and removed on next save if still not configured.');
            }
          } else {
             debugPrint('Invalid state format for service ID "$serviceId" in ${p.basename(filePath)}. Expected a Map.');
          }
        }
        debugPrint('Running state loaded from $filePath');
      } else {
        debugPrint('Running state file $filePath not found. Initializing default states for all configured services.');
        // If running.json doesn't exist, all services get a default state.
        // This assumes _services has been loaded by _loadServices() already.
      }
    } catch (e) {
      debugPrint('Error loading running state from $filePath: $e. Initializing with default states.');
      _serviceRunStates.clear(); // Clear any partially loaded states
      // Attempt to delete corrupt file
      try {
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
          debugPrint('Deleted corrupt running state file: $filePath');
        }
      } catch (deleteError) {
        debugPrint('Failed to delete corrupt running state file $filePath: $deleteError');
      }
    }
    // Ensure all configured services (from _services list) have a run state entry.
    // This is crucial if running.json was missing, empty, or corrupt, or if new services were added to services.json
    // This loop should ideally run *after* _services has been populated by _loadServices.
    // The _initializeController method calls _loadServices then _loadRunningState.
    for (var service in _services) {
      if (!_serviceRunStates.containsKey(service.id)) {
        _serviceRunStates[service.id] = PersistedServiceRunState.defaultState(
            // You might want to make autoStart configurable per service definition in services.json later
            // For now, using the default from PersistedServiceRunState.defaultState()
            );
        debugPrint('Created default run state for service not found in running.json: ${service.name} (ID: ${service.id})');
      }
    }
  }
  
  // Constructor - Load services when the controller is created
  TerminalController() {
    _initializeController();
  }
  
  Future<void> _initializeController() async {
    await _loadServices(); // Load service configurations first
    await _loadRunningState(); // Load persisted running state
    // await _checkAndSetInitialRunningServices(); // This is now handled externally by StartupService.checkAndRecoverServices
    await _saveRunningState(); // Save the consolidated initial state (e.g. if _loadRunningState cleaned up anything)
    notifyListeners(); // Notify UI after all initial setup
    if (!_initializedCompleter.isCompleted) {
      _initializedCompleter.complete();
    }
  }

  // This method's functionality is being superseded by the external call to StartupService.checkAndRecoverServices
  // which will directly use TerminalController's public methods.
  // Keeping it commented out for reference during refactoring.
  /*
  Future<void> _checkAndSetInitialRunningServices() async {
    // final result = await _startupService.checkAndRecoverService(); // StartupService API changed
    // final status = result['status'] as ServiceStatus?; // ServiceStatus is no longer defined here
    // final data = result['data'];
  
    // if (status == ServiceStatus.running && data is ServiceConfig) { // ServiceConfig might also be from the old start_up.dart
    //   final runningConfig = data;
    //   if (runningConfig.name != null && runningConfig.pid != null) {
    //     final serviceDefinition =
    //         _services.firstWhereOrNull((s) => s.name == runningConfig.name);
  
    //     if (serviceDefinition != null) {
    //       _servicePids[serviceDefinition.id] = runningConfig.pid!;
    //       _startTimes[serviceDefinition.id] = runningConfig.startTime ?? DateTime.now();
          
    //       String initialMessage = 'Service \'${serviceDefinition.name}\' (PID: ${runningConfig.pid}) recovered by StartupService.\nLast known command: ${runningConfig.command ?? "N/A"}\nStatus at startup: Running.\n';
    //       await _setupLoggingForRunningService(serviceDefinition.id, serviceDefinition, runningConfig.pid!, initialMessage);
          
    //       debugPrint('Service ${serviceDefinition.name} (ID: ${serviceDefinition.id}) state updated/confirmed by StartupService with PID ${runningConfig.pid}.');
    //     } else {
    //       debugPrint('StartupService recovered service "${runningConfig.name}" (PID: ${runningConfig.pid}) but it was not found in configured services.json. It will not be actively managed by TerminalController.');
    //     }
    //   } else {
    //     debugPrint('StartupService recovered a service but its name or PID is null. Config: ${runningConfig.toJson()}');
    //   }
    // } else if (data is Map && data.containsKey('message')) {
    //   // debugPrint('StartupService check result: Status: $status, Message: ${data['message']}');
    // } else {
    //   // debugPrint('StartupService check result: Status: $status, Data: $data (Type: ${data.runtimeType})');
    // }
  }
  */
  
  Future<List<String>> _readLastLines(File file, int maxLines, int maxBytes) async {
    try {
      final length = await file.length();
      if (length == 0) return [];

      final startByte = (length > maxBytes) ? length - maxBytes : 0;
      final randomAccessFile = await file.open(mode: FileMode.read);
      await randomAccessFile.setPosition(startByte);

      final contents = await randomAccessFile.read(length - startByte);
      await randomAccessFile.close();

      final lines = utf8.decode(contents).split('\n');
      if (lines.length > maxLines) {
        return lines.sublist(lines.length - maxLines);
      }
      return lines;
    } catch (e) {
      debugPrint("Error reading last lines from log file ${file.path}: $e");
      return ['[Error reading log file: $e]'];
    }
  }

  void _watchLogFile(String serviceId, File logFile) async {
    try {
      if (!await logFile.exists()) {
        _terminalOutput[serviceId]?.value += '\n[Log file ${logFile.path} disappeared. Tailing stopped.]';
        return;
      }

      var lastSize = await logFile.length();
      final Stream<FileSystemEvent> watcher = logFile.watch(events: FileSystemEvent.modify | FileSystemEvent.create); // Watch for modify and create

      // Add a small delay before starting to read to avoid reading the same content multiple times on rapid writes
      await Future.delayed(const Duration(milliseconds: 250));


      watcher.listen(
        (event) async {
          try {
            if (event.type == FileSystemEvent.modify || event.type == FileSystemEvent.create) {
              if (!await logFile.exists()) {
                 _terminalOutput[serviceId]?.value += '\n[Log file ${logFile.path} disappeared during watch. Tailing stopped.]';
                 // Consider how to stop the watcher here if possible, or let it error out.
                return;
              }
              final currentSize = await logFile.length();
              if (currentSize > lastSize) {
                final randomAccessFile = await logFile.open(mode: FileMode.read);
                await randomAccessFile.setPosition(lastSize);
                final newBytes = await randomAccessFile.read(currentSize - lastSize);
                await randomAccessFile.close();
                final newContent = utf8.decode(newBytes);
                if (newContent.isNotEmpty) {
                  _terminalOutput[serviceId]?.value += newContent;
                }
                lastSize = currentSize;
              } else if (currentSize < lastSize) { // Log file might have been truncated/rotated
                _terminalOutput[serviceId]?.value += '\n[Log file ${logFile.path} may have been truncated or rotated. Reading from start of new content.]\n';
                lastSize = 0; // Reset to read from beginning of new content or full if small
                 final randomAccessFile = await logFile.open(mode: FileMode.read);
                await randomAccessFile.setPosition(lastSize); // Should be 0
                final newBytes = await randomAccessFile.read(currentSize); // Read everything up to current size
                await randomAccessFile.close();
                final newContent = utf8.decode(newBytes);
                if (newContent.isNotEmpty) {
                  _terminalOutput[serviceId]?.value += newContent;
                }
                lastSize = currentSize;
              }
            }
          } catch (e) {
            _terminalOutput[serviceId]?.value += '\n[Error reading changes from log file ${logFile.path}: $e]';
            debugPrint("Error during log file watch for $serviceId: $e");
            // Potentially stop watching if error is persistent
          }
        },
        onError: (error) {
          _terminalOutput[serviceId]?.value += '\n[Error watching log file ${logFile.path}: $error. Tailing stopped.]';
          debugPrint("Error in log file watcher stream for $serviceId: $error");
        },
        onDone: () {
          // This might be called if the file is deleted or the watcher stops for other reasons.
          // Check if the file still exists. If not, it's a clear indication.
          logFile.exists().then((exists) {
            if (!exists) {
              _terminalOutput[serviceId]?.value += '\n[Log file ${logFile.path} no longer exists. Tailing stopped.]';
            } else {
              _terminalOutput[serviceId]?.value += '\n[Log file watching ended for ${logFile.path}.]';
            }
             debugPrint("Log file watcher stream done for $serviceId (${logFile.path}).");
          });
        },
        cancelOnError: true, // Stop watching on error
      );
      _terminalOutput[serviceId]?.value += '\n[Now watching for changes in ${logFile.path}]';
    } catch (e) {
      _terminalOutput[serviceId]?.value += '\n[Failed to start watching log file ${logFile.path}: $e]';
      debugPrint("Failed to initiate log file watch for $serviceId: $e");
    }
  }


  // --- Service Management Methods Moved Here ---

  // Helper function to get the full path to the services JSON file
  Future<String> _getServicesFilePath() async {
    // Get the directory of the executable, which is likely the installation directory
    final executablePath = Platform.resolvedExecutable;
    final installationDir = p.dirname(executablePath);
    return p.join(installationDir, 'data', 'services.json');
  }

  // 加载服务列表 (Load service list)
  Future<void> _loadServices() async {
    try {
      // Get the full file path
      final filePath = await _getServicesFilePath();
      final file = File(filePath);

      if (await file.exists()) {
        final contents = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(contents);
        _services = jsonList.map((json) {
          return Service.fromJson(json); // fromJson now handles ID generation
        }).toList();
      } else {
        // If the file doesn't exist, initialize with an empty list
        _services = [];
      }
    } catch (e) {
      // Handle file reading errors
      debugPrint('Error loading services: $e');
      _services = []; // Ensure services is empty on error
      // Optionally show an error notification
      NotifyController().showNotify(
        NotifyData(
          message: '加载服务列表失败: $e', // Failed to load service list
          type: NotifyType.app,
          time: DateTime.now(),
        ),
      );
    } finally {
      notifyListeners(); // Notify listeners after loading (or failing to load)
    }
  }

  // 保存服务列表 (Save service list)
  Future<void> _saveServices() async {
    final filePath = await _getServicesFilePath();

    try {
      final file = File(filePath);
      // Ensure the directory exists
      final dataDir = Directory(p.dirname(filePath));
      if (!await dataDir.exists()) {
        await dataDir.create(recursive: true);
      }

      // toJson now includes the ID
      final jsonList = _services.map((service) => service.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));

      // Save successful, send app notification
      NotifyController().showNotify(
        NotifyData(
          message: '服务列表保存成功', // Service list saved successfully
          type: NotifyType.app,
          time: DateTime.now(),
        ),
      );
    } catch (e) {
      // Handle file writing errors, send app notification
      debugPrint('Error saving services: $e');
      NotifyController().showNotify(
        NotifyData(
          message: '服务列表保存失败: $e', // Failed to save service list
          type: NotifyType.app,
          time: DateTime.now(),
        ),
      );
    } finally {
       notifyListeners(); // Notify listeners after saving attempt
    }
  }

  // Add a new service to the list and save
  Future<void> addService(Service newService) async {
    _services.add(newService);
    await _saveServices(); // Save includes notifyListeners
  }

  // Update an existing service in the list and save
  Future<void> updateService(Service updatedService) async {
    final index = _services.indexWhere((s) => s.id == updatedService.id);
    if (index != -1) {
      _services[index] = updatedService;
      await _saveServices(); // Save includes notifyListeners
    } else {
      debugPrint("Error: Service with ID ${updatedService.id} not found for update.");
      // Optionally notify user
    }
  }

  // Delete a service from the list and save
  Future<void> deleteService(String serviceId) async {
    final initialLength = _services.length;
     // Find the service to potentially delete its directory later
    final serviceToDelete = _services.firstWhere((s) => s.id == serviceId, orElse: () => Service(id: '', name: '', type: '', path: '')); // Provide a dummy service if not found

    _services.removeWhere((s) => s.id == serviceId);
    if (_services.length < initialLength) { // Check if removal happened
        await _saveServices(); // Save includes notifyListeners

        // If it was an "added" service, attempt to delete its folder
        if (serviceToDelete.type == '服务添加' && serviceToDelete.path.isNotEmpty) {
            try {
                final dirToDelete = Directory(serviceToDelete.path);
                if (await dirToDelete.exists()) {
                await dirToDelete.delete(recursive: true);
                debugPrint('Deleted directory: ${serviceToDelete.path}');
                NotifyController().showNotify(
                    NotifyData(
                    message: '已删除服务文件夹: ${serviceToDelete.name}',
                    type: NotifyType.app,
                    time: DateTime.now(),
                    ),
                );
                }
            } catch (e) {
                debugPrint('Error deleting service directory: $e');
                NotifyController().showNotify(
                    NotifyData(
                    message: '删除服务文件夹失败: ${serviceToDelete.name} - $e',
                    type: NotifyType.app,
                    time: DateTime.now(),
                    icon: Icons.error_outline,
                    ),
                );
            }
        }

    } else {
      debugPrint("Error: Service with ID $serviceId not found for deletion.");
      // Optionally notify user
    }
  }

  // Helper to get service name by ID
  String getServiceNameById(String serviceId) {
    try {
      return _services.firstWhere((s) => s.id == serviceId).name;
    } catch (e) {
      return 'Unknown Service'; // Return default if not found
    }
  }

  // Public method to get a service by its ID
  Service? getServiceById(String serviceId) {
    return _services.firstWhereOrNull((s) => s.id == serviceId);
  }
 
 
  // --- End of Service Management Methods ---
 
 
  // Method to check if a PID is currently running on the system
  Future<bool> isPidActuallyRunning(int? pid) async {
    if (pid == null || pid == 0) return false; // PID 0 is usually the scheduler, not a user process.

    try {
      if (Platform.isWindows) {
        // Using /NH to remove headers, making parsing simpler.
        // tasklist will output the process info if found, or "INFO: No tasks..." if not.
        final result = await Process.run('tasklist', ['/NH', '/FI', 'PID eq $pid'], runInShell: true);
        // Check if stdout is not empty and doesn't contain the "No tasks" message.
        // A more robust check might be to see if the output starts with an image name or contains the PID.
        // For simplicity, if stdout contains the PID string and exit code is 0, assume it's running.
        // Exit code 0 can be returned even if process not found, so stdout check is important.
        final output = result.stdout.toString();
        if (result.exitCode == 0 && output.contains(pid.toString()) && !output.contains("No tasks are running which match the specified criteria")) {
            return true;
        }
        return false;
      } else if (Platform.isLinux || Platform.isMacOS) {
        // 'ps -p <pid>' exits with 0 if the process exists, 1 otherwise.
        // No output is needed from stdout, just the exit code.
        final result = await Process.run('ps', ['-p', pid.toString()], runInShell: true);
        return result.exitCode == 0;
      }
    } catch (e) {
      debugPrint("Error checking PID $pid: $e");
      return false; // Error during check, assume not running
    }
    debugPrint("PID check not supported on this platform for PID $pid.");
    return false; // Default for unsupported platforms
  }

  // Get the output notifier for a specific service
  ValueNotifier<String>? getOutputNotifier(String serviceId) {
    return _terminalOutput[serviceId];
  }
 
  // Getter to check if auto-scroll is enabled
  bool get isAutoScrollEnabled => autoScrollToEnd.value;
 
  // Method to toggle the auto-scroll feature
  void toggleAutoScroll() {
    autoScrollToEnd.value = !autoScrollToEnd.value;
    notifyListeners(); // Notify listeners to rebuild UI if needed (e.g., the switch itself)
  }
  
 
  // Start a service process
  // Added forceStart parameter
  Future<bool> startService(Service service, {bool forceStart = false}) async {
    final currentRunState = _serviceRunStates[service.id];
    // If not forcing start, check if already running
    if (!forceStart && currentRunState != null && currentRunState.desiredState == 'running' && currentRunState.lastKnownPid != null) {
      bool actuallyRunning = await isPidActuallyRunning(currentRunState.lastKnownPid!);
      if (actuallyRunning) {
        debugPrint('Service ${service.name} is already running with PID ${currentRunState.lastKnownPid}. Start request ignored (forceStart is false).');
        if (_activeProcesses.containsKey(service.id)) {
          // Already active, logging should be fine
        } else {
          String recoveryMessage = 'Service \'${service.name}\' (PID: ${currentRunState.lastKnownPid}) was found running (verified). Re-attaching/logging.\n';
          await _setupLoggingForRunningService(service.id, service, currentRunState.lastKnownPid!, recoveryMessage);
        }
        return false; // Service is actually running and not forced to restart
      } else {
        debugPrint('Service ${service.name} was marked running with PID ${currentRunState.lastKnownPid}, but PID is dead. Proceeding to (re)start.');
        _serviceRunStates[service.id]?.lastKnownPid = null;
      }
    } else if (forceStart && currentRunState != null && currentRunState.desiredState == 'running') {
        debugPrint('Force starting service ${service.name}. Previous PID was ${currentRunState.lastKnownPid}.');
        // If forcing start, and it was marked as running, clear old PID to ensure new one is recorded.
        // This also handles the case where the old PID might still be valid but a force restart is requested.
        if (currentRunState.lastKnownPid != null) {
             // Attempt to kill the old process if it's still running and we are forcing a restart
            bool oldPidStillRunning = await isPidActuallyRunning(currentRunState.lastKnownPid);
            if (oldPidStillRunning) {
                debugPrint('Force start: Attempting to kill old process PID ${currentRunState.lastKnownPid} for service ${service.name}');
                // Use a simplified kill, similar to stopService but without full state updates yet
                try {
                    if (Platform.isWindows) {
                        await Process.run('taskkill', ['/PID', '${currentRunState.lastKnownPid}', '/T', '/F'], runInShell: true);
                    } else {
                        Process.killPid(currentRunState.lastKnownPid!);
                    }
                    debugPrint('Force start: Old process PID ${currentRunState.lastKnownPid} for ${service.name} likely killed.');
                } catch (e) {
                    debugPrint('Force start: Error killing old process PID ${currentRunState.lastKnownPid} for ${service.name}: $e');
                }
            }
        }
        _serviceRunStates[service.id]?.lastKnownPid = null;
    }


    try {
      // Determine the command and arguments
      String executable;
      List<String> arguments = [];
      String workingDirectory =
          service.path; // Use service path as working directory

      // Use preCommand if provided, otherwise use the programName
      if (service.preCommand.isNotEmpty) {
        executable = service.preCommand;
        // Add preParameters, programName, and postParameters as arguments
        if (service.preParameters.isNotEmpty) {
          arguments.addAll(
            service.preParameters.split(' ').where((p) => p.isNotEmpty),
          );
        }
        if (service.programName.isNotEmpty) {
          // Construct the full program path if programName is provided
          // This logic depends on whether programName is a path or just a name/script for preCommand
           if (service.programName.contains('/') || service.programName.contains('\\') || FileSystemEntity.isFileSync(p.join(service.path, service.programName))) {
             arguments.add(p.join(service.path, service.programName));
           } else {
             arguments.add(service.programName); // Assume it's an argument like 'start' for 'npm'
           }
        }
        if (service.postParameters.isNotEmpty) {
          arguments.addAll(
            service.postParameters.split(' ').where((p) => p.isNotEmpty),
          );
        }
      } else {
        // If no preCommand, the programName is the executable
        if (service.programName.isEmpty) {
          debugPrint('Error: programName is empty for service ${service.name}');
          NotifyController().showNotify(NotifyData(message: '启动服务 ${service.name} 失败: 服务程序名称为空。', type: NotifyType.app, time: DateTime.now(), icon: Icons.error_outline));
          return false; // Cannot start without a program name
        }
        executable = p.join(
          service.path,
          service.programName,
        ); // Construct full path
        // Add postParameters as arguments
        if (service.postParameters.isNotEmpty) {
          arguments.addAll(
            service.postParameters.split(' ').where((p) => p.isNotEmpty),
          );
        }
      }

      debugPrint(
        'Starting process: "$executable" ${arguments.map((a) => '"$a"').join(' ')} in "$workingDirectory"',
      );

      // Start the process
      final process = await Process.start(
        executable,
        arguments,
        workingDirectory: workingDirectory,
        runInShell: true, // Use shell to handle commands like 'pwsh' or 'bash'
      );
      
      // Update _serviceRunStates with the new running state
      // Ensure intentionallyStopped is false when a service is started/restarted programmatically or by user action.
      // It's set to true only when a user explicitly stops a service via the UI.
      _serviceRunStates[service.id] = PersistedServiceRunState(
        desiredState: 'running',
        lastKnownPid: process.pid,
        intentionallyStopped: false, // Explicitly set to false on start/restart
        autoStartPreference: _serviceRunStates[service.id]?.autoStartPreference ?? true, // Retain existing or default
      );
      _activeProcesses[service.id] = process;
      _terminalOutput[service.id] = ValueNotifier<String>(
        'Process starting with PID: ${process.pid}...\nCommand: $executable ${arguments.join(' ')}\nWorking Directory: $workingDirectory\n\n',
      ); // Initialize output notifier
      _startTimes[service.id] = DateTime.now(); // Record start time
 
       // The _startupService.updateRunningConfig was for the old single-service runing.json.
       // _saveRunningState now handles the Map<String, int> running.json.
       // final commandToStore = _getFullCommandForService(service);
       // if (commandToStore.isNotEmpty) {
       //   // await _startupService.updateRunningConfig(process.pid, service.name, commandToStore); // Removed
       // } else {
       //   // debugPrint("Could not update running.json for ${service.name} as command string is empty.");
       // }
 
       await _saveRunningState(); // Save state after successful start
 
       // Listen to stdout
       process.stdout.transform(utf8.decoder).listen((data) {
         // debugPrint('stdout ($service.name): $data');
         _terminalOutput[service.id]?.value += data;
       });
 
       // Listen to stderr
       process.stderr.transform(utf8.decoder).listen((data) {
         // debugPrint('stderr ($service.name): $data');
         _terminalOutput[service.id]?.value += data; // Append stderr to the same output for simplicity
       });
 
       // Listen for process exit
       process.exitCode.then((exitCode) async { // Make lambda async
         final exitedPid = _serviceRunStates[service.id]?.lastKnownPid; // Get PID before clearing state
         debugPrint('Service ${service.name} (PID: $exitedPid) exited with code $exitCode');
         
         if (_serviceRunStates.containsKey(service.id)) {
           // Only update if it wasn't intentionally stopped by user action in the meantime
           if (_serviceRunStates[service.id]!.intentionallyStopped == false) {
                _serviceRunStates[service.id]!.desiredState = 'stopped';
                _serviceRunStates[service.id]!.lastKnownPid = null;
           }
         }
         _activeProcesses.remove(service.id);
         _startTimes.remove(service.id); // Remove start time on exit
         _terminalOutput[service.id]?.value += '\nProcess (PID: $exitedPid) exited with code $exitCode.\n';
         await _saveRunningState(); // Save state after process exit
         // Optionally clear or mark output as finished
         // _terminalOutput.remove(service.id); // Or keep it for review
         notifyListeners(); // Notify listeners when a process exits
       });
 
       debugPrint('Service ${service.name} started successfully with PID ${process.pid}.');
       notifyListeners(); // Notify listeners when a process starts successfully
 // Show success notification
       NotifyController().showNotify(
         NotifyData(
          message: '服务 ${service.name} 已成功启动 (PID: ${process.pid})。',
          type: NotifyType.app,
          time: DateTime.now(),
          icon: Icons.check_circle_outline,
        ),
      );
      return true;
    } catch (e, stackTrace) {
      debugPrint('Error starting service ${service.name}: $e\n$stackTrace');
      NotifyController().showNotify(NotifyData(message: '启动服务失败: ${service.name} - $e', type: NotifyType.app, time: DateTime.now(), icon: Icons.error_outline));
      // Update state on failure
      if (_serviceRunStates.containsKey(service.id)) {
        _serviceRunStates[service.id]!.desiredState = 'stopped';
        _serviceRunStates[service.id]!.lastKnownPid = null;
        // intentionallyStopped should not be changed here, as failure isn't a user's explicit stop action
      } else {
        // If service somehow not in runStates, create a default stopped state
         _serviceRunStates[service.id] = PersistedServiceRunState.defaultState(autoStart: _serviceRunStates[service.id]?.autoStartPreference ?? true)
          ..desiredState = 'stopped'
          ..lastKnownPid = null;
      }
      await _saveRunningState();
      notifyListeners();
      return false;
    }
  }

  // Public method to start a service by its ID, added forceStart
  Future<bool> startServiceById(String serviceId, {bool forceStart = false}) async {
    final service = getServiceById(serviceId);
    if (service != null) {
      final currentRunState = _serviceRunStates[serviceId];
      // If not forcing start, and it's already marked as running with a valid PID,
      // and that PID is actually running, then skip.
      if (!forceStart && currentRunState != null && currentRunState.desiredState == 'running' && currentRunState.lastKnownPid != null) {
        bool actuallyRunning = await isPidActuallyRunning(currentRunState.lastKnownPid!);
        if (actuallyRunning) {
          debugPrint('Service ${service.name} (ID: $serviceId) is already running with PID ${currentRunState.lastKnownPid}. Skipping start attempt via startServiceById (forceStart is false).');
          // Ensure logging is attached if it's running but no active process object (recovered state)
          if (!_activeProcesses.containsKey(serviceId)) {
              String recoveryMessage = 'Service \'${service.name}\' (PID: ${currentRunState.lastKnownPid}) was found running (verified). Re-attaching/logging.\n';
              await _setupLoggingForRunningService(service.id, service, currentRunState.lastKnownPid!, recoveryMessage);
          }
          return true; // Indicate it's considered running and no action taken.
        } else {
           debugPrint('Service ${service.name} (ID: $serviceId) was marked running with PID ${currentRunState.lastKnownPid}, but PID is dead. Proceeding to start via startServiceById.');
        }
      }
      // Pass forceStart to the main startService method
      return await startService(service, forceStart: forceStart);
    }
    debugPrint("Service with ID $serviceId not found, cannot start.");
    NotifyController().showNotify(NotifyData(message: '启动服务失败: 未找到ID为 $serviceId 的服务。', type: NotifyType.app, time: DateTime.now(), icon: Icons.error_outline));
    return false;
  }
 
  // Stop a service process
  Future<bool> stopService(String serviceId) async {
    final serviceName = getServiceNameById(serviceId); // 获取服务名称用于日志和通知
    final currentRunState = _serviceRunStates[serviceId];

    // 1. Check service state using _serviceRunStates
    if (currentRunState == null || currentRunState.desiredState == 'stopped') {
      NotifyController().showNotify(
        NotifyData(
          message: '服务 $serviceName 未运行或已被记录为已停止。',
          type: NotifyType.app,
          time: DateTime.now(),
          icon: Icons.warning_amber_outlined,
        ),
      );
      // Ensure state is consistent if currentRunState is null but service exists (e.g. new service never started)
      if (currentRunState == null && getServiceById(serviceId) != null) {
         _serviceRunStates[serviceId] = PersistedServiceRunState.defaultState(autoStart: false)..intentionallyStopped = true;
         await _saveRunningState();
         notifyListeners();
      }
      return false;
    }

    final pid = currentRunState.lastKnownPid; // PID can be null if desiredState was 'running' but pid was lost

    // 2. 检查 PID 是否真的在操作系统中运行 (only if pid is not null)
    bool actuallyRunning = false;
    if (pid != null) {
      actuallyRunning = await isPidActuallyRunning(pid);
    }
    
    String stopMessagePrefix = "服务 $serviceName (PID: ${pid ?? 'N/A'})";

    if (pid == null || !actuallyRunning) {
      // 3. 如果 PID 为空或已经不在运行
      debugPrint('$stopMessagePrefix 在尝试停止时未运行或PID无效。清理记录...');
      _terminalOutput[serviceId]?.value += '\n$stopMessagePrefix 在尝试停止时未运行或PID无效。服务已被视为已停止。\n';
      
      _serviceRunStates[serviceId] = PersistedServiceRunState(
        desiredState: 'stopped',
        lastKnownPid: null,
        intentionallyStopped: true, // User initiated stop
        autoStartPreference: currentRunState.autoStartPreference, // Preserve preference
      );
      _activeProcesses.remove(serviceId);
      _startTimes.remove(serviceId);
      await _saveRunningState();

      NotifyController().showNotify(
        NotifyData(
          message: '$stopMessagePrefix 已停止 (或之前已停止/PID无效)。',
          type: NotifyType.app,
          time: DateTime.now(),
          icon: Icons.info_outline,
        ),
      );
      notifyListeners();
      return true;
    }

    // 4. 如果 PID 真的在运行，尝试终止它
    debugPrint('$stopMessagePrefix 正在运行，尝试停止...');
    _terminalOutput[serviceId]?.value += '\n$stopMessagePrefix 正在运行，尝试停止...\n';
    
    final process = _activeProcesses[serviceId];
    bool killSuccess = false;
    ProcessResult? taskkillResult;
    Object? exceptionCaught;
    String killAttemptDetails = "";

    try {
      if (Platform.isWindows) {
        killAttemptDetails += "尝试使用 taskkill (PID: $pid)... ";
        taskkillResult = await Process.run('taskkill', ['/PID', '$pid', '/T', '/F'], runInShell: true);
        if (taskkillResult.exitCode == 0) {
          killSuccess = true;
          killAttemptDetails += "成功。\n";
        } else {
          killAttemptDetails += "失败 (退出码: ${taskkillResult.exitCode}, stderr: ${taskkillResult.stderr.toString().trim()}).\n";
          if (process != null) {
            killAttemptDetails += "尝试使用 process.kill() (PID: $pid) 作为备用方案... ";
            debugPrint('taskkill failed for PID $pid. Attempting process.kill() as fallback.');
            try {
              killSuccess = process.kill();
              killAttemptDetails += killSuccess ? "成功。\n" : "失败。\n";
            } catch (eKill) {
              killSuccess = false;
              killAttemptDetails += "process.kill() 抛出异常: $eKill.\n";
              exceptionCaught = eKill;
            }
          } else {
            killAttemptDetails += "无活动的 Process 对象可用于 process.kill() 备用方案。\n";
            debugPrint('taskkill failed for PID $pid, and no active Process object for fallback.');
          }
        }
      } else { // Non-Windows
        killAttemptDetails += "尝试使用 process.kill() (PID: $pid) 在非 Windows 平台... ";
        if (process != null) {
          killSuccess = process.kill();
          killAttemptDetails += killSuccess ? "成功。\n" : "失败。\n";
        } else {
          killAttemptDetails += "失败，因为服务为恢复状态且无活动进程对象可供 process.kill()。\n";
          debugPrint('Service $serviceName (PID: $pid) is a recovered service on non-Windows. Cannot send SIGTERM without a Process object.');
          killSuccess = false;
        }
      }
    } catch (e, stackTrace) {
      exceptionCaught = e;
      killAttemptDetails += "停止过程中捕获到异常: $e.\n";
      debugPrint('尝试停止服务 $serviceName (PID: $pid) 时出错: $e\n$stackTrace');
      killSuccess = false;
    } finally {
      // Update the state in _serviceRunStates based on killSuccess
      // The pid != null check here is redundant because 'pid' is from currentRunState.lastKnownPid,
      // and if pid was null, the logic would have taken the '!actuallyRunning' path earlier.
      // If pid was null and it reached here, it means killSuccess path was taken, which implies pid was not null for the attempt.
      // Simplified: if killSuccess is true OR if pid was not null AND it's no longer running.
      // The 'pid != null' check for wasRunningAndNowStopped is still relevant because isPidActuallyRunning now accepts nullable int.
      bool wasRunningAndNowStopped = !await isPidActuallyRunning(pid);
      if (killSuccess || wasRunningAndNowStopped) { // If kill worked or process died anyway
           _serviceRunStates[serviceId] = PersistedServiceRunState(
              desiredState: 'stopped',
              lastKnownPid: null,
              intentionallyStopped: true, // User initiated stop
              autoStartPreference: currentRunState.autoStartPreference, // Preserve preference
          );
      } else {
          // If kill failed and process is still somehow running, state remains tricky.
          // Mark our intent, but PID might still be there.
          if (_serviceRunStates.containsKey(serviceId)) { // Check if key exists before modifying
            _serviceRunStates[serviceId]!.intentionallyStopped = true;
            _serviceRunStates[serviceId]!.desiredState = 'stopped'; // User wants it stopped
            // lastKnownPid might still be the old PID if kill truly failed.
          }
      }
      _activeProcesses.remove(serviceId);
      _startTimes.remove(serviceId);
      await _saveRunningState();

      _terminalOutput[serviceId]?.value += '\n$killAttemptDetails';

      if (killSuccess) {
          NotifyController().showNotify(
            NotifyData(
              message: '$stopMessagePrefix 已成功停止。',
              type: NotifyType.app,
              time: DateTime.now(),
              icon: Icons.check_circle_outline,
            ),
          );
          _terminalOutput[serviceId]?.value += '$stopMessagePrefix 已确认停止。\n';
      } else {
          String failureReason = "尝试终止正在运行的进程 (PID: $pid) 失败。";
          if (exceptionCaught != null) {
              failureReason = "尝试停止时发生错误: $exceptionCaught.";
          } else if (Platform.isWindows && taskkillResult != null && taskkillResult.exitCode != 0) {
              failureReason = 'taskkill 命令执行失败 (退出码: ${taskkillResult.exitCode}).';
              if (taskkillResult.stderr.toString().trim().isNotEmpty) {
                failureReason += ' 错误详情: ${taskkillResult.stderr.toString().trim()}';
              }
              if (taskkillResult.stderr.toString().contains('找不到具有指定 PID 的进程') ||
                  (taskkillResult.stderr.toString().contains('process with PID') && taskkillResult.stderr.toString().contains('could not be terminated'))) {
                  failureReason = "进程 (PID: $pid) 在尝试终止时意外消失或无法终止。";
              }
          } else if (!Platform.isWindows && process == null) {
               failureReason = "无法通过内部 Process 对象发送停止信号 (PID: $pid)，因服务为恢复状态。";
          } else if (!Platform.isWindows && process != null && !killSuccess) {
               failureReason = "通过内部 Process 对象发送停止信号失败 (PID: $pid)。";
          }
          
          NotifyController().showNotify(
            NotifyData(
              message: '停止服务 $serviceName (PID: $pid) 失败。原因: $failureReason',
              type: NotifyType.app,
              time: DateTime.now(),
              icon: Icons.error_outline,
            ),
          );
          _terminalOutput[serviceId]?.value += '停止服务 $serviceName (PID: $pid) 失败。原因: $failureReason\n';
      }
      notifyListeners();
    }
    return killSuccess;
  }

  // Check if a service is running based on its desired state and having a PID
  bool isServiceRunning(String serviceId) {
    final state = _serviceRunStates[serviceId];
    return state != null && state.desiredState == 'running' && state.lastKnownPid != null;
  }
 
  // Dispose resources (e.g., when the app closes)
  @override
  void dispose() {
    // Kill all active processes started by this app instance
    _activeProcesses.forEach((id, process) {
      try {
        process.kill();
        debugPrint('Killed process for service $id on dispose.');
      } catch (e) {
        debugPrint('Error killing process for service $id on dispose: $e');
      }
    });
    _activeProcesses.clear();
    
    // Instead of clearing _servicePids, we should ensure the _serviceRunStates reflect that these processes are now stopped
    // The exitCode.then handlers for these killed processes should ideally update the state.
    // However, dispose might be too abrupt for all async handlers to complete.
    // For safety, we can iterate and update the states here, then save.
    List<String> idsKilledOnDispose = List.from(_serviceRunStates.keys); // Iterate over a copy
    for (String id in idsKilledOnDispose) {
        if (_serviceRunStates.containsKey(id) && _serviceRunStates[id]!.desiredState == 'running') {
             _serviceRunStates[id]!.desiredState = 'stopped';
             _serviceRunStates[id]!.lastKnownPid = null;
             // intentionallyStopped should remain as it was, or be false if it was running due to app exit
             // If it was intentionallyStopped by user before dispose, that state should persist.
             // If it was running, then app dispose is not a user's "intentional stop" to prevent restart.
             // The exitCode.then handler should set intentionallyStopped = false.
        }
    }
    // A final save here might be good, though exitCode.then handlers also save.
    // Consider if _saveRunningState() should be awaited here. For dispose, perhaps not critical to await.
    _saveRunningState();


    _startTimes.clear();

    // Dispose all ValueNotifiers
    _terminalOutput.forEach((id, notifier) {
      notifier.dispose();
    });
    _terminalOutput.clear();
    autoScrollToEnd.dispose(); // Dispose the auto-scroll notifier
    super.dispose();
  }
}
