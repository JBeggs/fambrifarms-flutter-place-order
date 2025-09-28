import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/whatsapp_message.dart';
import '../../utils/messages_provider.dart';
import 'widgets/message_card.dart';
import 'widgets/message_editor.dart';

class MessagesPage extends ConsumerStatefulWidget {
  const MessagesPage({super.key});

  @override
  ConsumerState<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends ConsumerState<MessagesPage> {
  WhatsAppMessage? selectedMessageForEditing;
  bool showProcessedMessages = true;

  @override
  void initState() {
    super.initState();
    // Load messages when page opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(messagesProvider.notifier).loadMessages();
    });
  }

  Future<void> _createOrdersFromSelected(BuildContext context, messagesNotifier) async {
    try {
      final selectedCount = ref.read(messagesProvider).selectedMessageIds.length;
      final selectedMessages = ref.read(messagesProvider).messages.where(
        (msg) => ref.read(messagesProvider).selectedMessageIds.contains(msg.id)
      ).toList();
      
      final orderCount = selectedMessages.where((m) => m.type == MessageType.order).length;
      final stockCount = selectedMessages.where((m) => m.type == MessageType.stock).length;
      
      String contentText = 'Process $selectedCount selected messages?\n\n';
      if (orderCount > 0) {
        contentText += '• $orderCount order messages → Create orders\n';
      }
      if (stockCount > 0) {
        contentText += '• $stockCount stock messages → Update inventory\n';
      }
      
      // Show confirmation dialog
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
          // Show success message
          String successMessage = 'Messages processed successfully!';
          if (orderCount > 0) {
            successMessage += ' Check Orders page for new orders.';
          }
          if (stockCount > 0) {
            successMessage += ' Inventory levels updated.';
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(successMessage),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
            ),
          );
          
          // Navigate to orders page if orders were created
          if (orderCount > 0) {
            context.go('/orders');
          }
        }
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
                                ? '${messagesState.messages.length} total messages'
                                : '${messagesState.messages.where((m) => !m.processed).length} unprocessed messages',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(width: 12),
                      
                      // Selection Controls
                      TextButton(
                        onPressed: messagesState.messages.isEmpty ? null : messagesNotifier.selectAllMessages,
                        child: const Text('Select All'),
                      ),
                      
                      const SizedBox(width: 12),
                      
                      // Process Button
                      ElevatedButton(
                        onPressed: messagesState.selectedMessageIds.isEmpty || messagesState.isLoading
                            ? null
                            : messagesNotifier.processSelectedMessages,
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
                        await messagesNotifier.loadMessages();
                        
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
