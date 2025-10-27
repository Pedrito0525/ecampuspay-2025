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
                      title: 'API Configuration',
                      description: 'Configure external API integrations',
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
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Success'),
              ],
            ),
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

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error, color: Colors.red),
                SizedBox(width: 8),
                Text('Error'),
              ],
            ),
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
}
