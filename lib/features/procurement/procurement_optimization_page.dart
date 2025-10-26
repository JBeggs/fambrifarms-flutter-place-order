import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/api_service.dart';
import 'widgets/supplier_recommendations_card.dart';

class ProcurementOptimizationPage extends ConsumerStatefulWidget {
  const ProcurementOptimizationPage({super.key});

  @override
  ConsumerState<ProcurementOptimizationPage> createState() => _ProcurementOptimizationPageState();
}

class _ProcurementOptimizationPageState extends ConsumerState<ProcurementOptimizationPage> {
  final _productIdController = TextEditingController();
  final _quantityController = TextEditingController();
  final _productNameController = TextEditingController();
  
  bool _isLoading = false;
  Map<String, dynamic>? _splitResult;
  String? _error;

  @override
  void dispose() {
    _productIdController.dispose();
    _quantityController.dispose();
    _productNameController.dispose();
    super.dispose();
  }

  Future<void> _calculateSupplierSplit() async {
    if (_productIdController.text.isEmpty || _quantityController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both Product ID and Quantity')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiService = ApiService();
      final result = await apiService.calculateSupplierSplit(
        productId: int.parse(_productIdController.text),
        quantity: double.parse(_quantityController.text),
      );
      
      setState(() {
        _splitResult = result;
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
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Procurement Optimization'),
        backgroundColor: const Color(0xFF2D5016),
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.analytics, color: Colors.green, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Supplier Optimization Engine',
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Intelligent procurement with Fambri-first logic',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Key Features
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildFeatureChip('🏭 Fambri-First Priority', Colors.green),
                        _buildFeatureChip('💰 Cost Optimization', Colors.blue),
                        _buildFeatureChip('📊 Multi-Supplier Splitting', Colors.orange),
                        _buildFeatureChip('⭐ Quality Tracking', Colors.purple),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Input Form
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Calculate Supplier Split',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _productIdController,
                            decoration: const InputDecoration(
                              labelText: 'Product ID',
                              hintText: 'e.g., 111',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.inventory_2),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _quantityController,
                            decoration: const InputDecoration(
                              labelText: 'Quantity',
                              hintText: 'e.g., 25',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.numbers),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    TextField(
                      controller: _productNameController,
                      decoration: const InputDecoration(
                        labelText: 'Product Name (Optional)',
                        hintText: 'e.g., Avocados (Hard)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.label),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _calculateSupplierSplit,
                        icon: _isLoading 
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.calculate),
                        label: Text(_isLoading ? 'Calculating...' : 'Calculate Optimal Split'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Results
            if (_error != null)
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Error: $_error',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_splitResult != null)
              _buildResults(),

            // Supplier Recommendations Demo
            if (_productIdController.text.isNotEmpty && _quantityController.text.isNotEmpty)
              SupplierRecommendationsCard(
                productId: int.tryParse(_productIdController.text) ?? 111,
                productName: _productNameController.text.isNotEmpty 
                  ? _productNameController.text 
                  : 'Product ${_productIdController.text}',
                quantity: double.tryParse(_quantityController.text) ?? 1,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildResults() {
    final success = _splitResult!['success'] as bool? ?? false;
    final strategy = _splitResult!['strategy'] as String? ?? 'unknown';
    final productName = _splitResult!['product_name'] as String? ?? 'Unknown Product';
    final quantityNeeded = _splitResult!['quantity_needed'] as num? ?? 0;
    final totalCost = _splitResult!['total_cost'] as num? ?? 0;
    final suppliers = _splitResult!['suppliers'] as List<dynamic>? ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  success ? Icons.check_circle : Icons.warning,
                  color: success ? Colors.green : Colors.orange,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Optimization Results',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: success ? Colors.green.shade100 : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    strategy.toUpperCase(),
                    style: TextStyle(
                      color: success ? Colors.green : Colors.orange,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Product:', style: TextStyle(color: Colors.grey.shade600)),
                      Text(productName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Quantity:', style: TextStyle(color: Colors.grey.shade600)),
                      Text('${quantityNeeded.toStringAsFixed(0)} units', style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total Cost:', style: TextStyle(color: Colors.grey.shade600)),
                      Text(
                        'R${totalCost.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Suppliers
            if (suppliers.isNotEmpty) ...[
              Text(
                'Supplier Breakdown:',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ...suppliers.map((supplier) => _buildSupplierTile(supplier as Map<String, dynamic>)),
            ],

            // Multi-supplier specific info
            if (strategy == 'multi_supplier') ...[
              const SizedBox(height: 16),
              _buildMultiSupplierInfo(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSupplierTile(Map<String, dynamic> supplier) {
    final supplierName = supplier['supplier_name'] as String? ?? 'Unknown';
    final supplierType = supplier['supplier_type'] as String? ?? 'unknown';
    final quantity = supplier['quantity'] as num? ?? 0;
    final unitPrice = supplier['unit_price'] as num? ?? 0;
    final totalCost = supplier['total_cost'] as num? ?? 0;
    final qualityRating = supplier['quality_rating'] as num? ?? 0;
    final leadTime = supplier['lead_time_days'] as num? ?? 0;
    final isFambri = supplierType == 'internal';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: isFambri ? Colors.green.shade300 : Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
        color: isFambri ? Colors.green.shade50 : Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isFambri ? Icons.home : Icons.store,
                color: isFambri ? Colors.green : Colors.orange,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  supplierName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              if (isFambri)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'FAMBRI',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${quantity.toStringAsFixed(0)} units @ R${unitPrice.toStringAsFixed(2)}',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
              Text(
                'R${totalCost.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isFambri ? Colors.green : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.star, size: 14, color: Colors.amber),
              const SizedBox(width: 4),
              Text(
                '${qualityRating.toStringAsFixed(1)}/5.0',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(width: 16),
              Icon(Icons.schedule, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                '${leadTime.toInt()} days',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMultiSupplierInfo() {
    final fulfillmentRate = _splitResult!['fulfillment_rate'] as num? ?? 0;
    final fambriPercentage = _splitResult!['fambri_percentage'] as num? ?? 0;
    final externalPercentage = _splitResult!['external_percentage'] as num? ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart, color: Colors.blue),
              const SizedBox(width: 8),
              Text(
                'Multi-Supplier Analysis',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildPercentageBar(
                  'Fambri Internal',
                  fambriPercentage.toDouble(),
                  Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildPercentageBar(
                  'External Suppliers',
                  externalPercentage.toDouble(),
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Fulfillment Rate: ${fulfillmentRate.toStringAsFixed(1)}%',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildPercentageBar(String label, double percentage, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            widthFactor: percentage / 100,
            alignment: Alignment.centerLeft,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${percentage.toStringAsFixed(1)}%',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
