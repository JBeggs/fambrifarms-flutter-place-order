import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/whatsapp_message.dart';

class MessageEditor extends StatefulWidget {
  final WhatsAppMessage message;
  final Function(String, bool?) onSave;
  final Function(MessageType)? onTypeChange;
  final VoidCallback onCancel;

  const MessageEditor({
    super.key,
    required this.message,
    required this.onSave,
    this.onTypeChange,
    required this.onCancel,
  });

  @override
  State<MessageEditor> createState() => _MessageEditorState();
}

class _MessageEditorState extends State<MessageEditor> {
  late TextEditingController _controller;
  bool _hasChanges = false;
  late bool _processed;
  late MessageType _selectedType;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.message.content);
    _controller.addListener(_onTextChanged);
    _processed = widget.message.processed;
    _selectedType = widget.message.type;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {
      _hasChanges = _controller.text != widget.message.content || 
                   _processed != widget.message.processed ||
                   _selectedType != widget.message.type;
    });
  }
  
  void _onProcessedChanged(bool value) {
    setState(() {
      _processed = value;
      _hasChanges = _controller.text != widget.message.content || 
                   _processed != widget.message.processed ||
                   _selectedType != widget.message.type;
    });
  }

  void _onTypeChanged(MessageType? newType) {
    if (newType != null && newType != _selectedType) {
      setState(() {
        _selectedType = newType;
        _hasChanges = _controller.text != widget.message.content || 
                     _processed != widget.message.processed ||
                     _selectedType != widget.message.type;
      });
      
      // Immediately trigger backend update for type change
      if (widget.onTypeChange != null) {
        widget.onTypeChange!(newType);
      }
    }
  }

  void _applyQuickFix(String fixType) {
    String currentText = _controller.text;
    String newText = currentText;

    switch (fixType) {
      case 'remove_greetings':
        // Remove common greetings
        final greetings = [
          'good morning',
          'good afternoon', 
          'good evening',
          'hello',
          'hi',
          'hey',
          'thanks',
          'thank you',
          'please',
          'pls',
        ];
        
        for (final greeting in greetings) {
          newText = newText.replaceAll(RegExp(greeting, caseSensitive: false), '');
        }
        break;
        
      case 'remove_emojis':
        // Remove emojis and special characters
        newText = newText.replaceAll(RegExp(r'[^\w\s\n\-\+\×\*\/\.\,\:\(\)]'), '');
        break;
        
      case 'remove_sender_info':
        // Remove sender names and routing info
        final lines = newText.split('\n');
        final filteredLines = lines.where((line) {
          final trimmed = line.trim().toLowerCase();
          return !trimmed.startsWith('[') && // Remove timestamps
                 !trimmed.contains('→') && // Remove routing arrows
                 trimmed.isNotEmpty; // Remove empty lines
        }).toList();
        newText = filteredLines.join('\n');
        break;
        
      case 'extract_items_only':
        // Keep only lines that look like items (contain numbers/quantities)
        final lines = newText.split('\n');
        final itemLines = lines.where((line) {
          final trimmed = line.trim();
          return trimmed.isNotEmpty && 
                 (RegExp(r'\d+').hasMatch(trimmed) || // Contains numbers
                  RegExp(r'(kg|box|boxes|pcs|pieces|×|x)', caseSensitive: false).hasMatch(trimmed)); // Contains units
        }).toList();
        newText = itemLines.join('\n');
        break;
        
      case 'normalize_spacing':
        // Clean up whitespace
        newText = newText
            .replaceAll(RegExp(r'\n\s*\n'), '\n') // Remove empty lines
            .replaceAll(RegExp(r'[ \t]+'), ' ') // Normalize spaces
            .trim();
        break;
        
      case 'fix_spelling':
        // Fix common spelling mistakes in food/produce names
        final corrections = {
          // Vegetables
          'tomatoe': 'tomato',
          'tomatos': 'tomatoes',
          'potatos': 'potatoes',
          'carrot': 'carrots',
          'onoin': 'onion',
          'onions': 'onions',
          'cucmber': 'cucumber',
          'cucumbers': 'cucumbers',
          'spinich': 'spinach',
          'spinach': 'spinach',
          'brocoli': 'broccoli',
          'broccoli': 'broccoli',
          'cabage': 'cabbage',
          'cabbage': 'cabbage',
          'cauliflower': 'cauliflower',
          'califlower': 'cauliflower',
          'peper': 'pepper',
          'peppers': 'peppers',
          'chili': 'chilli',
          'chilis': 'chillies',
          'mushrom': 'mushroom',
          'mushrooms': 'mushrooms',
          'porta': 'portabellini',
          'portabello': 'portabellini',
          'portobello': 'portabellini',
          
          // Fruits
          'bannana': 'banana',
          'bananas': 'bananas',
          'aple': 'apple',
          'apples': 'apples',
          'oragne': 'orange',
          'oranges': 'oranges',
          'lemmon': 'lemon',
          'lemons': 'lemons',
          'lime': 'lime',
          'limes': 'limes',
          'avacado': 'avocado',
          'avocados': 'avocados',
          'avos': 'avocados',
          'strawbery': 'strawberry',
          'strawberries': 'strawberries',
          'pineaple': 'pineapple',
          'pineapple': 'pineapple',
          'blueberry': 'blueberries',
          'blue berry': 'blueberries',
          
          // Units
          'kgs': 'kg',
          'kilos': 'kg',
          'kilogram': 'kg',
          'grams': 'g',
          'pieces': 'pcs',
          'boxes': 'box',
          'bags': 'bag',
          'bunches': 'bunch',
          'heads': 'head',
          'punnets': 'punnet',
          'packets': 'packet',
        };
        
        // Apply corrections (case-insensitive)
        corrections.forEach((wrong, correct) {
          newText = newText.replaceAll(RegExp(wrong, caseSensitive: false), correct);
        });
        break;
    }

    _controller.text = newText;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: newText.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.edit,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Edit Message',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: widget.onCancel,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Message Info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'From: ${widget.message.sender}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getTypeColor(_selectedType).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<MessageType>(
                          value: _selectedType,
                          onChanged: widget.onTypeChange != null ? _onTypeChanged : null,
                          isDense: true,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _getTypeColor(_selectedType),
                          ),
                          items: MessageType.values.map((MessageType type) {
                            return DropdownMenuItem<MessageType>(
                              value: type,
                              child: Text('${type.icon} ${type.displayName}'),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Time: ${widget.message.timestamp}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Processed Status Toggle
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _processed 
                    ? Colors.green.withValues(alpha: 0.3)
                    : Colors.orange.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _processed ? Icons.check_circle : Icons.pending,
                  color: _processed ? Colors.green : Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Message Status:',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _processed ? 'Processed (orders created)' : 'Unprocessed (ready for processing)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _processed ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: _processed,
                  onChanged: _onProcessedChanged,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Quick Fix Buttons
          Text(
            'Quick Fixes:',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          
          const SizedBox(height: 8),
          
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QuickFixButton(
                label: 'Remove Greetings',
                icon: Icons.waving_hand,
                onPressed: () => _applyQuickFix('remove_greetings'),
              ),
              _QuickFixButton(
                label: 'Remove Emojis',
                icon: Icons.sentiment_satisfied,
                onPressed: () => _applyQuickFix('remove_emojis'),
              ),
              _QuickFixButton(
                label: 'Remove Sender Info',
                icon: Icons.person_remove,
                onPressed: () => _applyQuickFix('remove_sender_info'),
              ),
              _QuickFixButton(
                label: 'Items Only',
                icon: Icons.list,
                onPressed: () => _applyQuickFix('extract_items_only'),
              ),
              _QuickFixButton(
                label: 'Clean Spacing',
                icon: Icons.space_bar,
                onPressed: () => _applyQuickFix('normalize_spacing'),
              ),
              _QuickFixButton(
                label: 'Fix Spelling',
                icon: Icons.spellcheck,
                onPressed: () => _applyQuickFix('fix_spelling'),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Text Editor
          Text(
            'Message Content:',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          
          const SizedBox(height: 8),
          
          Expanded(
            child: TextField(
              controller: _controller,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              // Enable spell checking
              spellCheckConfiguration: SpellCheckConfiguration(
                spellCheckService: DefaultSpellCheckService(),
                misspelledTextStyle: const TextStyle(
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.red,
                  decorationStyle: TextDecorationStyle.wavy,
                ),
              ),
              decoration: InputDecoration(
                hintText: 'Edit the message content here...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.all(16),
                // Add spell check hint
                helperText: 'Spell check enabled - misspelled words will be underlined',
                helperStyle: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Action Buttons
          Row(
            children: [
              // Character count
              Text(
                '${_controller.text.length} characters',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              
              const Spacer(),
              
              // Cancel Button
              TextButton(
                onPressed: widget.onCancel,
                child: const Text('Cancel'),
              ),
              
              const SizedBox(width: 8),
              
              // Save Button
              ElevatedButton(
                onPressed: _hasChanges
                    ? () => widget.onSave(_controller.text, _processed != widget.message.processed ? _processed : null)
                    : null,
                child: const Text('Save Changes'),
              ),
            ],
          ),
        ],
      ),
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
}

class _QuickFixButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _QuickFixButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
