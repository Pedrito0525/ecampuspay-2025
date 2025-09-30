import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'admin_dashboard.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  static const Color evsuRed = Color(0xFFB01212);

  // Dashboard data
  int _totalUsers = 0;
  int _activeUsersToday = 0;
  double _totalTransactions = 0.0;
  int _totalServices = 0;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Use the combined dashboard stats function for better performance
      final response = await SupabaseService.adminClient.rpc(
        'get_dashboard_stats',
        params: {},
      );

      if (response['success']) {
        final data = response['data'];
        setState(() {
          _totalUsers = data['total_users'] ?? 0;
          _activeUsersToday = data['active_users_today'] ?? 0;
          _totalTransactions =
              (data['today_transactions'] as num?)?.toDouble() ?? 0.0;
          _totalServices = data['total_services'] ?? 0;
          _isLoading = false;
        });
      } else {
        // Fallback to individual calls if combined function fails
        final results = await Future.wait([
          SupabaseService.getAllUsers(),
          SupabaseService.getServiceAccounts(),
          _getTodayTransactions(),
          _getActiveUsersToday(),
        ]);

        final usersResult = results[0] as Map<String, dynamic>;
        final servicesResult = results[1] as Map<String, dynamic>;
        final todayTransactions = results[2] as double;
        final activeUsersToday = results[3] as int;

        setState(() {
          _totalUsers =
              usersResult['success'] ? (usersResult['data'] as List).length : 0;
          _totalServices =
              servicesResult['success']
                  ? (servicesResult['data'] as List).length
                  : 0;
          _totalTransactions = todayTransactions;
          _activeUsersToday = activeUsersToday;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading dashboard data: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<double> _getTodayTransactions() async {
    try {
      final response = await SupabaseService.adminClient.rpc(
        'get_today_transaction_total',
        params: {},
      );
      return (response['total'] as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  Future<int> _getActiveUsersToday() async {
    try {
      final response = await SupabaseService.adminClient.rpc(
        'get_active_users_today',
        params: {},
      );
      return (response['count'] as num?)?.toInt() ?? 0;
    } catch (e) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Admin Dashboard',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: evsuRed,
                        ),
                      ),
                      Text(
                        'EVSU eCampusPay System',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                CircleAvatar(
                  backgroundColor: evsuRed.withOpacity(0.1),
                  child: const Icon(Icons.admin_panel_settings, color: evsuRed),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Statistics Cards
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_errorMessage != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadDashboardData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'Total Users',
                          value: _totalUsers.toString(),
                          icon: Icons.people,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          title: 'Active Today',
                          value: _activeUsersToday.toString(),
                          icon: Icons.online_prediction,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'Today\'s Transactions',
                          value: '₱${_totalTransactions.toStringAsFixed(2)}',
                          icon: Icons.attach_money,
                          color: evsuRed,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          title: 'Service Accounts',
                          value: _totalServices.toString(),
                          icon: Icons.business_center,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            const SizedBox(height: 24),

            // Quick Actions
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: evsuRed,
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                // Responsive crossAxisCount based on screen width
                int crossAxisCount = 2; // Default for mobile
                double childAspectRatio = 1.5; // Default aspect ratio

                if (constraints.maxWidth > 1200) {
                  // Large desktop screens
                  crossAxisCount = 4;
                  childAspectRatio = 1.2;
                } else if (constraints.maxWidth > 800) {
                  // Tablet and small desktop
                  crossAxisCount = 3;
                  childAspectRatio = 1.3;
                } else if (constraints.maxWidth > 600) {
                  // Large mobile/small tablet
                  crossAxisCount = 2;
                  childAspectRatio = 1.4;
                }

                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: childAspectRatio,
                  children: [
                    _QuickActionCard(
                      title: 'User Management',
                      icon: Icons.manage_accounts,
                      onTap:
                          () => _handleQuickAction(context, 'User Management'),
                    ),
                    _QuickActionCard(
                      title: 'System Settings',
                      icon: Icons.settings,
                      onTap:
                          () => _handleQuickAction(context, 'System Settings'),
                    ),
                    _QuickActionCard(
                      title: 'Reports & Analytics',
                      icon: Icons.analytics,
                      onTap: () => _handleQuickAction(context, 'Reports'),
                    ),
                    _QuickActionCard(
                      title: 'Service Management',
                      icon: Icons.business_center,
                      onTap:
                          () =>
                              _handleQuickAction(context, 'Service Management'),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Recent Activity
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Recent Activity',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: evsuRed,
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 5,
                    itemBuilder:
                        (context, index) => _ActivityItem(
                          title: _getActivityTitle(index),
                          subtitle: _getActivitySubtitle(index),
                          time: _getActivityTime(index),
                          icon: _getActivityIcon(index),
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 100), // Space for bottom nav
          ],
        ),
      ),
    );
  }

  void _handleQuickAction(BuildContext context, String action) {
    // Find the parent AdminDashboard widget and update its tab index
    final adminDashboard =
        context.findAncestorStateOfType<State<AdminDashboard>>();

    if (adminDashboard != null) {
      switch (action) {
        case 'Service Management':
          // Navigate to vendors tab (index 6)
          (adminDashboard as dynamic).changeTabIndex(6);
          break;
        case 'User Management':
          // Navigate to user management tab (index 5)
          (adminDashboard as dynamic).changeTabIndex(5);
          break;
        case 'System Settings':
          // Navigate to settings tab (index 4)
          (adminDashboard as dynamic).changeTabIndex(4);
          break;
        case 'Reports':
          // Navigate to reports tab (index 1)
          (adminDashboard as dynamic).changeTabIndex(1);
          break;
        default:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Opening $action...'),
              backgroundColor: evsuRed,
            ),
          );
      }
    } else {
      // Fallback if parent AdminDashboard is not found
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to navigate to $action'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  static String _getActivityTitle(int index) {
    const titles = [
      'New user registration',
      'System backup completed',
      'Failed transaction alert',
      'Vendor payment processed',
      'User account suspended',
    ];
    return titles[index];
  }

  static String _getActivitySubtitle(int index) {
    const subtitles = [
      'Student ID: 2024-12345',
      'All data backed up successfully',
      'Transaction ID: TXN-001234',
      'Vendor: Campus Cafeteria',
      'User: john.doe@evsu.edu.ph',
    ];
    return subtitles[index];
  }

  static String _getActivityTime(int index) {
    const times = [
      '2 min ago',
      '15 min ago',
      '1 hour ago',
      '2 hours ago',
      '1 day ago',
    ];
    return times[index];
  }

  static IconData _getActivityIcon(int index) {
    const icons = [
      Icons.person_add,
      Icons.backup,
      Icons.error,
      Icons.payment,
      Icons.person_off,
    ];
    return icons[index];
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _DashboardTabState.evsuRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: _DashboardTabState.evsuRed, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final String time;
  final IconData icon;

  const _ActivityItem({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _DashboardTabState.evsuRed.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: _DashboardTabState.evsuRed, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
      trailing: Text(
        time,
        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
      ),
    );
  }
}
