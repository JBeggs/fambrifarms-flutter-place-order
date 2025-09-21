import 'customer.dart';

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
    // Handle Django API format where restaurant info is flattened
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

    return Order(
      id: json['id'] as int,
      orderNumber: json['order_number'] as String,
      restaurant: restaurant,
      orderDate: json['order_date'] as String,
      deliveryDate: json['delivery_date'] as String,
      status: json['status'] as String,
      items: (json['items'] as List<dynamic>?)
          ?.map((item) => OrderItem.fromJson(item))
          .toList() ?? [],
      originalMessage: json['original_message'] as String?,
      whatsappMessageId: json['whatsapp_message_id'] as String?,
      parsedByAi: json['parsed_by_ai'] as bool?,
      subtotal: _parseDouble(json['subtotal']),
      totalAmount: _parseDouble(json['total_amount']),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
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
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    // Handle Django API format where product info is flattened
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
    );

    return OrderItem(
      id: json['id'] as int,
      product: product,
      quantity: _parseDouble(json['quantity']) ?? 0.0,
      unit: json['unit'] as String?,
      price: _parseDouble(json['price']) ?? 0.0,
      totalPrice: _parseDouble(json['total_price']) ?? 0.0,
      originalText: json['original_text'] as String?,
      confidenceScore: (json['confidence_score'] as num?)?.toDouble(),
      manuallyCorrected: json['manually_corrected'] as bool?,
      notes: json['notes'] as String?,
    );
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
    };
  }

  String get displayQuantity {
    if (unit != null && unit!.isNotEmpty) {
      return '${quantity.toStringAsFixed(quantity.truncateToDouble() == quantity ? 0 : 1)}$unit';
    }
    return quantity.toStringAsFixed(quantity.truncateToDouble() == quantity ? 0 : 1);
  }
}

class Product {
  final int id;
  final String name;
  final double price;
  final bool isActive;
  final String? description;
  final Department? department;

  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.isActive,
    this.description,
    this.department,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as int,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      isActive: json['is_active'] as bool,
      description: json['description'] as String?,
      department: json['department'] != null 
          ? Department.fromJson(json['department'])
          : null,
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
