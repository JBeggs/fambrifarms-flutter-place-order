import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/dashboard_stock_kpi_provider.dart';
import '../../../core/professional_theme.dart';

class PredictiveStockAnalytics extends ConsumerWidget {
  const PredictiveStockAnalytics({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpiData = ref.watch(dashboardStockKPIProvider);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 20),
          
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              _buildStockoutPredictions(context, kpiData),
              _buildDemandForecasting(context, kpiData),
              _buildSeasonalTrends(context, kpiData),
              _buildReorderRecommendations(context, kpiData),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.accentBlue.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.trending_up,
            color: AppColors.accentBlue,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Predictive Stock Analytics',
                style: AppTextStyles.titleLarge.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                'AI-powered forecasting and recommendations',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.accentBlue.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.accentBlue),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_awesome,
                color: AppColors.accentBlue,
                size: 12,
              ),
              const SizedBox(width: 4),
              Text(
                'AI',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.accentBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStockoutPredictions(BuildContext context, Map<String, dynamic> kpiData) {
    final stockoutFreq = kpiData['stockoutFrequency'] as double;
    final criticalItems = kpiData['criticalStockItems'] as int;
    
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
                Icons.warning_amber,
                color: AppColors.accentRed,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Stockout Predictions',
                  style: AppTextStyles.titleSmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Text(
            'Risk Level: ${_getRiskLevel(stockoutFreq)}',
            style: AppTextStyles.bodyMedium.copyWith(
              color: _getRiskColor(stockoutFreq),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          
          Text(
            '$criticalItems items at risk',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          
          LinearProgressIndicator(
            value: (stockoutFreq / 100).clamp(0, 1),
            backgroundColor: AppColors.borderColor,
            valueColor: AlwaysStoppedAnimation(_getRiskColor(stockoutFreq)),
          ),
          const SizedBox(height: 8),
          
          Text(
            'Next 7 days forecast',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDemandForecasting(BuildContext context, Map<String, dynamic> kpiData) {
    final forecastAccuracy = kpiData['demandForecastAccuracy'] as double;
    final stockMovementTrend = kpiData['stockMovementTrend'] as String;
    
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
                Icons.analytics,
                color: AppColors.accentBlue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Demand Forecasting',
                  style: AppTextStyles.titleSmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Text(
            'Accuracy: ${forecastAccuracy.toStringAsFixed(1)}%',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          
          Row(
            children: [
              Icon(
                _getTrendIcon(stockMovementTrend),
                color: _getTrendColor(stockMovementTrend),
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                'Trend: ${_formatTrend(stockMovementTrend)}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: _getTrendColor(stockMovementTrend),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accentBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'ML model confidence: High',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.accentBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeasonalTrends(BuildContext context, Map<String, dynamic> kpiData) {
    final averageDays = kpiData['averageDaysOfStock'] as double;
    
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
                Icons.calendar_today,
                color: AppColors.accentOrange,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Seasonal Trends',
                  style: AppTextStyles.titleSmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Text(
            'Current Season: Summer',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          
          Text(
            'Avg. stock duration: ${averageDays.toStringAsFixed(0)} days',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          
          Wrap(
            spacing: 4,
            children: [
              _buildSeasonChip('High demand', AppColors.accentRed),
              _buildSeasonChip('Fresh produce', AppColors.accentGreen),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReorderRecommendations(BuildContext context, Map<String, dynamic> kpiData) {
    final topProducts = kpiData['topPerformingProducts'] as List<dynamic>;
    // final underProducts = kpiData['underperformingProducts'] as List<dynamic>; // Not used in this widget
    
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
                Icons.shopping_cart,
                color: AppColors.accentGreen,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Smart Reorders',
                  style: AppTextStyles.titleSmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Text(
            'Priority Items:',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          
          if (topProducts.isNotEmpty) ...[
            ...topProducts.take(2).map((product) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• ${product['name']}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            )),
          ] else ...[
            Text(
              'No urgent reorders needed',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.accentGreen,
              ),
            ),
          ],
          
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              // TODO: Navigate to procurement page
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
            child: Text(
              'View All',
              style: AppTextStyles.labelSmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeasonChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: color,
          fontSize: 10,
        ),
      ),
    );
  }

  String _getRiskLevel(double stockoutFreq) {
    if (stockoutFreq < 5) return 'Low';
    if (stockoutFreq < 15) return 'Medium';
    return 'High';
  }

  Color _getRiskColor(double stockoutFreq) {
    if (stockoutFreq < 5) return AppColors.accentGreen;
    if (stockoutFreq < 15) return AppColors.accentOrange;
    return AppColors.accentRed;
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

  Color _getTrendColor(String trend) {
    switch (trend.toLowerCase()) {
      case 'increasing':
        return AppColors.accentGreen;
      case 'decreasing':
        return AppColors.accentRed;
      case 'stable':
        return AppColors.accentBlue;
      default:
        return AppColors.textMuted;
    }
  }

  String _formatTrend(String trend) {
    switch (trend.toLowerCase()) {
      case 'increasing':
        return 'Growing';
      case 'decreasing':
        return 'Declining';
      case 'stable':
        return 'Stable';
      default:
        return 'Unknown';
    }
  }
}
