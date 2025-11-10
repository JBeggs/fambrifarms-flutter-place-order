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
  final String? processingNotes;
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
  
  // HTML processing and expansion tracking (simplified architecture)
  final String? rawHtml;           // Raw HTML from WhatsApp message element
  final bool wasExpanded;          // Whether message was expanded from truncated state
  final bool expansionFailed;      // Whether expansion was attempted but failed
  final String? originalPreview;   // Preview text before expansion
  final bool needsManualReview;    // Flagged for manual review
  final String? reviewReason;      // Reason for manual review

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
    this.processingNotes,
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
    // HTML processing and expansion tracking
    this.rawHtml,
    this.wasExpanded = false,
    this.expansionFailed = false,
    this.originalPreview,
    this.needsManualReview = false,
    this.reviewReason,
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
      messageId: json['message_id']?.toString(),
      chat: (json['chat_name'] ?? json['chat'] ?? '').toString(),
      sender: (json['sender_name'] ?? json['sender'] ?? '').toString(),
      senderPhone: json['sender_phone']?.toString(),
      content: (json['content'] ?? '').toString(),
      cleanedContent: (json['cleaned_content'] ?? json['cleanedContent'] ?? '').toString(),
      timestamp: (json['timestamp'] ?? '').toString(),
      scrapedAt: (json['scraped_at'] ?? '').toString(),
      type: _messageTypeFromString((json['message_type'] ?? json['type'] ?? 'other').toString()),
      items: (json['parsed_items'] as List? ?? json['items'] as List? ?? [])
          .map((item) => item.toString())
          .toList(),
      instructions: (json['instructions'] ?? '').toString(),
      edited: json['edited'] as bool? ?? false,
      originalContent: json['original_content']?.toString() ?? json['originalContent']?.toString(),
      processed: json['processed'] as bool? ?? false,
      processingNotes: json['processing_notes']?.toString(),
      orderDay: json['order_day']?.toString(),
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0.0,
      companyName: json['company_name']?.toString(),
      manualCompany: json['manual_company']?.toString(),
      isStockController: json['is_stock_controller'] as bool? ?? false,
      orderDetails: json['order_details'] as Map<String, dynamic>?,
      // Use backend media_type field for UI media rendering
      messageType: normalizedMediaType,
      mediaUrl: normalizedMediaUrl,
      mediaInfo: json['media_info']?.toString(),
      isForwarded: json['is_forwarded'] as bool? ?? false,
      forwardedInfo: json['forwarded_info']?.toString(),
      isReply: json['is_reply'] as bool? ?? false,
      replyContent: json['reply_content']?.toString(),
      // HTML processing and expansion tracking
      rawHtml: json['raw_html']?.toString(),
      wasExpanded: json['was_expanded'] as bool? ?? false,
      expansionFailed: json['expansion_failed'] as bool? ?? false,
      originalPreview: json['original_preview']?.toString(),
      needsManualReview: json['needs_manual_review'] as bool? ?? false,
      reviewReason: json['review_reason']?.toString(),
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
      'processing_notes': processingNotes,
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
      // HTML processing and expansion tracking
      'raw_html': rawHtml,
      'was_expanded': wasExpanded,
      'expansion_failed': expansionFailed,
      'original_preview': originalPreview,
      'needs_manual_review': needsManualReview,
      'review_reason': reviewReason,
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
    String? processingNotes,
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
    // HTML processing and expansion tracking
    String? rawHtml,
    bool? wasExpanded,
    bool? expansionFailed,
    String? originalPreview,
    bool? needsManualReview,
    String? reviewReason,
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
      processingNotes: processingNotes ?? this.processingNotes,
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
      // HTML processing and expansion tracking
      rawHtml: rawHtml ?? this.rawHtml,
      wasExpanded: wasExpanded ?? this.wasExpanded,
      expansionFailed: expansionFailed ?? this.expansionFailed,
      originalPreview: originalPreview ?? this.originalPreview,
      needsManualReview: needsManualReview ?? this.needsManualReview,
      reviewReason: reviewReason ?? this.reviewReason,
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