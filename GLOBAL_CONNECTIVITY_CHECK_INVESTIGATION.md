# Global Internet Connectivity Check Investigation

## Overview
Investigation into adding a global internet connectivity check with an overlay to prevent actions when offline in the Flutter app.

## Current State

### Existing Infrastructure
- **State Management**: Riverpod (`flutter_riverpod: ^3.0.0`)
- **HTTP Client**: Dio (`dio: ^5.3.2`)
- **App Structure**: `MaterialApp.router` with `ProviderScope` at root
- **Error Handling**: Existing error handlers detect network errors but don't prevent actions proactively

### Current Network Error Handling
- `NetworkErrorDisplay` widget exists in `lib/widgets/common/error_display.dart`
- Error handlers detect network issues after API calls fail
- No proactive connectivity checking before actions
- No global overlay to block interactions when offline

## Recommended Approach

### 1. Package Selection

**Option A: `connectivity_plus` (Recommended)**
```yaml
dependencies:
  connectivity_plus: ^6.0.0
```
- **Pros**: 
  - Official Flutter team package
  - Actively maintained
  - Works on all platforms (Android, iOS, Web, Desktop)
  - Lightweight
- **Cons**: 
  - Only checks if device has network connection, not actual internet access
  - May show "connected" even when internet is unavailable

**Option B: `internet_connection_checker`**
```yaml
dependencies:
  internet_connection_checker: ^2.0.0
```
- **Pros**: 
  - Actually checks internet connectivity (pings servers)
  - More accurate than connectivity_plus
- **Cons**: 
  - Uses more battery/resources
  - Requires periodic checks

**Option C: Combined Approach (Best)**
```yaml
dependencies:
  connectivity_plus: ^6.0.0
  internet_connection_checker: ^2.0.0
```
- Use `connectivity_plus` for quick checks (WiFi/Mobile data status)
- Use `internet_connection_checker` for actual internet verification
- Best of both worlds: fast detection + accurate verification

### 2. Implementation Architecture

#### A. Connectivity Provider (Riverpod)

**File**: `lib/providers/connectivity_provider.dart`

```dart
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

// Connectivity state
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

  bool get isOnline => isConnected && hasInternetAccess;
  bool get isOffline => !isOnline;
}

// Connectivity provider
final connectivityProvider = StreamProvider<ConnectivityState>((ref) async* {
  final connectivity = Connectivity();
  final internetChecker = InternetConnectionChecker();
  
  // Initial state
  ConnectivityResult? lastResult;
  bool? lastInternetStatus;
  
  // Listen to connectivity changes
  await for (final result in connectivity.onConnectivityChanged) {
    lastResult = result;
    
    // Check if we have actual internet access
    final hasInternet = await internetChecker.hasConnection;
    lastInternetStatus = hasInternet;
    
    yield ConnectivityState(
      isConnected: result != ConnectivityResult.none,
      connectionType: result,
      hasInternetAccess: hasInternet,
      lastChecked: DateTime.now(),
    );
  }
});

// Simplified boolean provider for easy access
final isOnlineProvider = Provider<bool>((ref) {
  final connectivity = ref.watch(connectivityProvider);
  return connectivity.when(
    data: (state) => state.isOnline,
    loading: () => true, // Assume online while checking
    error: (_, __) => false, // Assume offline on error
  );
});
```

#### B. Global Overlay Widget

**File**: `lib/widgets/common/connectivity_overlay.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/connectivity_provider.dart';

class ConnectivityOverlay extends ConsumerWidget {
  final Widget child;
  
  const ConnectivityOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    
    return Stack(
      children: [
        child,
        if (!isOnline)
          _OfflineOverlay(),
      ],
    );
  }
}

class _OfflineOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.7),
        child: Center(
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.wifi_off,
                    size: 64,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Internet Connection',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please check your internet connection and try again.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

#### C. Integration in App

**File**: `lib/core/app.dart` (modify PlaceOrderApp)

```dart
class PlaceOrderApp extends ConsumerWidget {
  final String? initialRoute;
  
  const PlaceOrderApp({super.key, this.initialRoute});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider(initialRoute));
    
    return MaterialApp.router(
      title: 'Fambri Farms Management',
      theme: ProfessionalTheme.theme,
      darkTheme: ProfessionalTheme.theme,
      themeMode: ThemeMode.dark,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        // Wrap entire app with connectivity overlay
        return ConnectivityOverlay(
          child: child ?? const SizedBox(),
        );
      },
    );
  }
}
```

### 3. Action Prevention Strategy

#### Option A: Overlay Blocks All Interactions (Recommended)
- Overlay covers entire screen with semi-transparent background
- User cannot interact with app content when offline
- Clear message displayed
- **Pros**: Prevents all actions, simple implementation
- **Cons**: User can't even view cached data

#### Option B: Selective Blocking
- Overlay only blocks actions that require internet
- Show banner/bar at top instead of full overlay
- Allow viewing cached data
- Disable buttons/actions that need network
- **Pros**: Better UX, allows viewing cached content
- **Cons**: More complex, need to mark which actions need internet

#### Option C: Hybrid Approach (Best UX)
- Show banner at top when offline
- Disable interactive elements (buttons, forms, etc.)
- Allow scrolling/viewing cached content
- Show overlay only when user tries to perform action

### 4. Implementation Details

#### A. Check Interval
- **Real-time**: Listen to connectivity changes (recommended)
- **Periodic**: Check every 5-10 seconds when app is active
- **On Action**: Check before each API call

#### B. Caching Strategy
- Cache last known connectivity state
- Show "checking..." state briefly when connectivity changes
- Avoid flickering overlay on/off

#### C. Platform Considerations
- **Android**: Requires `INTERNET` and `ACCESS_NETWORK_STATE` permissions (usually auto-added)
- **iOS**: No special permissions needed
- **Web**: Works with browser's online/offline events
- **Desktop**: Works with system network status

### 5. Integration Points

#### A. API Service Integration
**File**: `lib/services/api_service.dart`

```dart
// Add connectivity check before API calls
Future<Response> _makeRequest(...) async {
  // Check connectivity before making request
  final isOnline = ref.read(isOnlineProvider);
  if (!isOnline) {
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
      error: 'No internet connection',
    );
  }
  
  // Proceed with request...
}
```

#### B. Button/Action Disabling
```dart
// Example: Disable button when offline
Consumer(
  builder: (context, ref, child) {
    final isOnline = ref.watch(isOnlineProvider);
    return ElevatedButton(
      onPressed: isOnline ? () => _performAction() : null,
      child: Text('Submit Order'),
    );
  },
)
```

### 6. Testing Strategy

#### Test Cases
1. **Start app offline**: Should show overlay immediately
2. **Go offline while using app**: Overlay should appear
3. **Go online**: Overlay should disappear
4. **WiFi connected but no internet**: Should show offline (if using internet_connection_checker)
5. **Switch between WiFi/Mobile data**: Should maintain connection
6. **Background/foreground**: Should check connectivity on resume

### 7. Performance Considerations

- **Battery Impact**: Minimal if using connectivity_plus, moderate with internet_connection_checker
- **Memory**: Negligible (small state object)
- **Network**: No additional network usage with connectivity_plus, periodic checks with internet_connection_checker

### 8. Recommended Implementation Steps

1. **Add packages** to `pubspec.yaml`
2. **Create connectivity provider** (`lib/providers/connectivity_provider.dart`)
3. **Create overlay widget** (`lib/widgets/common/connectivity_overlay.dart`)
4. **Integrate in app** (modify `lib/core/app.dart`)
5. **Add connectivity checks** to critical actions
6. **Test on all platforms**
7. **Add analytics/logging** for connectivity events

### 9. Alternative: Simpler Implementation

If full implementation is too complex, simpler approach:

```dart
// Simple provider
final connectivityProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  await for (final result in connectivity.onConnectivityChanged) {
    yield result != ConnectivityResult.none;
  }
});

// Simple banner instead of overlay
class ConnectivityBanner extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivity = ref.watch(connectivityProvider);
    final isOnline = connectivity.when(
      data: (online) => online,
      loading: () => true,
      error: (_, __) => false,
    );
    
    if (isOnline) return const SizedBox.shrink();
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      color: Colors.red,
      child: Text(
        'No Internet Connection',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white),
      ),
    );
  }
}
```

## Conclusion

**Recommended Approach**: 
- Use `connectivity_plus` + `internet_connection_checker` for accurate detection
- Create Riverpod provider for global state
- Add overlay widget that blocks interactions when offline
- Integrate in app builder to wrap entire app
- Optionally add checks before API calls for better UX

**Complexity**: Medium
**Impact**: High (prevents user frustration from failed actions)
**Maintenance**: Low (standard Flutter patterns)

