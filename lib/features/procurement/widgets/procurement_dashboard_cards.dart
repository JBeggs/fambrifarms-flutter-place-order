// Procurement Dashboard Cards - Overview metrics for Karl's procurement system
// Shows key metrics and insights at a glance

import 'package:flutter/material.dart';
import '../../../models/procurement_models.dart';

class ProcurementDashboardCards extends StatelessWidget {
  final int totalRecommendations;
  final int pendingCount;
  final int approvedCount;
  final double totalEstimatedSpending;
  final int criticalItems;
  final ProcurementDashboardData? dashboardData;

  const ProcurementDashboardCards({
    super.key,
    required this.totalRecommendations,
    required this.pendingCount,
    required this.approvedCount,
    required this.totalEstimatedSpending,
    required this.criticalItems,
    this.dashboardData,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Recommendations Overview
        Expanded(
          child: _buildMetricCard(
            context,
            icon: Icons.auto_awesome,
            title: 'Smart Recommendations',
            value: totalRecommendations.toString(),
            subtitle: '$pendingCount pending • $approvedCount approved',
            color: const Color(0xFF2D5016),
            trend: totalRecommendations > 0 ? 'Active' : 'Ready to start',
          ),
        ),
        const SizedBox(width: 16),
        
        // Spending Overview
        Expanded(
          child: _buildMetricCard(
            context,
            icon: Icons.account_balance_wallet,
            title: 'Estimated Spending',
            value: 'R${totalEstimatedSpending.toStringAsFixed(0)}',
            subtitle: 'Approved recommendations',
            color: Colors.blue[700]!,
            trend: approvedCount > 0 ? 'Ready for market' : 'No trips planned',
          ),
        ),
        const SizedBox(width: 16),
        
        // System Health
        Expanded(
          child: _buildMetricCard(
            context,
            icon: Icons.health_and_safety,
            title: 'System Health',
            value: _getHealthScore(),
            subtitle: criticalItems > 0 ? '$criticalItems items need attention' : 'All systems optimal',
            color: criticalItems > 0 ? Colors.orange[700]! : Colors.green[700]!,
            trend: criticalItems > 0 ? 'Needs review' : 'Excellent',
          ),
        ),
        const SizedBox(width: 16),
        
        // Intelligence Insights
        Expanded(
          child: _buildMetricCard(
            context,
            icon: Icons.psychology,
            title: 'AI Intelligence',
            value: dashboardData?.productsWithRecipes.toString() ?? '0',
            subtitle: 'Products with recipes',
            color: Colors.purple[700]!,
            trend: 'Learning patterns',
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required String trend,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with icon and trend
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 20,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    trend,
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Main value
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 4),
            
            // Title
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Subtitle
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  String _getHealthScore() {
    if (criticalItems == 0) return '100%';
    if (criticalItems < 5) return '85%';
    if (criticalItems < 10) return '70%';
    return '60%';
  }
}

