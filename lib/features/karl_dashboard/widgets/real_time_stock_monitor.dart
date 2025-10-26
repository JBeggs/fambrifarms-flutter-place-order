import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/dashboard_stock_kpi_provider.dart';
import '../../../core/professional_theme.dart';

class RealTimeStockMonitor extends ConsumerWidget {
  const RealTimeStockMonitor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stockMonitorData = ref.watch(realTimeStockMonitorProvider);
    
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
              _buildLiveStockLevels(context, stockMonitorData['liveStockLevels']),
              _buildStockMovements(context, stockMonitorData['stockMovements']),
              _buildCriticalAlerts(context, stockMonitorData['criticalAlerts']),
              _buildStockVelocity(context, stockMonitorData['stockVelocityMetrics']),
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
            color: AppColors.primaryGreen.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.monitor_heart,
            color: AppColors.primaryGreen,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Real-Time Stock Monitor',
                style: AppTextStyles.titleLarge.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                'Live inventory tracking and alerts',
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
            color: AppColors.accentGreen.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.accentGreen),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: AppColors.accentGreen,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'LIVE',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.accentGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLiveStockLevels(BuildContext context, List<dynamic> stockLevels) {
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
                Icons.inventory_2,
                color: AppColors.accentBlue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Live Stock Levels',
                  style: AppTextStyles.titleSmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          Expanded(
            child: stockLevels.isEmpty
                ? Center(
                    child: Text(
                      'No stock data',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: (stockLevels.length).clamp(0, 4),
                    itemBuilder: (context, index) {
                      final stock = stockLevels[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _buildStockLevelItem(stock),
                      );
                    },
                  ),
          ),
          
          if (stockLevels.length > 4)
            TextButton(
              onPressed: () => _showAllStockLevels(context, stockLevels),
              child: Text(
                'View all ${stockLevels.length} items',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.accentBlue,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStockLevelItem(Map<String, dynamic> stock) {
    final percentage = (stock['percentage'] as double).clamp(0, 200);
    final status = stock['status'] as String;
    final color = _getStatusColor(status);
    
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stock['name'],
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${stock['currentStock']}/${stock['minimumStock']}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            children: [
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: (percentage / 200).clamp(0, 1),
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${percentage.toStringAsFixed(0)}%',
                style: AppTextStyles.bodySmall.copyWith(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStockMovements(BuildContext context, Map<String, dynamic> movements) {
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
                Icons.swap_vert,
                color: AppColors.accentOrange,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Stock Movements',
                  style: AppTextStyles.titleSmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Expanded(
            child: Column(
              children: [
                _buildMovementItem(
                  'Inbound',
                  movements['inbound'].toString(),
                  Icons.arrow_downward,
                  AppColors.accentGreen,
                ),
                const SizedBox(height: 12),
                _buildMovementItem(
                  'Outbound',
                  movements['outbound'].toString(),
                  Icons.arrow_upward,
                  AppColors.accentRed,
                ),
                const SizedBox(height: 12),
                _buildMovementItem(
                  'Adjustments',
                  movements['adjustments'].toString(),
                  Icons.tune,
                  AppColors.accentBlue,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMovementItem(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: color, size: 14),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: AppTextStyles.titleSmall.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildCriticalAlerts(BuildContext context, List<dynamic> alerts) {
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
                Icons.warning,
                color: AppColors.accentRed,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Critical Alerts',
                  style: AppTextStyles.titleSmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: alerts.isEmpty ? AppColors.accentGreen : AppColors.accentRed,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  alerts.length.toString(),
                  style: AppTextStyles.labelSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Expanded(
            child: alerts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: AppColors.accentGreen,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No alerts',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.accentGreen,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: (alerts.length).clamp(0, 3),
                    itemBuilder: (context, index) {
                      final alert = alerts[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _buildAlertItem(alert),
                      );
                    },
                  ),
          ),
          
          if (alerts.length > 3)
            TextButton(
              onPressed: () => _showAllAlerts(context, alerts),
              child: Text(
                'View all ${alerts.length} alerts',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.accentRed,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAlertItem(Map<String, dynamic> alert) {
    final alertLevel = alert['alertLevel'] as String;
    final color = alertLevel == 'critical' ? AppColors.accentRed : AppColors.accentOrange;
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            alert['name'],
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            alert['message'],
            style: AppTextStyles.bodySmall.copyWith(
              color: color,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockVelocity(BuildContext context, Map<String, dynamic> velocity) {
    final total = velocity['total'] as double;
    final fastMoving = velocity['fastMoving'] as double;
    final slowMoving = velocity['slowMoving'] as double;
    final normal = velocity['normal'] as double;
    
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
                Icons.speed,
                color: AppColors.primaryGreen,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Stock Velocity',
                  style: AppTextStyles.titleSmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Expanded(
            child: Column(
              children: [
                _buildVelocityItem(
                  'Fast Moving',
                  fastMoving,
                  total,
                  AppColors.accentGreen,
                ),
                const SizedBox(height: 8),
                _buildVelocityItem(
                  'Normal',
                  normal,
                  total,
                  AppColors.accentBlue,
                ),
                const SizedBox(height: 8),
                _buildVelocityItem(
                  'Slow Moving',
                  slowMoving,
                  total,
                  AppColors.accentOrange,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVelocityItem(String label, double value, double total, Color color) {
    final percentage = total > 0 ? (value / total) * 100 : 0.0;
    
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Text(
              '${value.toInt()}',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.borderColor,
            borderRadius: BorderRadius.circular(2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: (percentage / 100).clamp(0, 1),
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'excellent':
        return AppColors.accentGreen;
      case 'good':
        return AppColors.primaryGreen;
      case 'low':
        return AppColors.accentOrange;
      case 'critical':
        return AppColors.accentRed;
      case 'out_of_stock':
        return AppColors.accentRed;
      default:
        return AppColors.textSecondary;
    }
  }

  void _showAllStockLevels(BuildContext context, List<dynamic> stockLevels) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('All Stock Levels'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: stockLevels.length,
            itemBuilder: (context, index) {
              final stock = stockLevels[index];
              return ListTile(
                title: Text(stock['name']),
                subtitle: Text('${stock['currentStock']}/${stock['minimumStock']}'),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(stock['status']).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    stock['status'].toString().replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                      color: _getStatusColor(stock['status']),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
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

  void _showAllAlerts(BuildContext context, List<dynamic> alerts) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('All Critical Alerts'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: alerts.length,
            itemBuilder: (context, index) {
              final alert = alerts[index];
              final alertLevel = alert['alertLevel'] as String;
              final color = alertLevel == 'critical' ? AppColors.accentRed : AppColors.accentOrange;
              
              return ListTile(
                leading: Icon(
                  alertLevel == 'critical' ? Icons.error : Icons.warning,
                  color: color,
                ),
                title: Text(alert['name']),
                subtitle: Text(alert['message']),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    alertLevel.toUpperCase(),
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
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
