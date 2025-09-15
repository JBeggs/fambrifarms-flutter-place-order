import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/whatsapp_message.dart';
import '../services/api_service.dart';

// Messages state
class MessagesState {
  final List<WhatsAppMessage> messages;
  final Set<String> selectedMessageIds;
  final bool isLoading;
  final String? error;
  final bool whatsappRunning;

  const MessagesState({
    this.messages = const [],
    this.selectedMessageIds = const {},
    this.isLoading = false,
    this.error,
    this.whatsappRunning = false,
  });

  MessagesState copyWith({
    List<WhatsAppMessage>? messages,
    Set<String>? selectedMessageIds,
    bool? isLoading,
    String? error,
    bool? whatsappRunning,
  }) {
    return MessagesState(
      messages: messages ?? this.messages,
      selectedMessageIds: selectedMessageIds ?? this.selectedMessageIds,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      whatsappRunning: whatsappRunning ?? this.whatsappRunning,
    );
  }
}

// Messages notifier
class MessagesNotifier extends StateNotifier<MessagesState> {
  final ApiService _apiService;

  MessagesNotifier(this._apiService) : super(const MessagesState());

  // Start WhatsApp crawler
  Future<void> startWhatsApp() async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final result = await _apiService.startWhatsApp();
      state = state.copyWith(
        isLoading: false,
        whatsappRunning: true,
        error: result['status'] == 'qr_code' ? 'Please scan QR code with your phone' : null,
      );
      
      // Start polling for messages
      _startMessagePolling();
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
      state = state.copyWith(whatsappRunning: false);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  // Load messages
  Future<void> loadMessages() async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      // When WhatsApp is running, refresh will scrape and POST to Django, then pull back
      if (state.whatsappRunning) {
        await refreshMessages();
        state = state.copyWith(isLoading: false);
        return;
      }
      
      final messages = await _apiService.getMessages();
      // Sort by WhatsApp ISO timestamp (DateTime) ascending (oldest first, latest at bottom)
      messages.sort((a, b) =>
          DateTime.parse(a.timestamp).compareTo(DateTime.parse(b.timestamp)));
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

  // Refresh messages
  Future<void> refreshMessages() async {
    if (!state.whatsappRunning) return;
    
    try {
      await _apiService.refreshMessages();
      final messages = await _apiService.getMessages();
      messages.sort((a, b) =>
          DateTime.parse(a.timestamp).compareTo(DateTime.parse(b.timestamp)));
      state = state.copyWith(messages: messages);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
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
    state = state.copyWith(selectedMessageIds: {});
  }

  // Edit message
  Future<void> editMessage(String databaseId, String editedContent, {bool? processed}) async {
    try {
      // Find the message to get the WhatsApp messageId
      final message = state.messages.firstWhere((msg) => msg.id == databaseId);
      final whatsappMessageId = message.messageId;
      
      if (whatsappMessageId == null) {
        throw Exception('Message does not have a WhatsApp message ID');
      }
      
      final updatedMessage = await _apiService.editMessage(whatsappMessageId, editedContent, processed: processed);
      
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
      await loadMessages();
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
      await loadMessages();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  // Process selected messages
  Future<void> processSelectedMessages() async {
    if (state.selectedMessageIds.isEmpty) return;
    
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      // Convert database IDs to WhatsApp message IDs
      final whatsappMessageIds = <String>[];
      for (final dbId in state.selectedMessageIds) {
        final message = state.messages.firstWhere(
          (msg) => msg.id == dbId,
          orElse: () => throw Exception('Message with ID $dbId not found'),
        );
        if (message.messageId != null) {
          whatsappMessageIds.add(message.messageId!);
        } else {
          throw Exception('Message with ID $dbId has no WhatsApp message ID');
        }
      }
      
      final result = await _apiService.processMessages(whatsappMessageIds);
      
      // Clear selection after processing
      state = state.copyWith(
        isLoading: false,
        selectedMessageIds: {},
      );
      
      // Show success message or handle result
      debugPrint('Processed: ${result['processed_count']} messages');
      debugPrint('Orders: ${result['orders']?.length ?? 0}');
      debugPrint('Stock updates: ${result['stock_updates']?.length ?? 0}');
      
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  // Start polling for new messages
  void _startMessagePolling() {
    // Poll every 10 seconds when WhatsApp is running
    Future.delayed(const Duration(seconds: 10), () {
      if (state.whatsappRunning) {
        refreshMessages();
        _startMessagePolling();
      }
    });
  }

  // Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

// Provider
final messagesProvider = StateNotifierProvider<MessagesNotifier, MessagesState>((ref) {
  final apiService = ref.read(apiServiceProvider);
  return MessagesNotifier(apiService);
});
