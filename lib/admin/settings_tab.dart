import 'package:flutter/material.dart';
import 'system_update_screen.dart';
import 'api_configuration_screen.dart';
import '../services/supabase_service.dart';

class SettingsTab extends StatefulWidget {
  final int? initialFunction;

  const SettingsTab({super.key, this.initialFunction});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  static const Color evsuRed = Color(0xFFB91C1C);

  // General Settings state
  int _selectedFunction = -1;
  bool _isUpdating = false;

  // Reset Database state
  bool _isResetting = false;
  final TextEditingController _confirmPasswordController2 =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    // Set initial function if provided
    if (widget.initialFunction != null) {
      _selectedFunction = widget.initialFunction!;
    }
  }

  // Form controllers for General Settings
  final TextEditingController _currentUsernameController =
      TextEditingController();
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newUsernameController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _newFullNameController = TextEditingController();
  final TextEditingController _newEmailController = TextEditingController();

  @override
  void dispose() {
    _currentUsernameController.dispose();
    _currentPasswordController.dispose();
    _newUsernameController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _newFullNameController.dispose();
    _newEmailController.dispose();
    _confirmPasswordController2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text(
            'System Settings',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Configure system parameters and preferences',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 30),

          // Show function detail if selected, otherwise show cards
          if (_selectedFunction == 0)
            _buildGeneralSettings()
          else if (_selectedFunction == 1)
            _buildResetDatabase()
          else
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
                      icon: Icons.settings,
                      title: 'General Settings',
                      description: 'Configure system preferences',
                      color: evsuRed,
                      onTap: () => setState(() => _selectedFunction = 0),
                    ),
                    _buildFunctionCard(
                      icon: Icons.notifications,
                      title: 'Notification Settings',
                      description: 'Configure system notifications',
                      color: Colors.blue,
                      onTap: () {
                        // Handle notification settings
                      },
                    ),
                    _buildFunctionCard(
                      icon: Icons.backup,
                      title: 'Backup & Recovery',
                      description: 'Configure data backup and recovery',
                      color: Colors.purple,
                      onTap: () {
                        // Handle backup settings
                      },
                    ),
                    _buildFunctionCard(
                      icon: Icons.update,
                      title: 'System Updates',
                      description: 'Manage system updates and maintenance',
                      color: Colors.orange,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SystemUpdateScreen(),
                          ),
                        );
                      },
                    ),
                    _buildFunctionCard(
                      icon: Icons.integration_instructions,
                      title: 'E-Wallet Payment QR',
                      description: 'Configure QR Payment Options ',
                      color: Colors.teal,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => const ApiConfigurationScreen(),
                          ),
                        );
                      },
                    ),
                    _buildFunctionCard(
                      icon: Icons.delete_forever,
                      title: 'Reset Database',
                      description: 'Permanently delete all data and reset IDs',
                      color: Colors.red.shade900,
                      onTap: () => setState(() => _selectedFunction = 1),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildGeneralSettings() {
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
        border: Border.all(color: Colors.grey.shade200),
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
              const SizedBox(width: 8),
              const Text(
                'General Settings',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Update admin account credentials and information',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 30),

          // Admin Credentials Form
          _buildAdminCredentialsForm(),
        ],
      ),
    );
  }

  Widget _buildAdminCredentialsForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Update Admin Credentials',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 20),

        // Current Credentials Section
        const Text(
          'Current Credentials',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),

        // Current Username
        TextFormField(
          controller: _currentUsernameController,
          decoration: InputDecoration(
            labelText: 'Current Username',
            prefixIcon: const Icon(Icons.person, color: evsuRed),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: evsuRed, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Current Password
        TextFormField(
          controller: _currentPasswordController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Current Password',
            prefixIcon: const Icon(Icons.lock, color: evsuRed),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: evsuRed, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // New Credentials Section
        const Text(
          'New Credentials',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),

        // New Username
        TextFormField(
          controller: _newUsernameController,
          decoration: InputDecoration(
            labelText: 'New Username',
            prefixIcon: const Icon(Icons.person_outline, color: evsuRed),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: evsuRed, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // New Full Name
        TextFormField(
          controller: _newFullNameController,
          decoration: InputDecoration(
            labelText: 'Full Name',
            prefixIcon: const Icon(Icons.badge, color: evsuRed),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: evsuRed, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // New Email
        TextFormField(
          controller: _newEmailController,
          decoration: InputDecoration(
            labelText: 'Email Address',
            prefixIcon: const Icon(Icons.email, color: evsuRed),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: evsuRed, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // New Password
        TextFormField(
          controller: _newPasswordController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'New Password',
            prefixIcon: const Icon(Icons.lock_outline, color: evsuRed),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: evsuRed, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Confirm Password
        TextFormField(
          controller: _confirmPasswordController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Confirm New Password',
            prefixIcon: const Icon(Icons.lock_outline, color: evsuRed),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: evsuRed, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 30),

        // Update Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isUpdating ? null : _updateAdminCredentials,
            style: ElevatedButton.styleFrom(
              backgroundColor: evsuRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child:
                _isUpdating
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                    : const Text(
                      'Update Credentials',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
          ),
        ),
      ],
    );
  }

  Future<void> _updateAdminCredentials() async {
    // Validate form
    if (!_validateForm()) return;

    setState(() {
      _isUpdating = true;
    });

    try {
      final result = await SupabaseService.updateAdminCredentials(
        currentUsername: _currentUsernameController.text.trim(),
        currentPassword: _currentPasswordController.text.trim(),
        newUsername: _newUsernameController.text.trim(),
        newPassword: _newPasswordController.text.trim(),
        newFullName: _newFullNameController.text.trim(),
        newEmail: _newEmailController.text.trim(),
      );

      if (result['success']) {
        _showSuccessDialog('Admin credentials updated successfully!');
        _clearForm();
      } else {
        _showErrorDialog(result['message'] ?? 'Failed to update credentials');
      }
    } catch (e) {
      _showErrorDialog('Error updating credentials: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  bool _validateForm() {
    if (_currentUsernameController.text.trim().isEmpty) {
      _showErrorDialog('Please enter current username');
      return false;
    }
    if (_currentPasswordController.text.trim().isEmpty) {
      _showErrorDialog('Please enter current password');
      return false;
    }
    if (_newUsernameController.text.trim().isEmpty) {
      _showErrorDialog('Please enter new username');
      return false;
    }
    if (_newFullNameController.text.trim().isEmpty) {
      _showErrorDialog('Please enter full name');
      return false;
    }
    if (_newEmailController.text.trim().isEmpty) {
      _showErrorDialog('Please enter email address');
      return false;
    }
    if (_newPasswordController.text.trim().isEmpty) {
      _showErrorDialog('Please enter new password');
      return false;
    }
    if (_newPasswordController.text.trim() !=
        _confirmPasswordController.text.trim()) {
      _showErrorDialog('Passwords do not match');
      return false;
    }
    if (_newPasswordController.text.trim().length < 6) {
      _showErrorDialog('Password must be at least 6 characters long');
      return false;
    }
    return true;
  }

  void _clearForm() {
    _currentUsernameController.clear();
    _currentPasswordController.clear();
    _newUsernameController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
    _newFullNameController.clear();
    _newEmailController.clear();
  }

  void _showSuccessDialog(String message) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: isMobile ? 24 : 28,
                ),
                SizedBox(width: isMobile ? 6 : 8),
                Expanded(
                  child: Text(
                    'Success',
                    style: TextStyle(fontSize: isMobile ? 18 : 20),
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth:
                    isMobile ? MediaQuery.of(context).size.width * 0.8 : 400,
              ),
              child: Text(
                message,
                style: TextStyle(fontSize: isMobile ? 14 : 16),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'OK',
                  style: TextStyle(fontSize: isMobile ? 14 : 16),
                ),
              ),
            ],
          ),
    );
  }

  void _showErrorDialog(String message) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.error, color: Colors.red, size: isMobile ? 24 : 28),
                SizedBox(width: isMobile ? 6 : 8),
                Expanded(
                  child: Text(
                    'Error',
                    style: TextStyle(fontSize: isMobile ? 18 : 20),
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth:
                    isMobile ? MediaQuery.of(context).size.width * 0.8 : 400,
              ),
              child: SingleChildScrollView(
                child: Text(
                  message,
                  style: TextStyle(fontSize: isMobile ? 14 : 16),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'OK',
                  style: TextStyle(fontSize: isMobile ? 14 : 16),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildFunctionCard({
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

  // Reset Database Screen
  Widget _buildResetDatabase() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : (isTablet ? 20 : 24)),
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
          // Header with back button
          Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _selectedFunction = -1),
                icon: const Icon(Icons.arrow_back, color: evsuRed),
                iconSize: isMobile ? 20 : 24,
              ),
              SizedBox(width: isMobile ? 4 : 8),
              Icon(Icons.warning, color: Colors.red, size: isMobile ? 24 : 28),
              SizedBox(width: isMobile ? 4 : 8),
              Expanded(
                child: Text(
                  'Reset Database',
                  style: TextStyle(
                    fontSize: isMobile ? 20 : (isTablet ? 22 : 24),
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 4 : 8),
          Text(
            'DANGER ZONE: This action is irreversible',
            style: TextStyle(
              fontSize: isMobile ? 12 : 14,
              color: Colors.red,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: isMobile ? 20 : 30),

          // Warning Banner
          Container(
            padding: EdgeInsets.all(isMobile ? 16 : 20),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.red.shade300,
                width: isMobile ? 1 : 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.red.shade700,
                      size: isMobile ? 24 : 28,
                    ),
                    SizedBox(width: isMobile ? 8 : 12),
                    Expanded(
                      child: Text(
                        'WARNING: Critical Operation',
                        style: TextStyle(
                          fontSize: isMobile ? 16 : (isTablet ? 17 : 18),
                          fontWeight: FontWeight.w700,
                          color: Colors.red.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isMobile ? 12 : 16),
                Text(
                  'This action will permanently delete ALL data from the following tables:',
                  style: TextStyle(
                    fontSize: isMobile ? 13 : 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade900,
                  ),
                ),
                SizedBox(height: isMobile ? 8 : 12),
                _buildTableList(isMobile, isTablet),
                SizedBox(height: isMobile ? 12 : 16),
                Text(
                  'All auto-increment IDs will be reset to 1.',
                  style: TextStyle(
                    fontSize: isMobile ? 13 : 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade900,
                  ),
                ),
                SizedBox(height: isMobile ? 6 : 8),
                Text(
                  'This operation CANNOT be undone. Consider backing up your data before proceeding.',
                  style: TextStyle(
                    fontSize: isMobile ? 13 : 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade900,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: isMobile ? 20 : 30),

          // Backup Reminder
          Container(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.backup,
                  color: Colors.amber.shade700,
                  size: isMobile ? 20 : 24,
                ),
                SizedBox(width: isMobile ? 8 : 12),
                Expanded(
                  child: Text(
                    'RECOMMENDATION: Export and backup all data before proceeding with this operation.',
                    style: TextStyle(
                      fontSize: isMobile ? 13 : 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: isMobile ? 20 : 30),

          // Reset Database Button
          SizedBox(
            width: double.infinity,
            height: isMobile ? 45 : (isTablet ? 48 : 50),
            child: ElevatedButton(
              onPressed: _isResetting ? null : _showResetConfirmationDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child:
                  _isResetting
                      ? SizedBox(
                        width: isMobile ? 18 : 20,
                        height: isMobile ? 18 : 20,
                        child: const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                      : Text(
                        'Reset Database',
                        style: TextStyle(
                          fontSize: isMobile ? 14 : (isTablet ? 15 : 16),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableList(bool isMobile, bool isTablet) {
    final tables = [
      'loan_payments',
      'service_transactions',
      'top_up_transactions',
      'user_transfers',
      'withdrawal_transactions',
      'payment_items',
      'active_loans',
      'auth_students',
      'service_accounts',
      // Note: service_hierarchy is a VIEW (not a table) - will be empty after deleting service_accounts
      'top_up_requests',
      // Note: top_up_transaction_summary is a VIEW (not a table) - will be empty after deleting top_up_transactions
    ];

    return Container(
      padding: EdgeInsets.all(isMobile ? 10 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:
            tables
                .map(
                  (table) => Padding(
                    padding: EdgeInsets.symmetric(vertical: isMobile ? 3 : 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.table_chart,
                          size: isMobile ? 14 : 16,
                          color: Colors.red.shade700,
                        ),
                        SizedBox(width: isMobile ? 6 : 8),
                        Expanded(
                          child: Text(
                            table,
                            style: TextStyle(
                              fontSize: isMobile ? 12 : 13,
                              fontFamily: 'monospace',
                              color: Colors.red.shade900,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
      ),
    );
  }

  Future<void> _showResetConfirmationDialog() async {
    _confirmPasswordController2.clear();
    int cooldownSeconds = 5;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Start countdown timer if not already started
            if (cooldownSeconds == 5) {
              _startCooldownTimerForDialog(setDialogState, (newValue) {
                cooldownSeconds = newValue;
              }, cooldownSeconds);
            }

            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.warning, color: Colors.red.shade700, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Confirm Reset Database',
                      style: TextStyle(
                        fontSize:
                            MediaQuery.of(context).size.width < 600 ? 18 : 20,
                      ),
                    ),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth:
                      MediaQuery.of(context).size.width < 600
                          ? MediaQuery.of(context).size.width * 0.9
                          : 500,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'This will permanently delete ALL data from ALL system tables and reset their IDs. This action CANNOT be undone.',
                        style: TextStyle(
                          fontSize:
                              MediaQuery.of(context).size.width < 600 ? 13 : 14,
                          color: Colors.red.shade900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'For security, please enter your admin password to confirm:',
                        style: TextStyle(
                          fontSize:
                              MediaQuery.of(context).size.width < 600 ? 13 : 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirmPasswordController2,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Admin Password',
                          labelStyle: TextStyle(
                            fontSize:
                                MediaQuery.of(context).size.width < 600
                                    ? 13
                                    : 14,
                          ),
                          prefixIcon: const Icon(Icons.lock, color: evsuRed),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: evsuRed,
                              width: 2,
                            ),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical:
                                MediaQuery.of(context).size.width < 600
                                    ? 12
                                    : 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (cooldownSeconds > 0)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.orange.shade300),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.timer,
                                color: Colors.orange.shade700,
                                size:
                                    MediaQuery.of(context).size.width < 600
                                        ? 20
                                        : 24,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Please wait $cooldownSeconds seconds before confirming...',
                                  style: TextStyle(
                                    fontSize:
                                        MediaQuery.of(context).size.width < 600
                                            ? 12
                                            : 13,
                                    color: Colors.orange.shade900,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize:
                          MediaQuery.of(context).size.width < 600 ? 13 : 14,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed:
                      cooldownSeconds > 0
                          ? null
                          : () {
                            Navigator.of(context).pop();
                            _performDatabaseReset();
                          },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal:
                          MediaQuery.of(context).size.width < 600 ? 16 : 20,
                      vertical:
                          MediaQuery.of(context).size.width < 600 ? 10 : 12,
                    ),
                  ),
                  child: Text(
                    'Confirm Reset',
                    style: TextStyle(
                      fontSize:
                          MediaQuery.of(context).size.width < 600 ? 13 : 14,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _startCooldownTimerForDialog(
    StateSetter setDialogState,
    Function(int) updateCooldown,
    int currentSeconds,
  ) {
    if (currentSeconds > 0) {
      Future.delayed(const Duration(seconds: 1), () {
        final newSeconds = currentSeconds - 1;
        setDialogState(() {
          updateCooldown(newSeconds);
        });

        if (newSeconds > 0) {
          _startCooldownTimerForDialog(
            setDialogState,
            updateCooldown,
            newSeconds,
          );
        }
      });
    }
  }

  Future<void> _performDatabaseReset() async {
    // Validate password
    if (_confirmPasswordController2.text.trim().isEmpty) {
      _showErrorDialog('Please enter your admin password to confirm.');
      return;
    }

    setState(() {
      _isResetting = true;
    });

    try {
      print('=== DEBUG: Reset Database Started ===');
      print(
        'DEBUG: Password entered: ${_confirmPasswordController2.text.trim()}',
      );

      // Get current admin info for authentication
      print('DEBUG: Fetching admin info...');
      final adminData = await SupabaseService.getCurrentAdminInfo();

      print('DEBUG: Admin data response: ${adminData['success']}');
      if (adminData['success']) {
        print(
          'DEBUG: Admin username from DB: ${adminData['data']['username']}',
        );
        print('DEBUG: Admin data keys: ${adminData['data'].keys.toList()}');
      } else {
        print('DEBUG: Failed to get admin data: ${adminData['message']}');
        print('DEBUG: Error: ${adminData['error']}');
      }

      if (!adminData['success']) {
        _showErrorDialog(
          'Failed to verify admin credentials.\nError: ${adminData['message']}',
        );
        return;
      }

      // Call the reset database function with password verification
      print('DEBUG: Calling resetDatabase with:');
      print('  - username: ${adminData['data']['username']}');
      print(
        '  - password length: ${_confirmPasswordController2.text.trim().length}',
      );

      final result = await SupabaseService.resetDatabase(
        adminPassword: _confirmPasswordController2.text.trim(),
        adminUsername: adminData['data']['username'],
      );

      print('DEBUG: Reset result: ${result['success']}');
      print('DEBUG: Reset message: ${result['message']}');
      if (!result['success']) {
        print('DEBUG: Reset error: ${result['error']}');
      }
      print('=== DEBUG: Reset Database Completed ===');

      if (result['success']) {
        _showSuccessDialog(
          'Database has been successfully reset. All data has been deleted and IDs have been reset.',
        );
        _confirmPasswordController2.clear();
      } else {
        _showErrorDialog(
          result['message'] ?? 'Failed to reset database. Please try again.',
        );
      }
    } catch (e) {
      print('DEBUG: Exception caught: $e');
      print('DEBUG: Exception type: ${e.runtimeType}');
      _showErrorDialog('Error resetting database: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isResetting = false;
        });
      }
    }
  }
}
