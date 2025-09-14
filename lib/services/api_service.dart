import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/whatsapp_message.dart';
import '../models/order.dart';

class ApiService {
  static const String djangoBaseUrl = 'http://127.0.0.1:8000/api';  // Django backend
  static const String whatsappBaseUrl = 'http://127.0.0.1:5001/api'; // Python scraper
  late final Dio _djangoDio;
  late final Dio _whatsappDio;

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
    
    // Add logging interceptors
    _djangoDio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (obj) => print('[DJANGO] $obj'),
    ));
    
    _whatsappDio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (obj) => print('[WHATSAPP] $obj'),
    ));
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
  Future<List<WhatsAppMessage>> getMessages() async {
    try {
      // Get processed messages from Django backend
      final response = await _djangoDio.get('/whatsapp/messages/');
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

  Future<WhatsAppMessage> editMessage(String messageId, String editedContent) async {
    try {
      final response = await _djangoDio.post('/whatsapp/messages/edit/', data: {
        'message_id': messageId,  // This should be the WhatsApp messageId, not the database id
        'edited_content': editedContent,
      });
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
      final List<dynamic> ordersJson = response.data;
      return ordersJson.map((json) => Order.fromJson(json)).toList();
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

  Future<List<Map<String, dynamic>>> getStockUpdates() async {
    try {
      final response = await _djangoDio.get('/whatsapp/stock-updates/');
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

  Future<List<Map<String, dynamic>>> getCustomers() async {
    try {
      final response = await _djangoDio.get('/auth/customers/');
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      throw ApiException('Failed to get customers: $e');
    }
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
