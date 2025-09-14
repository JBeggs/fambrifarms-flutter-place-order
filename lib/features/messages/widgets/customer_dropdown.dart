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
        companyOptions = companies.map((company) => company['display_name'] as String).toList();
        isLoading = false;
      });
    } catch (e) {
      print('Error loading companies: $e');
      // Fallback to basic list if API fails
      setState(() {
        companyOptions = [
          'Venue',
          'Debonairs', 
          'Casa Bella',
          'Mugg and Bean',
          'Wimpy',
          'T-junction',
          'Shebeen',
          'Luma',
          'Marco',
          'Maltos',
        ];
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.blue.withOpacity(0.3),
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
                : DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: widget.selectedCompany,
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
                        // Company options from database
                        ...companyOptions.map((String company) {
                          return DropdownMenuItem<String>(
                            value: company,
                            child: Text(company),
                          );
                        }).toList(),
                      ],
                      onChanged: widget.enabled ? widget.onCompanyChanged : null,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
