// Smart Rounding Display Widget - Shows the intelligent pack-based rounding system
// This helps Karl understand how the system optimizes market purchases!

import 'package:flutter/material.dart';

class SmartRoundingDisplay extends StatelessWidget {
  const SmartRoundingDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1E1E1E),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D5016).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.auto_fix_high,
                    color: Color(0xFF2D5016),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🧮 Smart Rounding System',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Intelligent pack-based purchasing with waste buffers',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '780 Products',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // How it works
            const Text(
              '🎯 How Smart Rounding Works:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            // Process steps
            ...[
              _buildProcessStep(
                '1',
                'Apply Buffers',
                'Needed quantity × (1 + buffer rate)',
                'Accounts for spoilage, waste, and quality rejection',
                Icons.analytics,
                Colors.blue,
              ),
              _buildProcessStep(
                '2',
                'Seasonal Boost',
                'If peak season: × seasonal multiplier',
                'Automatically increases for high-demand periods',
                Icons.trending_up,
                Colors.orange,
              ),
              _buildProcessStep(
                '3',
                'Pack Rounding',
                'Round UP to nearest pack size',
                'Always buy full 5kg, 10kg, or 2.5kg packs',
                Icons.inventory_2,
                const Color(0xFF2D5016),
              ),
            ],

            const SizedBox(height: 20),

            // Examples
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2D5016).withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '📦 Real Examples:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...[
                    _buildExample('Need 2.6kg', '→ Buy 5kg', '(1 pack)', Colors.green),
                    _buildExample('Need 7.3kg', '→ Buy 10kg', '(2 packs)', Colors.blue),
                    _buildExample('Need 0.8kg', '→ Buy 5kg', '(1 pack)', Colors.orange),
                    _buildExample('Need 12.1kg', '→ Buy 20kg', '(4 packs)', Colors.purple),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Benefits
            Row(
              children: [
                _buildBenefit('No Shortages', 'Always have enough stock', Icons.check_circle, Colors.green),
                const SizedBox(width: 16),
                _buildBenefit('Waste Covered', 'Buffer for spoilage & quality', Icons.shield, Colors.blue),
                const SizedBox(width: 16),
                _buildBenefit('Time Saved', '60-80 min per market trip', Icons.timer, Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessStep(String step, String title, String formula, String description, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                step,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: color, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  formula,
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontFamily: 'Courier',
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExample(String need, String buy, String packs, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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
          Text(
            need,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            buy,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            packs,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefit(String title, String description, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
