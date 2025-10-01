import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'home_tab.dart';
import 'food_management_tab.dart';
import 'cashier_tab.dart';
import 'service_reports_tab.dart';
import 'payment_screen.dart';
import '../services/session_service.dart';
import '../services/supabase_service.dart';
import '../services/esp32_bluetooth_service_account.dart';
import '../login_page.dart';
import 'package:permission_handler/permission_handler.dart';

// Removed SettingsTab per requirements (settings is a separate screen)

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final isWeb = screenWidth > 600;
    final isTablet = screenWidth > 480 && screenWidth <= 1024;
    final horizontalPadding = isWeb ? 24.0 : (isTablet ? 20.0 : 16.0);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: const Color(0xFFB91C1C),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(horizontalPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            _SettingsItem(
              title: 'Profile',
              subtitle: 'View and edit account info',
            ),
            _SettingsItem(title: 'Notifications', subtitle: 'Manage alerts'),
            _SettingsItem(title: 'Scanner', subtitle: 'View assigned scanner'),
            _SettingsItem(title: 'Appearance', subtitle: 'Theme preferences'),
            _SettingsItem(title: 'About', subtitle: 'Version and info'),
          ],
        ),
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SettingsItem({required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE9ECEF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {},
      ),
    );
  }
}

class ServiceDashboard extends StatefulWidget {
  final String serviceName;
  final String serviceType;

  const ServiceDashboard({
    Key? key,
    required this.serviceName,
    required this.serviceType,
  }) : super(key: key);

  @override
  State<ServiceDashboard> createState() => _ServiceDashboardState();
}

class _ServiceDashboardState extends State<ServiceDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<Tab> _tabs = [
    const Tab(text: 'Home'),
    const Tab(text: 'Cashier'),
    const Tab(text: 'Manage'),
    const Tab(text: 'Reports'),
  ];

  // Scanner connection state
  bool _scannerConnected = false;
  String? _assignedScannerId;

  // Connection monitoring
  Timer? _connectionMonitorTimer;
  DateTime? _lastReconnectAttemptAt;
  final Duration _reconnectInterval = const Duration(seconds: 6);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _initializeServiceScanner();
    _startConnectionMonitoring();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _connectionMonitorTimer?.cancel();
    ESP32BluetoothServiceAccount.disconnect();
    super.dispose();
  }

  Future<void> _initializeServiceScanner() async {
    try {
      final username = SessionService.currentUserData?['username'];
      if (username == null) {
        print('DEBUG: No username found in session data');
        return;
      }

      print('DEBUG: Looking for scanner assigned to username: $username');

      // Get service account information directly
      final serviceResponse =
          await SupabaseService.client
              .from('service_accounts')
              .select('id, service_name, scanner_id')
              .eq('username', username)
              .eq('is_active', true)
              .maybeSingle();

      print('DEBUG: Service account response: $serviceResponse');

      if (serviceResponse != null) {
        final scannerId = serviceResponse['scanner_id'] as String?;

        if (scannerId != null && scannerId.isNotEmpty) {
          print('DEBUG: Found assigned scanner: $scannerId');
          setState(() {
            _assignedScannerId = scannerId;
          });

          await _connectToAssignedScanner(scannerId);
        } else {
          print('DEBUG: No scanner assigned to this service account');
        }
      } else {
        print('DEBUG: Service account not found or inactive');
      }
    } catch (e) {
      print('Error initializing scanner: $e');
    }
  }

  Future<void> _connectToAssignedScanner(String scannerId) async {
    if (Platform.isAndroid) {
      final status = await Permission.bluetoothConnect.status;
      if (!status.isGranted) {
        final result = await Permission.bluetoothConnect.request();
        if (!result.isGranted) {
          print('Bluetooth permission denied');
          return;
        }
      }
    }

    try {
      print('DEBUG: Disconnecting from any previous scanner...');
      await ESP32BluetoothServiceAccount.disconnect();

      print('DEBUG: Attempting to connect to scanner: $scannerId');
      final connected =
          await ESP32BluetoothServiceAccount.connectToAssignedScanner(
            scannerId,
          );
      setState(() {
        _scannerConnected = connected;
      });

      if (connected) {
        print('Successfully connected to scanner: $scannerId');
      } else {
        print('Failed to connect to scanner: $scannerId');
      }
    } catch (e) {
      print('Error connecting to scanner: $e');
      setState(() {
        _scannerConnected = false;
      });
    }
  }

  void _navigateToPayment(Map<String, dynamic> product) async {
    final actualServiceName =
        SessionService.currentUserData?['service_name']?.toString() ??
        widget.serviceName;

    final paymentResult = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder:
            (context) => PaymentScreen(
              product: product,
              serviceName: actualServiceName,
              scannerConnected: _scannerConnected,
              assignedScannerId: _assignedScannerId,
            ),
      ),
    );

    // Refresh the UI if payment was successful
    if (paymentResult == true && mounted) {
      print('DEBUG: Payment successful, refreshing service dashboard UI');
      setState(() {
        // This will trigger a rebuild of the entire dashboard,
        // including the home tab which displays the balance
      });
    }
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                SessionService.forceClearSession();
                Navigator.of(this.context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false,
                );
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  /// Start monitoring connection status periodically
  void _startConnectionMonitoring() {
    _connectionMonitorTimer = Timer.periodic(const Duration(seconds: 3), (
      timer,
    ) async {
      if (_assignedScannerId != null) {
        _checkConnectionStatus();
      }
    });
  }

  Future<void> _checkConnectionStatus() async {
    if (_assignedScannerId == null) return;

    try {
      final currentConnectionState = ESP32BluetoothServiceAccount.isConnected;

      // Update UI if state changed
      if (currentConnectionState != _scannerConnected) {
        setState(() {
          _scannerConnected = currentConnectionState;
        });
        if (currentConnectionState) {
          print("DEBUG: Scanner reconnected automatically");
        }
      }

      // Proactive reconnect attempts while disconnected
      if (!currentConnectionState && _assignedScannerId != null) {
        final bool isConnecting = ESP32BluetoothServiceAccount.isConnecting;
        final now = DateTime.now();
        final shouldAttempt =
            _lastReconnectAttemptAt == null ||
            now.difference(_lastReconnectAttemptAt!) >= _reconnectInterval;
        if (!isConnecting && shouldAttempt) {
          _lastReconnectAttemptAt = now;
          print(
            'DEBUG: Proactive reconnect attempt to scanner ${_assignedScannerId}...',
          );
          await _connectToAssignedScanner(_assignedScannerId!);
        }
      }
    } catch (e) {
      print("Error checking connection status: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final isWeb = screenWidth > 600;
    final isTablet = screenWidth > 480 && screenWidth <= 1024;

    // Responsive sizing and layout adjustments
    final headerHeight = isWeb ? 120.0 : (isTablet ? 110.0 : 100.0);
    final horizontalPadding = isWeb ? 24.0 : (isTablet ? 20.0 : 16.0);

    final serviceName =
        SessionService.currentUserData?['service_name']?.toString() ??
        widget.serviceName;
    final serviceType =
        SessionService.currentUserData?['service_category']?.toString() ??
        widget.serviceType;
    final operationalType =
        SessionService.currentUserData?['operational_type']?.toString() ??
        'Main';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(color: Color(0xFFF5F5F5)),
          child: Column(
            children: [
              // Header Section
              Container(
                width: double.infinity,
                height: headerHeight,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFB91C1C), Color(0xFF7F1D1D)],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: isWeb ? 20 : 16,
                    ),
                    child: Column(
                      children: [
                        // Top Row - Service Info and Status
                        Expanded(
                          child: Row(
                            children: [
                              // Service Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      serviceName,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize:
                                            isWeb ? 22 : (isTablet ? 20 : 18),
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      serviceType,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize:
                                            isWeb ? 14 : (isTablet ? 13 : 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Status Indicators
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Operational Type
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isWeb ? 12 : 8,
                                      vertical: isWeb ? 6 : 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(
                                        isWeb ? 12 : 10,
                                      ),
                                    ),
                                    child: Text(
                                      operationalType,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: isWeb ? 12 : 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (isWeb || isTablet)
                                    const SizedBox(height: 8),
                                  if (isWeb || isTablet)
                                    Text(
                                      _scannerConnected
                                          ? 'Scanner Connected'
                                          : 'Scanner Offline',
                                      style: TextStyle(
                                        color:
                                            _scannerConnected
                                                ? Colors.green.shade200
                                                : Colors.orange.shade200,
                                        fontSize: isWeb ? 12 : 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                ],
                              ),

                              // Scanner Status
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      _scannerConnected
                                          ? Colors.green.withOpacity(0.8)
                                          : Colors.orange.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _scannerConnected
                                          ? Icons.bluetooth_connected
                                          : Icons.bluetooth_disabled,
                                      color: Colors.white,
                                      size: isWeb ? 14 : 12,
                                    ),
                                    if (isWeb) ...[
                                      const SizedBox(width: 4),
                                      Text(
                                        _scannerConnected
                                            ? 'Online'
                                            : 'Offline',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: isWeb ? 12 : 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Tab Bar
              Container(
                color: Colors.white,
                child: TabBar(
                  controller: _tabController,
                  labelColor: const Color(0xFFB91C1C),
                  unselectedLabelColor: Colors.grey[600],
                  indicatorColor: const Color(0xFFB91C1C),
                  indicatorWeight: 3,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isWeb ? 14 : (isTablet ? 13 : 12),
                  ),
                  unselectedLabelStyle: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: isWeb ? 14 : (isTablet ? 13 : 12),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: isWeb ? 4 : 2,
                    vertical: 2,
                  ),
                  tabs:
                      _tabs
                          .map(
                            (tab) => Tab(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  tab.text!,
                                  style: TextStyle(
                                    fontSize: isWeb ? 14 : (isTablet ? 12 : 11),
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                ),
              ),

              // Tab Content
              Expanded(
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      const HomeTab(),
                      CashierTab(onProductSelected: _navigateToPayment),
                      const FoodManagementTab(),
                      const ServiceReportsTab(),
                    ],
                  ),
                ),
              ),

              // Bottom Navigation
              Container(
                height: isWeb ? 70 : (isTablet ? 75 : 80),
                decoration: BoxDecoration(
                  color: const Color(0xFFB91C1C),
                  borderRadius:
                      null, // Remove border radius for edge-to-edge coverage
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildNavItem('🏠', 'Home', 0, isWeb, isTablet),
                      _buildNavItem('🏪', 'Cashier', 1, isWeb, isTablet),
                      _buildNavItem('🧰', 'Manage', 2, isWeb, isTablet),
                      _buildNavItem('📊', 'Reports', 3, isWeb, isTablet),
                      _buildNavItem('⚙️', 'Settings', -2, isWeb, isTablet),
                      _buildNavItem('🚪', 'Logout', -1, isWeb, isTablet),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    String icon,
    String label,
    int tabIndex,
    bool isWeb,
    bool isTablet,
  ) {
    final isActive = tabIndex >= 0 && _tabController.index == tabIndex;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (label == 'Logout') {
            _logout();
          } else if (label == 'Settings') {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
          } else if (tabIndex >= 0) {
            _tabController.animateTo(tabIndex);
          }
        },
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isWeb ? 8 : 4,
            vertical: isWeb ? 12 : (isTablet ? 10 : 8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                icon,
                style: TextStyle(fontSize: isWeb ? 22 : (isTablet ? 20 : 18)),
              ),
              SizedBox(height: isWeb ? 4 : 2),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color:
                        isActive ? Colors.white : Colors.white.withOpacity(0.7),
                    fontSize: isWeb ? 12 : (isTablet ? 11 : 10),
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
