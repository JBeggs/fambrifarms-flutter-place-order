import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/whatsapp_message.dart';
import '../../utils/messages_provider.dart';
import '../../services/api_service.dart';
import 'widgets/customer_dropdown.dart';
import 'widgets/always_suggestions_dialog.dart';
import 'widgets/message_editor.dart';

/// Mobile-optimized WhatsApp messages/orders placement page
/// Allows viewing messages and placing orders on Android
class MobileMessagesPage extends ConsumerStatefulWidget {
  const MobileMessagesPage({super.key});

  @override
  ConsumerState<MobileMessagesPage> createState() => _MobileMessagesPageState();
}

class _MobileMessagesPageState extends ConsumerState<MobileMessagesPage> {
  String _searchQuery = '';
  String _filterType = 'all'; // all, order, stock
  bool _showProcessedOnly = false;
  bool _stockTakeCompleted = false;
  bool _isCheckingStockTake = true;

  @override
  void initState() {
    super.initState();
    // Load messages when page opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(messagesProvider.notifier).loadMessages(page: 1, pageSize: 50);
      _checkStockTakeStatus();
    });
  }

  Future<void> _checkStockTakeStatus() async {
    try {
      setState(() {
        _isCheckingStockTake = true;
      });
      final apiService = ref.read(apiServiceProvider);
      final status = await apiService.checkStockTakeStatus();
      if (mounted) {
        setState(() {
          _stockTakeCompleted = status['completed'] == true;
          _isCheckingStockTake = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking stock take status: $e');
      if (mounted) {
        setState(() {
          _isCheckingStockTake = false;
          // Default to false (not completed) if check fails
          _stockTakeCompleted = false;
        });
      }
    }
  }

  List<WhatsAppMessage> get filteredMessages {
    final messagesState = ref.watch(messagesProvider);
    var messages = messagesState.messages;

    // Filter by type
    if (_filterType != 'all') {
      messages = messages.where((msg) {
        if (_filterType == 'order') return msg.type == MessageType.order;
        if (_filterType == 'stock') return msg.type == MessageType.stock;
        return true;
      }).toList();
    }

    // Filter by processed status
    if (_showProcessedOnly) {
      messages = messages.where((msg) => msg.processed).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      messages = messages.where((msg) {
        final query = _searchQuery.toLowerCase();
        return msg.content.toLowerCase().contains(query) ||
               (msg.companyName?.toLowerCase().contains(query) ?? false) ||
               (msg.sender?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    return messages;
  }

  Future<void> _editMessage(WhatsAppMessage message) async {
    final messagesNotifier = ref.read(messagesProvider.notifier);

    // Use full screen dialog for mobile
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Edit Message'),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          body: SingleChildScrollView(
            child: MessageEditor(
              message: message,
              onSave: (editedContent, processed) async {
                await messagesNotifier.editMessage(
                  message.id,
                  editedContent,
                  processed: processed,
                );
                if (mounted) Navigator.of(context).pop();
              },
              onTypeChange: (newType) async {
                await messagesNotifier.updateMessageType(message.id, newType);
                await messagesNotifier.loadMessages(page: 1, pageSize: 50);
              },
              onCancel: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      ),
    );

    // Refresh messages after edit
    await ref.read(messagesProvider.notifier).loadMessages(page: 1, pageSize: 50);
  }

  Future<void> _processMessage(WhatsAppMessage message) async {
    // Check if customer is selected
    final hasManualCompany = message.manualCompany != null && message.manualCompany!.isNotEmpty && message.manualCompany != 'Clear Selection';
    final hasCompanyName = message.companyName != null && message.companyName!.isNotEmpty && message.companyName != 'Clear Selection';
    final hasCustomer = hasManualCompany || hasCompanyName;

    if (!hasCustomer) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Please select a customer first'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final messageId = message.messageId ?? '';
    if (messageId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Error: Message ID not found'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Show loading
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
      // Process the message with suggestions
      final messagesNotifier = ref.read(messagesProvider.notifier);
      final result = await messagesNotifier.processMessageWithSuggestions(messageId);

      // Close loading
      if (mounted) Navigator.of(context).pop();

      if (result['status'] == 'success') {
        // Show the suggestions dialog as full-screen for mobile
        if (mounted) {
          await Navigator.of(context).push(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (context) => Scaffold(
                appBar: AppBar(
                  title: const Text('Confirm Order Items'),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                body: AlwaysSuggestionsDialog(
                  messageId: messageId,
                  suggestionsData: result,
                ),
              ),
            ),
          );

          // Refresh messages after dialog closes
          await ref.read(messagesProvider.notifier).loadMessages(page: 1, pageSize: 50);
        }
      } else {
        throw Exception(result['message'] ?? 'Unknown error');
      }
    } catch (e) {
      // Close loading if still open
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesState = ref.watch(messagesProvider);
    final filteredList = filteredMessages;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Place Orders',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(messagesProvider.notifier).loadMessages(page: 1, pageSize: 50);
              _checkStockTakeStatus();
            },
            tooltip: 'Refresh Messages',
          ),
        ],
      ),
      body: Column(
        children: [
          // Warning banner if stock take not completed
          if (!_isCheckingStockTake && !_stockTakeCompleted)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.orange,
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '⚠️ Stock take has not been completed for today. Please complete stock take before placing orders.',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Main content
          Expanded(
            child: _buildBody(context, messagesState, filteredList),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, dynamic messagesState, List<WhatsAppMessage> filteredList) {
    final children = <Widget>[
          // Search and Filters
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search messages, customers...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  style: const TextStyle(fontSize: 16),
                ),

                const SizedBox(height: 12),

                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All', 'all'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Orders', 'order'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Stock', 'stock'),
                      const SizedBox(width: 16),
                      FilterChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _showProcessedOnly ? Icons.check_box : Icons.check_box_outline_blank,
                              size: 16,
                              color: _showProcessedOnly ? Colors.white : Colors.green,
                            ),
                            const SizedBox(width: 4),
                            const Text('Processed Only'),
                          ],
                        ),
                        selected: _showProcessedOnly,
                        onSelected: (selected) {
                          setState(() {
                            _showProcessedOnly = selected;
                          });
                        },
                        selectedColor: Colors.green,
                        backgroundColor: Colors.grey[100],
                        labelStyle: TextStyle(
                          color: _showProcessedOnly ? Colors.white : Colors.grey[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Messages List
          Expanded(
        child: _buildMessagesContent(context, messagesState, filteredList),
      ),
    ];

    // Add Summary Footer if needed
    if (filteredList.isNotEmpty) {
      children.add(
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${filteredList.length} messages',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              Text(
                '${filteredList.where((m) => !m.processed).length} unprocessed',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: children,
    );
  }

  Widget _buildMessagesContent(BuildContext context, dynamic messagesState, List<WhatsAppMessage> filteredList) {
    if (messagesState.isLoading && messagesState.messages.isEmpty) {
      return const Center(
                    child: CircularProgressIndicator(),
      );
    }
    
    if (messagesState.error != null) {
      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.red,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Error loading messages',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              messagesState.error!,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () {
                                ref.read(messagesProvider.notifier).loadMessages(page: 1, pageSize: 50);
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
      );
    }
    
    if (filteredList.isEmpty) {
      return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.message_outlined,
                                  size: 64,
                                  color: Colors.grey[300],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No messages found',
                                  style: Theme.of(context).textTheme.headlineSmall,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Try adjusting your filters',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
      );
    }
    
    return RefreshIndicator(
                            onRefresh: () async {
                              await ref.read(messagesProvider.notifier).loadMessages(page: 1, pageSize: 50);
                            },
                            child: ListView.builder(
                              padding: EdgeInsets.only(
                                left: 16,
                                right: 16,
                                top: 16,
                                bottom: filteredList.isNotEmpty ? 100 : 16, // Extra padding for footer and buttons
                              ),
                              itemCount: filteredList.length,
                              itemBuilder: (context, index) {
                                final message = filteredList[index];
                                return _buildMobileMessageCard(message);
                              },
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterType == value;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.green,
          fontWeight: FontWeight.w600,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterType = value;
        });
      },
      selectedColor: Colors.green,
      backgroundColor: Colors.grey[100],
    );
  }

  Widget _buildMobileMessageCard(WhatsAppMessage message) {
    final messagesNotifier = ref.read(messagesProvider.notifier);

    return Card(
      margin: const EdgeInsets.only(bottom: 16), // Increased margin for better spacing
      elevation: message.processed ? 1 : 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                // Type Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: message.type == MessageType.order 
                        ? Colors.blue.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    message.type == MessageType.order ? 'ORDER' : 'STOCK',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: message.type == MessageType.order ? Colors.blue : Colors.orange,
                    ),
                  ),
                ),
                const Spacer(),
                // Processed Badge
                if (message.processed)
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
              ],
            ),

            const SizedBox(height: 12),

            // Customer Dropdown (for order messages)
            if (message.type == MessageType.order) ...[
              CustomerDropdown(
                selectedCompany: message.manualCompany ?? message.companyName,
                onCompanyChanged: (newCompany) {
                  messagesNotifier.updateMessageCompany(message.id, newCompany);
                },
              ),
              const SizedBox(height: 12),
            ],

            // Message Content
            Text(
              message.content,
              style: const TextStyle(fontSize: 14),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 12),

            // Timestamp
            Text(
              message.timestamp,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),

            // Action Buttons Row
            if (!message.processed) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  // Edit Button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _editMessage(message),
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Edit'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  if (message.type == MessageType.order) ...[
                    const SizedBox(width: 8),
                    // Place Order Button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _stockTakeCompleted ? () => _processMessage(message) : null,
                        icon: const Icon(Icons.shopping_cart, size: 16),
                        label: const Text('Place Order'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _stockTakeCompleted ? Colors.green : Colors.grey,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          disabledBackgroundColor: Colors.grey,
                          disabledForegroundColor: Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

