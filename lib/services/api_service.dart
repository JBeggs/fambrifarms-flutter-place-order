import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/whatsapp_message.dart';
import '../models/order.dart';
import '../models/pricing_rule.dart';
import '../models/market_price.dart';
import '../models/customer_price_list.dart';
import '../models/customer.dart' as customer_model;
import '../models/product.dart' as product_model;
import '../config/app_config.dart';
import '../config/app_constants.dart';

class ApiService {
  // Singleton pattern
  static ApiService? _instance;
  
  // Flag to prevent infinite refresh loops
  bool _isRefreshing = false;
  
  // Private constructor for singleton
  ApiService._internal() {
    _initializeDio();
  }
  
  // Public factory constructor
  factory ApiService() {
    _instance ??= ApiService._internal();
    return _instance!;
  }
  
  // Use centralized configuration
  static String get djangoBaseUrl => AppConfig.djangoBaseUrl;
  static String get whatsappBaseUrl => AppConfig.pythonApiUrl;
  // Use constants for default values
  static int _defaultMessagesLimit = AppConstants.defaultPageSize * 5;
  static int _defaultStockUpdatesLimit = AppConstants.defaultPageSize * 2;
  static int _defaultProcessingLogsLimit = AppConstants.defaultPageSize * 10;
  // Dynamic configuration (loaded from backend)
  static Map<String, dynamic> _formOptions = {};
  static Map<String, dynamic> _businessConfig = {};
  static List<String> _customerSegments = ['standard']; // Fallback only
  static double _defaultBaseMarkup = AppConstants.defaultBaseMarkup;
  static double _defaultVolatilityAdjustment = AppConstants.defaultVolatilityAdjustment;
  static double _defaultTrendMultiplier = AppConstants.defaultTrendMultiplier;
  static bool _configLoaded = false;
  
  // Getters for configuration
  static int get defaultMessagesLimit => _defaultMessagesLimit;
  static int get defaultStockUpdatesLimit => _defaultStockUpdatesLimit;
  static int get defaultProcessingLogsLimit => _defaultProcessingLogsLimit;
  static Map<String, dynamic> get formOptions => _formOptions;
  static Map<String, dynamic> get businessConfig => _businessConfig;
  static List<String> get customerSegments => _customerSegments;
  static double get defaultBaseMarkup => _defaultBaseMarkup;
  static double get defaultVolatilityAdjustment => _defaultVolatilityAdjustment;
  static double get defaultTrendMultiplier => _defaultTrendMultiplier;
  
  late final Dio _djangoDio;
  late final Dio _whatsappDio;
  
  // Authentication tokens
  String? _accessToken;
  String? _refreshToken;
  
  // Expose Dio instance for specialized services
  Dio get dio => _djangoDio;
  
  // Initialize tokens from storage
  Future<void> _initializeTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _accessToken = prefs.getString('access_token');
      _refreshToken = prefs.getString('refresh_token');
      
      if (_accessToken != null) {
        debugPrint('[AUTH] Loaded access token from storage');
      }
      if (_refreshToken != null) {
        debugPrint('[AUTH] Loaded refresh token from storage');
      }
    } catch (e) {
      debugPrint('[AUTH] Failed to load tokens from storage: $e');
    }
  }
  
  // Store tokens in SharedPreferences
  Future<void> _storeTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_accessToken != null) {
        await prefs.setString('access_token', _accessToken!);
        debugPrint('[AUTH] Stored access token');
      }
      if (_refreshToken != null) {
        await prefs.setString('refresh_token', _refreshToken!);
        debugPrint('[AUTH] Stored refresh token');
      }
    } catch (e) {
      debugPrint('[AUTH] Failed to store tokens: $e');
    }
  }

  void _initializeDio() {
    // Initialize tokens from storage first
    _initializeTokens();
    
    // Django backend connection
    _djangoDio = Dio(BaseOptions(
      baseUrl: djangoBaseUrl,
      connectTimeout: AppConfig.connectionTimeout,
      receiveTimeout: AppConfig.apiTimeout,
    ));
    
    // Python WhatsApp scraper connection
    _whatsappDio = Dio(BaseOptions(
      baseUrl: whatsappBaseUrl,
      connectTimeout: AppConfig.connectionTimeout,
      receiveTimeout: Duration(seconds: AppConfig.apiTimeoutSeconds * 10), // Longer timeout for WhatsApp operations
    ));
    
    // Configuration will be loaded after authentication is established
    // Don't load config during initialization to avoid authentication loops
    
    // Add authentication interceptor for Django
    _djangoDio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_accessToken != null) {
          options.headers['Authorization'] = 'Bearer $_accessToken';
          debugPrint('[AUTH] Adding token to request: ${options.path}');
        } else {
          debugPrint('[AUTH] No access token available for request: ${options.path}');
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401 && _refreshToken != null) {
          // Prevent infinite loops by checking if we're already refreshing
          if (_isRefreshing) {
            handler.next(error);
            return;
          }
          
          _isRefreshing = true;
          try {
            await _refreshAccessToken();
            // Retry the original request
            final opts = error.requestOptions;
            opts.headers['Authorization'] = 'Bearer $_accessToken';
            final response = await _djangoDio.fetch(opts);
            handler.resolve(response);
            return;
          } catch (e) {
            // Refresh failed, clear tokens and stop trying
            debugPrint('[AUTH] Token refresh failed: $e');
            _accessToken = null;
            _refreshToken = null;
          } finally {
            _isRefreshing = false;
          }
        }
        handler.next(error);
      },
    ));
    
    // Add minimal logging interceptors (only in debug mode)
    if (kDebugMode) {
      _djangoDio.interceptors.add(LogInterceptor(
        requestBody: false,  // Disable request body logging
        responseBody: false, // Disable response body logging
        requestHeader: false, // Disable request headers
        responseHeader: false, // Disable response headers
        request: true,       // Keep request URL and method
        error: true,         // Keep error logging
        logPrint: (obj) => debugPrint('[DJANGO] $obj'),
      ));
      
      _whatsappDio.interceptors.add(LogInterceptor(
        requestBody: false,  // Disable request body logging
        responseBody: false, // Disable response body logging
        requestHeader: false, // Disable request headers
        responseHeader: false, // Disable response headers
        request: true,       // Keep request URL and method
        error: true,         // Keep error logging
        logPrint: (obj) => debugPrint('[WHATSAPP] $obj'),
      ));
    }
    
    // Auto-login disabled - user requested to always show login screen
    // Future.delayed(const Duration(milliseconds: 100), _autoLogin);
  }

  // Authentication methods
  Future<void> _autoLogin() async {
    try {
      // Only auto-login if no tokens are already stored
      if (_accessToken == null) {
        await login('admin@fambrifarms.com', 'admin123');
        debugPrint('[AUTH] Auto-login successful');
      } else {
        debugPrint('[AUTH] Skipping auto-login, tokens already available');
      }
    } catch (e) {
      debugPrint('[AUTH] Auto-login failed: $e');
    }
  }
  
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _djangoDio.post('/auth/login/', data: {
        'email': email,
        'password': password,
      });
      
      // Extract tokens from nested structure
      final tokens = response.data['tokens'];
      _accessToken = tokens['access'];
      _refreshToken = tokens['refresh'];
      
      // Store tokens in SharedPreferences for persistence
      await _storeTokens();
      
      // Load app configuration now that we're authenticated
      await loadConfigAfterAuth();
      
      return response.data;
    } catch (e) {
      throw ApiException(_extractErrorMessage(e, 'Failed to login'));
    }
  }

  Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final response = await _djangoDio.get('/auth/profile/');
      return response.data;
    } catch (e) {
      throw ApiException(_extractErrorMessage(e, 'Failed to get user profile'));
    }
  }

  void setTokens(String accessToken, String? refreshToken) {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    // Store tokens immediately when set
    _storeTokens();
    
    // Load config after tokens are set (for auto-login scenarios)
    loadConfigAfterAuth().catchError((e) {
      debugPrint('[CONFIG] Failed to load config after setting tokens: $e');
    });
  }
  
  Future<void> _refreshAccessToken() async {
    if (_refreshToken == null) {
      throw ApiException('No refresh token available');
    }
    
    try {
      final response = await _djangoDio.post('/auth/token/refresh/', data: {
        'refresh': _refreshToken,
      });
      
      _accessToken = response.data['access'];
      
      // Store the new access token
      await _storeTokens();
      debugPrint('[AUTH] Access token refreshed and stored');
    } catch (e) {
      // If refresh fails, clear tokens to force re-login
      debugPrint('[AUTH] Token refresh failed, clearing tokens: $e');
      _accessToken = null;
      _refreshToken = null;
      await clearStoredAuth();
      throw ApiException('Session expired. Please login again.');
    }
  }
  
  void logout() {
    _accessToken = null;
    _refreshToken = null;
  }
  
  /// Manually refresh the access token
  Future<void> refreshToken() async {
    await _refreshAccessToken();
  }
  
  /// Check if user is authenticated
  bool get isAuthenticated => _accessToken != null;
  
  /// Check if refresh token is available
  bool get canRefreshToken => _refreshToken != null;
  
  /// Clear all stored authentication data (for debugging)
  Future<void> clearStoredAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('karl_email');
      await prefs.remove('access_token');
      await prefs.remove('refresh_token');
      await prefs.remove('remember_karl');
      _accessToken = null;
      _refreshToken = null;
      debugPrint('[AUTH] Cleared all stored authentication data');
    } catch (e) {
      debugPrint('[AUTH] Failed to clear stored auth: $e');
    }
  }

  // Health check - Django backend
  Future<Map<String, dynamic>> checkHealth() async {
    try {
      final response = await _djangoDio.get('/whatsapp/health/');
      return response.data;
    } catch (e) {
      throw ApiException('Failed to connect to Django backend: $e');
    }
  }

  // WhatsApp operations - Python scraper
  Future<Map<String, dynamic>> startWhatsApp({int checkInterval = 30}) async {
    try {
      final response = await _whatsappDio.post('/whatsapp/start', data: {
        'django_url': AppConfig.djangoBaseUrl.replaceAll('/api', ''),  // Django backend URL
        'check_interval': checkInterval,        // Seconds between checks
      });
      return response.data;
    } catch (e) {
      throw ApiException('Failed to start WhatsApp: $e');
    }
  }

  Future<Map<String, dynamic>> stopWhatsApp() async {
    try {
      final response = await _whatsappDio.post('/whatsapp/stop');
      return response.data;
    } catch (e) {
      throw ApiException('Failed to stop WhatsApp: $e');
    }
  }

  Future<Map<String, dynamic>> getWhatsAppStatus() async {
    try {
      final response = await _whatsappDio.get('/whatsapp/status');
      return response.data;
    } catch (e) {
      throw ApiException('Failed to get WhatsApp status: $e');
    }
  }

  // Message operations - Integrated workflow
  Future<List<WhatsAppMessage>> getMessages({int? limit}) async {
    try {
      // Get processed messages from Django backend
      final response = await _djangoDio.get('/whatsapp/messages/', queryParameters: {
        'limit': limit ?? defaultMessagesLimit,
      });
      final Map<String, dynamic> data = response.data;
      final List<dynamic> messages = data['messages'] ?? [];
      return messages.map((json) => WhatsAppMessage.fromJson(Map<String, dynamic>.from(json))).toList();
    } catch (e) {
      throw ApiException('Failed to get messages: $e');
    }
  }

  Future<Map<String, dynamic>> refreshMessages({bool scrollToLoadMore = false}) async {
    try {
      // Trigger manual scan on Python crawler (which automatically sends to Django)
      final response = await _whatsappDio.post('/whatsapp/manual-scan', data: {
        'scroll_to_load_more': scrollToLoadMore,
      });
      
      return response.data;
    } catch (e) {
      throw ApiException('Failed to refresh messages: $e');
    }
  }

  Future<Map<String, dynamic>> testDjangoConnection() async {
    try {
      final response = await _whatsappDio.post('/debug/test-django', data: {
        'django_url': AppConfig.djangoBaseUrl.replaceAll('/api', ''),
      });
      return response.data;
    } catch (e) {
      throw ApiException('Failed to test Django connection: $e');
    }
  }

  Future<WhatsAppMessage> editMessage(String messageId, String editedContent, {bool? processed}) async {
    try {
      final data = <String, dynamic>{
        'message_id': messageId,  // This should be the WhatsApp messageId, not the database id
        'edited_content': editedContent,
      };
      
      // Only include processed if it's explicitly set
      if (processed != null) {
        data['processed'] = processed;
      }
      
      final response = await _djangoDio.post('/whatsapp/messages/edit/', data: data);
      return WhatsAppMessage.fromJson(Map<String, dynamic>.from(response.data['message']));
    } catch (e) {
      throw ApiException('Failed to edit message: $e');
    }
  }

  Future<WhatsAppMessage> updateMessageCompany(String databaseId, String? companyName) async {
    try {
      final response = await _djangoDio.post('/whatsapp/messages/update-company/', data: {
        'message_id': databaseId,  // This uses the database ID
        'company_name': companyName,
      });
      return WhatsAppMessage.fromJson(Map<String, dynamic>.from(response.data['data']));
    } catch (e) {
      throw ApiException('Failed to update message company: $e');
    }
  }

  Future<WhatsAppMessage> updateMessageType(String databaseId, String messageType) async {
    try {
      final response = await _djangoDio.post('/whatsapp/messages/update-type/', data: {
        'message_id': int.parse(databaseId),  // Backend expects integer ID
        'message_type': messageType,
      });
      return WhatsAppMessage.fromJson(Map<String, dynamic>.from(response.data['data']));
    } catch (e) {
      throw ApiException('Failed to update message type: $e');
    }
  }

  Future<Map<String, dynamic>> processMessages(List<String> messageIds) async {
    try {
      final response = await _djangoDio.post('/whatsapp/messages/process/', data: {
        'message_ids': messageIds,
      });
      return response.data;
    } catch (e) {
      throw ApiException('Failed to process messages: $e');
    }
  }

  Future<Map<String, dynamic>> processStockMessages(List<String> messageIds) async {
    try {
      final response = await _djangoDio.post('/whatsapp/messages/process-stock/', data: {
        'message_ids': messageIds,
      });
      return response.data;
    } catch (e) {
      throw ApiException('Failed to process stock messages: $e');
    }
  }

  Future<Map<String, dynamic>> processStockAndApplyToInventory(List<String> messageIds, {bool resetBeforeProcessing = true}) async {
    try {
      final response = await _djangoDio.post('/whatsapp/process-stock-and-apply/', data: {
        'message_ids': messageIds,
        'reset_before_processing': resetBeforeProcessing,
      });
      return response.data;
    } catch (e) {
      throw ApiException('Failed to process stock and apply to inventory: $e');
    }
  }

  Future<Map<String, dynamic>> applyStockUpdatesToInventory({bool resetBeforeProcessing = true}) async {
    try {
      final response = await _djangoDio.post('/whatsapp/stock-updates/apply-to-inventory/', data: {
        'reset_before_processing': resetBeforeProcessing,
      });
      return response.data;
    } catch (e) {
      throw ApiException('Failed to apply stock updates to inventory: $e');
    }
  }

  Future<Map<String, dynamic>> getStockTakeData({bool onlyWithStock = true}) async {
    try {
      final response = await _djangoDio.get('/whatsapp/stock-take-data/', queryParameters: {
        'only_with_stock': onlyWithStock.toString(),
      });
      return response.data;
    } catch (e) {
      throw ApiException('Failed to get stock take data: $e');
    }
  }

  // Order Management API methods
  Future<List<Order>> getOrders() async {
    try {
      print('[DEBUG] Starting getOrders API call...');
      final response = await _djangoDio.get('/orders/');
      print('[DEBUG] Got response, type: ${response.data.runtimeType}');
      
      // Handle Django REST Framework pagination format
      if (response.data is Map<String, dynamic>) {
        print('[DEBUG] Response is Map, checking for results...');
        final Map<String, dynamic> responseData = response.data;
        print('[DEBUG] Response keys: ${responseData.keys.toList()}');
        
        if (responseData.containsKey('results')) {
          final List<dynamic> ordersJson = responseData['results'];
          print('[DEBUG] Found ${ordersJson.length} orders in results');
          
          final List<Order> orders = [];
          for (int i = 0; i < ordersJson.length; i++) {
            try {
              print('[DEBUG] Processing order $i, type: ${ordersJson[i].runtimeType}');
              final orderMap = Map<String, dynamic>.from(ordersJson[i]);
              print('[DEBUG] Order $i converted to Map, creating Order object...');
              final order = Order.fromJson(orderMap);
              orders.add(order);
              print('[DEBUG] Order $i created successfully');
            } catch (e) {
              print('[ERROR] Failed to parse order $i: $e');
              print('[ERROR] Order $i data: ${ordersJson[i]}');
              rethrow;
            }
          }
          
          print('[DEBUG] Successfully parsed ${orders.length} orders');
          return orders;
        }
      }
      
      // Handle direct array response
      if (response.data is List<dynamic>) {
        print('[DEBUG] Response is direct List');
        final List<dynamic> ordersJson = response.data;
        print('[DEBUG] Found ${ordersJson.length} orders in direct list');
        
        final List<Order> orders = [];
        for (int i = 0; i < ordersJson.length; i++) {
          try {
            print('[DEBUG] Processing order $i, type: ${ordersJson[i].runtimeType}');
            final orderMap = Map<String, dynamic>.from(ordersJson[i]);
            print('[DEBUG] Order $i converted to Map, creating Order object...');
            final order = Order.fromJson(orderMap);
            orders.add(order);
            print('[DEBUG] Order $i created successfully');
          } catch (e) {
            print('[ERROR] Failed to parse order $i: $e');
            print('[ERROR] Order $i data: ${ordersJson[i]}');
            rethrow;
          }
        }
        
        print('[DEBUG] Successfully parsed ${orders.length} orders');
        return orders;
      }
      
      print('[ERROR] Unexpected response format: ${response.data.runtimeType}');
      throw ApiException('Unexpected response format from orders API');
    } catch (e) {
      print('[ERROR] getOrders failed: $e');
      throw ApiException('Failed to get orders: $e');
    }
  }

  Future<Order> getOrder(int orderId) async {
    try {
      final response = await _djangoDio.get('/orders/$orderId/');
      return Order.fromJson(Map<String, dynamic>.from(response.data));
    } catch (e) {
      throw ApiException('Failed to get order: $e');
    }
  }

  Future<Order> createOrder(Map<String, dynamic> orderData) async {
    try {
      final response = await _djangoDio.post('/orders/', data: orderData);
      return Order.fromJson(Map<String, dynamic>.from(response.data));
    } catch (e) {
      throw ApiException('Failed to create order: $e');
    }
  }

  Future<Order> updateOrder(int orderId, Map<String, dynamic> orderData) async {
    try {
      final response = await _djangoDio.put('/orders/$orderId/', data: orderData);
      return Order.fromJson(Map<String, dynamic>.from(response.data));
    } catch (e) {
      throw ApiException('Failed to update order: $e');
    }
  }

  Future<Order> updateOrderStatus(int orderId, String status) async {
    try {
      final response = await _djangoDio.patch('/orders/$orderId/status/', data: {
        'status': status,
      });
      return Order.fromJson(Map<String, dynamic>.from(response.data));
    } catch (e) {
      throw ApiException('Failed to update order status: $e');
    }
  }

  Future<void> deleteOrder(int orderId) async {
    try {
      // Ensure we have valid authentication before attempting delete
      if (_accessToken == null) {
        await _initializeTokens();
        if (_accessToken == null) {
          throw ApiException('Authentication required. Please log in again.');
        }
      }
      
      await _djangoDio.delete('/orders/$orderId/');
    } catch (e) {
      if (e is DioException) {
        if (e.response?.statusCode == 401) {
          throw ApiException('Authentication expired. Please log in again.');
        } else if (e.response?.statusCode == 403) {
          throw ApiException('You don\'t have permission to delete this order.');
        } else if (e.response?.statusCode == 404) {
          throw ApiException('Order not found. It may have already been deleted.');
        }
      }
      throw ApiException('Failed to delete order: $e');
    }
  }

  // Order Items Management
  Future<List<Map<String, dynamic>>> getOrderItems(int orderId) async {
    try {
      final response = await _djangoDio.get('/orders/$orderId/items/');
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      throw ApiException('Failed to get order items: $e');
    }
  }

  Future<Map<String, dynamic>> addOrderItem(int orderId, Map<String, dynamic> itemData) async {
    try {
      final response = await _djangoDio.post('/orders/$orderId/items/', data: itemData);
      return response.data;
    } catch (e) {
      throw ApiException('Failed to add order item: $e');
    }
  }

  Future<Map<String, dynamic>> updateOrderItem(int orderId, int itemId, Map<String, dynamic> itemData) async {
    try {
      final response = await _djangoDio.put('/orders/$orderId/items/$itemId/', data: itemData);
      return response.data;
    } catch (e) {
      throw ApiException('Failed to update order item: $e');
    }
  }

  Future<void> deleteOrderItem(int orderId, int itemId) async {
    try {
      await _djangoDio.delete('/orders/$orderId/items/$itemId/');
    } catch (e) {
      throw ApiException('Failed to delete order item: $e');
    }
  }

  // Inventory Management APIs
  Future<List<Map<String, dynamic>>> getStockLevels() async {
    try {
      final response = await _djangoDio.get('/inventory/stock-levels/');
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      throw ApiException('Failed to get stock levels: $e');
    }
  }

  Future<Map<String, dynamic>> adjustStock(int productId, Map<String, dynamic> adjustmentData) async {
    try {
      final response = await _djangoDio.post('/inventory/actions/stock-adjustment/', data: {
        'product_id': productId,
        ...adjustmentData,
      });
      return response.data;
    } catch (e) {
      throw ApiException('Failed to adjust stock: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getStockAlerts() async {
    try {
      print('[API] Calling /inventory/alerts/...');
      final response = await _djangoDio.get('/inventory/alerts/');
      print('[API] Stock alerts response status: ${response.statusCode}');
      print('[API] Stock alerts response type: ${response.data.runtimeType}');
      
      if (response.data is List) {
        // Direct array response
        final alerts = List<Map<String, dynamic>>.from(response.data);
        print('[API] Received ${alerts.length} stock alerts (direct array)');
        return alerts;
      } else if (response.data is Map && response.data['results'] != null) {
        // Paginated response from Django REST Framework
        final results = response.data['results'] as List;
        final alerts = List<Map<String, dynamic>>.from(results);
        print('[API] Received ${alerts.length} stock alerts from paginated response (total: ${response.data['count']})');
        return alerts;
      } else {
        print('[API] Unexpected response format: ${response.data}');
        throw ApiException('Unexpected response format for stock alerts');
      }
    } catch (e) {
      print('[API] Error getting stock alerts: $e');
      throw ApiException('Failed to get stock alerts: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getStockMovements({int? productId, int? limit}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (productId != null) queryParams['product_id'] = productId;
      if (limit != null) queryParams['limit'] = limit;
      
      final response = await _djangoDio.get('/inventory/stock-movements/', queryParameters: queryParams);
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      throw ApiException('Failed to get stock movements: $e');
    }
  }

  // Supplier Management APIs
  Future<List<Map<String, dynamic>>> getSuppliers() async {
    try {
      final response = await _djangoDio.get('/suppliers/suppliers/');
      
      // Handle paginated response
      if (response.data is Map<String, dynamic> && response.data.containsKey('results')) {
        final List<dynamic> suppliersJson = response.data['results'];
        return List<Map<String, dynamic>>.from(suppliersJson);
      }
      
      // Handle direct array response (fallback)
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      throw ApiException('Failed to get suppliers: $e');
    }
  }

  Future<Map<String, dynamic>> createSupplier(Map<String, dynamic> supplierData) async {
    try {
      final response = await _djangoDio.post('/suppliers/suppliers/', data: supplierData);
      return response.data;
    } catch (e) {
      throw ApiException('Failed to create supplier: $e');
    }
  }

  Future<Map<String, dynamic>> updateSupplier(int supplierId, Map<String, dynamic> supplierData) async {
    try {
      final response = await _djangoDio.put('/suppliers/suppliers/$supplierId/', data: supplierData);
      return response.data;
    } catch (e) {
      throw ApiException('Failed to update supplier: $e');
    }
  }

  Future<void> deleteSupplier(int supplierId) async {
    try {
      await _djangoDio.delete('/suppliers/suppliers/$supplierId/');
    } catch (e) {
      throw ApiException('Failed to delete supplier: $e');
    }
  }

  Future<Map<String, dynamic>> getSupplier(int supplierId) async {
    try {
      final response = await _djangoDio.get('/suppliers/suppliers/$supplierId/');
      return response.data;
    } catch (e) {
      throw ApiException('Failed to get supplier: $e');
    }
  }

  // Supplier Product Management APIs
  Future<List<Map<String, dynamic>>> getSupplierProducts({
    int? supplierId,
    int? productId,
    bool? isAvailable,
    String? search,
  }) async {
    try {
      Map<String, dynamic> queryParams = {};
      if (supplierId != null) queryParams['supplier'] = supplierId.toString();
      if (productId != null) queryParams['product'] = productId.toString();
      if (isAvailable != null) queryParams['is_available'] = isAvailable.toString();
      if (search != null) queryParams['search'] = search;

      final response = await _djangoDio.get('/suppliers/supplier-products/', queryParameters: queryParams);
      
      // Handle paginated response
      if (response.data is Map<String, dynamic> && response.data.containsKey('results')) {
        final List<dynamic> productsJson = response.data['results'];
        return List<Map<String, dynamic>>.from(productsJson);
      }
      
      // Handle direct array response (fallback)
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      throw ApiException('Failed to get supplier products: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getSupplierProductsForSupplier(int supplierId, {
    bool? isAvailable,
    String? search,
  }) async {
    try {
      Map<String, dynamic> queryParams = {};
      if (isAvailable != null) queryParams['is_available'] = isAvailable.toString();
      if (search != null) queryParams['search'] = search;

      final response = await _djangoDio.get('/suppliers/suppliers/$supplierId/products/', queryParameters: queryParams);
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      throw ApiException('Failed to get supplier products: $e');
    }
  }

  Future<Map<String, dynamic>> createSupplierProduct(Map<String, dynamic> supplierProductData) async {
    try {
      final response = await _djangoDio.post('/suppliers/supplier-products/', data: supplierProductData);
      return response.data;
    } catch (e) {
      throw ApiException('Failed to create supplier product: $e');
    }
  }

  Future<Map<String, dynamic>> updateSupplierProduct(int supplierProductId, Map<String, dynamic> supplierProductData) async {
    try {
      final response = await _djangoDio.put('/suppliers/supplier-products/$supplierProductId/', data: supplierProductData);
      return response.data;
    } catch (e) {
      throw ApiException('Failed to update supplier product: $e');
    }
  }

  Future<void> deleteSupplierProduct(int supplierProductId) async {
    try {
      await _djangoDio.delete('/suppliers/supplier-products/$supplierProductId/');
    } catch (e) {
      throw ApiException('Failed to delete supplier product: $e');
    }
  }

  // Supplier Optimization APIs
  Future<Map<String, dynamic>> calculateSupplierSplit({
    required int productId,
    required double quantity,
  }) async {
    try {
      final response = await _djangoDio.post('/products/supplier-optimization/calculate-split/', data: {
        'product_id': productId,
        'quantity': quantity,
      });
      return response.data;
    } catch (e) {
      throw ApiException('Failed to calculate supplier split: $e');
    }
  }

  Future<Map<String, dynamic>> calculateOrderOptimization({
    required List<Map<String, dynamic>> orderItems,
  }) async {
    try {
      final response = await _djangoDio.post('/products/supplier-optimization/calculate-order/', data: {
        'order_items': orderItems,
      });
      return response.data;
    } catch (e) {
      throw ApiException('Failed to calculate order optimization: $e');
    }
  }

  Future<Map<String, dynamic>> getSupplierRecommendations({
    required int productId,
    double quantity = 1.0,
  }) async {
    try {
      final response = await _djangoDio.get(
        '/products/supplier-optimization/recommendations/$productId/',
        queryParameters: {'quantity': quantity.toString()},
      );
      return response.data;
    } catch (e) {
      throw ApiException('Failed to get supplier recommendations: $e');
    }
  }

  // Procurement Workflow APIs
  Future<Map<String, dynamic>> analyzeOrderProcurement({
    required int orderId,
  }) async {
    try {
      final response = await _djangoDio.post('/procurement/analyze-order/', data: {
        'order_id': orderId,
      });
      return response.data;
    } catch (e) {
      throw ApiException('Failed to analyze order procurement: $e');
    }
  }

  Future<Map<String, dynamic>> processOrderWorkflow({
    required int orderId,
    bool autoCreatePOs = false,
  }) async {
    try {
      final response = await _djangoDio.post('/procurement/process-workflow/', data: {
        'order_id': orderId,
        'auto_create_pos': autoCreatePOs,
      });
      return response.data;
    } catch (e) {
      throw ApiException('Failed to process order workflow: $e');
    }
  }

  Future<Map<String, dynamic>> getLowStockRecommendations() async {
    try {
      final response = await _djangoDio.get('/procurement/low-stock-recommendations/');
      return response.data;
    } catch (e) {
      throw ApiException('Failed to get low stock recommendations: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getCompanies() async {
    try {
      final response = await _djangoDio.get('/whatsapp/companies/');
      final data = response.data;
      if (data['status'] == 'success') {
        return List<Map<String, dynamic>>.from(data['companies']);
      } else {
        throw ApiException('Failed to get companies: ${data['message']}');
      }
    } catch (e) {
      throw ApiException('Failed to get companies: $e');
    }
  }

  Future<void> deleteMessage(String messageId) async {
    try {
      await _djangoDio.delete('/whatsapp/messages/$messageId/');
    } catch (e) {
      throw ApiException('Failed to delete message: $e');
    }
  }

  Future<void> deleteMessages(List<String> messageIds) async {
    try {
      await _djangoDio.post('/whatsapp/messages/bulk-delete/', data: {
        'message_ids': messageIds,
      });
    } catch (e) {
      throw ApiException('Failed to delete messages: $e');
    }
  }

  // New Django backend methods

  Future<List<Map<String, dynamic>>> getProductsRaw() async {
    try {
      final response = await _djangoDio.get('/products/products/');
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      throw ApiException('Failed to get products: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getStockUpdates({int? limit}) async {
    try {
      final response = await _djangoDio.get('/whatsapp/stock-updates/', queryParameters: {
        'limit': limit ?? defaultStockUpdatesLimit,
      });
      final Map<String, dynamic> data = response.data;
      return List<Map<String, dynamic>>.from(data['stock_updates'] ?? []);
    } catch (e) {
      throw ApiException('Failed to get stock updates: $e');
    }
  }

  Future<Map<String, dynamic>> validateOrderStock(int orderId) async {
    try {
      final response = await _djangoDio.get('/whatsapp/orders/$orderId/validate-stock/');
      return response.data;
    } catch (e) {
      throw ApiException('Failed to validate order stock: $e');
    }
  }

  Future<List<customer_model.Customer>> getCustomers() async {
    try {
      final response = await _djangoDio.get('/auth/customers/');
      final Map<String, dynamic> data = response.data;
      final List<dynamic> customersJson = data['customers'] ?? [];
      return customersJson.map((json) => customer_model.Customer.fromJson(Map<String, dynamic>.from(json))).toList();
    } catch (e) {
      throw ApiException('Failed to get customers: $e');
    }
  }

  Future<customer_model.Customer> createCustomer(Map<String, dynamic> customerData) async {
    try {
      final response = await _djangoDio.post('/auth/customers/', data: customerData);
      return customer_model.Customer.fromJson(Map<String, dynamic>.from(response.data));
    } catch (e) {
      throw ApiException('Failed to create customer: $e');
    }
  }

  Future<customer_model.Customer> updateCustomer(int customerId, Map<String, dynamic> customerData) async {
    try {
      final response = await _djangoDio.put('/auth/customers/$customerId/', data: customerData);
      return customer_model.Customer.fromJson(Map<String, dynamic>.from(response.data));
    } catch (e) {
      throw ApiException('Failed to update customer: $e');
    }
  }

  Future<customer_model.Customer> getCustomer(int customerId) async {
    try {
      final response = await _djangoDio.get('/auth/customers/$customerId/');
      return customer_model.Customer.fromJson(Map<String, dynamic>.from(response.data));
    } catch (e) {
      throw ApiException('Failed to get customer: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getCustomerOrders(int customerId) async {
    try {
      final response = await _djangoDio.get('/orders/customer/$customerId/');
      final Map<String, dynamic> data = Map<String, dynamic>.from(response.data);
      final List<dynamic> ordersJson = data['results'] ?? [];
      return ordersJson.map((json) => Map<String, dynamic>.from(json)).toList();
    } catch (e) {
      throw ApiException('Failed to get customer orders: $e');
    }
  }

  Future<List<product_model.Product>> getProducts() async {
    try {
      final response = await _djangoDio.get('/products/products/');
      
      // Handle paginated response (if pagination is enabled)
      if (response.data is Map<String, dynamic> && response.data.containsKey('results')) {
        final List<dynamic> productsJson = response.data['results'];
        return productsJson.map((json) => product_model.Product.fromJson(Map<String, dynamic>.from(json))).toList();
      }
      
      // Handle direct array response (pagination disabled)
      final List<dynamic> productsJson = response.data;
      return productsJson.map((json) => product_model.Product.fromJson(json)).toList();
    } catch (e) {
      throw ApiException('Failed to get products: $e');
    }
  }

  // Update product (for inventory stock level updates)
  Future<product_model.Product> updateProduct(int productId, Map<String, dynamic> updateData) async {
    try {
      print('[API] Updating product $productId with data: $updateData');
      final response = await _djangoDio.patch('/products/products/$productId/', data: updateData);
      print('[API] Product update response: ${response.data}');
      return product_model.Product.fromJson(Map<String, dynamic>.from(response.data));
    } catch (e) {
      print('[API] Product update error: $e');
      throw ApiException('Failed to update product: $e');
    }
  }

  // Get departments for product editing
  Future<List<Map<String, dynamic>>> getDepartments() async {
    try {
      final response = await _djangoDio.get('/products/departments/');
      if (response.data is List) {
        return List<Map<String, dynamic>>.from(response.data);
      } else if (response.data is Map && response.data['results'] != null) {
        final results = response.data['results'] as List;
        return List<Map<String, dynamic>>.from(results);
      } else {
        throw ApiException('Unexpected response format for departments');
      }
    } catch (e) {
      throw ApiException('Failed to get departments: $e');
    }
  }

  // Get units of measure for product editing
  Future<List<Map<String, dynamic>>> getUnitsOfMeasure() async {
    try {
      final response = await _djangoDio.get('/inventory/units/');
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      throw ApiException('Failed to get units of measure: $e');
    }
  }

  // Log stock adjustment (placeholder - may need backend implementation)
  Future<void> logStockAdjustment(int productId, double newStock, String reason) async {
    try {
      await _djangoDio.post('/inventory/adjustments/', data: {
        'product_id': productId,
        'new_stock_level': newStock,
        'reason': reason,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw ApiException('Failed to log stock adjustment: $e');
    }
  }


  // Phase 3: Dynamic Pricing Management API Methods

  // Pricing Rules Management
  Future<List<PricingRule>> getPricingRules({String? segment, bool? isActive, bool? effective}) async {
    try {
      Map<String, dynamic> queryParams = {};
      if (segment != null) queryParams['segment'] = segment;
      if (isActive != null) queryParams['is_active'] = isActive.toString();
      if (effective != null) queryParams['effective'] = effective.toString();

      final response = await _djangoDio.get('/inventory/pricing-rules/', queryParameters: queryParams);
      
      // Handle Django REST Framework pagination format
      if (response.data is Map<String, dynamic> && response.data.containsKey('results')) {
        final List<dynamic> rulesJson = response.data['results'];
        return rulesJson.map((json) => PricingRule.fromJson(Map<String, dynamic>.from(json))).toList();
      }
      
      // Handle direct array response (fallback)
      final List<dynamic> rulesJson = response.data;
      return rulesJson.map((json) => PricingRule.fromJson(json)).toList();
    } catch (e) {
      throw ApiException('Failed to get pricing rules: $e');
    }
  }

  Future<PricingRule> getPricingRule(int ruleId) async {
    try {
      final response = await _djangoDio.get('/inventory/pricing-rules/$ruleId/');
      return PricingRule.fromJson(Map<String, dynamic>.from(response.data));
    } catch (e) {
      throw ApiException('Failed to get pricing rule: $e');
    }
  }

  Future<PricingRule> createPricingRule(Map<String, dynamic> ruleData) async {
    try {
      debugPrint('[PRICING] Creating pricing rule with data: $ruleData');
      debugPrint('[PRICING] Access token available: ${_accessToken != null}');
      final response = await _djangoDio.post('/inventory/pricing-rules/', data: ruleData);
      debugPrint('[PRICING] Pricing rule created successfully');
      return PricingRule.fromJson(Map<String, dynamic>.from(response.data));
    } catch (e) {
      debugPrint('[PRICING] Error creating pricing rule: $e');
      throw ApiException(_extractErrorMessage(e, 'Failed to create pricing rule'));
    }
  }

  Future<PricingRule> updatePricingRule(int ruleId, Map<String, dynamic> ruleData) async {
    try {
      debugPrint('[PRICING] Updating pricing rule $ruleId with data: $ruleData');
      debugPrint('[PRICING] Access token available: ${_accessToken != null}');
      final response = await _djangoDio.put('/inventory/pricing-rules/$ruleId/', data: ruleData);
      debugPrint('[PRICING] Pricing rule updated successfully');
      return PricingRule.fromJson(Map<String, dynamic>.from(response.data));
    } catch (e) {
      debugPrint('[PRICING] Error updating pricing rule: $e');
      if (e is DioException && e.response?.data != null) {
        debugPrint('[PRICING] Error response data: ${e.response?.data}');
      }
      throw ApiException(_extractErrorMessage(e, 'Failed to update pricing rule'));
    }
  }

  Future<Map<String, dynamic>> testPricingRuleMarkup(int ruleId, {
    double marketPrice = 100.0,
    String volatilityLevel = 'stable'
  }) async {
    try {
      final response = await _djangoDio.post('/inventory/pricing-rules/$ruleId/test_markup/', data: {
        'market_price': marketPrice,
        'volatility_level': volatilityLevel,
      });
      return response.data;
    } catch (e) {
      throw ApiException('Failed to test pricing rule markup: $e');
    }
  }

  // Market Price Intelligence
  Future<List<MarketPrice>> getMarketPrices({
    String? supplier,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? product,
    bool? isActive
  }) async {
    try {
      Map<String, dynamic> queryParams = {};
      if (supplier != null) queryParams['supplier'] = supplier;
      if (dateFrom != null) queryParams['date_from'] = dateFrom.toIso8601String().split('T')[0];
      if (dateTo != null) queryParams['date_to'] = dateTo.toIso8601String().split('T')[0];
      if (product != null) queryParams['product'] = product;
      if (isActive != null) queryParams['is_active'] = isActive.toString();

      final response = await _djangoDio.get('/inventory/market-prices/', queryParameters: queryParams);
      final List<dynamic> pricesJson = response.data;
      return pricesJson.map((json) => MarketPrice.fromJson(Map<String, dynamic>.from(json))).toList();
    } catch (e) {
      throw ApiException('Failed to get market prices: $e');
    }
  }

  Future<Map<String, dynamic>> getMarketVolatilityDashboard({int days = 30}) async {
    try {
      final response = await _djangoDio.get('/inventory/enhanced-market-prices/volatility_dashboard/', 
        queryParameters: {'days': days});
      return response.data;
    } catch (e) {
      throw ApiException('Failed to get market volatility dashboard: $e');
    }
  }

  // Customer Price Lists
  Future<List<CustomerPriceList>> getCustomerPriceLists({
    int? customerId,
    String? status,
    bool? current,
    String? segment
  }) async {
    try {
      Map<String, dynamic> queryParams = {};
      if (customerId != null) queryParams['customer'] = customerId.toString();
      if (status != null) queryParams['status'] = status;
      if (current != null) queryParams['current'] = current.toString();
      if (segment != null) queryParams['segment'] = segment;

      final response = await _djangoDio.get('/inventory/customer-price-lists/', queryParameters: queryParams);
      
      // Handle Django REST Framework pagination format
      if (response.data is Map<String, dynamic> && response.data.containsKey('results')) {
        final List<dynamic> listsJson = response.data['results'];
        return listsJson.map((json) => CustomerPriceList.fromJson(Map<String, dynamic>.from(json))).toList();
      }
      
      // Handle direct array response (fallback)
      final List<dynamic> listsJson = response.data;
      return listsJson.map((json) => CustomerPriceList.fromJson(json)).toList();
    } catch (e) {
      throw ApiException('Failed to get customer price lists: $e');
    }
  }

  Future<CustomerPriceList> getCustomerPriceList(int listId) async {
    try {
      final response = await _djangoDio.get('/inventory/customer-price-lists/$listId/');
      return CustomerPriceList.fromJson(Map<String, dynamic>.from(response.data));
    } catch (e) {
      throw ApiException('Failed to get customer price list: $e');
    }
  }

  Future<CustomerPriceList> createCustomerPriceList(Map<String, dynamic> priceListData) async {
    try {
      final response = await _djangoDio.post('/inventory/customer-price-lists/', data: priceListData);
      return CustomerPriceList.fromJson(Map<String, dynamic>.from(response.data));
    } catch (e) {
      throw ApiException('Failed to create customer price list: $e');
    }
  }

  Future<Map<String, dynamic>> generateCustomerPriceListsFromMarketData({
    required List<int> customerIds,
    required int pricingRuleId,
    String? marketDataDate,
  }) async {
    try {
      Map<String, dynamic> requestData = {
        'customer_ids': customerIds,
        'pricing_rule_id': pricingRuleId,
      };
      if (marketDataDate != null) {
        requestData['market_data_date'] = marketDataDate;
      }

      final response = await _djangoDio.post('/inventory/customer-price-lists/generate_from_market_data/', 
        data: requestData);
      return response.data;
    } catch (e) {
      throw ApiException('Failed to generate customer price lists: $e');
    }
  }

  Future<CustomerPriceList> activateCustomerPriceList(int listId) async {
    try {
      final response = await _djangoDio.post('/inventory/customer-price-lists/$listId/activate/');
      return CustomerPriceList.fromJson(Map<String, dynamic>.from(response.data));
    } catch (e) {
      throw ApiException('Failed to activate customer price list: $e');
    }
  }

  Future<CustomerPriceList> sendCustomerPriceListToCustomer(int listId) async {
    try {
      final response = await _djangoDio.post('/inventory/customer-price-lists/$listId/send_to_customer/');
      return CustomerPriceList.fromJson(Map<String, dynamic>.from(response.data));
    } catch (e) {
      throw ApiException('Failed to send customer price list: $e');
    }
  }

  Future<CustomerPriceList> updateCustomerPriceListRule(int listId, int pricingRuleId) async {
    try {
      final response = await _djangoDio.patch('/inventory/customer-price-lists/$listId/', data: {
        'pricing_rule': pricingRuleId,
      });
      return CustomerPriceList.fromJson(Map<String, dynamic>.from(response.data));
    } catch (e) {
      throw ApiException('Failed to update customer price list rule: $e');
    }
  }

  Future<CustomerPriceList> updateCustomerPriceListMetadata(
    int listId, {
    DateTime? effectiveFrom,
    DateTime? effectiveUntil,
    String? notes,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (effectiveFrom != null) {
        data['effective_from'] = effectiveFrom.toIso8601String().split('T')[0];
      }
      if (effectiveUntil != null) {
        data['effective_until'] = effectiveUntil.toIso8601String().split('T')[0];
      }
      if (notes != null) {
        data['notes'] = notes;
      }

      final response = await _djangoDio.patch('/inventory/customer-price-lists/$listId/', data: data);
      return CustomerPriceList.fromJson(Map<String, dynamic>.from(response.data));
    } catch (e) {
      throw ApiException('Failed to update customer price list metadata: $e');
    }
  }

  // Weekly Reports
  Future<List<Map<String, dynamic>>> getWeeklyReports({String? status, int? year, int? week}) async {
    try {
      Map<String, dynamic> queryParams = {};
      if (status != null) queryParams['status'] = status;
      if (year != null) queryParams['year'] = year.toString();
      if (week != null) queryParams['week'] = week.toString();

      final response = await _djangoDio.get('/inventory/weekly-reports/', queryParameters: queryParams);
      final List<dynamic> reportsJson = response.data;
      return List<Map<String, dynamic>>.from(reportsJson);
    } catch (e) {
      throw ApiException('Failed to get weekly reports: $e');
    }
  }

  Future<Map<String, dynamic>> generateCurrentWeekReport() async {
    try {
      final response = await _djangoDio.post('/inventory/weekly-reports/generate_current_week/');
      return response.data;
    } catch (e) {
      throw ApiException('Failed to generate current week report: $e');
    }
  }

  // Stock Analysis (Phase 1 & 2 integration)
  Future<List<Map<String, dynamic>>> getStockAnalyses({String? status, DateTime? dateFrom}) async {
    try {
      Map<String, dynamic> queryParams = {};
      if (status != null) queryParams['status'] = status;
      if (dateFrom != null) queryParams['date_from'] = dateFrom.toIso8601String().split('T')[0];

      final response = await _djangoDio.get('/inventory/stock-analysis/', queryParameters: queryParams);
      final List<dynamic> analysesJson = response.data;
      return List<Map<String, dynamic>>.from(analysesJson);
    } catch (e) {
      throw ApiException('Failed to get stock analyses: $e');
    }
  }

  Future<Map<String, dynamic>> runStockAnalysis() async {
    try {
      final response = await _djangoDio.post('/inventory/stock-analysis/analyze_current_period/');
      return response.data;
    } catch (e) {
      throw ApiException('Failed to run stock analysis: $e');
    }
  }

  // Procurement Recommendations
  Future<List<Map<String, dynamic>>> getProcurementRecommendations({
    String? urgency,
    String? status,
    DateTime? orderDateFrom,
    DateTime? orderDateTo
  }) async {
    try {
      Map<String, dynamic> queryParams = {};
      if (urgency != null) queryParams['urgency'] = urgency;
      if (status != null) queryParams['status'] = status;
      if (orderDateFrom != null) queryParams['order_date_from'] = orderDateFrom.toIso8601String().split('T')[0];
      if (orderDateTo != null) queryParams['order_date_to'] = orderDateTo.toIso8601String().split('T')[0];

      final response = await _djangoDio.get('/inventory/procurement-recommendations/', queryParameters: queryParams);
      final List<dynamic> recommendationsJson = response.data;
      return List<Map<String, dynamic>>.from(recommendationsJson);
    } catch (e) {
      throw ApiException('Failed to get procurement recommendations: $e');
    }
  }

  // Price Alerts
  Future<List<Map<String, dynamic>>> getPriceAlerts({bool? acknowledged, String? alertType}) async {
    try {
      Map<String, dynamic> queryParams = {};
      if (acknowledged != null) queryParams['acknowledged'] = acknowledged.toString();
      if (alertType != null) queryParams['alert_type'] = alertType;

      final response = await _djangoDio.get('/inventory/price-alerts/', queryParameters: queryParams);
      final List<dynamic> alertsJson = response.data;
      return List<Map<String, dynamic>>.from(alertsJson);
    } catch (e) {
      throw ApiException('Failed to get price alerts: $e');
    }
  }

  Future<Map<String, dynamic>> acknowledgeAllPriceAlerts() async {
    try {
      final response = await _djangoDio.post('/inventory/price-alerts/acknowledge_all/');
      return response.data;
    } catch (e) {
      throw ApiException('Failed to acknowledge all price alerts: $e');
    }
  }


  // Weekly Report Actions  
  Future<Map<String, dynamic>> generateWeeklyReport() async {
    try {
      final response = await _djangoDio.post('/inventory/weekly-reports/generate_current_week/');
      return response.data;
    } catch (e) {
      throw ApiException('Failed to generate weekly report: $e');
    }
  }



  // Customer Price List Operations
  Future<List<Map<String, dynamic>>> getCustomerPriceListItems(int priceListId) async {
    try {
      final response = await _djangoDio.get('/inventory/customer-price-lists/$priceListId/items/');
      final List<dynamic> itemsJson = response.data;
      return List<Map<String, dynamic>>.from(itemsJson);
    } catch (e) {
      throw ApiException('Failed to get price list items: $e');
    }
  }


  Future<Map<String, dynamic>> sendCustomerPriceList(int priceListId) async {
    try {
      final response = await _djangoDio.post('/inventory/customer-price-lists/$priceListId/send/');
      return response.data;
    } catch (e) {
      throw ApiException('Failed to send price list: $e');
    }
  }

  // Pricing Rule Delete Method
  Future<void> deletePricingRule(int ruleId) async {
    try {
      await _djangoDio.delete('/inventory/pricing-rules/$ruleId/');
    } catch (e) {
      throw ApiException('Failed to delete pricing rule: $e');
    }
  }
  
  /// Load app configuration from database (requires authentication)
  Future<void> _loadAppConfig() async {
    try {
      // Only load config if we have authentication tokens
      if (_accessToken == null) {
        debugPrint('[CONFIG] Skipping config load - no authentication token');
        return;
      }
      
      // Use the authenticated Django Dio instance instead of creating a new one
      // Load all configuration in parallel for efficiency
      final results = await Future.wait([
        _djangoDio.get('/products/app-config/'),
        _djangoDio.get('/settings/form-options/'),
        _djangoDio.get('/settings/business-config/'),
      ]);
      
      final config = results[0].data;
      _formOptions = results[1].data ?? {};
      _businessConfig = results[2].data ?? {};
      
      // Update configuration from database (except URLs which are now centralized)
      _defaultMessagesLimit = config['default_messages_limit'] ?? _defaultMessagesLimit;
      _defaultStockUpdatesLimit = config['default_stock_updates_limit'] ?? _defaultStockUpdatesLimit;
      
      // Update customer segments from form options first, then legacy config
      if (_formOptions['customer_segments'] != null) {
        _customerSegments = (_formOptions['customer_segments'] as List)
            .map((segment) => segment['name'] as String)
            .toList();
      } else {
        _customerSegments = List<String>.from(config['customer_segments'] ?? ['standard']);
      }
      
      // Update business values from business config first, then legacy config
      _defaultBaseMarkup = (_businessConfig['default_base_markup']?['value'] ?? 
                           config['default_base_markup'] ?? 1.25).toDouble();
      _defaultVolatilityAdjustment = (_businessConfig['default_volatility_adjustment']?['value'] ?? 
                                     config['default_volatility_adjustment'] ?? 0.15).toDouble();
      _defaultTrendMultiplier = (_businessConfig['default_trend_multiplier']?['value'] ?? 
                                config['default_trend_multiplier'] ?? 1.10).toDouble();
      
      _configLoaded = true;
      if (kDebugMode) {
        debugPrint('✅ App configuration loaded from database');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Failed to load app configuration from database: $e');
      }
      _configLoaded = true; // Don't keep retrying
    }
  }
  
  /// Force reload configuration from database (requires authentication)
  Future<void> reloadConfig() async {
    _configLoaded = false;
    await _loadAppConfig();
  }
  
  /// Load configuration after successful authentication
  Future<void> loadConfigAfterAuth() async {
    if (!_configLoaded) {
      await _loadAppConfig().catchError((e) {
        debugPrint('[CONFIG] Failed to load app config after auth: $e');
        // Don't block authentication flow if config loading fails
      });
    }
  }

  /// Get form options for dropdowns
  static List<Map<String, dynamic>> getFormOptions(String category) {
    final options = _formOptions[category];
    if (options is List) {
      return List<Map<String, dynamic>>.from(options);
    }
    return [];
  }

  /// Get business configuration value
  static T? getBusinessConfig<T>(String key, [T? defaultValue]) {
    final config = _businessConfig[key];
    if (config != null && config['value'] != null) {
      return config['value'] as T;
    }
    return defaultValue;
  }

  /// Get all form options (for debugging)
  static Map<String, dynamic> getAllFormOptions() => _formOptions;

  /// Get all business config (for debugging)
  static Map<String, dynamic> getAllBusinessConfig() => _businessConfig;
  
  // ===== SETTINGS API METHODS =====
  
  Future<List<String>> getCustomerSegments() async {
    try {
      final response = await _djangoDio.get('/api/settings/customer-segments/');
      return List<String>.from(response.data);
    } catch (e) {
      throw ApiException('Failed to get customer segments: ${_extractErrorMessage(e, "Network error")}');
    }
  }

  Future<List<String>> getOrderStatuses() async {
    try {
      final response = await _djangoDio.get('/api/settings/order-statuses/');
      return List<String>.from(response.data);
    } catch (e) {
      throw ApiException('Failed to get order statuses: ${_extractErrorMessage(e, "Network error")}');
    }
  }

  Future<List<Map<String, dynamic>>> getAdjustmentTypes() async {
    try {
      final response = await _djangoDio.get('/api/settings/adjustment-types/');
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      throw ApiException('Failed to get adjustment types: ${_extractErrorMessage(e, "Network error")}');
    }
  }

  Future<Map<String, dynamic>> getBusinessConfiguration() async {
    try {
      final response = await _djangoDio.get('/api/settings/business-config/');
      return response.data;
    } catch (e) {
      throw ApiException('Failed to get business configuration: ${_extractErrorMessage(e, "Network error")}');
    }
  }

  Future<Map<String, dynamic>> getSystemSettings() async {
    try {
      final response = await _djangoDio.get('/api/settings/system-settings/');
      return response.data;
    } catch (e) {
      throw ApiException('Failed to get system settings: ${_extractErrorMessage(e, "Network error")}');
    }
  }

  Future<Map<String, dynamic>> getFormOptionsFromApi() async {
    try {
      final response = await _djangoDio.get('/api/settings/form-options/');
      return response.data;
    } catch (e) {
      throw ApiException('Failed to get form options: ${_extractErrorMessage(e, "Network error")}');
    }
  }

  Future<Map<String, dynamic>> updateBusinessConfig(Map<String, dynamic> configData) async {
    try {
      final response = await _djangoDio.post('/api/settings/business-config/update/', data: configData);
      return response.data;
    } catch (e) {
      throw ApiException('Failed to update business configuration: ${_extractErrorMessage(e, "Network error")}');
    }
  }

  // ===== PROCUREMENT API METHODS =====
  
  Future<Map<String, dynamic>> createSimplePurchaseOrder(Map<String, dynamic> orderData) async {
    try {
      final response = await _djangoDio.post('/api/procurement/purchase-orders/create/', data: orderData);
      return response.data;
    } catch (e) {
      throw ApiException('Failed to create purchase order: ${_extractErrorMessage(e, "Network error")}');
    }
  }

  // ===== PRODUCTS PROCUREMENT API METHODS =====
  
  Future<Map<String, dynamic>> generateMarketRecommendation(Map<String, dynamic> requestData) async {
    try {
      final response = await _djangoDio.post('/products/procurement/generate-recommendation/', data: requestData);
      return response.data;
    } catch (e) {
      throw ApiException('Failed to generate market recommendation: ${_extractErrorMessage(e, "Network error")}');
    }
  }

  Future<List<Map<String, dynamic>>> getMarketRecommendations() async {
    try {
      final response = await _djangoDio.get('/products/procurement/recommendations/');
      final data = response.data as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(data['recommendations'] ?? []);
    } catch (e) {
      throw ApiException('Failed to get market recommendations: ${_extractErrorMessage(e, "Network error")}');
    }
  }

  Future<Map<String, dynamic>> approveMarketRecommendation(int recommendationId) async {
    try {
      final response = await _djangoDio.post('/products/procurement/recommendations/$recommendationId/approve/');
      return response.data;
    } catch (e) {
      throw ApiException('Failed to approve market recommendation: ${_extractErrorMessage(e, "Network error")}');
    }
  }

  Future<List<Map<String, dynamic>>> getProcurementBuffers() async {
    try {
      final response = await _djangoDio.get('/products/procurement/buffers/');
      final data = response.data as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(data['buffers'] ?? []);
    } catch (e) {
      throw ApiException('Failed to get procurement buffers: ${_extractErrorMessage(e, "Network error")}');
    }
  }

  Future<Map<String, dynamic>> updateProcurementBuffer(int productId, Map<String, dynamic> bufferData) async {
    try {
      final response = await _djangoDio.post('/products/procurement/buffers/$productId/', data: bufferData);
      return response.data;
    } catch (e) {
      throw ApiException('Failed to update procurement buffer: ${_extractErrorMessage(e, "Network error")}');
    }
  }

  Future<Map<String, dynamic>> updateProcurementRecommendation(int recommendationId, Map<String, dynamic> recommendationData) async {
    try {
      final response = await _djangoDio.put('/products/procurement/recommendations/$recommendationId/', data: recommendationData);
      return response.data;
    } catch (e) {
      throw ApiException('Failed to update procurement recommendation: ${_extractErrorMessage(e, "Network error")}');
    }
  }

  // Debug method to check authentication status
  Future<bool> checkAuthenticationStatus() async {
    try {
      debugPrint('[AUTH] Checking authentication status...');
      debugPrint('[AUTH] Access token exists: ${_accessToken != null}');
      debugPrint('[AUTH] Refresh token exists: ${_refreshToken != null}');
      
      if (_accessToken == null) {
        debugPrint('[AUTH] No access token - attempting to load from storage');
        await _initializeTokens();
        debugPrint('[AUTH] After loading - Access token exists: ${_accessToken != null}');
      }
      
      // Test with a simple API call
      final response = await _djangoDio.get('/products/business-settings/');
      debugPrint('[AUTH] Test API call successful');
      return true;
    } catch (e) {
      debugPrint('[AUTH] Authentication check failed: $e');
      return false;
    }
  }

  // Force re-authentication
  Future<void> forceReAuthentication() async {
    debugPrint('[AUTH] Forcing re-authentication...');
    _accessToken = null;
    _refreshToken = null;
    await clearStoredAuth();
    
    // Trigger auto-login
    await _autoLogin();
  }

  Future<List<Map<String, dynamic>>> getProductRecipes() async {
    try {
      final response = await _djangoDio.get('/products/procurement/recipes/');
      final data = response.data as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(data['recipes'] ?? []);
    } catch (e) {
      throw ApiException('Failed to get product recipes: ${_extractErrorMessage(e, "Network error")}');
    }
  }

  // Business Settings API methods
  Future<Map<String, dynamic>> getBusinessSettings() async {
    try {
      final response = await _djangoDio.get('/products/business-settings/');
      return response.data;
    } catch (e) {
      throw ApiException('Failed to get business settings: ${_extractErrorMessage(e, "Network error")}');
    }
  }

  Future<Map<String, dynamic>> updateBusinessSettings(Map<String, dynamic> settings) async {
    try {
      final response = await _djangoDio.put('/products/business-settings/update/', data: settings);
      return response.data;
    } catch (e) {
      throw ApiException('Failed to update business settings: ${_extractErrorMessage(e, "Network error")}');
    }
  }

  Future<Map<String, dynamic>> getDepartmentBufferSettings() async {
    try {
      final response = await _djangoDio.get('/products/business-settings/departments/');
      return response.data;
    } catch (e) {
      throw ApiException('Failed to get department buffer settings: ${_extractErrorMessage(e, "Network error")}');
    }
  }

  Future<Map<String, dynamic>> updateDepartmentBufferSettings(String departmentName, Map<String, dynamic> settings) async {
    try {
      final response = await _djangoDio.put('/products/business-settings/departments/$departmentName/', data: settings);
      return response.data;
    } catch (e) {
      throw ApiException('Failed to update department buffer settings: ${_extractErrorMessage(e, "Network error")}');
    }
  }

  Future<Map<String, dynamic>> createVeggieBoxRecipes(Map<String, dynamic> recipeData) async {
    try {
      final response = await _djangoDio.post('/products/procurement/recipes/create-veggie-boxes/', data: recipeData);
      return response.data;
    } catch (e) {
      throw ApiException('Failed to create veggie box recipes: ${_extractErrorMessage(e, "Network error")}');
    }
  }

  Future<Map<String, dynamic>> getProcurementDashboardData() async {
    try {
      final response = await _djangoDio.get('/products/procurement/dashboard/');
      return response.data;
    } catch (e) {
      throw ApiException('Failed to get procurement dashboard data: ${_extractErrorMessage(e, "Network error")}');
    }
  }

  // ===== INVENTORY DASHBOARD API METHODS =====
  
  Future<Map<String, dynamic>> getInventoryDashboard() async {
    try {
      final response = await _djangoDio.get('/api/inventory/dashboard/');
      return response.data;
    } catch (e) {
      throw ApiException('Failed to get inventory dashboard: ${_extractErrorMessage(e, "Network error")}');
    }
  }

  Future<Map<String, dynamic>> reserveStock(Map<String, dynamic> reservationData) async {
    try {
      final response = await _djangoDio.post('/api/inventory/actions/reserve-stock/', data: reservationData);
      return response.data;
    } catch (e) {
      throw ApiException('Failed to reserve stock: ${_extractErrorMessage(e, "Network error")}');
    }
  }

  Future<Map<String, dynamic>> stockAdjustmentAction(Map<String, dynamic> adjustmentData) async {
    try {
      final response = await _djangoDio.post('/api/inventory/actions/stock-adjustment/', data: adjustmentData);
      return response.data;
    } catch (e) {
      throw ApiException('Failed to perform stock adjustment: ${_extractErrorMessage(e, "Network error")}');
    }
  }

  // ===== WHATSAPP PROCESSING LOGS =====
  
  Future<List<Map<String, dynamic>>> getProcessingLogs({int? limit}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (limit != null) queryParams['limit'] = limit;
      
      final response = await _djangoDio.get('/api/whatsapp/logs/', queryParameters: queryParams);
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      throw ApiException('Failed to get processing logs: ${_extractErrorMessage(e, "Network error")}');
    }
  }

  Future<Map<String, dynamic>> refreshCompanyExtraction() async {
    try {
      final response = await _djangoDio.post('/api/whatsapp/messages/refresh-companies/');
      return response.data;
    } catch (e) {
      throw ApiException('Failed to refresh company extraction: ${_extractErrorMessage(e, "Network error")}');
    }
  }

  // ===== PRODUCT ALERTS =====
  
  Future<List<Map<String, dynamic>>> getProductAlerts() async {
    try {
      final response = await _djangoDio.get('/api/products/alerts/');
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      throw ApiException('Failed to get product alerts: ${_extractErrorMessage(e, "Network error")}');
    }
  }

  Future<Map<String, dynamic>> resolveAlert(int alertId) async {
    try {
      final response = await _djangoDio.post('/api/products/alerts/$alertId/resolve/');
      return response.data;
    } catch (e) {
      throw ApiException('Failed to resolve alert: ${_extractErrorMessage(e, "Network error")}');
    }
  }

  /// Extract meaningful error message from DioException or other exceptions
  String _extractErrorMessage(dynamic error, String fallbackMessage) {
    if (error is DioException) {
      // Check for Django REST Framework error format
      if (error.response?.data is Map<String, dynamic>) {
        final data = error.response!.data as Map<String, dynamic>;
        
        // Handle field-specific errors
        if (data.containsKey('non_field_errors')) {
          final errors = data['non_field_errors'];
          if (errors is List && errors.isNotEmpty) {
            return errors.first.toString();
          }
        }
        
        // Handle general error message
        if (data.containsKey('error')) {
          return data['error'].toString();
        }
        
        // Handle detail message
        if (data.containsKey('detail')) {
          return data['detail'].toString();
        }
        
        // Handle field validation errors
        final fieldErrors = <String>[];
        data.forEach((key, value) {
          if (value is List && value.isNotEmpty && key != 'non_field_errors') {
            fieldErrors.add('$key: ${value.first}');
          }
        });
        if (fieldErrors.isNotEmpty) {
          return fieldErrors.join(', ');
        }
      }
      
      // Handle simple string error response
      if (error.response?.data is String) {
        return error.response!.data;
      }
      
      // Handle HTTP status messages
      if (error.response?.statusMessage != null) {
        return '${error.response!.statusCode}: ${error.response!.statusMessage}';
      }
    }
    
    // Fallback to original error message
    return '$fallbackMessage: ${error.toString()}';
  }

  // Supplier Performance APIs
  Future<Map<String, dynamic>> getSupplierPerformance(int supplierId, {int daysBack = 90}) async {
    try {
      final response = await _djangoDio.get('/suppliers/performance/$supplierId/?days_back=$daysBack');
      return response.data;
    } catch (e) {
      throw ApiException('Failed to get supplier performance: $e');
    }
  }

  Future<Map<String, dynamic>> getSupplierRankings({int daysBack = 90}) async {
    try {
      final response = await _djangoDio.get('/suppliers/performance/rankings/?days_back=$daysBack');
      return response.data;
    } catch (e) {
      throw ApiException('Failed to get supplier rankings: $e');
    }
  }

  Future<Map<String, dynamic>> getSupplierPerformanceDashboard({int daysBack = 90}) async {
    try {
      final response = await _djangoDio.get('/suppliers/performance/dashboard/?days_back=$daysBack');
      return response.data;
    } catch (e) {
      throw ApiException('Failed to get supplier performance dashboard: $e');
    }
  }

}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  
  @override
  String toString() => 'ApiException: $message';
}

// Provider for API service - singleton instance
final apiServiceProvider = Provider<ApiService>((ref) {
  // Keep the same instance across the app
  return ApiService();
});
