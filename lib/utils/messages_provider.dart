import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../models/whatsapp_message.dart';
import '../services/api_service.dart';
import '../config/app_config.dart';
import '../providers/inventory_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/orders_provider.dart';
import 'dart:async';

// Messages state
class MessagesState {
  final List<WhatsAppMessage> messages;
  final Set<String> selectedMessageIds;
  final bool isLoading;
  final String? error;
  final bool whatsappRunning;
  final Map<String, dynamic>? lastProcessingResult;
  final int currentPage;
  final int pageSize;
  final int totalPages;
  final int totalCount;

  const MessagesState({
    this.messages = const [],
    this.selectedMessageIds = const {},
    this.isLoading = false,
    this.error,
    this.whatsappRunning = false,
    this.lastProcessingResult,
    this.currentPage = 1,
    this.pageSize = 20,
    this.totalPages = 0,
    this.totalCount = 0,
  });

  MessagesState copyWith({
    List<WhatsAppMessage>? messages,
    Set<String>? selectedMessageIds,
    bool? isLoading,
    String? error,
    bool? whatsappRunning,
    Map<String, dynamic>? lastProcessingResult,
    int? currentPage,
    int? pageSize,
    int? totalPages,
    int? totalCount,
  }) {
    return MessagesState(
      messages: messages ?? this.messages,
      selectedMessageIds: selectedMessageIds != null ? Set<String>.from(selectedMessageIds) : this.selectedMessageIds,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      whatsappRunning: whatsappRunning ?? this.whatsappRunning,
      lastProcessingResult: lastProcessingResult ?? this.lastProcessingResult,
      currentPage: currentPage ?? this.currentPage,
      pageSize: pageSize ?? this.pageSize,
      totalPages: totalPages ?? this.totalPages,
      totalCount: totalCount ?? this.totalCount,
    );
  }
}

// Messages notifier
class MessagesNotifier extends StateNotifier<MessagesState> {
  final ApiService _apiService;
  final Ref _ref;
  Timer? _statusCheckTimer;

  MessagesNotifier(this._apiService, this._ref) : super(const MessagesState());

  // Start WhatsApp crawler
  Future<void> startWhatsApp() async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final result = await _apiService.startWhatsApp(
        checkInterval: AppConfig.whatsappCheckInterval
      );
      state = state.copyWith(
        isLoading: false,
        whatsappRunning: true,
        error: result['status'] == 'qr_code' ? 'Please scan QR code with your phone' : null,
      );
      
      // Start simple status monitoring (no message polling)
      _startStatusMonitoring();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  // Stop WhatsApp crawler
  Future<void> stopWhatsApp() async {
    try {
      await _apiService.stopWhatsApp();
      _stopStatusMonitoring();
      state = state.copyWith(whatsappRunning: false);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  // Load messages with pagination support
  Future<void> loadMessages({int page = 1, int pageSize = 20}) async {
    debugPrint('🔄 MESSAGES: Starting loadMessages (page $page, size $pageSize)...');
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final messages = await _apiService.getMessages(page: page, pageSize: pageSize);
      debugPrint('📥 MESSAGES: Received ${messages.length} messages from API');
      
      // Get pagination data from API
      final paginationData = await _apiService.getMessagesPagination(page: page, pageSize: pageSize);
      
      // Backend now provides messages in correct chronological order (oldest first)
      // No need to sort here anymore
      
      // Debug: Check if any message has updated content
      for (var msg in messages.take(3)) {
        debugPrint('📄 MESSAGES: Message ${msg.id} content preview: ${msg.content.substring(0, math.min(50, msg.content.length))}...');
      }
      
      state = state.copyWith(
        messages: messages,
        isLoading: false,
        currentPage: page,
        pageSize: pageSize,
        totalPages: paginationData['total_pages'] ?? 0,
        totalCount: paginationData['total_count'] ?? 0,
      );
      debugPrint('✅ MESSAGES: Successfully loaded and updated state with ${messages.length} messages');
    } catch (e) {
      debugPrint('❌ MESSAGES: Error loading messages: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  // Refresh messages (simplified - manual scan trigger)
  Future<void> refreshMessages({bool scrollToLoadMore = false}) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      if (state.whatsappRunning) {
        // Trigger manual scan via Python API (which sends to Django automatically)
        await _apiService.refreshMessages(scrollToLoadMore: scrollToLoadMore);
      }
      
      // Always get latest messages from Django with current pagination
      final messages = await _apiService.getMessages(
        page: state.currentPage, 
        pageSize: state.pageSize
      );
      // Backend now provides messages in correct chronological order (oldest first)
      // No need to sort here anymore
      
      state = state.copyWith(
        messages: messages,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  // Pagination navigation methods
  Future<void> goToPage(int page) async {
    if (page < 1 || page > state.totalPages) return;
    await loadMessages(page: page, pageSize: state.pageSize);
  }

  Future<void> nextPage() async {
    if (state.currentPage < state.totalPages) {
      await goToPage(state.currentPage + 1);
    }
  }

  Future<void> previousPage() async {
    if (state.currentPage > 1) {
      await goToPage(state.currentPage - 1);
    }
  }

  Future<void> changePageSize(int newPageSize) async {
    await loadMessages(page: 1, pageSize: newPageSize);
  }

  // Toggle message selection
  void toggleMessageSelection(String messageId) {
    final newSelection = Set<String>.from(state.selectedMessageIds);
    if (newSelection.contains(messageId)) {
      newSelection.remove(messageId);
    } else {
      newSelection.add(messageId);
    }
    state = state.copyWith(selectedMessageIds: newSelection);
  }

  // Select all messages
  void selectAllMessages() {
    final allIds = state.messages.map((m) => m.id).toSet();
    state = state.copyWith(selectedMessageIds: allIds);
  }

  // Clear selection
  void clearSelection() {
    debugPrint('🔄 MESSAGES: Clearing selection - before: ${state.selectedMessageIds.length} selected');
    state = state.copyWith(selectedMessageIds: <String>{});
    debugPrint('🔄 MESSAGES: Clearing selection - after: ${state.selectedMessageIds.length} selected');
  }

  // Edit message
  Future<void> editMessage(String databaseId, String editedContent, {bool? processed}) async {
    try {
      print('🔄 PROVIDER: editMessage called for databaseId: $databaseId');
      
      // Find the message to get the WhatsApp messageId
      final message = state.messages.firstWhere((msg) => msg.id == databaseId);
      final whatsappMessageId = message.messageId;
      
      print('🔄 PROVIDER: Found whatsappMessageId: $whatsappMessageId');
      
      if (whatsappMessageId == null) {
        throw Exception('Message does not have a WhatsApp message ID');
      }
      
      print('🔄 PROVIDER: Calling API editMessage...');
      final updatedMessage = await _apiService.editMessage(whatsappMessageId, editedContent, processed: processed);
      print('🔄 PROVIDER: API returned message with content: "${updatedMessage.content}"');
      
      final updatedMessages = state.messages.map((message) {
        return message.id == databaseId ? updatedMessage : message;
      }).toList();
      
      print('🔄 PROVIDER: Updating state with ${updatedMessages.length} messages');
      state = state.copyWith(messages: updatedMessages);
      print('🔄 PROVIDER: State updated successfully');
    } catch (e) {
      print('🔄 PROVIDER ERROR: $e');
      state = state.copyWith(error: e.toString());
    }
  }

  // Update message type
  Future<void> updateMessageType(String databaseId, MessageType newType) async {
    try {
      final updatedMessage = await _apiService.updateMessageType(databaseId, newType.name);
      
      final updatedMessages = state.messages.map((message) {
        return message.id == databaseId ? updatedMessage : message;
      }).toList();
      
      state = state.copyWith(messages: updatedMessages);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  // Update message company name (local update)
  Future<void> updateMessageCompany(String messageId, String? companyName) async {
    try {
      // Update the backend first
      await _apiService.updateMessageCompany(messageId, companyName);
      
      // Then update local state
    final updatedMessages = state.messages.map((message) {
      if (message.id == messageId) {
        return WhatsAppMessage(
          id: message.id,
          messageId: message.messageId,
          chat: message.chat,
          sender: message.sender,
          senderPhone: message.senderPhone,
          content: message.content,
          cleanedContent: message.cleanedContent,
          timestamp: message.timestamp,
          scrapedAt: message.scrapedAt,
          type: message.type,
          items: message.items,
          instructions: message.instructions,
          edited: message.edited,
          originalContent: message.originalContent,
          processed: message.processed,
          orderDay: message.orderDay,
          confidenceScore: message.confidenceScore,
          companyName: companyName, // Update company name
          manualCompany: companyName, // Set manual company to the selected company
          isStockController: message.isStockController,
          orderDetails: message.orderDetails,
          messageType: message.messageType,
          mediaUrl: message.mediaUrl,
          mediaInfo: message.mediaInfo,
          isForwarded: message.isForwarded,
          forwardedInfo: message.forwardedInfo,
          isReply: message.isReply,
          replyContent: message.replyContent,
        );
      }
      return message;
    }).toList();
    
    state = state.copyWith(messages: updatedMessages);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  // Delete single message
  Future<void> deleteMessage(String messageId) async {
    try {
      await _apiService.deleteMessage(messageId);
      
      // Refresh messages from server to ensure consistency with Django soft delete
      // Preserve current pagination state
      await loadMessages(page: state.currentPage, pageSize: state.pageSize);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  // Delete selected messages
  Future<void> deleteSelectedMessages() async {
    if (state.selectedMessageIds.isEmpty) return;
    
    try {
      await _apiService.deleteMessages(state.selectedMessageIds.toList());
      
      // Refresh messages from server to ensure consistency with Django soft delete
      // Preserve current pagination state
      await loadMessages(page: state.currentPage, pageSize: state.pageSize);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  // TODO: DEPRECATED - This method is only used for stock messages now
  // Order messages use the streamlined flow with processMessageWithSuggestions
  // Process selected messages
  Future<void> processSelectedMessages() async {
    if (state.selectedMessageIds.isEmpty) return;
    
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      // Get selected messages and separate by type
      final selectedMessages = state.messages.where(
        (msg) => state.selectedMessageIds.contains(msg.id)
      ).toList();
      
      final orderMessages = <String>[];
      final stockMessages = <String>[];
      
      for (final message in selectedMessages) {
        if (message.messageId != null) {
          if (message.type == MessageType.stock) {
            stockMessages.add(message.messageId!);
          } else if (message.type == MessageType.order) {
            orderMessages.add(message.messageId!);
          }
        }
      }
      
      Map<String, dynamic> result = {
        'orders_created': 0,
        'stock_updates_created': 0,
        'errors': [],
        'warnings': []
      };
      
      // Process order messages
      if (orderMessages.isNotEmpty) {
        final orderResult = await _apiService.processMessages(orderMessages);
        
        // Handle new response format with suggestions
        if (orderResult['status'] == 'failed' && orderResult['failed_products'] != null) {
          // New format with suggestions
          result['status'] = 'failed';
          result['message'] = orderResult['message'];
          result['failed_products'] = orderResult['failed_products'];
          result['parsing_failures'] = orderResult['parsing_failures'] ?? [];
          result['unparseable_lines'] = orderResult['unparseable_lines'] ?? [];
          result['orders_created'] = 0;
        } else {
          // Old format
          result['orders_created'] = orderResult['orders_created'] ?? 0;
          result['errors'].addAll(orderResult['errors'] ?? []);
          result['warnings'].addAll(orderResult['warnings'] ?? []);
        }
      }
      
      // Process stock messages and apply to inventory
      if (stockMessages.isNotEmpty) {
        final stockResult = await _apiService.processStockAndApplyToInventory(
          stockMessages, 
          resetBeforeProcessing: true, // Default to complete stock take
        );
        result['stock_updates_created'] = stockResult['stock_updates_created'] ?? 0;
        result['inventory_updates'] = stockResult['inventory_updates'] ?? {};
        result['errors'].addAll(stockResult['errors'] ?? []);
        result['warnings'].addAll(stockResult['warnings'] ?? []);
      }
      
      // Don't clear selection yet - dialog needs it
      state = state.copyWith(
        isLoading: false,
      );
      
      // Refresh related providers after processing
      if (orderMessages.isNotEmpty || stockMessages.isNotEmpty) {
        debugPrint('Message processing completed, refreshing messages and related providers...');
        try {
          // Always refresh messages to show updated processing notes
          await refreshMessages();
          
          // Refresh inventory data if stock updates were created
          if (result['stock_updates_created'] != null && result['stock_updates_created'] > 0) {
            await _ref.read(inventoryProvider.notifier).refreshAll();
          }
          
          // Refresh orders if orders were processed (success or failure)
          if (orderMessages.isNotEmpty) {
            _ref.read(ordersProvider.notifier).loadOrders();
          }
          
          // Refresh dashboard data  
          _ref.read(dashboardProvider.notifier).refresh();
          debugPrint('Successfully refreshed messages and related providers after processing');
        } catch (e) {
          debugPrint('Error refreshing providers after processing: $e');
        }
      }
      
      // Show success message or handle result
      debugPrint('Orders created: ${result['orders_created']}');
      debugPrint('Stock updates created: ${result['stock_updates_created']}');
      debugPrint('Errors: ${result['errors']?.length ?? 0}');
      debugPrint('Warnings: ${result['warnings']?.length ?? 0}');
      
      // Store processing result for UI to display
      final resultString = result.toString();
      final preview = resultString.length > 200 
          ? '${resultString.substring(0, 200)}...' 
          : resultString;
      debugPrint('📋 Storing processing result: $preview');
      state = state.copyWith(
        lastProcessingResult: result,
        isLoading: false
      );
      debugPrint('✅ Processing result stored in state');
      
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Process a single message with always-suggestions flow
  Future<Map<String, dynamic>> processMessageWithSuggestions(String messageId) async {
    final apiService = ApiService();
    
    try {
      final result = await apiService.processMessageWithSuggestions(messageId);
      
      if (result['status'] == 'success') {
        return {
          'status': 'success',
          'message': result['message'],
          'customer': result['customer'],
          'items': result['items'],
          'total_items': result['total_items'],
        };
      } else {
        return {
          'status': 'error',
          'message': result['message'],
          'items': result['items'] ?? [],
        };
      }
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Failed to process message with suggestions: $e',
        'items': [],
      };
    }
  }

  // Start polling for new messages
  // Simple status monitoring (no message polling)
  void _startStatusMonitoring() {
    _stopStatusMonitoring(); // Ensure no duplicate timers
    
    _statusCheckTimer = Timer.periodic(
      AppConfig.whatsappStatusCheckDuration,
      (timer) async {
        if (!mounted) {
          timer.cancel();
          return;
        }
        
        try {
          // Just check if WhatsApp is still running
          final status = await _apiService.getWhatsAppStatus();
          final isRunning = status['running'] == true;
          
          if (state.whatsappRunning != isRunning) {
            state = state.copyWith(whatsappRunning: isRunning);
            
            if (!isRunning) {
              // WhatsApp stopped, cancel monitoring
              timer.cancel();
            }
          }
        } catch (e) {
          // If status check fails, assume WhatsApp is not running
          if (state.whatsappRunning) {
            state = state.copyWith(whatsappRunning: false);
            timer.cancel();
          }
        }
      },
    );
  }
  
  void _stopStatusMonitoring() {
    _statusCheckTimer?.cancel();
    _statusCheckTimer = null;
  }

  // Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }

  Future<Map<String, dynamic>> processStockMessageWithSuggestions(String messageId) async {
    try {
      final result = await _apiService.processStockMessageWithSuggestions(messageId);
      
      if (result['status'] == 'success') {
        return {
          'status': 'success',
          'message': result['message'],
          'customer': result['customer'],
          'items': result['items'],
          'total_items': result['total_items'],
          'stock_date': result['stock_date'],
          'order_day': result['order_day'],
        };
      } else {
        return {
          'status': 'error',
          'message': result['message'],
          'items': result['items'] ?? [],
        };
      }
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Failed to process stock message with suggestions: $e',
        'items': [],
      };
    }
  }
  
  @override
  void dispose() {
    _stopStatusMonitoring();
    super.dispose();
  }
}

// Provider
final messagesProvider = StateNotifierProvider<MessagesNotifier, MessagesState>((ref) {
  final apiService = ref.read(apiServiceProvider);
  return MessagesNotifier(apiService, ref);
});
