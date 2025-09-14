import 'package:flutter_test/flutter_test.dart';
import 'package:place_order_final/models/whatsapp_message.dart';

void main() {
  group('WhatsAppMessage.fromJson', () {
    test('maps media_type and media_url correctly', () {
      final json = {
        'id': '1',
        'message_id': 'MSG_1',
        'chat_name': 'ORDERS Restaurants',
        'sender_name': 'Karl',
        'sender_phone': '+27...',
        'content': 'Photo of stock',
        'cleaned_content': 'Photo of stock',
        'timestamp': '2025-09-10T19:55:00+00:00',
        'scraped_at': '2025-09-10T20:00:00+00:00',
        'message_type': 'other',
        'parsed_items': [],
        'instructions': '',
        'edited': false,
        'original_content': '',
        'processed': false,
        'order_day': null,
        'confidence_score': 0.5,
        'company_name': null,
        'is_stock_controller': false,
        'order_details': null,
        'media_type': 'image',
        'media_url': 'https://media.example.com/image.jpg',
        'media_info': '',
        'is_forwarded': false,
        'forwarded_info': '',
        'is_reply': false,
        'reply_content': '',
      };

      final msg = WhatsAppMessage.fromJson(json);
      expect(msg.messageType, equals('image'));
      expect(msg.mediaUrl, equals('https://media.example.com/image.jpg'));
      // Treat text properly when media_type is empty
      final jsonText = Map<String, dynamic>.from(json)
        ..['media_type'] = ''
        ..['media_url'] = '';
      final msgText = WhatsAppMessage.fromJson(jsonText);
      expect(msgText.messageType, isNull);
      expect(msgText.mediaUrl, isNull);
    });

    test('classification maps to MessageType', () {
      final json = {
        'id': '2',
        'message_id': 'MSG_2',
        'chat_name': 'ORDERS Restaurants',
        'sender_name': 'Karl',
        'content': '2x lettuce',
        'cleaned_content': '2x lettuce',
        'timestamp': '2025-09-10T12:00:00+00:00',
        'scraped_at': '2025-09-10T12:05:00+00:00',
        'message_type': 'order',
        'parsed_items': [],
        'instructions': '',
        'edited': false,
        'processed': false,
        'media_type': '',
        'media_url': '',
        'media_info': '',
      };
      final msg = WhatsAppMessage.fromJson(json);
      expect(msg.type, equals(MessageType.order));
    });
  });
}


