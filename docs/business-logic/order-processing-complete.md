# ORDER PROCESSING SYSTEM

## Overview
The order processing system is the core of the Family Farms business, connecting customers, inventory, pricing, procurement, and financial systems. This document explains the complete flow from order placement to fulfillment.

## 🔄 ORDER LIFECYCLE

### 1. ORDER PLACEMENT
**Sources:**
- **WhatsApp Messages**: Scraped from "ORDERS Restaurants" group
- **Flutter App**: Manual order entry by staff
- **API Endpoints**: Direct integration

**Process:**
1. Order received and parsed
2. Customer identification/creation
3. Product matching and validation
4. Price calculation using customer price lists
5. Order creation with status `pending`

### 2. ORDER VALIDATION
**Automatic Checks:**
- Product availability in inventory
- Customer credit limits
- Delivery date validation (Monday/Thursday → Tuesday/Wednesday/Friday)
- Minimum order quantities

**Manual Review:**
- Staff can review and modify orders
- Price adjustments if needed
- Special instructions handling

### 3. ORDER CONFIRMATION
**Status Changes:**
- `pending` → `confirmed`
- Customer notification (if configured)
- Inventory reservation
- Procurement triggers (if stock low)

### 4. ORDER FULFILLMENT
**Picking Process:**
- Generate picking lists
- Update inventory levels
- Quality control checks
- Packaging and labeling

**Status Updates:**
- `confirmed` → `picked` → `packed` → `dispatched`

### 5. ORDER DELIVERY
**Final Steps:**
- Delivery confirmation
- Invoice generation
- Payment tracking
- Customer feedback

## 💰 PRICING SYSTEM

### Customer Price Lists
**Structure:**
```
CustomerPriceList
├── customer (User)
├── pricing_rule (PricingRule)
├── effective_from/until (Date range)
├── status (active/inactive/draft)
└── items (CustomerPriceListItem[])
    ├── product
    ├── base_price
    ├── markup_percentage
    ├── customer_price_excl_vat
    └── customer_price_incl_vat
```

**Price Calculation Flow:**
1. **Check Customer Price List**: Look for active price list for customer
2. **Apply Pricing Rule**: Use customer's segment pricing rule
3. **Market Price Integration**: Factor in current market prices
4. **Markup Application**: Apply customer-specific markup
5. **VAT Calculation**: Add 15% VAT for final price
6. **Fallback**: Use base product price if no customer pricing

### Pricing Rules
**Customer Segments:**
- `premium` - Highest volume customers (lowest markup)
- `standard` - Regular customers (standard markup)
- `new` - New customers (higher markup)
- `wholesale` - Bulk buyers (special pricing)

**Rule Components:**
- `base_markup_percentage` - Base markup for segment
- `minimum_margin_percentage` - Minimum profit margin
- `seasonal_adjustment` - Seasonal price adjustments
- `volume_discount_threshold` - Bulk order discounts

### Price List Management
**Flutter App Features:**
- ✅ View all customer price lists
- ✅ Create new price lists
- ✅ Edit price list details (dates, notes)
- ✅ Change pricing rules
- ✅ Bulk operations (activate, send, change rules)
- ✅ Individual item price adjustments
- ✅ Regenerate prices from market data

**Pricing Rule Management:**
- ✅ Create new pricing rules
- ✅ Edit existing rules
- ✅ Set effective dates
- ✅ Customer segment assignment
- ✅ Markup and margin settings

## 📦 INVENTORY IMPACT

### Stock Levels
**Order Impact:**
1. **Order Placement**: No immediate stock impact
2. **Order Confirmation**: Stock reserved (not yet deducted)
3. **Order Picking**: Stock deducted from available inventory
4. **Order Cancellation**: Reserved stock released

**Inventory Types:**
- **Finished Products**: Ready-to-sell items
- **Raw Materials**: Ingredients for production
- **Work in Progress**: Items being processed

### Stock Movements
**Automatic Tracking:**
```
StockMovement
├── movement_type (sale, purchase, adjustment, waste, production)
├── reference_number (Order number, PO number, etc.)
├── product/raw_material
├── quantity (positive/negative)
├── user (who made the change)
└── notes (reason/details)
```

### Low Stock Alerts
**Triggers:**
- Stock level below `minimum_stock`
- High demand products running low
- Seasonal stock requirements

**Actions:**
- Generate `StockAlert`
- Create `ProcurementRecommendation`
- Notify purchasing team

## 🛒 PROCUREMENT INTEGRATION

### Automatic Procurement
**Triggers:**
1. **Stock Analysis**: Daily analysis identifies low stock
2. **Order Patterns**: Predictive analysis of upcoming demand
3. **Seasonal Factors**: Seasonal demand adjustments
4. **Lead Times**: Account for supplier delivery times

### Procurement Recommendations
**Generated When:**
- Stock level below reorder point
- Projected demand exceeds available stock
- Seasonal stock buildup needed
- New product introduction

**Recommendation Details:**
- Suggested supplier
- Recommended quantity
- Urgency level (low/medium/high/critical)
- Cost estimates
- Delivery timeline

### Purchase Order Creation
**From Recommendations:**
1. Review procurement recommendations
2. Select items to order
3. Choose suppliers
4. Generate purchase orders
5. Send to suppliers
6. Track delivery status

## 💵 COSTING & FINANCIAL IMPACT

### Cost Tracking
**Product Costs:**
- **Purchase Cost**: What we pay suppliers
- **Production Cost**: Raw materials + labor + overhead
- **Landed Cost**: Purchase cost + transport + handling
- **Average Cost**: Weighted average of all purchases

### Margin Analysis
**Per Order:**
- Total revenue (customer prices)
- Total cost (product costs)
- Gross margin (revenue - cost)
- Margin percentage

**Per Product:**
- Sales volume
- Revenue contribution
- Cost analysis
- Profitability ranking

### Financial Reports
**Available Reports:**
- Daily sales summary
- Weekly price reports
- Monthly profitability analysis
- Customer profitability
- Product performance
- Supplier cost analysis

## 🔧 SYSTEM INTEGRATION

### WhatsApp Integration
**Message Processing:**
1. **Scraping**: Python scraper extracts messages
2. **Classification**: AI classifies message types
3. **Company Extraction**: Identify customer companies
4. **Item Parsing**: Extract products and quantities
5. **Order Creation**: Generate Django orders

### Flutter App Integration
**Order Management:**
- View all orders
- Edit order details
- Update order status
- Generate reports
- Manage pricing

### API Endpoints
**Key Endpoints:**
- `POST /orders/` - Create new order
- `GET /orders/` - List orders
- `PATCH /orders/{id}/` - Update order
- `GET /inventory/stock-levels/` - Check stock
- `POST /inventory/customer-price-lists/` - Generate price lists
- `GET /procurement/recommendations/` - Get procurement needs

## 📋 TESTING SCENARIOS

### Basic Order Flow
1. **Create Customer**: Add new restaurant customer
2. **Set Up Pricing**: Create price list with pricing rule
3. **Place Order**: Create order via WhatsApp or Flutter
4. **Check Pricing**: Verify customer-specific prices applied
5. **Confirm Order**: Move to confirmed status
6. **Check Inventory**: Verify stock reservation
7. **Pick Order**: Update to picked status
8. **Check Stock Movement**: Verify inventory deduction

### Price List Testing
1. **Create Pricing Rule**: Set up customer segment rule
2. **Generate Price List**: Create customer price list
3. **Test Price Calculation**: Verify markup application
4. **Edit Prices**: Modify individual item prices
5. **Change Rule**: Switch to different pricing rule
6. **Regenerate Prices**: Update from market data

### Inventory Testing
1. **Check Stock Levels**: View current inventory
2. **Place Large Order**: Test stock reservation
3. **Trigger Low Stock**: Create procurement recommendation
4. **Manual Adjustment**: Test stock adjustment functionality
5. **Production Impact**: Test raw material consumption

### Procurement Testing
1. **Generate Recommendations**: Run stock analysis
2. **Create Purchase Order**: From recommendations
3. **Receive Stock**: Update inventory levels
4. **Cost Impact**: Verify cost calculations

## 🚨 IMPORTANT NOTES

### Data Integrity
- All price calculations are logged
- Stock movements are fully auditable
- Order changes maintain history
- Customer pricing is version controlled

### Performance Considerations
- Price lists are cached for performance
- Stock levels updated in real-time
- Bulk operations use database transactions
- Query optimization prevents N+1 problems

### Security
- All inputs are validated and sanitized
- User permissions control access
- Audit trails for all changes
- Fail-fast error handling

### Business Rules
- Orders can only be placed on Monday/Thursday
- Delivery dates are Tuesday/Wednesday/Friday
- Minimum order quantities may apply
- Credit limits are enforced
- Seasonal pricing adjustments are automatic

## 🎯 SUCCESS CRITERIA

### Order Processing
- ✅ Orders created from WhatsApp messages
- ✅ Customer-specific pricing applied
- ✅ Inventory levels updated correctly
- ✅ Procurement triggered when needed
- ✅ Financial tracking accurate

### Price Management
- ✅ Price lists can be created and edited
- ✅ Pricing rules can be managed
- ✅ Bulk operations work correctly
- ✅ Market price integration functional
- ✅ Customer segments properly handled

### System Integration
- ✅ WhatsApp → Django → Flutter flow works
- ✅ Real-time inventory updates
- ✅ Automated procurement recommendations
- ✅ Financial reporting accurate
- ✅ User-friendly error handling

---

**The order system is the heart of the Family Farms operation. When working correctly, it should seamlessly connect customer requests to inventory management, pricing, procurement, and financial tracking, providing a complete business management solution.**
