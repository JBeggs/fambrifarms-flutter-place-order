class SupplierProduct {
  final int id;
  final int supplierId;
  final String supplierName;
  final int productId;
  final String productName;
  final String? supplierProductCode;
  final String? supplierProductName;
  final String? supplierCategoryCode;
  final double supplierPrice;
  final String? currency;
  final bool? isAvailable;
  final int? stockQuantity;
  final int? minimumOrderQuantity;
  final int? leadTimeDays;
  final double? qualityRating;
  final DateTime? lastOrderDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SupplierProduct({
    required this.id,
    required this.supplierId,
    required this.supplierName,
    required this.productId,
    required this.productName,
    this.supplierProductCode,
    this.supplierProductName,
    this.supplierCategoryCode,
    required this.supplierPrice,
    this.currency,
    this.isAvailable,
    this.stockQuantity,
    this.minimumOrderQuantity,
    this.leadTimeDays,
    this.qualityRating,
    this.lastOrderDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SupplierProduct.fromJson(Map<String, dynamic> json) {
    return SupplierProduct(
      id: json['id'] as int,
      supplierId: json['supplier'] as int,
      supplierName: json['supplier_name'] as String? ?? '',
      productId: json['product'] as int,
      productName: json['product_name'] as String? ?? '',
      supplierProductCode: json['supplier_product_code'] as String?,
      supplierProductName: json['supplier_product_name'] as String?,
      supplierCategoryCode: json['supplier_category_code'] as String?,
      supplierPrice: (json['supplier_price'] as num).toDouble(),
      currency: json['currency'] as String?,
      isAvailable: json['is_available'] as bool?,
      stockQuantity: json['stock_quantity'] as int?,
      minimumOrderQuantity: json['minimum_order_quantity'] as int?,
      leadTimeDays: json['lead_time_days'] as int?,
      qualityRating: json['quality_rating'] != null 
          ? (json['quality_rating'] as num).toDouble() 
          : null,
      lastOrderDate: json['last_order_date'] != null 
          ? DateTime.parse(json['last_order_date'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'supplier': supplierId,
      'supplier_name': supplierName,
      'product': productId,
      'product_name': productName,
      'supplier_product_code': supplierProductCode,
      'supplier_product_name': supplierProductName,
      'supplier_category_code': supplierCategoryCode,
      'supplier_price': supplierPrice,
      'currency': currency,
      'is_available': isAvailable,
      'stock_quantity': stockQuantity,
      'minimum_order_quantity': minimumOrderQuantity,
      'lead_time_days': leadTimeDays,
      'quality_rating': qualityRating,
      'last_order_date': lastOrderDate?.toIso8601String().split('T')[0],
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  SupplierProduct copyWith({
    int? id,
    int? supplierId,
    String? supplierName,
    int? productId,
    String? productName,
    String? supplierProductCode,
    String? supplierProductName,
    String? supplierCategoryCode,
    double? supplierPrice,
    String? currency,
    bool? isAvailable,
    int? stockQuantity,
    int? minimumOrderQuantity,
    int? leadTimeDays,
    double? qualityRating,
    DateTime? lastOrderDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SupplierProduct(
      id: id ?? this.id,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      supplierProductCode: supplierProductCode ?? this.supplierProductCode,
      supplierProductName: supplierProductName ?? this.supplierProductName,
      supplierCategoryCode: supplierCategoryCode ?? this.supplierCategoryCode,
      supplierPrice: supplierPrice ?? this.supplierPrice,
      currency: currency ?? this.currency,
      isAvailable: isAvailable ?? this.isAvailable,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      minimumOrderQuantity: minimumOrderQuantity ?? this.minimumOrderQuantity,
      leadTimeDays: leadTimeDays ?? this.leadTimeDays,
      qualityRating: qualityRating ?? this.qualityRating,
      lastOrderDate: lastOrderDate ?? this.lastOrderDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'SupplierProduct(id: $id, supplier: $supplierName, product: $productName, price: \$${supplierPrice.toStringAsFixed(2)})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SupplierProduct && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  // Helper getters
  String get displayName => supplierProductName ?? productName;
  bool get hasStock => (stockQuantity ?? 0) > 0;
  bool get isCurrentlyAvailable => (isAvailable ?? false) && hasStock;
  String get availabilityStatus {
    if (!(isAvailable ?? false)) return 'Not Available';
    if (!hasStock) return 'Out of Stock';
    return 'Available (${stockQuantity ?? 0} units)';
  }
  
  String get priceDisplay => 'R${supplierPrice.toStringAsFixed(2)}';
  String get qualityDisplay => qualityRating != null 
      ? '${qualityRating!.toStringAsFixed(1)}/5.0' 
      : 'Not Rated';
}
