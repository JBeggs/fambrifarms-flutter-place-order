import 'package:flutter/material.dart';
import '../../../models/customer.dart';

class CustomerCard extends StatelessWidget {
  final Customer customer;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onViewOrders;

  const CustomerCard({
    super.key,
    required this.customer,
    this.onTap,
    this.onEdit,
    this.onViewOrders,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  // Customer avatar
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: _getCustomerTypeColor(customer.customerType),
                    child: Text(
                      customer.initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // Customer info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name and business name
                        Text(
                          customer.profile?.businessName ?? customer.displayName,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        
                        if (customer.profile?.businessName != null && 
                            customer.profile!.businessName != customer.displayName)
                          Text(
                            customer.displayName,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        
                        const SizedBox(height: 4),
                        
                        // Customer type and status
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getCustomerTypeColor(customer.customerType)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                customer.customerTypeDisplay,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _getCustomerTypeColor(customer.customerType),
                                ),
                              ),
                            ),
                            
                            const SizedBox(width: 8),
                            
                            // Status indicator
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: customer.isActive ? Colors.green : Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                            
                            const SizedBox(width: 4),
                            
                            Text(
                              customer.statusDisplay,
                              style: TextStyle(
                                fontSize: 12,
                                color: customer.isActive ? Colors.green : Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Action buttons
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          onEdit?.call();
                          break;
                        case 'orders':
                          onViewOrders?.call();
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Text('Edit Customer'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'orders',
                        child: Row(
                          children: [
                            Icon(Icons.shopping_cart, size: 18),
                            SizedBox(width: 8),
                            Text('View Orders'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Contact information
              Row(
                children: [
                  Expanded(
                    child: _buildInfoItem(
                      context,
                      Icons.email_outlined,
                      'Email',
                      customer.email,
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  Expanded(
                    child: _buildInfoItem(
                      context,
                      Icons.phone_outlined,
                      'Phone',
                      customer.phone.isNotEmpty ? customer.phone : 'Not provided',
                    ),
                  ),
                ],
              ),
              
              // Profile-specific information
              if (customer.profile != null) ...[
                const SizedBox(height: 12),
                _buildProfileInfo(context, customer.profile!),
              ],
              
              const SizedBox(height: 16),
              
              // Order statistics
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      context,
                      'Total Orders',
                      customer.totalOrders.toString(),
                      Icons.shopping_cart_outlined,
                    ),
                  ),
                  
                  Expanded(
                    child: _buildStatItem(
                      context,
                      'Order Value',
                      'R${customer.totalOrderValue.toStringAsFixed(0)}',
                      Icons.attach_money,
                    ),
                  ),
                  
                  Expanded(
                    child: _buildStatItem(
                      context,
                      'Frequency',
                      customer.orderFrequency,
                      Icons.trending_up,
                    ),
                  ),
                  
                  if (customer.lastOrderDate != null)
                    Expanded(
                      child: _buildStatItem(
                        context,
                        'Last Order',
                        _formatLastOrderDate(customer.lastOrderDate!),
                        Icons.schedule,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(BuildContext context, IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                  fontSize: 11,
                ),
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileInfo(BuildContext context, CustomerProfile profile) {
    final info = <String>[];
    
    if (profile.cuisineType != null) {
      info.add(profile.cuisineType!);
    }
    
    if (profile.seatingCapacity != null) {
      info.add('${profile.seatingCapacity} seats');
    }
    
    if (profile.deliveryInfo.isNotEmpty) {
      info.add(profile.deliveryInfo);
    }
    
    if (info.isEmpty) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              info.join(' • '),
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
            fontSize: 10,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Color _getCustomerTypeColor(String type) {
    switch (type) {
      case 'restaurant':
        return const Color(0xFF2D5016); // Farm green
      case 'private':
        return const Color(0xFF6366F1); // Indigo
      case 'internal':
        return const Color(0xFFE67E22); // Orange
      default:
        return Colors.grey;
    }
  }

  String _formatLastOrderDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}w ago';
    } else {
      return '${(difference.inDays / 30).floor()}m ago';
    }
  }
}

