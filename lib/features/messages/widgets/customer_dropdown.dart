import 'package:flutter/material.dart';
import '../../../services/api_service.dart';

class CustomerDropdown extends StatefulWidget {
  final String? selectedCompany;
  final Function(String?) onCompanyChanged;
  final bool enabled;

  const CustomerDropdown({
    super.key,
    required this.selectedCompany,
    required this.onCompanyChanged,
    this.enabled = true,
  });

  @override
  State<CustomerDropdown> createState() => _CustomerDropdownState();
}

class _CustomerDropdownState extends State<CustomerDropdown> {
  List<String> companyOptions = [];
  bool isLoading = true;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  Future<void> _loadCompanies() async {
    try {
      final companies = await _apiService.getCompanies();
      setState(() {
        // Remove duplicates and sort
        final companyNames = companies.map((company) => company['display_name'] as String).toSet().toList();
        companyNames.sort();
        companyOptions = companyNames;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading companies: $e');
      setState(() {
        companyOptions = []; // Empty list - no hardcoded fallback
        isLoading = false;
      });
      
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load companies: ${e.toString()}'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () {
                setState(() {
                  isLoading = true;
                });
                _loadCompanies();
              },
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.blue.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.business,
            size: 16,
            color: Colors.blue.shade700,
          ),
          const SizedBox(width: 8),
          Text(
            'Customer:',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.blue.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: isLoading
                ? Text(
                    'Loading companies...',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                : companyOptions.isEmpty
                ? Text(
                    'No companies available (API error)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.red.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                : DropdownButtonHideUnderline(
                    child: Builder(
                      builder: (context) {
                        // Validate that the selected company exists in available options
                        final allValidValues = <String?>{null, '', ...companyOptions};
                        final validSelectedCompany = allValidValues.contains(widget.selectedCompany) 
                            ? widget.selectedCompany 
                            : null;
                        
                        return DropdownButton<String>(
                          value: validSelectedCompany,
                          hint: Text(
                            'Select Company',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          isExpanded: true,
                          isDense: true,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                          icon: Icon(
                            Icons.arrow_drop_down,
                            color: Colors.blue.shade700,
                            size: 20,
                          ),
                          items: [
                            // Clear selection option
                            DropdownMenuItem<String>(
                              value: null,
                              child: Text(
                                'Clear Selection',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                            // Empty string option (for messages with empty company_name)
                            DropdownMenuItem<String>(
                              value: '',
                              child: Text(
                                'No Company Selected',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                            // Company options from database (remove duplicates)
                            ...companyOptions.toSet().map((String company) {
                              return DropdownMenuItem<String>(
                                value: company,
                                child: Text(company),
                              );
                            }),
                          ],
                          onChanged: widget.enabled ? widget.onCompanyChanged : null,
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
