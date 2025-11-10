import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'core/app.dart';
import 'config/app_config.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Debug: Print configuration to verify environment variables
  print('🔧 Flutter Configuration Debug:');
  print('Environment: ${AppConfig.isDevelopment ? 'development' : 'production'}');
  print('Django URL: ${AppConfig.djangoBaseUrl}');
  print('Python API URL: ${AppConfig.pythonApiUrl}');
  print('API Timeout: ${AppConfig.apiTimeoutSeconds}s');
  print('Debug Logging: ${AppConfig.enableDebugLogging}');
  
  // Configure window for desktop platforms only
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    await windowManager.ensureInitialized();
    
    WindowOptions windowOptions = const WindowOptions(
      size: Size(1400, 900),
      minimumSize: Size(1000, 700),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      title: 'Place Order Final',
    );
    
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
  
  // Check for bulk stock take argument (from dart-define or command line)
  const isBulkStockTakeDefine = String.fromEnvironment('BULK_STOCK_TAKE') == 'true';
  final isBulkStockTake = isBulkStockTakeDefine || args.contains('--bulk-stock-take');
  
  // Determine initial route based on platform and arguments
  String? initialRoute;
  if (Platform.isAndroid) {
    // Android goes to dashboard for Stock/Orders selection
    initialRoute = '/android-dashboard';
  } else if (isBulkStockTake) {
    // Other platforms with explicit bulk stock take flag go directly there
    initialRoute = '/bulk-stock-take';
  }
  
  print('🚀 Platform: ${Platform.operatingSystem}');
  print('📱 Initial route: ${initialRoute ?? 'default'}');
  
  runApp(
    ProviderScope(
      child: PlaceOrderApp(initialRoute: initialRoute),
    ),
  );
}
