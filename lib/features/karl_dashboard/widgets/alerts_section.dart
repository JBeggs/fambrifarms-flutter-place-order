import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/dashboard_provider.dart';

class AlertsSection extends StatelessWidget {
  final List<AlertItem> alerts;

  const AlertsSection({
    super.key,
    required this.alerts,
  });

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green[200]!),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green[600], size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'All Systems Healthy',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                  Text(
                    'No alerts or issues detected',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.green[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Icon(
              Icons.warning_amber,
              color: _getHighestPriorityColor(alerts),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Alerts & Notifications',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getHighestPriorityColor(alerts).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${alerts.length}',
                style: TextStyle(
                  color: _getHighestPriorityColor(alerts),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Alerts list
        ...alerts.take(5).map((alert) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildAlertCard(context, alert),
        )),
        
        // Show more button if there are more alerts
        if (alerts.length > 5)
          Center(
            child: TextButton(
              onPressed: () {
                // TODO: Show all alerts dialog or page
                _showAllAlertsDialog(context, alerts);
              },
              child: Text('View ${alerts.length - 5} more alerts'),
            ),
          ),
      ],
    );
  }

  Widget _buildAlertCard(BuildContext context, AlertItem alert) {
    final color = _getPriorityColor(alert.priority);
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: alert.actionRoute != null 
            ? () => context.go(alert.actionRoute!)
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Alert icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getAlertIcon(alert.type),
                  color: color,
                  size: 20,
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Alert content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            alert.title,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _getPriorityText(alert.priority),
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 4),
                    
                    Text(
                      alert.message,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    
                    const SizedBox(height: 4),
                    
                    Text(
                      _formatTimestamp(alert.timestamp),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[500],
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Action arrow
              if (alert.actionRoute != null)
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey[400],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getPriorityColor(AlertPriority priority) {
    switch (priority) {
      case AlertPriority.critical:
        return Colors.red;
      case AlertPriority.high:
        return Colors.orange;
      case AlertPriority.medium:
        return Colors.blue;
      case AlertPriority.low:
        return Colors.grey;
    }
  }

  Color _getHighestPriorityColor(List<AlertItem> alerts) {
    if (alerts.any((a) => a.priority == AlertPriority.critical)) {
      return Colors.red;
    } else if (alerts.any((a) => a.priority == AlertPriority.high)) {
      return Colors.orange;
    } else if (alerts.any((a) => a.priority == AlertPriority.medium)) {
      return Colors.blue;
    } else {
      return Colors.grey;
    }
  }

  String _getPriorityText(AlertPriority priority) {
    switch (priority) {
      case AlertPriority.critical:
        return 'CRITICAL';
      case AlertPriority.high:
        return 'HIGH';
      case AlertPriority.medium:
        return 'MEDIUM';
      case AlertPriority.low:
        return 'LOW';
    }
  }

  IconData _getAlertIcon(AlertType type) {
    switch (type) {
      case AlertType.stock:
        return Icons.inventory;
      case AlertType.customer:
        return Icons.people;
      case AlertType.supplier:
        return Icons.business;
      case AlertType.order:
        return Icons.shopping_cart;
      case AlertType.system:
        return Icons.settings;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  void _showAllAlertsDialog(BuildContext context, List<AlertItem> alerts) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('All Alerts'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: alerts.length,
            itemBuilder: (context, index) {
              final alert = alerts[index];
              return ListTile(
                leading: Icon(
                  _getAlertIcon(alert.type),
                  color: _getPriorityColor(alert.priority),
                ),
                title: Text(alert.title),
                subtitle: Text(alert.message),
                trailing: Text(_getPriorityText(alert.priority)),
                onTap: alert.actionRoute != null 
                    ? () {
                        Navigator.of(context).pop();
                        context.go(alert.actionRoute!);
                      }
                    : null,
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

