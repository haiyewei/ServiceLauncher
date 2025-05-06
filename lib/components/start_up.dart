
import 'package:logging/logging.dart';

import 'terminalcontroller.dart'; // Import TerminalController

// 服务配置信息类 (This class might still be useful for other parts, or can be removed if not used elsewhere)
// For the recovery logic, we'll primarily use serviceId and PID from running.json
class ServiceConfig {
  final int? pid;
  final String? name; // Corresponds to serviceId in the new running.json structure
  final String? command; // This might not be directly available or needed if TerminalController handles restart
  final DateTime? startTime;

  ServiceConfig({this.pid, this.name, this.command, this.startTime});

  factory ServiceConfig.fromJson(Map<String, dynamic> json) {
    return ServiceConfig(
      pid: json['pid'] as int?,
      name: json['name'] as String?, // This was service name, now should map to serviceId
      command: json['command'] as String?,
      startTime: json['startTime'] != null
          ? DateTime.tryParse(json['startTime'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pid': pid,
      'name': name,
      'command': command,
      'startTime': startTime?.toIso8601String(),
    };
  }
}

// 启动服务检查和恢复逻辑
class StartupService {
  final Logger _logger = Logger('StartupService');
  // The filename should match what TerminalController uses for consistency.
  // static const String _configFileName = 'running.json'; // No longer needed here as path generation is removed
  // static const String _dataDirName = 'data'; // No longer needed here

  // _getRunningJsonPath is removed as TerminalController handles its own path.

  // Main method to check and recover services using TerminalController
  Future<void> checkAndRecoverServices(TerminalController controller) async {
    _logger.info('Starting service recovery check...');
    await controller.initializationComplete; // Ensure TerminalController is fully initialized

    // TerminalController has already loaded running.json into its _serviceRunStates.
    // We should iterate over the services configured in TerminalController.
    if (controller.services.isEmpty) {
        _logger.info('No services configured in TerminalController. Recovery check skipped.');
        return;
    }
    _logger.info('Checking ${controller.services.length} configured services...');

    for (var configuredService in controller.services) {
      final serviceId = configuredService.id;
      final tcRunState = controller.getServiceRunState(serviceId); // Get state from TC

      if (tcRunState == null) {
          _logger.warning('Service ID "$serviceId" (${configuredService.name}) has no run state in TerminalController. This should not happen if TC initializes correctly. Skipping recovery.');
          continue;
      }

      _logger.info('Checking service "${configuredService.name}" (ID: $serviceId)...');
      _logger.info('  Current TC State: desired=${tcRunState.desiredState}, pid=${tcRunState.lastKnownPid}, intentionally_stopped=${tcRunState.intentionallyStopped}, auto_start=${tcRunState.autoStartPreference}');

      if (tcRunState.intentionallyStopped) {
        _logger.info('Service "${configuredService.name}" (ID: $serviceId) was intentionally stopped. No recovery action.');
        // Ensure TerminalController reflects it as stopped. TC's initial load should handle this.
        // If TC's desiredState is 'running', it's an inconsistency.
        if (tcRunState.desiredState == 'running') {
             _logger.warning('Service "${configuredService.name}" is marked intentionally_stopped, but TC desiredState is running. TC should reconcile this.');
             // Potentially: await controller.updateServiceDesiredState(serviceId, 'stopped', markIntentionallyStopped: true);
        }
        continue;
      }

      // Primary condition for restart: desiredState is "running", not intentionally stopped, and PID is dead.
      if (tcRunState.desiredState == 'running' && !tcRunState.intentionallyStopped) {
        _logger.info('Service "${configuredService.name}" (ID: $serviceId) has desiredState="running" and is not intentionally stopped. Checking PID status...');
        bool isActuallyRunning = false;
        if (tcRunState.lastKnownPid != null) {
          isActuallyRunning = await controller.isPidActuallyRunning(tcRunState.lastKnownPid!);
        }

        if (isActuallyRunning) {
          _logger.info('PID ${tcRunState.lastKnownPid} for service "${configuredService.name}" is ACTUALLY RUNNING. No restart action needed based on primary condition.');
          // Optional: Reconcile TerminalController's active state if it's somehow out of sync
          if (!controller.isServiceRunning(serviceId) || controller.getServicePid(serviceId) != tcRunState.lastKnownPid) {
             _logger.warning('Service "${configuredService.name}" (PID: ${tcRunState.lastKnownPid}) is ACTUALLY RUNNING, but TerminalController state is inconsistent (TC running: ${controller.isServiceRunning(serviceId)}, TC PID: ${controller.getServicePid(serviceId)}). TC should ideally reconcile this during its own load or via a dedicated method.');
             // For now, we rely on TerminalController's startService logic to handle re-attaching logs if it considers it running.
             // If TC thinks it's stopped but it's actually running, calling startServiceById might be one way to reconcile,
             // as startService now checks actual PID.
             // await controller.startServiceById(serviceId); // This could be an option to force TC to re-evaluate.
          }
        } else { // desiredState is "running", not intentionally stopped, AND PID is dead/null. THIS IS THE RESTART CONDITION.
          _logger.info('Service "${configuredService.name}" (ID: $serviceId, recorded PID: ${tcRunState.lastKnownPid}) meets restart criteria: desiredState="running", not intentionally stopped, and PID is not active. Attempting to restart.');
          
          // Call startServiceById with forceStart: true.
          // The modified startService in TC will handle this.
          // It will also ensure intentionallyStopped is set to false.
          bool restarted = await controller.startServiceById(serviceId, forceStart: true);
          if (restarted) {
            final newPid = controller.getServicePid(serviceId);
            _logger.info('Service "${configuredService.name}" restart initiated with forceStart. New PID (if successful): $newPid.');
          } else {
            _logger.severe('Failed to initiate restart for service "${configuredService.name}".');
          }
        }
      }
      // Secondary condition: Service is NOT intentionally stopped, desiredState is 'stopped', but autoStartPreference is true.
      // This handles cases where a service should auto-start but wasn't previously 'running'.
      else if (!tcRunState.intentionallyStopped && tcRunState.desiredState == 'stopped' && tcRunState.autoStartPreference) {
        _logger.info('Service "${configuredService.name}" (ID: $serviceId) has desiredState="stopped", not intentionally stopped, and autoStartPreference=true. Checking if it needs to be started.');
        
        bool isActuallyRunning = false;
        if (tcRunState.lastKnownPid != null) { // Check if an old PID exists and is somehow still running
            isActuallyRunning = await controller.isPidActuallyRunning(tcRunState.lastKnownPid!);
        }

        if (isActuallyRunning) {
            _logger.info('Service "${configuredService.name}" (PID: ${tcRunState.lastKnownPid}) was found unexpectedly running despite desiredState="stopped" (but autoStart=true). TerminalController should reconcile.');
            // Similar to above, TC might need to reconcile its state.
            // Calling startServiceById could help TC re-evaluate and potentially re-attach.
            // await controller.startServiceById(serviceId);
        } else {
            _logger.info('Service "${configuredService.name}" (ID: $serviceId) is not running and has autoStartPreference=true. Attempting to start.');
            bool started = await controller.startServiceById(serviceId);
            if (started) {
                final newPid = controller.getServicePid(serviceId);
                _logger.info('Service "${configuredService.name}" auto-started successfully. New PID: $newPid.');
            } else {
                _logger.severe('Failed to auto-start service "${configuredService.name}".');
            }
        }
      }
      // If intentionallyStopped, we've already logged and continued.
      // If not intentionallyStopped, and desiredState is 'stopped', and autoStart is false, no action.
      else if (!tcRunState.intentionallyStopped && tcRunState.desiredState == 'stopped' && !tcRunState.autoStartPreference) {
         _logger.info('Service "${configuredService.name}" (ID: $serviceId) is desired stopped, not intentionally stopped, and autoStart is false. No startup action.');
      }
      // Other states (e.g., tcRunState.desiredState != 'running' && tcRunState.desiredState != 'stopped') are not expected by current PersistedServiceRunState design.
    }
    _logger.info('Service recovery check finished.');
  }
}

// Example of how this might be called, e.g., in main.dart or a root widget's initState
/*
Future<void> performStartupRecovery(TerminalController terminalController) async {
  final startupService = StartupService();
  await startupService.checkAndRecoverServices(terminalController);
}

// In your main App Widget's initState or similar:
// @override
// void initState() {
//   super.initState();
//   final terminalController = Provider.of<TerminalController>(context, listen: false);
//   performStartupRecovery(terminalController);
// }
*/

// Note: The ServiceConfig class definition is kept as it might be used elsewhere.
// It's not directly used by the core recovery logic of checkAndRecoverServices anymore.
 
// Unused enum ServiceStatus and old method comments are removed for clarity.
 
// 示例用法 (可以放在 main.dart 或其他初始化代码中)
/*
void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // 如果在Flutter环境
  
  // Logger setup
  Logger.root.level = Level.INFO; // 设置日志级别
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.loggerName}: ${record.message}');
  });
  final _logger = Logger('main');

  // Предполагается, что TerminalController инициализируется где-то (например, через Provider)
  // Для этого примера мы не можем его здесь создать без Flutter контекста.
  // TerminalController terminalController = TerminalController();
  // await terminalController._initializeController(); // Подождать инициализации

  // final startupService = StartupService();
  // _logger.info('Performing startup recovery...');
  // await startupService.checkAndRecoverServices(terminalController);
  // _logger.info('Startup recovery process completed.');

  // runApp(MyApp(terminalController: terminalController)); // Пример передачи
}
*/