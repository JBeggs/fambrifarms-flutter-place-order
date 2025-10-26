import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/api_service.dart';
import '../../../models/product.dart';

class InvoiceItemProcessor {
  final int itemId;
  final String originalDescription;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double lineTotal;
  
  final TextEditingController weightController;
  List<ProductMatch> productMatches;
  bool isProcessed;
  
  InvoiceItemProcessor({
    required this.itemId,
    required this.originalDescription,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.lineTotal,
    String? existingWeight,
  }) : weightController = TextEditingController(text: existingWeight ?? ''),
       productMatches = [],
       isProcessed = false;
       
  void dispose() {
    weightController.dispose();
  }
  
  double? get actualWeight {
    final text = weightController.text.trim();
    return text.isEmpty ? null : double.tryParse(text);
  }
  
  double? get calculatedPricePerKg {
    final weight = actualWeight;
    return weight != null && weight > 0 ? lineTotal / weight : null;
  }
  
  bool get hasValidWeight => actualWeight != null && actualWeight! > 0;
  
  bool get hasProductMatches => productMatches.isNotEmpty;
  
  bool get canProcess => hasValidWeight && hasProductMatches;
}

class ProductMatch {
  final Product product;
  final String pricingStrategy; // 'per_kg', 'per_package', 'per_unit'
  final TextEditingController quantityController;
  final TextEditingController packageSizeController;
  bool isSelected;
  
  ProductMatch({
    required this.product,
    required this.pricingStrategy,
    String? initialQuantity,
    String? initialPackageSize,
  }) : quantityController = TextEditingController(text: initialQuantity ?? '1'),
       packageSizeController = TextEditingController(text: initialPackageSize ?? ''),
       isSelected = false;
       
  void dispose() {
    quantityController.dispose();
    packageSizeController.dispose();
  }
  
  double? get quantity {
    final text = quantityController.text.trim();
    return text.isEmpty ? null : double.tryParse(text);
  }
  
  double? get packageSize {
    final text = packageSizeController.text.trim();
    return text.isEmpty ? null : double.tryParse(text);
  }
}

class WeightInputDialog extends ConsumerStatefulWidget {
  final int invoiceId;

  const WeightInputDialog({
    super.key,
    required this.invoiceId,
  });

  @override
  ConsumerState<WeightInputDialog> createState() => _WeightInputDialogState();
}

class _WeightInputDialogState extends ConsumerState<WeightInputDialog> {
  Map<String, dynamic>? _invoiceData;
  List<Map<String, dynamic>> _items = [];
  Map<int, InvoiceItemProcessor> _itemProcessors = {};
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadInvoiceData();
  }

  @override
  void dispose() {
    for (final processor in _itemProcessors.values) {
      processor.dispose();
      for (final match in processor.productMatches) {
        match.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _loadInvoiceData() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.getExtractedInvoiceData(widget.invoiceId);
      
      if (mounted) {
        setState(() {
          _invoiceData = response;
          _items = List<Map<String, dynamic>>.from(response['items'] ?? []);
          
          // Initialize item processors
          for (final item in _items) {
            final itemId = item['id'] as int;
            final existingWeight = item['actual_weight_kg'];
            
            _itemProcessors[itemId] = InvoiceItemProcessor(
              itemId: itemId,
              originalDescription: item['product_description'] as String? ?? 'Unknown Product',
              quantity: (item['quantity'] as num?)?.toDouble() ?? 0.0,
              unit: item['unit'] as String? ?? '',
              unitPrice: (item['unit_price'] as num?)?.toDouble() ?? 0.0,
              lineTotal: (item['line_total'] as num?)?.toDouble() ?? 0.0,
              existingWeight: existingWeight?.toString(),
            );
          }
          
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading invoice data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _getProductSuggestions(int itemId) async {
    final processor = _itemProcessors[itemId];
    if (processor == null) return;

    try {
      // Use the same API as SHALLOME stock processing for suggestions
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.processMessageWithSuggestions(
        processor.originalDescription,
      );

      if (mounted && response['suggestions'] != null) {
        final suggestions = response['suggestions'] as List;
        
        setState(() {
          processor.productMatches.clear();
          
          for (final suggestion in suggestions) {
            final product = Product.fromJson(suggestion['product']);
            
            // Determine default pricing strategy based on product unit
            String defaultStrategy = 'per_kg';
            if (product.unit != null && (product.unit!.toLowerCase().contains('each') ||
                product.unit!.toLowerCase().contains('bunch') ||
                product.unit!.toLowerCase().contains('head'))) {
              defaultStrategy = 'per_unit';
            } else if (product.name.toLowerCase().contains('bag') ||
                      product.name.toLowerCase().contains('box') ||
                      product.name.toLowerCase().contains('packet')) {
              defaultStrategy = 'per_package';
            }
            
            processor.productMatches.add(ProductMatch(
              product: product,
              pricingStrategy: defaultStrategy,
            ));
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting product suggestions: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _addProductMatch(int itemId) {
    final processor = _itemProcessors[itemId];
    if (processor == null) return;

    // Add a blank product match for manual selection
    setState(() {
      processor.productMatches.add(ProductMatch(
        product: Product(
          id: 0,
          name: 'Select Product...',
          unit: 'kg',
          price: 0.0,
          stockLevel: 0.0,
          minimumStock: 0.0,
          department: 'General',
        ),
        pricingStrategy: 'per_kg',
      ));
    });
  }

  void _removeProductMatch(int itemId, int matchIndex) {
    final processor = _itemProcessors[itemId];
    if (processor == null || matchIndex >= processor.productMatches.length) return;

    setState(() {
      processor.productMatches[matchIndex].dispose();
      processor.productMatches.removeAt(matchIndex);
    });
  }

  Future<void> _saveWeights() async {
    // Validate all weights and product matches
    final processedData = <Map<String, dynamic>>[];
    bool hasErrors = false;

    for (final processor in _itemProcessors.values) {
      // Check weight
      if (!processor.hasValidWeight) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please enter valid weight for ${processor.originalDescription}'),
            backgroundColor: Colors.orange,
          ),
        );
        hasErrors = true;
        break;
      }

      // Check product matches
      final selectedMatches = processor.productMatches.where((m) => m.isSelected).toList();
      if (selectedMatches.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please select at least one product match for ${processor.originalDescription}'),
            backgroundColor: Colors.orange,
          ),
        );
        hasErrors = true;
        break;
      }

      // Validate product match quantities
      for (final match in selectedMatches) {
        if (match.quantity == null || match.quantity! <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Please enter valid quantity for ${match.product.name}'),
              backgroundColor: Colors.orange,
            ),
          );
          hasErrors = true;
          break;
        }

        if (match.pricingStrategy == 'per_package' && 
            (match.packageSize == null || match.packageSize! <= 0)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Please enter valid package size for ${match.product.name}'),
              backgroundColor: Colors.orange,
            ),
          );
          hasErrors = true;
          break;
        }
      }

      if (hasErrors) break;

      // Add to processed data
      processedData.add({
        'item_id': processor.itemId,
        'weight_kg': processor.actualWeight!,
        'product_matches': selectedMatches.map((match) => {
          'product_id': match.product.id,
          'pricing_strategy': match.pricingStrategy,
          'quantity': match.quantity!,
          'package_size_kg': match.packageSize,
        }).toList(),
      });
    }

    if (hasErrors) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.updateInvoiceWeightsAndMatches(
        widget.invoiceId,
        processedData,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Invoice processing completed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving invoice data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.scale, color: Color(0xFF2D5016)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Process Invoice Items',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      if (_invoiceData != null) ...[
                        Text(
                          '${_invoiceData!['supplier']} - ${_invoiceData!['invoice_date']}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(),

            // Instructions
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'For each invoice item: 1) Add actual weight, 2) Get product suggestions, 3) Select matching products and quantities. You can break one invoice item into multiple products (e.g., 50kg potatoes → 10x 5kg bags).',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _itemProcessors.isEmpty
                      ? const Center(
                          child: Text('No items found for this invoice'),
                        )
                      : ListView.builder(
                          itemCount: _itemProcessors.length,
                          itemBuilder: (context, index) {
                            final processor = _itemProcessors.values.elementAt(index);
                            return _buildInvoiceItemCard(processor);
                          },
                        ),
            ),

            // Actions
            const Divider(),
            Row(
              children: [
                Text(
                  '${_itemProcessors.length} item(s) to process',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveWeights,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isSaving ? 'Processing...' : 'Complete Processing'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D5016),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceItemCard(InvoiceItemProcessor processor) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with original description
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D5016).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Invoice Item',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D5016),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    processor.originalDescription,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Invoice details
            Row(
              children: [
                Expanded(
                  child: _buildInfoChip(
                    'Quantity',
                    '${processor.quantity} ${processor.unit}',
                    Icons.inventory,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildInfoChip(
                    'Unit Price',
                    'R${processor.unitPrice.toStringAsFixed(2)}',
                    Icons.attach_money,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildInfoChip(
                    'Line Total',
                    'R${processor.lineTotal.toStringAsFixed(2)}',
                    Icons.receipt,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Weight input section
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.scale, color: Color(0xFF2D5016), size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Actual Weight (kg):',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: processor.weightController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            hintText: 'Enter weight',
                            border: const OutlineInputBorder(),
                            suffixText: 'kg',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            errorText: _getWeightError(processor.weightController.text),
                          ),
                          onChanged: (value) {
                            setState(() {}); // Trigger rebuild
                          },
                        ),
                      ),
                    ],
                  ),
                  if (processor.hasValidWeight) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calculate, color: Colors.green[700], size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Price per kg: R${processor.calculatedPricePerKg!.toStringAsFixed(2)}/kg',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Product matching section
            Row(
              children: [
                const Icon(Icons.link, color: Color(0xFF2D5016), size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Product Matching:',
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                ),
                const Spacer(),
                if (processor.hasValidWeight) ...[
                  OutlinedButton.icon(
                    onPressed: () => _getProductSuggestions(processor.itemId),
                    icon: const Icon(Icons.search, size: 16),
                    label: const Text('Get Suggestions'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2D5016),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _addProductMatch(processor.itemId),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Manual'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2D5016),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),

            // Product matches
            if (processor.productMatches.isEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        processor.hasValidWeight
                            ? 'Click "Get Suggestions" to find matching products'
                            : 'Enter weight first to enable product matching',
                        style: TextStyle(color: Colors.orange[700]),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              ...processor.productMatches.asMap().entries.map((entry) {
                final index = entry.key;
                final match = entry.value;
                return _buildProductMatchCard(processor, match, index);
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProductMatchCard(InvoiceItemProcessor processor, ProductMatch match, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: match.isSelected ? Colors.green[50] : Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: match.isSelected ? Colors.green[300]! : Colors.grey[300]!,
          width: match.isSelected ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product selection header
          Row(
            children: [
              Checkbox(
                value: match.isSelected,
                onChanged: (value) {
                  setState(() {
                    match.isSelected = value ?? false;
                  });
                },
                activeColor: const Color(0xFF2D5016),
              ),
              Expanded(
                child: Text(
                  match.product.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: match.isSelected ? Colors.green[700] : Colors.grey[700],
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _removeProductMatch(processor.itemId, index),
                icon: const Icon(Icons.close, size: 16),
                color: Colors.red,
              ),
            ],
          ),

          if (match.isSelected) ...[
            const SizedBox(height: 8),
            
            // Pricing strategy
            Row(
              children: [
                const Text('Pricing: ', style: TextStyle(fontWeight: FontWeight.w500)),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: match.pricingStrategy,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'per_kg', child: Text('Per kg (loose/bulk)')),
                      DropdownMenuItem(value: 'per_package', child: Text('Per package (as delivered)')),
                      DropdownMenuItem(value: 'per_unit', child: Text('Per unit (each, bunch, head)')),
                    ],
                    onChanged: (value) {
                      // Note: This would require updating the ProductMatch class to be mutable
                      // For now, we'll handle this in the save logic
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Quantity and package size
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Quantity:', style: TextStyle(fontWeight: FontWeight.w500)),
                      TextField(
                        controller: match.quantityController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: '1',
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (match.pricingStrategy == 'per_package') ...[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Package Size (kg):', style: TextStyle(fontWeight: FontWeight.w500)),
                        TextField(
                          controller: match.packageSizeController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: '5.0',
                            suffixText: 'kg',
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String? _getWeightError(String weightText) {
    if (weightText.isEmpty) return null;
    
    final weight = double.tryParse(weightText);
    if (weight == null) {
      return 'Invalid number';
    }
    if (weight <= 0) {
      return 'Weight must be positive';
    }
    return null;
  }
}
