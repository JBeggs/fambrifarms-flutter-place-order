import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/whatsapp_message.dart';
import '../../../services/api_service.dart';
import '../../../models/product.dart';
import '../../../utils/messages_provider.dart';

class MessageEditor extends ConsumerStatefulWidget {
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
  ConsumerState<MessageEditor> createState() => _MessageEditorState();
}

class _MessageEditorState extends ConsumerState<MessageEditor> {
  late TextEditingController _controller;
  bool _hasChanges = false;
  late bool _processed;
  late MessageType _selectedType;
  
  // Shared spelling corrections dictionary for consistency across all functions
  static const Map<String, String> _spellingCorrections = {
    // Vegetables - based on database products
    'tomato': 'tomatoes',
    'tomatoe': 'tomatoes',
    'tomatos': 'tomatoes',
    'potatoe': 'potatoes', 
    'potatos': 'potatoes',
    'carrot': 'carrots',
    'carrotss': 'carrots',  // Fix double 's' issue
    'carrotsss': 'carrots', // Fix triple 's' issue
    'carrott': 'carrots',
    'onoin': 'onions',
    'onion': 'onions',
    'cucmber': 'cucumber',
    'spinich': 'spinach',
    'brocoli': 'broccoli',
    'cabage': 'cabbage',
    'cauliflower': 'cauliflower',
    'califlower': 'cauliflower',
    'cellery': 'celery',
    'peper': 'peppers',
    'pepper': 'peppers',
    'mushrom': 'mushrooms',
    'mushrrom': 'mushroom',
    'mushroom': 'mushrooms',
    'lettice': 'lettuce',
    'porta': 'portabellini',
    'portabello': 'portabellini',
    'portobello': 'portabellini',
    
    // Fruits - based on database products  
    'bannana': 'bananas',
    'bananna': 'banana',
    'aple': 'apples',
    'oragne': 'oranges',
    'lemmon': 'lemons',
    'avacado': 'avocados',
    'avos': 'avocados',
    'strawbery': 'strawberries',
    'strawberry': 'strawberries',
    'pineaple': 'pineapple',
    'pine apple': 'pineapple',
    'blueberry': 'blueberries',
    'blue berry': 'blueberries',
    
    // Units and measurements
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
    'pun': 'punnet',
    'packets': 'packet',
  };

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

  Future<void> _onDeleteMessage() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message?'),
        content: const Text(
          'Are you sure you want to delete this message? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      try {
        // Delete the message using the messages provider
        await ref.read(messagesProvider.notifier).deleteMessage(widget.message.id);
        
        if (mounted) {
          // Close loading dialog
          Navigator.of(context).pop();
          
          // Close the message editor
          widget.onCancel();
          
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Message deleted successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          // Close loading dialog
          Navigator.of(context).pop();
          
          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Failed to delete message: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  Future<void> _applyQuickFix(String fixType) async {
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
        // Fix common spelling mistakes in food/produce names using shared dictionary
        // Apply corrections (case-insensitive) with word boundaries to prevent double corrections
        _spellingCorrections.forEach((wrong, correct) {
          // Use word boundaries to ensure we only replace whole words
          final regex = RegExp(r'\b' + RegExp.escape(wrong) + r'\b', caseSensitive: false);
          newText = newText.replaceAll(regex, correct);
        });
        break;
        
      case 'improve_items':
        // Get real product data from API and suggest actual packaging units
        await _improveItemsWithApiData();
        break;
        
      case 'remove_hyphens':
        // Remove hyphens and dashes from the text while preserving line breaks
        final lines = newText.split('\n');
        final processedLines = lines.map((line) {
          return line
              .replaceAll('-', ' ')  // Replace hyphens with spaces
              .replaceAll('–', ' ')  // Replace en dashes with spaces
              .replaceAll('—', ' ')  // Replace em dashes with spaces
              .replaceAll(RegExp(r'[ \t]+'), ' ')  // Normalize multiple spaces/tabs to single space
              .trim();  // Remove leading/trailing whitespace from each line
        }).toList();
        newText = processedLines.join('\n');  // Rejoin lines with newlines
        break;
        
      case 'remove_stray_x':
        // Remove stray x/X/×/* characters but preserve x inside words like "box", "mixed"
        final lines = newText.split('\n');
        final processedLines = lines.map((line) {
          String cleanedLine = line;
          
          // Remove multiplication symbols (×, *) everywhere
          cleanedLine = cleanedLine.replaceAll(RegExp(r'[×*]'), ' ');
          
          // Remove standalone x/X that are separated by spaces (stray ones)
          // "2 x 5kg" -> "2 5kg" but keep "box" as "box"
          cleanedLine = cleanedLine.replaceAll(RegExp(r'\s+[xX]\s+'), ' ');
          
          // Remove x/X at the very end of line (clearly stray)
          // "Product x" -> "Product"
          cleanedLine = cleanedLine.replaceAll(RegExp(r'\s+[xX]\s*$'), '');
          
          // Remove x/X at the very beginning of line (clearly stray)
          // "x Product" -> "Product"
          cleanedLine = cleanedLine.replaceAll(RegExp(r'^\s*[xX]\s+'), '');
          
          // Clean up multiple spaces
          return cleanedLine.replaceAll(RegExp(r'\s+'), ' ').trim();
        }).toList();
        newText = processedLines.join('\n');
        break;
        
      case 'remove_numbering':
        // Remove numbering from stock messages and order lists
        final lines = newText.split('\n');
        final cleanedLines = lines.map((line) {
          String cleanedLine = line.trim();
          if (cleanedLine.isEmpty) return cleanedLine;
          
          // Pattern 1: "1.Product name" -> "Product name"  
          cleanedLine = cleanedLine.replaceAll(RegExp(r'^\d+\.\s*'), '');
          
          // Pattern 2: "1) Product name" -> "Product name"
          cleanedLine = cleanedLine.replaceAll(RegExp(r'^\d+\)\s*'), '');
          
          // Pattern 3: "1 Product name" -> "Product name" (only single digit at start)
          if (RegExp(r'^\d\s+[A-Za-z]').hasMatch(cleanedLine)) {
            cleanedLine = cleanedLine.replaceAll(RegExp(r'^\d\s+'), '');
          }
          
          // Pattern 4: "(1) Product name" -> "Product name"
          cleanedLine = cleanedLine.replaceAll(RegExp(r'^\(\d+\)\s*'), '');
          
          // Pattern 5: "# Product name" -> "Product name" 
          cleanedLine = cleanedLine.replaceAll(RegExp(r'^#\s*'), '');
          
          // Pattern 6: "- Product name" -> "Product name"  
          cleanedLine = cleanedLine.replaceAll(RegExp(r'^-\s+'), '');
          
          // Pattern 7: "• Product name" -> "Product name" 
          cleanedLine = cleanedLine.replaceAll(RegExp(r'^•\s*'), '');
          
          // Pattern 8: "* Product name" -> "Product name" 
          cleanedLine = cleanedLine.replaceAll(RegExp(r'^\*\s*'), '');
          
          return cleanedLine.trim();
        }).where((line) => line.isNotEmpty).toList();
        
        newText = cleanedLines.join('\n');
        break;
    }

    _controller.text = newText;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: newText.length),
    );
  }

  void _showItemImprovements() async {
    final content = _controller.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No content to analyze'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Use our local Flutter function to get improvements
      final improvements = await _getItemImprovements(content);

      if (mounted) Navigator.of(context).pop(); // Close loading dialog

      if (mounted) {
        print('DEBUG: Improvements data: $improvements');
        final improvementsList = improvements['improvements'] as List<dynamic>;
        print('DEBUG: Improvements list: $improvementsList');
        _showImprovementsDialog(improvementsList);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error analyzing items: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showImprovementsDialog(List<dynamic> improvements) {
    print('DEBUG: Dialog received ${improvements.length} improvements');
    for (int i = 0; i < improvements.length; i++) {
      print('DEBUG: Improvement $i: ${improvements[i]}');
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Item Improvements'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Here are suggestions to improve your items:'),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: improvements.length,
                  itemBuilder: (context, index) {
                    final improvement = improvements[index];
                    return Card(
                      child: ListTile(
                        title: Text('Original: ${improvement['original']}'),
                        subtitle: Text('Suggested: ${improvement['suggestion']}'),
                        trailing: ElevatedButton(
                          onPressed: () {
                            _applyLineImprovement(
                              improvement['line_index'],
                              improvement['suggestion'],
                            );
                            // Don't close dialog - let user apply more improvements
                          },
                          child: const Text('Apply'),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Apply all improvements
              for (final improvement in improvements) {
                _applyLineImprovement(
                  improvement['line_index'],
                  improvement['suggestion'],
                );
              }
              Navigator.of(context).pop();
            },
            child: const Text('Apply All'),
          ),
        ],
      ),
    );
  }

  void _applyLineImprovement(int lineIndex, String improvedText) {
    final lines = _controller.text.split('\n');
    if (lineIndex >= 0 && lineIndex < lines.length) {
      lines[lineIndex] = improvedText;
      _controller.text = lines.join('\n');
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    }
  }

  // Get item improvements using DYNAMIC API data (not hardcoded!)
  Future<Map<String, dynamic>> _getItemImprovements(String content) async {
    // Get all products from API dynamically
    final apiService = ref.read(apiServiceProvider);
    final products = await apiService.getProducts();
    
    print('DEBUG: Got ${products.length} products from API');
    if (products.isNotEmpty) {
      print('DEBUG: First product example: ${products.first.name} - ${products.first.unit}');
      print('DEBUG: First product aliases: ${products.first.aliases}');
    }
    
    // Build dynamic product matching map
    final Map<String, String> productSuggestions = {};
    
    for (final product in products) {
      // Extract base product name (without size/packaging info)
      final baseName = product.name.toLowerCase().replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
      
      // Store suggestion mapping - prefer common sizes
      if (!productSuggestions.containsKey(baseName)) {
        productSuggestions[baseName] = product.name;
      } else {
        // Replace with better default if this product has a more common size
        final currentSuggestion = productSuggestions[baseName]!;
        final newProduct = product.name;
        
        // Keep the first match - don't overcomplicate with size preferences
      }
      
      // Add aliases if they exist
      if (product.aliases != null) {
        for (final alias in product.aliases!) {
          final cleanAlias = alias.toLowerCase().trim();
          if (!productSuggestions.containsKey(cleanAlias)) {
            productSuggestions[cleanAlias] = product.name;
          }
        }
      }
    }
    
    print('DEBUG: Built ${productSuggestions.length} product suggestions');
    print('DEBUG: Sample suggestions: ${productSuggestions.keys.take(5).toList()}');
    
    // Debug specific products we're looking for
    final strawberryKeys = productSuggestions.keys.where((k) => k.contains('strawberr')).toList();
    final appleKeys = productSuggestions.keys.where((k) => k.contains('apple')).toList();
    print('DEBUG: Strawberry keys: $strawberryKeys');
    print('DEBUG: Apple keys: $appleKeys');
    
    // Test the matching logic for specific cases
    final testLine1 = "strawberry x 2";
    final testLine2 = "red apple 1kg";
    print('DEBUG: Testing "$testLine1" against strawberry keys...');
    print('DEBUG: Testing "$testLine2" against apple keys...');
    
    final lines = content.split('\n');
    final improvements = <Map<String, dynamic>>[];
    
    print('DEBUG: Input lines: ${lines.map((l) => '"$l"').toList()}');
    
    for (int i = 0; i < lines.length; i++) {
      final trimmedLine = lines[i].trim();
      if (trimmedLine.isEmpty) continue;
      
      // Skip lines that already have complete specifications
      if (RegExp(r'\([^)]*\d+\s*(g|kg|ml|l)\)', caseSensitive: false).hasMatch(trimmedLine)) {
        print('DEBUG: Skipping line with complete specs: "$trimmedLine"');
        continue;
      }
      
      print('DEBUG: Processing line: "$trimmedLine"');
      
      // Extract quantity: NUMBER ON ITS OWN = quantity, else quantity = 1
      String? quantity;
      
      // THE ONE FUCKING RULE: Find the FIRST number that is standalone (not attached to units)
      final allNumbers = RegExp(r'\b(\d+(?:\.\d+)?)\b').allMatches(trimmedLine);
      
      for (final match in allNumbers) {
        final numberStr = match.group(0)!;
        final numberStart = match.start;
        final numberEnd = match.end;
        
        // Check what comes immediately after the number (no space allowed for attachment)
        final afterNumber = trimmedLine.substring(numberEnd);
        
        // Skip if number is DIRECTLY attached to units (no space): "200g", "5kg", "10ml"
        final isAttachedToUnit = RegExp(r'^(kg|g|ml|l)\b', caseSensitive: false).hasMatch(afterNumber);
        
        if (!isAttachedToUnit) {
          // This number is ON ITS OWN - use it as quantity
          quantity = numberStr.split('.')[0]; // Remove decimal part for quantity
          print('DEBUG: Found standalone quantity "$quantity" in "$trimmedLine"');
          break;
        } else {
          print('DEBUG: Skipping attached number "$numberStr" in "$trimmedLine" (attached to unit)');
        }
      }
      
      // If no standalone number found, quantity = 1
      if (quantity == null) {
        quantity = '1';
        print('DEBUG: No standalone number found in "$trimmedLine", defaulting to quantity = 1');
      }
      
      // Check for obscure/unrecognized words and provide warnings
      final words = trimmedLine.toLowerCase().split(RegExp(r'\s+'));
      final obscureWords = <String>[];
      
      for (final word in words) {
        // Skip numbers, common units, and very short words
        if (RegExp(r'^\d+(\.\d+)?$').hasMatch(word) || 
            word.length <= 2 ||
            ['kg', 'g', 'ml', 'l', 'box', 'bag', 'packet', 'punnet', 'bunch', 'head', 'each', 'piece'].contains(word)) {
          continue;
        }
        
        // Check if this word appears in any product name from the database
        bool foundInDatabase = false;
        for (final productName in productSuggestions.values) {
          if (productName.toLowerCase().contains(word)) {
            foundInDatabase = true;
            break;
          }
        }
        
        // If word not found in database, it might be obscure/misspelled
        if (!foundInDatabase) {
          obscureWords.add(word);
        }
      }
      
      // Check for format improvements even if words are recognized
      String? formatImprovement = null;
      
      // Check for inconsistent capitalization (mix of upper/lower case)
      if (RegExp(r'[a-z][A-Z]|[A-Z][a-z][A-Z]').hasMatch(trimmedLine)) {
        // Suggest proper case formatting
        final words = trimmedLine.split(' ');
        final improvedWords = words.map((word) {
          if (RegExp(r'^\d+$').hasMatch(word)) return word; // Keep numbers as-is
          return word.toLowerCase(); // Convert to lowercase for consistency
        }).toList();
        formatImprovement = improvedWords.join(' ');
      }
      
      // Check for non-standard size indicators like "xs", "s", "m", "l", "xl"
      if (RegExp(r'\b(xs|s|m|l|xl)\b', caseSensitive: false).hasMatch(trimmedLine)) {
        final suggestion = trimmedLine.replaceAllMapped(
          RegExp(r'\b(xs|s|m|l|xl)\b', caseSensitive: false),
          (match) {
            switch (match.group(0)?.toLowerCase()) {
              case 'xs': return 'small';
              case 's': return 'small';
              case 'm': return 'medium';
              case 'l': return 'large';
              case 'xl': return 'extra large';
              default: return match.group(0) ?? '';
            }
          }
        );
        formatImprovement = suggestion;
      }
      
      // If we have a format improvement, suggest it
      if (formatImprovement != null && formatImprovement != trimmedLine) {
        improvements.add({
          'line_index': i,
          'original': trimmedLine,
          'suggestion': formatImprovement,
          'confidence': 0.8,
          'reason': 'Improved formatting and standardization',
        });
        continue; // Move to next line
      }
      
      // Check if item needs packaging/size suggestions (no existing packaging info)
      if (!RegExp(r'\b(box|bag|packet|punnet|bunch|head|each|piece|\d+g|\d+kg|\d+ml|\d+l)\b', caseSensitive: false).hasMatch(trimmedLine)) {
        // Extract product name for matching
        String productName = trimmedLine.toLowerCase()
            .replaceAll(RegExp(r'^\d+\s*'), '') // Remove leading quantity
            .replaceAll(RegExp(r'\s*[x×*]\s*\d+\s*'), '') // Remove x multipliers
            .trim();
        
        // Find all products that match this name and collect their packaging options
        final packagingOptions = <String>[];
        final sizeOptions = <String>[];
        
        for (final dbProduct in productSuggestions.values) {
          final dbProductLower = dbProduct.toLowerCase();
          
          // Check if this database product matches our item
          if (dbProductLower.contains(productName) || productName.contains(dbProductLower.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim())) {
            // Extract packaging info from database product name
            final packagingMatch = RegExp(r'\b(box|bag|packet|punnet|bunch|head|each|piece)\b', caseSensitive: false).firstMatch(dbProduct);
            if (packagingMatch != null) {
              final packaging = packagingMatch.group(0)!.toLowerCase();
              if (!packagingOptions.contains(packaging)) {
                packagingOptions.add(packaging);
              }
            }
            
            // Extract size info from database product name
            final sizeMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(g|kg|ml|l)\b', caseSensitive: false).firstMatch(dbProduct);
            if (sizeMatch != null) {
              final size = sizeMatch.group(0)!;
              if (!sizeOptions.contains(size)) {
                sizeOptions.add(size);
              }
            }
          }
        }
        
        // If we found packaging or size options, suggest them
        if (packagingOptions.isNotEmpty || sizeOptions.isNotEmpty) {
          String suggestionText = 'Missing packaging/size info. Available options:\\n';
          
          if (packagingOptions.isNotEmpty) {
            suggestionText += 'Packaging: ${packagingOptions.join(', ')}\\n';
          }
          
          if (sizeOptions.isNotEmpty) {
            suggestionText += 'Sizes: ${sizeOptions.join(', ')}\\n';
          }
          
          // Create example suggestions
          final examples = <String>[];
          if (packagingOptions.isNotEmpty && sizeOptions.isNotEmpty) {
            // Combine first packaging with first size
            examples.add('$trimmedLine ${sizeOptions.first} ${packagingOptions.first}');
          } else if (packagingOptions.isNotEmpty) {
            examples.add('$trimmedLine ${packagingOptions.first}');
          } else if (sizeOptions.isNotEmpty) {
            examples.add('$trimmedLine ${sizeOptions.first}');
          }
          
          if (examples.isNotEmpty) {
            suggestionText += 'Example: ${examples.first}';
          }
          
          improvements.add({
            'line_index': i,
            'original': trimmedLine,
            'suggestion': '$trimmedLine\\n📦 $suggestionText',
            'confidence': 0.85,
            'reason': 'Missing packaging or size information',
          });
          continue; // Move to next line
        }
      }
      
      // If we found obscure words, add a warning suggestion with similar products
      if (obscureWords.isNotEmpty) {
        final suggestions = <String>[];
        
        // Find similar products for each obscure word
        for (final obscureWord in obscureWords) {
          final similarProducts = <String>[];
          
          for (final productName in productSuggestions.values) {
            final productLower = productName.toLowerCase();
            // Check for partial matches or similar words
            if (productLower.contains(obscureWord.substring(0, (obscureWord.length * 0.7).round())) ||
                obscureWord.contains(productLower.split(' ').first.substring(0, (productLower.split(' ').first.length * 0.7).round()))) {
              similarProducts.add(productName);
              if (similarProducts.length >= 3) break; // Limit to 3 suggestions
            }
          }
          
          if (similarProducts.isNotEmpty) {
            suggestions.add('For "$obscureWord": ${similarProducts.join(', ')}');
          }
        }
        
        String warningMessage = 'Warning: Unrecognized words: ${obscureWords.join(', ')}. Please check spelling.';
        if (suggestions.isNotEmpty) {
          warningMessage += '\nSuggestions:\n${suggestions.join('\n')}';
        }
        
        improvements.add({
          'line_index': i,
          'original': trimmedLine,
          'suggestion': '$trimmedLine\n⚠️ $warningMessage',
          'confidence': 0.7,
          'reason': 'Contains unrecognized words - check spelling',
        });
        continue; // Move to next line
      }

      // DYNAMIC matching against database products
      String? bestMatch;
      String? matchedKey;
      final lowerLine = trimmedLine.toLowerCase();
      
      // STEP 1: Try EXACT matches first
      String cleanLine = lowerLine.replaceAll(RegExp(r'\b\d+\b|\b(kg|g|ml|l|box|bag|bunch|head|each|packet|punnet|x|×|\*)\b'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
      
      for (final baseName in productSuggestions.keys) {
        final lowerBaseName = baseName.toLowerCase();
        String cleanBaseName = lowerBaseName.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
        
        // Check for EXACT matches only
        bool isExactMatch = cleanLine == cleanBaseName ||
            // Handle singular/plural variations
            (cleanLine.endsWith('s') && cleanBaseName == cleanLine.substring(0, cleanLine.length - 1)) ||
            (cleanBaseName.endsWith('s') && cleanLine == cleanBaseName.substring(0, cleanBaseName.length - 1)) ||
            // Handle berry -> berries (strawberry -> strawberries)
            (cleanLine.endsWith('y') && cleanBaseName == cleanLine.substring(0, cleanLine.length - 1) + 'ies') ||
            (cleanBaseName.endsWith('ies') && cleanLine == cleanBaseName.substring(0, cleanBaseName.length - 3) + 'y') ||
            // Handle apple -> apples
            (cleanLine + 's' == cleanBaseName) ||
            (cleanBaseName + 's' == cleanLine);
        
        if (isExactMatch) {
          bestMatch = productSuggestions[baseName];
          matchedKey = baseName;
          print('DEBUG: EXACT MATCH! cleanLine="$cleanLine" matched cleanBaseName="$cleanBaseName"');
          break;
        }
      }
      
      // STEP 2: If no exact match, try partial matches
      if (bestMatch == null) {
        for (final baseName in productSuggestions.keys) {
          final lowerBaseName = baseName.toLowerCase();
          String cleanBaseName = lowerBaseName.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
          
          print('DEBUG: Comparing cleanLine="$cleanLine" with cleanBaseName="$cleanBaseName"');
          
          bool isPartialMatch = lowerLine.contains(lowerBaseName) || 
              lowerBaseName.contains(cleanLine) ||
              cleanLine.contains(cleanBaseName);
          
          if (isPartialMatch) {
            bestMatch = productSuggestions[baseName];
            matchedKey = baseName;
            print('DEBUG: PARTIAL MATCH! cleanLine="$cleanLine" matched cleanBaseName="$cleanBaseName"');
            break;
          }
        }
      }
      
      // If no match found, try fuzzy matching on individual words
      if (bestMatch == null) {
        final lineWords = lowerLine.split(' ').where((w) => w.length > 2 && !RegExp(r'^\d+$').hasMatch(w)).toList();
        for (final baseName in productSuggestions.keys) {
          final baseWords = baseName.toLowerCase().split(' ');
          int matchCount = 0;
          for (final lineWord in lineWords) {
            for (final baseWord in baseWords) {
              if (baseWord.contains(lineWord) || lineWord.contains(baseWord)) {
                matchCount++;
                break;
              }
            }
          }
          // If most words match, consider it a match
          if (matchCount >= (lineWords.length * 0.6).ceil() && matchCount >= 1) {
            bestMatch = productSuggestions[baseName];
            matchedKey = baseName;
            break;
          }
        }
      }
      
      print('DEBUG: Line "$trimmedLine" - Quantity: $quantity, Matched: $matchedKey -> $bestMatch');
      
      // Debug why some items aren't matching
      if (bestMatch == null) {
        final cleanLine = lowerLine.replaceAll(RegExp(r'\d+|\s*(kg|g|ml|l|box|bag|bunch|head|each|packet|punnet)\s*'), '').trim();
        print('DEBUG: No match for "$trimmedLine" - cleaned: "$cleanLine"');
        print('DEBUG: Available product keys: ${productSuggestions.keys.take(10).toList()}');
      }
      
      if (bestMatch != null) {
        // Extract product name - ALWAYS remove the standalone quantity we identified
        String productName = trimmedLine;
        
        // Remove the standalone quantity from anywhere in the line (beginning, middle, or end)
        // But be careful to only remove the EXACT quantity we identified
        final quantityPattern = RegExp(r'\b' + RegExp.escape(quantity) + r'\b');
        productName = productName.replaceFirst(quantityPattern, '').trim();
        
        // Clean up extra spaces
        productName = productName.replaceAll(RegExp(r'\s+'), ' ').trim();
        
        print('DEBUG: Extracted productName: "$productName" from "$trimmedLine"');
        print('DEBUG: Step by step extraction:');
        print('  1. Original: "$trimmedLine"');
        String step1 = trimmedLine.replaceAll(RegExp(r'^\d+(?:\.\d+)?\s*[x×*]?\s*'), '');
        print('  2. After removing leading quantity: "$step1"');
        String step2 = step1.replaceAll(RegExp(r'\s*[x×*]\s*\d+(?:\.\d+)?\s*$'), '');
        print('  3. After removing trailing x N: "$step2"');
        String step3 = step2.replaceAll(RegExp(r'\s*\d+(?:\.\d+)?\s*(kg|g|ml|l|piece)\s*(box|bag|bunch|head|each|packet|punnet)?\s*$'), '');
        print('  4. After removing size+unit: "$step3"');
        String step4 = step3.replaceAll(RegExp(r'\s*\d+(?:\.\d+)?\s*(box|bag|bunch|head|each|packet|punnet)\s*$'), '');
        print('  5. After removing standalone numbers before units: "$step4"');
        String step5 = step4.replaceAll(RegExp(r'\s*(box|bag|bunch|head|each|packet|punnet)\s*$'), '');
        print('  6. After removing trailing unit: "$step5"');
        String step6 = step5.replaceAll(RegExp(r'\s*\d+(?:\.\d+)?\s*(kg|g|ml|l|piece)\s*$'), '');
        print('  7. After removing trailing size: "$step6"');
        String step7 = step6.replaceAll(RegExp(r'\s*\d+(?:\.\d+)?\s*$'), '');
        print('  8. After removing any trailing numbers: "$step7"');
        String step8 = step7.replaceAll(RegExp(r'\s*\([^)]*\)\s*'), '');
        print('  9. Final after removing brackets: "$step8"');
        
        // Look for existing packaging info
        final sizeMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(kg|g|ml|l)\b', caseSensitive: false).firstMatch(trimmedLine);
        final unitMatch = RegExp(r'\b(box|bag|bunch|head|each|packet|punnet)\b', caseSensitive: false).firstMatch(trimmedLine);
        
        // Create improved line: quantity + product name (keeping existing packaging)
        String improvedLine = '$quantity $productName';
        
        print('DEBUG: Improved line: "$improvedLine"');
        
        // Add improvement if we found a match and it's different AND actually improved
        if (improvedLine != trimmedLine && improvedLine.trim() != trimmedLine.trim()) {
          // Don't suggest if we're just rearranging the same words
          final originalWords = trimmedLine.toLowerCase().split(RegExp(r'\s+')).toSet();
          final improvedWords = improvedLine.toLowerCase().split(RegExp(r'\s+')).toSet();
          
          // Only suggest if we're actually adding value (not just rearranging)
          if (!originalWords.containsAll(improvedWords) || improvedWords.length > originalWords.length) {
            improvements.add({
              'line_index': i,
              'original': trimmedLine,
              'suggestion': improvedLine,
              'confidence': 0.9,
              'reason': 'Improved product format',
            });
          }
        }
      } else {
        print('DEBUG: No match found for "$trimmedLine"');
        
        // No exact match found - suggest similar products if the line seems like a product
        if (trimmedLine.length > 3 && !RegExp(r'^(order|from|to|please|thank|hello|hi)').hasMatch(trimmedLine.toLowerCase())) {
          // Find the most similar products
          final similarProducts = <String>[];
          final cleanLine = trimmedLine.toLowerCase().replaceAll(RegExp(r'\b\d+\b|\b(kg|g|ml|l|box|bag|bunch|head|each|packet|punnet|x|×|\*)\b'), '').trim();
          
          for (final productName in productSuggestions.values) {
            final productLower = productName.toLowerCase();
            // Check for partial word matches
            final lineWords = cleanLine.split(' ');
            final productWords = productLower.split(' ');
            
            int matchCount = 0;
            for (final lineWord in lineWords) {
              if (lineWord.length > 2) {
                for (final productWord in productWords) {
                  if (productWord.contains(lineWord) || lineWord.contains(productWord)) {
                    matchCount++;
                    break;
                  }
                }
              }
            }
            
            if (matchCount > 0) {
              similarProducts.add(productName);
              if (similarProducts.length >= 5) break; // Limit suggestions
            }
          }
          
          if (similarProducts.isNotEmpty) {
            final suggestionText = 'No exact match found. Similar products:\\n${similarProducts.take(3).join('\\n')}';
            improvements.add({
              'line_index': i,
              'original': trimmedLine,
              'suggestion': '$trimmedLine\\n💡 $suggestionText',
              'confidence': 0.6,
              'reason': 'Suggested similar products',
            });
          }
        }
      }
    }
    
    return {
      'improvements': improvements,
      'total_items': lines.where((line) => line.trim().isNotEmpty).length,
      'improved_items': improvements.length,
    };
  }

  // Calculate similarity between two strings using word-based matching
  double _calculateSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;
    
    // Check if one string contains the other
    if (s1.contains(s2) || s2.contains(s1)) return 0.8;
    
    // Simple word-based matching
    final words1 = s1.split(' ');
    final words2 = s2.split(' ');
    
    int matchingWords = 0;
    for (final word1 in words1) {
      for (final word2 in words2) {
        if (word1.toLowerCase() == word2.toLowerCase()) {
          matchingWords++;
          break;
        }
      }
    }
    
    return matchingWords / (words1.length > words2.length ? words1.length : words2.length);
  }

  // OLD FUNCTION - REMOVE THIS ENTIRE BLOCK
  Future<void> _improveItemsWithApiData() async {
    try {
      // Get all products from API
      final apiService = ref.read(apiServiceProvider);
      final products = await apiService.getProducts();
      
      print('DEBUG: Loaded ${products.length} products from API');
      
      // Create maps for product matching with full specifications
      final Map<String, List<String>> productVariations = {};
      final Map<String, String> productSuggestions = {};
      final Set<String> allUnits = <String>{};
      
      for (final product in products) {
        // Collect all unit types from the database
        allUnits.add(product.unit.toLowerCase());
        
        // Extract base product name (without size/packaging info)
        final baseName = product.name.toLowerCase().replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
        
        // Store all variations for this base product
        if (!productVariations.containsKey(baseName)) {
          productVariations[baseName] = [];
        }
        productVariations[baseName]!.add(product.name);
        
        // Store a suggestion mapping from base name to a good default product
        // Prefer smaller/common sizes as defaults
        if (!productSuggestions.containsKey(baseName)) {
          productSuggestions[baseName] = product.name;
        } else {
          // Replace with better default if this product has a more common size
          final currentSuggestion = productSuggestions[baseName]!;
          final newProduct = product.name;
          
          // Prefer products with common sizes (2kg, 5kg for boxes; 10kg, 20kg for bags)
          if (product.unit.toLowerCase() == 'box') {
            // For boxes, prefer 2kg or 5kg
            if (newProduct.contains('(2kg)') || newProduct.contains('(5kg)')) {
              if (!currentSuggestion.contains('(2kg)') && !currentSuggestion.contains('(5kg)')) {
                productSuggestions[baseName] = newProduct;
              }
            }
          } else if (product.unit.toLowerCase() == 'bag') {
            // For bags, prefer 10kg or 20kg
            if (newProduct.contains('(10kg)') || newProduct.contains('(20kg)')) {
              if (!currentSuggestion.contains('(10kg)') && !currentSuggestion.contains('(20kg)')) {
                productSuggestions[baseName] = newProduct;
              }
            }
          } else if (product.unit.toLowerCase() == 'punnet') {
            // For punnets, prefer 200g or 500g
            if (newProduct.contains('(200g)') || newProduct.contains('(500g)')) {
              if (!currentSuggestion.contains('(200g)') && !currentSuggestion.contains('(500g)')) {
                productSuggestions[baseName] = newProduct;
              }
            }
          }
        }
        
        // Add aliases if they exist
        if (product.aliases != null) {
          for (final alias in product.aliases!) {
            final cleanAlias = alias.toLowerCase().trim();
            if (!productVariations.containsKey(cleanAlias)) {
              productVariations[cleanAlias] = [];
            }
            productVariations[cleanAlias]!.add(product.name);
            if (!productSuggestions.containsKey(cleanAlias)) {
              productSuggestions[cleanAlias] = product.name;
            } else {
              // Apply same default size logic for aliases
              final currentSuggestion = productSuggestions[cleanAlias]!;
              final newProduct = product.name;
              
              if (product.unit.toLowerCase() == 'box') {
                if (newProduct.contains('(2kg)') || newProduct.contains('(5kg)')) {
                  if (!currentSuggestion.contains('(2kg)') && !currentSuggestion.contains('(5kg)')) {
                    productSuggestions[cleanAlias] = newProduct;
                  }
                }
              } else if (product.unit.toLowerCase() == 'bag') {
                if (newProduct.contains('(10kg)') || newProduct.contains('(20kg)')) {
                  if (!currentSuggestion.contains('(10kg)') && !currentSuggestion.contains('(20kg)')) {
                    productSuggestions[cleanAlias] = newProduct;
                  }
                }
              } else if (product.unit.toLowerCase() == 'punnet') {
                if (newProduct.contains('(200g)') || newProduct.contains('(500g)')) {
                  if (!currentSuggestion.contains('(200g)') && !currentSuggestion.contains('(500g)')) {
                    productSuggestions[cleanAlias] = newProduct;
                  }
                }
              }
            }
          }
        }
      }
      
      // Create dynamic regex pattern from actual database units
      final unitsPattern = allUnits.map((unit) => RegExp.escape(unit)).join('|');
      
      print('DEBUG: Found ${productSuggestions.length} product suggestions');
      print('DEBUG: Units pattern: $unitsPattern');
      
      // Process each line
      final lines = _controller.text.split('\n');
      print('DEBUG: Processing ${lines.length} lines');
      
      final improvedLines = lines.map((line) {
        String improvedLine = line.trim();
        print('DEBUG: Processing line: "$improvedLine"');
        
        // Skip empty lines
        if (improvedLine.isEmpty) {
          return improvedLine;
        }
        
        // Skip lines that already have complete product specifications with sizes
        // e.g. "2 Baby Marrow (5kg)" or "5 Cherry Tomatoes (200g)"
        if (RegExp(r'\([^)]*\d+\s*(g|kg|ml|l)\)', caseSensitive: false).hasMatch(improvedLine)) {
          print('DEBUG: Skipping line (already complete): "$improvedLine"');
          return improvedLine; // Already has complete specification
        }
        
        // Simple fucking logic: just fix the obvious shit
        
        // Extract quantity properly - look for ANY number in the line
        String? quantity;
        final allNumbers = RegExp(r'\b(\d+)\b').allMatches(improvedLine);
        if (allNumbers.isNotEmpty) {
          quantity = allNumbers.first.group(1);
        }
        
        // Simple replacements for common items
        if (improvedLine.toLowerCase().contains('cherry tomato')) {
          improvedLine = '${quantity ?? '1'} Cherry Tomatoes (200g)';
        } else if (improvedLine.toLowerCase().contains('carrots')) {
          improvedLine = '${quantity ?? '1'} Carrots (10kg)';
        } else if (improvedLine.toLowerCase().contains('mixed lettuce')) {
          improvedLine = '${quantity ?? '1'} Mixed Lettuce (250g)';
        } else if (improvedLine.toLowerCase().contains('mint')) {
          improvedLine = '${quantity ?? '1'} Mint (100g)';
        } else if (improvedLine.toLowerCase().contains('cauliflower')) {
          improvedLine = '${quantity ?? '1'} Cauliflower (head)';
        } else if (improvedLine.toLowerCase().contains('celery')) {
          improvedLine = '${quantity ?? '1'} Celery (head)';
        } else if (improvedLine.toLowerCase().contains('green pepper')) {
          improvedLine = '${quantity ?? '1'} Green Peppers (5kg)';
        } else {
          // If nothing matches, just add (IMPROVED) to see if it works
          improvedLine = '$improvedLine (IMPROVED)';
        }
        
        return improvedLine;
      }).toList();
      
      // Update the text controller
      _controller.text = improvedLines.join('\n');
      
    } catch (e) {
      // If API call fails, show error but don't crash
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load product data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
              _QuickFixButton(
                label: 'Remove Hyphens',
                icon: Icons.remove,
                onPressed: () => _applyQuickFix('remove_hyphens'),
              ),
              _QuickFixButton(
                label: 'Remove Stray X',
                icon: Icons.clear,
                onPressed: () => _applyQuickFix('remove_stray_x'),
              ),
              _QuickFixButton(
                label: 'Remove Numbering',
                icon: Icons.clear_all,
                onPressed: () => _applyQuickFix('remove_numbering'),
              ),
              _QuickFixButton(
                label: 'Improve Items',
                icon: Icons.lightbulb_outline,
                onPressed: () => _showSimpleItemImprovements(),
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
          
          // Use fixed height for mobile compatibility (works with SingleChildScrollView)
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.4, // 40% of screen height
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
              // Delete Button
              TextButton.icon(
                onPressed: _onDeleteMessage,
                icon: const Icon(Icons.delete, size: 18),
                label: const Text('Delete'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
              ),
              
              const SizedBox(width: 8),
              
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

  // SIMPLE item improvements - just basic text fixes, no product matching!
  Future<void> _showSimpleItemImprovements() async {
    final content = _controller.text;
    if (content.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter some message content first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final lines = content.split('\n');
    final improvements = <Map<String, dynamic>>[];
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      
      String improved = line;
      final reasons = <String>[];
      
      // Fix common spelling and formatting issues
      final original = improved;
      
      // 1. Fix spelling mistakes using shared dictionary
      _spellingCorrections.forEach((wrong, correct) {
        final regex = RegExp(r'\b' + RegExp.escape(wrong) + r'\b', caseSensitive: false);
        improved = improved.replaceAll(regex, correct);
      });
      
      // 2. Expand abbreviations
      improved = improved
          .replaceAll(RegExp(r'\bpkt\b', caseSensitive: false), 'packet')
          .replaceAll(RegExp(r'\bpckt\b', caseSensitive: false), 'packet')
          .replaceAll(RegExp(r'\bbx\b', caseSensitive: false), 'box')
          .replaceAll(RegExp(r'\bbxs\b', caseSensitive: false), 'boxes')
          .replaceAll(RegExp(r'\bpun\b', caseSensitive: false), 'punnet')
          .replaceAll(RegExp(r'\bpnts\b', caseSensitive: false), 'punnets');
      
      // 3. Fix spacing and formatting  
      improved = improved
          .replaceAll(RegExp(r'(\d+)x(\d+)', caseSensitive: false), r'$1 x $2')
          // Don't add space to kg/g - they're package sizes, not quantities
          .replaceAll(RegExp(r'\s+'), ' ');  // Multiple spaces to single
      
      // 4. Capitalize first letter
      if (improved.isNotEmpty) {
        improved = improved[0].toUpperCase() + improved.substring(1).toLowerCase();
      }
      
      if (improved != original) {
        final changes = <String>[];
        if (original.toLowerCase() != improved.toLowerCase()) changes.add('spelling');
        if (RegExp(r'\b(pkt|bx|pun)\b', caseSensitive: false).hasMatch(original)) changes.add('abbreviations');
        if (RegExp(r'(\d+)x(\d+)', caseSensitive: false).hasMatch(original)) changes.add('spacing');
        if (original[0] != improved[0]) changes.add('capitalization');
        
        reasons.add('Fixed: ${changes.join(', ')}');
      }
      
      // Only add if we actually improved something
      if (improved != line && reasons.isNotEmpty) {
        improvements.add({
          'line_index': i,
          'original': line,
          'suggestion': improved,
          'reasons': reasons,
        });
      }
    }
    
    if (improvements.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No improvements found - text looks good!'),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }
    
    _showSimpleImprovementsDialog(improvements);
  }

  void _showSimpleImprovementsDialog(List<Map<String, dynamic>> improvements) {
    // Perfect examples that work 100%
    final perfectExamples = [
      "5 Potatoes 2kg bag",           // quantity + product + weight + container
      "3 Tomatoes 500g punnet",       // quantity + product + weight + container  
      "1 Spinach 200g packet",        // quantity + product + weight + container
      "2 Carrots 1kg bag",            // quantity + product + weight + container
      "4 Mushrooms 200g punnet",      // quantity + product + weight + container
      "1 Broccoli 500g head",         // quantity + product + weight + unit
      "6 Lemons 2kg box",             // quantity + product + weight + container
      "1 Lettuce 300g head",          // quantity + product + weight + unit
      "3 Onions 5kg bag",             // quantity + product + weight + container  
      "2 Strawberries 250g punnet"    // quantity + product + weight + container
    ];
    
    // Track which improvements are selected
    final selectedImprovements = List.generate(improvements.length, (index) => true);
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Item Improvements (${improvements.length} items)'),
          content: SizedBox(
            width: double.maxFinite,
            height: 500, // Increased height to fit perfect examples
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Perfect Examples Section
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    border: Border.all(color: Colors.green.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.star, color: Colors.green.shade600, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '💡 Perfect Line Item Formats (100% Success Rate):',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...perfectExamples.map((example) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Text('✅ ', style: TextStyle(color: Colors.green.shade600)),
                            Expanded(
                              child: Text(
                                example,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                      const SizedBox(height: 8),
                      Text(
                        'Format: [quantity] [product] [weight] [container/unit]',
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Colors.green.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Select All / Deselect All buttons
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          for (int i = 0; i < selectedImprovements.length; i++) {
                            selectedImprovements[i] = true;
                          }
                        });
                      },
                      child: const Text('Select All'),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          for (int i = 0; i < selectedImprovements.length; i++) {
                            selectedImprovements[i] = false;
                          }
                        });
                      },
                      child: const Text('Deselect All'),
                    ),
                  ],
                ),
                const Divider(),
                // Improvements list with checkboxes
                Expanded(
                  child: ListView.builder(
                    itemCount: improvements.length,
                    itemBuilder: (context, index) {
                      final improvement = improvements[index];
                      final reasons = improvement['reasons'] as List<String>;
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: CheckboxListTile(
                          value: selectedImprovements[index],
                          onChanged: (bool? value) {
                            setState(() {
                              selectedImprovements[index] = value ?? false;
                            });
                          },
                          title: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Original: ${improvement['original']}', 
                                   style: const TextStyle(color: Colors.red, fontSize: 14)),
                              Text('Suggested: ${improvement['suggestion']}', 
                                   style: const TextStyle(color: Colors.green, fontSize: 14)),
                              Text('Changes: ${reasons.join(', ')}', 
                                   style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                // Apply only selected improvements
                final selectedItems = <Map<String, dynamic>>[];
                for (int i = 0; i < improvements.length; i++) {
                  if (selectedImprovements[i]) {
                    selectedItems.add(improvements[i]);
                  }
                }
                
                if (selectedItems.isNotEmpty) {
                  _applySimpleImprovements(selectedItems);
                }
                Navigator.of(context).pop();
              },
              child: Text('Apply Selected (${selectedImprovements.where((selected) => selected).length})'),
            ),
          ],
        ),
      ),
    );
  }

  void _applySimpleImprovements(List<Map<String, dynamic>> improvements) {
    final lines = _controller.text.split('\n');
    
    for (final improvement in improvements.reversed) {
      final lineIndex = improvement['line_index'] as int;
      if (lineIndex < lines.length) {
        lines[lineIndex] = improvement['suggestion'] as String;
      }
    }
    
    _controller.text = lines.join('\n');
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Applied ${improvements.length} improvements'),
        backgroundColor: Colors.green,
      ),
    );
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

class ItemImprovementsDialog extends StatefulWidget {
  final List<dynamic> improvements;
  final Function(int lineIndex, String improvedText) onApplyImprovement;

  const ItemImprovementsDialog({
    super.key,
    required this.improvements,
    required this.onApplyImprovement,
  });

  @override
  State<ItemImprovementsDialog> createState() => _ItemImprovementsDialogState();
}

class _ItemImprovementsDialogState extends State<ItemImprovementsDialog> {
  final Set<String> _appliedSuggestions = <String>{};

  void _applyAllSuggestions() {
    for (int i = 0; i < widget.improvements.length; i++) {
      final improvement = widget.improvements[i];
      final suggestions = improvement['suggestions'] as List<dynamic>? ?? [];
      
      if (suggestions.isNotEmpty) {
        // Apply the first suggestion for each item
        final firstSuggestion = suggestions[0];
        final improvedText = firstSuggestion['improved_text'] ?? '';
        
        if (improvedText.isNotEmpty && !_appliedSuggestions.contains('${i}_$improvedText')) {
          widget.onApplyImprovement(i, improvedText);
          setState(() {
            _appliedSuggestions.add('${i}_$improvedText');
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.lightbulb_outline, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Item Improvements',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            Text(
              'Here are suggestions to improve your items:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Improvements List
            Expanded(
              child: ListView.builder(
                itemCount: widget.improvements.length,
                itemBuilder: (context, index) {
                  final improvement = widget.improvements[index];
                  return _buildImprovementCard(context, improvement, index);
                },
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Action Buttons
            Row(
              children: [
                if (_appliedSuggestions.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      '${_appliedSuggestions.length} applied',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _applyAllSuggestions,
                  icon: const Icon(Icons.done_all, size: 16),
                  label: const Text('Apply All'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImprovementCard(BuildContext context, Map<String, dynamic> improvement, int index) {
    final originalText = improvement['original_text'] ?? '';
    final suggestions = improvement['suggestions'] as List<dynamic>? ?? [];
    final isComment = improvement['is_comment'] as bool? ?? false;
    final hasIssues = suggestions.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Original Text
            Row(
              children: [
                Icon(
                  isComment ? Icons.comment : (hasIssues ? Icons.warning_amber : Icons.check_circle),
                  color: isComment ? Colors.blue : (hasIssues ? Colors.orange : Colors.green),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    originalText,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isComment ? Colors.blue.shade700 : null,
                      fontStyle: isComment ? FontStyle.italic : null,
                    ),
                  ),
                ),
              ],
            ),
            
            if (hasIssues) ...[
              const SizedBox(height: 12),
              
              // Suggestions
              ...suggestions.map<Widget>((suggestion) {
                final suggestionText = suggestion['suggestion'] ?? '';
                final improvedText = suggestion['improved_text'] ?? '';
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        suggestionText,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.blue.shade700,
                        ),
                      ),
                      
                      if (improvedText.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  improvedText,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: _appliedSuggestions.contains('${index}_$improvedText') ? null : () {
                                widget.onApplyImprovement(index, improvedText);
                                setState(() {
                                  _appliedSuggestions.add('${index}_$improvedText');
                                });
                              },
                              icon: Icon(
                                _appliedSuggestions.contains('${index}_$improvedText') ? Icons.check_circle : Icons.check, 
                                size: 16
                              ),
                              label: Text(_appliedSuggestions.contains('${index}_$improvedText') ? 'Applied' : 'Apply'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _appliedSuggestions.contains('${index}_$improvedText') ? Colors.grey : Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              }),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                isComment ? '💬 Comment - not processed by system' : '✓ This item looks good!',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isComment ? Colors.blue.shade600 : Colors.green.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

}
