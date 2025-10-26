import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/api_service.dart';

class EditBufferDialog extends StatefulWidget {
  final Map<String, dynamic> buffer;
  final VoidCallback? onUpdated;

  const EditBufferDialog({
    super.key,
    required this.buffer,
    this.onUpdated,
  });

  @override
  State<EditBufferDialog> createState() => _EditBufferDialogState();
}

class _EditBufferDialogState extends State<EditBufferDialog> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();
  
  late TextEditingController _spoilageRateController;
  late TextEditingController _cuttingWasteRateController;
  late TextEditingController _qualityRejectionRateController;
  late TextEditingController _marketPackSizeController;
  late TextEditingController _peakSeasonMultiplierController;
  
  String _marketPackUnit = 'kg';
  bool _isSeasonal = false;
  List<int> _peakSeasonMonths = [];
  bool _isLoading = false;

  List<Map<String, dynamic>> _units = [];
  final List<String> _monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadUnits();
  }

  Future<void> _loadUnits() async {
    try {
      final units = ApiService.getFormOptions('units_of_measure');
      setState(() {
        _units = units;
      });
    } catch (e) {
      // Fallback to hardcoded units if API fails
      setState(() {
        _units = [
          {'name': 'kg', 'display_name': 'Kilogram'},
          {'name': 'g', 'display_name': 'Gram'},
          {'name': 'piece', 'display_name': 'Piece'},
          {'name': 'each', 'display_name': 'Each'},
          {'name': 'head', 'display_name': 'Head'},
          {'name': 'bunch', 'display_name': 'Bunch'},
          {'name': 'box', 'display_name': 'Box'},
          {'name': 'bag', 'display_name': 'Bag'},
          {'name': 'punnet', 'display_name': 'Punnet'},
          {'name': 'packet', 'display_name': 'Packet'},
          {'name': 'crate', 'display_name': 'Crate'},
          {'name': 'tray', 'display_name': 'Tray'},
          {'name': 'bundle', 'display_name': 'Bundle'},
          {'name': 'L', 'display_name': 'Liter'},
          {'name': 'ml', 'display_name': 'Milliliter'},
        ];
      });
    }
  }

  void _initializeControllers() {
    _spoilageRateController = TextEditingController(
      text: _parseDouble(widget.buffer['spoilage_rate'], 0.15).toString()
    );
    _cuttingWasteRateController = TextEditingController(
      text: _parseDouble(widget.buffer['cutting_waste_rate'], 0.10).toString()
    );
    _qualityRejectionRateController = TextEditingController(
      text: _parseDouble(widget.buffer['quality_rejection_rate'], 0.05).toString()
    );
    _marketPackSizeController = TextEditingController(
      text: _parseDouble(widget.buffer['market_pack_size'], 5.0).toString()
    );
    _peakSeasonMultiplierController = TextEditingController(
      text: _parseDouble(widget.buffer['peak_season_buffer_multiplier'], 1.5).toString()
    );
    
    _marketPackUnit = widget.buffer['market_pack_unit'] ?? 'kg';
    _isSeasonal = widget.buffer['is_seasonal'] ?? false;
    _peakSeasonMonths = List<int>.from(widget.buffer['peak_season_months'] ?? []);
  }

  // Helper method to safely parse double values from API responses
  double _parseDouble(dynamic value, double defaultValue) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? defaultValue;
    }
    return defaultValue;
  }

  @override
  void dispose() {
    _spoilageRateController.dispose();
    _cuttingWasteRateController.dispose();
    _qualityRejectionRateController.dispose();
    _marketPackSizeController.dispose();
    _peakSeasonMultiplierController.dispose();
    super.dispose();
  }

  Future<void> _saveBuffer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final bufferData = {
        'spoilage_rate': double.parse(_spoilageRateController.text),
        'cutting_waste_rate': double.parse(_cuttingWasteRateController.text),
        'quality_rejection_rate': double.parse(_qualityRejectionRateController.text),
        'market_pack_size': double.parse(_marketPackSizeController.text),
        'market_pack_unit': _marketPackUnit,
        'is_seasonal': _isSeasonal,
        'peak_season_months': _peakSeasonMonths,
        'peak_season_buffer_multiplier': double.parse(_peakSeasonMultiplierController.text),
      };

      await _apiService.updateProcurementBuffer(
        widget.buffer['product_id'] ?? widget.buffer['product']['id'],
        bufferData,
      );

      if (mounted) {
        Navigator.of(context).pop();
        widget.onUpdated?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Buffer settings updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating buffer: $e'),
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

  @override
  Widget build(BuildContext context) {
    final productName = widget.buffer['product_name'] ?? widget.buffer['product']?['name'] ?? 'Unknown Product';
    
    return Dialog(
      child: Container(
        width: 600,
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
                  const Icon(Icons.tune, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Edit Buffer Settings',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          productName,
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
                      // Wastage Rates Section
                      const Text(
                        'Wastage Rates',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _spoilageRateController,
                              decoration: const InputDecoration(
                                labelText: 'Spoilage Rate',
                                hintText: '0.15 (15%)',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                              ],
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'Required';
                                final rate = double.tryParse(value);
                                if (rate == null || rate < 0 || rate > 1) {
                                  return 'Enter a value between 0 and 1';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _cuttingWasteRateController,
                              decoration: const InputDecoration(
                                labelText: 'Cutting Waste Rate',
                                hintText: '0.10 (10%)',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                              ],
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'Required';
                                final rate = double.tryParse(value);
                                if (rate == null || rate < 0 || rate > 1) {
                                  return 'Enter a value between 0 and 1';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 12),
                      
                      TextFormField(
                        controller: _qualityRejectionRateController,
                        decoration: const InputDecoration(
                          labelText: 'Quality Rejection Rate',
                          hintText: '0.05 (5%)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Required';
                          final rate = double.tryParse(value);
                          if (rate == null || rate < 0 || rate > 1) {
                            return 'Enter a value between 0 and 1';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Market Pack Settings
                      const Text(
                        'Market Pack Settings',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _marketPackSizeController,
                              decoration: const InputDecoration(
                                labelText: 'Market Pack Size',
                                hintText: '5.0',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                              ],
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'Required';
                                final size = double.tryParse(value);
                                if (size == null || size <= 0) {
                                  return 'Enter a positive number';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _marketPackUnit,
                              decoration: const InputDecoration(
                                labelText: 'Unit',
                                border: OutlineInputBorder(),
                              ),
                              items: _units.map((unit) => DropdownMenuItem<String>(
                                value: unit['name'],
                                child: Text(unit['display_name'] ?? unit['name']),
                              )).toList(),
                              onChanged: (value) {
                                setState(() => _marketPackUnit = value!);
                              },
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Seasonal Settings
                      const Text(
                        'Seasonal Settings',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      SwitchListTile(
                        title: const Text('Seasonal Product'),
                        subtitle: const Text('Enable seasonal buffer adjustments'),
                        value: _isSeasonal,
                        onChanged: (value) {
                          setState(() => _isSeasonal = value);
                        },
                      ),
                      
                      if (_isSeasonal) ...[
                        const SizedBox(height: 12),
                        
                        TextFormField(
                          controller: _peakSeasonMultiplierController,
                          decoration: const InputDecoration(
                            labelText: 'Peak Season Buffer Multiplier',
                            hintText: '1.5',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Required';
                            final multiplier = double.tryParse(value);
                            if (multiplier == null || multiplier <= 0) {
                              return 'Enter a positive number';
                            }
                            return null;
                          },
                        ),
                        
                        const SizedBox(height: 12),
                        
                        const Text('Peak Season Months:'),
                        const SizedBox(height: 8),
                        
                        Wrap(
                          spacing: 8,
                          children: List.generate(12, (index) {
                            final monthIndex = index + 1;
                            final isSelected = _peakSeasonMonths.contains(monthIndex);
                            
                            return FilterChip(
                              label: Text(_monthNames[index]),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _peakSeasonMonths.add(monthIndex);
                                  } else {
                                    _peakSeasonMonths.remove(monthIndex);
                                  }
                                  _peakSeasonMonths.sort();
                                });
                              },
                            );
                          }),
                        ),
                      ],
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
                    onPressed: _isLoading ? null : _saveBuffer,
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
}
