# Intelligent Pricing System - Flutter UI

## Overview

The Flutter frontend provides a beautiful, modern interface for the intelligent pricing system, offering real-time market volatility management, dynamic customer pricing, and comprehensive business intelligence through an intuitive desktop application.

## 🎨 UI Architecture

### Modern Flutter Stack
- **Flutter 3.16+** with Material Design 3
- **Riverpod** for state management and providers
- **Go Router** for navigation and routing
- **Dio HTTP Client** for API communication
- **Responsive Design** optimized for desktop use

### Design Principles
- **Professional Business Interface** - Clean, modern design suitable for enterprise use
- **Real-time Data** - Live updates from Django backend APIs
- **Visual Intelligence** - Color-coded indicators for market volatility and pricing status
- **Intuitive Navigation** - Seamless flow between different pricing functions
- **Responsive Layout** - Adapts to different screen sizes and window states

## 📱 Core UI Components

### 1. Dynamic Pricing Dashboard
**Route**: `/pricing`  
**File**: `lib/features/pricing/pricing_dashboard_page.dart`

**Features**:
- **Intelligent Stats Cards** - Real-time pricing rules, market volatility, active price lists, and price alerts
- **Price Volatility Alerts** - Visual alerts for significant market changes
- **Quick Actions** - One-click stock analysis, report generation, and market data upload
- **Floating Action Button** - Quick price list generation for all customers

**Visual Elements**:
- Color-coded stats cards with real-time data
- Alert banners for price volatility warnings
- Professional card-based layout with proper spacing
- Interactive elements with hover states and animations

### 2. Pricing Rules Management
**Component**: `PricingRulesSection`  
**File**: `lib/features/pricing/widgets/pricing_rules_section.dart`

**Features**:
- **Visual Rule Cards** - Customer segment badges, markup percentages, volatility adjustments
- **Interactive Details** - Tap to view full rule configuration and example calculations
- **Segment Color Coding** - Premium (Indigo), Standard (Green), Budget (Amber), Wholesale (Violet), Retail (Red)
- **Rule Testing** - Test markup calculations with different market prices and volatility levels

**UI Components**:
```dart
// Pricing Rule Card Example
Container(
  child: Card(
    child: Column(
      children: [
        // Segment Badge
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: rule.segmentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(rule.segmentDisplayName),
        ),
        // Rule Details
        _buildMetric('Base Markup', '${rule.baseMarkupPercentage}%'),
        _buildMetric('Volatility Adj.', '+${rule.volatilityAdjustment}%'),
        _buildMetric('Min Margin', '${rule.minimumMarginPercentage}%'),
      ],
    ),
  ),
)
```

### 3. Market Volatility Visualization
**Component**: `MarketVolatilitySection`  
**File**: `lib/features/pricing/widgets/market_volatility_section.dart`

**Features**:
- **Volatility Dashboard** - Real-time analysis of 30-day price movements
- **Color-coded Alerts** - Extremely Volatile (Red), Highly Volatile (Orange), Stable (Green)
- **Impact Analysis** - Shows affected customers and price ranges
- **Interactive Details** - Detailed volatility breakdown and recommendations

**Visual Indicators**:
- **Volatility Levels**: Color-coded bars and badges
- **Price Ranges**: Clear display of min/max prices
- **Trend Indicators**: Visual arrows and percentage changes
- **Customer Impact**: Number of affected customers displayed

### 4. Customer Price Lists Management
**Component**: `CustomerPriceListsSection`  
**File**: `lib/features/pricing/widgets/customer_price_lists_section.dart`

**Features**:
- **Smart Price List Cards** - Status tracking, effective periods, total values
- **Automated Actions** - Activate and send price lists with one tap
- **Price Change Tracking** - Visual indicators for price increases/decreases
- **Detailed Views** - Complete price list breakdown with market data sources

**Status Management**:
```dart
// Status Color Coding
Color get statusColor {
  switch (status) {
    case 'draft': return Color(0xFF6B7280);      // Gray
    case 'generated': return Color(0xFF3B82F6);  // Blue
    case 'sent': return Color(0xFF8B5CF6);       // Purple
    case 'acknowledged': return Color(0xFF10B981); // Green
    case 'active': return Color(0xFF059669);     // Emerald
    case 'expired': return Color(0xFFEF4444);    // Red
  }
}
```

## 🎯 Data Models

### PricingRule Model
```dart
class PricingRule {
  final int id;
  final String name;
  final String description;
  final String customerSegment;
  final double baseMarkupPercentage;
  final double volatilityAdjustment;
  final double minimumMarginPercentage;
  final Map<String, dynamic> categoryAdjustments;
  final double trendMultiplier;
  final double seasonalAdjustment;
  final bool isActive;
  final DateTime effectiveFrom;
  final DateTime? effectiveUntil;
  final bool isEffectiveNow;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int createdBy;
  final String createdByName;
  
  // Visual properties
  Color get segmentColor { /* segment-specific colors */ }
}
```

### MarketVolatilityData Model
```dart
class MarketVolatilityData {
  final String productName;
  final double minPrice;
  final double maxPrice;
  final double volatilityPercentage;
  final String volatilityLevel;
  final int affectedCustomers;
  
  // Visual properties
  Color get volatilityColor { /* level-specific colors */ }
  String get formattedPriceRange { /* formatted display */ }
  String get formattedVolatility { /* percentage with sign */ }
}
```

### CustomerPriceList Model
```dart
class CustomerPriceList {
  final int id;
  final String customerName;
  final String pricingRuleName;
  final String status;
  final DateTime effectiveFrom;
  final DateTime effectiveUntil;
  final int totalProducts;
  final double averageMarkupPercentage;
  final double totalListValue;
  final List<CustomerPriceListItem>? items;
  
  // Visual properties
  Color get statusColor { /* status-specific colors */ }
  String get formattedEffectivePeriod { /* date range */ }
  String get formattedTotalValue { /* currency format */ }
}
```

## 🔄 State Management

### Riverpod Providers
```dart
// Pricing data providers
final pricingRulesProvider = FutureProvider<List<PricingRule>>((ref) async {
  final apiService = ref.read(apiServiceProvider);
  return apiService.getPricingRules(effective: true);
});

final marketVolatilityProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final apiService = ref.read(apiServiceProvider);
  return apiService.getMarketVolatilityDashboard(days: 30);
});

final customerPriceListsProvider = FutureProvider<List<CustomerPriceList>>((ref) async {
  final apiService = ref.read(apiServiceProvider);
  return apiService.getCustomerPriceLists(current: true);
});

final priceAlertsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final apiService = ref.read(apiServiceProvider);
  return apiService.getPriceAlerts(acknowledged: false);
});
```

### API Integration
```dart
// Extended API service with 20+ pricing endpoints
class ApiService {
  // Pricing Rules Management
  Future<List<PricingRule>> getPricingRules({String? segment, bool? isActive});
  Future<PricingRule> createPricingRule(Map<String, dynamic> ruleData);
  Future<Map<String, dynamic>> testPricingRuleMarkup(int ruleId, {double marketPrice, String volatilityLevel});
  
  // Market Intelligence
  Future<List<MarketPrice>> getMarketPrices({String? supplier, DateTime? dateFrom});
  Future<Map<String, dynamic>> getMarketVolatilityDashboard({int days = 30});
  
  // Customer Price Lists
  Future<List<CustomerPriceList>> getCustomerPriceLists({int? customerId, String? status});
  Future<Map<String, dynamic>> generateCustomerPriceListsFromMarketData({required List<int> customerIds, required int pricingRuleId});
  Future<CustomerPriceList> activateCustomerPriceList(int listId);
  Future<CustomerPriceList> sendCustomerPriceListToCustomer(int listId);
  
  // Business Intelligence
  Future<List<Map<String, dynamic>>> getWeeklyReports({String? status});
  Future<Map<String, dynamic>> generateCurrentWeekReport();
}
```

## 🎨 Visual Design System

### Color Palette
```dart
// Customer Segments
const premiumColor = Color(0xFF6366F1);    // Indigo
const standardColor = Color(0xFF10B981);   // Emerald
const budgetColor = Color(0xFFF59E0B);     // Amber
const wholesaleColor = Color(0xFF8B5CF6);  // Violet
const retailColor = Color(0xFFEF4444);     // Red

// Volatility Levels
const extremeVolatilityColor = Color(0xFFDC2626);  // Red-600
const highVolatilityColor = Color(0xFFEA580C);     // Orange-600
const volatileColor = Color(0xFFD97706);           // Amber-600
const stableColor = Color(0xFF059669);             // Emerald-600

// Status Colors
const draftColor = Color(0xFF6B7280);      // Gray
const generatedColor = Color(0xFF3B82F6);  // Blue
const sentColor = Color(0xFF8B5CF6);       // Purple
const activeColor = Color(0xFF059669);     // Emerald
const expiredColor = Color(0xFFEF4444);    // Red
```

### Typography
- **Headlines**: Bold, clear hierarchy
- **Body Text**: Readable, consistent sizing
- **Data Display**: Monospace for numbers, proper alignment
- **Labels**: Clear, descriptive, properly sized

### Spacing & Layout
- **Card Padding**: 16-20px for comfortable content spacing
- **Section Spacing**: 24-32px between major sections
- **Grid Layout**: Responsive columns that adapt to screen size
- **Button Spacing**: Consistent 8-16px margins

## 🚀 User Experience Features

### Interactive Elements
- **Hover States** - Visual feedback on interactive elements
- **Loading States** - Smooth loading indicators and skeleton screens
- **Error Handling** - User-friendly error messages and retry options
- **Success Feedback** - Clear confirmation of completed actions

### Navigation Flow
1. **Main Dashboard** → Overview of system status
2. **Dynamic Pricing** → Navigate to intelligent pricing management
3. **Market Intelligence** → Monitor volatility and price trends
4. **Customer Pricing** → Generate and manage price lists
5. **Quick Actions** → Run analysis and generate reports

### Responsive Design
- **Desktop Optimized** - Primary target for business use
- **Window Management** - Proper window sizing and constraints
- **Scalable UI** - Adapts to different screen resolutions
- **Professional Layout** - Business-appropriate design language

## 📊 Performance Characteristics

### Real-time Updates
- **Automatic Refresh** - Data refreshes on navigation and user action
- **Manual Refresh** - Pull-to-refresh and refresh buttons
- **Live Data** - Real-time connection to Django backend
- **Efficient Loading** - Parallel API calls for better performance

### Error Handling
- **Network Errors** - Graceful handling of connection issues
- **API Errors** - User-friendly error messages
- **Validation Errors** - Clear field-level validation feedback
- **Retry Mechanisms** - Automatic and manual retry options

### User Feedback
- **Loading Indicators** - Clear progress indication
- **Success Messages** - Confirmation of completed actions
- **Warning Alerts** - Important notifications for user attention
- **Status Updates** - Real-time status information

## 🔧 Technical Implementation

### Widget Architecture
```dart
// Main dashboard structure
class PricingDashboardPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(/* header with actions */),
      body: RefreshIndicator(
        onRefresh: () async { /* refresh all data */ },
        child: SingleChildScrollView(
          child: Column(
            children: [
              PricingStatsCards(/* real-time stats */),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        PricingRulesSection(/* rules management */),
                        MarketVolatilitySection(/* volatility dashboard */),
                      ],
                    ),
                  ),
                  Expanded(
                    child: CustomerPriceListsSection(/* price lists */),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showGeneratePriceListsDialog(),
        label: Text('Generate Price Lists'),
      ),
    );
  }
}
```

### Custom Widgets
- **StatsCard** - Reusable metric display cards
- **VolatilityCard** - Market volatility visualization
- **PriceListCard** - Customer price list management
- **AlertBanner** - Price volatility alerts
- **ActionButton** - Consistent action buttons

## 🎯 Business Value

### Operational Efficiency
- **One-Click Operations** - Complex business processes automated
- **Visual Intelligence** - Immediate understanding of market conditions
- **Automated Workflows** - From market data to customer pricing
- **Real-time Monitoring** - Live price volatility tracking

### User Experience
- **Professional Interface** - Business-appropriate design
- **Intuitive Navigation** - Clear, logical flow between functions
- **Visual Feedback** - Immediate response to user actions
- **Error Prevention** - Clear validation and confirmation dialogs

### Data Visualization
- **Color-coded Status** - Immediate visual understanding
- **Trend Indicators** - Clear display of price movements
- **Impact Analysis** - Visual representation of business impact
- **Performance Metrics** - Key business indicators prominently displayed

This Flutter UI represents a world-class interface for intelligent pricing management, combining beautiful design with powerful functionality to deliver exceptional user experience for complex business operations.
