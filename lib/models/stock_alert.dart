class StockAlert {
  final int id;
  final String alertType;
  final String alertTypeDisplay;
  final String? rawMaterialName;
  final String? productName;
  final String? batchNumber;
  final String message;
  final String severity;
  final String severityDisplay;
  final bool isActive;
  final bool? isAcknowledged;
  final String? acknowledgedByName;
  final DateTime? acknowledgedAt;
  final DateTime createdAt;

  StockAlert({
    required this.id,
    required this.alertType,
    required this.alertTypeDisplay,
    this.rawMaterialName,
    this.productName,
    this.batchNumber,
    required this.message,
    required this.severity,
    required this.severityDisplay,
    required this.isActive,
    this.isAcknowledged,
    this.acknowledgedByName,
    this.acknowledgedAt,
    required this.createdAt,
  });

  factory StockAlert.fromJson(Map<String, dynamic> json) {
    return StockAlert(
      id: json['id'],
      alertType: json['alert_type'],
      alertTypeDisplay: json['alert_type_display'],
      rawMaterialName: json['raw_material_name'],
      productName: json['product_name'],
      batchNumber: json['batch_number'],
      message: json['message'],
      severity: json['severity'],
      severityDisplay: json['severity_display'],
      isActive: json['is_active'],
      isAcknowledged: json['is_acknowledged'],
      acknowledgedByName: json['acknowledged_by_name'],
      acknowledgedAt: json['acknowledged_at'] != null 
          ? DateTime.parse(json['acknowledged_at']) 
          : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'alert_type': alertType,
      'alert_type_display': alertTypeDisplay,
      'raw_material_name': rawMaterialName,
      'product_name': productName,
      'batch_number': batchNumber,
      'message': message,
      'severity': severity,
      'severity_display': severityDisplay,
      'is_active': isActive,
      'is_acknowledged': isAcknowledged,
      'acknowledged_by_name': acknowledgedByName,
      'acknowledged_at': acknowledgedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get isOutOfStock => alertType == 'out_of_stock';
  bool get isLowStock => alertType == 'low_stock';
  bool get isCritical => severity == 'critical';
  bool get isHigh => severity == 'high';
}
