import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/product.dart';
import '../../../providers/product_stock_provider.dart';
import '../../../core/professional_theme.dart';

class ProductStockAnalytics extends ConsumerWidget {
  final Product product;

  const ProductStockAnalytics({
    super.key,
    required this.product,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.watch(productStockProvider).stockAnalytics[product.id];
    final healthScore = ref.watch(productStockProvider).stockHealthScores[product.id];

    if (analytics == null || healthScore == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Icon(Icons.analytics_outlined, size: 48, color: Colors.grey),
              const SizedBox(height: 8),
              Text(
                'Stock Analytics',
                style: AppTextStyles.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Loading analytics...',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: AppDecorations.professionalCard,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, healthScore),
            const SizedBox(height: 16),
            _buildStockHealthScore(context, healthScore),
            const SizedBox(height: 16),
            _buildKeyMetrics(context, analytics),
            const SizedBox(height: 16),
            _buildReorderRecommendations(context, analytics),
            const SizedBox(height: 16),
            _buildStockTrend(context, analytics),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, double healthScore) {
    return Row(
      children: [
        Icon(
          Icons.analytics,
          color: AppColors.primaryGreen,
          size: 24,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Stock Analytics',
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _getHealthScoreColor(healthScore).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _getHealthScoreColor(healthScore),
              width: 1,
            ),
          ),
          child: Text(
            '${healthScore.toStringAsFixed(0)}%',
            style: AppTextStyles.labelMedium.copyWith(
              color: _getHealthScoreColor(healthScore),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStockHealthScore(BuildContext context, double healthScore) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getHealthScoreIcon(healthScore),
                color: _getHealthScoreColor(healthScore),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Stock Health Score',
                style: AppTextStyles.titleSmall.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Health score progress bar
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: AppColors.borderColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: healthScore / 100,
              child: Container(
                decoration: BoxDecoration(
                  color: _getHealthScoreColor(healthScore),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          
          Text(
            _getHealthScoreDescription(healthScore),
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyMetrics(BuildContext context, Map<String, dynamic> analytics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Key Metrics',
          style: AppTextStyles.titleSmall.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 2.5,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _buildMetricCard(
              'Stock Value',
              'R${(analytics['stockValue'] as double).toStringAsFixed(2)}',
              Icons.attach_money,
              AppColors.accentGreen,
            ),
            _buildMetricCard(
              'Days of Stock',
              '${(analytics['daysOfStock'] as double).toStringAsFixed(0)} days',
              Icons.calendar_today,
              AppColors.accentBlue,
            ),
            _buildMetricCard(
              'Order Frequency',
              '${analytics['orderFrequency']} orders',
              Icons.shopping_cart,
              AppColors.accentOrange,
            ),
            _buildMetricCard(
              'Turnover Rate',
              '${(analytics['stockTurnoverRate'] as double).toStringAsFixed(2)}x',
              Icons.refresh,
              AppColors.primaryGreen,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Text(
            value,
            style: AppTextStyles.titleSmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReorderRecommendations(BuildContext context, Map<String, dynamic> analytics) {
    final shouldReorder = analytics['shouldReorder'] as bool;
    final recommendedQuantity = analytics['recommendedOrderQuantity'] as double;
    final stockStatus = analytics['stockStatus'] as String;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: shouldReorder ? AppColors.accentRed.withValues(alpha: 0.1) : AppColors.accentGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: shouldReorder ? AppColors.accentRed : AppColors.accentGreen,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                shouldReorder ? Icons.warning : Icons.check_circle,
                color: shouldReorder ? AppColors.accentRed : AppColors.accentGreen,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Reorder Recommendations',
                style: AppTextStyles.titleSmall.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status: $stockStatus',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      shouldReorder 
                          ? 'Recommended order: ${recommendedQuantity.toStringAsFixed(0)} ${product.unit}'
                          : 'Stock levels are adequate',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (shouldReorder)
                ElevatedButton.icon(
                  onPressed: () => _showReorderDialog(context, recommendedQuantity),
                  icon: const Icon(Icons.add_shopping_cart, size: 16),
                  label: const Text('Reorder'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: AppColors.textPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStockTrend(BuildContext context, Map<String, dynamic> analytics) {
    final demandTrend = analytics['demandTrend'] as String;
    final lastOrderDate = analytics['lastOrderDate'] as String?;
    final totalRevenue = analytics['totalRevenue'] as double;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.trending_up,
                color: AppColors.accentBlue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Demand Analysis',
                style: AppTextStyles.titleSmall.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTrendItem('Demand Trend', demandTrend, _getTrendIcon(demandTrend)),
                    const SizedBox(height: 8),
                    _buildTrendItem('Total Revenue', 'R${totalRevenue.toStringAsFixed(2)}', Icons.monetization_on),
                    const SizedBox(height: 8),
                    _buildTrendItem(
                      'Last Order', 
                      lastOrderDate ?? 'No orders yet', 
                      Icons.schedule,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrendItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Color _getHealthScoreColor(double score) {
    if (score >= 80) return AppColors.accentGreen;
    if (score >= 60) return AppColors.accentOrange;
    return AppColors.accentRed;
  }

  IconData _getHealthScoreIcon(double score) {
    if (score >= 80) return Icons.check_circle;
    if (score >= 60) return Icons.warning;
    return Icons.error;
  }

  String _getHealthScoreDescription(double score) {
    if (score >= 90) return 'Excellent stock health with optimal levels and consistent demand';
    if (score >= 80) return 'Good stock health with adequate levels and stable demand';
    if (score >= 70) return 'Fair stock health with some areas for improvement';
    if (score >= 60) return 'Poor stock health requiring attention and optimization';
    return 'Critical stock health needing immediate action';
  }

  IconData _getTrendIcon(String trend) {
    switch (trend.toLowerCase()) {
      case 'increasing':
        return Icons.trending_up;
      case 'decreasing':
        return Icons.trending_down;
      case 'stable':
        return Icons.trending_flat;
      default:
        return Icons.help_outline;
    }
  }

  void _showReorderDialog(BuildContext context, double recommendedQuantity) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reorder ${product.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current stock: ${product.stockLevel} ${product.unit}'),
            Text('Minimum stock: ${product.minimumStock} ${product.unit}'),
            const SizedBox(height: 16),
            Text('Recommended order quantity: ${recommendedQuantity.toStringAsFixed(0)} ${product.unit}'),
            const SizedBox(height: 8),
            Text('Estimated cost: R${(recommendedQuantity * product.price).toStringAsFixed(2)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Implement actual reorder functionality
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Reorder request created for ${product.name}'),
                  backgroundColor: AppColors.accentGreen,
                ),
              );
            },
            child: const Text('Create Reorder'),
          ),
        ],
      ),
    );
  }
}
