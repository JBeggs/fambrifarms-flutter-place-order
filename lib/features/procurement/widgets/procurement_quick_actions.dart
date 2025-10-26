// Procurement Quick Actions - Fast access to key procurement functions
// Karl's shortcut to procurement magic!

import 'package:flutter/material.dart';

class ProcurementQuickActions extends StatelessWidget {
  final VoidCallback onGenerateRecommendation;
  final VoidCallback onViewBuffers;
  final VoidCallback onViewRecipes;
  final VoidCallback onViewHistory;

  const ProcurementQuickActions({
    super.key,
    required this.onGenerateRecommendation,
    required this.onViewBuffers,
    required this.onViewRecipes,
    required this.onViewHistory,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Generate recommendation - primary action
            _buildPrimaryAction(
              context,
              icon: Icons.auto_awesome,
              title: 'Generate Smart Recommendation',
              subtitle: 'AI-powered market planning',
              onTap: onGenerateRecommendation,
              color: const Color(0xFF2D5016),
            ),
            
            const SizedBox(height: 12),
            
            // Secondary actions grid
            Row(
              children: [
                Expanded(
                  child: _buildSecondaryAction(
                    context,
                    icon: Icons.tune,
                    title: 'Buffer Settings',
                    subtitle: 'Adjust waste factors',
                    onTap: onViewBuffers,
                    color: Colors.blue[700]!,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSecondaryAction(
                    context,
                    icon: Icons.restaurant_menu,
                    title: 'Recipes',
                    subtitle: 'Veggie box ingredients',
                    onTap: onViewRecipes,
                    color: Colors.green[700]!,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            Row(
              children: [
                Expanded(
                  child: _buildSecondaryAction(
                    context,
                    icon: Icons.history,
                    title: 'History',
                    subtitle: 'Past recommendations',
                    onTap: onViewHistory,
                    color: Colors.purple[700]!,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSecondaryAction(
                    context,
                    icon: Icons.analytics,
                    title: 'Analytics',
                    subtitle: 'Performance insights',
                    onTap: () => _showComingSoon(context, 'Analytics'),
                    color: Colors.orange[700]!,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryAction(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withOpacity(0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.white.withOpacity(0.8),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryAction(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: color,
                size: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature coming soon! 🚀'),
        backgroundColor: const Color(0xFF2D5016),
      ),
    );
  }
}

