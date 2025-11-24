/// Utility functions for formatting stock quantities with proper unit display
/// 
/// This utility handles the display of stock quantities based on unit type:
/// - Continuous units (kg, g, ml, l): Show decimals (e.g., "4.6 kg")
/// - Discrete units (punnet, each, box, etc.): Show whole numbers with weight if available (e.g., "6 punnets (0.6 kg)")
library;

/// Format stock quantity using backend-provided count and weight values
/// 
/// For discrete units (punnet, each, box, etc.): show count and weight if available
/// For continuous units (kg, g, ml, l): show weight with decimals
/// 
/// Parameters:
/// - [unit]: The product unit (e.g., 'punnet', 'kg', 'each')
/// - [count]: The stock count (whole number) - optional
/// - [weightKg]: The stock weight in kg - optional
/// 
/// Returns formatted string:
/// - For continuous units: "4.6" (weight only)
/// - For discrete units with both: "6 (0.6 kg)" (count and weight)
/// - For discrete units with count only: "6" (count only)
/// - No stock: "0"
String formatStockQuantity({
  required String unit,
  int? count,
  double? weightKg,
}) {
  final unitLower = unit.toLowerCase();
  
  // For continuous units (kg, g, ml, l), show weight with decimals
  if (unitLower == 'kg' || unitLower == 'g' || unitLower == 'ml' || unitLower == 'l') {
    if (weightKg != null && weightKg > 0) {
      return weightKg.toStringAsFixed(1);
    }
    return '0.0';
  }
  
  // For discrete units (punnet, each, box, etc.), show count and weight
  if (count != null && count > 0) {
    if (weightKg != null && weightKg > 0) {
      // Show both count and weight: "6 (0.6 kg)" for 6 punnets = 0.6 kg
      return '$count (${weightKg.toStringAsFixed(1)} kg)';
    } else {
      // Only count available, show whole number
      return count.toString();
    }
  }
  
  // No stock available
  return '0';
}

/// Extract stock count and weight from stock map (from API response)
/// 
/// Handles both new format (with count/weight fields) and legacy format (backward compatibility)
/// 
/// Parameters:
/// - [stock]: Stock map from API response
/// - [unit]: Product unit for determining display format
/// 
/// Returns formatted stock quantity string
String formatStockFromMap(Map<String, dynamic>? stock, String unit) {
  if (stock == null) {
    return '0';
  }
  
  // Try new format first (with count and weight fields)
  final count = (stock['available_quantity_count'] as num?)?.toInt();
  final weightKg = (stock['available_quantity_kg'] as num?)?.toDouble();
  
  if (count != null || weightKg != null) {
    return formatStockQuantity(
      unit: unit,
      count: count,
      weightKg: weightKg,
    );
  }
  
  // Fallback to legacy format (backward compatibility)
  final availableQuantity = (stock['available_quantity'] as num?)?.toDouble() ?? 0.0;
  final unitLower = unit.toLowerCase();
  
  // For continuous units, show with decimals
  if (unitLower == 'kg' || unitLower == 'g' || unitLower == 'ml' || unitLower == 'l') {
    return availableQuantity.toStringAsFixed(1);
  }
  
  // For discrete units, show as whole number
  return availableQuantity.toInt().toString();
}

