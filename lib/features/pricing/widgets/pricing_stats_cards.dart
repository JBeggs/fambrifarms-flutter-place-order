import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/pricing_rule.dart';
import '../../../models/customer_price_list.dart';

class PricingStatsCards extends StatelessWidget {
  final AsyncValue<List<PricingRule>> pricingRulesAsync;
  final AsyncValue<Map<String, dynamic>> marketVolatilityAsync;
  final AsyncValue<List<CustomerPriceList>> customerPriceListsAsync;
  final AsyncValue<List<Map<String, dynamic>>> priceAlertsAsync;

  const PricingStatsCards({
    super.key,
    required this.pricingRulesAsync,
    required this.marketVolatilityAsync,
    required this.customerPriceListsAsync,
    required this.priceAlertsAsync,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Active Pricing Rules
        Expanded(
          child: _StatsCard(
            title: 'Active Rules',
            value: pricingRulesAsync.when(
              data: (rules) => '${rules.where((r) => r.isActive).length}',
              loading: () => '...',
              error: (_, __) => '0',
            ),
            subtitle: pricingRulesAsync.when(
              data: (rules) => '${rules.length} total rules',
              loading: () => 'Loading...',
              error: (_, __) => 'Error loading',
            ),
            icon: Icons.rule,
            color: const Color(0xFF6366F1),
          ),
        ),
        
        const SizedBox(width: 16),
        
        // Market Volatility
        Expanded(
          child: _StatsCard(
            title: 'High Volatility',
            value: marketVolatilityAsync.when(
              data: (data) => '${data['high_volatility_products']?.length ?? 0}',
              loading: () => '...',
              error: (_, __) => '0',
            ),
            subtitle: marketVolatilityAsync.when(
              data: (data) => '${data['total_products_analyzed'] ?? 0} products analyzed',
              loading: () => 'Loading...',
              error: (_, __) => 'Error loading',
            ),
            icon: Icons.trending_up,
            color: const Color(0xFFEF4444),
          ),
        ),
        
        const SizedBox(width: 16),
        
        // Active Price Lists
        Expanded(
          child: _StatsCard(
            title: 'Active Lists',
            value: customerPriceListsAsync.when(
              data: (lists) => '${lists.where((l) => l.status == 'active').length}',
              loading: () => '...',
              error: (_, __) => '0',
            ),
            subtitle: customerPriceListsAsync.when(
              data: (lists) => '${lists.length} total lists',
              loading: () => 'Loading...',
              error: (_, __) => 'Error loading',
            ),
            icon: Icons.list_alt,
            color: const Color(0xFF10B981),
          ),
        ),
        
        const SizedBox(width: 16),
        
        // Price Alerts
        Expanded(
          child: _StatsCard(
            title: 'Price Alerts',
            value: priceAlertsAsync.when(
              data: (alerts) => '${alerts.length}',
              loading: () => '...',
              error: (_, __) => '0',
            ),
            subtitle: priceAlertsAsync.when(
              data: (alerts) => alerts.isEmpty ? 'All clear' : 'Need attention',
              loading: () => 'Loading...',
              error: (_, __) => 'Error loading',
            ),
            icon: Icons.notifications_active,
            color: priceAlertsAsync.when(
              data: (alerts) => alerts.isEmpty ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
              loading: () => const Color(0xFF6B7280),
              error: (_, __) => const Color(0xFF6B7280),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatsCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _StatsCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
