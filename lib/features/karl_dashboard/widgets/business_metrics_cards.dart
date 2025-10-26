import 'package:flutter/material.dart';
import '../../../providers/dashboard_provider.dart';

class BusinessMetricsCards extends StatelessWidget {
  final BusinessMetrics metrics;

  const BusinessMetricsCards({
    super.key,
    required this.metrics,
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
              Icons.analytics,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Business Overview',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getHealthColor(metrics.overallHealthStatus).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _getHealthColor(metrics.overallHealthStatus).withOpacity(0.3),
                ),
              ),
              child: Text(
                metrics.overallHealthStatus,
                style: TextStyle(
                  color: _getHealthColor(metrics.overallHealthStatus),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // First row of metrics
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                context,
                'Customers',
                '${metrics.activeCustomers}/${metrics.totalCustomers}',
                'Active customers',
                Icons.people,
                const Color(0xFF2D5016),
                healthScore: metrics.customerHealthScore,
              ),
            ),
            
            const SizedBox(width: 12),
            
            Expanded(
              child: _buildMetricCard(
                context,
                'Products',
                '${metrics.totalProducts - metrics.outOfStockProducts}/${metrics.totalProducts}',
                'In stock',
                Icons.inventory,
                Colors.blue,
                healthScore: metrics.stockHealthScore,
              ),
            ),
            
            const SizedBox(width: 12),
            
            Expanded(
              child: _buildMetricCard(
                context,
                'Suppliers',
                '${metrics.activeSuppliers}/${metrics.totalSuppliers}',
                'Active suppliers',
                Icons.business,
                Colors.purple,
                healthScore: metrics.supplierHealthScore,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 12),
        
        // Second row of metrics
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                context,
                'Business Value',
                'R${_formatCurrency(metrics.totalBusinessValue)}',
                'Total value',
                Icons.attach_money,
                Colors.green,
              ),
            ),
            
            const SizedBox(width: 12),
            
            Expanded(
              child: _buildMetricCard(
                context,
                'Avg Order',
                'R${_formatCurrency(metrics.averageOrderValue)}',
                'Average order value',
                Icons.trending_up,
                Colors.orange,
              ),
            ),
            
            const SizedBox(width: 12),
            
            Expanded(
              child: _buildMetricCard(
                context,
                'Recent Activity',
                '${metrics.recentOrders}',
                'Recent orders',
                Icons.schedule,
                Colors.teal,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    BuildContext context,
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color, {
    double? healthScore,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon and health indicator
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              
              const Spacer(),
              
              if (healthScore != null)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _getHealthScoreColor(healthScore),
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Value
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          
          const SizedBox(height: 4),
          
          // Title and subtitle
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          
          // Health score bar (if provided)
          if (healthScore != null) ...[
            const SizedBox(height: 8),
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(2),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: healthScore / 100,
                child: Container(
                  decoration: BoxDecoration(
                    color: _getHealthScoreColor(healthScore),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getHealthColor(String status) {
    switch (status) {
      case 'Excellent':
        return Colors.green;
      case 'Good':
        return Colors.blue;
      case 'Fair':
        return Colors.orange;
      case 'Needs Attention':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getHealthScoreColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.blue;
    if (score >= 40) return Colors.orange;
    return Colors.red;
  }

  String _formatCurrency(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    } else {
      return value.toStringAsFixed(0);
    }
  }
}

