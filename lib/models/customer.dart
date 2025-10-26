class Customer {
  final int id;
  final String name;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String customerType;
  final String? customerSegment;
  final bool isActive;
  final DateTime? lastOrderDate;
  final double totalOrderValue;
  final int totalOrders;
  final CustomerProfile? profile;

  const Customer({
    required this.id,
    required this.name,
    this.firstName = '',
    this.lastName = '',
    required this.email,
    required this.phone,
    required this.customerType,
    this.customerSegment,
    this.isActive = true,
    this.lastOrderDate,
    this.totalOrderValue = 0.0,
    this.totalOrders = 0,
    this.profile,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    final firstName = json['first_name'] ?? '';
    final lastName = json['last_name'] ?? '';
    final businessName = json['name'] ?? '';
    
    // Construct display name: prefer business name, fallback to first+last name
    String displayName = businessName.isNotEmpty 
        ? businessName 
        : '$firstName $lastName'.trim();
    
    if (displayName.isEmpty) {
      displayName = json['email']?.split('@').first ?? 'Unknown Customer';
    }
    
    return Customer(
      id: json['id'] ?? 0,
      name: displayName,
      firstName: firstName,
      lastName: lastName,
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      customerType: json['user_type'] ?? json['customer_type'] ?? 'restaurant',
      customerSegment: json['customer_segment'],
      isActive: json['is_active'] ?? true,
      lastOrderDate: json['last_order_date'] != null 
          ? DateTime.parse(json['last_order_date']) 
          : null,
      totalOrderValue: (json['total_order_value'] ?? 0.0).toDouble(),
      totalOrders: json['total_orders'] ?? 0,
      profile: json['profile'] != null 
          ? CustomerProfile.fromJson(json['profile'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'phone': phone,
      'customer_type': customerType,
      'customer_segment': customerSegment,
      'is_active': isActive,
      'last_order_date': lastOrderDate?.toIso8601String(),
      'total_order_value': totalOrderValue,
      'total_orders': totalOrders,
      'profile': profile?.toJson(),
    };
  }

  // Customer type helpers
  bool get isRestaurant => customerType == 'restaurant';
  bool get isPrivate => customerType == 'private';
  bool get isInternal => customerType == 'internal';

  // Display helpers
  String get displayName => name.isNotEmpty ? name : email.split('@').first;
  String get customerTypeDisplay {
    switch (customerType) {
      case 'restaurant':
        return 'Restaurant';
      case 'private':
        return 'Private Customer';
      case 'internal':
        return 'Internal';
      default:
        return customerType;
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
    return 'C';
  }

  // Business logic helpers
  bool get isRecentCustomer {
    if (lastOrderDate == null) return false;
    final daysSinceLastOrder = DateTime.now().difference(lastOrderDate!).inDays;
    return daysSinceLastOrder <= 30;
  }

  String get orderFrequency {
    if (totalOrders == 0) return 'No orders';
    if (totalOrders >= 20) return 'Very High';
    if (totalOrders >= 10) return 'High';
    if (totalOrders >= 5) return 'Medium';
    return 'Low';
  }

  @override
  String toString() => 'Customer(name: $name, email: $email, type: $customerType)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Customer &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          email == other.email;

  @override
  int get hashCode => id.hashCode ^ email.hashCode;

  Customer copyWith({
    int? id,
    String? name,
    String? email,
    String? phone,
    String? customerType,
    String? customerSegment,
    bool? isActive,
    DateTime? lastOrderDate,
    double? totalOrderValue,
    int? totalOrders,
    CustomerProfile? profile,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      customerType: customerType ?? this.customerType,
      customerSegment: customerSegment ?? this.customerSegment,
      isActive: isActive ?? this.isActive,
      lastOrderDate: lastOrderDate ?? this.lastOrderDate,
      totalOrderValue: totalOrderValue ?? this.totalOrderValue,
      totalOrders: totalOrders ?? this.totalOrders,
      profile: profile ?? this.profile,
    );
  }
}

class CustomerProfile {
  final int id;
  final String? businessName;
  final String? branchName;
  final String? cuisineType;
  final int? seatingCapacity;
  final String? deliveryAddress;
  final String? city;
  final String? postalCode;
  final String? deliveryNotes;
  final String? orderPattern;
  final String? preferredDeliveryDay;
  final double? creditLimit;
  final int? paymentTermsDays;

  const CustomerProfile({
    required this.id,
    this.businessName,
    this.branchName,
    this.cuisineType,
    this.seatingCapacity,
    this.deliveryAddress,
    this.city,
    this.postalCode,
    this.deliveryNotes,
    this.orderPattern,
    this.preferredDeliveryDay,
    this.creditLimit,
    this.paymentTermsDays,
  });

  factory CustomerProfile.fromJson(Map<String, dynamic> json) {
    return CustomerProfile(
      id: json['id'] ?? 0,
      businessName: json['business_name'],
      branchName: json['branch_name'],
      cuisineType: json['cuisine_type'],
      seatingCapacity: json['seating_capacity'],
      deliveryAddress: json['delivery_address'],
      city: json['city'],
      postalCode: json['postal_code'],
      deliveryNotes: json['delivery_notes'],
      orderPattern: json['order_pattern'],
      preferredDeliveryDay: json['preferred_delivery_day'],
      creditLimit: json['credit_limit']?.toDouble(),
      paymentTermsDays: json['payment_terms_days'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_name': businessName,
      'branch_name': branchName,
      'cuisine_type': cuisineType,
      'seating_capacity': seatingCapacity,
      'delivery_address': deliveryAddress,
      'city': city,
      'postal_code': postalCode,
      'delivery_notes': deliveryNotes,
      'order_pattern': orderPattern,
      'preferred_delivery_day': preferredDeliveryDay,
      'credit_limit': creditLimit,
      'payment_terms_days': paymentTermsDays,
    };
  }

  String get displayName => businessName ?? 'Customer Profile';
  
  String get deliveryInfo {
    final parts = <String>[];
    if (preferredDeliveryDay != null) {
      parts.add(preferredDeliveryDay!);
    }
    if (deliveryNotes != null && deliveryNotes!.isNotEmpty) {
      parts.add(deliveryNotes!);
    }
    return parts.join(' • ');
  }
}