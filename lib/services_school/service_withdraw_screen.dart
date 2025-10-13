import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/supabase_service.dart';
import '../services/session_service.dart';

class ServiceWithdrawScreen extends StatefulWidget {
  const ServiceWithdrawScreen({Key? key}) : super(key: key);

  @override
  State<ServiceWithdrawScreen> createState() => _ServiceWithdrawScreenState();
}

class _ServiceWithdrawScreenState extends State<ServiceWithdrawScreen> {
  final TextEditingController _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isProcessing = false;
  double _currentBalance = 0.0;

  static const Color evsuRed = Color(0xFFB91C1C);
  static const Color evsuRedDark = Color(0xFF7F1D1D);

  @override
  void initState() {
    super.initState();
    _loadCurrentBalance();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentBalance() async {
    final balance = SessionService.currentUserData?['balance'];
    if (balance != null) {
      setState(() {
        _currentBalance = (balance as num).toDouble();
      });
    }
  }

  Future<void> _processWithdrawal() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final serviceIdStr =
          SessionService.currentUserData?['service_id']?.toString();

      if (serviceIdStr == null || serviceIdStr.isEmpty) {
        throw Exception('Service account ID not found in session');
      }

      final serviceId = int.tryParse(serviceIdStr);
      if (serviceId == null) {
        throw Exception('Invalid service account ID');
      }

      final amount = double.parse(_amountController.text);

      final result = await SupabaseService.processServiceWithdrawal(
        serviceAccountId: serviceId,
        amount: amount,
      );

      setState(() {
        _isProcessing = false;
      });

      if (result['success'] == true) {
        // Update session balance
        await SessionService.refreshUserData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Withdrawal successful'),
              backgroundColor: Colors.green,
            ),
          );

          // Return true to indicate successful withdrawal
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Withdrawal failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWeb = screenWidth > 600;
    final horizontalPadding = isWeb ? 32.0 : 16.0;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Withdraw to Admin',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: evsuRed,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(horizontalPadding),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

              // Current Balance Card
              _buildBalanceCard(),

              const SizedBox(height: 24),

              // Destination Info Card
              _buildDestinationInfoCard(),

              const SizedBox(height: 24),

              // Amount Input
              _buildAmountInput(),

              const SizedBox(height: 24),

              // Information Card
              _buildInformationCard(),

              const SizedBox(height: 32),

              // Submit Button
              _buildSubmitButton(),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [evsuRed, evsuRedDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: evsuRed.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Available Balance',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '₱${_currentBalance.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDestinationInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: evsuRed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.admin_panel_settings,
              color: evsuRed,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Withdraw to Admin',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Cash out your service balance',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Withdrawal Amount',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
          ],
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.attach_money, color: evsuRed),
            hintText: '0.00',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: evsuRed, width: 2),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter an amount';
            }
            final amount = double.tryParse(value);
            if (amount == null || amount <= 0) {
              return 'Please enter a valid amount';
            }
            if (amount > _currentBalance) {
              return 'Insufficient balance';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildInformationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Important Information',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[900],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '• Service accounts can only withdraw to Admin.\n'
                  '• The withdrawn amount will be deducted from your service balance.\n'
                  '• Admin balance will NOT increase (cash out).\n'
                  '• Please visit the Admin office to collect your withdrawal.\n'
                  '• This transaction cannot be reversed.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue[900],
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _isProcessing ? null : _processWithdrawal,
      style: ElevatedButton.styleFrom(
        backgroundColor: evsuRed,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
      ),
      child:
          _isProcessing
              ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
              : const Text(
                'Process Withdrawal',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
    );
  }
}
