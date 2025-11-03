import 'package:flutter/material.dart';

class Product {
  final int id;
  final String name;
  final String? description;
  final String? sku;
  final double price;
  final String unit;
  final String department;
  final bool isActive;
  final double stockLevel;
  final double minimumStock;
  final DateTime? lastUpdated;
  final ProductPricing? pricing;
  final List<String>? aliases;

  const Product({
    required this.id,
    required this.name,
    this.description,
    this.sku,
    required this.price,
    required this.unit,
    required this.department,
    this.isActive = true,
    this.stockLevel = 0.0,
    this.minimumStock = 0.0,
    this.lastUpdated,
    this.pricing,
    this.aliases,
  });

  // Helper method to safely parse double values from API response
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  // Helper method to safely parse int values from API response
  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  // Helper method to safely parse string values from API response
  static String _parseString(dynamic value, [String defaultValue = '']) {
    if (value == null) return defaultValue;
    if (value is String) return value;
    if (value is int || value is double || value is bool) {
      return value.toString();
    }
    return defaultValue;
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] ?? 0,
      name: _parseString(json['name'], ''),
      description: _parseString(json['description']),
      sku: _parseString(json['sku']),
      price: _parseDouble(json['price'] ?? 0.0),
      unit: _parseString(json['unit'], '') != '' ? _parseString(json['unit'], '') : _parseString(json['unit_of_measure'], 'each'),
      department: _parseString(json['department_name'] ?? json['department'], 'Other'),
      isActive: json['is_active'] ?? true,
      stockLevel: _parseDouble(json['stock_level'] ?? 0.0),
      minimumStock: _parseDouble(json['minimum_stock'] ?? 0.0),
      lastUpdated: json['last_updated'] != null 
          ? DateTime.parse(json['last_updated']) 
          : null,
      pricing: json['pricing'] != null 
          ? ProductPricing.fromJson(json['pricing'])
          : null,
      aliases: json['aliases'] != null 
          ? List<String>.from(json['aliases'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'sku': sku,
      'price': price,
      'unit': unit,
      'department': department,
      'is_active': isActive,
      'stock_level': stockLevel,
      'minimum_stock': minimumStock,
      'last_updated': lastUpdated?.toIso8601String(),
      'pricing': pricing?.toJson(),
      'aliases': aliases,
    };
  }

  // Display helpers
  String get displayName => name;
  String get priceDisplay => 'R${price.toStringAsFixed(2)}';
  String get unitDisplay => unit.toLowerCase();
  String get fullPriceDisplay => '$priceDisplay per $unitDisplay';
  
  String get stockStatusDisplay {
    if (stockLevel <= 0) return 'Out of Stock';
    if (stockLevel <= minimumStock) return 'Low Stock';
    return 'In Stock';
  }

  Color get stockStatusColor {
    if (stockLevel <= 0) return const Color(0xFFE74C3C); // Red
    if (stockLevel <= minimumStock) return const Color(0xFFF39C12); // Orange
    return const Color(0xFF27AE60); // Green
  }

  // Business logic helpers
  bool get isOutOfStock => stockLevel <= 0;
  bool get isLowStock => stockLevel > 0 && stockLevel <= minimumStock;
  bool get isInStock => stockLevel > minimumStock;
  
  double get stockPercentage {
    if (minimumStock <= 0) return stockLevel > 0 ? 100.0 : 0.0;
    return (stockLevel / (minimumStock * 2)) * 100;
  }

  String get departmentDisplay {
    switch (department.toLowerCase()) {
      case 'vegetables':
        return '🥬 Vegetables';
      case 'fruits':
        return '🍎 Fruits';
      case 'herbs & spices':
      case 'herbs':
      case 'spices':
        return '🌿 Herbs & Spices';
      case 'mushrooms':
        return '🍄 Mushrooms';
      case 'specialty items':
      case 'specialty':
        return '⭐ Specialty';
      default:
        return '📦 $department';
    }
  }

  // Search helpers
  bool matchesSearch(String query) {
    final lowerQuery = query.toLowerCase();
    return name.toLowerCase().contains(lowerQuery) ||
           department.toLowerCase().contains(lowerQuery) ||
           (description?.toLowerCase().contains(lowerQuery) ?? false) ||
           (sku?.toLowerCase().contains(lowerQuery) ?? false) ||
           (aliases?.any((alias) => alias.toLowerCase().contains(lowerQuery)) ?? false);
  }

  @override
  String toString() => 'Product(name: $name, price: $price, unit: $unit)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Product &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  Product copyWith({
    int? id,
    String? name,
    String? description,
    String? sku,
    double? price,
    String? unit,
    String? department,
    bool? isActive,
    double? stockLevel,
    double? minimumStock,
    DateTime? lastUpdated,
    ProductPricing? pricing,
    List<String>? aliases,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      sku: sku ?? this.sku,
      price: price ?? this.price,
      unit: unit ?? this.unit,
      department: department ?? this.department,
      isActive: isActive ?? this.isActive,
      stockLevel: stockLevel ?? this.stockLevel,
      minimumStock: minimumStock ?? this.minimumStock,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      pricing: pricing ?? this.pricing,
      aliases: aliases ?? this.aliases,
    );
  }
}

class ProductPricing {
  final double basePrice;
  final double? wholesalePrice;
  final double? retailPrice;
  final double? premiumPrice;
  final String? priceSource;
  final DateTime? lastPriceUpdate;

  const ProductPricing({
    required this.basePrice,
    this.wholesalePrice,
    this.retailPrice,
    this.premiumPrice,
    this.priceSource,
    this.lastPriceUpdate,
  });

  factory ProductPricing.fromJson(Map<String, dynamic> json) {
    return ProductPricing(
      basePrice: Product._parseDouble(json['base_price'] ?? 0.0),
      wholesalePrice: json['wholesale_price'] != null ? Product._parseDouble(json['wholesale_price']) : null,
      retailPrice: json['retail_price'] != null ? Product._parseDouble(json['retail_price']) : null,
      premiumPrice: json['premium_price'] != null ? Product._parseDouble(json['premium_price']) : null,
      priceSource: Product._parseString(json['price_source']),
      lastPriceUpdate: json['last_price_update'] != null 
          ? DateTime.parse(json['last_price_update']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'base_price': basePrice,
      'wholesale_price': wholesalePrice,
      'retail_price': retailPrice,
      'premium_price': premiumPrice,
      'price_source': priceSource,
      'last_price_update': lastPriceUpdate?.toIso8601String(),
    };
  }

  double getPriceForSegment(String segment) {
    switch (segment.toLowerCase()) {
      case 'wholesale':
        return wholesalePrice ?? basePrice;
      case 'retail':
        return retailPrice ?? basePrice;
      case 'premium':
        return premiumPrice ?? basePrice;
      default:
        return basePrice;
    }
  }
}

// Product department enum for filtering
enum ProductDepartment {
  all('All Products', '🛒'),
  vegetables('Vegetables', '🥬'),
  fruits('Fruits', '🍎'),
  herbs('Herbs & Spices', '🌿'),
  mushrooms('Mushrooms', '🍄'),
  specialty('Specialty Items', '⭐');

  const ProductDepartment(this.displayName, this.emoji);
  
  final String displayName;
  final String emoji;
  
  String get fullDisplay => '$emoji $displayName';
}

// Product stock status enum
enum StockStatus {
  all('All Stock Levels'),
  inStock('In Stock'),
  lowStock('Low Stock'),
  outOfStock('Out of Stock');

  const StockStatus(this.displayName);
  
  final String displayName;
}
