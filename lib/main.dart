import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'core/app.dart';
import 'config/app_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Debug: Print configuration to verify environment variables
  print('🔧 Flutter Configuration Debug:');
  print('Environment: ${AppConfig.isDevelopment ? 'development' : 'production'}');
  print('Django URL: ${AppConfig.djangoBaseUrl}');
  print('Python API URL: ${AppConfig.pythonApiUrl}');
  print('API Timeout: ${AppConfig.apiTimeoutSeconds}s');
  print('Debug Logging: ${AppConfig.enableDebugLogging}');
  
  // Configure window for desktop
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
  
  runApp(
    const ProviderScope(
      child: PlaceOrderApp(),
    ),
  );
}
