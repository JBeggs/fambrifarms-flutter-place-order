import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/professional_theme.dart';
import '../../providers/customers_provider.dart';
import '../../features/auth/karl_auth_provider.dart';
import 'widgets/customer_card.dart';
import 'widgets/customer_search.dart';
import 'widgets/add_customer_dialog.dart';
import 'widgets/edit_customer_dialog.dart';

class CustomersPage extends ConsumerWidget {
  const CustomersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final karl = ref.watch(karlAuthProvider).user;
    final customersState = ref.watch(customersProvider);
    final customersList = ref.watch(customersListProvider);
    final customersStats = ref.watch(customersStatsProvider);

    if (karl == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/login');
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundDark, // Professional dark background
      appBar: AppBar(
        title: const Text('Customer Management'),
        backgroundColor: AppColors.primaryGreen, // Professional green AppBar
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/karl-dashboard'),
        ),
        actions: [
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(customersProvider.notifier).refresh();
            },
          ),
          
          // Add customer button
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const AddCustomerDialog(),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats header
          _buildStatsHeader(context, customersStats),
          
          // Search and filters
          const CustomerSearch(),
          
          // Customer list
          Expanded(
            child: _buildCustomersList(context, ref, customersState, customersList),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader(BuildContext context, Map<String, dynamic> stats) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              context,
              'Total Customers',
              stats['total'].toString(),
              Icons.people,
              const Color(0xFF2D5016),
            ),
          ),
          
          const SizedBox(width: 12),
          
          Expanded(
            child: _buildStatCard(
              context,
              'Active',
              stats['active'].toString(),
              Icons.check_circle,
              Colors.green,
            ),
          ),
          
          const SizedBox(width: 12),
          
          Expanded(
            child: _buildStatCard(
              context,
              'Recent Orders',
              stats['recent'].toString(),
              Icons.schedule,
              Colors.blue,
            ),
          ),
          
          const SizedBox(width: 12),
          
          Expanded(
            child: _buildStatCard(
              context,
              'Total Value',
              'R${(stats['total_value'] as double).toStringAsFixed(0)}',
              Icons.attach_money,
              Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCustomersList(
    BuildContext context,
    WidgetRef ref,
    CustomersState state,
    List<dynamic> customers,
  ) {
    if (state.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading customers...'),
          ],
        ),
      );
    }

    if (state.error != null) {
      return Center(
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
              'Error loading customers',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              state.error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.read(customersProvider.notifier).refresh();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (customers.isEmpty) {
      final hasFilters = state.searchQuery.isNotEmpty || state.selectedType != 'all';
      
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasFilters ? Icons.search_off : Icons.people_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              hasFilters ? 'No customers found' : 'No customers yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasFilters 
                  ? 'Try adjusting your search or filters'
                  : 'Customers will appear here once they\'re added',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            if (hasFilters) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  ref.read(customersProvider.notifier).clearSearch();
                  ref.read(customersProvider.notifier).filterByType('all');
                },
                child: const Text('Clear filters'),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(customersProvider.notifier).refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: customers.length,
        itemBuilder: (context, index) {
          final customer = customers[index];
          return CustomerCard(
            customer: customer,
            onTap: () {
              context.push('/customers/${customer.id}');
            },
            onEdit: () {
              showDialog(
                context: context,
                builder: (context) => EditCustomerDialog(customer: customer),
              );
            },
            onViewOrders: () {
              context.push('/customers/${customer.id}/orders');
            },
          );
        },
      ),
    );
  }
}
