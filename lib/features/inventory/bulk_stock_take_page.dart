import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/inventory_provider.dart';
import '../../models/karl_user.dart';
import '../../services/api_service.dart';
import '../auth/karl_auth_provider.dart';
import 'widgets/bulk_stock_take_dialog.dart';
import 'utils/bulk_stock_take_launcher.dart';

class BulkStockTakePage extends ConsumerStatefulWidget {
  const BulkStockTakePage({super.key});

  @override
  ConsumerState<BulkStockTakePage> createState() => _BulkStockTakePageState();
}

class _BulkStockTakePageState extends ConsumerState<BulkStockTakePage> {
  static bool _globalDialogShown = false; // Persist across widget recreations
  
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  bool _needsAuth = false;
  bool _isLoggingIn = false;

  @override
  void initState() {
    super.initState();
    print('[BULK_STOCK_TAKE] initState called, globalDialogShown: $_globalDialogShown');
    
    // Reset the flag on first initialization (app start)
    // This handles the case where the app was closed and restarted
    if (!_globalDialogShown) {
      print('[BULK_STOCK_TAKE] First initialization, proceeding...');
    } else {
      print('[BULK_STOCK_TAKE] Dialog already shown globally, skipping initialization');
      return;
    }
    
    // Check if already authenticated
    final isAuthenticated = ref.read(isAuthenticatedProvider);
    print('[BULK_STOCK_TAKE] Current auth status: $isAuthenticated');
    
    if (isAuthenticated) {
      // Already authenticated, go straight to loading inventory
      print('[BULK_STOCK_TAKE] Already authenticated, loading inventory...');
      _loadInventoryData();
    } else {
      // Need to authenticate first
      print('[BULK_STOCK_TAKE] Not authenticated, starting auth check...');
      _checkAuthAndLoad();
    }
  }

  Future<void> _checkAuthAndLoad() async {
    try {
      print('[BULK_STOCK_TAKE] Starting auth check...');
      setState(() {
        _isLoading = true;
        _hasError = false;
        _needsAuth = false;
      });

      // For bulk stock take, try to authenticate with ANY stored credentials
      // (not just when remember_karl is true)
      final prefs = await SharedPreferences.getInstance();
      final storedToken = prefs.getString('access_token');
      final refreshToken = prefs.getString('refresh_token');
      
      print('[BULK_STOCK_TAKE] Found stored token: ${storedToken != null}');
      print('[BULK_STOCK_TAKE] Found refresh token: ${refreshToken != null}');
      
      if (storedToken != null) {
        try {
          print('[BULK_STOCK_TAKE] Attempting to validate stored token...');
          // Set tokens in API service
          final apiService = ref.read(apiServiceProvider);
          apiService.setTokens(storedToken, refreshToken);
          
          // Try to get user profile to validate token
          final profileResponse = await apiService.getUserProfile();
          print('[BULK_STOCK_TAKE] Profile response: ${profileResponse.keys}');
          
          if (profileResponse['id'] != null) {
            // Manually set auth state since auto-login is disabled
            final karl = KarlUser.fromJson(profileResponse);
            ref.read(karlAuthProvider.notifier).state = ref.read(karlAuthProvider).copyWith(
              user: karl,
              isAuthenticated: true,
              isLoading: false,
            );
            
            print('[BULK_STOCK_TAKE] ✅ Auto-authenticated successfully as ${karl.name}');
            await _loadInventoryData();
            return;
          } else {
            print('[BULK_STOCK_TAKE] ❌ Profile response missing ID field');
          }
        } catch (e) {
          print('[BULK_STOCK_TAKE] ❌ Auto-auth failed: $e');
          // Continue to show login dialog
        }
      } else {
        print('[BULK_STOCK_TAKE] ❌ No stored token found');
      }
      
      // No stored auth or auto-login failed - show login dialog
      print('[BULK_STOCK_TAKE] Showing login dialog...');
      setState(() {
        _isLoading = false;
        _needsAuth = true;
      });
    } catch (e) {
      print('[BULK_STOCK_TAKE] ❌ Error in auth check: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _loadInventoryData() async {
    try {
      print('[BULK_STOCK_TAKE] _loadInventoryData started, globalDialogShown: $_globalDialogShown');
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      // Load inventory data
      print('[BULK_STOCK_TAKE] Loading inventory data...');
      await ref.read(inventoryProvider.notifier).refreshAll();
      print('[BULK_STOCK_TAKE] Inventory data loaded');
      
      if (mounted) {
        setState(() => _isLoading = false);
        print('[BULK_STOCK_TAKE] About to check dialog flag, globalDialogShown: $_globalDialogShown');
        if (!_globalDialogShown) {
          print('[BULK_STOCK_TAKE] Setting globalDialogShown to true and showing dialog');
          _globalDialogShown = true;
          _showBulkStockTakeDialog();
        } else {
          print('[BULK_STOCK_TAKE] Dialog already shown, skipping');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _showBulkStockTakeDialog() {
    print('[BULK_STOCK_TAKE] 🎯 Showing bulk stock take dialog...');
    
    // Start with empty list - let the dialog handle loading ALL products via search
    // This avoids the 43-product limitation from inventory provider
    print('[BULK_STOCK_TAKE] Starting with empty product list - dialog will load ALL products for search');

    print('[BULK_STOCK_TAKE] Opening BulkStockTake interface...');
    BulkStockTakeLauncher.launch(
      context: context,
      products: [], // Empty list - interface loads ALL products internally
    );
  }

  void _showNoProductsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('No Products with Stock'),
        content: const Text('No products with stock found. Please sync your inventory first.'),
        actions: [
          TextButton(
            onPressed: _exitApp,
            child: const Text('Exit'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _loadInventoryData();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('✅ Stock Take Complete'),
        content: const Text('Bulk stock take has been completed successfully. The application will now close.'),
        actions: [
          TextButton(
            onPressed: _exitApp,
            child: const Text('Close Application'),
          ),
        ],
      ),
    );
  }

  Future<void> _quickLogin() async {
    try {
      setState(() => _isLoading = true);
      
      // Attempt auto-login with stored credentials
      await ref.read(karlAuthProvider.notifier).checkStoredAuth();
      
      // Check if now authenticated
      final isAuthenticated = ref.read(isAuthenticatedProvider);
      if (isAuthenticated) {
        await _loadInventoryData();
      } else {
        // Show login dialog
        _showLoginDialog();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Authentication failed: $e';
      });
    }
  }

  void _showLoginDialog() {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Login Required'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Please login to access bulk stock take:'),
              const SizedBox(height: 16),
              TextField(
                controller: usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                ),
                enabled: !_isLoggingIn,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                enabled: !_isLoggingIn,
                onSubmitted: (_) => _performLogin(usernameController.text, passwordController.text, setDialogState),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: _isLoggingIn ? null : _exitApp,
              child: const Text('Exit'),
            ),
            ElevatedButton(
              onPressed: _isLoggingIn ? null : () => _performLogin(usernameController.text, passwordController.text, setDialogState),
              child: _isLoggingIn 
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Login'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performLogin(String username, String password, StateSetter setDialogState) async {
    if (username.isEmpty || password.isEmpty) return;

    setState(() => _isLoggingIn = true);
    setDialogState(() {});

    try {
      await ref.read(karlAuthProvider.notifier).loginAsKarl(username, password);
      
      if (mounted) {
        Navigator.of(context).pop(); // Close login dialog
        setState(() => _isLoggingIn = false);
        await _loadInventoryData();
      }
    } catch (e) {
      setState(() => _isLoggingIn = false);
      setDialogState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _exitApp() {
    // Close the application
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Bulk Stock Take'),
        backgroundColor: const Color(0xFF2D5016),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _exitApp,
        ),
      ),
      body: Center(
        child: _isLoading
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Loading inventory data...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              )
            : _needsAuth
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.lock_outline,
                        color: Colors.orange,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Authentication Required',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Please login to access bulk stock take',
                        style: TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: _exitApp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            child: const Text('Exit'),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            onPressed: _quickLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2D5016),
                            ),
                            child: const Text('Login'),
                          ),
                        ],
                      ),
                    ],
                  )
                : _hasError
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 64,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Failed to load inventory data',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _errorMessage,
                            style: const TextStyle(color: Colors.white70),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton(
                                onPressed: _exitApp,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                child: const Text('Exit'),
                              ),
                              const SizedBox(width: 16),
                              ElevatedButton(
                                onPressed: _checkAuthAndLoad,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2D5016),
                                ),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ],
                      )
                    : const SizedBox(), // This shouldn't be reached as dialog opens immediately
      ),
    );
  }
}
