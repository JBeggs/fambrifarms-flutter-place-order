import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/api_service.dart';
import '../../../utils/messages_provider.dart';
import 'always_suggestions_dialog.dart';

class EnhancedProcessingResultDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> result;
  final VoidCallback? onRetry;
  final String messageId;

  const EnhancedProcessingResultDialog({
    super.key,
    required this.result,
    this.onRetry,
    required this.messageId,
  });

  @override
  ConsumerState<EnhancedProcessingResultDialog> createState() => _EnhancedProcessingResultDialogState();
}

class _EnhancedProcessingResultDialogState extends ConsumerState<EnhancedProcessingResultDialog> {
  Map<String, dynamic> _selectedCorrections = {};
  bool _isSaving = false;

  // Helper function to prevent range errors in text
  String _safeText(String text) {
    if (text.isEmpty) return '';
    // Limit text length to prevent rendering issues
    const maxLength = 200;
    if (text.length > maxLength) {
      return '${text.substring(0, maxLength)}...';
    }
    return text;
  }

  bool _hasErrors() {
    // Check for new backend format
    if (widget.result['failed_products'] != null && (widget.result['failed_products'] as List).isNotEmpty) {
      return true;
    }
    if (widget.result['parsing_failures'] != null && (widget.result['parsing_failures'] as List).isNotEmpty) {
      return true;
    }
    if (widget.result['unparseable_lines'] != null && (widget.result['unparseable_lines'] as List).isNotEmpty) {
      return true;
    }
    // Check for old format
    if (widget.result['errors'] != null && (widget.result['errors'] as List).isNotEmpty) {
      return true;
    }
    return false;
  }

  void _selectCorrection(String originalLine, Map<String, dynamic> suggestion) {
    setState(() {
      // Extract quantity and unit from the original line (e.g., "3x5kg Tomato", "CARROTS X 5 KG")
      String originalQuantity = '1'; // Default quantity
      String originalUnit = '';
      String originalProductName = originalLine;
      
      // Try to parse various formats
      final regex = RegExp(r'^(\d+)(?:x|×)?(\d+)?([a-zA-Z]+)?\s*(.+)$');
      final match = regex.firstMatch(originalLine.trim());
      
      if (match != null) {
        final firstNumber = match.group(1);
        final secondNumber = match.group(2);
        final unitPart = match.group(3);
        final productPart = match.group(4);
        
        if (secondNumber != null && unitPart != null) {
          // Format like "3x5kg Tomato" - first number is quantity, second+unit is unit
          originalQuantity = firstNumber!;
          originalUnit = '$secondNumber$unitPart';
          originalProductName = productPart ?? '';
        } else if (unitPart != null) {
          // Format like "5kg Tomato" - treat as unit with quantity 1
          originalQuantity = '1';
          originalUnit = '$firstNumber$unitPart';
          originalProductName = productPart ?? '';
        } else {
          // Format like "3 Tomato" - first number is quantity
          originalQuantity = firstNumber!;
          originalUnit = '';
          originalProductName = productPart ?? '';
        }
      } else {
        // Fallback: try to parse with spaces (e.g., "CARROTS X 5 KG")
        final originalParts = originalLine.split(' ');
        for (int i = 0; i < originalParts.length; i++) {
          if (originalParts[i].toLowerCase() == 'x' && i + 1 < originalParts.length) {
            // Found "x" followed by a number
            originalQuantity = originalParts[i + 1];
            if (i + 2 < originalParts.length) {
              originalUnit = originalParts[i + 2];
            }
            // Reconstruct the product name (everything before "x")
            originalProductName = originalParts.sublist(0, i).join(' ');
            break;
          }
        }
      }
      
      // Create the corrected line in the format the system expects
      final correctedName = suggestion['name'] ?? suggestion['product_name'] ?? '';
      final correctedUnit = suggestion['unit'] ?? originalUnit;
      final correctedLine = '$correctedName x $originalQuantity $correctedUnit';
      
      _selectedCorrections[originalLine] = {
        'original_line': originalLine,
        'original_quantity': originalQuantity,
        'original_unit': originalUnit,
        'original_product_name': originalProductName,
        'corrected_name': correctedName,
        'corrected_quantity': originalQuantity,
        'corrected_unit': correctedUnit,
        'corrected_line': correctedLine,
        'confidence': suggestion['confidence'] ?? suggestion['confidence_score'],
        'price': suggestion['price'],
        'id': suggestion['id'] ?? suggestion['product_id'],
        'corrected': true,
      };
      debugPrint('Selected correction for $originalLine: ${_selectedCorrections[originalLine]}');
    });
  }

  Widget _buildErrorsList() {
    List<Widget> errorWidgets = [];
    
    // Handle new backend format
    if (widget.result['failed_products'] != null) {
      final failedProducts = widget.result['failed_products'] as List;
      for (int i = 0; i < failedProducts.length; i++) {
        final product = failedProducts[i];
        final suggestions = product['suggestions'] as List? ?? [];
        errorWidgets.add(_buildFailedProductWithSuggestions(product, 'failed_product_$i', suggestions));
      }
    }
    
    if (widget.result['parsing_failures'] != null) {
      final parsingFailures = widget.result['parsing_failures'] as List;
      for (int i = 0; i < parsingFailures.length; i++) {
        final failure = parsingFailures[i];
        errorWidgets.add(_buildParsingFailureItem(failure, 'parsing_failure_$i'));
      }
    }
    
    if (widget.result['unparseable_lines'] != null) {
      final unparseableLines = widget.result['unparseable_lines'] as List;
      for (int i = 0; i < unparseableLines.length; i++) {
        final line = unparseableLines[i];
        errorWidgets.add(_buildUnparseableLineItem(line, 'unparseable_$i'));
      }
    }
    
    // Handle old format
    if (widget.result['errors'] != null) {
      final errors = widget.result['errors'] as List;
      for (int i = 0; i < errors.length; i++) {
        final error = errors[i];
        errorWidgets.add(_buildEnhancedErrorItem(error, i));
      }
    }
    
    return ListView(children: errorWidgets);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95, // Increased width
        height: MediaQuery.of(context).size.height * 0.95, // Increased height to 95%
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.95,
          maxHeight: MediaQuery.of(context).size.height * 0.95,
          minHeight: 400, // Minimum height to ensure usability
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.assignment_turned_in, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Message Processing Results',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(),
            
            // Results Summary
            _buildSummarySection(),
            const SizedBox(height: 16),
            
            // Errors with Enhanced Suggestions (New Backend Format)
            if (_hasErrors()) ...[
              const Text('❌ Errors Found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
              const SizedBox(height: 8),
              Expanded(
                flex: 3, // Give errors section more space
                child: _buildErrorsList(),
              ),
            ],
            
            // Warnings
            if (widget.result['warnings'] != null && (widget.result['warnings'] as List).isNotEmpty) ...[
              const Text('⚠️ Warnings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange)),
              const SizedBox(height: 8),
              Expanded(
                flex: 1, // Give warnings section some space
                child: ListView(
                  shrinkWrap: true,
                  children: (widget.result['warnings'] as List).map((warning) => _buildWarningItem(warning)).toList(),
                ),
              ),
            ],
            
            // Success Messages
            if (widget.result['orders_created'] != null) ...[
              _buildSuccessSection(),
            ],
            
            const Spacer(),
            
            // Action Buttons
            Row(
              children: [
                if (_selectedCorrections.isNotEmpty) ...[
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveCorrections,
                    icon: _isSaving 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save),
                    label: Text(_isSaving ? 'Saving...' : 'Save Corrections'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  ),
                  const SizedBox(width: 8),
                ],
                // TODO: DEPRECATED - This button is no longer needed for order messages
                // since they now go directly to suggestions. Only used for stock message retry.
                ElevatedButton.icon(
                  onPressed: _processWithSuggestions,
                  icon: const Icon(Icons.shopping_cart),
                  label: const Text('Process with Suggestions'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: widget.onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry Old Flow'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessSection() {
    final ordersCreatedData = widget.result['orders_created'];
    final count = ordersCreatedData is int ? ordersCreatedData : (ordersCreatedData as List?)?.length ?? 0;
    
    if (count > 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('✅ Orders Created', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
          const SizedBox(height: 8),
          _buildSuccessItem({
            'count': count,
            'order_numbers': widget.result['order_numbers'] as List<dynamic>? ?? [],
          }),
        ],
      );
    }
    
    return const SizedBox.shrink();
  }

  Widget _buildSummarySection() {
    // Handle new backend format
    if (widget.result['status'] != null) {
      final status = widget.result['status'] as String;
      final message = widget.result['message'] as String? ?? '';
      
      // Count errors from new format
      final failedProducts = (widget.result['failed_products'] as List?)?.length ?? 0;
      final parsingFailures = (widget.result['parsing_failures'] as List?)?.length ?? 0;
      final unparseableLines = (widget.result['unparseable_lines'] as List?)?.length ?? 0;
      final totalErrors = failedProducts + parsingFailures + unparseableLines;
      
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: status == 'failed' ? Colors.red.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: status == 'failed' ? Colors.red.withValues(alpha: 0.3) : Colors.blue.withValues(alpha: 0.3)
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: ${status.toUpperCase()}', 
                 style: TextStyle(fontWeight: FontWeight.bold, 
                 color: status == 'failed' ? Colors.red : Colors.green)),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(message, style: const TextStyle(fontSize: 12)),
            ],
            const SizedBox(height: 8),
            Text('Processed: 1 message', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('Orders Created: ${status == 'failed' ? 0 : 1}', 
                 style: const TextStyle(color: Colors.green)),
            Text('Errors: $totalErrors', style: const TextStyle(color: Colors.red)),
            if (failedProducts > 0) Text('  - Failed Products: $failedProducts', style: const TextStyle(fontSize: 12, color: Colors.red)),
            if (parsingFailures > 0) Text('  - Parsing Failures: $parsingFailures', style: const TextStyle(fontSize: 12, color: Colors.red)),
            if (unparseableLines > 0) Text('  - Unparseable Lines: $unparseableLines', style: const TextStyle(fontSize: 12, color: Colors.red)),
          ],
        ),
      );
    }
    
    // Handle old format
    final totalProcessed = widget.result['total_processed'] ?? 0;
    final ordersCreatedData = widget.result['orders_created'];
    final ordersCreated = ordersCreatedData is int ? ordersCreatedData : (ordersCreatedData as List?)?.length ?? 0;
    final errors = (widget.result['errors'] as List?)?.length ?? 0;
    final warnings = (widget.result['warnings'] as List?)?.length ?? 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Processed: $totalProcessed messages', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text('Orders Created: $ordersCreated', style: const TextStyle(color: Colors.green)),
          Text('Errors: $errors', style: const TextStyle(color: Colors.red)),
          Text('Warnings: $warnings', style: const TextStyle(color: Colors.orange)),
        ],
      ),
    );
  }

  Widget _buildEnhancedErrorItem(dynamic error, int errorIndex) {
    final failedProducts = error['details']?['failed_products'] as List? ?? [];
    final suggestions = error['details']?['suggestions'] as List? ?? [];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Error: ${error['error'] ?? 'Unknown error'}',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
          ),
          const SizedBox(height: 8),
          
          // Failed Products with Enhanced Suggestions
          if (failedProducts.isNotEmpty) ...[
            const Text('Failed Products:', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            ...failedProducts.asMap().entries.map((entry) {
              final productIndex = entry.key;
              final product = entry.value;
              final productKey = '${errorIndex}_$productIndex';
              
              return _buildFailedProductWithSuggestions(
                product, 
                productKey,
                suggestions.where((s) => s['original_name'] == product['original_name']).toList(),
              );
            }).toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildParsingFailureItem(Map<String, dynamic> failure, String failureKey) {
    final originalName = failure['original_name'] ?? 'Unknown';
    final failureReason = failure['failure_reason'] ?? 'Parsing failed';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error, color: Colors.red, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _safeText('$originalName: $failureReason'),
                  style: const TextStyle(fontSize: 12, color: Colors.red),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUnparseableLineItem(dynamic lineData, String lineKey) {
    // Handle both old format (String) and new format (Map with suggestions)
    String line;
    List<dynamic> suggestions = [];
    
    if (lineData is String) {
      line = lineData;
    } else if (lineData is Map<String, dynamic>) {
      line = lineData['original_line'] ?? '';
      suggestions = lineData['suggestions'] ?? [];
    } else {
      line = lineData.toString();
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning, color: Colors.orange, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _safeText('Could not parse: "$line"'),
                  style: const TextStyle(fontSize: 12, color: Colors.orange),
                ),
              ),
            ],
          ),
          // Only show suggestions if no correction has been made for this line
          if (suggestions.isNotEmpty && !_selectedCorrections.containsKey(line)) ...[
            const SizedBox(height: 12),
            Text('Did you mean:', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12.0,
              runSpacing: 8.0,
              children: suggestions.map<Widget>((suggestion) {
                final productName = suggestion['name'] ?? suggestion['product_name'] ?? '';
                final unit = suggestion['unit'] ?? '';
                final price = suggestion['price'] ?? 0.0;
                final confidence = suggestion['confidence'] ?? suggestion['confidence_score'] ?? 0;
                final display = '$productName (${unit}) - R${price.toStringAsFixed(2)} (${confidence.toStringAsFixed(0)}% match)';

                return SizedBox(
                  height: 48, // Fixed height for better touch targets
                  child: ChoiceChip(
                    label: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      child: Text(
                        display,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ),
                    selected: false,
                    onSelected: (selected) {
                      if (selected) {
                        _selectCorrection(line, suggestion);
                      }
                    },
                    selectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                    checkmarkColor: Theme.of(context).primaryColor,
                    side: BorderSide(
                      color: Theme.of(context).dividerColor,
                      width: 1.0,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          
          // Show confirmation message if correction has been made
          if (_selectedCorrections.containsKey(line)) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Selected: ${_selectedCorrections[line]!['corrected_name']} (${_selectedCorrections[line]!['corrected_unit']}) - R${_selectedCorrections[line]!['price'].toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedCorrections.remove(line);
                      });
                    },
                    child: const Text('Change', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFailedProductWithSuggestions(Map<String, dynamic> product, String productKey, List<dynamic> suggestions) {
    final originalName = product['original_name'] ?? 'Unknown';
    final quantity = product['quantity'] ?? 1;
    final unit = product['unit'] ?? 'piece';
    final originalLine = product['original_text'] ?? '$originalName x $quantity $unit';
    final selectedCorrection = _selectedCorrections[originalLine];  // Use originalLine as key
    
    // Hide corrected items
    if (selectedCorrection?['corrected'] == true) {
      return const SizedBox.shrink();
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: selectedCorrection != null ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: selectedCorrection != null ? Colors.green : Colors.grey.withValues(alpha: 0.3),
          width: selectedCorrection != null ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Original Product Info
          Row(
            children: [
              Icon(
                selectedCorrection != null ? Icons.check_circle : Icons.error,
                color: selectedCorrection != null ? Colors.green : Colors.red,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  selectedCorrection != null 
                    ? '✅ Corrected: ${selectedCorrection['name']} (${selectedCorrection['unit']}) - R${selectedCorrection['price'].toStringAsFixed(2)}'
                    : '$quantity${unit.isNotEmpty ? ' $unit' : ''} $originalName',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: selectedCorrection != null ? Colors.green : Colors.red,
                  ),
                ),
              ),
            ],
          ),
          
          // Suggestions (only show if not corrected)
          if (suggestions.isNotEmpty && selectedCorrection == null) ...[
            const SizedBox(height: 8),
            const Text(
              'Did you mean:',
              style: TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: suggestions.map((suggestion) => _buildSuggestionChip(
                suggestion, 
                productKey,
                isSelected: selectedCorrection?['id'] == suggestion['id'],
              )).toList(),
            ),
          ],
          
          // Quick Add Product Button (only show if not corrected)
          if (selectedCorrection == null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _showQuickAddDialog(originalName, quantity, unit),
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('Quick Add Product', style: TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(Map<String, dynamic> suggestion, String productKey, {required bool isSelected}) {
    final name = suggestion['name'] ?? 'Unknown';
    final confidence = suggestion['confidence'] ?? 0.0;
    final unit = suggestion['unit'] ?? '';
    final price = suggestion['price'] ?? 0.0;
    
    return InkWell(
      onTap: () => _selectSuggestion(suggestion, productKey),
      child: Container(
        height: 48, // Fixed height for better touch targets
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green.withValues(alpha: 0.2) : Colors.blue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.green : Colors.blue.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? Icons.check_circle : Icons.lightbulb_outline,
              color: isSelected ? Colors.green : Colors.blue,
              size: 16,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _safeText('$name${unit.isNotEmpty ? ' ($unit)' : ''} - R${price.toStringAsFixed(2)} (${confidence.toStringAsFixed(0)}% match)'),
                style: TextStyle(
                  fontSize: 13,
                  color: isSelected ? Colors.green : Colors.blue,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectSuggestion(Map<String, dynamic> suggestion, String productKey) {
    // For failed products, we need to get the original line from the product data
    // The productKey is like "failed_product_0", so we need to find the original product data
    final failedProducts = widget.result['failed_products'] as List? ?? [];
    final productIndex = int.tryParse(productKey.split('_').last) ?? 0;
    
    if (productIndex < failedProducts.length) {
      final product = failedProducts[productIndex];
      final originalName = product['original_name'] ?? '';
      final quantity = product['quantity'] ?? 1;
      final unit = product['unit'] ?? '';
      
      // Use the actual original text from the message instead of reconstructing
      final originalLine = product['original_text'] ?? '$originalName x $quantity $unit';
      
      // Create the corrected line format
      final correctedName = suggestion['name'] ?? suggestion['product_name'] ?? '';
      final correctedUnit = suggestion['unit'] ?? unit;
      final correctedLine = '$correctedName x $quantity $correctedUnit';
      
      setState(() {
        _selectedCorrections[originalLine] = {  // Use originalLine as key for backend compatibility
          'original_line': originalLine,
          'original_quantity': quantity.toString(),
          'original_unit': unit,
          'original_product_name': originalName,
          'corrected_name': correctedName,
          'corrected_quantity': quantity.toString(),
          'corrected_unit': correctedUnit,
          'corrected_line': correctedLine,
          'confidence': suggestion['confidence'] ?? suggestion['confidence_score'],
          'price': suggestion['price'],
          'id': suggestion['id'] ?? suggestion['product_id'],
          'corrected': true,
        };
      });
      
      // Immediately save the correction and hide the item
      _saveSingleCorrection(_selectedCorrections[originalLine]!, originalLine);
    }
  }

  Future<void> _saveSingleCorrection(Map<String, dynamic> suggestion, String productKey) async {
    try {
      final apiService = ref.read(apiServiceProvider);
      
      // Send single correction to backend
      final response = await apiService.updateMessageCorrections(
        widget.messageId,
        {productKey: suggestion},
      );
      
      if (response['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_safeText('Selected "${suggestion['name']}" - correction saved!')),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        
        // Hide this specific item by removing it from the error list
        _hideCorrectedItem(productKey);
        
        // Immediately reprocess the message with corrections to update the content
        try {
          debugPrint('🔄 FLUTTER: Starting immediate reprocess with single correction...');
          await apiService.reprocessMessageWithCorrections(widget.messageId);
          debugPrint('✅ FLUTTER: Immediate reprocess completed successfully');
          
          // Refresh messages to show updated content
          debugPrint('🔄 FLUTTER: Refreshing messages after single correction...');
          final messagesNotifier = ref.read(messagesProvider.notifier);
          await messagesNotifier.loadMessages();
          debugPrint('✅ FLUTTER: Messages refreshed after single correction');
        } catch (e) {
          debugPrint('❌ FLUTTER: Error during immediate reprocess: $e');
          // Don't show error to user as the correction was saved successfully
        }
      } else {
        throw Exception(response['error'] ?? 'Failed to save correction');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving correction: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _hideCorrectedItem(String productKey) {
    // This will trigger a rebuild and hide the corrected item
    setState(() {
      // Mark as corrected so it won't show in the UI
      _selectedCorrections[productKey] = {
        ..._selectedCorrections[productKey]!,
        'corrected': true,
      };
    });
  }

  Future<void> _saveCorrections() async {
    if (_selectedCorrections.isEmpty) return;
    
    setState(() {
      _isSaving = true;
    });
    
    try {
      final apiService = ref.read(apiServiceProvider);
      
      // Debug: Check what messageId we're sending
      debugPrint('🔍 SAVING CORRECTIONS:');
      debugPrint('  messageId: "${widget.messageId}"');
      debugPrint('  messageId length: ${widget.messageId.length}');
      debugPrint('  messageId is empty: ${widget.messageId.isEmpty}');
      debugPrint('  corrections: $_selectedCorrections');
      
      // Check if messageId is empty
      if (widget.messageId.isEmpty) {
        debugPrint('❌ ERROR: messageId is empty!');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: No message selected for corrections'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // Send corrections to backend
      final response = await apiService.updateMessageCorrections(
        widget.messageId,
        _selectedCorrections,
      );
      
      if (response['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Corrections saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Clear selections
        setState(() {
          _selectedCorrections.clear();
        });
        
        // Reprocess the message with corrections
        try {
          debugPrint('🔄 FLUTTER: Starting reprocess with corrections...');
          await apiService.reprocessMessageWithCorrections(widget.messageId);
          debugPrint('✅ FLUTTER: Reprocess completed successfully');
          
          // Refresh messages to show updated content
          debugPrint('🔄 FLUTTER: Refreshing messages to show updated content...');
          final messagesNotifier = ref.read(messagesProvider.notifier);
          await messagesNotifier.loadMessages();
          debugPrint('✅ FLUTTER: Messages refreshed successfully');
          
          // Close this dialog and show success
          Navigator.of(context).pop();
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Message reprocessed with corrections!'),
              backgroundColor: Colors.green,
            ),
          );
        } catch (e) {
          debugPrint('❌ FLUTTER: Error reprocessing message: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error reprocessing: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        throw Exception(response['error'] ?? 'Failed to save corrections');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving corrections: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _showQuickAddDialog(String productName, dynamic quantity, String unit) {
    // Implementation for quick add product dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quick Add Product'),
        content: Text(_safeText('Add "$productName" to the database')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Implement quick add product functionality
            },
            child: const Text('Add Product'),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningItem(dynamic warning) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Text(_safeText('⚠️ ${warning['warning'] ?? warning.toString()}')),
    );
  }

  Widget _buildSuccessItem(dynamic data) {
    final count = data['count'] as int? ?? 0;
    final orderNumbers = data['order_numbers'] as List<dynamic>? ?? [];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('✅ $count order${count == 1 ? '' : 's'} created successfully'),
          if (orderNumbers.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Order numbers: ${orderNumbers.join(', ')}',
              style: const TextStyle(fontSize: 12, color: Colors.green),
            ),
          ],
        ],
      ),
    );
  }

  // TODO: DEPRECATED - This method is no longer needed since order processing
  // now goes directly to suggestions. Only used for stock message retry flow.
  Future<void> _processWithSuggestions() async {
    try {
      // Get the messages provider
      final messagesNotifier = ref.read(messagesProvider.notifier);
      
      // Process the message with always-suggestions
      final result = await messagesNotifier.processMessageWithSuggestions(widget.messageId);
      
      if (result['status'] == 'success') {
        // Show the always-suggestions dialog
        if (mounted) {
          await showDialog(
            context: context,
            builder: (context) => AlwaysSuggestionsDialog(
              messageId: widget.messageId,
              suggestionsData: result,
            ),
          );
        }
      } else {
        // Show error
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${result['message']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error testing always-suggestions: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
