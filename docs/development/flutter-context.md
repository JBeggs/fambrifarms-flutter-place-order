# 🌾 FAMBRI FARMS FLUTTER DEVELOPMENT CONTEXT

## 🎯 **EXECUTIVE SUMMARY**

This document provides comprehensive context for developing the **Fambri Farms Flutter Application** based on the complete backend system that has been built with **real WhatsApp data** and **authentic business workflows**. The backend contains **6 complete phases** of a digital transformation with real customer data, pricing intelligence, and operational workflows.

---

## 🏗️ **BACKEND SYSTEM OVERVIEW**

### **✅ COMPLETED PHASES (6/8)**

1. **✅ Data Extraction** - Real WhatsApp customer and supplier data
2. **✅ Supplier Network** - 3 suppliers with specialized roles
3. **✅ Customer Database** - 16 real customers with contact details
4. **✅ Product Catalog** - 63 products from actual farm inventory
5. **✅ User System** - Role-based access with real staff
6. **✅ Pricing Intelligence** - Market-driven dynamic pricing

### **🔄 REMAINING PHASES (2/8)**
7. **Order History Seeding** - Realistic order patterns
8. **Stock Level Integration** - Live inventory management

---

## 👥 **USER PERSONAS & ROLES**

### **🌾 FARM OPERATIONS TEAM**

#### **Karl - Farm Manager** 
- **Phone**: +27 76 655 4873 (Real WhatsApp contact)
- **Role**: Operations oversight, customer relationships, order approvals
- **Access**: Full admin access, pricing management, customer management
- **Key Functions**: 
  - Approve/reject orders
  - Manage customer relationships
  - Oversee pricing strategies
  - View comprehensive reports

#### **Hazvinei - Stock Taker**
- **Phone**: +27 61 674 9368 (Real WhatsApp contact)
- **Role**: Inventory management, SHALLOME stock reports
- **Access**: Inventory management, stock updates, alerts
- **Key Functions**:
  - Update stock levels (SHALLOME reports)
  - Create stock alerts
  - Manage inventory counts
  - Generate procurement recommendations

### **🏪 CUSTOMER SEGMENTS**

#### **Premium Restaurants (35% markup)**
- **Casa Bella** - Italian cuisine, premium ingredients
- **Pecanwood Golf Estate** - Large institutional orders
- **Culinary Institute** - Educational institution, diverse needs

#### **Standard Restaurants (25% markup)**
- **Maltos** - Detailed orders (deveined spinach, semi-ripe avos)
- **T-junction** - Lettuce and herb specialist
- **Venue** - Event catering supplies
- **Mugg and Bean** - High volume orders (30kg potato, 20kg onions)

#### **Budget Establishments (18% markup)**
- **Debonair Pizza** - Pizza ingredients focus
- **Wimpy Mooikloof** - Family restaurant supplies
- **Barchef Entertainment** - Bar garnishes (lemons, strawberries, mint)

#### **Private Customers (15% markup)**
- **Sylvia** (+27 73 621 2471) - "Tuesday orders" household basics
- **Marco** - Private customer, mixed vegetables and fruits
- **Arthur** - Simple orders "Arthur box x2"

---

## 🏭 **SUPPLIER ECOSYSTEM**

### **Fambri Farms Internal**
- **Contact**: Karl (Farm Manager)
- **Pricing**: Cost pricing (70% of retail)
- **Specialty**: Fresh daily harvest, all produce categories
- **Lead Time**: 0 days (internal)

### **Tania's Fresh Produce**
- **Contact**: Tania Mthembu
- **Pricing**: Premium emergency pricing (115% + 10-15% markup)
- **Specialty**: Emergency supply, herbs, quick delivery
- **Lead Time**: 0 days (same day delivery)

### **Mumbai Spice & Produce**
- **Contact**: Raj Patel (Owner), Priya Sharma (Sales Manager)
- **Pricing**: Specialty pricing (105% + 20% spice premium)
- **Specialty**: Spices, exotic vegetables, specialty items
- **Lead Time**: 1 day

---

## 📦 **PRODUCT CATALOG (63 Products)**

### **🥬 Vegetables (27 products)**
- **High Stock Items**: Butternut (60kg), Lemons (56kg), Cucumber (47)
- **Low Stock Items**: Oranges (0.6kg), Red Peppers (3kg)
- **Popular Items**: Mixed Lettuce, Potatoes, Tomatoes, Onions

### **🍎 Fruits (15 products)**
- **Premium Items**: Avocados (Soft/Hard/Semi-ripe), Grapes, Strawberries
- **Bulk Items**: Bananas, Lemons, Oranges
- **Seasonal Items**: Pineapple, Melons, Berries

### **🌿 Herbs & Spices (13 products)**
- **High Value**: Ginger (R150/kg), Turmeric (R150/kg), Rocket (R120/kg)
- **Daily Use**: Coriander, Parsley, Mint, Basil
- **Specialty**: Micro Herbs, Crushed Garlic

### **🍄 Mushrooms (3 products)**
- Button Mushrooms, Brown Mushrooms, Portabellini

### **⭐ Specialty Items (5 products)**
- Baby Corn, Cherry Tomatoes, Micro Herbs, Edible Flowers

---

## 💰 **PRICING INTELLIGENCE SYSTEM**

### **📊 Market Data**
- **1,890 Price Records** across 30 days
- **3 Market Sources**: Tshwane, Johannesburg, Pretoria
- **Dynamic Variations**: Seasonal, stock-level, supplier-specific

### **🎯 Customer-Specific Pricing**
- **13 Active Price Lists** with **385 Total Items**
- **Automatic Markup Application** based on customer segment
- **Real Examples**:
  - Casa Bella: R45.50 for Mixed Lettuce (52.1% markup)
  - Maltos: R35.20 for Mixed Lettuce (32.0% markup)
  - Marco: R28.80 for Mixed Lettuce (10.8% markup)

### **🔄 Procurement Intelligence**
- **Smart Recommendations** for low-stock items
- **Urgency Levels**: Urgent (same day), High (1 day), Medium (3 days)
- **Supplier Optimization** based on price and lead times

---

## 📱 **FLUTTER APP FEATURES TO IMPLEMENT**

### **🌾 FARM MANAGER DASHBOARD (Karl)**
```dart
// Key Features:
- Order approval workflow
- Customer relationship management
- Pricing strategy controls
- Comprehensive reporting
- Stock level overview
- Procurement recommendations
```

### **📊 STOCK TAKER INTERFACE (Hazvinei)**
```dart
// Key Features:
- SHALLOME stock report entry
- Inventory count updates
- Stock alert management
- Low stock notifications
- Procurement request generation
```

### **🏪 CUSTOMER ORDERING PORTAL**
```dart
// Segment-Specific Features:
- Personalized product catalogs
- Customer-specific pricing
- Order history and patterns
- Delivery preference management
- Real-time stock availability
```

### **📋 ORDER MANAGEMENT SYSTEM**
```dart
// Core Functionality:
- Tuesday/Thursday order cycles
- Delivery scheduling
- Order status tracking
- Customer communication
- Invoice generation
```

---

## 🔄 **REAL BUSINESS WORKFLOWS**

### **📅 Weekly Order Cycle**
1. **Monday**: Stock assessment, procurement planning
2. **Tuesday**: Customer orders (primary order day)
3. **Wednesday**: Order processing, delivery preparation
4. **Thursday**: Customer orders (secondary order day)
5. **Friday**: Order processing, week-end preparation
6. **Weekend**: Stock preparation, planning

### **📊 SHALLOME Stock Reports**
```
Real Example from WhatsApp:
"SHALLOME STOCK AS AT 09 SEPTEMBER 2025
1. Mixed Lettuce 3.2kg
2. Green Chillie 6.9kg
3. Red Chillie 2.4kg
4. Beetroot 3kg
..."
```

### **🎯 Customer Order Patterns**
- **Maltos**: "10*heads broccoli, 10 heads cauliflower, 1*box tomatoes, 5*box avos (2 semi ripe)"
- **Sylvia**: "Tuesday order: Potato 2x1kg, Orange 1kg, Banana 2x1kg, Carrots 1kg"
- **Barchef**: "Lemon × 1 box, Strawberry × 4, Mint× 4, Rosemary × 2"

---

## 🎨 **UI/UX DESIGN CONSIDERATIONS**

### **🎯 User Experience Priorities**
1. **Mobile-First Design** - Farm staff use phones/tablets
2. **Quick Data Entry** - Stock updates need to be fast
3. **Clear Visual Hierarchy** - Important info stands out
4. **Offline Capability** - Farm connectivity can be spotty
5. **WhatsApp Integration** - Familiar communication method

### **🌾 Brand & Theme**
- **Colors**: Earth tones, greens, fresh produce colors
- **Typography**: Clean, readable fonts for outdoor use
- **Icons**: Agricultural, fresh produce, farm-themed
- **Images**: Real farm photos, fresh produce

### **📱 Screen Priorities**
1. **Dashboard** - Quick overview of key metrics
2. **Stock Management** - Easy inventory updates
3. **Order Processing** - Streamlined order workflow
4. **Customer Management** - Contact and pricing info
5. **Reports** - Visual data presentation

---

## 🔌 **API INTEGRATION POINTS**

### **🌐 Backend Endpoints**
```
Base URL: http://localhost:8000/api/

Authentication:
POST /auth/login/
POST /auth/logout/

Products:
GET /products/
GET /products/{id}/
GET /products/departments/

Customers:
GET /customers/
GET /customers/{id}/
GET /customers/{id}/price-list/

Orders:
GET /orders/
POST /orders/
PUT /orders/{id}/
GET /orders/{id}/status/

Inventory:
GET /inventory/stock-levels/
POST /inventory/stock-update/
GET /inventory/alerts/
GET /inventory/procurement-recommendations/

Pricing:
GET /pricing/market-prices/
GET /pricing/customer-pricing/{customer_id}/
POST /pricing/price-list-generate/

WhatsApp Integration:
POST /whatsapp/receive-messages/
GET /whatsapp/messages/
POST /whatsapp/messages/process/
```

---

## 📊 **SAMPLE DATA FOR TESTING**

### **🧪 Test Users**
```json
{
  "farm_manager": {
    "email": "karl@fambrifarms.co.za",
    "password": "FambriFarms2025!",
    "phone": "+27 76 655 4873"
  },
  "stock_taker": {
    "email": "hazvinei@fambrifarms.co.za", 
    "password": "FambriFarms2025!",
    "phone": "+27 61 674 9368"
  },
  "customer": {
    "email": "procurement@maltos.co.za",
    "password": "FambriFarms2025!",
    "business": "Maltos Restaurant"
  }
}
```

### **🛒 Sample Order Data**
```json
{
  "customer": "Maltos",
  "items": [
    {"product": "Broccoli", "quantity": 10, "unit": "heads"},
    {"product": "Cauliflower", "quantity": 10, "unit": "heads"},
    {"product": "Tomatoes", "quantity": 1, "unit": "box"},
    {"product": "Avocados", "quantity": 5, "unit": "box", "notes": "2 semi ripe"}
  ],
  "delivery_date": "2025-09-10",
  "special_instructions": "Deveined spinach, semi-ripe avos"
}
```

---

## 🚀 **DEVELOPMENT PRIORITIES**

### **🎯 Phase 1: Core Functionality**
1. **Authentication System** - Role-based login
2. **Dashboard Views** - User-specific dashboards
3. **Product Catalog** - Browse and search products
4. **Basic Ordering** - Simple order placement

### **🎯 Phase 2: Advanced Features**
1. **Stock Management** - Inventory updates and alerts
2. **Pricing Intelligence** - Dynamic pricing display
3. **Order Processing** - Complete order workflow
4. **Customer Management** - Relationship management

### **🎯 Phase 3: Integration & Polish**
1. **WhatsApp Integration** - Message processing
2. **Reporting System** - Analytics and insights
3. **Offline Capability** - Local data storage
4. **Performance Optimization** - Speed and reliability

---

## 🎉 **SUCCESS METRICS**

### **📊 Key Performance Indicators**
- **Order Processing Time** - Target: <2 minutes per order
- **Stock Update Frequency** - Target: Daily SHALLOME reports
- **Customer Satisfaction** - Target: 95% on-time delivery
- **Inventory Accuracy** - Target: 98% stock level accuracy
- **User Adoption** - Target: 100% staff using mobile app

### **🎯 Business Impact Goals**
- **Reduce Order Errors** by 80%
- **Improve Stock Visibility** by 95%
- **Increase Customer Satisfaction** by 25%
- **Streamline Operations** - 50% faster processing
- **Enable Growth** - Support 2x customer base

---

## 🔗 **ADDITIONAL RESOURCES**

### **📁 Backend Documentation**
- **API Documentation**: Available at `/api/docs/`
- **Database Schema**: See Django models in `/backend/`
- **Test Data**: Comprehensive seed commands available

### **💡 Development Tips**
1. **Use Real Data** - All seed data is based on actual operations
2. **Follow User Workflows** - Stick to proven business processes
3. **Mobile-First** - Design for phone/tablet usage
4. **Test with Real Users** - Karl and Hazvinei can provide feedback
5. **Iterate Quickly** - Start simple, add complexity gradually

---

## 🎯 **CONCLUSION**

This Flutter app has the potential to be **EXTRAORDINARY** because it's built on **real data** and **authentic workflows**. Every feature, every user persona, every business process is based on actual farm operations extracted from WhatsApp conversations.

**The backend is GOLD** - use it to build something truly special! 🌟

---

*Last Updated: September 15, 2025*  
*Backend Phases Complete: 6/8*  
*Ready for Flutter Development: ✅*
