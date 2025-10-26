import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import '../auth/karl_auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../core/professional_theme.dart';
import 'widgets/business_metrics_cards.dart';
import 'widgets/alerts_section.dart';
import 'widgets/quick_actions_grid.dart';

// State provider to track if dashboard has been loaded
final dashboardLoadedProvider = StateProvider<bool>((ref) => false);

class KarlDashboardPage extends ConsumerWidget {
  const KarlDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final karl = ref.watch(karlAuthProvider).user;
    final dashboardState = ref.watch(dashboardProvider);
    final hasLoaded = ref.watch(dashboardLoadedProvider);
    
    // Determine selected index based on current route
    int selectedIndex = 0; // Default to dashboard
    final currentRoute = GoRouterState.of(context).uri.toString();
    if (currentRoute.contains('/customers')) {
      selectedIndex = 1;
    } else if (currentRoute.contains('/products')) {
      selectedIndex = 2;
    } else if (currentRoute.contains('/inventory')) {
      selectedIndex = 3;
    } else if (currentRoute.contains('/suppliers')) {
      selectedIndex = 4;
    } else if (currentRoute.contains('/pricing')) {
      selectedIndex = 5;
    } else if (currentRoute.contains('/procurement')) {
      selectedIndex = 6;
    } else if (currentRoute.contains('/messages')) {
      selectedIndex = 7;
    } else if (currentRoute.contains('/orders')) {
      selectedIndex = 8;
    }
    
    if (karl == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/login');
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Load dashboard data only once
    if (!hasLoaded && dashboardState is AsyncLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(dashboardProvider.notifier).loadDashboard();
        ref.read(dashboardLoadedProvider.notifier).state = true;
      });
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundDark, // Professional dark background
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen, // Professional green top bar
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
                Icons.agriculture,
                size: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Fambri Farms',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Farm Management System',
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
          // Refresh dashboard
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(dashboardProvider.notifier).refresh();
            },
          ),
          
          // Notifications with alerts count
          dashboardState.when(
            data: (overview) => IconButton(
              icon: Badge(
                isLabelVisible: overview.alerts.isNotEmpty,
                label: Text('${overview.alerts.length}'),
                child: const Icon(Icons.notifications_outlined),
              ),
              onPressed: () {
                // TODO: Show notifications
              },
            ),
            loading: () => IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () {},
            ),
            error: (_, __) => IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () {},
            ),
          ),
          
          // Karl's profile menu
          PopupMenuButton<String>(
            icon: CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF2D5016),
              child: Text(
                karl.initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            onSelected: (value) async {
              switch (value) {
                case 'profile':
                  // TODO: Show profile dialog
                  break;
                case 'settings':
                  // TODO: Navigate to settings
                  break;
                case 'logout':
                  ref.read(karlAuthProvider.notifier).logout();
                  if (context.mounted) {
                    context.go('/login');
                  }
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    const Icon(Icons.person_outline, size: 18),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(karl.displayName),
                        Text(
                          'Farm Manager',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined, size: 18),
                    SizedBox(width: 12),
                    Text('Settings'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 18, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Sign Out', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          // Left navigation rail
          NavigationRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) {
              switch (index) {
                case 0:
                  // Already on dashboard
                  break;
                case 1:
                  context.go('/customers');
                  break;
                case 2:
                  context.go('/products');
                  break;
                case 3:
                  context.go('/inventory');
                  break;
                case 4:
                  context.go('/suppliers');
                  break;
                case 5:
                  context.go('/pricing');
                  break;
                case 6:
                  context.go('/procurement');
                  break;
                case 7:
                  context.go('/messages');
                  break;
                case 8:
                  context.go('/orders');
                  break;
              }
            },
            backgroundColor: AppColors.primaryGreen, // Professional green sidebar
            elevation: 1,
            minWidth: 80,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('Dashboard'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people_outlined),
                selectedIcon: Icon(Icons.people),
                label: Text('Customers'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.inventory_outlined),
                selectedIcon: Icon(Icons.inventory),
                label: Text('Products'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.warehouse_outlined),
                selectedIcon: Icon(Icons.warehouse),
                label: Text('Inventory'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.business_outlined),
                selectedIcon: Icon(Icons.business),
                label: Text('Suppliers'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.trending_up_outlined),
                selectedIcon: Icon(Icons.trending_up),
                label: Text('Pricing'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.auto_awesome_outlined),
                selectedIcon: Icon(Icons.auto_awesome),
                label: Text('Procurement'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.message_outlined),
                selectedIcon: Icon(Icons.message),
                label: Text('WhatsApp'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.shopping_cart_outlined),
                selectedIcon: Icon(Icons.shopping_cart),
                label: Text('Orders'),
              ),
            ],
          ),
          
          // Main content area
          Expanded(
            child: dashboardState.when(
              data: (overview) => _buildDashboardContent(context, karl, overview),
              loading: () => const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading dashboard...'),
                  ],
                ),
              ),
              error: (error, stackTrace) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red[300],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading dashboard',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        ref.read(dashboardProvider.notifier).refresh();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardContent(BuildContext context, dynamic karl, DashboardOverview overview) {
    return RefreshIndicator(
      onRefresh: () async {
        // This will be handled by the provider
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome header
            _buildWelcomeHeader(context, karl, overview.businessMetrics),
            
            const SizedBox(height: 32),
            
            // Business metrics cards
            BusinessMetricsCards(metrics: overview.businessMetrics),
            
            const SizedBox(height: 32),
            
            // Main content sections
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left column (60%)
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      // Quick actions grid
                      QuickActionsGrid(actions: overview.quickActions),
                      
                      const SizedBox(height: 24),
                      
                      // Recent activity placeholder
                      _buildRecentActivitySection(context, overview.recentActivities),
                    ],
                  ),
                ),
                
                const SizedBox(width: 24),
                
                // Right column (40%)
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      // Alerts section
                      AlertsSection(alerts: overview.alerts),
                      
                      const SizedBox(height: 24),
                      
                      // System status
                      _buildSystemStatusSection(context),
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

  Widget _buildWelcomeHeader(BuildContext context, dynamic karl, BusinessMetrics metrics) {
    return Container(
      padding: const EdgeInsets.all(24),
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
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2D5016).withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.white.withOpacity(0.2),
            child: Text(
              karl.initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back, ${karl.displayName}!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Farm Manager • Full System Access',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'System Health: ${metrics.overallHealthStatus} • ${metrics.totalCustomers} customers • ${metrics.totalProducts} products',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified, color: Colors.white, size: 18),
                SizedBox(width: 6),
                Text(
                  'Master Access',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
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

  Widget _buildRecentActivitySection(BuildContext context, List<RecentActivity> activities) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.history,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Recent Activity',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          if (activities.isEmpty)
            Container(
              height: 120,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.timeline,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Recent activities will appear here',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...activities.map((activity) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity.title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          activity.subtitle,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _formatActivityTime(activity.timestamp),
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            )),
        ],
      ),
    );
  }

  Widget _buildSystemStatusSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.settings,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'System Status',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          _buildStatusItem('Django Backend', true, 'API endpoints active'),
          _buildStatusItem('Database', true, 'All connections healthy'),
          _buildStatusItem('Authentication', true, 'JWT tokens valid'),
          _buildStatusItem('WhatsApp Scraper', false, 'Not currently running'),
        ],
      ),
    );
  }

  Widget _buildStatusItem(String service, bool isOnline, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: isOnline ? Colors.green : Colors.orange,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Text(
            isOnline ? 'Online' : 'Offline',
            style: TextStyle(
              fontSize: 12,
              color: isOnline ? Colors.green : Colors.orange,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatActivityTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else {
      return '${difference.inDays}d';
    }
  }
}