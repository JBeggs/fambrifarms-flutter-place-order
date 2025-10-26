import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/pricing_rule.dart';
import '../../../services/api_service.dart';
import '../pricing_dashboard_page.dart';
import 'pricing_rule_form_dialog.dart';

class PricingRulesSection extends ConsumerWidget {
  final AsyncValue<List<PricingRule>> pricingRulesAsync;

  const PricingRulesSection({
    super.key,
    required this.pricingRulesAsync,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.rule, color: Theme.of(context).primaryColor),
                const SizedBox(width: 12),
                Text(
                  'Pricing Rules',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _showAddRuleDialog(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Rule'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: pricingRulesAsync.when(
                data: (rules) => rules.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.rule, size: 48, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No pricing rules configured',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: rules.length,
                        itemBuilder: (context, index) {
                          final rule = rules[index];
                          return _PricingRuleCard(
                            rule: rule,
                            onEdit: () => _showEditRuleDialog(context, ref, rule),
                            onDelete: () => _deleteRule(context, ref, rule),
                          );
                        },
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load pricing rules',
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

  void _showAddRuleDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => const PricingRuleFormDialog(),
    ).then((_) {
      // Refresh the pricing rules after dialog closes
      ref.invalidate(pricingRulesProvider);
    });
  }

  void _showEditRuleDialog(BuildContext context, WidgetRef ref, PricingRule rule) {
    showDialog(
      context: context,
      builder: (context) => PricingRuleFormDialog(
        existingRule: rule,
      ),
    ).then((_) {
      // Refresh the pricing rules after dialog closes
      ref.invalidate(pricingRulesProvider);
    });
  }

  void _deleteRule(BuildContext context, WidgetRef ref, PricingRule rule) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Pricing Rule'),
        content: Text('Are you sure you want to delete "${rule.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final apiService = ref.read(apiServiceProvider);
                await apiService.deletePricingRule(rule.id);
                ref.invalidate(pricingRulesProvider);
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Pricing rule deleted successfully')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting rule: $e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _PricingRuleCard extends StatelessWidget {
  final PricingRule rule;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PricingRuleCard({
    required this.rule,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 1,
        child: InkWell(
          onTap: () => _showRuleDetailsDialog(context, rule),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: rule.segmentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        rule.segmentDisplayName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: rule.segmentColor,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (rule.isEffectiveNow)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'ACTIVE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  rule.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                if (rule.description.isNotEmpty)
                  Text(
                    rule.description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildMetric(
                      context,
                      'Base Markup',
                      '${rule.baseMarkupPercentage.toStringAsFixed(1)}%',
                      Icons.percent,
                    ),
                    const SizedBox(width: 16),
                    _buildMetric(
                      context,
                      'Volatility Adj.',
                      '+${rule.volatilityAdjustment.toStringAsFixed(1)}%',
                      Icons.trending_up,
                    ),
                    const SizedBox(width: 16),
                    _buildMetric(
                      context,
                      'Min Margin',
                      '${rule.minimumMarginPercentage.toStringAsFixed(1)}%',
                      Icons.security,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Edit'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF6366F1),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete, size: 16),
                      label: const Text('Delete'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetric(BuildContext context, String label, String value, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Theme.of(context).colorScheme.outline),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
                fontSize: 10,
              ),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showRuleDetailsDialog(BuildContext context, PricingRule rule) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(rule.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: rule.segmentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  rule.segmentDisplayName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: rule.segmentColor,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (rule.description.isNotEmpty) ...[
                Text(
                  'Description',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(rule.description),
                const SizedBox(height: 16),
              ],
              Text(
                'Pricing Details',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text('Base Markup: ${rule.baseMarkupPercentage.toStringAsFixed(1)}%'),
              Text('Volatility Adjustment: +${rule.volatilityAdjustment.toStringAsFixed(1)}%'),
              Text('Minimum Margin: ${rule.minimumMarginPercentage.toStringAsFixed(1)}%'),
            ],
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