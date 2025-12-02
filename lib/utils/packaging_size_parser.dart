/// Utility to parse packaging size and convert to kg
/// Handles formats like "100g", "1kg", "0.5kg", "500g", etc.
class PackagingSizeParser {
  /// Parse packaging size string and convert to kg
  /// 
  /// Examples:
  ///   "100g" -> 0.1
  ///   "1kg" -> 1.0
  ///   "0.5kg" -> 0.5
  ///   "500g" -> 0.5
  ///   null -> null
  /// 
  /// Returns weight in kg, or null if cannot parse
  static double? parseToKg(String? packagingSize) {
    if (packagingSize == null || packagingSize.trim().isEmpty) {
      return null;
    }
    
    final size = packagingSize.trim().toLowerCase();
    
    // Remove any spaces
    final cleanSize = size.replaceAll(' ', '');
    
    // Try to match patterns: "100g", "1kg", "0.5kg", "500g", etc.
    final kgMatch = RegExp(r'^(\d+(?:\.\d+)?)\s*kg$').firstMatch(cleanSize);
    if (kgMatch != null) {
      return double.tryParse(kgMatch.group(1) ?? '');
    }
    
    final gMatch = RegExp(r'^(\d+(?:\.\d+)?)\s*g$').firstMatch(cleanSize);
    if (gMatch != null) {
      final grams = double.tryParse(gMatch.group(1) ?? '');
      if (grams != null) {
        return grams / 1000.0;  // Convert grams to kg
      }
    }
    
    // Try to parse as number (assume kg if no unit)
    final numberMatch = RegExp(r'^(\d+(?:\.\d+)?)$').firstMatch(cleanSize);
    if (numberMatch != null) {
      return double.tryParse(numberMatch.group(1) ?? '');
    }
    
    return null;
  }
  
  /// Calculate weight from count and packaging size
  /// 
  /// Returns calculated weight in kg, or null if cannot calculate
  static double? calculateWeightFromPackaging({
    required int count,
    required String? packagingSize,
  }) {
    final packagingKg = parseToKg(packagingSize);
    if (packagingKg == null || packagingKg <= 0) {
      return null;
    }
    
    return count * packagingKg;
  }
  
  /// Check if weight can be calculated from packaging size
  static bool canCalculateWeight(String? packagingSize) {
    return parseToKg(packagingSize) != null;
  }
  
  /// Extract packaging size from product name as fallback
  /// 
  /// Examples:
  ///   "Cabbage (1kg)" -> "1kg"
  ///   "Potatoes (2kg bag)" -> "2kg"
  ///   "Basil 100g packet" -> "100g"
  ///   "Tomatoes 5kg box" -> "5kg"
  ///   "Carrots 500g" -> "500g"
  /// 
  /// Returns packaging size string like "1kg", "100g", or null if not found
  static String? extractFromProductName(String? productName) {
    if (productName == null || productName.trim().isEmpty) {
      return null;
    }
    
    // Pattern 1: Product Name (Size) or (Size container)
    // Matches: "Cabbage (1kg)", "Potatoes (2kg bag)", "Basil (100g packet)"
    final pattern1 = RegExp(r'\((\d+(?:\.\d+)?)\s*(kg|g|ml|l)\s*(?:bag|box|packet|punnet|bunch|head)?\)', caseSensitive: false);
    final match1 = pattern1.firstMatch(productName);
    if (match1 != null) {
      return '${match1.group(1)}${match1.group(2)}';
    }
    
    // Pattern 2: Product Name Size container
    // Matches: "Tomatoes 5kg box", "Carrots 500g bag", "Basil 100g packet"
    final pattern2 = RegExp(r'(\d+(?:\.\d+)?)\s*(kg|g|ml|l)\s+(?:bag|box|packet|punnet|bunch|head)', caseSensitive: false);
    final match2 = pattern2.firstMatch(productName);
    if (match2 != null) {
      return '${match2.group(1)}${match2.group(2)}';
    }
    
    // Pattern 3: Product Name Size (standalone)
    // Matches: "Carrots 500g", "Tomatoes 2kg" (but not "5 Carrots")
    final pattern3 = RegExp(r'(\d+(?:\.\d+)?)\s*(kg|g|ml|l)\b(?!\s*(?:bag|box|packet|punnet|bunch|head|each|piece))', caseSensitive: false);
    final match3 = pattern3.firstMatch(productName);
    if (match3 != null) {
      // Verify it's not a quantity by checking context
      final afterMatch = productName.substring(match3.end).trim();
      if (afterMatch.isEmpty || 
          RegExp(r'^(bag|box|packet|punnet|bunch|head|each|piece)', caseSensitive: false).hasMatch(afterMatch.toLowerCase())) {
        return '${match3.group(1)}${match3.group(2)}';
      }
    }
    
    // Pattern 4: Size x Product or Product x Size
    // Matches: "1kg Cabbage", "500g Basil", "Cabbage x 1kg"
    final pattern4a = RegExp(r'(\d+(?:\.\d+)?)\s*(kg|g|ml|l)\s*(?:x|×|\*)?\s*[A-Za-z]', caseSensitive: false);
    final match4a = pattern4a.firstMatch(productName);
    if (match4a != null) {
      return '${match4a.group(1)}${match4a.group(2)}';
    }
    
    final pattern4b = RegExp(r'[A-Za-z]\s*(?:x|×|\*)\s*(\d+(?:\.\d+)?)\s*(kg|g|ml|l)', caseSensitive: false);
    final match4b = pattern4b.firstMatch(productName);
    if (match4b != null) {
      return '${match4b.group(1)}${match4b.group(2)}';
    }
    
    return null;
  }
}

