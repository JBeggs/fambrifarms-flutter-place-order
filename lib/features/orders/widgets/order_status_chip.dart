import 'package:flutter/material.dart';

class OrderStatusChip extends StatelessWidget {
  final String status;

  const OrderStatusChip({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final statusInfo = _getStatusInfo(status);
    
    return Chip(
      label: Text(
        statusInfo.label,
        style: TextStyle(
          color: statusInfo.textColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      backgroundColor: statusInfo.backgroundColor,
      side: BorderSide(
        color: statusInfo.borderColor,
        width: 1,
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  _StatusInfo _getStatusInfo(String status) {
    switch (status) {
      case 'received':
        return _StatusInfo(
          label: 'Received',
          backgroundColor: Colors.blue.shade50,
          textColor: Colors.blue.shade700,
          borderColor: Colors.blue.shade200,
        );
      case 'parsed':
        return _StatusInfo(
          label: 'AI Parsed',
          backgroundColor: Colors.purple.shade50,
          textColor: Colors.purple.shade700,
          borderColor: Colors.purple.shade200,
        );
      case 'confirmed':
        return _StatusInfo(
          label: 'Confirmed',
          backgroundColor: Colors.green.shade50,
          textColor: Colors.green.shade700,
          borderColor: Colors.green.shade200,
        );
      case 'po_sent':
        return _StatusInfo(
          label: 'PO Sent',
          backgroundColor: Colors.orange.shade50,
          textColor: Colors.orange.shade700,
          borderColor: Colors.orange.shade200,
        );
      case 'po_confirmed':
        return _StatusInfo(
          label: 'PO Confirmed',
          backgroundColor: Colors.teal.shade50,
          textColor: Colors.teal.shade700,
          borderColor: Colors.teal.shade200,
        );
      case 'delivered':
        return _StatusInfo(
          label: 'Delivered',
          backgroundColor: Colors.green.shade100,
          textColor: Colors.green.shade800,
          borderColor: Colors.green.shade300,
        );
      case 'cancelled':
        return _StatusInfo(
          label: 'Cancelled',
          backgroundColor: Colors.red.shade50,
          textColor: Colors.red.shade700,
          borderColor: Colors.red.shade200,
        );
      default:
        return _StatusInfo(
          label: status.toUpperCase(),
          backgroundColor: Colors.grey.shade50,
          textColor: Colors.grey.shade700,
          borderColor: Colors.grey.shade200,
        );
    }
  }
}

class _StatusInfo {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final Color borderColor;

  const _StatusInfo({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    required this.borderColor,
  });
}
