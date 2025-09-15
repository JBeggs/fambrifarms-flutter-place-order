import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../models/whatsapp_message.dart';
import 'customer_dropdown.dart';

class MessageCard extends StatefulWidget {
  final WhatsAppMessage message;
  final bool isSelected;
  final VoidCallback onToggleSelection;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Function(String, String?)? onCompanyChanged;

  const MessageCard({
    super.key,
    required this.message,
    required this.isSelected,
    required this.onToggleSelection,
    required this.onEdit,
    required this.onDelete,
    this.onCompanyChanged,
  });

  @override
  State<MessageCard> createState() => _MessageCardState();
}

class _MessageCardState extends State<MessageCard> {
  late String? selectedCompany;
  bool _hasManualSelection = false; // Track if user manually selected a company

  @override
  void initState() {
    super.initState();
    selectedCompany = widget.message.companyName;
    // Check if this message has a manual company selection from backend
    _hasManualSelection = widget.message.manualCompany != null && widget.message.manualCompany!.isNotEmpty;
  }

  @override
  void didUpdateWidget(MessageCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only update selectedCompany if user hasn't made a manual selection
    if (!_hasManualSelection && oldWidget.message.companyName != widget.message.companyName) {
      selectedCompany = widget.message.companyName;
    }
  }

  void _handleCompanyChanged(String? newCompany) {
    setState(() {
      selectedCompany = newCompany;
      _hasManualSelection = true; // Mark that user has made a manual selection
    });
    
    // Notify parent about the change
    if (widget.onCompanyChanged != null) {
      widget.onCompanyChanged!(widget.message.id, newCompany);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: widget.isSelected ? 4 : 1,
        color: widget.isSelected 
            ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
            : widget.message.processed
                ? Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
                : null,
        child: InkWell(
          onTap: widget.onToggleSelection,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  children: [
                    // Selection Checkbox
                    Checkbox(
                      value: widget.isSelected,
                      onChanged: (_) => widget.onToggleSelection(),
                    ),
                    
                    const SizedBox(width: 8),
                    
                    // Message Type Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getTypeColor(widget.message.type).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _getTypeColor(widget.message.type).withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.message.type.icon,
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.message.type.displayName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _getTypeColor(widget.message.type),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const Spacer(),
                    
                    // Processed Indicator
                    if (widget.message.processed)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 12,
                              color: Colors.green.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'PROCESSED',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    // Edited Indicator
                    if (widget.message.edited)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'EDITED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      ),
                    
                    // Add spacing between indicators
                    if (widget.message.processed || widget.message.edited)
                      const SizedBox(width: 8),
                    
                    // Edit Button
                    IconButton(
                      onPressed: widget.onEdit,
                      icon: const Icon(Icons.edit, size: 18),
                      tooltip: 'Edit Message',
                      visualDensity: VisualDensity.compact,
                    ),
                    
                    // Delete Button
                    IconButton(
                      onPressed: () => _showDeleteConfirmation(context),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      tooltip: 'Delete Message',
                      visualDensity: VisualDensity.compact,
                      iconSize: 18,
                      color: Colors.red.shade600,
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Sender Info
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 16,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.message.sender,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.message.timestamp,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Message Content
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Show original content if edited
                      if (widget.message.edited && widget.message.originalContent != null) ...[
                        Text(
                          'Original:',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.message.originalContent!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Edited:',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.secondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      
                      // Reply indicator
                      if (widget.message.isReply && widget.message.replyContent != null) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border(
                              left: BorderSide(
                                color: Colors.blue.shade300,
                                width: 3,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.reply,
                                size: 16,
                                color: Colors.blue.shade600,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Replying to: ${widget.message.replyContent}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue.shade700,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      
                      // Forwarded indicator
                      if (widget.message.isForwarded) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Icon(
                                Icons.forward,
                                size: 16,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Forwarded',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Current content - handle media messages
                      if (widget.message.messageType != null && widget.message.messageType != 'text') ...[
                        // Media message display
                        _buildMediaWidget(context, widget.message),
                      ] else ...[
                        // Regular text message
                        Text(
                          widget.message.content,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Processing Hints
                if (widget.message.type == MessageType.stock) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'This will update inventory levels, not create an order',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (widget.message.type == MessageType.order) ...[
                  const SizedBox(height: 8),
                  
                  // Customer Dropdown
                  CustomerDropdown(
                    selectedCompany: selectedCompany,
                    onCompanyChanged: _handleCompanyChanged,
                    enabled: true,
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Order Info Container
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 16,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'This will create a customer order',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Show parsed items if available
                  if (widget.message.items.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.list_alt,
                                size: 16,
                                color: Colors.orange.shade700,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Parsed Items (${widget.message.items.length}):',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.orange.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ...widget.message.items.map((item) => Padding(
                            padding: const EdgeInsets.only(left: 22, top: 2),
                            child: Text(
                              '• $item',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.orange.shade600,
                              ),
                            ),
                          )).toList(),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Message'),
          content: Text(
            'Are you sure you want to delete this message?\n\n"${widget.message.content.length > 100 ? widget.message.content.substring(0, 100) + '...' : widget.message.content}"'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onDelete();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Color _getTypeColor(MessageType type) {
    switch (type) {
      case MessageType.order:
        return Colors.green;
      case MessageType.stock:
        return Colors.blue;
      case MessageType.instruction:
        return Colors.orange;
      case MessageType.demarcation:
        return Colors.purple;
      case MessageType.other:
        return Colors.grey;
    }
  }


  Widget _buildMediaWidget(BuildContext context, WhatsAppMessage message) {
    final mediaType = widget.message.messageType?.toLowerCase() ?? 'other';
    
    // Debug media details (non-throwing)
    // Using mediaUrl for images; mediaInfo is auxiliary text
    debugPrint('🖼️ MEDIA DEBUG type=${widget.message.messageType} url=${widget.message.mediaUrl} info=${widget.message.mediaInfo}');
    
    switch (mediaType) {
      case 'image':
        return _buildImageWidget(context, message);
      case 'voice':
        return _buildVoiceWidget(context, message);
      case 'video':
        return _buildVideoWidget(context, message);
      case 'document':
        return _buildDocumentWidget(context, message);
      case 'sticker':
        return _buildStickerWidget(context, message);
      default:
        return _buildGenericMediaWidget(context, message);
    }
  }

  Widget _buildImageWidget(BuildContext context, WhatsAppMessage message) {
    return Container(
      constraints: const BoxConstraints(
        maxWidth: 300,
        maxHeight: 400,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey[100],
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Actual image or placeholder
            Container(
              width: double.infinity,
              height: 200,
              color: Colors.pink.withValues(alpha: 0.1),
              child: _buildActualImage(message),
            ),
            // Media info
            if (widget.message.mediaInfo != null) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  widget.message.mediaInfo!,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            // Action buttons
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // TODO: Implement image viewing
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Image viewing not yet implemented')),
                        );
                      },
                      icon: const Icon(Icons.visibility, size: 16),
                      label: const Text('View'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pink.shade50,
                        foregroundColor: Colors.pink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      // TODO: Implement image download
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Image download not yet implemented')),
                      );
                    },
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Save'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade100,
                      foregroundColor: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceWidget(BuildContext context, WhatsAppMessage message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.deepPurple.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          // Play button
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.deepPurple,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: () {
                // TODO: Implement voice playback
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Voice playback not yet implemented')),
                );
              },
              icon: const Icon(Icons.play_arrow, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          // Voice info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Voice Message',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                    // Extract and display duration
                    if (widget.message.mediaInfo != null) ...[
                      Builder(
                        builder: (context) {
                          // Extract duration from mediaInfo (e.g., "Voice message (0:19)")
                          final match = RegExp(r'\(([0-9:]+)\)').firstMatch(widget.message.mediaInfo!);
                          final duration = match?.group(1);
                          return duration != null
                              ? Text(
                                  duration,
                                  style: TextStyle(
                                    color: Colors.deepPurple.shade600,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                )
                              : const SizedBox.shrink();
                        },
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                if (widget.message.mediaInfo != null)
                  Text(
                    widget.message.mediaInfo!,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                // Waveform placeholder
                const SizedBox(height: 8),
                Container(
                  height: 20,
                  child: Row(
                    children: List.generate(20, (index) => 
                      Container(
                        width: 2,
                        height: (index % 3 + 1) * 6.0,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Duration
          Text(
            '0:00', // TODO: Get actual duration
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoWidget(BuildContext context, WhatsAppMessage message) {
    return Container(
      constraints: const BoxConstraints(
        maxWidth: 300,
        maxHeight: 300,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.red.withValues(alpha: 0.1),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          // Video thumbnail placeholder
          Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.videocam,
                  size: 48,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
                // Play button overlay
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.8),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: () {
                      // TODO: Implement video playback
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Video playback not yet implemented')),
                      );
                    },
                    icon: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
                  ),
                ),
              ],
            ),
          ),
          // Video info
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.videocam, color: Colors.red, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Video',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      if (widget.message.mediaInfo != null)
                        Text(
                          widget.message.mediaInfo!,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentWidget(BuildContext context, WhatsAppMessage message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.indigo.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.indigo.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          // Document icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.indigo,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.description, color: Colors.white),
          ),
          const SizedBox(width: 12),
          // Document info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Document',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
                if (widget.message.mediaInfo != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.message.mediaInfo!,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Download button
          ElevatedButton.icon(
            onPressed: () {
              // TODO: Implement document download
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Document download not yet implemented')),
              );
            },
            icon: const Icon(Icons.download, size: 16),
            label: const Text('Open'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo.shade50,
              foregroundColor: Colors.indigo,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickerWidget(BuildContext context, WhatsAppMessage message) {
    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.amber.withValues(alpha: 0.1),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.emoji_emotions,
            size: 64,
            color: Colors.amber,
          ),
          const SizedBox(height: 8),
          Text(
            'Sticker',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.amber.shade700,
            ),
          ),
          if (widget.message.mediaInfo != null) ...[
            const SizedBox(height: 4),
            Text(
              widget.message.mediaInfo!,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGenericMediaWidget(BuildContext context, WhatsAppMessage message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.attachment,
            color: Colors.grey,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Media Attachment',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                if (widget.message.mediaInfo != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.message.mediaInfo!,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActualImage(WhatsAppMessage message) {
    // Prefer mediaUrl (direct URL). Fallback to mediaInfo if it looks like a URL/base64
    final candidate = widget.message.mediaUrl ?? widget.message.mediaInfo;
    final imageUrl = candidate ?? '';
    final hasValidUrl = imageUrl.length > 10;
    
    if (hasValidUrl) {
      // Handle different image URL types
      if (imageUrl.startsWith('data:image')) {
        // Base64 image
        try {
          final base64String = imageUrl.split(',')[1];
          final bytes = base64Decode(base64String);
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (context, error, stackTrace) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.broken_image,
                    size: 48,
                    color: Colors.pink,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Failed to load base64 image',
                    style: TextStyle(
                      color: Colors.pink,
                      fontSize: 12,
                    ),
                  ),
                ],
              );
            },
          );
        } catch (e) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.broken_image,
                size: 48,
                color: Colors.pink,
              ),
              const SizedBox(height: 8),
              Text(
                'Invalid base64 image',
                style: TextStyle(
                  color: Colors.pink,
                  fontSize: 12,
                ),
              ),
            ],
          );
        }
      } else if (imageUrl.startsWith('blob:')) {
        // Blob URL - can't be loaded directly in Flutter
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image,
              size: 48,
              color: Colors.pink,
            ),
            const SizedBox(height: 8),
            Text(
              'WhatsApp Image',
              style: TextStyle(
                color: Colors.pink,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Blob URL detected',
              style: TextStyle(
                color: Colors.pink.shade300,
                fontSize: 10,
              ),
            ),
          ],
        );
      } else {
        // Regular HTTP/HTTPS URL
        return Image.network(
          imageUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stackTrace) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.broken_image,
                  size: 48,
                  color: Colors.pink,
                ),
                const SizedBox(height: 8),
                Text(
                  'Failed to load image',
                  style: TextStyle(
                    color: Colors.pink,
                    fontSize: 12,
                  ),
                ),
              ],
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded / 
                          loadingProgress.expectedTotalBytes!
                        : null,
                    color: Colors.pink,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Loading image...',
                    style: TextStyle(
                      color: Colors.pink,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      }
    } else {
      // Placeholder for invalid/missing URLs
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image,
            size: 48,
            color: Colors.pink,
          ),
          const SizedBox(height: 8),
          Text(
            'Image',
            style: TextStyle(
              color: Colors.pink,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    }
  }
}
