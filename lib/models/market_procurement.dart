import 'package:flutter/material.dart';

class MarketProcurement {
  final int id;
  final DateTime purchaseDate;
  final String marketName;
  final String receiptNumber;
  final List<MarketPurchaseItem> items;
  final double totalAmount;
  final double vatAmount;
  final double subtotal;
  final ProcurementStatus status;
  final String? notes;
  final DateTime? stockTakeDate;
  final String? stockTakeNotes;

  const MarketProcurement({
    required this.id,
    required this.purchaseDate,
    required this.marketName,
    required this.receiptNumber,
    required this.items,
    required this.totalAmount,
    required this.vatAmount,
    required this.subtotal,
    this.status = ProcurementStatus.purchased,
    this.notes,
    this.stockTakeDate,
    this.stockTakeNotes,
  });

  factory MarketProcurement.fromJson(Map<String, dynamic> json) {
    return MarketProcurement(
      id: json['id'] ?? 0,
      purchaseDate: DateTime.parse(json['purchase_date']),
      marketName: json['market_name'] ?? '',
      receiptNumber: json['receipt_number'] ?? '',
      items: (json['items'] as List?)
          ?.map((item) => MarketPurchaseItem.fromJson(item))
          .toList() ?? [],
      totalAmount: (json['total_amount'] ?? 0.0).toDouble(),
      vatAmount: (json['vat_amount'] ?? 0.0).toDouble(),
      subtotal: (json['subtotal'] ?? 0.0).toDouble(),
      status: ProcurementStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => ProcurementStatus.purchased,
      ),
      notes: json['notes'],
      stockTakeDate: json['stock_take_date'] != null 
          ? DateTime.parse(json['stock_take_date'])
          : null,
      stockTakeNotes: json['stock_take_notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'purchase_date': purchaseDate.toIso8601String(),
      'market_name': marketName,
      'receipt_number': receiptNumber,
      'items': items.map((item) => item.toJson()).toList(),
      'total_amount': totalAmount,
      'vat_amount': vatAmount,
      'subtotal': subtotal,
      'status': status.name,
      'notes': notes,
      'stock_take_date': stockTakeDate?.toIso8601String(),
      'stock_take_notes': stockTakeNotes,
    };
  }

  // Business logic helpers
  int get totalItems => items.fold(0, (sum, item) => sum + item.quantity);
  
  double get averageItemCost => items.isNotEmpty 
      ? totalAmount / items.length 
      : 0.0;
  
  String get statusDisplay {
    switch (status) {
      case ProcurementStatus.purchased:
        return 'Purchased';
      case ProcurementStatus.stockTaken:
        return 'Stock Verified';
      case ProcurementStatus.distributed:
        return 'Distributed';
      case ProcurementStatus.completed:
        return 'Completed';
    }
  }

  Color get statusColor {
    switch (status) {
      case ProcurementStatus.purchased:
        return Colors.orange;
      case ProcurementStatus.stockTaken:
        return Colors.blue;
      case ProcurementStatus.distributed:
        return Colors.purple;
      case ProcurementStatus.completed:
        return Colors.green;
    }
  }

  bool get needsStockTake => status == ProcurementStatus.purchased;
  bool get isCompleted => status == ProcurementStatus.completed;
  
  String get formattedTotal => 'R${totalAmount.toStringAsFixed(2)}';
  String get formattedSubtotal => 'R${subtotal.toStringAsFixed(2)}';
  String get formattedVat => 'R${vatAmount.toStringAsFixed(2)}';

  // Get items by category
  List<MarketPurchaseItem> getItemsByCategory(String category) {
    return items.where((item) => 
        item.category.toLowerCase() == category.toLowerCase()).toList();
  }

  // Calculate markup potential
  Map<String, dynamic> getMarkupAnalysis() {
    double totalWholesaleCost = 0.0;
    double totalRetailPotential = 0.0;
    
    for (final item in items) {
      totalWholesaleCost += item.totalCost;
      totalRetailPotential += item.estimatedRetailValue;
    }
    
    final potentialProfit = totalRetailPotential - totalWholesaleCost;
    final markupPercentage = totalWholesaleCost > 0 
        ? (potentialProfit / totalWholesaleCost) * 100 
        : 0.0;
    
    return {
      'wholesale_cost': totalWholesaleCost,
      'retail_potential': totalRetailPotential,
      'potential_profit': potentialProfit,
      'markup_percentage': markupPercentage,
    };
  }
}

class MarketPurchaseItem {
  final int id;
  final String productCode;
  final String description;
  final String category;
  final int quantity;
  final String unit;
  final double unitPrice;
  final double totalCost;
  final double vatRate;
  final String? quality;
  final int? verifiedQuantity;
  final String? verifiedQuality;
  final double? wastage;

  const MarketPurchaseItem({
    required this.id,
    required this.productCode,
    required this.description,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.totalCost,
    this.vatRate = 0.15,
    this.quality,
    this.verifiedQuantity,
    this.verifiedQuality,
    this.wastage,
  });

  factory MarketPurchaseItem.fromJson(Map<String, dynamic> json) {
    return MarketPurchaseItem(
      id: json['id'] ?? 0,
      productCode: json['product_code'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? '',
      quantity: json['quantity'] ?? 0,
      unit: json['unit'] ?? '',
      unitPrice: (json['unit_price'] ?? 0.0).toDouble(),
      totalCost: (json['total_cost'] ?? 0.0).toDouble(),
      vatRate: (json['vat_rate'] ?? 0.15).toDouble(),
      quality: json['quality'],
      verifiedQuantity: json['verified_quantity'],
      verifiedQuality: json['verified_quality'],
      wastage: json['wastage']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_code': productCode,
      'description': description,
      'category': category,
      'quantity': quantity,
      'unit': unit,
      'unit_price': unitPrice,
      'total_cost': totalCost,
      'vat_rate': vatRate,
      'quality': quality,
      'verified_quantity': verifiedQuantity,
      'verified_quality': verifiedQuality,
      'wastage': wastage,
    };
  }

  // Business logic helpers
  double get estimatedRetailValue => totalCost * 1.4; // 40% markup estimate
  
  String get formattedUnitPrice => 'R${unitPrice.toStringAsFixed(2)}';
  String get formattedTotalCost => 'R${totalCost.toStringAsFixed(2)}';
  
  bool get hasQualityIssues => verifiedQuality != null && 
      (verifiedQuality!.toLowerCase().contains('poor') || 
       verifiedQuality!.toLowerCase().contains('damaged'));
  
  bool get hasWastage => wastage != null && wastage! > 0;
  
  int get finalQuantity => verifiedQuantity ?? quantity;
  
  double get wastagePercentage => quantity > 0 && wastage != null
      ? (wastage! / quantity) * 100
      : 0.0;

  String get categoryEmoji {
    switch (category.toLowerCase()) {
      case 'vegetables':
      case 'veg':
        return '🥬';
      case 'fruits':
      case 'fruit':
        return '🍎';
      case 'herbs':
      case 'spices':
        return '🌿';
      case 'potatoes':
        return '🥔';
      case 'onions':
        return '🧅';
      case 'tomatoes':
        return '🍅';
      default:
        return '📦';
    }
  }

  // Match with existing product catalog
  double calculateOptimalRetailPrice({double targetMarkup = 1.4}) {
    return unitPrice * targetMarkup;
  }
}

enum ProcurementStatus {
  purchased,
  stockTaken,
  distributed,
  completed,
}

// Market procurement analytics
class MarketAnalytics {
  final double totalSpent;
  final int totalTrips;
  final double averageSpendPerTrip;
  final Map<String, double> categorySpending;
  final Map<String, int> categoryQuantities;
  final double totalWastage;
  final double averageMarkup;

  const MarketAnalytics({
    required this.totalSpent,
    required this.totalTrips,
    required this.averageSpendPerTrip,
    required this.categorySpending,
    required this.categoryQuantities,
    required this.totalWastage,
    required this.averageMarkup,
  });

  String get formattedTotalSpent => 'R${totalSpent.toStringAsFixed(2)}';
  String get formattedAverageSpend => 'R${averageSpendPerTrip.toStringAsFixed(2)}';
  String get formattedWastage => '${totalWastage.toStringAsFixed(1)}%';
  String get formattedMarkup => '${averageMarkup.toStringAsFixed(1)}%';

  String get topCategory => categorySpending.entries
      .reduce((a, b) => a.value > b.value ? a : b)
      .key;
}

