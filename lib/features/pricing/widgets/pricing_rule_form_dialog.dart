import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/pricing_rule.dart';
import '../../../services/api_service.dart';
import '../../auth/karl_auth_provider.dart';

class PricingRuleFormDialog extends ConsumerStatefulWidget {
  final PricingRule? existingRule;

  const PricingRuleFormDialog({
    super.key,
    this.existingRule,
  });

  @override
  ConsumerState<PricingRuleFormDialog> createState() => _PricingRuleFormDialogState();
}

class _PricingRuleFormDialogState extends ConsumerState<PricingRuleFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _baseMarkupController = TextEditingController();
  final _volatilityAdjustmentController = TextEditingController();
  final _trendMultiplierController = TextEditingController();
  
  String _selectedSegment = '';
  bool _isActive = true;
  bool _isLoading = false;
  
  List<String> _segments = [];
  bool _segmentsLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSegments();
    if (widget.existingRule != null) {
      _populateForm(widget.existingRule!);
    } else {
      // Load defaults from API/configuration instead of hardcoding
      _loadDefaultValues();
    }
  }

  Future<void> _loadDefaultValues() async {
    try {
      // Load defaults from database-driven configuration
      _baseMarkupController.text = ApiService.defaultBaseMarkup.toString();
      _volatilityAdjustmentController.text = ApiService.defaultVolatilityAdjustment.toString();
      _trendMultiplierController.text = ApiService.defaultTrendMultiplier.toString();
    } catch (e) {
      debugPrint('Error loading default values: $e');
      // Minimal safe defaults
      _baseMarkupController.text = '1.00';
      _volatilityAdjustmentController.text = '0.00';
      _trendMultiplierController.text = '1.00';
    }
  }

  Future<void> _loadSegments() async {
    try {
      // Load customer segments from database-driven configuration
      await Future.delayed(const Duration(milliseconds: 50)); // Small delay for UI
      
      setState(() {
        _segments = ApiService.customerSegments;
        _selectedSegment = _selectedSegment.isEmpty ? 
            (_segments.isNotEmpty ? _segments.first : 'standard') : _selectedSegment;
        _segmentsLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading segments: $e');
      setState(() {
        _segments = ['standard']; // Minimal fallback
        _selectedSegment = 'standard';
        _segmentsLoading = false;
      });
    }
  }

  void _populateForm(PricingRule rule) {
    _nameController.text = rule.name;
    _selectedSegment = rule.customerSegment;
    _baseMarkupController.text = (rule.baseMarkupPercentage / 100 + 1).toString();
    _volatilityAdjustmentController.text = rule.volatilityAdjustment.toString();
    _trendMultiplierController.text = rule.trendMultiplier.toString();
    _isActive = rule.isActive;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _baseMarkupController.dispose();
    _volatilityAdjustmentController.dispose();
    _trendMultiplierController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingRule != null;
    
    return AlertDialog(
      title: Text(isEditing ? 'Edit Pricing Rule' : 'Add Pricing Rule'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Rule Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Rule Name',
                    hintText: 'e.g., Premium Customer Pricing',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a rule name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Customer Segment
                _segmentsLoading
                    ? const SizedBox(
                        height: 56,
                        child: Center(
                          child: Row(
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 12),
                              Text('Loading segments...'),
                            ],
                          ),
                        ),
                      )
                    : _segments.isEmpty
                        ? Container(
                            height: 56,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.red),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.error, color: Colors.red, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Failed to load customer segments',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          )
                        : DropdownButtonFormField<String>(
                            value: _segments.contains(_selectedSegment) ? _selectedSegment : _segments.first,
                            decoration: const InputDecoration(
                              labelText: 'Customer Segment',
                              border: OutlineInputBorder(),
                            ),
                            items: _segments.map((segment) {
                              return DropdownMenuItem(
                                value: segment,
                                child: Text(segment[0].toUpperCase() + segment.substring(1)),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedSegment = value!;
                              });
                            },
                          ),
                const SizedBox(height: 16),

                // Base Markup
                TextFormField(
                  controller: _baseMarkupController,
                  decoration: const InputDecoration(
                    labelText: 'Base Markup',
                    hintText: '1.25 (25% markup)',
                    border: OutlineInputBorder(),
                    suffixText: 'multiplier',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter base markup';
                    }
                    final markup = double.tryParse(value);
                    if (markup == null || markup <= 0) {
                      return 'Please enter a valid positive number';
                    }
                    if (markup < 1.0) {
                      return 'Markup should be >= 1.0 (no loss)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Volatility Adjustment
                TextFormField(
                  controller: _volatilityAdjustmentController,
                  decoration: const InputDecoration(
                    labelText: 'Volatility Adjustment',
                    hintText: '0.15 (15% extra for volatile items)',
                    border: OutlineInputBorder(),
                    suffixText: 'multiplier',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter volatility adjustment';
                    }
                    final adjustment = double.tryParse(value);
                    if (adjustment == null || adjustment < 0) {
                      return 'Please enter a valid non-negative number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Trend Multiplier
                TextFormField(
                  controller: _trendMultiplierController,
                  decoration: const InputDecoration(
                    labelText: 'Trend Multiplier',
                    hintText: '1.10 (10% extra for rising trends)',
                    border: OutlineInputBorder(),
                    suffixText: 'multiplier',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter trend multiplier';
                    }
                    final multiplier = double.tryParse(value);
                    if (multiplier == null || multiplier <= 0) {
                      return 'Please enter a valid positive number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Active Toggle
                SwitchListTile(
                  title: const Text('Active'),
                  subtitle: Text(_isActive ? 'Rule is currently active' : 'Rule is inactive'),
                  value: _isActive,
                  onChanged: (value) {
                    setState(() {
                      _isActive = value;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveRule,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(isEditing ? 'Update' : 'Create'),
        ),
      ],
    );
  }

  Future<void> _saveRule() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isLoading) return; // Prevent multiple submissions

    setState(() {
      _isLoading = true;
    });

    final apiService = ref.read(apiServiceProvider);
    
    try {
      
      // Check if user is authenticated
      final authState = ref.read(karlAuthProvider);
      if (authState.user == null || !apiService.isAuthenticated) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You must be logged in to create pricing rules'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      // Try to refresh token if we can, to prevent auth errors
      if (!apiService.isAuthenticated && apiService.canRefreshToken) {
        try {
          await apiService.refreshToken();
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Authentication expired. Please log out and log back in.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }
      
      final now = DateTime.now();
      final baseMarkup = double.tryParse(_baseMarkupController.text) ?? 1.25;
      final volatilityAdj = double.tryParse(_volatilityAdjustmentController.text) ?? 0.15;
      final trendMult = double.tryParse(_trendMultiplierController.text) ?? 1.10;
      
      // Calculate base markup percentage and ensure it fits within 5 digits (max 999.99)
      double baseMarkupPercentage = (baseMarkup - 1) * 100;
      if (baseMarkupPercentage > 999.99) {
        baseMarkupPercentage = 999.99;
      }
      if (baseMarkupPercentage < 0) {
        baseMarkupPercentage = 0.0;
      }
      
      final ruleData = {
        'name': _nameController.text.trim(),
        'description': _nameController.text.trim(), // Add description
        'customer_segment': _selectedSegment,
        'base_markup_percentage': double.parse(baseMarkupPercentage.toStringAsFixed(2)), // Ensure 2 decimal places
        'volatility_adjustment': double.parse(volatilityAdj.toStringAsFixed(2)),
        'minimum_margin_percentage': 10.0, // Default minimum margin
        'trend_multiplier': double.parse(trendMult.toStringAsFixed(2)),
        'seasonal_adjustment': 0.05, // Default seasonal adjustment
        'is_active': _isActive,
        'effective_from': now.toIso8601String().split('T')[0], // Today's date
        'effective_until': DateTime(now.year + 1, now.month, now.day).toIso8601String().split('T')[0], // One year from now
      };

      if (widget.existingRule != null) {
        // Update existing rule - use existing dates
        final updateData = Map<String, dynamic>.from(ruleData);
        updateData['effective_from'] = widget.existingRule!.effectiveFrom.toIso8601String().split('T')[0];
        updateData['effective_until'] = widget.existingRule!.effectiveUntil?.toIso8601String().split('T')[0] ?? DateTime(now.year + 1, now.month, now.day).toIso8601String().split('T')[0];
        
        await apiService.updatePricingRule(widget.existingRule!.id, updateData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pricing rule updated successfully!'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      } else {
        // Create new rule
        await apiService.createPricingRule(ruleData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pricing rule created successfully!'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      }

      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        // Extract clean error message
        String errorMessage = e.toString();
        if (errorMessage.startsWith('ApiException: ')) {
          errorMessage = errorMessage.substring('ApiException: '.length);
        }
        
        // Check for specific authentication errors
        if (errorMessage.contains('created_by: This field is required') || 
            errorMessage.contains('401') || 
            errorMessage.contains('Unauthorized') ||
            errorMessage.contains('Authentication error')) {
          // Try to refresh the token first
          try {
            await apiService.refreshToken();
            // If refresh succeeds, show a different message
            errorMessage = 'Authentication token refreshed. Please try again.';
          } catch (refreshError) {
            errorMessage = 'Authentication error. Please log out and log back in.';
          }
        }
        
        // Check for validation errors
        if (errorMessage.contains('base_markup_percentage')) {
          errorMessage = 'Invalid markup percentage. Please enter a value between 0% and 999%.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $errorMessage'),
            backgroundColor: const Color(0xFFEF4444),
            duration: const Duration(seconds: 5), // Show longer for errors
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
