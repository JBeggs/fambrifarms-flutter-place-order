import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/whatsapp_message.dart';
import '../models/order.dart';
import '../models/pricing_rule.dart';
import '../models/market_price.dart';
import '../models/customer_price_list.dart';
import '../models/customer.dart';
import '../models/product.dart';
import '../models/supplier.dart';

class ApiService {
  // Django URL must be hardcoded - it's needed to fetch other config from database
  static const String djangoBaseUrl = 'http://127.0.0.1:8000/api';
  
  // Everything else loaded from database via API
  static String _whatsappBaseUrl = 'http://127.0.0.1:5001/api'; // Fallback
  static int _defaultMessagesLimit = 100;
  static int _defaultStockUpdatesLimit = 50;
  static int _defaultProcessingLogsLimit = 200;
  static List<String> _customerSegments = ['standard']; // Fallback
  static double _defaultBaseMarkup = 1.25;
  static double _defaultVolatilityAdjustment = 0.15;
  static double _defaultTrendMultiplier = 1.10;
  static bool _configLoaded = false;
  
  // Getters for configuration
  static String get whatsappBaseUrl => _whatsappBaseUrl;
  static int get defaultMessagesLimit => _defaultMessagesLimit;
  static int get defaultStockUpdatesLimit => _defaultStockUpdatesLimit;
  static int get defaultProcessingLogsLimit => _defaultProcessingLogsLimit;
  static List<String> get customerSegments => _customerSegments;
  static double get defaultBaseMarkup => _defaultBaseMarkup;
  static double get defaultVolatilityAdjustment => _defaultVolatilityAdjustment;
  static double get defaultTrendMultiplier => _defaultTrendMultiplier;
  
  late final Dio _djangoDio;
  late final Dio _whatsappDio;
  
  // Authentication tokens
  String? _accessToken;
  String? _refreshToken;

  ApiService() {
    // Django backend connection
    _djangoDio = Dio(BaseOptions(
      baseUrl: djangoBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 120),
    ));
    
    // Python WhatsApp scraper connection
    _whatsappDio = Dio(BaseOptions(
      baseUrl: whatsappBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 300), // 5 minutes for WhatsApp startup
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
    
    // Add logging interceptors
    _djangoDio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (obj) => debugPrint('[DJANGO] $obj'),
    ));
    
    _whatsappDio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (obj) => debugPrint('[WHATSAPP] $obj'),
    ));
    
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
  Future<Map<String, dynamic>> startWhatsApp() async {
    try {
      final response = await _whatsappDio.post('/whatsapp/start');
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

  Future<Map<String, dynamic>> refreshMessages() async {
    try {
      // 1. Get fresh messages from Python scraper
      final scraperResponse = await _whatsappDio.get('/messages');
      
      // 2. Send scraped messages to Django for processing
      final djangoResponse = await _djangoDio.post('/whatsapp/receive-messages/', data: {
        'messages': scraperResponse.data
      });
      
      return djangoResponse.data;
    } catch (e) {
      throw ApiException('Failed to refresh messages: $e');
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

  Future<Order> updateOrder(int orderId, Map<String, dynamic> orderData) async {
    try {
      final response = await _djangoDio.put('/orders/$orderId/', data: orderData);
      return Order.fromJson(response.data);
    } catch (e) {
      throw ApiException('Failed to update order: $e');
    }
  }

  Future<void> deleteOrder(int orderId) async {
    try {
      await _djangoDio.delete('/orders/$orderId/');
    } catch (e) {
      throw ApiException('Failed to delete order: $e');
    }
  }

  Future<Order> updateOrderStatus(int orderId, String status) async {
    try {
      final response = await _djangoDio.patch('/orders/$orderId/update-status/', data: {
        'status': status,
      });
      return Order.fromJson(response.data);
    } catch (e) {
      throw ApiException('Failed to update order status: $e');
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

  Future<List<Map<String, dynamic>>> getProducts() async {
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

  Future<List<Customer>> getCustomers() async {
    try {
      final response = await _djangoDio.get('/auth/customers/');
      final List<dynamic> customersJson = response.data;
      return customersJson.map((json) => Customer.fromJson(json)).toList();
    } catch (e) {
      throw ApiException('Failed to get customers: $e');
    }
  }

  Future<List<Product>> getProducts() async {
    try {
      final response = await _djangoDio.get('/products/');
      final List<dynamic> productsJson = response.data;
      return productsJson.map((json) => Product.fromJson(json)).toList();
    } catch (e) {
      throw ApiException('Failed to get products: $e');
    }
  }

  Future<List<Supplier>> getSuppliers() async {
    try {
      final response = await _djangoDio.get('/suppliers/');
      final List<dynamic> suppliersJson = response.data;
      return suppliersJson.map((json) => Supplier.fromJson(json)).toList();
    } catch (e) {
      throw ApiException('Failed to get suppliers: $e');
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
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));
      
      final response = await dio.get('/products/app-config/');
      final config = response.data;
      
      // Update configuration from database (except Django URL which must stay hardcoded)
      _whatsappBaseUrl = config['whatsapp_base_url'] ?? _whatsappBaseUrl;
      _defaultMessagesLimit = config['default_messages_limit'] ?? _defaultMessagesLimit;
      _defaultStockUpdatesLimit = config['default_stock_updates_limit'] ?? _defaultStockUpdatesLimit;
      _customerSegments = List<String>.from(config['customer_segments'] ?? ['standard']);
      _defaultBaseMarkup = (config['default_base_markup'] ?? 1.25).toDouble();
      _defaultVolatilityAdjustment = (config['default_volatility_adjustment'] ?? 0.15).toDouble();
      _defaultTrendMultiplier = (config['default_trend_multiplier'] ?? 1.10).toDouble();
      
      _configLoaded = true;
      print('App configuration loaded from database');
    } catch (e) {
      print('Failed to load app configuration from database: $e');
      print('Using fallback configuration values');
      _configLoaded = true; // Don't keep retrying
    }
  }
  
  /// Force reload configuration from database
  static Future<void> reloadConfig() async {
    _configLoaded = false;
    await _loadAppConfig();
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

}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  
  @override
  String toString() => 'ApiException: $message';
}

// Provider for API service
final apiServiceProvider = Provider<ApiService>((ref) => ApiService());
