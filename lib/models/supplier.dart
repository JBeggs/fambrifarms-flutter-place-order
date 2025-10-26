import 'package:flutter/material.dart';

class Supplier {
  final int id;
  final String name;
  final String? description;
  final String email;
  final String phone;
  final String? address;
  final String supplierType;
  final bool isActive;
  final DateTime? lastOrderDate;
  final double totalOrderValue;
  final int totalOrders;
  final List<SalesRep> salesReps;
  final List<String> specialties;
  final SupplierMetrics? metrics;

  const Supplier({
    required this.id,
    required this.name,
    this.description,
    required this.email,
    required this.phone,
    this.address,
    required this.supplierType,
    this.isActive = true,
    this.lastOrderDate,
    this.totalOrderValue = 0.0,
    this.totalOrders = 0,
    this.salesReps = const [],
    this.specialties = const [],
    this.metrics,
  });

  factory Supplier.fromJson(Map<String, dynamic> json) {
    return Supplier(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'],
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      address: json['address'],
      supplierType: json['supplier_type'] ?? 'external',
      isActive: json['is_active'] ?? true,
      lastOrderDate: json['last_order_date'] != null 
          ? DateTime.parse(json['last_order_date']) 
          : null,
      totalOrderValue: (json['total_order_value'] ?? 0.0).toDouble(),
      totalOrders: json['total_orders'] ?? 0,
      salesReps: json['sales_reps'] != null 
          ? (json['sales_reps'] as List).map((rep) => SalesRep.fromJson(rep)).toList()
          : [],
      specialties: json['specialties'] != null 
          ? List<String>.from(json['specialties'])
          : [],
      metrics: json['metrics'] != null 
          ? SupplierMetrics.fromJson(json['metrics'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'email': email,
      'phone': phone,
      'address': address,
      'supplier_type': supplierType,
      'is_active': isActive,
      'last_order_date': lastOrderDate?.toIso8601String(),
      'total_order_value': totalOrderValue,
      'total_orders': totalOrders,
      'sales_reps': salesReps.map((rep) => rep.toJson()).toList(),
      'specialties': specialties,
      'metrics': metrics?.toJson(),
    };
  }

  // Display helpers
  String get displayName => name;
  String get supplierTypeDisplay {
    switch (supplierType.toLowerCase()) {
      case 'internal':
        return 'Internal Farm';
      case 'external':
        return 'External Supplier';
      case 'wholesale':
        return 'Wholesale';
      case 'retail':
        return 'Retail';
      default:
        return supplierType;
    }
  }

  String get statusDisplay => isActive ? 'Active' : 'Inactive';
  
  String get initials {
    final words = displayName.split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    } else if (words.isNotEmpty) {
      return words[0].substring(0, 1).toUpperCase();
    }
    return 'S';
  }

  Color get supplierTypeColor {
    switch (supplierType.toLowerCase()) {
      case 'internal':
        return const Color(0xFF2D5016); // Farm green
      case 'external':
        return const Color(0xFF3498DB); // Blue
      case 'wholesale':
        return const Color(0xFF9B59B6); // Purple
      case 'retail':
        return const Color(0xFFE67E22); // Orange
      default:
        return Colors.grey;
    }
  }

  String get supplierTypeEmoji {
    switch (supplierType.toLowerCase()) {
      case 'internal':
        return '🏠';
      case 'external':
        return '🚚';
      case 'wholesale':
        return '📦';
      case 'retail':
        return '🏪';
      default:
        return '🏢';
    }
  }

  // Business logic helpers
  bool get isRecentSupplier {
    if (lastOrderDate == null) return false;
    final daysSinceLastOrder = DateTime.now().difference(lastOrderDate!).inDays;
    return daysSinceLastOrder <= 30;
  }

  String get orderFrequency {
    if (totalOrders == 0) return 'No orders';
    if (totalOrders >= 50) return 'Very High';
    if (totalOrders >= 20) return 'High';
    if (totalOrders >= 10) return 'Medium';
    return 'Low';
  }

  String get specialtiesDisplay {
    if (specialties.isEmpty) return 'General supplies';
    return specialties.join(', ');
  }

  SalesRep? get primarySalesRep {
    if (salesReps.isEmpty) return null;
    try {
      return salesReps.firstWhere((rep) => rep.isPrimary);
    } catch (e) {
      return salesReps.first;
    }
  }

  // Search helpers
  bool matchesSearch(String query) {
    final lowerQuery = query.toLowerCase();
    return name.toLowerCase().contains(lowerQuery) ||
           email.toLowerCase().contains(lowerQuery) ||
           phone.contains(query) ||
           (description?.toLowerCase().contains(lowerQuery) ?? false) ||
           specialties.any((specialty) => specialty.toLowerCase().contains(lowerQuery)) ||
           salesReps.any((rep) => rep.matchesSearch(query));
  }

  @override
  String toString() => 'Supplier(name: $name, type: $supplierType)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Supplier &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  Supplier copyWith({
    int? id,
    String? name,
    String? description,
    String? email,
    String? phone,
    String? address,
    String? supplierType,
    bool? isActive,
    DateTime? lastOrderDate,
    double? totalOrderValue,
    int? totalOrders,
    List<SalesRep>? salesReps,
    List<String>? specialties,
    SupplierMetrics? metrics,
  }) {
    return Supplier(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      supplierType: supplierType ?? this.supplierType,
      isActive: isActive ?? this.isActive,
      lastOrderDate: lastOrderDate ?? this.lastOrderDate,
      totalOrderValue: totalOrderValue ?? this.totalOrderValue,
      totalOrders: totalOrders ?? this.totalOrders,
      salesReps: salesReps ?? this.salesReps,
      specialties: specialties ?? this.specialties,
      metrics: metrics ?? this.metrics,
    );
  }
}

class SalesRep {
  final int id;
  final String name;
  final String email;
  final String phone;
  final String? position;
  final bool isPrimary;
  final String? notes;

  const SalesRep({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.position,
    this.isPrimary = false,
    this.notes,
  });

  factory SalesRep.fromJson(Map<String, dynamic> json) {
    return SalesRep(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      position: json['position'],
      isPrimary: json['is_primary'] ?? false,
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'position': position,
      'is_primary': isPrimary,
      'notes': notes,
    };
  }

  String get displayName => name;
  String get displayPosition => position ?? 'Sales Representative';
  
  bool matchesSearch(String query) {
    final lowerQuery = query.toLowerCase();
    return name.toLowerCase().contains(lowerQuery) ||
           email.toLowerCase().contains(lowerQuery) ||
           phone.contains(query) ||
           (position?.toLowerCase().contains(lowerQuery) ?? false);
  }

  @override
  String toString() => 'SalesRep(name: $name, email: $email)';
}

class SupplierMetrics {
  final double averageLeadTime;
  final double onTimeDeliveryRate;
  final double qualityRating;
  final double priceCompetitiveness;
  final int totalProducts;
  final DateTime? lastMetricsUpdate;

  const SupplierMetrics({
    required this.averageLeadTime,
    required this.onTimeDeliveryRate,
    required this.qualityRating,
    required this.priceCompetitiveness,
    required this.totalProducts,
    this.lastMetricsUpdate,
  });

  factory SupplierMetrics.fromJson(Map<String, dynamic> json) {
    return SupplierMetrics(
      averageLeadTime: (json['average_lead_time'] ?? 0.0).toDouble(),
      onTimeDeliveryRate: (json['on_time_delivery_rate'] ?? 0.0).toDouble(),
      qualityRating: (json['quality_rating'] ?? 0.0).toDouble(),
      priceCompetitiveness: (json['price_competitiveness'] ?? 0.0).toDouble(),
      totalProducts: json['total_products'] ?? 0,
      lastMetricsUpdate: json['last_metrics_update'] != null 
          ? DateTime.parse(json['last_metrics_update']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'average_lead_time': averageLeadTime,
      'on_time_delivery_rate': onTimeDeliveryRate,
      'quality_rating': qualityRating,
      'price_competitiveness': priceCompetitiveness,
      'total_products': totalProducts,
      'last_metrics_update': lastMetricsUpdate?.toIso8601String(),
    };
  }

  String get leadTimeDisplay => '${averageLeadTime.toStringAsFixed(1)} days';
  String get deliveryRateDisplay => '${(onTimeDeliveryRate * 100).toStringAsFixed(1)}%';
  String get qualityRatingDisplay => '${qualityRating.toStringAsFixed(1)}/5.0';
  String get competitivenessDisplay => '${(priceCompetitiveness * 100).toStringAsFixed(1)}%';
}

// Supplier type enum for filtering
enum SupplierType {
  all('All Suppliers', '🏢'),
  internal('Internal Farm', '🏠'),
  external('External', '🚚'),
  wholesale('Wholesale', '📦'),
  retail('Retail', '🏪');

  const SupplierType(this.displayName, this.emoji);
  
  final String displayName;
  final String emoji;
  
  String get fullDisplay => '$emoji $displayName';
}

