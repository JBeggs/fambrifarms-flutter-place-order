import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  void _initializeDio() {
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
    
    // Load configuration from database on first instantiation
    if (!_configLoaded) {
      _loadAppConfig();
    }
    
    // Add authentication interceptor for Django
    _djangoDio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_accessToken != null) {
          options.headers['Authorization'] = 'Bearer $_accessToken';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401 && _refreshToken != null) {
          // Try to refresh token
          try {
            await _refreshAccessToken();
            // Retry the original request
            final opts = error.requestOptions;
            opts.headers['Authorization'] = 'Bearer $_accessToken';
            final response = await _djangoDio.fetch(opts);
            handler.resolve(response);
            return;
          } catch (e) {
            // Refresh failed, clear tokens
            _accessToken = null;
            _refreshToken = null;
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
    
    // Auto-login for development (with delay to ensure constructor completes)
    Future.delayed(const Duration(milliseconds: 100), _autoLogin);
  }

  // Authentication methods
  Future<void> _autoLogin() async {
    try {
      await login('admin@fambrifarms.com', 'admin123');
      debugPrint('[AUTH] Auto-login successful');
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
      
      return response.data;
    } catch (e) {
      throw ApiException(_extractErrorMessage(e, 'Failed to login'));
    }
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
    } catch (e) {
      throw ApiException('Failed to refresh token: $e');
    }
  }
  
  void logout() {
    _accessToken = null;
    _refreshToken = null;
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
      return messages.map((json) => WhatsAppMessage.fromJson(json)).toList();
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
      return WhatsAppMessage.fromJson(response.data['message']);
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
      return WhatsAppMessage.fromJson(response.data['data']);
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
      return WhatsAppMessage.fromJson(response.data['data']);
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

  // Order Management API methods
  Future<List<Order>> getOrders() async {
    try {
      final response = await _djangoDio.get('/orders/');
      
      // Handle Django REST Framework pagination format
      if (response.data is Map<String, dynamic>) {
        final Map<String, dynamic> responseData = response.data;
        if (responseData.containsKey('results')) {
          final List<dynamic> ordersJson = responseData['results'];
          return ordersJson.map((json) => Order.fromJson(json)).toList();
        }
      }
      
      // Handle direct array response
      if (response.data is List<dynamic>) {
        final List<dynamic> ordersJson = response.data;
        return ordersJson.map((json) => Order.fromJson(json)).toList();
      }
      
      throw ApiException('Unexpected response format from orders API');
    } catch (e) {
      throw ApiException('Failed to get orders: $e');
    }
  }

  Future<Order> getOrder(int orderId) async {
    try {
      final response = await _djangoDio.get('/orders/$orderId/');
      return Order.fromJson(response.data);
    } catch (e) {
      throw ApiException('Failed to get order: $e');
    }
  }

  Future<Order> createOrder(Map<String, dynamic> orderData) async {
    try {
      final response = await _djangoDio.post('/orders/', data: orderData);
      return Order.fromJson(response.data);
    } catch (e) {
      throw ApiException('Failed to create order: $e');
    }
  }

  Future<Order> updateOrder(int orderId, Map<String, dynamic> orderData) async {
    try {
      final response = await _djangoDio.put('/orders/$orderId/', data: orderData);
      return Order.fromJson(response.data);
    } catch (e) {
      throw ApiException('Failed to update order: $e');
    }
  }

  Future<Order> updateOrderStatus(int orderId, String status) async {
    try {
      final response = await _djangoDio.patch('/orders/$orderId/status/', data: {
        'status': status,
      });
      return Order.fromJson(response.data);
    } catch (e) {
      throw ApiException('Failed to update order status: $e');
    }
  }

  Future<void> deleteOrder(int orderId) async {
    try {
      await _djangoDio.delete('/orders/$orderId/');
    } catch (e) {
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
      return customersJson.map((json) => customer_model.Customer.fromJson(json)).toList();
    } catch (e) {
      throw ApiException('Failed to get customers: $e');
    }
  }

  Future<customer_model.Customer> createCustomer(Map<String, dynamic> customerData) async {
    try {
      final response = await _djangoDio.post('/auth/customers/', data: customerData);
      return customer_model.Customer.fromJson(response.data);
    } catch (e) {
      throw ApiException('Failed to create customer: $e');
    }
  }

  Future<customer_model.Customer> updateCustomer(int customerId, Map<String, dynamic> customerData) async {
    try {
      final response = await _djangoDio.put('/auth/customers/$customerId/', data: customerData);
      return customer_model.Customer.fromJson(response.data);
    } catch (e) {
      throw ApiException('Failed to update customer: $e');
    }
  }

  Future<customer_model.Customer> getCustomer(int customerId) async {
    try {
      final response = await _djangoDio.get('/auth/customers/$customerId/');
      return customer_model.Customer.fromJson(response.data);
    } catch (e) {
      throw ApiException('Failed to get customer: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getCustomerOrders(int customerId) async {
    try {
      final response = await _djangoDio.get('/orders/customer/$customerId/');
      final Map<String, dynamic> data = response.data;
      final List<dynamic> ordersJson = data['results'] ?? [];
      return List<Map<String, dynamic>>.from(ordersJson);
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
        return productsJson.map((json) => product_model.Product.fromJson(json)).toList();
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
      return product_model.Product.fromJson(response.data);
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
        return rulesJson.map((json) => PricingRule.fromJson(json)).toList();
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
      return PricingRule.fromJson(response.data);
    } catch (e) {
      throw ApiException('Failed to get pricing rule: $e');
    }
  }

  Future<PricingRule> createPricingRule(Map<String, dynamic> ruleData) async {
    try {
      final response = await _djangoDio.post('/inventory/pricing-rules/', data: ruleData);
      return PricingRule.fromJson(response.data);
    } catch (e) {
      throw ApiException(_extractErrorMessage(e, 'Failed to create pricing rule'));
    }
  }

  Future<PricingRule> updatePricingRule(int ruleId, Map<String, dynamic> ruleData) async {
    try {
      final response = await _djangoDio.put('/inventory/pricing-rules/$ruleId/', data: ruleData);
      return PricingRule.fromJson(response.data);
    } catch (e) {
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
      return pricesJson.map((json) => MarketPrice.fromJson(json)).toList();
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
        return listsJson.map((json) => CustomerPriceList.fromJson(json)).toList();
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
      return CustomerPriceList.fromJson(response.data);
    } catch (e) {
      throw ApiException('Failed to get customer price list: $e');
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
      return CustomerPriceList.fromJson(response.data);
    } catch (e) {
      throw ApiException('Failed to activate customer price list: $e');
    }
  }

  Future<CustomerPriceList> sendCustomerPriceListToCustomer(int listId) async {
    try {
      final response = await _djangoDio.post('/inventory/customer-price-lists/$listId/send_to_customer/');
      return CustomerPriceList.fromJson(response.data);
    } catch (e) {
      throw ApiException('Failed to send customer price list: $e');
    }
  }

  Future<CustomerPriceList> updateCustomerPriceListRule(int listId, int pricingRuleId) async {
    try {
      final response = await _djangoDio.patch('/inventory/customer-price-lists/$listId/', data: {
        'pricing_rule': pricingRuleId,
      });
      return CustomerPriceList.fromJson(response.data);
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
      return CustomerPriceList.fromJson(response.data);
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
  
  /// Load app configuration from database
  static Future<void> _loadAppConfig() async {
    try {
      final dio = Dio(BaseOptions(
        baseUrl: djangoBaseUrl, // Use hardcoded Django URL to fetch other config
        connectTimeout: AppConfig.connectionTimeout,
        receiveTimeout: AppConfig.apiTimeout,
      ));
      
      // Load all configuration in parallel for efficiency
      final results = await Future.wait([
        dio.get('/products/app-config/'),
        dio.get('/settings/form-options/'),
        dio.get('/settings/business-config/'),
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
  
  /// Force reload configuration from database
  static Future<void> reloadConfig() async {
    _configLoaded = false;
    await _loadAppConfig();
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
