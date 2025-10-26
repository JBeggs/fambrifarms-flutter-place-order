import 'package:flutter/material.dart';

class PricingRule {
  final int id;
  final String name;
  final String description;
  final String customerSegment;
  final double baseMarkupPercentage;
  final double volatilityAdjustment;
  final double minimumMarginPercentage;
  final Map<String, dynamic> categoryAdjustments;
  final double trendMultiplier;
  final double seasonalAdjustment;
  final bool isActive;
  final DateTime effectiveFrom;
  final DateTime? effectiveUntil;
  final bool isEffectiveNow;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int createdBy;
  final String createdByName;

  PricingRule({
    required this.id,
    required this.name,
    required this.description,
    required this.customerSegment,
    required this.baseMarkupPercentage,
    required this.volatilityAdjustment,
    required this.minimumMarginPercentage,
    required this.categoryAdjustments,
    required this.trendMultiplier,
    required this.seasonalAdjustment,
    required this.isActive,
    required this.effectiveFrom,
    this.effectiveUntil,
    required this.isEffectiveNow,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.createdByName,
  });

  factory PricingRule.fromJson(Map<String, dynamic> json) {
    return PricingRule(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      customerSegment: json['customer_segment'],
      baseMarkupPercentage: double.parse(json['base_markup_percentage'].toString()),
      volatilityAdjustment: double.parse(json['volatility_adjustment'].toString()),
      minimumMarginPercentage: double.parse(json['minimum_margin_percentage'].toString()),
      categoryAdjustments: json['category_adjustments'] != null 
          ? Map<String, dynamic>.from(json['category_adjustments'])
          : <String, dynamic>{},
      trendMultiplier: double.parse(json['trend_multiplier'].toString()),
      seasonalAdjustment: double.parse(json['seasonal_adjustment'].toString()),
      isActive: json['is_active'],
      effectiveFrom: DateTime.parse(json['effective_from']),
      effectiveUntil: json['effective_until'] != null ? DateTime.parse(json['effective_until']) : null,
      isEffectiveNow: json['is_effective_now'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      createdBy: json['created_by'],
      createdByName: json['created_by_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'customer_segment': customerSegment,
      'base_markup_percentage': baseMarkupPercentage,
      'volatility_adjustment': volatilityAdjustment,
      'minimum_margin_percentage': minimumMarginPercentage,
      'category_adjustments': categoryAdjustments,
      'trend_multiplier': trendMultiplier,
      'seasonal_adjustment': seasonalAdjustment,
      'is_active': isActive,
      'effective_from': effectiveFrom.toIso8601String().split('T')[0],
      'effective_until': effectiveUntil?.toIso8601String().split('T')[0],
    };
  }

  String get segmentDisplayName {
    switch (customerSegment) {
      case 'premium':
        return 'Premium Restaurants';
      case 'standard':
        return 'Standard Restaurants';
      case 'budget':
        return 'Budget Cafes';
      case 'wholesale':
        return 'Wholesale Buyers';
      case 'retail':
        return 'Retail Customers';
      default:
        return customerSegment;
    }
  }

  Color get segmentColor {
    switch (customerSegment) {
      case 'premium':
        return const Color(0xFF6366F1); // Indigo
      case 'standard':
        return const Color(0xFF10B981); // Emerald
      case 'budget':
        return const Color(0xFFF59E0B); // Amber
      case 'wholesale':
        return const Color(0xFF8B5CF6); // Violet
      case 'retail':
        return const Color(0xFFEF4444); // Red
      default:
        return const Color(0xFF6B7280); // Gray
    }
  }

  double get totalMarkupForVolatile {
    return baseMarkupPercentage + volatilityAdjustment;
  }
}
