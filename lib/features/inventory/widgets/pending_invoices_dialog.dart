import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/api_service.dart';
import 'weight_input_dialog.dart';

class PendingInvoicesDialog extends ConsumerStatefulWidget {
  const PendingInvoicesDialog({super.key});

  @override
  ConsumerState<PendingInvoicesDialog> createState() => _PendingInvoicesDialogState();
}

class _PendingInvoicesDialogState extends ConsumerState<PendingInvoicesDialog> {
  List<Map<String, dynamic>> _pendingInvoices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPendingInvoices();
  }

  Future<void> _loadPendingInvoices() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.getPendingInvoices();
      
      if (mounted) {
        setState(() {
          _pendingInvoices = List<Map<String, dynamic>>.from(
            response['pending_invoices'] ?? []
          );
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
            content: Text('Error loading pending invoices: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'uploaded':
        return Colors.blue;
      case 'processing':
        return Colors.orange;
      case 'extracted':
        return Colors.purple;
      case 'completed':
        return Colors.green;
      case 'error':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusDisplay(String status) {
    switch (status) {
      case 'uploaded':
        return 'Awaiting Processing';
      case 'processing':
        return 'OCR in Progress';
      case 'extracted':
        return 'Ready for Weight Input';
      case 'completed':
        return 'Ready for Stock Processing';
      case 'error':
        return 'Processing Failed';
      default:
        return status.toUpperCase();
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'uploaded':
        return Icons.upload_file;
      case 'processing':
        return Icons.hourglass_empty;
      case 'extracted':
        return Icons.scale;
      case 'completed':
        return Icons.check_circle;
      case 'error':
        return Icons.error;
      default:
        return Icons.help;
    }
  }

  void _handleInvoiceAction(Map<String, dynamic> invoice) {
    final status = invoice['status'] as String;
    final invoiceId = invoice['id'] as int;

    switch (status) {
      case 'extracted':
        // Show weight input dialog
        showDialog(
          context: context,
          builder: (context) => WeightInputDialog(invoiceId: invoiceId),
        ).then((_) => _loadPendingInvoices()); // Refresh after weight input
        break;
      case 'uploaded':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invoice is awaiting OCR processing. Please wait.'),
            backgroundColor: Colors.blue,
          ),
        );
        break;
      case 'processing':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invoice is currently being processed. Please wait.'),
            backgroundColor: Colors.orange,
          ),
        );
        break;
      case 'completed':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invoice is ready for stock processing. Use the main button.'),
            backgroundColor: Colors.green,
          ),
        );
        break;
      case 'error':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invoice processing failed: ${invoice['notes'] ?? 'Unknown error'}'),
            backgroundColor: Colors.red,
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.list, color: Color(0xFF2D5016)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Pending Invoices',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _pendingInvoices.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 64,
                                color: Colors.green,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No pending invoices',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'All invoices have been processed',
                                style: TextStyle(
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _pendingInvoices.length,
                          itemBuilder: (context, index) {
                            final invoice = _pendingInvoices[index];
                            final status = invoice['status'] as String;
                            final statusColor = _getStatusColor(status);
                            final canInteract = status == 'extracted';

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    _getStatusIcon(status),
                                    color: statusColor,
                                  ),
                                ),
                                title: Text(
                                  invoice['supplier'] as String? ?? 'Unknown Supplier',
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Date: ${invoice['invoice_date'] ?? 'Unknown'}',
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: statusColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            _getStatusDisplay(status),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: statusColor,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Uploaded: ${invoice['created_at'] ?? ''}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (invoice['notes'] != null && 
                                        (invoice['notes'] as String).isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Notes: ${invoice['notes']}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                trailing: canInteract
                                    ? ElevatedButton.icon(
                                        onPressed: () => _handleInvoiceAction(invoice),
                                        icon: const Icon(Icons.scale, size: 16),
                                        label: const Text('Add Weights'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF2D5016),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                        ),
                                      )
                                    : IconButton(
                                        onPressed: () => _handleInvoiceAction(invoice),
                                        icon: const Icon(Icons.info_outline),
                                        tooltip: 'View details',
                                      ),
                                onTap: canInteract
                                    ? () => _handleInvoiceAction(invoice)
                                    : null,
                              ),
                            );
                          },
                        ),
            ),

            // Actions
            const Divider(),
            Row(
              children: [
                Text(
                  '${_pendingInvoices.length} pending invoice(s)',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _loadPendingInvoices,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
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
}
