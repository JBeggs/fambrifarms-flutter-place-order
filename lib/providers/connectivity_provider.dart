import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

/// Connectivity state model
class ConnectivityState {
  final bool isConnected;
  final ConnectivityResult connectionType;
  final bool hasInternetAccess;
  final DateTime lastChecked;

  ConnectivityState({
    required this.isConnected,
    required this.connectionType,
    required this.hasInternetAccess,
    required this.lastChecked,
  });

  /// Returns true if device has network connection AND internet access
  bool get isOnline => isConnected && hasInternetAccess;
  
  /// Returns true if device is offline (no connection or no internet)
  bool get isOffline => !isOnline;

  ConnectivityState copyWith({
    bool? isConnected,
    ConnectivityResult? connectionType,
    bool? hasInternetAccess,
    DateTime? lastChecked,
  }) {
    return ConnectivityState(
      isConnected: isConnected ?? this.isConnected,
      connectionType: connectionType ?? this.connectionType,
      hasInternetAccess: hasInternetAccess ?? this.hasInternetAccess,
      lastChecked: lastChecked ?? this.lastChecked,
    );
  }
}

/// Stream provider that monitors connectivity changes
final connectivityProvider = StreamProvider<ConnectivityState>((ref) async* {
  final connectivity = Connectivity();
  final internetChecker = InternetConnectionChecker.instance;
  
  // Get initial connectivity state
  final initialResult = await connectivity.checkConnectivity();
  final initialInternet = await internetChecker.hasConnection;
  final initialType = initialResult.isNotEmpty ? initialResult.first : ConnectivityResult.none;
  
  yield ConnectivityState(
    isConnected: initialType != ConnectivityResult.none,
    connectionType: initialType,
    hasInternetAccess: initialInternet,
    lastChecked: DateTime.now(),
  );
  
  // Listen to connectivity changes
  await for (final result in connectivity.onConnectivityChanged) {
    // Check if we have actual internet access
    final hasInternet = await internetChecker.hasConnection;
    final connectionType = result.isNotEmpty ? result.first : ConnectivityResult.none;
    
    yield ConnectivityState(
      isConnected: connectionType != ConnectivityResult.none,
      connectionType: connectionType,
      hasInternetAccess: hasInternet,
      lastChecked: DateTime.now(),
    );
  }
});

/// Simplified boolean provider for easy access throughout the app
/// Returns true if online, false if offline
final isOnlineProvider = Provider<bool>((ref) {
  final connectivity = ref.watch(connectivityProvider);
  return connectivity.when(
    data: (state) => state.isOnline,
    loading: () => true, // Assume online while checking (prevents blocking on startup)
    error: (_, __) => false, // Assume offline on error
  );
});

/// Provider that returns the current connectivity state (nullable)
final connectivityStateProvider = Provider<ConnectivityState?>((ref) {
  final connectivity = ref.watch(connectivityProvider);
  return connectivity.when(
    data: (state) => state,
    loading: () => null,
    error: (_, __) => null,
  );
});

