import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/dashboard_provider.dart';

class QuickActionsGrid extends StatelessWidget {
  final List<QuickAction> actions;

  const QuickActionsGrid({
    super.key,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Icon(
              Icons.dashboard,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Actions grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
          ),
          itemCount: actions.length,
          itemBuilder: (context, index) {
            final action = actions[index];
            return _buildActionCard(context, action);
          },
        ),
      ],
    );
  }

  Widget _buildActionCard(BuildContext context, QuickAction action) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => context.go(action.route),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with icon and badge
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getActionColor(action.icon).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getActionIcon(action.icon),
                      color: _getActionColor(action.icon),
                      size: 24,
                    ),
                  ),
                  
                  const Spacer(),
                  
                  if (action.badgeCount != null && action.badgeCount! > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${action.badgeCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Title
              Text(
                action.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: 4),
              
              // Subtitle
              Text(
                action.subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              const Spacer(),
              
              // Action indicator
              Row(
                children: [
                  Text(
                    'Open',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _getActionColor(action.icon),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward,
                    size: 16,
                    color: _getActionColor(action.icon),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getActionIcon(String iconName) {
    switch (iconName) {
      case 'people':
        return Icons.people;
      case 'inventory':
        return Icons.inventory;
      case 'business':
        return Icons.business;
      case 'message':
        return Icons.message;
      case 'analytics':
        return Icons.analytics;
      case 'settings':
        return Icons.settings;
      default:
        return Icons.dashboard;
    }
  }

  Color _getActionColor(String iconName) {
    switch (iconName) {
      case 'people':
        return const Color(0xFF2D5016); // Farm green
      case 'inventory':
        return Colors.blue;
      case 'business':
        return Colors.purple;
      case 'message':
        return Colors.green;
      case 'analytics':
        return Colors.orange;
      case 'settings':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }
}

