import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/pricing_rule.dart';
import '../../models/customer_price_list.dart';
import '../../services/api_service.dart';
import 'widgets/pricing_stats_cards.dart';
import 'widgets/pricing_rules_section.dart';
import 'widgets/market_volatility_section.dart';
import 'widgets/customer_price_lists_section.dart';

// Providers
final pricingRulesProvider = FutureProvider<List<PricingRule>>((ref) async {
  final apiService = ref.read(apiServiceProvider);
  return apiService.getPricingRules();
});

final marketVolatilityProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final apiService = ref.read(apiServiceProvider);
  return apiService.getMarketVolatilityDashboard();
});

final customerPriceListsProvider = FutureProvider<List<CustomerPriceList>>((ref) async {
  final apiService = ref.read(apiServiceProvider);
  return apiService.getCustomerPriceLists();
});

final priceAlertsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final apiService = ref.read(apiServiceProvider);
  return apiService.getPriceAlerts(acknowledged: false);
});

class PricingDashboardPage extends ConsumerWidget {
  const PricingDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pricingRulesAsync = ref.watch(pricingRulesProvider);
    final marketVolatilityAsync = ref.watch(marketVolatilityProvider);
    final customerPriceListsAsync = ref.watch(customerPriceListsProvider);
    final priceAlertsAsync = ref.watch(priceAlertsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dynamic Pricing Management'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(pricingRulesProvider);
              ref.invalidate(marketVolatilityProvider);
              ref.invalidate(customerPriceListsProvider);
              ref.invalidate(priceAlertsProvider);
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // TODO: Navigate to pricing settings
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(pricingRulesProvider);
          ref.invalidate(marketVolatilityProvider);
          ref.invalidate(customerPriceListsProvider);
          ref.invalidate(priceAlertsProvider);
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Page Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.trending_up,
                      color: Color(0xFF6366F1),
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Intelligent Pricing Dashboard',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'AI-powered market volatility management and dynamic pricing',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Stats Cards
              PricingStatsCards(
                pricingRulesAsync: pricingRulesAsync,
                marketVolatilityAsync: marketVolatilityAsync,
                customerPriceListsAsync: customerPriceListsAsync,
                priceAlertsAsync: priceAlertsAsync,
              ),
              const SizedBox(height: 32),

              // Pricing Rules Section
              PricingRulesSection(pricingRulesAsync: pricingRulesAsync),
              const SizedBox(height: 32),

              // Market Volatility Section
              MarketVolatilitySection(marketVolatilityAsync: marketVolatilityAsync),
              const SizedBox(height: 32),

              // Customer Price Lists Section
              CustomerPriceListsSection(customerPriceListsAsync: customerPriceListsAsync),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
        ),
        child: Row(
          children: [
            // Run Stock Analysis Button
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _runStockAnalysis(context, ref),
                icon: const Icon(Icons.analytics_outlined),
                label: const Text('Run Stock Analysis'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            
            // Generate Weekly Report Button
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _generateWeeklyReport(context, ref),
                icon: const Icon(Icons.assessment_outlined),
                label: const Text('Weekly Report'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            
            // Generate Price Lists Button
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _generatePriceLists(context, ref),
                icon: const Icon(Icons.price_change_outlined),
                label: const Text('Generate Price Lists'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Action Methods
  Future<void> _runStockAnalysis(BuildContext context, WidgetRef ref) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Running stock analysis...'),
          ],
        ),
      ),
    );

    try {
      final apiService = ref.read(apiServiceProvider);
      final result = await apiService.runStockAnalysis();
      
      Navigator.of(context).pop(); // Close loading dialog
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Stock analysis completed! Analysis ID: ${result['id']}'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to run stock analysis: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  Future<void> _generateWeeklyReport(BuildContext context, WidgetRef ref) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Generating weekly report...'),
          ],
        ),
      ),
    );

    try {
      final apiService = ref.read(apiServiceProvider);
      final result = await apiService.generateWeeklyReport();
      
      Navigator.of(context).pop(); // Close loading dialog
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Weekly report generated! ${result['report_name']}'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate weekly report: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  Future<void> _generatePriceLists(BuildContext context, WidgetRef ref) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Generating price lists...'),
          ],
        ),
      ),
    );

    try {
      final apiService = ref.read(apiServiceProvider);
      
      // Get all pricing rules and customers
      final allPricingRules = await apiService.getPricingRules(effective: true);
      final customers = await apiService.getCustomers();
      
      // Remove duplicates by keeping only unique combinations of name + segment
      final uniqueRules = <String, PricingRule>{};
      for (final rule in allPricingRules) {
        final key = '${rule.name.toLowerCase()}_${rule.customerSegment}';
        if (!uniqueRules.containsKey(key)) {
          uniqueRules[key] = rule;
        }
      }
      
      final pricingRules = uniqueRules.values.toList();
      debugPrint('Using ${pricingRules.length} unique pricing rules (filtered from ${allPricingRules.length} total)');
      
      int totalGenerated = 0;
      
      // FIXED: Generate price lists for all customers using the standard pricing rule
      // This ensures all customers get price lists regardless of their segment classification
      if (pricingRules.isNotEmpty && customers.isNotEmpty) {
        // Use the standard pricing rule (25% markup) for all customers
        final standardRule = pricingRules.firstWhere(
          (rule) => rule.customerSegment == 'standard',
          orElse: () => pricingRules.first, // Fallback to first rule if standard not found
        );
        
        final customerIds = customers.map((c) => (c as Map<String, dynamic>)['id'] as int).toList();
        
        debugPrint('Generating price lists for ${customerIds.length} customers using rule: ${standardRule.name}');
        
        await apiService.generateCustomerPriceListsFromMarketData(
          customerIds: customerIds,
          pricingRuleId: standardRule.id,
        );
        totalGenerated = customerIds.length;
      }

      Navigator.of(context).pop(); // Close loading dialog
      
      // Refresh data
      ref.invalidate(customerPriceListsProvider);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Generated $totalGenerated price lists successfully!'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate price lists: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }
}
