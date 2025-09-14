import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:place_order_final/features/messages/widgets/message_card.dart';
import 'package:place_order_final/models/whatsapp_message.dart';

void main() {
  testWidgets('MessageCard renders text content', (tester) async {
    final msg = WhatsAppMessage(
      id: '1',
      messageId: '1',
      chat: 'ORDERS Restaurants',
      sender: 'Karl',
      content: '2x lettuce',
      cleanedContent: '2x lettuce',
      timestamp: '2025-09-10T10:00:00+00:00',
      scrapedAt: '2025-09-10T10:00:00+00:00',
      type: MessageType.order,
      items: const [],
      instructions: '',
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MessageCard(
          message: msg,
          isSelected: false,
          onToggleSelection: () {},
          onEdit: () {},
          onDelete: () {},
        ),
      ),
    ));

    expect(find.text('2x lettuce'), findsOneWidget);
  });

  testWidgets('MessageCard renders image when media_type=image and has mediaUrl', (tester) async {
    final msg = WhatsAppMessage(
      id: '2',
      messageId: '2',
      chat: 'ORDERS Restaurants',
      sender: 'Karl',
      content: '',
      cleanedContent: '',
      timestamp: '2025-09-10T10:00:00+00:00',
      scrapedAt: '2025-09-10T10:00:00+00:00',
      type: MessageType.other,
      items: const [],
      instructions: '',
    ).copyWith(
      messageType: 'image',
      mediaUrl: 'https://via.placeholder.com/150.jpg',
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MessageCard(
          message: msg,
          isSelected: false,
          onToggleSelection: () {},
          onEdit: () {},
          onDelete: () {},
        ),
      ),
    ));

    // Should render an Image widget; we look for a network image by type
    expect(find.byType(Image), findsWidgets);
  });

  testWidgets('MessageCard shows blob placeholder for blob: URLs', (tester) async {
    final msg = WhatsAppMessage(
      id: '3',
      messageId: '3',
      chat: 'ORDERS Restaurants',
      sender: 'Karl',
      content: '',
      cleanedContent: '',
      timestamp: '2025-09-10T10:00:00+00:00',
      scrapedAt: '2025-09-10T10:00:00+00:00',
      type: MessageType.other,
      items: const [],
      instructions: '',
    ).copyWith(
      messageType: 'image',
      mediaUrl: 'blob:https://web.whatsapp.com/abc-123',
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MessageCard(
          message: msg,
          isSelected: false,
          onToggleSelection: () {},
          onEdit: () {},
          onDelete: () {},
        ),
      ),
    ));

    expect(find.text('WhatsApp Image'), findsOneWidget);
  });
}


