import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class VendorsTab extends StatefulWidget {
  final bool? navigateToServiceRegistration;

  const VendorsTab({super.key, this.navigateToServiceRegistration});

  @override
  State<VendorsTab> createState() => _VendorsTabState();
}

class _VendorsTabState extends State<VendorsTab> {
  static const Color evsuRed = Color(0xFFB91C1C);
  int _selectedFunction = -1;

  // Form state variables
  String? _selectedServiceCategory;
  String? _selectedOperationalType;
  int? _selectedMainServiceId;

  // Form controllers
  final TextEditingController _serviceNameController = TextEditingController();
  final TextEditingController _contactPersonController =
      TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _scannerIdController = TextEditingController();
  final TextEditingController _commissionRateController =
      TextEditingController();

  // Loading states
  bool _isCreatingAccount = false;
  bool _isLoadingMainServices = false;

  // Main services list
  List<Map<String, dynamic>> _mainServices = [];

  // Scanner assignment state variables
  List<Map<String, dynamic>> _services = [];
  bool _isLoadingScanners = false;
  String? _selectedServiceId;
  String? _selectedScannerId;

  // Admin scanner assignment state variables
  List<Map<String, dynamic>> _adminAccounts = [];
  bool _isLoadingAdminScanners = false;
  String? _selectedAdminId;
  String? _selectedAdminScannerId;

  // Service categories
  final List<String> _serviceCategories = [
    'School Org',
    'Vendor',
    'Campus Service Units',
  ];

  // Operational types for Campus Service Units
  final List<String> _operationalTypes = ['Main', 'Sub'];

  @override
  void dispose() {
    _serviceNameController.dispose();
    _contactPersonController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _scannerIdController.dispose();
    _commissionRateController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // If navigateToServiceRegistration is true, automatically navigate to Service Registration
    if (widget.navigateToServiceRegistration == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _selectedFunction = 0; // Service Registration is index 0
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _selectedFunction != -1
        ? _buildFunctionDetail(_selectedFunction)
        : SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                const Text(
                  'Service Management',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Manage services and service points',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 30),

                // Function Cards
                LayoutBuilder(
                  builder: (context, constraints) {
                    int crossAxisCount = 1;
                    if (constraints.maxWidth > 1200) {
                      crossAxisCount = 3;
                    } else if (constraints.maxWidth > 800) {
                      crossAxisCount = 2;
                    }

                    return GridView.count(
                      crossAxisCount: crossAxisCount,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 20,
                      crossAxisSpacing: 20,
                      childAspectRatio: 1.5,
                      children: [
                        _buildFunctionCard(
                          index: 0,
                          icon: Icons.add_business,
                          title: 'Service Registration',
                          description: 'Create new service accounts',
                          color: evsuRed,
                          onTap: () => setState(() => _selectedFunction = 0),
                        ),
                        _buildFunctionCard(
                          index: 1,
                          icon: Icons.bluetooth,
                          title: 'RFID Scanner Assignment',
                          description:
                              'Assign RFID Bluetooth scanners to vendors',
                          color: Colors.blue,
                          onTap: () => setState(() => _selectedFunction = 1),
                        ),
                        _buildFunctionCard(
                          index: 2,
                          icon: Icons.business_center,
                          title: 'Service Account Management',
                          description: 'Manage existing service accounts',
                          color: Colors.green,
                          onTap: () => setState(() => _selectedFunction = 2),
                        ),
                        _buildFunctionCard(
                          index: 3,
                          icon: Icons.analytics,
                          title: 'Performance Analytics',
                          description: 'View vendor sales and performance',
                          color: Colors.purple,
                          onTap: () => setState(() => _selectedFunction = 3),
                        ),
                        _buildFunctionCard(
                          index: 4,
                          icon: Icons.payment,
                          title: 'Commission Management',
                          description: 'Manage vendor commission rates',
                          color: Colors.orange,
                          onTap: () => setState(() => _selectedFunction = 4),
                        ),
                        _buildFunctionCard(
                          index: 5,
                          icon: Icons.admin_panel_settings,
                          title: 'Admin Scanner Assignment',
                          description: 'Assign RFID scanners to admin accounts',
                          color: Colors.indigo,
                          onTap: () => setState(() => _selectedFunction = 5),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
  }

  Widget _buildFunctionDetail(int functionIndex) {
    switch (functionIndex) {
      case 0:
        return _buildServiceRegistration();
      case 1:
        return _buildScannerAssignment();
      case 2:
        return _buildServiceAccountManagement();
      case 3:
        return _buildCommissionManagement();
      case 4:
        return _buildCommissionManagement();
      case 5:
        return _buildAdminScannerAssignment();
      default:
        return Container();
    }
  }

  Widget _buildServiceRegistration() {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.of(context).size.width > 600 ? 24.0 : 16.0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with back button
            Row(
              children: [
                IconButton(
                  onPressed: () => setState(() => _selectedFunction = -1),
                  icon: const Icon(Icons.arrow_back, color: evsuRed),
                ),
                Expanded(
                  child: Text(
                    'Service Registration',
                    style: TextStyle(
                      fontSize:
                          MediaQuery.of(context).size.width > 600 ? 28 : 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Responsive layout with MediaQuery
            LayoutBuilder(
              builder: (context, constraints) {
                final screenWidth = MediaQuery.of(context).size.width;
                bool isWideScreen = screenWidth > 800;

                return isWideScreen
                    ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: _buildServiceForm()),
                        const SizedBox(width: 20),
                        Expanded(flex: 1, child: _buildServiceList()),
                      ],
                    )
                    : Column(
                      children: [
                        _buildServiceForm(),
                        const SizedBox(height: 20),
                        _buildServiceList(),
                      ],
                    );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceForm() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Create Service Account',
            style: TextStyle(
              fontSize: isMobile ? 18 : 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: isMobile ? 16 : 24),

          // Form fields with flexible spacing
          _buildFormField(
            'Service Name',
            Icons.business,
            _serviceNameController,
          ),
          SizedBox(height: isMobile ? 12 : 16),

          // Service Category Dropdown
          _buildServiceCategoryDropdown(),
          SizedBox(height: isMobile ? 12 : 16),

          // Conditional Operational Type Dropdown (only for Campus Service Units)
          if (_selectedServiceCategory == 'Campus Service Units') ...[
            _buildOperationalTypeDropdown(),
            SizedBox(height: isMobile ? 12 : 16),
          ],

          // Conditional Main Service Selection (only if Sub is selected)
          if (_selectedServiceCategory == 'Campus Service Units' &&
              _selectedOperationalType == 'Sub') ...[
            _buildMainServiceDropdown(),
            SizedBox(height: isMobile ? 12 : 16),
          ],

          _buildFormField(
            'Contact Person',
            Icons.person,
            _contactPersonController,
          ),
          SizedBox(height: isMobile ? 12 : 16),
          _buildFormField('Email Address', Icons.email, _emailController),
          SizedBox(height: isMobile ? 12 : 16),
          _buildFormField('Phone Number', Icons.phone, _phoneController),
          SizedBox(height: isMobile ? 12 : 16),
          _buildFormField(
            'Username',
            Icons.account_circle,
            _usernameController,
          ),
          SizedBox(height: isMobile ? 12 : 16),
          _buildPasswordField(),
          SizedBox(height: isMobile ? 12 : 16),
          _buildFormField(
            'Scanner ID (Optional)',
            Icons.qr_code_scanner,
            _scannerIdController,
          ),
          SizedBox(height: isMobile ? 12 : 16),
          _buildFormField(
            'Commission Rate (%)',
            Icons.percent,
            _commissionRateController,
          ),
          SizedBox(height: isMobile ? 16 : 24),

          // Action buttons - responsive layout
          isMobile
              ? Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          _isCreatingAccount ? null : _createServiceAccount,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: evsuRed,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child:
                          _isCreatingAccount
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                              : const Text(
                                'Create Service Account',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _isCreatingAccount ? null : _clearForm,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: evsuRed),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Clear',
                        style: TextStyle(
                          color: evsuRed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              )
              : Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed:
                          _isCreatingAccount ? null : _createServiceAccount,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: evsuRed,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child:
                          _isCreatingAccount
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                              : const Text(
                                'Create Service Account',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Flexible(
                    child: OutlinedButton(
                      onPressed: _isCreatingAccount ? null : _clearForm,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: evsuRed),
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 24,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Clear',
                        style: TextStyle(
                          color: evsuRed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
        ],
      ),
    );
  }

  Widget _buildServiceAccountManagement() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Header with back button
          Container(
            color: evsuRed,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => setState(() => _selectedFunction = -1),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                ),
                Expanded(
                  child: Text(
                    'Service Account Management',
                    style: TextStyle(
                      fontSize:
                          MediaQuery.of(context).size.width > 600 ? 28 : 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Statistics Header
          Container(
            color: evsuRed,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: FutureBuilder<Map<String, dynamic>>(
              future: SupabaseService.getServiceAccounts(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                }

                if (snapshot.hasError ||
                    !snapshot.hasData ||
                    !snapshot.data!['success']) {
                  return const Center(
                    child: Text(
                      'Error loading statistics',
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                }

                final serviceAccounts = List<Map<String, dynamic>>.from(
                  snapshot.data!['data'],
                );

                return Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Total Services',
                        value: serviceAccounts.length.toString(),
                        icon: Icons.business_center,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: 'Active',
                        value:
                            serviceAccounts
                                .where((s) => s['is_active'] == true)
                                .length
                                .toString(),
                        icon: Icons.check_circle,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: 'Main Accounts',
                        value:
                            serviceAccounts
                                .where((s) => s['operational_type'] == 'Main')
                                .length
                                .toString(),
                        icon: Icons.account_balance,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: 'Sub Accounts',
                        value:
                            serviceAccounts
                                .where((s) => s['operational_type'] == 'Sub')
                                .length
                                .toString(),
                        icon: Icons.subdirectory_arrow_right,
                        color: Colors.white,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Service List
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.of(context).size.width > 600 ? 24.0 : 16.0,
            ),
            child: _buildServiceManagementList(),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceManagementList() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24.0),
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
          Text(
            'Manage Service Accounts',
            style: TextStyle(
              fontSize: MediaQuery.of(context).size.width > 600 ? 20 : 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),

          // Service accounts list
          FutureBuilder<Map<String, dynamic>>(
            future: SupabaseService.getServiceAccounts(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: evsuRed),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error loading service accounts: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }

              if (!snapshot.hasData || !snapshot.data!['success']) {
                return const Center(child: Text('No service accounts found'));
              }

              final services = List<Map<String, dynamic>>.from(
                snapshot.data!['data'],
              );

              if (services.isEmpty) {
                return const Center(
                  child: Text('No service accounts available'),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: services.length,
                itemBuilder: (context, index) {
                  final service = services[index];
                  return _buildServiceManagementItem(service);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildServiceManagementItem(Map<String, dynamic> service) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service['service_name'] ?? 'Unknown Service',
                      style: TextStyle(
                        fontSize: isMobile ? 16 : 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      service['service_category'] ?? 'No Category',
                      style: TextStyle(
                        fontSize: isMobile ? 12 : 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      service['is_active'] == true ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  service['is_active'] == true ? 'Active' : 'Inactive',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Service details
          Row(
            children: [
              Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  service['location'] ?? 'No location specified',
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),

          if (service['scanner_id'] != null &&
              service['scanner_id'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.bluetooth, size: 16, color: Colors.blue.shade600),
                const SizedBox(width: 4),
                Text(
                  'Scanner: ${service['scanner_id']}',
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 14,
                    color: Colors.blue.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 12),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _editServiceAccount(service),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: evsuRed,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: isMobile ? 8 : 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _toggleServiceStatus(service),
                  icon: Icon(
                    service['is_active'] == true
                        ? Icons.pause
                        : Icons.play_arrow,
                    size: 16,
                  ),
                  label: Text(
                    service['is_active'] == true ? 'Deactivate' : 'Activate',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        service['is_active'] == true
                            ? Colors.orange
                            : Colors.green,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: isMobile ? 8 : 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _deleteServiceAccount(service),
                  icon: const Icon(Icons.delete, size: 16),
                  label: const Text('Delete'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: isMobile ? 8 : 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _editServiceAccount(Map<String, dynamic> service) {
    final nameCtrl = TextEditingController(text: service['service_name'] ?? '');
    final contactCtrl = TextEditingController(
      text: service['contact_person'] ?? '',
    );
    final emailCtrl = TextEditingController(text: service['email'] ?? '');
    final phoneCtrl = TextEditingController(text: service['phone'] ?? '');
    final usernameCtrl = TextEditingController(text: service['username'] ?? '');
    final scannerCtrl = TextEditingController(
      text: service['scanner_id'] ?? '',
    );
    final commissionCtrl = TextEditingController(
      text: (service['commission_rate'] ?? 0.0).toString(),
    );

    showDialog(
      context: context,
      builder: (context) {
        bool saving = false;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Edit Service Account'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Service Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: contactCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Contact Person',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: phoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Phone',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: usernameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: scannerCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Scanner ID (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: commissionCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Commission Rate (%)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed:
                      saving
                          ? null
                          : () async {
                            setStateDialog(() => saving = true);
                            final result =
                                await SupabaseService.updateServiceAccount(
                                  accountId: service['id'],
                                  serviceName: nameCtrl.text.trim(),
                                  contactPerson: contactCtrl.text.trim(),
                                  email: emailCtrl.text.trim(),
                                  phone: phoneCtrl.text.trim(),
                                  scannerId:
                                      scannerCtrl.text.trim().isEmpty
                                          ? null
                                          : scannerCtrl.text.trim(),
                                  commissionRate: double.tryParse(
                                    commissionCtrl.text.trim(),
                                  ),
                                );
                            setStateDialog(() => saving = false);
                            if (result['success'] == true) {
                              if (mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Service updated successfully',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                setState(() {}); // refresh list
                              }
                            } else {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Update failed: ${result['message']}',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: evsuRed,
                    foregroundColor: Colors.white,
                  ),
                  child:
                      saving
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _toggleServiceStatus(Map<String, dynamic> service) {
    final bool newStatus = !(service['is_active'] == true);
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(newStatus ? 'Activate Service' : 'Deactivate Service'),
            content: Text(
              'Are you sure you want to ${newStatus ? 'activate' : 'deactivate'} "${service['service_name']}"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  final result = await SupabaseService.updateServiceAccount(
                    accountId: service['id'],
                    isActive: newStatus,
                  );
                  if (result['success'] == true) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Service ${newStatus ? 'activated' : 'deactivated'} successfully',
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                      setState(() {});
                    }
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Operation failed: ${result['message']}',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: Text(newStatus ? 'Activate' : 'Deactivate'),
              ),
            ],
          ),
    );
  }

  void _deleteServiceAccount(Map<String, dynamic> service) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Service Account'),
            content: Text(
              'Are you sure you want to delete "${service['service_name']}"? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  final result = await SupabaseService.deleteServiceAccount(
                    accountId: service['id'],
                  );
                  if (result['success'] == true) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Service account deleted successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      setState(() {});
                    }
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Delete failed: ${result['message']}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildScannerAssignment() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    // Load data when this function is first accessed
    if (_services.isEmpty && !_isLoadingScanners) {
      _loadScannerData();
    }

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth > 600 ? 24.0 : 16.0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with back button
            Row(
              children: [
                IconButton(
                  onPressed: () => setState(() => _selectedFunction = -1),
                  icon: const Icon(Icons.arrow_back, color: evsuRed),
                ),
                Expanded(
                  child: Text(
                    'RFID Scanner Assignment',
                    style: TextStyle(
                      fontSize: isMobile ? 24 : 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 20 : 30),

            // Scanner assignment interface
            _isLoadingScanners
                ? const Center(child: CircularProgressIndicator())
                : LayoutBuilder(
                  builder: (context, constraints) {
                    bool isWideScreen = constraints.maxWidth > 800;

                    return isWideScreen
                        ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 1,
                              child: _buildScannerAssignmentForm(),
                            ),
                            const SizedBox(width: 20),
                            Expanded(flex: 1, child: _buildScannerList()),
                          ],
                        )
                        : Column(
                          children: [
                            _buildScannerAssignmentForm(),
                            SizedBox(height: isMobile ? 20 : 30),
                            _buildScannerList(),
                          ],
                        );
                  },
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerAssignmentForm() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Container(
      padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
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
          Text(
            'Assign RFID Scanner',
            style: TextStyle(
              fontSize: isMobile ? 18 : 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: isMobile ? 16 : 20),

          // Service Selection
          Text(
            'Select Service',
            style: TextStyle(
              fontSize: isMobile ? 14 : 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedServiceId,
                hint: const Text('Choose service to assign scanner'),
                isExpanded: true,
                items:
                    _services.map((service) {
                      return DropdownMenuItem<String>(
                        value: service['id'].toString(),
                        child: Text(
                          service['service_name'] ?? 'Unknown Service',
                        ),
                      );
                    }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedServiceId = value;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Scanner Selection
          Text(
            'Select RFID Scanner',
            style: TextStyle(
              fontSize: isMobile ? 14 : 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedScannerId,
                hint: const Text('Choose EvsuPay1-100 scanner'),
                isExpanded: true,
                items: _buildScannerDropdownItems(),
                onChanged: (value) {
                  setState(() {
                    _selectedScannerId = value;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Assignment Summary
          Container(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue.shade600,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Assignment Summary',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade700,
                        fontSize: isMobile ? 12 : 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Services with scanners: ${_services.where((s) => s['scanner_id'] != null && s['scanner_id'].toString().isNotEmpty).length}',
                  style: TextStyle(
                    color: Colors.blue.shade600,
                    fontSize: isMobile ? 11 : 12,
                  ),
                ),
                Text(
                  'Services without scanners: ${_services.where((s) => s['scanner_id'] == null || s['scanner_id'].toString().isEmpty).length}',
                  style: TextStyle(
                    color: Colors.blue.shade600,
                    fontSize: isMobile ? 11 : 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Assign Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _assignScanner,
              style: ElevatedButton.styleFrom(
                backgroundColor: evsuRed,
                padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Assign Scanner',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isMobile ? 14 : 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerList() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    // Separate services with and without scanners
    final servicesWithScanners =
        _services
            .where(
              (service) =>
                  service['scanner_id'] != null &&
                  service['scanner_id'].toString().isNotEmpty,
            )
            .toList();
    final servicesWithoutScanners =
        _services
            .where(
              (service) =>
                  service['scanner_id'] == null ||
                  service['scanner_id'].toString().isEmpty,
            )
            .toList();

    return Container(
      padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
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
          Text(
            'Service Scanner Assignments',
            style: TextStyle(
              fontSize: isMobile ? 18 : 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: isMobile ? 16 : 20),

          // Services with scanners
          Text(
            'Services with RFID Scanners (${servicesWithScanners.length})',
            style: TextStyle(
              fontSize: isMobile ? 14 : 16,
              fontWeight: FontWeight.w500,
              color: Colors.green.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 200,
            child:
                servicesWithScanners.isEmpty
                    ? Center(
                      child: Text(
                        'No services have scanners assigned',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: isMobile ? 12 : 14,
                        ),
                      ),
                    )
                    : ListView.builder(
                      itemCount: servicesWithScanners.length,
                      itemBuilder: (context, index) {
                        final service = servicesWithScanners[index];
                        return _buildServiceWithScannerItem(service);
                      },
                    ),
          ),
          const SizedBox(height: 16),

          // Services without scanners
          Text(
            'Services without RFID Scanners (${servicesWithoutScanners.length})',
            style: TextStyle(
              fontSize: isMobile ? 14 : 16,
              fontWeight: FontWeight.w500,
              color: Colors.orange.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 200,
            child:
                servicesWithoutScanners.isEmpty
                    ? Center(
                      child: Text(
                        'All services have scanners assigned',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: isMobile ? 12 : 14,
                        ),
                      ),
                    )
                    : ListView.builder(
                      itemCount: servicesWithoutScanners.length,
                      itemBuilder: (context, index) {
                        final service = servicesWithoutScanners[index];
                        return _buildServiceWithoutScannerItem(service);
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceWithScannerItem(Map<String, dynamic> service) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.bluetooth, color: Colors.green.shade600, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service['service_name'] ?? 'Unknown Service',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isMobile ? 14 : 16,
                  ),
                ),
                Text(
                  'Scanner: ${service['scanner_id']} • ${service['service_category'] ?? 'Unknown'}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: isMobile ? 12 : 14,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _unassignScanner(service['scanner_id']),
            icon: const Icon(Icons.remove_circle, color: Colors.red),
            iconSize: 20,
            tooltip: 'Unassign Scanner',
          ),
        ],
      ),
    );
  }

  Widget _buildServiceWithoutScannerItem(Map<String, dynamic> service) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(
            Icons.bluetooth_disabled,
            color: Colors.orange.shade600,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service['service_name'] ?? 'Unknown Service',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isMobile ? 14 : 16,
                  ),
                ),
                Text(
                  '${service['service_category'] ?? 'Unknown'} • No Scanner Assigned',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: isMobile ? 12 : 14,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Needs Scanner',
              style: TextStyle(
                color: Colors.orange.shade700,
                fontSize: isMobile ? 10 : 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Additional helper methods for service management
  Widget _buildServiceList() {
    // This will be populated from database in a real implementation
    final services = [
      {
        'name': 'Campus Cafeteria',
        'status': 'Active',
        'type': 'Food Service',
        'operational_type': 'Main',
        'balance': 1250.50,
      },
      {
        'name': 'IGP Printing',
        'status': 'Active',
        'type': 'Print Shop',
        'operational_type': 'Sub',
        'main_service': 'Campus Cafeteria',
      },
      {
        'name': 'Student Store',
        'status': 'Active',
        'type': 'Retail',
        'operational_type': 'Main',
        'balance': 890.25,
      },
      {
        'name': 'Library Services',
        'status': 'Active',
        'type': 'Educational',
        'operational_type': 'Main',
        'balance': 2100.75,
      },
    ];

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Registered Services',
            style: TextStyle(
              fontSize: isMobile ? 18 : 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: isMobile ? 12 : 16),

          ...services.map((service) => _buildServiceListItem(service)).toList(),
        ],
      ),
    );
  }

  Widget _buildServiceListItem(Map<String, dynamic> service) {
    final isActive = service['status'] == 'Active';
    final isMainAccount = service['operational_type'] == 'Main';
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 8 : 12),
      padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
      decoration: BoxDecoration(
        color: isMainAccount ? Colors.blue.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isMainAccount ? Colors.blue.shade200 : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: isMobile ? 30 : 40,
            decoration: BoxDecoration(
              color:
                  isActive
                      ? (isMainAccount ? Colors.blue : Colors.green)
                      : Colors.orange,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      service['name']!,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: isMobile ? 14 : 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isMainAccount) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'MAIN',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'SUB',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  service['type']!,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: isMobile ? 12 : 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (isMainAccount && service['balance'] != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Balance: ₱${service['balance'].toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontSize: isMobile ? 11 : 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ] else if (!isMainAccount &&
                    service['main_service'] != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Connected to: ${service['main_service']}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: isMobile ? 11 : 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 8 : 12,
              vertical: isMobile ? 4 : 6,
            ),
            decoration: BoxDecoration(
              color: isActive ? Colors.green.shade100 : Colors.orange.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              service['status']!,
              style: TextStyle(
                color:
                    isActive ? Colors.green.shade700 : Colors.orange.shade700,
                fontSize: isMobile ? 10 : 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommissionManagement() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _selectedFunction = -1),
                icon: const Icon(Icons.arrow_back, color: evsuRed),
              ),
              const Text(
                'Commission Management',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),

          // Commission management content
          _buildCommissionContent(),
        ],
      ),
    );
  }

  Widget _buildCommissionContent() {
    return Container(
      padding: const EdgeInsets.all(24),
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
      child: const Text(
        'Commission rate management and vendor payment settings would be displayed here.',
        style: TextStyle(fontSize: 16, color: Colors.grey),
      ),
    );
  }

  Widget _buildFormField(
    String label,
    IconData icon,
    TextEditingController controller,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isMobile ? 12 : 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: isMobile ? 6 : 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: evsuRed, size: isMobile ? 20 : 24),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: evsuRed),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 16,
              vertical: isMobile ? 10 : 12,
            ),
            isDense: isMobile,
          ),
        ),
      ],
    );
  }

  Widget _buildServiceCategoryDropdown() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Service Category',
          style: TextStyle(
            fontSize: isMobile ? 12 : 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: isMobile ? 6 : 8),
        DropdownButtonFormField<String>(
          value: _selectedServiceCategory,
          isExpanded: true, // Prevent overflow
          decoration: InputDecoration(
            prefixIcon: Icon(
              Icons.category,
              color: evsuRed,
              size: isMobile ? 20 : 24,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: evsuRed),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 16,
              vertical: isMobile ? 10 : 12,
            ),
            isDense: isMobile,
          ),
          items:
              _serviceCategories.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Flexible(
                    child: Text(
                      value,
                      style: TextStyle(fontSize: isMobile ? 12 : 14),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                );
              }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              _selectedServiceCategory = newValue;
              // Reset dependent dropdowns
              _selectedOperationalType = null;
              _selectedMainServiceId = null;
            });
          },
          validator:
              (value) =>
                  value == null ? 'Please select a service category' : null,
        ),
      ],
    );
  }

  Widget _buildOperationalTypeDropdown() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Operational Type',
          style: TextStyle(
            fontSize: isMobile ? 12 : 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: isMobile ? 6 : 8),
        DropdownButtonFormField<String>(
          value: _selectedOperationalType,
          isExpanded: true, // Prevent overflow
          decoration: InputDecoration(
            prefixIcon: Icon(
              Icons.settings,
              color: evsuRed,
              size: isMobile ? 20 : 24,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: evsuRed),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 16,
              vertical: isMobile ? 10 : 12,
            ),
            isDense: isMobile,
          ),
          items:
              _operationalTypes.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Flexible(
                    child: Text(
                      value,
                      style: TextStyle(fontSize: isMobile ? 12 : 14),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                );
              }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              _selectedOperationalType = newValue;
              // Reset main service selection when changing operational type
              _selectedMainServiceId = null;
            });

            // Load main services when Sub is selected
            if (newValue == 'Sub') {
              _loadMainServices();
            }
          },
          validator:
              (value) =>
                  value == null ? 'Please select an operational type' : null,
        ),
      ],
    );
  }

  Widget _buildMainServiceDropdown() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Connected to Main Service',
          style: TextStyle(
            fontSize: isMobile ? 12 : 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: isMobile ? 6 : 8),
        DropdownButtonFormField<int>(
          value: _selectedMainServiceId,
          isExpanded: true, // Prevent overflow
          decoration: InputDecoration(
            prefixIcon: Icon(
              Icons.link,
              color: evsuRed,
              size: isMobile ? 20 : 24,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: evsuRed),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 16,
              vertical: isMobile ? 10 : 12,
            ),
            isDense: isMobile,
          ),
          items:
              _mainServices.map<DropdownMenuItem<int>>((
                Map<String, dynamic> service,
              ) {
                return DropdownMenuItem<int>(
                  value: service['id'],
                  child: Flexible(
                    child: Text(
                      service['service_name'],
                      style: TextStyle(fontSize: isMobile ? 12 : 14),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                );
              }).toList(),
          onChanged: (int? newValue) {
            setState(() {
              _selectedMainServiceId = newValue;
            });
          },
          validator:
              (value) =>
                  value == null
                      ? 'Please select a main service to connect to'
                      : null,
        ),
        if (_isLoadingMainServices)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(evsuRed),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Loading main services...',
                  style: TextStyle(
                    fontSize: isMobile ? 10 : 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPasswordField() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Password',
          style: TextStyle(
            fontSize: isMobile ? 12 : 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: isMobile ? 6 : 8),
        TextFormField(
          controller: _passwordController,
          obscureText: true,
          decoration: InputDecoration(
            prefixIcon: Icon(
              Icons.lock,
              color: evsuRed,
              size: isMobile ? 20 : 24,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: evsuRed),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 16,
              vertical: isMobile ? 10 : 12,
            ),
            isDense: isMobile,
          ),
        ),
      ],
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Success'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  // Scanner dropdown items (EvsuPay1-100)
  List<DropdownMenuItem<String>> _buildScannerDropdownItems() {
    List<DropdownMenuItem<String>> items = [];

    for (int i = 1; i <= 100; i++) {
      String scannerId = 'EvsuPay$i';
      // Check if this scanner is already assigned
      bool isAssignedToService = _services.any(
        (service) => service['scanner_id'] == scannerId,
      );
      bool isAssignedToAdmin = _adminAccounts.any(
        (admin) => admin['scanner_id'] == scannerId,
      );
      bool isAssigned = isAssignedToService || isAssignedToAdmin;

      items.add(
        DropdownMenuItem<String>(
          value: scannerId,
          enabled: !isAssigned,
          child: Row(
            children: [
              Icon(
                Icons.bluetooth,
                color: isAssigned ? Colors.grey : Colors.green[700],
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  scannerId,
                  style: TextStyle(
                    color: isAssigned ? Colors.grey : Colors.black87,
                  ),
                ),
              ),
              if (isAssigned)
                Text(
                  isAssignedToAdmin ? '(Assigned to Admin)' : '(Assigned)',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
            ],
          ),
        ),
      );
    }

    return items;
  }

  // Load scanner data
  Future<void> _loadScannerData() async {
    setState(() {
      _isLoadingScanners = true;
    });

    try {
      // Load services
      final servicesResult = await SupabaseService.getServiceAccounts();
      if (servicesResult['success']) {
        setState(() {
          _services = List<Map<String, dynamic>>.from(servicesResult['data']);
        });
      }

      // Also load admin accounts to cross-check assigned scanners for dropdown disabling
      if (_adminAccounts.isEmpty) {
        try {
          await _loadAdminAccountsFallback();
        } catch (_) {
          // ignore: just for dropdown disabling; UI already handles admin loading elsewhere
        }
      }

      // Load scanners from database
      await _loadScanners();
    } catch (e) {
      _showErrorDialog('Error loading data: $e');
    } finally {
      setState(() {
        _isLoadingScanners = false;
      });
    }
  }

  Future<void> _loadScanners() async {
    try {
      // Reload services to get updated scanner assignments
      final servicesResult = await SupabaseService.getServiceAccounts();
      if (servicesResult['success']) {
        setState(() {
          _services = List<Map<String, dynamic>>.from(servicesResult['data']);
        });
      }
    } catch (e) {
      _showErrorDialog('Error loading scanner data: $e');
    }
  }

  Future<void> _assignScanner() async {
    if (_selectedServiceId == null || _selectedScannerId == null) {
      _showErrorDialog('Please select both service and scanner');
      return;
    }

    // Check if scanner is already assigned
    bool isAlreadyAssignedToService = _services.any(
      (service) => service['scanner_id'] == _selectedScannerId,
    );
    bool isAlreadyAssignedToAdmin = _adminAccounts.any(
      (admin) => admin['scanner_id'] == _selectedScannerId,
    );
    bool isAlreadyAssigned =
        isAlreadyAssignedToService || isAlreadyAssignedToAdmin;

    if (isAlreadyAssigned) {
      _showErrorDialog('This scanner is already assigned to another account');
      return;
    }

    try {
      // Insert scanner into database if not exists
      await _ensureScannerExists(_selectedScannerId!);

      // Assign scanner to service using the updated function
      final response = await SupabaseService.client.rpc(
        'assign_scanner_to_service',
        params: {
          'scanner_device_id': _selectedScannerId!,
          'service_account_id': int.parse(_selectedServiceId!),
        },
      );

      if (response == true) {
        _showSuccessDialog('Scanner assigned successfully');
        await _loadScanners();
        setState(() {
          _selectedServiceId = null;
          _selectedScannerId = null;
        });
      } else {
        _showErrorDialog('Failed to assign scanner');
      }
    } catch (e) {
      _showErrorDialog('Error assigning scanner: $e');
    }
  }

  Future<void> _ensureScannerExists(String scannerId) async {
    try {
      // Check if scanner exists in database
      final existing =
          await SupabaseService.client
              .from('scanner_devices')
              .select('id')
              .eq('scanner_id', scannerId)
              .maybeSingle();

      if (existing == null) {
        // Use a more permissive approach - try to insert with proper error handling
        try {
          await SupabaseService.client.from('scanner_devices').insert({
            'scanner_id': scannerId,
            'device_name':
                'RFID Bluetooth Scanner ${scannerId.replaceAll('EvsuPay', '')}',
            'device_type': 'RFID_Bluetooth_Scanner',
            'model': 'ESP32 RFID',
            'serial_number':
                'ESP${scannerId.replaceAll('EvsuPay', '').padLeft(3, '0')}',
            'status': 'Available',
            'notes': 'Ready for assignment',
          });
        } catch (insertError) {
          // If direct insert fails due to RLS, try using a database function
          print(
            'Direct insert failed, scanner may already exist or RLS issue: $insertError',
          );
          // The assignment function will handle scanner creation
        }
      }
    } catch (e) {
      print('Error ensuring scanner exists: $e');
      // Continue with assignment - the function will handle scanner creation
    }
  }

  Future<void> _unassignScanner(String scannerId) async {
    try {
      final response = await SupabaseService.client.rpc(
        'unassign_scanner_from_service',
        params: {'scanner_device_id': scannerId},
      );

      if (response == true) {
        _showSuccessDialog('Scanner unassigned successfully');
        await _loadScanners();
      } else {
        _showErrorDialog('Failed to unassign scanner');
      }
    } catch (e) {
      _showErrorDialog('Error unassigning scanner: $e');
    }
  }

  Widget _buildFunctionCard({
    required int index,
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
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
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withOpacity(0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey.shade400,
                  size: 16,
                ),
              ],
            ),
            const SizedBox(height: 15),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Service Account Management Methods

  Future<void> _loadMainServices() async {
    setState(() {
      _isLoadingMainServices = true;
    });

    try {
      final result = await SupabaseService.getMainServiceAccounts();
      if (result['success']) {
        setState(() {
          _mainServices = List<Map<String, dynamic>>.from(result['data']);
        });
      } else {
        _showErrorDialog('Failed to load main services: ${result['message']}');
      }
    } catch (e) {
      _showErrorDialog('Error loading main services: ${e.toString()}');
    } finally {
      setState(() {
        _isLoadingMainServices = false;
      });
    }
  }

  Future<void> _createServiceAccount() async {
    // Validate form
    if (!_validateForm()) return;

    setState(() {
      _isCreatingAccount = true;
    });

    try {
      final result = await SupabaseService.createServiceAccount(
        serviceName: _serviceNameController.text.trim(),
        serviceCategory: _selectedServiceCategory!,
        operationalType: _selectedOperationalType ?? 'Main',
        mainServiceId:
            _selectedOperationalType == 'Sub' ? _selectedMainServiceId : null,
        contactPerson: _contactPersonController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text.trim(),
        scannerId:
            _scannerIdController.text.trim().isNotEmpty
                ? _scannerIdController.text.trim()
                : null,
        commissionRate:
            double.tryParse(_commissionRateController.text.trim()) ?? 0.0,
      );

      if (result['success']) {
        _showSuccessDialog('Service account created successfully!');
        _clearForm();
      } else {
        _showErrorDialog(
          'Failed to create service account: ${result['message']}',
        );
      }
    } catch (e) {
      _showErrorDialog('Error creating service account: ${e.toString()}');
    } finally {
      setState(() {
        _isCreatingAccount = false;
      });
    }
  }

  bool _validateForm() {
    // Validate service name
    if (_serviceNameController.text.trim().isEmpty) {
      _showErrorDialog('Please enter service name');
      return false;
    }

    // Validate service category
    if (_selectedServiceCategory == null) {
      _showErrorDialog('Please select service category');
      return false;
    }

    // Validate operational type for Campus Service Units
    if (_selectedServiceCategory == 'Campus Service Units' &&
        _selectedOperationalType == null) {
      _showErrorDialog('Please select operational type');
      return false;
    }

    // Validate main service selection for sub accounts
    if (_selectedOperationalType == 'Sub' && _selectedMainServiceId == null) {
      _showErrorDialog('Please select a main service to connect to');
      return false;
    }

    // Validate contact person
    if (_contactPersonController.text.trim().isEmpty) {
      _showErrorDialog('Please enter contact person');
      return false;
    }

    // Validate email (more flexible)
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showErrorDialog('Please enter email address');
      return false;
    }

    // Basic email validation (not strict EVSU requirement)
    if (!_isValidEmail(email)) {
      _showErrorDialog('Please enter a valid email address');
      return false;
    }

    // Validate phone
    if (_phoneController.text.trim().isEmpty) {
      _showErrorDialog('Please enter phone number');
      return false;
    }

    // Validate username
    if (_usernameController.text.trim().isEmpty) {
      _showErrorDialog('Please enter username');
      return false;
    }

    // Validate password
    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      _showErrorDialog('Please enter password');
      return false;
    }
    if (password.length < 6) {
      _showErrorDialog('Password must be at least 6 characters long');
      return false;
    }

    return true;
  }

  // Helper function for basic email validation
  bool _isValidEmail(String email) {
    return RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(email);
  }

  void _clearForm() {
    _serviceNameController.clear();
    _contactPersonController.clear();
    _emailController.clear();
    _phoneController.clear();
    _usernameController.clear();
    _passwordController.clear();
    _scannerIdController.clear();
    _commissionRateController.clear();

    setState(() {
      _selectedServiceCategory = null;
      _selectedOperationalType = null;
      _selectedMainServiceId = null;
      _mainServices.clear();
    });
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Error'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  Widget _buildAdminScannerAssignment() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    // Load data when this function is first accessed
    if (_adminAccounts.isEmpty && !_isLoadingAdminScanners) {
      print('DEBUG: Loading admin scanner data...');
      _loadAdminScannerData();
    }

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth > 600 ? 24.0 : 16.0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with back button
            Row(
              children: [
                IconButton(
                  onPressed: () => setState(() => _selectedFunction = -1),
                  icon: const Icon(Icons.arrow_back, color: evsuRed),
                ),
                Expanded(
                  child: Text(
                    'Admin Scanner Assignment',
                    style: TextStyle(
                      fontSize: isMobile ? 24 : 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 20 : 30),

            // Admin scanner assignment interface
            _isLoadingAdminScanners
                ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        'Loading admin accounts and scanner data...',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Debug: _adminAccounts.length = ${_adminAccounts.length}',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ),
                )
                : LayoutBuilder(
                  builder: (context, constraints) {
                    bool isWideScreen = constraints.maxWidth > 800;

                    // Show error message if no admin accounts are loaded
                    if (_adminAccounts.isEmpty) {
                      return Center(
                        child: Container(
                          padding: EdgeInsets.all(isMobile ? 20 : 30),
                          margin: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.red.shade600,
                                size: 48,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No Admin Accounts Found',
                                style: TextStyle(
                                  fontSize: isMobile ? 18 : 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade700,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'This might be due to Row Level Security (RLS) policies blocking access to the admin_accounts table.',
                                style: TextStyle(
                                  fontSize: isMobile ? 14 : 16,
                                  color: Colors.red.shade600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () {
                                  _showErrorDialog(
                                    'Please run the fix_admin_accounts_rls.sql script in your database to enable access to admin accounts for scanner assignment.',
                                  );
                                },
                                icon: const Icon(Icons.info_outline),
                                label: const Text('View Instructions'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade600,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextButton.icon(
                                onPressed: _loadAdminScannerData,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry Loading'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return isWideScreen
                        ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 1,
                              child: _buildAdminScannerAssignmentForm(),
                            ),
                            const SizedBox(width: 20),
                            Expanded(flex: 1, child: _buildAdminScannerList()),
                          ],
                        )
                        : Column(
                          children: [
                            _buildAdminScannerAssignmentForm(),
                            SizedBox(height: isMobile ? 20 : 30),
                            _buildAdminScannerList(),
                          ],
                        );
                  },
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminScannerAssignmentForm() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Container(
      padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
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
          Text(
            'Assign Scanner to Admin',
            style: TextStyle(
              fontSize: isMobile ? 18 : 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: isMobile ? 16 : 20),

          // Admin Selection
          Text(
            'Select Admin Account',
            style: TextStyle(
              fontSize: isMobile ? 14 : 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedAdminId,
                hint: const Text('Choose admin account'),
                isExpanded: true,
                items:
                    _adminAccounts.map((admin) {
                      return DropdownMenuItem<String>(
                        value: admin['id'].toString(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              admin['full_name'] ?? 'Unknown Admin',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${admin['username']} • ${admin['role']}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedAdminId = value;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Scanner Selection
          Text(
            'Select RFID Scanner',
            style: TextStyle(
              fontSize: isMobile ? 14 : 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedAdminScannerId,
                hint: const Text('Choose available scanner'),
                isExpanded: true,
                items: _buildAdminScannerDropdownItems(),
                onChanged: (value) {
                  setState(() {
                    _selectedAdminScannerId = value;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Assignment Summary
          Container(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.indigo.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.indigo.shade600,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Assignment Summary',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.indigo.shade700,
                        fontSize: isMobile ? 12 : 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Admins with scanners: ${_adminAccounts.where((a) => a['scanner_id'] != null && a['scanner_id'].toString().isNotEmpty).length}',
                  style: TextStyle(
                    color: Colors.indigo.shade600,
                    fontSize: isMobile ? 11 : 12,
                  ),
                ),
                Text(
                  'Admins without scanners: ${_adminAccounts.where((a) => a['scanner_id'] == null || a['scanner_id'].toString().isEmpty).length}',
                  style: TextStyle(
                    color: Colors.indigo.shade600,
                    fontSize: isMobile ? 11 : 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Assign Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _assignScannerToAdmin,
              style: ElevatedButton.styleFrom(
                backgroundColor: evsuRed,
                padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Assign Scanner',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isMobile ? 14 : 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminScannerList() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    // Separate admins with and without scanners
    final adminsWithScanners =
        _adminAccounts
            .where(
              (admin) =>
                  admin['scanner_id'] != null &&
                  admin['scanner_id'].toString().isNotEmpty,
            )
            .toList();
    final adminsWithoutScanners =
        _adminAccounts
            .where(
              (admin) =>
                  admin['scanner_id'] == null ||
                  admin['scanner_id'].toString().isEmpty,
            )
            .toList();

    return Container(
      padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
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
          Text(
            'Admin Scanner Assignments',
            style: TextStyle(
              fontSize: isMobile ? 18 : 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: isMobile ? 16 : 20),

          // Admins with scanners
          Text(
            'Admins with RFID Scanners (${adminsWithScanners.length})',
            style: TextStyle(
              fontSize: isMobile ? 14 : 16,
              fontWeight: FontWeight.w500,
              color: Colors.green.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 200,
            child:
                adminsWithScanners.isEmpty
                    ? Center(
                      child: Text(
                        'No admins have scanners assigned',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: isMobile ? 12 : 14,
                        ),
                      ),
                    )
                    : ListView.builder(
                      itemCount: adminsWithScanners.length,
                      itemBuilder: (context, index) {
                        final admin = adminsWithScanners[index];
                        return _buildAdminWithScannerItem(admin);
                      },
                    ),
          ),
          const SizedBox(height: 16),

          // Admins without scanners
          Text(
            'Admins without RFID Scanners (${adminsWithoutScanners.length})',
            style: TextStyle(
              fontSize: isMobile ? 14 : 16,
              fontWeight: FontWeight.w500,
              color: Colors.orange.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 200,
            child:
                adminsWithoutScanners.isEmpty
                    ? Center(
                      child: Text(
                        'All admins have scanners assigned',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: isMobile ? 12 : 14,
                        ),
                      ),
                    )
                    : ListView.builder(
                      itemCount: adminsWithoutScanners.length,
                      itemBuilder: (context, index) {
                        final admin = adminsWithoutScanners[index];
                        return _buildAdminWithoutScannerItem(admin);
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminWithScannerItem(Map<String, dynamic> admin) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(
            Icons.admin_panel_settings,
            color: Colors.green.shade600,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  admin['full_name'] ?? 'Unknown Admin',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isMobile ? 14 : 16,
                  ),
                ),
                Text(
                  'Scanner: ${admin['scanner_id']} • ${admin['role']}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: isMobile ? 12 : 14,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _unassignScannerFromAdmin(admin['id']),
            icon: const Icon(Icons.remove_circle, color: Colors.red),
            iconSize: 20,
            tooltip: 'Unassign Scanner',
          ),
        ],
      ),
    );
  }

  Widget _buildAdminWithoutScannerItem(Map<String, dynamic> admin) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(
            Icons.admin_panel_settings_outlined,
            color: Colors.orange.shade600,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  admin['full_name'] ?? 'Unknown Admin',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isMobile ? 14 : 16,
                  ),
                ),
                Text(
                  '${admin['role']} • No Scanner Assigned',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: isMobile ? 12 : 14,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Needs Scanner',
              style: TextStyle(
                color: Colors.orange.shade700,
                fontSize: isMobile ? 10 : 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Additional helper methods for admin scanner management
  List<DropdownMenuItem<String>> _buildAdminScannerDropdownItems() {
    List<DropdownMenuItem<String>> items = [];

    for (int i = 1; i <= 100; i++) {
      String scannerId = 'EvsuPay$i';
      // Check if this scanner is already assigned to services or admins
      bool isAssignedToService = _services.any(
        (service) => service['scanner_id'] == scannerId,
      );
      bool isAssignedToAdmin = _adminAccounts.any(
        (admin) => admin['scanner_id'] == scannerId,
      );

      items.add(
        DropdownMenuItem<String>(
          value: scannerId,
          child: Row(
            children: [
              Icon(
                Icons.bluetooth,
                color:
                    (isAssignedToService || isAssignedToAdmin)
                        ? Colors.grey
                        : Colors.green[700],
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  scannerId,
                  style: TextStyle(
                    color:
                        (isAssignedToService || isAssignedToAdmin)
                            ? Colors.grey
                            : Colors.black87,
                  ),
                ),
              ),
              if (isAssignedToService || isAssignedToAdmin)
                const Text(
                  '(Assigned)',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
            ],
          ),
        ),
      );
    }

    return items;
  }

  // Load admin scanner data
  Future<void> _loadAdminScannerData() async {
    setState(() {
      _isLoadingAdminScanners = true;
    });

    try {
      // First, try to load admin accounts using the RPC function
      try {
        final response = await SupabaseService.client.rpc(
          'get_admin_accounts_with_scanners',
        );
        if (response != null && response['success']) {
          setState(() {
            _adminAccounts = List<Map<String, dynamic>>.from(response['data']);
          });
        } else {
          // Fallback: load admin accounts directly from table
          await _loadAdminAccountsFallback();
        }
      } catch (rpcError) {
        print('RPC function failed, using fallback: $rpcError');
        // Fallback: load admin accounts directly from table
        await _loadAdminAccountsFallback();
      }

      // Load services to check scanner assignments
      final servicesResult = await SupabaseService.getServiceAccounts();
      if (servicesResult['success']) {
        setState(() {
          _services = List<Map<String, dynamic>>.from(servicesResult['data']);
        });
      } else {
        print('Failed to load services: ${servicesResult['message']}');
        setState(() {
          _services = [];
        });
      }
    } catch (e) {
      print('Error loading admin scanner data: $e');
      _showErrorDialog('Error loading data: $e');
      // Set empty lists to prevent infinite loading
      setState(() {
        _adminAccounts = [];
        _services = [];
      });
    } finally {
      setState(() {
        _isLoadingAdminScanners = false;
      });
    }
  }

  // Fallback method to load admin accounts directly from table
  Future<void> _loadAdminAccountsFallback() async {
    try {
      print('DEBUG: Attempting to load admin accounts directly from table...');

      // Try multiple approaches to load admin accounts
      List<Map<String, dynamic>> accounts = [];

      // Approach 1: Check authentication status first
      try {
        final currentUser = SupabaseService.client.auth.currentUser;
        print('Current auth user: ${currentUser?.id}');
        print('Current auth email: ${currentUser?.email}');
        print('Is authenticated: ${currentUser != null}');
      } catch (authError) {
        print('Auth check failed: $authError');
      }

      // Approach 2: Direct table query
      try {
        final response = await SupabaseService.client
            .from('admin_accounts')
            .select(
              'id, username, full_name, email, role, is_active, scanner_id, created_at, updated_at',
            )
            .order('full_name');

        accounts = List<Map<String, dynamic>>.from(response);
        print(
          'Successfully loaded ${accounts.length} admin accounts via direct query',
        );
      } catch (directError) {
        print('Direct query failed: $directError');

        // Approach 2: Try with different select fields
        try {
          final response = await SupabaseService.client
              .from('admin_accounts')
              .select('id, username, full_name, role, scanner_id')
              .order('full_name');

          accounts = List<Map<String, dynamic>>.from(response);
          print(
            'Successfully loaded ${accounts.length} admin accounts via simplified query',
          );
        } catch (simpleError) {
          print('Simplified query failed: $simpleError');

          // Approach 3: Try with minimal fields
          try {
            final response = await SupabaseService.client
                .from('admin_accounts')
                .select('id, username, full_name')
                .order('full_name');

            accounts = List<Map<String, dynamic>>.from(response);
            print(
              'Successfully loaded ${accounts.length} admin accounts via minimal query',
            );
          } catch (minimalError) {
            print('Minimal query failed: $minimalError');

            // Approach 4: Try with RPC function as last resort
            try {
              print('Trying RPC function as last resort...');
              final rpcResponse = await SupabaseService.client.rpc(
                'get_admin_accounts_with_scanners',
              );
              if (rpcResponse != null && rpcResponse is List) {
                accounts = List<Map<String, dynamic>>.from(rpcResponse);
                print(
                  'Successfully loaded ${accounts.length} admin accounts via RPC',
                );
              } else if (rpcResponse != null &&
                  rpcResponse is Map &&
                  rpcResponse['success'] == true) {
                accounts = List<Map<String, dynamic>>.from(rpcResponse['data']);
                print(
                  'Successfully loaded ${accounts.length} admin accounts via RPC with wrapper',
                );
              } else {
                throw Exception('RPC function returned unexpected format');
              }
            } catch (rpcError) {
              print('RPC approach failed: $rpcError');
              throw minimalError; // Throw the original error
            }
          }
        }
      }

      setState(() {
        _adminAccounts = accounts;
      });

      if (_adminAccounts.isEmpty) {
        print('WARNING: No admin accounts found. This might be due to:');
        print('1. RLS policies blocking access to admin_accounts table');
        print('2. No admin accounts exist in the database');
        print('3. Insufficient permissions for authenticated user');
        print('4. Table structure issues');
      } else {
        print('SUCCESS: Loaded ${_adminAccounts.length} admin accounts');
        // Print first account for debugging
        if (_adminAccounts.isNotEmpty) {
          print('Sample account: ${_adminAccounts.first}');
        }
      }
    } catch (e) {
      print('All admin loading approaches failed: $e');
      print('Error type: ${e.runtimeType}');

      // Check if it's an RLS-related error
      if (e.toString().contains('RLS') ||
          e.toString().contains('permission') ||
          e.toString().contains('policy') ||
          e.toString().contains('403') ||
          e.toString().contains('unauthorized') ||
          e.toString().contains('row-level security')) {
        print(
          'This is definitely an RLS/permission issue. Please run the comprehensive fix_admin_accounts_rls.sql script.',
        );
      }

      setState(() {
        _adminAccounts = [];
      });
    }
  }

  Future<void> _assignScannerToAdmin() async {
    if (_selectedAdminId == null || _selectedAdminScannerId == null) {
      _showErrorDialog('Please select both admin account and scanner');
      return;
    }

    // Check if scanner is already assigned
    bool isAlreadyAssignedToService = _services.any(
      (service) => service['scanner_id'] == _selectedAdminScannerId,
    );
    bool isAlreadyAssignedToAdmin = _adminAccounts.any(
      (admin) => admin['scanner_id'] == _selectedAdminScannerId,
    );

    if (isAlreadyAssignedToService || isAlreadyAssignedToAdmin) {
      _showErrorDialog('This scanner is already assigned to another account');
      return;
    }

    try {
      // Try RPC function first
      try {
        final response = await SupabaseService.client.rpc(
          'assign_scanner_to_admin',
          params: {
            'p_admin_id': int.parse(_selectedAdminId!),
            'p_scanner_id': _selectedAdminScannerId!,
          },
        );

        if (response['success']) {
          _showSuccessDialog('Scanner assigned to admin successfully');
          await _loadAdminScannerData();
          setState(() {
            _selectedAdminId = null;
            _selectedAdminScannerId = null;
          });
          return;
        } else {
          throw Exception(response['message'] ?? 'RPC function failed');
        }
      } catch (rpcError) {
        print('RPC assignment failed, using fallback: $rpcError');
        // Fallback: direct table update
        await _assignScannerFallback();
      }
    } catch (e) {
      _showErrorDialog('Error assigning scanner: $e');
    }
  }

  // Fallback method for scanner assignment
  Future<void> _assignScannerFallback() async {
    try {
      // Direct table update
      await SupabaseService.client
          .from('admin_accounts')
          .update({
            'scanner_id': _selectedAdminScannerId!,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', int.parse(_selectedAdminId!));

      _showSuccessDialog('Scanner assigned to admin successfully');
      await _loadAdminScannerData();
      setState(() {
        _selectedAdminId = null;
        _selectedAdminScannerId = null;
      });
    } catch (e) {
      _showErrorDialog('Error assigning scanner: $e');
    }
  }

  Future<void> _unassignScannerFromAdmin(int adminId) async {
    try {
      // Try RPC function first
      try {
        final response = await SupabaseService.client.rpc(
          'unassign_scanner_from_admin',
          params: {'p_admin_id': adminId},
        );

        if (response['success']) {
          _showSuccessDialog('Scanner unassigned from admin successfully');
          await _loadAdminScannerData();
          return;
        } else {
          throw Exception(response['message'] ?? 'RPC function failed');
        }
      } catch (rpcError) {
        print('RPC unassignment failed, using fallback: $rpcError');
        // Fallback: direct table update
        await _unassignScannerFallback(adminId);
      }
    } catch (e) {
      _showErrorDialog('Error unassigning scanner: $e');
    }
  }

  // Fallback method for scanner unassignment
  Future<void> _unassignScannerFallback(int adminId) async {
    try {
      // Direct table update
      await SupabaseService.client
          .from('admin_accounts')
          .update({
            'scanner_id': null,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', adminId);

      _showSuccessDialog('Scanner unassigned from admin successfully');
      await _loadAdminScannerData();
    } catch (e) {
      _showErrorDialog('Error unassigning scanner: $e');
    }
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
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: color.withOpacity(0.8)),
          ),
        ],
      ),
    );
  }
}
