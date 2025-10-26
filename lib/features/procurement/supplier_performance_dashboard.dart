import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/api_service.dart';

class SupplierPerformanceDashboard extends ConsumerStatefulWidget {
  const SupplierPerformanceDashboard({super.key});

  @override
  ConsumerState<SupplierPerformanceDashboard> createState() => _SupplierPerformanceDashboardState();
}

class _SupplierPerformanceDashboardState extends ConsumerState<SupplierPerformanceDashboard> {
  bool _isLoading = false;
  Map<String, dynamic>? _dashboardData;
  String? _error;
  int _evaluationDays = 90;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiService = ApiService();
      final result = await apiService.getSupplierPerformanceDashboard(daysBack: _evaluationDays);
      
      setState(() {
        _dashboardData = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Supplier Performance Dashboard'),
        backgroundColor: const Color(0xFF2D5016),
        elevation: 1,
        actions: [
          // Evaluation period selector
          PopupMenuButton<int>(
            icon: const Icon(Icons.date_range),
            tooltip: 'Evaluation Period',
            onSelected: (days) {
              setState(() {
                _evaluationDays = days;
              });
              _loadDashboardData();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 30, child: Text('Last 30 Days')),
              const PopupMenuItem(value: 60, child: Text('Last 60 Days')),
              const PopupMenuItem(value: 90, child: Text('Last 90 Days')),
              const PopupMenuItem(value: 180, child: Text('Last 6 Months')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadDashboardData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF2D5016)),
                  SizedBox(height: 16),
                  Text(
                    '📊 Analyzing supplier performance...',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            )
          : _error != null
              ? _buildErrorState()
              : _dashboardData != null
                  ? _buildDashboard()
                  : const Center(child: Text('No data available')),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
            const SizedBox(height: 16),
            const Text(
              'Failed to load performance data',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadDashboardData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
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

  Widget _buildDashboard() {
    final summary = _dashboardData!['summary'] as Map<String, dynamic>;
    final tierDistribution = _dashboardData!['tier_distribution'] as Map<String, dynamic>;
    final performanceComparison = _dashboardData!['performance_comparison'] as Map<String, dynamic>;
    final topPerformers = _dashboardData!['top_performers'] as List<dynamic>;
    final bottomPerformers = _dashboardData!['bottom_performers'] as List<dynamic>;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with evaluation period
          _buildHeader(),
          const SizedBox(height: 24),

          // Summary metrics
          _buildSummaryCards(summary),
          const SizedBox(height: 24),

          // Performance comparison (Fambri vs External)
          _buildPerformanceComparison(performanceComparison),
          const SizedBox(height: 24),

          // Tier distribution
          _buildTierDistribution(tierDistribution),
          const SizedBox(height: 24),

          // Top and bottom performers
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildTopPerformers(topPerformers),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildBottomPerformers(bottomPerformers),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // All suppliers ranking
          _buildAllSuppliersRanking(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
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
              Icons.analytics,
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
                  'Supplier Performance Intelligence',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Comprehensive analysis over $_evaluationDays days',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
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
                Icon(Icons.trending_up, color: Colors.white, size: 16),
                SizedBox(width: 4),
                Text(
                  'Live Data',
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

  Widget _buildSummaryCards(Map<String, dynamic> summary) {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            'Total Suppliers',
            '${summary['total_suppliers']}',
            'Active suppliers tracked',
            Icons.business,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            'Platinum Tier',
            '${summary['platinum_suppliers']}',
            'Top performing suppliers',
            Icons.star,
            Colors.amber,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            'Gold Tier',
            '${summary['gold_suppliers']}',
            'High quality suppliers',
            Icons.workspace_premium,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            'Avg Score',
            '${summary['overall_average_score'].toStringAsFixed(1)}',
            'Overall performance',
            Icons.analytics,
            const Color(0xFF2D5016),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade400,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceComparison(Map<String, dynamic> comparison) {
    final fambri = comparison['fambri_internal'] as Map<String, dynamic>;
    final external = comparison['external_suppliers'] as Map<String, dynamic>;

    return Card(
      color: const Color(0xFF1E1E1E),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.compare_arrows, color: Color(0xFF2D5016)),
                const SizedBox(width: 8),
                const Text(
                  'Fambri vs External Performance',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildComparisonCard(
                    'Fambri Internal',
                    fambri['average_score'].toStringAsFixed(1),
                    '${fambri['count']} suppliers',
                    Colors.green,
                    Icons.home,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildComparisonCard(
                    'External Suppliers',
                    external['average_score'].toStringAsFixed(1),
                    '${external['count']} suppliers',
                    Colors.orange,
                    Icons.store,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonCard(String title, String score, String count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade300,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            score,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            count,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierDistribution(Map<String, dynamic> tierDistribution) {
    final tiers = ['platinum', 'gold', 'silver', 'bronze', 'needs_improvement'];
    final tierColors = {
      'platinum': Colors.purple,
      'gold': Colors.amber,
      'silver': Colors.grey,
      'bronze': Colors.brown,
      'needs_improvement': Colors.red,
    };
    final tierNames = {
      'platinum': 'Platinum',
      'gold': 'Gold',
      'silver': 'Silver',
      'bronze': 'Bronze',
      'needs_improvement': 'Needs Improvement',
    };

    return Card(
      color: const Color(0xFF1E1E1E),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.pie_chart, color: Color(0xFF2D5016)),
                SizedBox(width: 8),
                Text(
                  'Performance Tier Distribution',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...tiers.map((tier) {
              final tierData = tierDistribution[tier] as Map<String, dynamic>;
              final count = tierData['count'] as int;
              final avgScore = tierData['average_score'] as double;
              
              if (count == 0) return const SizedBox.shrink();
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildTierRow(
                  tierNames[tier]!,
                  count,
                  avgScore,
                  tierColors[tier]!,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTierRow(String tierName, int count, double avgScore, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            tierName,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          avgScore.toStringAsFixed(1),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildTopPerformers(List<dynamic> topPerformers) {
    return Card(
      color: const Color(0xFF1E1E1E),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.emoji_events, color: Colors.amber),
                SizedBox(width: 8),
                Text(
                  'Top Performers',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...topPerformers.asMap().entries.map((entry) {
              final index = entry.key;
              final supplier = entry.value as Map<String, dynamic>;
              return _buildSupplierRankCard(supplier, index + 1, true);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomPerformers(List<dynamic> bottomPerformers) {
    return Card(
      color: const Color(0xFF1E1E1E),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.trending_down, color: Colors.red),
                SizedBox(width: 8),
                Text(
                  'Needs Attention',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...bottomPerformers.reversed.toList().asMap().entries.map((entry) {
              final supplier = entry.value as Map<String, dynamic>;
              return _buildSupplierRankCard(supplier, supplier['rank'], false);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSupplierRankCard(Map<String, dynamic> supplier, int rank, bool isTop) {
    final isInternal = supplier['supplier_type'] == 'internal';
    final score = supplier['overall_score'] as double;
    final tier = supplier['performance_tier'] as String;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isTop ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: isTop ? Colors.green : Colors.red,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isInternal ? Icons.home : Icons.store,
                      size: 14,
                      color: isInternal ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        supplier['supplier_name'],
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _getTierDisplayName(tier),
                  style: TextStyle(
                    fontSize: 11,
                    color: _getTierColor(tier),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            score.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isTop ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllSuppliersRanking() {
    final allSuppliers = _dashboardData!['all_suppliers'] as List<dynamic>;
    
    return Card(
      color: const Color(0xFF1E1E1E),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.leaderboard, color: Color(0xFF2D5016)),
                SizedBox(width: 8),
                Text(
                  'Complete Supplier Rankings',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...allSuppliers.map((supplier) {
              final supplierData = supplier as Map<String, dynamic>;
              return _buildDetailedSupplierCard(supplierData);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedSupplierCard(Map<String, dynamic> supplier) {
    final isInternal = supplier['supplier_type'] == 'internal';
    final score = supplier['overall_score'] as double;
    final tier = supplier['performance_tier'] as String;
    final rank = supplier['rank'] as int;
    final strengths = supplier['key_strengths'] as List<dynamic>;
    final improvements = supplier['improvement_areas'] as List<dynamic>;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getTierColor(tier).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _getTierColor(tier),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    '#$rank',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isInternal ? Icons.home : Icons.store,
                          size: 16,
                          color: isInternal ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            supplier['supplier_name'],
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getTierColor(tier).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _getTierDisplayName(tier),
                            style: TextStyle(
                              fontSize: 10,
                              color: _getTierColor(tier),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isInternal ? 'Internal' : 'External',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                score.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _getTierColor(tier),
                ),
              ),
            ],
          ),
          
          if (strengths.isNotEmpty || improvements.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: Color(0xFF333333)),
            const SizedBox(height: 12),
            
            if (strengths.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(width: 6),
                  const Text(
                    'Strengths:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      strengths.join(', '),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade300,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            
            if (improvements.isNotEmpty) ...[
              if (strengths.isNotEmpty) const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.trending_up, color: Colors.orange, size: 16),
                  const SizedBox(width: 6),
                  const Text(
                    'Improve:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      improvements.join(', '),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade300,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  String _getTierDisplayName(String tier) {
    switch (tier) {
      case 'platinum': return 'Platinum';
      case 'gold': return 'Gold';
      case 'silver': return 'Silver';
      case 'bronze': return 'Bronze';
      case 'needs_improvement': return 'Needs Improvement';
      default: return tier;
    }
  }

  Color _getTierColor(String tier) {
    switch (tier) {
      case 'platinum': return Colors.purple;
      case 'gold': return Colors.amber;
      case 'silver': return Colors.grey;
      case 'bronze': return Colors.brown;
      case 'needs_improvement': return Colors.red;
      default: return Colors.grey;
    }
  }
}
