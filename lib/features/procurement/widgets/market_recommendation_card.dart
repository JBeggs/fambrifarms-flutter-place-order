// Market Recommendation Card - Shows Karl's intelligent market recommendations
// This is where the magic happens - AI-powered procurement suggestions!

import 'package:flutter/material.dart';
import '../../../models/procurement_models.dart';

class MarketRecommendationCard extends StatelessWidget {
  final MarketRecommendation recommendation;
  final VoidCallback? onApprove;
  final VoidCallback? onViewDetails;
  final bool showApprovalButton;

  const MarketRecommendationCard({
    super.key,
    required this.recommendation,
    this.onApprove,
    this.onViewDetails,
    this.showApprovalButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status and date
            Row(
              children: [
                Text(
                  recommendation.statusEmoji,
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Market Trip for ${_formatDate(recommendation.forDate)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        recommendation.statusDisplay,
                        style: TextStyle(
                          fontSize: 12,
                          color: _getStatusColor(),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D5016).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'R${recommendation.totalEstimatedCost.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D5016),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Items summary
            Row(
              children: [
                Icon(
                  Icons.shopping_basket,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  '${recommendation.itemsCount} items',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getTimeSavingText(),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Top priority items preview
            if (recommendation.items.isNotEmpty) ...[
              Text(
                'Top Priority Items:',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ...recommendation.items
                  .where((item) => item.priority == 'critical' || item.priority == 'high')
                  .take(3)
                  .map((item) => _buildItemPreview(item)),
            ],

            const SizedBox(height: 16),

            // Time saving insight
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.psychology,
                    color: Colors.blue[700],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      recommendation.timeSavingInsight,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[800],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                if (onViewDetails != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onViewDetails,
                      icon: const Icon(Icons.visibility, size: 16),
                      label: const Text('View Details'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2D5016),
                        side: const BorderSide(color: Color(0xFF2D5016)),
                      ),
                    ),
                  ),
                if (onViewDetails != null && showApprovalButton && onApprove != null)
                  const SizedBox(width: 12),
                if (showApprovalButton && onApprove != null && recommendation.status == 'pending')
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onApprove,
                      icon: const Icon(Icons.check_circle, size: 16),
                      label: const Text('Approve & Go!'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D5016),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemPreview(MarketRecommendationItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            item.priorityEmoji,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${item.productName}: ${item.recommendedQuantity.toStringAsFixed(1)}kg',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            'R${item.estimatedTotalCost.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    
    final weekday = weekdays[date.weekday - 1];
    final month = months[date.month - 1];
    
    return '$weekday, $month ${date.day}';
  }

  Color _getStatusColor() {
    switch (recommendation.status) {
      case 'pending':
        return Colors.orange[700]!;
      case 'approved':
        return Colors.green[700]!;
      case 'purchased':
        return Colors.blue[700]!;
      case 'cancelled':
        return Colors.red[700]!;
      default:
        return Colors.grey[700]!;
    }
  }

  String _getTimeSavingText() {
    if (recommendation.itemsCount == 0) return 'No items needed';
    
    final estimatedTime = (recommendation.itemsCount * 3) + 30; // 3 mins per item + 30 travel
    final timeSaved = recommendation.itemsCount * 5; // 5 mins saved per item
    
    return 'Saves ${timeSaved}min planning • ~${estimatedTime}min trip';
  }
}

