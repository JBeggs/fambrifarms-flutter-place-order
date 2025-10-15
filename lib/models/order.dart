import 'customer.dart';
import 'pricing_rule.dart';

class Order {
  final int id;
  final String orderNumber;
  final Customer restaurant;
  final String orderDate;
  final String deliveryDate;
  final String status;
  final List<OrderItem> items;
  final String? originalMessage;
  final String? whatsappMessageId;
  final bool? parsedByAi;
  final double? subtotal;
  final double? totalAmount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Order({
    required this.id,
    required this.orderNumber,
    required this.restaurant,
    required this.orderDate,
    required this.deliveryDate,
    required this.status,
    required this.items,
    this.originalMessage,
    this.whatsappMessageId,
    this.parsedByAi,
    this.subtotal,
    this.totalAmount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    try {
      print('[DEBUG] Order.fromJson - Starting parse...');
      print('[DEBUG] Order.fromJson - JSON keys: ${json.keys.toList()}');
      
      // Handle Django API format where restaurant info is flattened
      print('[DEBUG] Order.fromJson - Creating customer...');
      final restaurant = Customer(
        id: json['restaurant'] as int,
        email: json['restaurant_email'] as String? ?? '',
        name: json['restaurant_name'] as String? ?? '',
        phone: json['restaurant_phone'] as String? ?? '',
        customerType: 'restaurant',
        isActive: true,
        profile: json['restaurant_business_name'] != null ? CustomerProfile(
          id: json['restaurant'] as int,
          businessName: json['restaurant_business_name'] as String?,
        ) : null,
      );
      print('[DEBUG] Order.fromJson - Customer created successfully');

      print('[DEBUG] Order.fromJson - Processing items...');
      final itemsList = json['items'] as List<dynamic>?;
      print('[DEBUG] Order.fromJson - Items list type: ${itemsList.runtimeType}, length: ${itemsList?.length}');
      
      final List<OrderItem> items = [];
      if (itemsList != null) {
        for (int i = 0; i < itemsList.length; i++) {
          try {
            print('[DEBUG] Order.fromJson - Processing item $i, type: ${itemsList[i].runtimeType}');
            final itemMap = Map<String, dynamic>.from(itemsList[i]);
            print('[DEBUG] Order.fromJson - Item $i converted to Map, creating OrderItem...');
            final orderItem = OrderItem.fromJson(itemMap);
            items.add(orderItem);
            print('[DEBUG] Order.fromJson - Item $i created successfully');
          } catch (e) {
            print('[ERROR] Order.fromJson - Failed to parse item $i: $e');
            print('[ERROR] Order.fromJson - Item $i data: ${itemsList[i]}');
            rethrow;
          }
        }
      }
      print('[DEBUG] Order.fromJson - All items processed successfully');

      print('[DEBUG] Order.fromJson - Creating Order object...');
      return Order(
        id: json['id'] as int,
        orderNumber: json['order_number'] as String,
        restaurant: restaurant,
        orderDate: json['order_date'] as String,
        deliveryDate: json['delivery_date'] as String,
        status: json['status'] as String,
        items: items,
        originalMessage: json['original_message'] as String?,
        whatsappMessageId: json['whatsapp_message_id'] as String?,
        parsedByAi: json['parsed_by_ai'] as bool?,
        subtotal: _parseDouble(json['subtotal']),
        totalAmount: _parseDouble(json['total_amount']),
        createdAt: DateTime.parse(json['created_at']),
        updatedAt: DateTime.parse(json['updated_at']),
      );
    } catch (e) {
      print('[ERROR] Order.fromJson - Failed: $e');
      print('[ERROR] Order.fromJson - JSON: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_number': orderNumber,
      'restaurant': restaurant.toJson(),
      'order_date': orderDate,
      'delivery_date': deliveryDate,
      'status': status,
      'items': items.map((item) => item.toJson()).toList(),
      'original_message': originalMessage,
      'whatsapp_message_id': whatsappMessageId,
      'parsed_by_ai': parsedByAi,
      'subtotal': subtotal,
      'total_amount': totalAmount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  String get statusDisplay {
    switch (status) {
      case 'received':
        return 'Received via WhatsApp';
      case 'parsed':
        return 'AI Parsed';
      case 'confirmed':
        return 'Manager Confirmed';
      case 'po_sent':
        return 'PO Sent to Sales Rep';
      case 'po_confirmed':
        return 'Sales Rep Confirmed';
      case 'delivered':
        return 'Delivered to Customer';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  bool get isValidOrderDay {
    final date = DateTime.parse(orderDate);
    final weekday = date.weekday;
    return weekday == 1 || weekday == 4; // Monday = 1, Thursday = 4
  }

  bool get isValidDeliveryDay {
    final date = DateTime.parse(deliveryDate);
    final weekday = date.weekday;
    return weekday == 2 || weekday == 3 || weekday == 5; // Tue = 2, Wed = 3, Fri = 5
  }
}

class OrderItem {
  final int id;
  final Product product;
  final double quantity;
  final String? unit;
  final double price;
  final double totalPrice;
  final String? originalText;
  final double? confidenceScore;
  final bool? manuallyCorrected;
  final String? notes;
  final double? productBasePrice;
  final PricingBreakdown? pricingBreakdown;
  final String? stockAction;
  final Map<String, dynamic>? stockResult;

  const OrderItem({
    required this.id,
    required this.product,
    required this.quantity,
    this.unit,
    required this.price,
    required this.totalPrice,
    this.originalText,
    this.confidenceScore,
    this.manuallyCorrected,
    this.notes,
    this.productBasePrice,
    this.pricingBreakdown,
    this.stockAction,
    this.stockResult,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    try {
      print('[DEBUG] OrderItem.fromJson - Starting parse...');
      print('[DEBUG] OrderItem.fromJson - JSON keys: ${json.keys.toList()}');
      
      // Handle Django API format where product info is flattened
      print('[DEBUG] OrderItem.fromJson - Creating product...');
      final product = Product(
        id: json['product'] as int,
        name: json['product_name'] as String? ?? '',
        price: _parseDouble(json['price']) ?? 0.0,
        isActive: true,
        description: json['product_description'] as String?,
        department: json['product_department'] != null 
            ? Department(
                id: 0, // We don't have the department ID
                name: json['product_department'] as String,
              )
            : null,
        unit: json['product_default_unit'] as String? ?? 'piece',
      );
      print('[DEBUG] OrderItem.fromJson - Product created successfully');

      print('[DEBUG] OrderItem.fromJson - Processing pricing breakdown...');
      PricingBreakdown? pricingBreakdown;
      if (json['pricing_breakdown'] != null) {
        print('[DEBUG] OrderItem.fromJson - pricing_breakdown type: ${json['pricing_breakdown'].runtimeType}');
        try {
          final breakdownMap = Map<String, dynamic>.from(json['pricing_breakdown']);
          print('[DEBUG] OrderItem.fromJson - Converted pricing_breakdown to Map, creating PricingBreakdown...');
          pricingBreakdown = PricingBreakdown.fromJson(breakdownMap);
          print('[DEBUG] OrderItem.fromJson - PricingBreakdown created successfully');
        } catch (e) {
          print('[ERROR] OrderItem.fromJson - Failed to parse pricing_breakdown: $e');
          print('[ERROR] OrderItem.fromJson - pricing_breakdown data: ${json['pricing_breakdown']}');
          rethrow;
        }
      }

      print('[DEBUG] OrderItem.fromJson - Creating OrderItem...');
      return OrderItem(
        id: json['id'] as int,
        product: product,
        quantity: _parseDouble(json['quantity']) ?? 0.0,
        unit: json['unit'] as String? ?? json['product_default_unit'] as String? ?? 'piece',
        price: _parseDouble(json['price']) ?? 0.0,
        totalPrice: _parseDouble(json['total_price']) ?? 0.0,
        originalText: json['original_text'] as String?,
        confidenceScore: (json['confidence_score'] as num?)?.toDouble(),
        manuallyCorrected: json['manually_corrected'] as bool?,
        notes: json['notes'] as String?,
        productBasePrice: _parseDouble(json['product_base_price']),
        pricingBreakdown: pricingBreakdown,
        stockAction: json['stock_action'] as String?,
        stockResult: json['stock_result'] as Map<String, dynamic>?,
      );
    } catch (e) {
      print('[ERROR] OrderItem.fromJson - Failed: $e');
      print('[ERROR] OrderItem.fromJson - JSON: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product': product.toJson(),
      'quantity': quantity,
      'unit': unit,
      'price': price,
      'total_price': totalPrice,
      'original_text': originalText,
      'confidence_score': confidenceScore,
      'manually_corrected': manuallyCorrected,
      'notes': notes,
      'product_base_price': productBasePrice,
      'pricing_breakdown': pricingBreakdown?.toJson(),
      'stock_action': stockAction,
      'stock_result': stockResult,
    };
  }

  String get displayQuantity {
    if (unit != null && unit!.isNotEmpty) {
      return '${quantity.toStringAsFixed(quantity.truncateToDouble() == quantity ? 0 : 1)}$unit';
    }
    return quantity.toStringAsFixed(quantity.truncateToDouble() == quantity ? 0 : 1);
  }

  // Stock reservation helper methods
  bool get hasStockReservation => stockAction != null;
  
  bool get isStockReserved => stockAction == 'reserve' && 
      stockResult != null && 
      (stockResult!['success'] as bool? ?? false);
  
  bool get isStockReservationFailed => stockAction == 'reserve' && 
      stockResult != null && 
      !(stockResult!['success'] as bool? ?? true);
  
  bool get isConvertedToBulkKg => stockAction == 'convert_to_kg';
  
  bool get isNoReserve => stockAction == 'no_reserve';
  
  String get stockStatusDisplay {
    if (stockAction == null) return '';
    
    switch (stockAction) {
      case 'reserve':
        if (stockResult != null) {
          final success = stockResult!['success'] as bool? ?? false;
          if (success) {
            return '✅ Stock Reserved';
          } else {
            final message = stockResult!['message'] as String? ?? 'Failed to reserve';
            return '❌ $message';
          }
        }
        return '⏳ Reserving...';
      case 'no_reserve':
        return '🔓 No Reservation';
      case 'convert_to_kg':
        return '🔄 Converted to Bulk Kg';
      default:
        return '';
    }
  }
}

class Product {
  final int id;
  final String name;
  final double price;
  final bool isActive;
  final String? description;
  final Department? department;
  final String unit;

  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.isActive,
    this.description,
    this.department,
    this.unit = 'piece',
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as int,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      isActive: json['is_active'] as bool,
      description: json['description'] as String?,
      department: json['department'] != null 
          ? Department.fromJson(Map<String, dynamic>.from(json['department']))
          : null,
      unit: json['unit'] as String? ?? 'piece',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'is_active': isActive,
      'description': description,
      'department': department?.toJson(),
      'unit': unit,
    };
  }
}

class Department {
  final int id;
  final String name;
  final String? description;

  const Department({
    required this.id,
    required this.name,
    this.description,
  });

  factory Department.fromJson(Map<String, dynamic> json) {
    return Department(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
    };
  }
}


// Helper function to parse string or number to double
double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}

class PricingBreakdown {
  final double basePrice;
  final double customerPrice;
  final double priceDifference;
  final double markupPercentage;
  final String customerSegment;
  final String pricingSource;
  final PricingRule? pricingRule;
  final PriceListItem? priceListItem;
  final String? error;

  const PricingBreakdown({
    required this.basePrice,
    required this.customerPrice,
    required this.priceDifference,
    required this.markupPercentage,
    required this.customerSegment,
    required this.pricingSource,
    this.pricingRule,
    this.priceListItem,
    this.error,
  });

  factory PricingBreakdown.fromJson(Map<String, dynamic> json) {
    try {
      print('[DEBUG] PricingBreakdown.fromJson - Starting parse...');
      print('[DEBUG] PricingBreakdown.fromJson - JSON keys: ${json.keys.toList()}');
      
      print('[DEBUG] PricingBreakdown.fromJson - Processing pricing_rule...');
      PricingRule? pricingRule;
      if (json['pricing_rule'] != null) {
        print('[DEBUG] PricingBreakdown.fromJson - pricing_rule type: ${json['pricing_rule'].runtimeType}');
        try {
          final ruleMap = Map<String, dynamic>.from(json['pricing_rule']);
          print('[DEBUG] PricingBreakdown.fromJson - Converted pricing_rule to Map: ${ruleMap.keys.toList()}');
          pricingRule = PricingRule.fromJson({
            'id': 0, // We don't have the full pricing rule ID in breakdown
            'name': ruleMap['name'] ?? '',
            'description': '',
            'customer_segment': ruleMap['customer_segment'] ?? '',
            'base_markup_percentage': ruleMap['base_markup_percentage'] ?? 0.0,
            'volatility_adjustment': 0.0,
            'minimum_margin_percentage': 0.0,
            'category_adjustments': {},
            'trend_multiplier': 1.0,
            'seasonal_adjustment': 0.0,
            'is_active': true,
            'effective_from': DateTime.now().toIso8601String().split('T')[0],
            'is_effective_now': true,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
            'created_by': 0,
            'created_by_name': '',
          });
          print('[DEBUG] PricingBreakdown.fromJson - PricingRule created successfully');
        } catch (e) {
          print('[ERROR] PricingBreakdown.fromJson - Failed to parse pricing_rule: $e');
          print('[ERROR] PricingBreakdown.fromJson - pricing_rule data: ${json['pricing_rule']}');
          rethrow;
        }
      }

      print('[DEBUG] PricingBreakdown.fromJson - Processing price_list_item...');
      PriceListItem? priceListItem;
      if (json['price_list_item'] != null) {
        print('[DEBUG] PricingBreakdown.fromJson - price_list_item type: ${json['price_list_item'].runtimeType}');
        try {
          final itemMap = Map<String, dynamic>.from(json['price_list_item']);
          priceListItem = PriceListItem.fromJson(itemMap);
          print('[DEBUG] PricingBreakdown.fromJson - PriceListItem created successfully');
        } catch (e) {
          print('[ERROR] PricingBreakdown.fromJson - Failed to parse price_list_item: $e');
          print('[ERROR] PricingBreakdown.fromJson - price_list_item data: ${json['price_list_item']}');
          rethrow;
        }
      }

      print('[DEBUG] PricingBreakdown.fromJson - Creating PricingBreakdown...');
      return PricingBreakdown(
        basePrice: _parseDouble(json['base_price']) ?? 0.0,
        customerPrice: _parseDouble(json['customer_price']) ?? 0.0,
        priceDifference: _parseDouble(json['price_difference']) ?? 0.0,
        markupPercentage: _parseDouble(json['markup_percentage']) ?? 0.0,
        customerSegment: json['customer_segment'] as String? ?? 'unknown',
        pricingSource: json['pricing_source'] as String? ?? 'base_price',
        pricingRule: pricingRule,
        priceListItem: priceListItem,
        error: json['error'] as String?,
      );
    } catch (e) {
      print('[ERROR] PricingBreakdown.fromJson - Failed: $e');
      print('[ERROR] PricingBreakdown.fromJson - JSON: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'base_price': basePrice,
      'customer_price': customerPrice,
      'price_difference': priceDifference,
      'markup_percentage': markupPercentage,
      'customer_segment': customerSegment,
      'pricing_source': pricingSource,
      'pricing_rule': pricingRule?.toJson(),
      'price_list_item': priceListItem?.toJson(),
      'error': error,
    };
  }

  String get markupDisplay {
    if (markupPercentage > 0) {
      return '+${markupPercentage.toStringAsFixed(1)}%';
    } else if (markupPercentage < 0) {
      return '${markupPercentage.toStringAsFixed(1)}%';
    } else {
      return 'Base Price';
    }
  }

  String get pricingSourceDisplay {
    switch (pricingSource) {
      case 'price_list':
        return 'Customer Price List';
      case 'pricing_rule':
        return 'Pricing Rule';
      case 'base_price':
      default:
        return 'Base Price';
    }
  }

  String get customerSegmentDisplay {
    // Use the same logic as PricingRule.segmentDisplayName
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
}


class PriceListItem {
  final double marketPriceExclVat;
  final double marketPriceInclVat;
  final double markupPercentage;
  final String marketPriceDate;
  final String priceListName;

  const PriceListItem({
    required this.marketPriceExclVat,
    required this.marketPriceInclVat,
    required this.markupPercentage,
    required this.marketPriceDate,
    required this.priceListName,
  });

  factory PriceListItem.fromJson(Map<String, dynamic> json) {
    return PriceListItem(
      marketPriceExclVat: _parseDouble(json['market_price_excl_vat']) ?? 0.0,
      marketPriceInclVat: _parseDouble(json['market_price_incl_vat']) ?? 0.0,
      markupPercentage: _parseDouble(json['markup_percentage']) ?? 0.0,
      marketPriceDate: json['market_price_date'] as String? ?? '',
      priceListName: json['price_list_name'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'market_price_excl_vat': marketPriceExclVat,
      'market_price_incl_vat': marketPriceInclVat,
      'markup_percentage': markupPercentage,
      'market_price_date': marketPriceDate,
      'price_list_name': priceListName,
    };
  }
}
