import 'package:flutter/material.dart';

class CustomerPriceList {
  final int id;
  final int customer;
  final String customerName;
  final int pricingRule;
  final String pricingRuleName;
  final String listName;
  final DateTime effectiveFrom;
  final DateTime effectiveUntil;
  final bool isCurrent;
  final int daysUntilExpiry;
  final DateTime basedOnMarketData;
  final String marketDataSource;
  final int totalProducts;
  final double averageMarkupPercentage;
  final double totalListValue;
  final String status;
  final DateTime? sentAt;
  final DateTime? acknowledgedAt;
  final DateTime generatedAt;
  final int generatedBy;
  final String generatedByName;
  final String notes;
  final List<CustomerPriceListItem>? items;

  CustomerPriceList({
    required this.id,
    required this.customer,
    required this.customerName,
    required this.pricingRule,
    required this.pricingRuleName,
    required this.listName,
    required this.effectiveFrom,
    required this.effectiveUntil,
    required this.isCurrent,
    required this.daysUntilExpiry,
    required this.basedOnMarketData,
    required this.marketDataSource,
    required this.totalProducts,
    required this.averageMarkupPercentage,
    required this.totalListValue,
    required this.status,
    this.sentAt,
    this.acknowledgedAt,
    required this.generatedAt,
    required this.generatedBy,
    required this.generatedByName,
    required this.notes,
    this.items,
  });

  factory CustomerPriceList.fromJson(Map<String, dynamic> json) {
    return CustomerPriceList(
      id: json['id'],
      customer: json['customer'],
      customerName: json['customer_name'],
      pricingRule: json['pricing_rule'],
      pricingRuleName: json['pricing_rule_name'],
      listName: json['list_name'],
      effectiveFrom: DateTime.parse(json['effective_from']),
      effectiveUntil: DateTime.parse(json['effective_until']),
      isCurrent: json['is_current'],
      daysUntilExpiry: json['days_until_expiry'],
      basedOnMarketData: DateTime.parse(json['based_on_market_data']),
      marketDataSource: json['market_data_source'],
      totalProducts: json['total_products'],
      averageMarkupPercentage: double.parse(json['average_markup_percentage'].toString()),
      totalListValue: double.parse(json['total_list_value'].toString()),
      status: json['status'],
      sentAt: json['sent_at'] != null ? DateTime.parse(json['sent_at']) : null,
      acknowledgedAt: json['acknowledged_at'] != null ? DateTime.parse(json['acknowledged_at']) : null,
      generatedAt: DateTime.parse(json['generated_at']),
      generatedBy: json['generated_by'],
      generatedByName: json['generated_by_name'],
      notes: json['notes'] ?? '',
      items: json['items'] != null 
          ? (json['items'] as List).map((item) => CustomerPriceListItem.fromJson(item)).toList()
          : null,
    );
  }

  Color get statusColor {
    switch (status) {
      case 'draft':
        return const Color(0xFF6B7280); // Gray
      case 'generated':
        return const Color(0xFF3B82F6); // Blue
      case 'sent':
        return const Color(0xFF8B5CF6); // Purple
      case 'acknowledged':
        return const Color(0xFF10B981); // Green
      case 'active':
        return const Color(0xFF059669); // Emerald
      case 'expired':
        return const Color(0xFFEF4444); // Red
      default:
        return const Color(0xFF6B7280);
    }
  }

  String get statusDisplayName {
    switch (status) {
      case 'draft':
        return 'Draft';
      case 'generated':
        return 'Generated';
      case 'sent':
        return 'Sent to Customer';
      case 'acknowledged':
        return 'Acknowledged';
      case 'active':
        return 'Active';
      case 'expired':
        return 'Expired';
      default:
        return status;
    }
  }

  String get formattedEffectivePeriod {
    return '${effectiveFrom.day}/${effectiveFrom.month}/${effectiveFrom.year} - ${effectiveUntil.day}/${effectiveUntil.month}/${effectiveUntil.year}';
  }

  String get formattedTotalValue => 'R${totalListValue.toStringAsFixed(2)}';
  String get formattedAverageMarkup => '${averageMarkupPercentage.toStringAsFixed(1)}%';
}

class CustomerPriceListItem {
  final int id;
  final int product;
  final String productName;
  final String? productDepartment;
  final double marketPriceExclVat;
  final double marketPriceInclVat;
  final DateTime marketPriceDate;
  final double markupPercentage;
  final double customerPriceExclVat;
  final double customerPriceInclVat;
  final double? previousPrice;
  final double priceChangePercentage;
  final double marginAmount;
  final String unitOfMeasure;
  final String productCategory;
  final bool isVolatile;
  final bool isSeasonal;
  final bool isPremium;
  final bool isPriceIncrease;
  final bool isSignificantChange;

  CustomerPriceListItem({
    required this.id,
    required this.product,
    required this.productName,
    this.productDepartment,
    required this.marketPriceExclVat,
    required this.marketPriceInclVat,
    required this.marketPriceDate,
    required this.markupPercentage,
    required this.customerPriceExclVat,
    required this.customerPriceInclVat,
    this.previousPrice,
    required this.priceChangePercentage,
    required this.marginAmount,
    required this.unitOfMeasure,
    required this.productCategory,
    required this.isVolatile,
    required this.isSeasonal,
    required this.isPremium,
    required this.isPriceIncrease,
    required this.isSignificantChange,
  });

  factory CustomerPriceListItem.fromJson(Map<String, dynamic> json) {
    return CustomerPriceListItem(
      id: json['id'],
      product: json['product'],
      productName: json['product_name'],
      productDepartment: json['product_department'],
      marketPriceExclVat: double.parse(json['market_price_excl_vat'].toString()),
      marketPriceInclVat: double.parse(json['market_price_incl_vat'].toString()),
      marketPriceDate: DateTime.parse(json['market_price_date']),
      markupPercentage: double.parse(json['markup_percentage'].toString()),
      customerPriceExclVat: double.parse(json['customer_price_excl_vat'].toString()),
      customerPriceInclVat: double.parse(json['customer_price_incl_vat'].toString()),
      previousPrice: json['previous_price'] != null ? double.parse(json['previous_price'].toString()) : null,
      priceChangePercentage: double.parse(json['price_change_percentage'].toString()),
      marginAmount: double.parse(json['margin_amount'].toString()),
      unitOfMeasure: json['unit_of_measure'],
      productCategory: json['product_category'] ?? '',
      isVolatile: json['is_volatile'],
      isSeasonal: json['is_seasonal'],
      isPremium: json['is_premium'],
      isPriceIncrease: json['is_price_increase'],
      isSignificantChange: json['is_significant_change'],
    );
  }

  String get formattedMarketPrice => 'R${marketPriceInclVat.toStringAsFixed(2)}';
  String get formattedCustomerPrice => 'R${customerPriceInclVat.toStringAsFixed(2)}';
  String get formattedMarkup => '${markupPercentage.toStringAsFixed(1)}%';
  String get formattedMargin => 'R${marginAmount.toStringAsFixed(2)}';
  String get formattedPriceChange => '${priceChangePercentage >= 0 ? '+' : ''}${priceChangePercentage.toStringAsFixed(1)}%';

  Color get priceChangeColor {
    if (priceChangePercentage > 0) {
      return const Color(0xFFEF4444); // Red for increases
    } else if (priceChangePercentage < 0) {
      return const Color(0xFF10B981); // Green for decreases
    } else {
      return const Color(0xFF6B7280); // Gray for no change
    }
  }

  List<Widget> get badges {
    List<Widget> badges = [];
    
    if (isVolatile) {
      badges.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'VOLATILE',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Color(0xFFEF4444),
          ),
        ),
      ));
    }
    
    if (isPremium) {
      badges.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF6366F1).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'PREMIUM',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Color(0xFF6366F1),
          ),
        ),
      ));
    }
    
    if (isSignificantChange) {
      badges.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'SIGNIFICANT',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Color(0xFFF59E0B),
          ),
        ),
      ));
    }
    
    return badges;
  }
}
