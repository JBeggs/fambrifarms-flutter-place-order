class WhatsAppMessage {
  final String id;
  final String? messageId;
  final String chat;
  final String sender;
  final String? senderPhone;
  final String content;
  final String cleanedContent;
  final String timestamp;
  final String scrapedAt;
  final MessageType type;
  final List<String> items;
  final String instructions;
  final bool edited;
  final String? originalContent;
  final bool processed;
  final String? orderDay;
  final double confidenceScore;
  final String? companyName;
  final String? manualCompany;
  final bool isStockController;
  final Map<String, dynamic>? orderDetails;
  // Media type from backend 'media_type' (image, voice, video, document, sticker). Null/empty for text
  final String? messageType;
  final String? mediaUrl;     // Direct media URL from backend (e.g., image http url)
  final String? mediaInfo;    // Additional media information
  final bool isForwarded;     // Whether this is a forwarded message
  final String? forwardedInfo; // Forwarded message info
  final bool isReply;         // Whether this is a reply to another message
  final String? replyContent; // Content of the message being replied to

  const WhatsAppMessage({
    required this.id,
    this.messageId,
    required this.chat,
    required this.sender,
    this.senderPhone,
    required this.content,
    required this.cleanedContent,
    required this.timestamp,
    required this.scrapedAt,
    required this.type,
    required this.items,
    required this.instructions,
    this.edited = false,
    this.originalContent,
    this.processed = false,
    this.orderDay,
    this.confidenceScore = 0.0,
    this.companyName,
    this.manualCompany,
    this.isStockController = false,
    this.orderDetails,
    this.messageType,
    this.mediaUrl,
    this.mediaInfo,
    this.isForwarded = false,
    this.forwardedInfo,
    this.isReply = false,
    this.replyContent,
  });

  factory WhatsAppMessage.fromJson(Map<String, dynamic> json) {
    // Normalize media_type: map empty string to null so UI treats it as text
    final String? rawMediaType = json['media_type'] as String?;
    final String? normalizedMediaType = (rawMediaType != null && rawMediaType.trim().isNotEmpty)
        ? rawMediaType
        : null;
    // Normalize media_url: map empty string to null
    final String? rawMediaUrl = json['media_url'] as String?;
    final String? normalizedMediaUrl = (rawMediaUrl != null && rawMediaUrl.trim().isNotEmpty)
        ? rawMediaUrl
        : null;

    return WhatsAppMessage(
      id: json['id'].toString(),
      messageId: json['message_id'] as String?,
      chat: json['chat_name'] as String? ?? json['chat'] as String? ?? '',
      sender: json['sender_name'] as String? ?? json['sender'] as String? ?? '',
      senderPhone: json['sender_phone'] as String?,
      content: json['content'] as String,
      cleanedContent: json['cleaned_content'] as String? ?? json['cleanedContent'] as String? ?? '',
      timestamp: json['timestamp'] as String,
      scrapedAt: json['scraped_at'] as String,
      type: _messageTypeFromString(json['message_type'] as String? ?? json['type'] as String? ?? 'other'),
      items: List<String>.from(json['parsed_items'] as List? ?? json['items'] as List? ?? []),
      instructions: json['instructions'] as String? ?? '',
      edited: json['edited'] as bool? ?? false,
      originalContent: json['original_content'] as String? ?? json['originalContent'] as String?,
      processed: json['processed'] as bool? ?? false,
      orderDay: json['order_day'] as String?,
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0.0,
      companyName: json['company_name'] as String?,
      manualCompany: json['manual_company'] as String?,
      isStockController: json['is_stock_controller'] as bool? ?? false,
      orderDetails: json['order_details'] as Map<String, dynamic>?,
      // Use backend media_type field for UI media rendering
      messageType: normalizedMediaType,
      mediaUrl: normalizedMediaUrl,
      mediaInfo: json['media_info'] as String?,
      isForwarded: json['is_forwarded'] as bool? ?? false,
      forwardedInfo: json['forwarded_info'] as String?,
      isReply: json['is_reply'] as bool? ?? false,
      replyContent: json['reply_content'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'message_id': messageId,
      'chat_name': chat,
      'sender_name': sender,
      'sender_phone': senderPhone,
      'content': content,
      'cleaned_content': cleanedContent,
      'timestamp': timestamp,
      'scraped_at': scrapedAt,
      // Classification type
      'message_type': type.name,
      'parsed_items': items,
      'instructions': instructions,
      'edited': edited,
      'original_content': originalContent,
      'processed': processed,
      'order_day': orderDay,
      'confidence_score': confidenceScore,
      'company_name': companyName,
      'is_stock_controller': isStockController,
      'order_details': orderDetails,
      // Media fields
      'media_type': messageType ?? '',
      'media_url': mediaUrl,
      'media_info': mediaInfo,
      'is_forwarded': isForwarded,
      'forwarded_info': forwardedInfo,
      'is_reply': isReply,
      'reply_content': replyContent,
    };
  }

  WhatsAppMessage copyWith({
    String? id,
    String? messageId,
    String? chat,
    String? sender,
    String? senderPhone,
    String? content,
    String? cleanedContent,
    String? timestamp,
    String? scrapedAt,
    MessageType? type,
    List<String>? items,
    String? instructions,
    bool? edited,
    String? originalContent,
    bool? processed,
    String? orderDay,
    double? confidenceScore,
    String? companyName,
    String? manualCompany,
    bool? isStockController,
    Map<String, dynamic>? orderDetails,
    String? messageType,
    String? mediaUrl,
    String? mediaInfo,
    bool? isForwarded,
    String? forwardedInfo,
    bool? isReply,
    String? replyContent,
  }) {
    return WhatsAppMessage(
      id: id ?? this.id,
      messageId: messageId ?? this.messageId,
      chat: chat ?? this.chat,
      sender: sender ?? this.sender,
      senderPhone: senderPhone ?? this.senderPhone,
      content: content ?? this.content,
      cleanedContent: cleanedContent ?? this.cleanedContent,
      timestamp: timestamp ?? this.timestamp,
      scrapedAt: scrapedAt ?? this.scrapedAt,
      type: type ?? this.type,
      items: items ?? this.items,
      instructions: instructions ?? this.instructions,
      edited: edited ?? this.edited,
      originalContent: originalContent ?? this.originalContent,
      processed: processed ?? this.processed,
      orderDay: orderDay ?? this.orderDay,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      companyName: companyName ?? this.companyName,
      manualCompany: manualCompany ?? this.manualCompany,
      isStockController: isStockController ?? this.isStockController,
      orderDetails: orderDetails ?? this.orderDetails,
      messageType: messageType ?? this.messageType,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaInfo: mediaInfo ?? this.mediaInfo,
      isForwarded: isForwarded ?? this.isForwarded,
      forwardedInfo: forwardedInfo ?? this.forwardedInfo,
      isReply: isReply ?? this.isReply,
      replyContent: replyContent ?? this.replyContent,
    );
  }
}

enum MessageType {
  order('Order', '🛒', 'order'),
  stock('Stock Update', '📦', 'stock'),
  instruction('Instruction', '📝', 'instruction'),
  demarcation('Order Day', '📅', 'demarcation'),
  other('Other', '❓', 'other');

  const MessageType(this.displayName, this.icon, this.name);

  final String displayName;
  final String icon;
  final String name;

  static MessageType fromString(String value) {
    switch (value) {
      case 'order':
        return MessageType.order;
      case 'stock':
        return MessageType.stock;
      case 'instruction':
        return MessageType.instruction;
      case 'demarcation':
        return MessageType.demarcation;
      default:
        return MessageType.other;
    }
  }
}

// Helper function for JSON parsing
MessageType _messageTypeFromString(String value) {
  switch (value) {
    case 'order':
      return MessageType.order;
    case 'stock':
      return MessageType.stock;
    case 'instruction':
      return MessageType.instruction;
    case 'demarcation':
      return MessageType.demarcation;
    default:
      return MessageType.other;
  }
}