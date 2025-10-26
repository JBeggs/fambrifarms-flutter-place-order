import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/market_price.dart';

class MarketVolatilitySection extends StatelessWidget {
  final AsyncValue<Map<String, dynamic>> marketVolatilityAsync;

  const MarketVolatilitySection({
    super.key,
    required this.marketVolatilityAsync,
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
                Icon(Icons.trending_up, color: Theme.of(context).primaryColor),
                const SizedBox(width: 12),
                Text(
                  'Market Volatility',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                marketVolatilityAsync.when(
                  data: (data) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${data['period']}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: marketVolatilityAsync.when(
                data: (data) {
                  final volatilityData = data['volatility_data'] as List<dynamic>? ?? [];
                  
                  if (volatilityData.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.show_chart, size: 48, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No volatility data available',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: [
                      // Summary Stats
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildSummaryItem(
                                context,
                                'Products Analyzed',
                                '${data['total_products_analyzed']}',
                                Icons.inventory,
                              ),
                            ),
                            Expanded(
                              child: _buildSummaryItem(
                                context,
                                'High Volatility',
                                '${data['high_volatility_products']?.length ?? 0}',
                                Icons.warning,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Volatility List
                      Expanded(
                        child: ListView.builder(
                          itemCount: volatilityData.length,
                          itemBuilder: (context, index) {
                            final item = MarketVolatilityData.fromJson(volatilityData[index]);
                            return _VolatilityCard(volatilityData: item);
                          },
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load volatility data',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.toString(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.red,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(BuildContext context, String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.outline),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _VolatilityCard extends StatelessWidget {
  final MarketVolatilityData volatilityData;

  const _VolatilityCard({required this.volatilityData});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Card(
        elevation: 1,
        child: InkWell(
          onTap: () => _showVolatilityDetails(context),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Volatility Indicator
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: volatilityData.volatilityColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Product Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        volatilityData.productName,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        volatilityData.formattedPriceRange,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Volatility Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: volatilityData.volatilityColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    volatilityData.formattedVolatility,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: volatilityData.volatilityColor,
                    ),
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // Affected Customers
                if (volatilityData.affectedCustomers > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6B7280).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${volatilityData.affectedCustomers}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                
                const SizedBox(width: 4),
                
                Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showVolatilityDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(volatilityData.productName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Volatility Level Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: volatilityData.volatilityColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                volatilityData.volatilityDisplayName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: volatilityData.volatilityColor,
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Price Information
            _buildDetailRow('Price Range', volatilityData.formattedPriceRange),
            _buildDetailRow('Volatility', volatilityData.formattedVolatility),
            _buildDetailRow('Price Points', '${volatilityData.pricePoints} data points'),
            _buildDetailRow('Affected Customers', '${volatilityData.affectedCustomers} customers'),
            
            const SizedBox(height: 16),
            
            // Impact Analysis
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Impact Analysis',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(_getVolatilityImpact()),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Navigate to price history or create alert
            },
            child: const Text('View History'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  String _getVolatilityImpact() {
    switch (volatilityData.volatilityLevel) {
      case 'extremely_volatile':
        return 'Extreme price swings detected. Consider immediate pricing adjustments and customer notifications.';
      case 'highly_volatile':
        return 'High volatility may impact customer pricing. Monitor closely and adjust markup rules as needed.';
      case 'volatile':
        return 'Moderate volatility detected. Standard volatility adjustments should apply.';
      case 'stable':
        return 'Price is stable. Normal pricing rules apply without volatility adjustments.';
      default:
        return 'Insufficient data to determine volatility impact.';
    }
  }
}
