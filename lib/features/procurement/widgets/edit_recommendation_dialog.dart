import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/api_service.dart';

// Define the models we need for editing
class MarketProcurementRecommendation {
  final int id;
  final DateTime forDate;
  final double totalEstimatedCost;
  final int itemsCount;
  final String status;
  final DateTime createdAt;
  final List<MarketProcurementItem> items;

  MarketProcurementRecommendation({
    required this.id,
    required this.forDate,
    required this.totalEstimatedCost,
    required this.itemsCount,
    required this.status,
    required this.createdAt,
    required this.items,
  });
}

class MarketProcurementItem {
  final int id;
  final int productId;
  final String productName;
  final double neededQuantity;
  final double recommendedQuantity;
  final double bufferQuantity;
  final double estimatedUnitPrice;
  final double estimatedTotalCost;
  final String priority;
  final String reasoning;

  MarketProcurementItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.neededQuantity,
    required this.recommendedQuantity,
    required this.bufferQuantity,
    required this.estimatedUnitPrice,
    required this.estimatedTotalCost,
    required this.priority,
    required this.reasoning,
  });

  MarketProcurementItem copyWith({
    int? id,
    int? productId,
    String? productName,
    double? neededQuantity,
    double? recommendedQuantity,
    double? bufferQuantity,
    double? estimatedUnitPrice,
    double? estimatedTotalCost,
    String? priority,
    String? reasoning,
  }) {
    return MarketProcurementItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      neededQuantity: neededQuantity ?? this.neededQuantity,
      recommendedQuantity: recommendedQuantity ?? this.recommendedQuantity,
      bufferQuantity: bufferQuantity ?? this.bufferQuantity,
      estimatedUnitPrice: estimatedUnitPrice ?? this.estimatedUnitPrice,
      estimatedTotalCost: estimatedTotalCost ?? this.estimatedTotalCost,
      priority: priority ?? this.priority,
      reasoning: reasoning ?? this.reasoning,
    );
  }
}

class EditRecommendationDialog extends StatefulWidget {
  final MarketProcurementRecommendation recommendation;
  final VoidCallback? onUpdated;

  const EditRecommendationDialog({
    super.key,
    required this.recommendation,
    this.onUpdated,
  });

  @override
  State<EditRecommendationDialog> createState() => _EditRecommendationDialogState();
}

class _EditRecommendationDialogState extends State<EditRecommendationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();
  
  late DateTime _forDate;
  late List<MarketProcurementItem> _items;
  bool _isLoading = false;

  final List<String> _priorities = ['low', 'medium', 'high', 'critical'];

  @override
  void initState() {
    super.initState();
    _forDate = widget.recommendation.forDate;
    _items = List.from(widget.recommendation.items);
  }

  Future<void> _saveRecommendation() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final recommendationData = {
        'for_date': _forDate.toIso8601String().split('T')[0],
        'items': _items.map((item) => {
          'id': item.id,
          'product_id': item.productId,
          'needed_quantity': item.neededQuantity,
          'recommended_quantity': item.recommendedQuantity,
          'estimated_unit_price': item.estimatedUnitPrice,
          'priority': item.priority,
        }).toList(),
      };

      await _apiService.updateProcurementRecommendation(
        widget.recommendation.id,
        recommendationData,
      );

      if (mounted) {
        Navigator.of(context).pop();
        widget.onUpdated?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recommendation updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating recommendation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _forDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    
    if (picked != null) {
      setState(() => _forDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 800,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF2D5016),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.edit, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Edit Market Recommendation',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${_items.length} items • R${widget.recommendation.totalEstimatedCost.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            
            // Form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date Selection
                      Row(
                        children: [
                          const Text(
                            'Market Trip Date:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: _selectDate,
                            icon: const Icon(Icons.calendar_today),
                            label: Text(
                              '${_forDate.day}/${_forDate.month}/${_forDate.year}',
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Items Section
                      Row(
                        children: [
                          const Text(
                            'Recommendation Items',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${_items.length} items',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Items List
                      if (_items.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(40),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Text(
                              'No items in this recommendation',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        )
                      else
                        ...List.generate(_items.length, (index) {
                          final item = _items[index];
                          return _buildItemCard(item, index);
                        }),
                    ],
                  ),
                ),
              ),
            ),
            
            // Actions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveRecommendation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D5016),
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Save Changes'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(MarketProcurementItem item, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.productName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DropdownButton<String>(
                  value: item.priority,
                  items: _priorities.map((priority) => DropdownMenuItem(
                    value: priority,
                    child: Text(priority.toUpperCase()),
                  )).toList(),
                  onChanged: (value) {
                    setState(() {
                      _items[index] = item.copyWith(priority: value!);
                    });
                  },
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _removeItem(index),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Quantities
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: item.neededQuantity.toString(),
                    decoration: const InputDecoration(
                      labelText: 'Needed',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    onChanged: (value) {
                      final quantity = double.tryParse(value) ?? 0;
                      setState(() {
                        _items[index] = item.copyWith(neededQuantity: quantity);
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: item.recommendedQuantity.toString(),
                    decoration: const InputDecoration(
                      labelText: 'Recommended',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    onChanged: (value) {
                      final recommendedQuantity = double.tryParse(value) ?? 0;
                      final bufferQuantity = recommendedQuantity - item.neededQuantity;
                      setState(() {
                        _items[index] = item.copyWith(
                          recommendedQuantity: recommendedQuantity,
                          bufferQuantity: bufferQuantity,
                        );
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: item.bufferQuantity.toString(),
                    decoration: const InputDecoration(
                      labelText: 'Buffer',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    onChanged: (value) {
                      final bufferQuantity = double.tryParse(value) ?? 0;
                      final newRecommendedQuantity = item.neededQuantity + bufferQuantity;
                      setState(() {
                        _items[index] = item.copyWith(
                          recommendedQuantity: newRecommendedQuantity,
                          bufferQuantity: bufferQuantity,
                        );
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: item.estimatedUnitPrice.toString(),
                    decoration: const InputDecoration(
                      labelText: 'Unit Price (R)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    onChanged: (value) {
                      final price = double.tryParse(value) ?? 0;
                      setState(() {
                        _items[index] = item.copyWith(estimatedUnitPrice: price);
                      });
                    },
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Total
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Total: R${(item.recommendedQuantity * item.estimatedUnitPrice).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D5016),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
