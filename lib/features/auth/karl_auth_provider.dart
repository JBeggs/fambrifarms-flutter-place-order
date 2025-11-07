import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:state_notifier/state_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/karl_user.dart';
import '../../services/api_service.dart';

// Authentication state
class AuthState {
  final KarlUser? user;
  final bool isLoading;
  final String? error;
  final bool isAuthenticated;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
    this.isAuthenticated = false,
  });

  AuthState copyWith({
    KarlUser? user,
    bool? isLoading,
    String? error,
    bool? isAuthenticated,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }
}

// Authentication provider
class KarlAuthNotifier extends StateNotifier<AuthState> {
  final ApiService _apiService;

  KarlAuthNotifier(this._apiService) : super(const AuthState()) {
    // Auto-login disabled - always show login screen
    // _checkStoredAuth();
    state = state.copyWith(isLoading: false);
  }

  // Check if Karl is already logged in (stored credentials)
  Future<void> _checkStoredAuth() async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      
      final prefs = await SharedPreferences.getInstance();
      final storedEmail = prefs.getString('karl_email');
      final storedToken = prefs.getString('access_token');
      
      final rememberMe = prefs.getBool('remember_karl') ?? false;
      
      if (storedEmail != null && storedToken != null && rememberMe) {
        try {
          // Set the token in API service first
          _apiService.setTokens(storedToken, prefs.getString('refresh_token'));
          
          // Try to get user profile to validate token
          final profileResponse = await _apiService.getUserProfile();
          
          if (profileResponse['id'] != null) {
            // Create Karl user from backend response
            final karl = KarlUser.fromJson(profileResponse);
            
            state = state.copyWith(
              user: karl,
              isAuthenticated: true,
              isLoading: false,
            );
            print('[AUTH] Auto-login successful');
            return;
          }
        } catch (e) {
          print('[AUTH] Auto-login failed: $e');
          // Token invalid, clear stored data and continue to manual login
          await _clearStoredAuth();
        }
      }
      
      // No stored auth or auto-login failed
      state = state.copyWith(isLoading: false);
    } catch (e) {
      // If auto-login fails, just clear stored data and continue to manual login
      print('[AUTH] Auto-login error: $e');
      await _clearStoredAuth();
      state = state.copyWith(isLoading: false, error: null);
    }
  }

  // Karl's login method
  Future<bool> loginAsKarl(String email, String password, {bool rememberMe = true}) async {
    try {
      print('[KARL_AUTH] Starting login for: $email');
      state = state.copyWith(isLoading: true, error: null);

      // Call backend login API
      print('[KARL_AUTH] Calling API service login...');
      final loginResponse = await _apiService.login(email, password);
      
      print('[KARL_AUTH] API login response received');
      
      if (loginResponse['user'] != null) {
        print('[KARL_AUTH] User data found in response');
        // Create Karl user from backend response
        final karl = KarlUser.fromJson(loginResponse['user']);
        
        // Store tokens for session persistence and enable auto-login
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('karl_email', email);
        await prefs.setString('access_token', loginResponse['tokens']['access']);
        await prefs.setString('refresh_token', loginResponse['tokens']['refresh']);
        // Enable auto-login for better user experience
        await prefs.setBool('remember_karl', rememberMe);
        
        print('[KARL_AUTH] Tokens and user data stored successfully');
        
        state = state.copyWith(
          user: karl,
          isAuthenticated: true,
          isLoading: false,
        );
        
        print('[KARL_AUTH] Login completed successfully');
        return true;
      } else {
        print('[KARL_AUTH] No user data in response: $loginResponse');
        state = state.copyWith(
          isLoading: false,
          error: 'Invalid login response from server',
        );
        return false;
      }
    } catch (e) {
      print('[KARL_AUTH] Login failed with error: $e');
      print('[KARL_AUTH] Error type: ${e.runtimeType}');
      state = state.copyWith(
        isLoading: false,
        error: _getErrorMessage(e),
      );
      return false;
    }
  }

  // Logout Karl
  Future<void> logout() async {
    try {
      // Clear stored credentials
      await _clearStoredAuth();
      
      // Clear API service tokens
      _apiService.logout();
      
      // Reset state
      state = const AuthState();
    } catch (e) {
      // Even if logout fails, clear local state
      await _clearStoredAuth();
      state = const AuthState();
    }
  }

  // Clear stored authentication data
  Future<void> _clearStoredAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('karl_email');
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('remember_karl');
  }
  
  // Public method to clear stored auth (for debugging)
  Future<void> clearStoredAuth() async {
    await _clearStoredAuth();
    await _apiService.clearStoredAuth();
    state = const AuthState(); // Reset state
    print('[AUTH] Cleared all stored authentication data');
  }

  // Get user-friendly error message
  String _getErrorMessage(dynamic error) {
    if (error.toString().contains('401')) {
      return 'Invalid email or password';
    } else if (error.toString().contains('network')) {
      return 'Network error. Please check your connection.';
    } else if (error.toString().contains('timeout')) {
      return 'Connection timeout. Please try again.';
    } else {
      return 'Login failed. Please try again.';
    }
  }

  // Clear error message
  void clearError() {
    if (state.error != null) {
      state = state.copyWith(error: null);
    }
  }

  // Enable auto-login (for future use if needed)
  Future<void> enableAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('remember_karl', true);
    print('[AUTH] Auto-login enabled for next session');
  }

  // Manual method to check stored auth (if auto-login is re-enabled)
  Future<void> checkStoredAuth() async {
    await _checkStoredAuth();
  }

  // Refresh Karl's data
  Future<void> refreshUserData() async {
    if (!state.isAuthenticated || state.user == null) return;
    
    try {
      // Get updated user data from backend
      final userData = await _apiService.checkHealth();
      
      if (userData['status'] == 'success' && state.user != null) {
        // Update user data while keeping existing info
        final updatedKarl = state.user!.copyWith(
          lastLogin: DateTime.now(),
        );
        
        state = state.copyWith(user: updatedKarl);
      }
    } catch (e) {
      // If refresh fails, don't logout but log the error
      print('Failed to refresh user data: $e');
    }
  }
}

// Provider for Karl's authentication
final karlAuthProvider = StateNotifierProvider<KarlAuthNotifier, AuthState>((ref) {
  final apiService = ref.read(apiServiceProvider);
  return KarlAuthNotifier(apiService);
});

// Convenience providers
final karlUserProvider = Provider<KarlUser?>((ref) {
  return ref.watch(karlAuthProvider).user;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(karlAuthProvider).isAuthenticated;
});

final authLoadingProvider = Provider<bool>((ref) {
  return ref.watch(karlAuthProvider).isLoading;
});

final authErrorProvider = Provider<String?>((ref) {
  return ref.watch(karlAuthProvider).error;
});

