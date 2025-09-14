class StockUpdate {
  final int id;
  final String stockDate;
  final String orderDay;
  final Map<String, StockItem> items;
  final bool processed;
  final DateTime createdAt;
  final DateTime updatedAt;
  final WhatsAppMessageDetails? messageDetails;

  const StockUpdate({
    required this.id,
    required this.stockDate,
    required this.orderDay,
    required this.items,
    required this.processed,
    required this.createdAt,
    required this.updatedAt,
    this.messageDetails,
  });

  factory StockUpdate.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> itemsJson = json['items'] as Map<String, dynamic>;
    final Map<String, StockItem> items = {};
    
    itemsJson.forEach((key, value) {
      items[key] = StockItem.fromJson(value as Map<String, dynamic>);
    });

    return StockUpdate(
      id: json['id'] as int,
      stockDate: json['stock_date'] as String,
      orderDay: json['order_day'] as String,
      items: items,
      processed: json['processed'] as bool,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      messageDetails: json['message_details'] != null
          ? WhatsAppMessageDetails.fromJson(json['message_details'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> itemsJson = {};
    items.forEach((key, value) {
      itemsJson[key] = value.toJson();
    });

    return {
      'id': id,
      'stock_date': stockDate,
      'order_day': orderDay,
      'items': itemsJson,
      'processed': processed,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'message_details': messageDetails?.toJson(),
    };
  }

  double getAvailableQuantity(String productName) {
    final productKey = productName.toLowerCase().trim();
    for (final entry in items.entries) {
      if (entry.key.toLowerCase().trim() == productKey) {
        return entry.value.quantity;
      }
    }
    return 0.0;
  }

  String getProductUnit(String productName) {
    final productKey = productName.toLowerCase().trim();
    for (final entry in items.entries) {
      if (entry.key.toLowerCase().trim() == productKey) {
        return entry.value.unit;
      }
    }
    return '';
  }

  List<StockItem> get sortedItems {
    final itemsList = items.entries
        .map((entry) => StockItem(
              name: entry.key,
              quantity: entry.value.quantity,
              unit: entry.value.unit,
            ))
        .toList();
    
    itemsList.sort((a, b) => a.name.compareTo(b.name));
    return itemsList;
  }

  int get totalItemsCount => items.length;

  String get formattedDate {
    try {
      final date = DateTime.parse(stockDate);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return stockDate;
    }
  }
}

class StockItem {
  final String name;
  final double quantity;
  final String unit;

  const StockItem({
    required this.name,
    required this.quantity,
    required this.unit,
  });

  factory StockItem.fromJson(Map<String, dynamic> json) {
    return StockItem(
      name: json['name'] as String? ?? '',
      quantity: (json['quantity'] as num).toDouble(),
      unit: json['unit'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'unit': unit,
    };
  }

  String get displayQuantity {
    return '${quantity.toStringAsFixed(quantity.truncateToDouble() == quantity ? 0 : 1)}$unit';
  }

  String get displayName {
    return name.split(' ').map((word) => 
        word.isNotEmpty ? word[0].toUpperCase() + word.substring(1).toLowerCase() : word
    ).join(' ');
  }
}

class WhatsAppMessageDetails {
  final int id;
  final String messageId;
  final String senderName;
  final String content;
  final DateTime timestamp;
  final String messageType;

  const WhatsAppMessageDetails({
    required this.id,
    required this.messageId,
    required this.senderName,
    required this.content,
    required this.timestamp,
    required this.messageType,
  });

  factory WhatsAppMessageDetails.fromJson(Map<String, dynamic> json) {
    return WhatsAppMessageDetails(
      id: json['id'] as int,
      messageId: json['message_id'] as String,
      senderName: json['sender_name'] as String,
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp']),
      messageType: json['message_type'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'message_id': messageId,
      'sender_name': senderName,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'message_type': messageType,
    };
  }
}
