import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';

class BusinessSettingsPage extends StatefulWidget {
  const BusinessSettingsPage({super.key});

  @override
  State<BusinessSettingsPage> createState() => _BusinessSettingsPageState();
}

class _BusinessSettingsPageState extends State<BusinessSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();
  
  // Controllers for global defaults
  late TextEditingController _defaultSpoilageRateController;
  late TextEditingController _defaultCuttingWasteRateController;
  late TextEditingController _defaultQualityRejectionRateController;
  late TextEditingController _defaultMarketPackSizeController;
  late TextEditingController _defaultPeakSeasonMultiplierController;
  
  bool _enableSeasonalAdjustments = true;
  bool _autoCreateBuffers = true;
  String _bufferCalculationMethod = 'additive';
  
  Map<String, dynamic> _departmentSettings = {};
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadBusinessSettings();
  }

  void _initializeControllers() {
    _defaultSpoilageRateController = TextEditingController();
    _defaultCuttingWasteRateController = TextEditingController();
    _defaultQualityRejectionRateController = TextEditingController();
    _defaultMarketPackSizeController = TextEditingController();
    _defaultPeakSeasonMultiplierController = TextEditingController();
  }

  @override
  void dispose() {
    _defaultSpoilageRateController.dispose();
    _defaultCuttingWasteRateController.dispose();
    _defaultQualityRejectionRateController.dispose();
    _defaultMarketPackSizeController.dispose();
    _defaultPeakSeasonMultiplierController.dispose();
    super.dispose();
  }

  Future<void> _loadBusinessSettings() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final response = await _apiService.getBusinessSettings();
      final settings = response['settings'];
      
      if (mounted) {
        setState(() {
          _defaultSpoilageRateController.text = _parseDouble(settings['default_spoilage_rate'], 0.15).toString();
          _defaultCuttingWasteRateController.text = _parseDouble(settings['default_cutting_waste_rate'], 0.10).toString();
          _defaultQualityRejectionRateController.text = _parseDouble(settings['default_quality_rejection_rate'], 0.05).toString();
          _defaultMarketPackSizeController.text = _parseDouble(settings['default_market_pack_size'], 5.0).toString();
          _defaultPeakSeasonMultiplierController.text = _parseDouble(settings['default_peak_season_multiplier'], 1.3).toString();
          
          _enableSeasonalAdjustments = settings['enable_seasonal_adjustments'] ?? true;
          _autoCreateBuffers = settings['auto_create_buffers'] ?? true;
          _bufferCalculationMethod = settings['buffer_calculation_method'] ?? 'additive';
          _departmentSettings = Map<String, dynamic>.from(settings['department_buffer_settings'] ?? {});
          
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
            content: Text('Error loading settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() {
        _isSaving = true;
      });

      final settingsData = {
        'default_spoilage_rate': double.parse(_defaultSpoilageRateController.text),
        'default_cutting_waste_rate': double.parse(_defaultCuttingWasteRateController.text),
        'default_quality_rejection_rate': double.parse(_defaultQualityRejectionRateController.text),
        'default_market_pack_size': double.parse(_defaultMarketPackSizeController.text),
        'default_peak_season_multiplier': double.parse(_defaultPeakSeasonMultiplierController.text),
        'enable_seasonal_adjustments': _enableSeasonalAdjustments,
        'auto_create_buffers': _autoCreateBuffers,
        'buffer_calculation_method': _bufferCalculationMethod,
        'department_buffer_settings': _departmentSettings,
      };

      await _apiService.updateBusinessSettings(settingsData);

      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Business settings updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Business Settings'),
        backgroundColor: const Color(0xFF2D5016),
        foregroundColor: Colors.white,
        actions: [
          if (!_isLoading)
            TextButton.icon(
              onPressed: _isSaving ? null : _saveSettings,
              icon: _isSaving 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save, color: Colors.white),
              label: Text(
                _isSaving ? 'Saving...' : 'Save',
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Global Defaults Section
                  _buildSectionHeader('Global Default Settings'),
                  const SizedBox(height: 16),
                  
                  _buildPercentageField(
                    'Default Spoilage Rate',
                    _defaultSpoilageRateController,
                    'Expected spoilage rate for new products',
                  ),
                  const SizedBox(height: 16),
                  
                  _buildPercentageField(
                    'Default Cutting Waste Rate',
                    _defaultCuttingWasteRateController,
                    'Waste from cutting/trimming for new products',
                  ),
                  const SizedBox(height: 16),
                  
                  _buildPercentageField(
                    'Default Quality Rejection Rate',
                    _defaultQualityRejectionRateController,
                    'Rate of quality rejections for new products',
                  ),
                  const SizedBox(height: 16),
                  
                  _buildNumberField(
                    'Default Market Pack Size',
                    _defaultMarketPackSizeController,
                    'Standard market pack size (kg)',
                  ),
                  const SizedBox(height: 16),
                  
                  _buildNumberField(
                    'Default Peak Season Multiplier',
                    _defaultPeakSeasonMultiplierController,
                    'Extra buffer during peak season',
                  ),
                  const SizedBox(height: 32),
                  
                  // System Settings Section
                  _buildSectionHeader('System Settings'),
                  const SizedBox(height: 16),
                  
                  SwitchListTile(
                    title: const Text('Enable Seasonal Adjustments'),
                    subtitle: const Text('Apply seasonal multipliers to buffer calculations'),
                    value: _enableSeasonalAdjustments,
                    onChanged: (value) {
                      setState(() {
                        _enableSeasonalAdjustments = value;
                      });
                    },
                    activeColor: const Color(0xFF2D5016),
                  ),
                  
                  SwitchListTile(
                    title: const Text('Auto-Create Buffers'),
                    subtitle: const Text('Automatically create procurement buffers for new products'),
                    value: _autoCreateBuffers,
                    onChanged: (value) {
                      setState(() {
                        _autoCreateBuffers = value;
                      });
                    },
                    activeColor: const Color(0xFF2D5016),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  DropdownButtonFormField<String>(
                    value: _bufferCalculationMethod,
                    decoration: const InputDecoration(
                      labelText: 'Buffer Calculation Method',
                      border: OutlineInputBorder(),
                      helperText: 'Method for calculating total buffer rates',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'additive',
                        child: Text('Additive (sum all rates)'),
                      ),
                      DropdownMenuItem(
                        value: 'multiplicative',
                        child: Text('Multiplicative (compound rates)'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _bufferCalculationMethod = value;
                        });
                      }
                    },
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Department Settings Section
                  _buildSectionHeader('Department-Specific Settings'),
                  const SizedBox(height: 16),
                  
                  if (_departmentSettings.isNotEmpty)
                    ..._departmentSettings.entries.map((entry) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          title: Text(
                            entry.key,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Spoilage: ${(_parseDouble(entry.value['spoilage_rate'], 0.15) * 100).toStringAsFixed(1)}% • '
                                'Waste: ${(_parseDouble(entry.value['cutting_waste_rate'], 0.10) * 100).toStringAsFixed(1)}% • '
                                'Quality: ${(_parseDouble(entry.value['quality_rejection_rate'], 0.05) * 100).toStringAsFixed(1)}%',
                                style: const TextStyle(fontSize: 12),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2D5016).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Total: ${((_parseDouble(entry.value['spoilage_rate'], 0.15) + _parseDouble(entry.value['cutting_waste_rate'], 0.10) + _parseDouble(entry.value['quality_rejection_rate'], 0.05)) * 100).toStringAsFixed(1)}%',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF2D5016),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Pack: ${_parseDouble(entry.value['market_pack_size'], 5.0).toStringAsFixed(1)} ${entry.value['market_pack_unit'] ?? 'kg'}',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _editDepartmentSettings(entry.key, entry.value),
                          ),
                        ),
                      );
                    }).toList()
                  else
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'No department-specific settings configured',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Color(0xFF2D5016),
      ),
    );
  }

  Widget _buildPercentageField(String label, TextEditingController controller, String helperText) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        helperText: helperText,
        suffixText: '%',
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ],
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter a value';
        }
        final doubleValue = double.tryParse(value);
        if (doubleValue == null) {
          return 'Please enter a valid number';
        }
        if (doubleValue < 0 || doubleValue > 1) {
          return 'Value must be between 0 and 1 (0% to 100%)';
        }
        return null;
      },
    );
  }

  Widget _buildNumberField(String label, TextEditingController controller, String helperText) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        helperText: helperText,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ],
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter a value';
        }
        final doubleValue = double.tryParse(value);
        if (doubleValue == null) {
          return 'Please enter a valid number';
        }
        if (doubleValue <= 0) {
          return 'Value must be greater than 0';
        }
        return null;
      },
    );
  }

  void _editDepartmentSettings(String departmentName, Map<String, dynamic> settings) {
    // TODO: Implement department-specific settings editor
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Department settings editor for $departmentName coming soon'),
        backgroundColor: Colors.orange,
      ),
    );
  }
}
