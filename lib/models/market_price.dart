import 'package:flutter/material.dart';

class MarketPrice {
  final int id;
  final String supplierName;
  final DateTime invoiceDate;
  final String invoiceReference;
  final String productName;
  final int? matchedProduct;
  final String? matchedProductName;
  final double unitPriceExclVat;
  final double vatAmount;
  final double unitPriceInclVat;
  final String quantityUnit;
  final double vatPercentage;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  MarketPrice({
    required this.id,
    required this.supplierName,
    required this.invoiceDate,
    required this.invoiceReference,
    required this.productName,
    this.matchedProduct,
    this.matchedProductName,
    required this.unitPriceExclVat,
    required this.vatAmount,
    required this.unitPriceInclVat,
    required this.quantityUnit,
    required this.vatPercentage,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MarketPrice.fromJson(Map<String, dynamic> json) {
    return MarketPrice(
      id: json['id'],
      supplierName: json['supplier_name'],
      invoiceDate: DateTime.parse(json['invoice_date']),
      invoiceReference: json['invoice_reference'] ?? '',
      productName: json['product_name'],
      matchedProduct: json['matched_product'],
      matchedProductName: json['matched_product_name'],
      unitPriceExclVat: double.parse(json['unit_price_excl_vat'].toString()),
      vatAmount: double.parse(json['vat_amount'].toString()),
      unitPriceInclVat: double.parse(json['unit_price_incl_vat'].toString()),
      quantityUnit: json['quantity_unit'],
      vatPercentage: double.parse(json['vat_percentage'].toString()),
      isActive: json['is_active'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  String get formattedPrice => 'R${unitPriceInclVat.toStringAsFixed(2)}';
  String get formattedDate => '${invoiceDate.day}/${invoiceDate.month}/${invoiceDate.year}';
}

class MarketVolatilityData {
  final String productName;
  final double minPrice;
  final double maxPrice;
  final double volatilityPercentage;
  final String volatilityLevel;
  final int affectedCustomers;
  final int pricePoints;

  MarketVolatilityData({
    required this.productName,
    required this.minPrice,
    required this.maxPrice,
    required this.volatilityPercentage,
    required this.volatilityLevel,
    required this.affectedCustomers,
    required this.pricePoints,
  });

  factory MarketVolatilityData.fromJson(Map<String, dynamic> json) {
    return MarketVolatilityData(
      productName: json['product_name'],
      minPrice: double.parse(json['min_price'].toString()),
      maxPrice: double.parse(json['max_price'].toString()),
      volatilityPercentage: double.parse(json['volatility_percentage'].toString()),
      volatilityLevel: json['volatility_level'],
      affectedCustomers: json['affected_customers'],
      pricePoints: json['price_points'],
    );
  }

  Color get volatilityColor {
    switch (volatilityLevel) {
      case 'extremely_volatile':
        return const Color(0xFFDC2626); // Red-600
      case 'highly_volatile':
        return const Color(0xFFEA580C); // Orange-600
      case 'volatile':
        return const Color(0xFFD97706); // Amber-600
      case 'stable':
        return const Color(0xFF059669); // Emerald-600
      default:
        return const Color(0xFF6B7280); // Gray-500
    }
  }

  String get volatilityDisplayName {
    switch (volatilityLevel) {
      case 'extremely_volatile':
        return 'Extremely Volatile';
      case 'highly_volatile':
        return 'Highly Volatile';
      case 'volatile':
        return 'Volatile';
      case 'stable':
        return 'Stable';
      default:
        return 'Unknown';
    }
  }

  String get formattedPriceRange => 'R${minPrice.toStringAsFixed(2)} - R${maxPrice.toStringAsFixed(2)}';
  String get formattedVolatility => '${volatilityPercentage >= 0 ? '+' : ''}${volatilityPercentage.toStringAsFixed(1)}%';
}
