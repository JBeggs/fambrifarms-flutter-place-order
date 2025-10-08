import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/whatsapp_message.dart';
import '../../utils/messages_provider.dart';
import '../../services/api_service.dart';
import 'widgets/message_card.dart';
import 'widgets/enhanced_processing_result_dialog.dart';
import 'widgets/always_suggestions_dialog.dart';
import 'widgets/stock_suggestions_dialog.dart';
import 'widgets/message_editor.dart';
import 'widgets/pagination_controls.dart';

class MessagesPage extends ConsumerStatefulWidget {
  const MessagesPage({super.key});

  @override
  ConsumerState<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends ConsumerState<MessagesPage> {
  WhatsAppMessage? selectedMessageForEditing;
  bool showProcessedMessages = true;

  String _getMessageIdForDialog(MessagesState messagesState) {
    try {
      debugPrint('🔍 _getMessageIdForDialog: Starting...');
      debugPrint('🔍 _getMessageIdForDialog: selectedMessageIds: ${messagesState.selectedMessageIds}');
      debugPrint('🔍 _getMessageIdForDialog: selectedMessageIds.isEmpty: ${messagesState.selectedMessageIds.isEmpty}');
      debugPrint('🔍 _getMessageIdForDialog: messages.length: ${messagesState.messages.length}');
      
      if (messagesState.selectedMessageIds.isEmpty) {
        debugPrint('🔍 _getMessageIdForDialog: No selected messages - returning empty string');
        return '';
      }
      
      // Find the first selected message and return its messageId (WhatsApp ID)
      debugPrint('🔍 _getMessageIdForDialog: Looking for message with ID in: ${messagesState.selectedMessageIds}');
      
      final selectedMessage = messagesState.messages.firstWhere(
        (msg) => messagesState.selectedMessageIds.contains(msg.id),
      );
      
      debugPrint('🔍 _getMessageIdForDialog: Found selected message:');
      debugPrint('  - Database ID: ${selectedMessage.id}');
      debugPrint('  - messageId: ${selectedMessage.messageId}');
      debugPrint('  - messageId is null: ${selectedMessage.messageId == null}');
      debugPrint('  - messageId isEmpty: ${selectedMessage.messageId?.isEmpty ?? true}');
      
      // Safe content preview
      try {
        final contentPreview = selectedMessage.content.length > 50 
            ? selectedMessage.content.substring(0, 50) + "..." 
            : selectedMessage.content;
        debugPrint('  - Content preview: "$contentPreview"');
      } catch (e) {
        debugPrint('  - Content preview: Error getting content preview: $e');
      }
      
      final messageId = selectedMessage.messageId ?? '';
      
      if (messageId.isEmpty) {
        debugPrint('❌ ERROR: messageId is empty for selected message!');
        debugPrint('❌ This means the message was not loaded with messageId from the API');
      } else {
        debugPrint('✅ SUCCESS: Found valid messageId: "$messageId"');
      }
      
      return messageId;
    } catch (e, stackTrace) {
      debugPrint('❌ _getMessageIdForDialog: Error finding message: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      debugPrint('❌ Available message IDs: ${messagesState.messages.map((m) => m.id).toList()}');
      return '';
    }
  }

  @override
  void initState() {
    super.initState();
    // Load messages when page opens with pagination
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(messagesProvider.notifier).loadMessages(page: 1, pageSize: 20);
    });
  }

  // TODO: DEPRECATED - This method is only used for stock messages now
  // Can be removed when stock message processing is also streamlined
  Future<void> _retryProcessingWithCorrections(BuildContext context, messagesNotifier, messagesState) async {
    try {
      final messageId = _getMessageIdForDialog(messagesState);
      if (messageId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: No message selected for reprocessing'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Show loading indicator
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      try {
        // Call the proper reprocessing endpoint
        final apiService = ref.read(apiServiceProvider);
        final result = await apiService.reprocessMessageWithCorrections(messageId);
        
        // Close loading dialog
        if (mounted) {
          Navigator.of(context).pop();
        }
        
        if (result['status'] == 'success') {
          // Success - refresh messages and show success
          await messagesNotifier.loadMessages(
            page: ref.read(messagesProvider).currentPage, 
            pageSize: ref.read(messagesProvider).pageSize
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Message reprocessed successfully!'),
                backgroundColor: Colors.green,
              ),
            );
            
            // Navigate to orders page if orders were created
            final ordersCreated = result['orders_created'] ?? 0;
            if (ordersCreated > 0) {
              context.go('/orders');
            }
          }
        } else {
          // Still has errors - show the result dialog again
          if (mounted) {
            await showDialog(
              context: context,
              builder: (context) => EnhancedProcessingResultDialog(
                result: result,
                messageId: messageId,
                onRetry: () async {
                  Navigator.of(context).pop();
                  await _retryProcessingWithCorrections(context, messagesNotifier, messagesState);
                },
              ),
            );
          }
        }
      } catch (e) {
        // Close loading dialog
        if (mounted) {
          Navigator.of(context).pop();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to reprocess message: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error during reprocessing: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _processSelectedMessages(BuildContext context, messagesNotifier, messagesState) async {
    try {
      final selectedCount = messagesState.selectedMessageIds.length;
      debugPrint('🔍 Selected messages count: $selectedCount');
      debugPrint('🔍 Selected message IDs: ${messagesState.selectedMessageIds}');
      
      final orderMessages = messagesState.messages
          .where((msg) => messagesState.selectedMessageIds.contains(msg.id) && msg.type == MessageType.order)
          .toList();
      final stockCount = messagesState.messages
          .where((msg) => messagesState.selectedMessageIds.contains(msg.id) && msg.type == MessageType.stock)
          .length;
      
      // Check if any order messages don't have a customer selected
      final orderMessagesWithoutCustomer = orderMessages.where((msg) {
        final hasManualCompany = msg.manualCompany != null && msg.manualCompany!.isNotEmpty && msg.manualCompany != 'Clear Selection';
        final hasCompanyName = msg.companyName != null && msg.companyName!.isNotEmpty && msg.companyName != 'Clear Selection';
        final hasCustomer = hasManualCompany || hasCompanyName;
        
        debugPrint('🔍 Message ${msg.id}: manualCompany="${msg.manualCompany}", companyName="${msg.companyName}", hasCustomer=$hasCustomer');
        
        return !hasCustomer;
      }).toList();
      
      if (orderMessagesWithoutCustomer.isNotEmpty) {
        // Show error alert for messages without customer selection
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                SizedBox(width: 8),
                Text('Customer Selection Required'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('The following order messages need a customer selected before processing:'),
                const SizedBox(height: 12),
                ...orderMessagesWithoutCustomer.take(3).map((msg) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '• ${msg.content.length > 50 ? msg.content.substring(0, 50) + '...' : msg.content}',
                    style: const TextStyle(fontSize: 12),
                  ),
                )),
                if (orderMessagesWithoutCustomer.length > 3)
                  Text('• ... and ${orderMessagesWithoutCustomer.length - 3} more messages'),
                const SizedBox(height: 12),
                const Text(
                  'Please select a customer for each order message using the dropdown menu.',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return; // Don't proceed with processing
      }
      
      final orderCount = orderMessages.length;
      
      debugPrint('🔍 Order messages: $orderCount, Stock messages: $stockCount');
      
      // For order messages, go directly to suggestions flow
      if (orderCount > 0) {
        await _processOrderMessagesDirectly(context, messagesNotifier, messagesState);
      } else if (stockCount > 0) {
        // For stock messages, go directly to suggestions flow
        await _processStockMessagesDirectly(context, messagesNotifier, messagesState);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process messages: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _processOrderMessagesDirectly(BuildContext context, messagesNotifier, messagesState) async {
    try {
      // Get the first selected order message
      final orderMessages = messagesState.messages
          .where((msg) => messagesState.selectedMessageIds.contains(msg.id) && msg.type == MessageType.order)
          .toList();
      
      if (orderMessages.isEmpty) return;
      
      final message = orderMessages.first;
      final messageId = message.messageId ?? '';
      
      if (messageId.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: Message ID not found'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      // Show loading indicator
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }
      
      try {
        // Process the message with always-suggestions directly
        final result = await messagesNotifier.processMessageWithSuggestions(messageId);
        
        // Close loading dialog
        if (context.mounted) {
          Navigator.of(context).pop();
        }
        
        if (result['status'] == 'success') {
          // Show the always-suggestions dialog directly
          if (context.mounted) {
            await showDialog(
              context: context,
              builder: (context) => AlwaysSuggestionsDialog(
                messageId: messageId,
                suggestionsData: result,
              ),
            );
            
            // Refresh messages after dialog is closed
            await messagesNotifier.loadMessages(
              page: ref.read(messagesProvider).currentPage, 
              pageSize: ref.read(messagesProvider).pageSize
            );
            
            // Clear selection after dialog is closed
            messagesNotifier.clearSelection();
          }
        } else {
          // Show error
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: ${result['message']}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        // Close loading dialog
        if (context.mounted) {
          Navigator.of(context).pop();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to process message: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing order messages: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _processStockMessagesDirectly(BuildContext context, messagesNotifier, messagesState) async {
    try {
      // Get the first selected stock message
      final stockMessages = messagesState.messages
          .where((msg) => messagesState.selectedMessageIds.contains(msg.id) && msg.type == MessageType.stock)
          .toList();
      
      if (stockMessages.isEmpty) return;
      
      final message = stockMessages.first;
      final messageId = message.messageId ?? '';
      
      if (messageId.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: Message ID not found'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      // Show loading indicator
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }
      
      try {
        // Process the stock message with suggestions directly
        final result = await messagesNotifier.processStockMessageWithSuggestions(messageId);
        
        // Close loading dialog
        if (context.mounted) {
          Navigator.of(context).pop();
        }
        
        if (result['status'] == 'success') {
          // Show the stock suggestions dialog directly
          if (context.mounted) {
            await showDialog(
              context: context,
              builder: (context) => StockSuggestionsDialog(
                messageId: messageId,
                suggestionsData: result,
              ),
            );
            
            // Refresh messages after dialog is closed
            await messagesNotifier.loadMessages(
              page: ref.read(messagesProvider).currentPage, 
              pageSize: ref.read(messagesProvider).pageSize
            );
            
            // Clear selection after dialog is closed
            messagesNotifier.clearSelection();
          }
        } else {
          // Show error
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: ${result['message']}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        // Close loading dialog
        if (context.mounted) {
          Navigator.of(context).pop();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to process stock message: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing stock messages: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // TODO: DEPRECATED - This method uses the old multi-popup flow for stock messages
  // Consider streamlining stock message processing to match order message flow
  Future<void> _processStockMessages(BuildContext context, messagesNotifier, messagesState) async {
    try {
      final selectedCount = messagesState.selectedMessageIds.length;
      final stockCount = messagesState.messages
          .where((msg) => messagesState.selectedMessageIds.contains(msg.id) && msg.type == MessageType.stock)
          .length;
      
      String contentText = 'Process $selectedCount selected messages?\n\n';
      contentText += '• $stockCount stock messages → Update inventory\n';
      
      // Show confirmation dialog for stock messages
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Process Messages'),
          content: Text(contentText),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Process Messages'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        // Call the processSelectedMessages method
        await messagesNotifier.processSelectedMessages();
        
        if (context.mounted) {
          // Show processing result dialog
          final result = messagesNotifier.state.lastProcessingResult;
          debugPrint('🔍 Processing result: $result');
          if (result != null) {
            debugPrint('✅ Showing processing result dialog');
            
            // Get messageId BEFORE showing dialog
            final messageId = _getMessageIdForDialog(messagesNotifier.state);
            debugPrint('🔍 Dialog messageId: "$messageId"');
            
            await showDialog(
              context: context,
              builder: (context) => EnhancedProcessingResultDialog(
                result: result,
                messageId: messageId,
                onRetry: () async {
                  Navigator.of(context).pop();
                  // Retry processing with corrections
                  await _retryProcessingWithCorrections(context, messagesNotifier, messagesNotifier.state);
                },
              ),
            );
            
            // Refresh messages to show updated content after processing
            debugPrint('🔄 Refreshing messages after processing dialog closed...');
            // Add a small delay to ensure backend has updated the message
            await Future.delayed(const Duration(milliseconds: 500));
            await messagesNotifier.loadMessages(
              page: ref.read(messagesProvider).currentPage, 
              pageSize: ref.read(messagesProvider).pageSize
            );
            
            // Clear selection after dialog is closed
            messagesNotifier.clearSelection();
            
            // Navigate to orders page if orders were created
            final ordersCreated = result['orders_created'] ?? 0;
            if (ordersCreated > 0) {
              context.go('/orders');
            }
          } else {
            debugPrint('❌ No processing result found');
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process stock messages: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final messagesState = ref.watch(messagesProvider);
    final messagesNotifier = ref.read(messagesProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('WhatsApp Messages'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          // WhatsApp status indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: messagesState.whatsappRunning ? Colors.green : Colors.grey,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  messagesState.whatsappRunning ? Icons.circle : Icons.circle_outlined,
                  size: 12,
                  color: Colors.white,
                ),
                const SizedBox(width: 4),
                Text(
                  messagesState.whatsappRunning ? 'Connected' : 'Disconnected',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Row(
        children: [
          // Messages List (Left Panel)
          Expanded(
            flex: 2,
            child: Column(
              children: [
                // Control Bar
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: IntrinsicWidth(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                      // WhatsApp Controls
                      ElevatedButton.icon(
                        onPressed: messagesState.isLoading
                            ? null
                            : messagesState.whatsappRunning
                                ? messagesNotifier.stopWhatsApp
                                : messagesNotifier.startWhatsApp,
                        icon: Icon(messagesState.whatsappRunning ? Icons.stop : Icons.play_arrow),
                        label: Text(messagesState.whatsappRunning ? 'Stop WhatsApp' : 'Start WhatsApp'),
                      ),
                      
                      const SizedBox(width: 12),
                      
                      // Refresh Button
                      IconButton(
                        onPressed: messagesState.whatsappRunning ? messagesNotifier.refreshMessages : null,
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Refresh Messages',
                      ),
                      
                      const SizedBox(width: 12),
                      
                      // Processed Messages Filter
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.filter_list,
                            size: 16,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          // Commented out for smaller screens - can be re-enabled later
                          // const SizedBox(width: 4),
                          // Text(
                          //   'Show Processed',
                          //   style: Theme.of(context).textTheme.bodySmall,
                          // ),
                          // const SizedBox(width: 4),
                          // Switch(
                          //   value: showProcessedMessages,
                          //   onChanged: (value) {
                          //     setState(() {
                          //       showProcessedMessages = value;
                          //     });
                          //   },
                          //   materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          // ),
                        ],
                      ),
                      
                      const Spacer(),
                      
                      // Selection Info and Message Count
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (messagesState.selectedMessageIds.isNotEmpty)
                            Text(
                              '${messagesState.selectedMessageIds.length} selected',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          Text(
                            showProcessedMessages 
                                ? '${messagesState.messages.length} of ${messagesState.totalCount} messages (Page ${ref.read(messagesProvider).currentPage}/${messagesState.totalPages})'
                                : '${messagesState.messages.where((m) => !m.processed).length} unprocessed messages',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(width: 12),
                      
                      // Selection Controls
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: messagesState.messages.isEmpty ? null : messagesNotifier.selectAllMessages,
                            child: const Text('Select All'),
                          ),
                          TextButton(
                            onPressed: messagesState.selectedMessageIds.isEmpty ? null : messagesNotifier.clearSelection,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: const Size(0, 0),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Deselect All',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(width: 12),
                      
                      // Process Button - Now goes directly to suggestions for order messages
                      ElevatedButton(
                        onPressed: messagesState.selectedMessageIds.isEmpty || messagesState.isLoading
                            ? null
                            : () => _processSelectedMessages(context, messagesNotifier, messagesState),
                        child: messagesState.isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Process Selected'),
                      ),
                      
                      const SizedBox(width: 12),
                      
                      // Delete Selected Button
                      ElevatedButton.icon(
                        onPressed: messagesState.selectedMessageIds.isEmpty || messagesState.isLoading
                            ? null
                            : () => _showBulkDeleteConfirmation(context, messagesNotifier, messagesState),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Delete Selected'),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                          backgroundColor: Colors.red.shade50,
                        ),
                      ),
                      ],
                      ),
                    ),
                  ),
                ),
                
                // Pagination Controls (Top)
                const PaginationControls(),
                
                // Messages List
                Expanded(
                  child: messagesState.isLoading && messagesState.messages.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : messagesState.messages.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.message_outlined,
                                    size: 64,
                                    color: Theme.of(context).colorScheme.outline,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No messages yet',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.outline,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    messagesState.whatsappRunning
                                        ? 'Waiting for WhatsApp messages...'
                                        : 'Start WhatsApp to begin receiving messages',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.outline,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Builder(
                              builder: (context) {
                                // Filter messages based on processed status
                                final filteredMessages = showProcessedMessages 
                                    ? messagesState.messages 
                                    : messagesState.messages.where((m) => !m.processed).toList();
                                
                                if (filteredMessages.isEmpty && !showProcessedMessages) {
                                  return Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.check_circle_outline,
                                          size: 64,
                                          color: Theme.of(context).colorScheme.outline,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'No unprocessed messages',
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            color: Theme.of(context).colorScheme.outline,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'All messages have been processed into orders.\nToggle "Show Processed" to see all messages.',
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: Theme.of(context).colorScheme.outline,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                
                                return ListView.builder(
                                  key: const ValueKey('messages_list'),
                                  padding: const EdgeInsets.all(16),
                                  itemCount: filteredMessages.length,
                                  itemBuilder: (context, index) {
                                    final message = filteredMessages[index];
                                    return MessageCard(
                                      key: ValueKey('message_${message.id}'),
                                      message: message,
                                      isSelected: messagesState.selectedMessageIds.contains(message.id),
                                      onToggleSelection: () => messagesNotifier.toggleMessageSelection(message.id),
                                      onEdit: () => setState(() {
                                        selectedMessageForEditing = message;
                                      }),
                                      onDelete: () => messagesNotifier.deleteMessage(message.id),
                                      onCompanyChanged: (messageId, companyName) {
                                        messagesNotifier.updateMessageCompany(messageId, companyName);
                                      },
                                    );
                                  },
                                );
                              },
                            ),
                ),
                
                // Pagination Controls (Bottom)
                const PaginationControls(),
              ],
            ),
          ),
          
          // Vertical Divider
          VerticalDivider(
            width: 1,
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
          
          // Message Editor (Right Panel)
          Expanded(
            flex: 1,
            child: selectedMessageForEditing != null
                ? MessageEditor(
                    message: selectedMessageForEditing!,
                    onSave: (editedContent, processed) async {
                      await messagesNotifier.editMessage(
                        selectedMessageForEditing!.id,
                        editedContent,
                        processed: processed,
                      );
                      setState(() {
                        selectedMessageForEditing = null;
                      });
                    },
                    onTypeChange: (newType) async {
                      try {
                        // Show loading state
                        setState(() {
                          // Keep editor open but show it's updating
                        });
                        
                        // Update backend first
                        await messagesNotifier.updateMessageType(
                          selectedMessageForEditing!.id,
                          newType,
                        );
                        
                        // Update the local reference to reflect the change
                        setState(() {
                          selectedMessageForEditing = selectedMessageForEditing!.copyWith(type: newType);
                        });
                        
                        // Refresh the messages list to show the updated type
                        await messagesNotifier.loadMessages(
              page: ref.read(messagesProvider).currentPage, 
              pageSize: ref.read(messagesProvider).pageSize
            );
                        
                        // Show success feedback
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Message type updated to ${newType.displayName}'),
                              backgroundColor: Colors.green,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      } catch (e) {
                        // Show error feedback
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to update message type: $e'),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      }
                    },
                    onCancel: () => setState(() {
                      selectedMessageForEditing = null;
                    }),
                  )
                : Container(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          size: 64,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Select a message to edit',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Click the edit button on any message to clean up the text and remove unwanted content.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
      
      // Error Snackbar
      bottomSheet: messagesState.error != null
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).colorScheme.errorContainer,
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      messagesState.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: messagesNotifier.clearError,
                    icon: Icon(
                      Icons.close,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  void _showBulkDeleteConfirmation(BuildContext context, messagesNotifier, messagesState) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Selected Messages'),
          content: Text(
            'Are you sure you want to delete ${messagesState.selectedMessageIds.length} selected messages?'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                messagesNotifier.deleteSelectedMessages();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
