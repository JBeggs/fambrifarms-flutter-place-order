// Karl's Market Procurement Intelligence Dashboard
// The ultimate time-saving tool for smart market trips!

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/procurement_provider.dart';
import '../../models/procurement_models.dart';
import '../../models/product.dart';
import '../../services/api_service.dart';
import 'widgets/procurement_dashboard_cards.dart';
import 'widgets/market_recommendation_card.dart';
import 'widgets/time_savings_summary.dart';
import 'widgets/procurement_quick_actions.dart';
import 'widgets/edit_buffer_dialog.dart';
import 'widgets/smart_rounding_display.dart';
import 'business_settings_page.dart';
import 'procurement_details_page.dart';
import 'supplier_performance_dashboard.dart';
import 'procurement_optimization_page.dart';

class ProcurementPage extends ConsumerStatefulWidget {
  const ProcurementPage({super.key});

  @override
  ConsumerState<ProcurementPage> createState() => _ProcurementPageState();
}

class _ProcurementPageState extends ConsumerState<ProcurementPage> {
  bool _useHistoricalDates = true; // Default to true for backdating
  
  @override
  void initState() {
    super.initState();
    // Load procurement data when page opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(procurementProvider.notifier).loadProcurementData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final procurementState = ref.watch(procurementProvider);
    final timeSavings = ref.watch(timeSavingsProvider);
    final pendingRecommendations = ref.watch(pendingRecommendationsProvider);
    final approvedRecommendations = ref.watch(approvedRecommendationsProvider);
    
    // Stock-based procurement data
    final stockBasedNeeds = ref.watch(stockBasedProcurementNeedsProvider);
    final lowStockItems = ref.watch(lowStockProcurementProvider);
    final stockHealthMetrics = ref.watch(stockHealthMetricsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Very dark background like dashboard
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D5016), // Dark green AppBar to match dashboard
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/karl-dashboard'),
        ),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF2D5016),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.shopping_cart,
                size: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Procurement Intelligence',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Unified Procurement Management',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ],
        ),
        elevation: 1,
        actions: [
          // Historical dates toggle
          Tooltip(
            message: _useHistoricalDates 
                ? 'Using historical dates from orders' 
                : 'Using current date',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _useHistoricalDates ? Icons.history : Icons.today,
                  color: Colors.white70,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Switch(
                  value: _useHistoricalDates,
                  onChanged: (value) {
                    setState(() {
                      _useHistoricalDates = value;
                    });
                  },
                  activeThumbColor: Colors.white,
                  activeTrackColor: Colors.white30,
                  inactiveThumbColor: Colors.white70,
                  inactiveTrackColor: Colors.white10,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Generate new recommendation button
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'Generate Smart Recommendation',
            onPressed: procurementState.isLoading ? null : () async {
              await _generateNewRecommendation();
            },
          ),
          // Refresh data
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Data',
            onPressed: procurementState.isLoading ? null : () {
              ref.read(procurementProvider.notifier).loadProcurementData();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: procurementState.isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Color(0xFF2D5016),
                  ),
                  SizedBox(height: 16),
                  Text(
                    '🧠 Analyzing your orders and stock...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Calculating optimal quantities with waste buffers',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
          : procurementState.error != null
              ? _buildErrorState(procurementState.error!)
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Welcome header with time savings
                      _buildWelcomeHeader(timeSavings),

                      const SizedBox(height: 24),

                      // Dashboard metrics cards
                      ProcurementDashboardCards(
                        totalRecommendations: procurementState.totalRecommendations,
                        pendingCount: pendingRecommendations.length,
                        approvedCount: approvedRecommendations.length,
                        totalEstimatedSpending: procurementState.totalEstimatedSpending,
                        criticalItems: procurementState.criticalItems,
                        dashboardData: procurementState.dashboardData,
                      ),

                      const SizedBox(height: 24),

                      // Smart Rounding Display
                      const SmartRoundingDisplay(),

                      const SizedBox(height: 24),

                      // Stock-based procurement analysis
                      _buildStockAnalysisSection(stockHealthMetrics, stockBasedNeeds, lowStockItems),

                      const SizedBox(height: 24),

                      // Main content sections
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left column (60%)
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Pending recommendations
                                if (pendingRecommendations.isNotEmpty) ...[
                                  _buildSectionHeader(
                                    '⏳ Pending Recommendations',
                                    '${pendingRecommendations.length} waiting for your approval',
                                  ),
                                  const SizedBox(height: 16),
                                  ...pendingRecommendations.map((recommendation) =>
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 16),
                                      child: MarketRecommendationCard(
                                        recommendation: recommendation,
                                        onApprove: () => _approveRecommendation(recommendation),
                                        onViewDetails: () => _viewRecommendationDetails(recommendation),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                ],

                                // Approved recommendations
                                if (approvedRecommendations.isNotEmpty) ...[
                                  _buildSectionHeader(
                                    '✅ Ready for Market',
                                    '${approvedRecommendations.length} approved recommendations',
                                  ),
                                  const SizedBox(height: 16),
                                  ...approvedRecommendations.take(3).map((recommendation) =>
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 16),
                                      child: MarketRecommendationCard(
                                        recommendation: recommendation,
                                        onViewDetails: () => _viewRecommendationDetails(recommendation),
                                        showApprovalButton: false,
                                      ),
                                    ),
                                  ),
                                ],

                                // Empty state
                                if (pendingRecommendations.isEmpty && approvedRecommendations.isEmpty)
                                  _buildEmptyState(),
                              ],
                            ),
                          ),

                          const SizedBox(width: 16),

                          // Right column (40%)
                          Expanded(
                            flex: 2,
                            child: Column(
                              children: [
                                // Time savings summary
                                TimeSavingsSummary(timeSavings: timeSavings),
                                
                                const SizedBox(height: 16),
                                
                                // Quick actions
                                ProcurementQuickActions(
                                  onGenerateRecommendation: _generateNewRecommendation,
                                  onViewBuffers: () => _navigateToBusinessSettings(),
                                  onViewRecipes: () => _navigateToRecipes(),
                                  onViewHistory: () => _navigateToHistory(),
                                ),

                                const SizedBox(height: 16),

                                // New Performance & Optimization Links
                                _buildPerformanceLinks(),

                                const SizedBox(height: 16),

                                // System insights
                                _buildSystemInsights(procurementState),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildWelcomeHeader(Map<String, dynamic> timeSavings) {
    final timeSavedHours = timeSavings['total_time_saved_hours'] as double;
    final itemsOptimized = timeSavings['total_items_optimized'] as int;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF2D5016),
            const Color(0xFF2D5016).withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Karl\'s Procurement Intelligence',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  timeSavedHours > 0 
                      ? 'You\'ve saved ${timeSavedHours.toStringAsFixed(1)} hours with smart procurement!'
                      : 'Ready to revolutionize your market trips?',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                if (itemsOptimized > 0)
                  Text(
                    '$itemsOptimized items optimized with intelligent buffers',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.psychology, color: Colors.white, size: 16),
                SizedBox(width: 4),
                Text(
                  'AI Powered',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Market Recommendations Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Generate your first intelligent market recommendation to start saving time!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _generateNewRecommendation,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Generate Smart Recommendation'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D5016),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemInsights(ProcurementState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'System Insights',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildInsightItem(
              Icons.inventory,
              'Products Tracked',
              '${state.buffers.length} with smart buffers',
              Colors.blue,
            ),
            _buildInsightItem(
              Icons.restaurant_menu,
              'Recipe Products',
              '${state.recipes.length} with ingredient breakdowns',
              Colors.green,
            ),
            _buildInsightItem(
              Icons.warning,
              'Critical Buffers',
              '${state.criticalItems} need attention',
              state.criticalItems > 0 ? Colors.orange : Colors.green,
            ),
            _buildInsightItem(
              Icons.trending_up,
              'Efficiency',
              state.karlsTimeSavingSummary,
              const Color(0xFF2D5016),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightItem(IconData icon, String title, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    // Check if it's a network error
    final bool isNetworkError = error.toLowerCase().contains('network') || 
                               error.toLowerCase().contains('connection') ||
                               error.toLowerCase().contains('timeout');
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isNetworkError ? Icons.wifi_off : Icons.error_outline,
              size: 64,
              color: isNetworkError ? Colors.orange[400] : Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              isNetworkError ? 'Connection Issue' : 'Oops! Something went wrong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isNetworkError 
                ? 'Unable to connect to the server. Please check your internet connection and try again.'
                : error,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            if (isNetworkError) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange[600], size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'The app will work offline with existing data',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                ref.read(procurementProvider.notifier).clearError();
                ref.read(procurementProvider.notifier).loadProcurementData();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D5016),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Actions
  Future<void> _generateNewRecommendation() async {
    try {
      // Show loading state
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 16),
                Text('🧠 Generating smart recommendation...'),
              ],
            ),
            backgroundColor: Color(0xFF2D5016),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Use centralized API service
      final apiService = ref.read(apiServiceProvider);
      final result = await apiService.generateMarketRecommendation({
        'use_historical_dates': _useHistoricalDates,
        // Only set for_date if not using historical dates
        if (!_useHistoricalDates) 'for_date': DateTime.now().toIso8601String().split('T')[0]
      });
      
      // Refresh data through single provider call to avoid multiple concurrent requests
      ref.read(procurementProvider.notifier).loadProcurementData();
      
      if (mounted && result['success'] == true) {
        final recommendation = MarketRecommendation.fromJson(result['recommendation']);
        
        // Show success message with time savings
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🎉 Generated smart recommendation with ${recommendation.itemsCount} items! ${recommendation.timeSavingInsight}',
            ),
            backgroundColor: const Color(0xFF2D5016),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to generate recommendation: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _approveRecommendation(MarketRecommendation recommendation) async {
    try {
      // Use centralized API service
      final apiService = ref.read(apiServiceProvider);
      final result = await apiService.approveMarketRecommendation(recommendation.id);
      
      // Refresh data through single provider call to avoid multiple concurrent requests
      ref.read(procurementProvider.notifier).loadProcurementData();
      
      if (mounted && result['success'] == true) {
        final ordersConfirmed = result['orders_confirmed'] ?? 0;
        final messagesDeleted = result['messages_deleted'] ?? 0;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ System reset complete!\n• $ordersConfirmed orders confirmed\n• $messagesDeleted messages deleted\n• Ready for next order day'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to approve recommendation: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _viewRecommendationDetails(MarketRecommendation recommendation) {
    ref.read(procurementProvider.notifier).setActiveRecommendation(recommendation);
    
    // Navigate to details page
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProcurementDetailsPage(
          recommendation: recommendation,
        ),
      ),
    ).then((_) {
      // Refresh data when returning from details page
      ref.invalidate(marketRecommendationsProvider);
      ref.invalidate(procurementDashboardProvider);
      ref.invalidate(procurementProvider);
    });
  }

  void _navigateToBusinessSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const BusinessSettingsPage(),
      ),
    );
  }

  void _navigateToBuffers() async {
    try {
      // Get buffers from API
      final apiService = ApiService();
      final buffers = await apiService.getProcurementBuffers();
      
      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => _BufferManagementDialog(buffers: buffers),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading buffers: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToRecipes() {
    // TODO: Navigate to recipe management page
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Recipe management coming soon!')),
    );
  }

  void _navigateToHistory() {
    // TODO: Navigate to procurement history page
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Procurement history coming soon!')),
    );
  }

  Widget _buildStockAnalysisSection(Map<String, dynamic> stockMetrics, List<Product> criticalStock, List<Product> lowStock) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2D5016).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF2D5016).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.analytics,
                  color: Color(0xFF2D5016),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '📊 Stock-Based Procurement Intelligence',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Real-time stock analysis for smarter purchasing',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStockHealthColor(stockMetrics['stockHealthPercentage']).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _getStockHealthColor(stockMetrics['stockHealthPercentage']).withOpacity(0.5),
                  ),
                ),
                child: Text(
                  '${stockMetrics['stockHealthPercentage'].toStringAsFixed(1)}% Healthy',
                  style: TextStyle(
                    color: _getStockHealthColor(stockMetrics['stockHealthPercentage']),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Stock metrics grid
          Row(
            children: [
              Expanded(
                child: _buildStockMetricCard(
                  'Critical Stock',
                  '${stockMetrics['criticalStock']}',
                  'Need immediate attention',
                  Colors.red,
                  Icons.warning,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStockMetricCard(
                  'Low Stock',
                  '${stockMetrics['lowStock']}',
                  'Approaching minimum',
                  Colors.orange,
                  Icons.trending_down,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStockMetricCard(
                  'Stock Value',
                  'R${(stockMetrics['totalStockValue'] as double).toStringAsFixed(0)}',
                  'Total inventory value',
                  const Color(0xFF2D5016),
                  Icons.attach_money,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStockMetricCard(
                  'Avg Level',
                  (stockMetrics['averageStockLevel'] as double).toStringAsFixed(1),
                  'Average stock per product',
                  Colors.blue,
                  Icons.bar_chart,
                ),
              ),
            ],
          ),

          if (lowStock.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Divider(color: Color(0xFF333333)),
            const SizedBox(height: 16),

            // Critical stock items section removed

            // Low stock items
            if (lowStock.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.trending_down, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Low Stock Monitoring',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${lowStock.length}',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...lowStock.take(3).map((product) => _buildStockItemCard(product, false)),
              if (lowStock.length > 3)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '... and ${lowStock.length - 3} more low stock items',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildStockMetricCard(String title, String value, String subtitle, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[400],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockItemCard(Product product, bool isCritical) {
    final color = isCritical ? Colors.red : Colors.orange;
    final stockPercentage = product.minimumStock > 0 
        ? (product.stockLevel / product.minimumStock) * 100 
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Current: ${product.stockLevel} ${product.unit}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[400],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Min: ${product.minimumStock} ${product.unit}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${stockPercentage.toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'R${(product.stockLevel * product.price).toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[400],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStockHealthColor(double percentage) {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 60) return Colors.orange;
    return Colors.red;
  }

  // Helper method to safely parse double values from API responses
  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  Widget _buildPerformanceLinks() {
    return Card(
      color: const Color(0xFF1E1E1E),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D5016).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.analytics,
                    color: Color(0xFF2D5016),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Procurement Modules',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Shopping Lists • Supplier Analysis • Purchase Orders',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Module 1: Supplier Analysis
            _buildAnalyticsLink(
              'Supplier Analysis',
              'Performance rankings & optimization tools',
              Icons.analytics,
              Colors.purple,
              () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SupplierPerformanceDashboard(),
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Module 2: Cost Optimization
            _buildAnalyticsLink(
              'Cost Optimization',
              'Multi-supplier splitting & price analysis',
              Icons.savings,
              Colors.blue,
              () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ProcurementOptimizationPage(),
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Module 3: Shopping Lists (existing functionality)
            _buildAnalyticsLink(
              'Shopping Lists',
              'Smart market recommendations & time savings',
              Icons.shopping_cart,
              Colors.green,
              () {
                // This is the existing functionality - generate recommendations
                _generateNewRecommendation();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsLink(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
          ],
        ),
      ),
    );
  }
}

class _BufferManagementDialog extends StatefulWidget {
  final List<dynamic> buffers;

  const _BufferManagementDialog({required this.buffers});

  @override
  State<_BufferManagementDialog> createState() => _BufferManagementDialogState();
}

class _BufferManagementDialogState extends State<_BufferManagementDialog> {
  late List<dynamic> _buffers;

  @override
  void initState() {
    super.initState();
    _buffers = List.from(widget.buffers);
  }

  void _refreshBuffers() async {
    try {
      final apiService = ApiService();
      final buffers = await apiService.getProcurementBuffers();
      
      if (mounted) {
        setState(() {
          _buffers = buffers;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error refreshing buffers: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 800,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF2D5016),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.tune, color: Colors.white),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Buffer Management',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings, color: Colors.white),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const BusinessSettingsPage(),
                        ),
                      );
                    },
                    tooltip: 'Business Settings',
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    onPressed: _refreshBuffers,
                    tooltip: 'Refresh',
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            
            // Buffer List
            Flexible(
              child: _buffers.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Text(
                          'No buffer settings found',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: _buffers.length,
                      itemBuilder: (context, index) {
                        final buffer = _buffers[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF2D5016),
                              child: Text(
                                buffer['product_name']?.substring(0, 1).toUpperCase() ?? 'P',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(
                              buffer['product_name'] ?? 'Unknown Product',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              'Spoilage: ${(_parseDouble(buffer['spoilage_rate']) * 100).toStringAsFixed(1)}% • '
                              'Waste: ${(_parseDouble(buffer['cutting_waste_rate']) * 100).toStringAsFixed(1)}% • '
                              'Pack: ${_parseDouble(buffer['market_pack_size']).toStringAsFixed(1)} ${buffer['market_pack_unit'] ?? ''}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (buffer['is_seasonal'] == true)
                                  const Icon(
                                    Icons.ac_unit,
                                    color: Colors.blue,
                                    size: 16,
                                  ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => _editBuffer(buffer),
                                ),
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
    );
  }

  void _editBuffer(Map<String, dynamic> buffer) async {
    await showDialog(
      context: context,
      builder: (context) => EditBufferDialog(
        buffer: buffer,
        onUpdated: _refreshBuffers,
      ),
    );
  }

  // Helper method to safely parse double values from API responses
  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }
}

