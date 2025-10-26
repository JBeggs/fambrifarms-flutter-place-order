import 'package:flutter/material.dart';
import '../../../services/api_service.dart';

class SupplierRecommendationsCard extends StatefulWidget {
  final int productId;
  final String productName;
  final double quantity;
  final VoidCallback? onRecommendationSelected;

  const SupplierRecommendationsCard({
    super.key,
    required this.productId,
    required this.productName,
    required this.quantity,
    this.onRecommendationSelected,
  });

  @override
  State<SupplierRecommendationsCard> createState() => _SupplierRecommendationsCardState();
}

class _SupplierRecommendationsCardState extends State<SupplierRecommendationsCard> {
  bool _isLoading = false;
  Map<String, dynamic>? _recommendations;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiService = ApiService();
      final result = await apiService.getSupplierRecommendations(
        productId: widget.productId,
        quantity: widget.quantity,
      );
      
      setState(() {
        _recommendations = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.local_shipping, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Supplier Recommendations',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadRecommendations,
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Product Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${widget.productName} × ${widget.quantity.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Content
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Error loading recommendations: $_error',
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              )
            else if (_recommendations != null)
              _buildRecommendations()
            else
              const Center(
                child: Text('No recommendations available'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendations() {
    final suppliers = _recommendations!['suppliers'] as List<dynamic>? ?? [];
    
    if (suppliers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: const Text('No suppliers available for this product'),
      );
    }

    return Column(
      children: suppliers.asMap().entries.map((entry) {
        final index = entry.key;
        final supplier = entry.value as Map<String, dynamic>;
        final isRecommended = index == 0;
        final isFambri = supplier['supplier_type'] == 'internal';
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isRecommended 
                ? (isFambri ? Colors.green : Colors.blue)
                : Colors.grey.shade300,
              width: isRecommended ? 2 : 1,
            ),
            color: isRecommended 
              ? (isFambri ? Colors.green.shade50 : Colors.blue.shade50)
              : Colors.white,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Supplier Header
                Row(
                  children: [
                    // Priority Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isRecommended 
                          ? (isFambri ? Colors.green : Colors.blue)
                          : Colors.grey,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isRecommended 
                          ? (isFambri ? 'RECOMMENDED' : 'BEST PRICE')
                          : 'FALLBACK',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    
                    // Supplier Type Icon
                    Icon(
                      isFambri ? Icons.home : Icons.store,
                      color: isFambri ? Colors.green : Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    
                    // Supplier Name
                    Expanded(
                      child: Text(
                        supplier['supplier_name'] ?? 'Unknown Supplier',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    
                    // Savings Badge (if not primary)
                    if (!isRecommended && suppliers.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      _buildSavingsBadge(supplier, suppliers[0] as Map<String, dynamic>),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                
                // Details Grid
                Row(
                  children: [
                    Expanded(
                      child: _buildDetailItem(
                        Icons.attach_money,
                        'Price',
                        'R${(supplier['unit_price'] as num).toStringAsFixed(2)}',
                        Colors.green,
                      ),
                    ),
                    Expanded(
                      child: _buildDetailItem(
                        Icons.inventory,
                        'Available',
                        '${(supplier['available_quantity'] as num).toInt()} units',
                        Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildDetailItem(
                        Icons.star,
                        'Quality',
                        '${(supplier['quality_rating'] as num).toStringAsFixed(1)}/5.0',
                        Colors.amber,
                      ),
                    ),
                    Expanded(
                      child: _buildDetailItem(
                        Icons.schedule,
                        'Lead Time',
                        '${supplier['lead_time_days']} days',
                        Colors.purple,
                      ),
                    ),
                  ],
                ),
                
                // Total Cost
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Cost:',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'R${(supplier['total_cost'] as num).toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: isRecommended ? Colors.green.shade700 : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Can Fulfill Badge
                if (supplier['can_fulfill_full_order'] == true) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green.shade700, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Can fulfill full order',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSavingsBadge(Map<String, dynamic> supplier, Map<String, dynamic> bestSupplier) {
    final currentPrice = supplier['unit_price'] as num;
    final bestPrice = bestSupplier['unit_price'] as num;
    final difference = currentPrice - bestPrice;
    final percentageMore = (difference / bestPrice * 100);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.red.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '+${percentageMore.toStringAsFixed(0)}%',
        style: TextStyle(
          color: Colors.red.shade700,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
