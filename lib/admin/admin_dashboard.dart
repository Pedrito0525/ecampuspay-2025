import 'package:flutter/material.dart';
import 'dashboard_tab.dart';
import 'reports_tab.dart';
import 'transactions_tab.dart';
import 'topup_tab.dart';
import 'user_management_tab.dart';
import 'vendors_tab.dart';
import 'settings_tab.dart';
import 'loaning_tab.dart';
import '../login_page.dart';

class AdminDashboard extends StatefulWidget {
  final int? initialTabIndex;
  final bool? navigateToServiceRegistration;

  const AdminDashboard({
    super.key,
    this.initialTabIndex,
    this.navigateToServiceRegistration,
  });

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  static const Color evsuRed = Color(0xFFB91C1C);
  static const Color evsuRedDark = Color(0xFF7F1D1D);
  int _currentIndex = 0;
  bool _isSidebarCollapsed = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late final List<Widget> _tabs;

  final List<NavigationItem> _navigationItems = [
    NavigationItem(
      icon: Icons.dashboard,
      activeIcon: Icons.dashboard,
      label: 'Dashboard',
      id: 'dashboard',
    ),
    NavigationItem(
      icon: Icons.analytics_outlined,
      activeIcon: Icons.analytics,
      label: 'Reports',
      id: 'reports',
    ),
    NavigationItem(
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long,
      label: 'Transactions',
      id: 'transactions',
      badge: 12,
    ),
    NavigationItem(
      icon: Icons.add_card_outlined,
      activeIcon: Icons.add_card,
      label: 'Top-Up',
      id: 'topup',
    ),
    NavigationItem(
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings,
      label: 'Settings',
      id: 'settings',
    ),
    NavigationItem(
      icon: Icons.people_outline,
      activeIcon: Icons.people,
      label: 'User Management',
      id: 'users',
      badge: 3,
    ),
    NavigationItem(
      icon: Icons.store_outlined,
      activeIcon: Icons.store,
      label: 'Service Ports',
      id: 'vendors',
    ),
    NavigationItem(
      icon: Icons.account_balance_outlined,
      activeIcon: Icons.account_balance,
      label: 'Loaning',
      id: 'loaning',
    ),
  ];

  @override
  void initState() {
    super.initState();

    // Set initial tab index if provided
    if (widget.initialTabIndex != null) {
      _currentIndex = widget.initialTabIndex!;
    }

    _tabs = [
      const DashboardTab(), // 0 - Dashboard (Main)
      const ReportsTab(), // 1 - Reports (Main)
      const TransactionsTab(), // 2 - Transactions (Main)
      const TopUpTab(), // 3 - Top-Up (Main)
      const SettingsTab(), // 4 - Settings (Bottom nav profile replacement)
      const UserManagementTab(), // 5 - User Management (Management)
      VendorsTab(
        navigateToServiceRegistration: widget.navigateToServiceRegistration,
      ), // 6 - Service Ports (Management)
      const LoaningTab(), // 7 - Loaning (Management)
    ];
  }

  // Method to change tab index from child widgets
  void changeTabIndex(int index) {
    if (index >= 0 && index < _tabs.length) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 1024;
        final isTablet =
            constraints.maxWidth > 768 && constraints.maxWidth <= 1024;

        if (isDesktop) {
          return _buildDesktopLayout();
        } else if (isTablet) {
          return _buildTabletLayout();
        } else {
          return _buildMobileLayout();
        }
      },
    );
  }

  Widget _buildDesktopLayout() {
    final sidebarWidth = _isSidebarCollapsed ? 70.0 : 280.0;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.grey[50],
      body: Row(
        children: [
          // Sidebar
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: sidebarWidth,
            child: _buildSidebar(isCollapsed: _isSidebarCollapsed),
          ),
          // Main Content
          Expanded(
            child: Column(
              children: [
                _buildDesktopHeader(),
                Expanded(child: _buildMainContent()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletLayout() {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.grey[50],
      appBar: _buildMobileAppBar(),
      drawer: SizedBox(width: 250, child: _buildSidebar(isCollapsed: false)),
      body: _buildMainContent(),
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.grey[50],
      appBar: _buildMobileAppBar(),
      drawer: SizedBox(width: 280, child: _buildSidebar(isCollapsed: false)),
      body: _buildMainContent(),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildSidebar({required bool isCollapsed}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Logo Section
          Container(
            padding: const EdgeInsets.all(25),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE9ECEF))),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [evsuRed, evsuRedDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text(
                      'E',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                if (!isCollapsed) ...[
                  const SizedBox(width: 12),
                  const Text(
                    'eCampusPay',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: evsuRed,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Navigation Menu
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              children: [
                if (!isCollapsed)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 25, vertical: 10),
                    child: Text(
                      'MAIN',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ..._navigationItems
                    .take(5)
                    .map((item) => _buildNavItem(item, isCollapsed)),
                if (!isCollapsed) ...[
                  const SizedBox(height: 20),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 25, vertical: 10),
                    child: Text(
                      'MANAGEMENT',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
                ..._navigationItems
                    .skip(5)
                    .map((item) => _buildNavItem(item, isCollapsed)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(NavigationItem item, bool isCollapsed) {
    final isActive = _navigationItems[_currentIndex].id == item.id;
    final index = _navigationItems.indexOf(item);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: InkWell(
        onTap: () => setState(() => _currentIndex = index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isCollapsed ? 12 : 25,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFFEF2F2) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border(
              right: BorderSide(
                color: isActive ? evsuRed : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isActive ? item.activeIcon : item.icon,
                color: isActive ? evsuRed : Colors.grey[600],
                size: 18,
              ),
              if (!isCollapsed) ...[
                const SizedBox(width: 15),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isActive ? evsuRed : Colors.grey[600],
                    ),
                  ),
                ),
                if (item.badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: evsuRed,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      item.badge.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopHeader() {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [evsuRed, evsuRedDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Row(
          children: [
            IconButton(
              onPressed:
                  () => setState(
                    () => _isSidebarCollapsed = !_isSidebarCollapsed,
                  ),
              icon: const Icon(Icons.menu, color: Colors.white),
            ),
            const SizedBox(width: 20),
            const Text(
              'eCampusPay Admin',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            // Notifications
            Stack(
              children: [
                IconButton(
                  onPressed: () {},
                  icon: const Icon(
                    Icons.notifications_outlined,
                    color: Colors.white,
                  ),
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text(
                        '5',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 20),
            // Admin Info
            const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'System Administrator',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Full Access',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(width: 20),
            IconButton(
              onPressed: _showQuickActions,
              icon: const Icon(Icons.account_circle, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildMobileAppBar() {
    return AppBar(
      backgroundColor: evsuRed,
      elevation: 2,
      leading: IconButton(
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        icon: const Icon(Icons.menu, color: Colors.white),
      ),
      title: const Text(
        'eCampusPay Admin',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      actions: [
        Stack(
          children: [
            IconButton(
              onPressed: () {},
              icon: const Icon(
                Icons.notifications_outlined,
                color: Colors.white,
              ),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text(
                    '5',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        IconButton(
          onPressed: _showQuickActions,
          icon: const Icon(Icons.account_circle, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildMainContent() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Container(
      padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
      child:
          _currentIndex < _tabs.length
              ? _tabs[_currentIndex]
              : _tabs[0], // Fallback to dashboard if index is out of range
    );
  }

  Widget _buildBottomNavigation() {
    // Map current index to bottom navigation index
    int bottomNavIndex = _currentIndex;
    if (_currentIndex > 3) {
      bottomNavIndex = 3; // Default to settings for other tabs
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: bottomNavIndex,
        onTap: (index) {
          // Map bottom navigation index to actual tab index
          int actualIndex = index;
          if (index == 3) {
            actualIndex = 4; // Settings tab is at index 4
          }
          setState(() => _currentIndex = actualIndex);
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: evsuRed,
        unselectedItemColor: Colors.grey[600],
        backgroundColor: Colors.white,
        elevation: 0,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        items: [
          BottomNavigationBarItem(
            icon: Icon(
              _currentIndex == 0 ? Icons.dashboard : Icons.dashboard_outlined,
            ),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              _currentIndex == 1 ? Icons.analytics : Icons.analytics_outlined,
            ),
            label: 'Reports',
          ),
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                Icon(
                  _currentIndex == 2
                      ? Icons.receipt_long
                      : Icons.receipt_long_outlined,
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 12,
                      minHeight: 12,
                    ),
                    child: const Text(
                      '12',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
            label: 'Transactions',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              _currentIndex == 4 ? Icons.settings : Icons.settings_outlined,
            ),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  void _showQuickActions() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1024;

    if (isDesktop) {
      // Show as a popup dialog for desktop/web
      showDialog(
        context: context,
        builder:
            (context) => Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: 400,
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'Emergency Actions',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: evsuRed,
                        ),
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildActionButton(
                              icon: Icons.lock,
                              iconColor: Colors.red,
                              title: 'Lock All Transactions',
                              onTap: () {
                                Navigator.pop(context);
                                _showConfirmDialog('Lock all transactions?');
                              },
                            ),
                            _buildActionButton(
                              icon: Icons.notification_important,
                              iconColor: Colors.orange,
                              title: 'Send System Alert',
                              onTap: () {
                                Navigator.pop(context);
                                _showAlertDialog();
                              },
                            ),
                            _buildActionButton(
                              icon: Icons.support_agent,
                              iconColor: evsuRed,
                              title: 'Contact Support',
                              onTap: () {
                                Navigator.pop(context);
                                // Handle contact support
                              },
                            ),
                            _buildActionButton(
                              icon: Icons.logout,
                              iconColor: Colors.red,
                              title: 'Logout',
                              onTap: () {
                                Navigator.pop(context);
                                _logout();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
      );
    } else {
      // Show as bottom sheet for mobile/tablet
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder:
            (context) => Container(
              margin: const EdgeInsets.all(16),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Emergency Actions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: evsuRed,
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.lock, color: Colors.red),
                    title: const Text('Lock All Transactions'),
                    onTap: () {
                      Navigator.pop(context);
                      _showConfirmDialog('Lock all transactions?');
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.notification_important,
                      color: Colors.orange,
                    ),
                    title: const Text('Send System Alert'),
                    onTap: () {
                      Navigator.pop(context);
                      _showAlertDialog();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.support_agent, color: evsuRed),
                    title: const Text('Contact Support'),
                    onTap: () {
                      Navigator.pop(context);
                      // Handle contact support
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text('Logout'),
                    onTap: () {
                      Navigator.pop(context);
                      _logout();
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
      );
    }
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[200]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showConfirmDialog(String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirm Action'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: evsuRed),
                onPressed: () {
                  Navigator.pop(context);
                  // Handle emergency action
                },
                child: const Text(
                  'Confirm',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  void _showAlertDialog() {
    final TextEditingController alertController = TextEditingController();
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Send System Alert'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Enter alert message:'),
                const SizedBox(height: 12),
                TextField(
                  controller: alertController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Alert message...',
                  ),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: evsuRed),
                onPressed: () {
                  Navigator.pop(context);
                  // Handle send alert
                },
                child: const Text(
                  'Send Alert',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  void _logout() {
    // Show confirmation dialog for logout
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Logout'),
            content: const Text('Are you sure you want to logout?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  // Navigate to login page and clear all previous routes
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                    (route) => false,
                  );
                },
                child: const Text(
                  'Logout',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }
}

class NavigationItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String id;
  final int? badge;

  NavigationItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.id,
    this.badge,
  });
}
