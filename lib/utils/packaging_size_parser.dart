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
}

