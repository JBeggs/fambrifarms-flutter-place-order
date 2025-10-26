// Time Savings Summary Widget - Shows Karl how much time he's saving!
// This is the surprise element that makes Karl smile 😊

import 'package:flutter/material.dart';

class TimeSavingsSummary extends StatelessWidget {
  final Map<String, dynamic> timeSavings;

  const TimeSavingsSummary({
    super.key,
    required this.timeSavings,
  });

  @override
  Widget build(BuildContext context) {
    final timeSavedHours = timeSavings['total_time_saved_hours'] as double;
    final itemsOptimized = timeSavings['total_items_optimized'] as int;
    final efficiencyImprovement = timeSavings['efficiency_improvement'] as double;
    final recommendationsCount = timeSavings['recommendations_count'] as int;

    return Card(
      elevation: 3,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              Colors.green[400]!,
              Colors.green[600]!,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
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
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.timer_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Karl\'s Time Savings',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (timeSavedHours > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '🎉 HERO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 20),

              if (timeSavedHours > 0) ...[
                // Main time savings metric
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      timeSavedHours.toStringAsFixed(1),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'hours saved',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Detailed metrics
                _buildMetricRow(
                  Icons.shopping_cart,
                  'Items Optimized',
                  itemsOptimized.toString(),
                ),
                const SizedBox(height: 8),
                _buildMetricRow(
                  Icons.trending_up,
                  'Efficiency Gain',
                  '${efficiencyImprovement.toStringAsFixed(0)}%',
                ),
                const SizedBox(height: 8),
                _buildMetricRow(
                  Icons.auto_awesome,
                  'Smart Recommendations',
                  recommendationsCount.toString(),
                ),

                const SizedBox(height: 16),

                // Motivational message
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Text('🚀', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _getMotivationalMessage(timeSavedHours),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Getting started state
                Column(
                  children: [
                    const Text(
                      '⚡',
                      style: TextStyle(fontSize: 32),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Ready to Save Time?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Generate your first smart recommendation to start tracking your time savings!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lightbulb, color: Colors.white, size: 16),
                          SizedBox(width: 8),
                          Text(
                            'Each recommendation saves ~12 minutes!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.white.withOpacity(0.8),
          size: 16,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _getMotivationalMessage(double hours) {
    if (hours < 1) {
      return "Great start! You're already working smarter, not harder.";
    } else if (hours < 5) {
      return "Fantastic! You've saved enough time for a coffee break.";
    } else if (hours < 10) {
      return "Amazing! That's almost a full workday saved through smart planning.";
    } else if (hours < 20) {
      return "Incredible! You've saved more than 2 full workdays. You're a procurement hero!";
    } else {
      return "LEGENDARY! You've revolutionized your market operations. Karl the Procurement Master! 👑";
    }
  }
}

