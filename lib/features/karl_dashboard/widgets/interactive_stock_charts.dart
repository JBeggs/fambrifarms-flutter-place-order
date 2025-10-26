import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/dashboard_stock_kpi_provider.dart';
import '../../../core/professional_theme.dart';

class InteractiveStockCharts extends ConsumerStatefulWidget {
  const InteractiveStockCharts({super.key});

  @override
  ConsumerState<InteractiveStockCharts> createState() => _InteractiveStockChartsState();
}

class _InteractiveStockChartsState extends ConsumerState<InteractiveStockCharts>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          
          TabBar(
            controller: _tabController,
            labelColor: AppColors.primaryGreen,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primaryGreen,
            tabs: const [
              Tab(text: 'Stock Levels'),
              Tab(text: 'Movements'),
              Tab(text: 'Value'),
              Tab(text: 'Trends'),
            ],
          ),
          const SizedBox(height: 20),
          
          SizedBox(
            height: 300,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildStockLevelChart(context, kpiData),
                _buildStockMovementChart(context, kpiData),
                _buildStockValueChart(context, kpiData),
                _buildStockTrendChart(context, kpiData),
              ],
            ),
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
            Icons.bar_chart,
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
                'Interactive Stock Charts',
                style: AppTextStyles.titleLarge.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                'Visual analytics with drill-down capabilities',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () {
            // TODO: Implement export functionality
          },
          icon: Icon(
            Icons.download,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildStockLevelChart(BuildContext context, Map<String, dynamic> kpiData) {
    final criticalItems = kpiData['criticalStockItems'] as int;
    final stockHealthScore = kpiData['stockHealthScore'] as double;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Current Stock Distribution',
          style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        
        Expanded(
          child: Row(
            children: [
              // Mock bar chart
              Expanded(
                flex: 3,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.borderColor),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildBar('Excellent', 0.8, AppColors.accentGreen),
                            _buildBar('Good', 0.6, AppColors.primaryGreen),
                            _buildBar('Low', 0.4, AppColors.accentOrange),
                            _buildBar('Critical', 0.2, AppColors.accentRed),
                            _buildBar('Out', 0.1, AppColors.accentRed),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              
              // Legend and stats
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLegendItem('Excellent Stock', AppColors.accentGreen, '45%'),
                    _buildLegendItem('Good Stock', AppColors.primaryGreen, '30%'),
                    _buildLegendItem('Low Stock', AppColors.accentOrange, '15%'),
                    _buildLegendItem('Critical Stock', AppColors.accentRed, '8%'),
                    _buildLegendItem('Out of Stock', AppColors.accentRed, '2%'),
                    const SizedBox(height: 16),
                    
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Health Score',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${stockHealthScore.toStringAsFixed(0)}%',
                            style: AppTextStyles.titleMedium.copyWith(
                              color: AppColors.accentGreen,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$criticalItems items need attention',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStockMovementChart(BuildContext context, Map<String, dynamic> kpiData) {
    final stockVelocity = kpiData['stockVelocity'] as double;
    final turnoverRate = kpiData['stockTurnoverRate'] as double;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Stock Movement Analysis',
          style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borderColor),
            ),
            child: Column(
              children: [
                // Mock line chart area
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.borderColor),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: CustomPaint(
                      painter: StockMovementPainter(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMetricCard('Velocity', '${stockVelocity.toStringAsFixed(2)}x', AppColors.accentBlue),
                    _buildMetricCard('Turnover', '${turnoverRate.toStringAsFixed(2)}x', AppColors.accentOrange),
                    _buildMetricCard('Efficiency', '85%', AppColors.accentGreen),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStockValueChart(BuildContext context, Map<String, dynamic> kpiData) {
    final totalValue = kpiData['totalStockValue'] as double;
    final carryingCost = kpiData['carryingCostEfficiency'] as double;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Stock Value Distribution',
          style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        
        Expanded(
          child: Row(
            children: [
              // Mock pie chart
              Expanded(
                flex: 2,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.borderColor),
                  ),
                  child: CustomPaint(
                    painter: PieChartPainter(),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              
              // Value breakdown
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Value: R${totalValue.toStringAsFixed(2)}',
                      style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    _buildValueItem('Fresh Produce', 'R15,420', 45, AppColors.accentGreen),
                    _buildValueItem('Packaged Goods', 'R8,230', 25, AppColors.accentBlue),
                    _buildValueItem('Dairy Products', 'R6,180', 18, AppColors.accentOrange),
                    _buildValueItem('Other Items', 'R4,170', 12, AppColors.primaryGreen),
                    
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceDark,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.borderColor),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Carrying Efficiency',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            '${carryingCost.toStringAsFixed(1)}%',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.accentGreen,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStockTrendChart(BuildContext context, Map<String, dynamic> kpiData) {
    final forecastAccuracy = kpiData['demandForecastAccuracy'] as double;
    final averageDays = kpiData['averageDaysOfStock'] as double;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Historical Trends & Forecasts',
          style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borderColor),
            ),
            child: Column(
              children: [
                // Mock trend chart
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.borderColor),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: CustomPaint(
                      painter: TrendChartPainter(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    Expanded(
                      child: _buildTrendMetric(
                        'Forecast Accuracy',
                        '${forecastAccuracy.toStringAsFixed(1)}%',
                        Icons.check_circle,
                        AppColors.accentBlue,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTrendMetric(
                        'Avg. Stock Days',
                        '${averageDays.toStringAsFixed(0)} days',
                        Icons.calendar_today,
                        AppColors.accentOrange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBar(String label, double height, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 30,
          height: height * 150,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color, String percentage) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
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
            percentage,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppTextStyles.titleSmall.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValueItem(String category, String value, int percentage, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
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
              category,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            '$percentage%',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendMetric(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: AppTextStyles.titleSmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painters for mock charts
class StockMovementPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accentBlue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(0, size.height * 0.7);
    path.lineTo(size.width * 0.2, size.height * 0.5);
    path.lineTo(size.width * 0.4, size.height * 0.3);
    path.lineTo(size.width * 0.6, size.height * 0.4);
    path.lineTo(size.width * 0.8, size.height * 0.2);
    path.lineTo(size.width, size.height * 0.1);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PieChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.3;

    final colors = [
      AppColors.accentGreen,
      AppColors.accentBlue,
      AppColors.accentOrange,
      AppColors.primaryGreen,
    ];

    final angles = [0.45, 0.25, 0.18, 0.12];
    double startAngle = 0;

    for (int i = 0; i < colors.length; i++) {
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.fill;

      final sweepAngle = angles[i] * 2 * 3.14159;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class TrendChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Historical line
    final historicalPaint = Paint()
      ..color = AppColors.accentBlue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final historicalPath = Path();
    historicalPath.moveTo(0, size.height * 0.8);
    historicalPath.lineTo(size.width * 0.3, size.height * 0.6);
    historicalPath.lineTo(size.width * 0.6, size.height * 0.4);

    // Forecast line (dashed)
    final forecastPaint = Paint()
      ..color = AppColors.accentOrange
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final forecastPath = Path();
    forecastPath.moveTo(size.width * 0.6, size.height * 0.4);
    forecastPath.lineTo(size.width * 0.8, size.height * 0.3);
    forecastPath.lineTo(size.width, size.height * 0.2);

    canvas.drawPath(historicalPath, historicalPaint);
    canvas.drawPath(forecastPath, forecastPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
