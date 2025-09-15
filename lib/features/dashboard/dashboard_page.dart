import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/messages_provider.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesState = ref.watch(messagesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Alerts Section
            _buildAlertsSection(context, messagesState),
            
            const SizedBox(height: 24),
            // Stats Cards
            Row(
              children: [
                Expanded(
                  child: _StatsCard(
                    title: 'Total Messages',
                    value: '${messagesState.messages.length}',
                    icon: Icons.message,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _StatsCard(
                    title: 'Orders',
                    value: '${messagesState.messages.where((m) => m.type.name == 'order').length}',
                    icon: Icons.shopping_cart,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _StatsCard(
                    title: 'Stock Updates',
                    value: '${messagesState.messages.where((m) => m.type.name == 'stock_update').length}',
                    icon: Icons.inventory,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _StatsCard(
                    title: 'WhatsApp Status',
                    value: messagesState.whatsappRunning ? 'Connected' : 'Disconnected',
                    icon: messagesState.whatsappRunning ? Icons.check_circle : Icons.error,
                    color: messagesState.whatsappRunning ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // Quick Actions
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: Card(
                    child: InkWell(
                      onTap: () => context.go('/messages'),
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Icon(Icons.message, size: 48, color: Colors.blue),
                            SizedBox(height: 12),
                            Text(
                              'Process Messages',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Edit and process WhatsApp messages',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(width: 16),
                
                Expanded(
                  child: Card(
                    child: InkWell(
                      onTap: () => context.go('/pricing'),
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Icon(Icons.trending_up, size: 48, color: Color(0xFF6366F1)),
                            SizedBox(height: 12),
                            Text(
                              'Dynamic Pricing',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'AI-powered market volatility management',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(width: 16),
                
                Expanded(
                  child: Card(
                    child: InkWell(
                      onTap: () {
                        // TODO: Navigate to customers
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Icon(Icons.people, size: 48, color: Colors.green),
                            SizedBox(height: 12),
                            Text(
                              'Customers',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Manage customer database',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // Recent Activity
            Text(
              'Recent Activity',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 16),
            
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: messagesState.messages.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inbox, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'No recent activity',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Start WhatsApp to begin receiving messages',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: messagesState.messages.take(5).length,
                          itemBuilder: (context, index) {
                            final message = messagesState.messages[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _getTypeColor(message.type.name).withValues(alpha: 0.2),
                                child: Text(
                                  message.type.icon,
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                              title: Text(message.sender),
                              subtitle: Text(
                                message.content.length > 50
                                    ? '${message.content.substring(0, 50)}...'
                                    : message.content,
                              ),
                              trailing: Text(
                                message.timestamp,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            );
                          },
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertsSection(BuildContext context, messagesState) {
    List<Widget> alerts = [];
    
    // Check for WhatsApp connection issues
    if (!messagesState.whatsappRunning) {
      alerts.add(_buildAlert(
        context,
        'WhatsApp Disconnected',
        'WhatsApp scraper is not running. Start it to receive new messages.',
        Icons.warning,
        Colors.orange,
        () => context.go('/messages'),
      ));
    }
    
    // Check for unprocessed messages
    final unprocessedCount = messagesState.messages.where((m) => !m.processed).length;
    if (unprocessedCount > 0) {
      alerts.add(_buildAlert(
        context,
        'Unprocessed Messages',
        '$unprocessedCount messages need to be processed into orders.',
        Icons.notification_important,
        Colors.blue,
        () => context.go('/messages'),
      ));
    }
    
    // Check for failed orders (processed messages with no orders)
    final failedOrderCount = messagesState.messages.where((m) => 
      m.processed && m.type.name == 'order' && (m.orderDetails == null)).length;
    if (failedOrderCount > 0) {
      alerts.add(_buildAlert(
        context,
        'Failed Order Creation',
        '$failedOrderCount messages were processed but no orders were created. Check for product issues.',
        Icons.error,
        Colors.red,
        () => context.go('/messages'),
      ));
    }
    
    if (alerts.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Alerts',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...alerts,
      ],
    );
  }
  
  Widget _buildAlert(BuildContext context, String title, String message, 
                    IconData icon, Color color, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Card(
        color: color.withValues(alpha: 0.1),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, color: color, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'order':
        return Colors.green;
      case 'stock_update':
        return Colors.blue;
      case 'greeting':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}

class _StatsCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatsCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const Spacer(),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
