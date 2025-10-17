import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/supabase_service.dart';

class ApiConfigurationScreen extends StatefulWidget {
  const ApiConfigurationScreen({super.key});

  @override
  State<ApiConfigurationScreen> createState() => _ApiConfigurationScreenState();
}

class _ApiConfigurationScreenState extends State<ApiConfigurationScreen>
    with SingleTickerProviderStateMixin {
  static const Color evsuRed = Color(0xFFB91C1C);

  // Paytaca controllers
  final TextEditingController _xpubKeyController = TextEditingController();
  final TextEditingController _walletHashController = TextEditingController();
  final TextEditingController _webhookUrlController = TextEditingController();

  // PayMongo controllers
  final TextEditingController _pmPublicKeyController = TextEditingController();
  final TextEditingController _pmSecretKeyController = TextEditingController();
  final TextEditingController _pmWebhookSecretController =
      TextEditingController();

  // State variables
  bool _paytacaEnabled = false;
  bool _showXpubKey = false;
  bool _showWalletHash = false;
  bool _isLoading = false;
  String _connectionStatus = 'Not Connected';

  // PayMongo state
  bool _paymongoEnabled = false;
  bool _showPmPublic = false;
  bool _showPmSecret = false;
  bool _showPmWebhook = false;
  String _paymongoProvider = 'gcash'; // gcash | maya | grabpay (extendable)

  // UI: Tabs
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSavedConfiguration();
  }

  @override
  void dispose() {
    _xpubKeyController.dispose();
    _walletHashController.dispose();
    _webhookUrlController.dispose();
    _pmPublicKeyController.dispose();
    _pmSecretKeyController.dispose();
    _pmWebhookSecretController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedConfiguration() async {
    setState(() => _isLoading = true);
    try {
      final response = await SupabaseService.getApiConfiguration();
      if (response['success'] == true) {
        final data = response['data'];
        setState(() {
          _paytacaEnabled = data['enabled'] ?? false;
          _xpubKeyController.text = data['xpub_key'] ?? '';
          _walletHashController.text = data['wallet_hash'] ?? '';
          _webhookUrlController.text = data['webhook_url'] ?? '';
          _connectionStatus = _paytacaEnabled ? 'Connected' : 'Disabled';

          // PayMongo
          _paymongoEnabled = data['paymongo_enabled'] ?? false;
          _pmPublicKeyController.text = data['paymongo_public_key'] ?? '';
          _pmSecretKeyController.text = data['paymongo_secret_key'] ?? '';
          _pmWebhookSecretController.text =
              data['paymongo_webhook_secret'] ?? '';
          _paymongoProvider = data['paymongo_provider'] ?? 'gcash';
        });
      }
    } catch (e) {
      print("Error loading configuration: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'API Configuration',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: evsuRed,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [Tab(text: 'Paytaca'), Tab(text: 'PayMongo')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Paytaca Tab
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusCard(),
                const SizedBox(height: 24),
                _buildConfigurationSection(),
                const SizedBox(height: 24),
                _buildApiKeysSection(),
                const SizedBox(height: 24),
                _buildWebhookSection(),
                const SizedBox(height: 32),
                _buildActionButtons(),
                const SizedBox(height: 24),
                _buildTestSection(),
              ],
            ),
          ),
          // PayMongo Tab
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPaymongoStatusCard(),
                const SizedBox(height: 24),
                _buildPaymongoConfigSection(),
                const SizedBox(height: 24),
                _buildPaymongoKeysSection(),
                const SizedBox(height: 24),
                _buildPaymongoWebhookSection(),
                const SizedBox(height: 32),
                _buildPaymongoActionButtons(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [evsuRed, evsuRed.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: evsuRed.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
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
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.currency_bitcoin,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Paytaca Integration',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatusIndicator(
                  'Status',
                  _connectionStatus,
                  _getStatusColor(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatusIndicator(
                  'Service',
                  'Bitcoin Lightning',
                  Colors.blue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(String label, String status, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  status,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConfigurationSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Paytaca Configuration',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.power_settings_new, color: evsuRed, size: 24),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Enable Paytaca',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        'Activate Bitcoin Lightning payment gateway',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _paytacaEnabled,
                  onChanged: (value) async {
                    setState(() => _paytacaEnabled = value);
                    await _saveEnabledState(); // Save only the enabled state
                    _validateConfiguration(); // Update status display
                  },
                  activeColor: evsuRed,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildApiKeysSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paytaca Configuration',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Enter your Paytaca wallet configuration details',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),

            // XPub Key Field
            const Text(
              'Extended Public Key (xpub)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _xpubKeyController,
              obscureText: !_showXpubKey,
              decoration: InputDecoration(
                hintText: 'xpub6...',
                prefixIcon: Icon(Icons.vpn_key, color: evsuRed),
                suffixIcon: IconButton(
                  icon: Icon(
                    _showXpubKey ? Icons.visibility : Icons.visibility_off,
                    color: Colors.grey,
                  ),
                  onPressed: () => setState(() => _showXpubKey = !_showXpubKey),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: evsuRed, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (value) => _validateConfiguration(),
            ),

            const SizedBox(height: 20),

            // Wallet Hash Field
            const Text(
              'Wallet Hash',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _walletHashController,
              obscureText: !_showWalletHash,
              decoration: InputDecoration(
                hintText: 'wallet_hash_...',
                prefixIcon: Icon(Icons.fingerprint, color: evsuRed),
                suffixIcon: IconButton(
                  icon: Icon(
                    _showWalletHash ? Icons.visibility : Icons.visibility_off,
                    color: Colors.grey,
                  ),
                  onPressed:
                      () => setState(() => _showWalletHash = !_showWalletHash),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: evsuRed, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (value) => _validateConfiguration(),
            ),

            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Get your xpub key and wallet hash from your Paytaca wallet settings.',
                      style: TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebhookSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Webhook Configuration',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Webhook URL for Paytaca payment notifications',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),

            const Text(
              'Webhook URL',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _webhookUrlController,
              decoration: InputDecoration(
                hintText: 'https://your-domain.com/paytaca-webhook',
                prefixIcon: Icon(Icons.webhook, color: evsuRed),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.copy, color: Colors.grey),
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: _webhookUrlController.text),
                    );
                    _showToast('Webhook URL copied to clipboard');
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: evsuRed, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (value) => _validateConfiguration(),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Configure this webhook URL in your Paytaca wallet to receive payment notifications.',
                      style: TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // PayMongo UI
  Widget _buildPaymongoStatusCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [evsuRed, evsuRed.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: evsuRed.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
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
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.payment, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                'PayMongo Integration',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatusIndicator(
                  'Status',
                  _paymongoEnabled ? 'Enabled' : 'Disabled',
                  _paymongoEnabled ? Colors.green : Colors.grey,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatusIndicator(
                  'Provider',
                  _paymongoProvider.toUpperCase(),
                  Colors.blue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymongoConfigSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'PayMongo Configuration',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.power_settings_new, color: evsuRed, size: 24),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Enable PayMongo',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        'Activate PayMongo payment gateway',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _paymongoEnabled,
                  onChanged:
                      (value) => setState(() => _paymongoEnabled = value),
                  activeColor: evsuRed,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Payment Provider',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _paymongoProvider,
                  items: const [
                    DropdownMenuItem(value: 'gcash', child: Text('GCash')),
                    DropdownMenuItem(value: 'maya', child: Text('Maya')),
                    DropdownMenuItem(value: 'grabpay', child: Text('GrabPay')),
                  ],
                  onChanged: (value) {
                    if (value != null)
                      setState(() => _paymongoProvider = value);
                  },
                  decoration: InputDecoration(
                    prefixIcon: Icon(
                      Icons.account_balance_wallet,
                      color: evsuRed,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: evsuRed, width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymongoKeysSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'PayMongo API Keys',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Public Key',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _pmPublicKeyController,
              obscureText: !_showPmPublic,
              decoration: InputDecoration(
                hintText: 'pk_test_...',
                prefixIcon: Icon(Icons.vpn_key, color: evsuRed),
                suffixIcon: IconButton(
                  icon: Icon(
                    _showPmPublic ? Icons.visibility : Icons.visibility_off,
                    color: Colors.grey,
                  ),
                  onPressed:
                      () => setState(() => _showPmPublic = !_showPmPublic),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: evsuRed, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Secret Key',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _pmSecretKeyController,
              obscureText: !_showPmSecret,
              decoration: InputDecoration(
                hintText: 'sk_test_...',
                prefixIcon: Icon(Icons.lock, color: evsuRed),
                suffixIcon: IconButton(
                  icon: Icon(
                    _showPmSecret ? Icons.visibility : Icons.visibility_off,
                    color: Colors.grey,
                  ),
                  onPressed:
                      () => setState(() => _showPmSecret = !_showPmSecret),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: evsuRed, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Webhook Secret',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _pmWebhookSecretController,
              obscureText: !_showPmWebhook,
              decoration: InputDecoration(
                hintText: 'whsec_...',
                prefixIcon: Icon(Icons.webhook, color: evsuRed),
                suffixIcon: IconButton(
                  icon: Icon(
                    _showPmWebhook ? Icons.visibility : Icons.visibility_off,
                    color: Colors.grey,
                  ),
                  onPressed:
                      () => setState(() => _showPmWebhook = !_showPmWebhook),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: evsuRed, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymongoWebhookSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Webhook Notes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Configure the webhook endpoint and use the provided secret to verify signatures.',
                      style: TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymongoActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed:
                _isLoading
                    ? null
                    : () async {
                      setState(() => _isLoading = true);
                      try {
                        final result =
                            await SupabaseService.savePaymongoConfiguration(
                              enabled: _paymongoEnabled,
                              publicKey: _pmPublicKeyController.text.trim(),
                              secretKey: _pmSecretKeyController.text.trim(),
                              webhookSecret:
                                  _pmWebhookSecretController.text.trim(),
                              provider: _paymongoProvider,
                            );
                        if (result['success'] == true) {
                          _showToast(
                            'PayMongo configuration saved successfully',
                          );
                        } else {
                          _showToast(
                            'Error saving PayMongo: ${result['message']}',
                          );
                        }
                      } catch (e) {
                        _showToast('Error saving PayMongo configuration: $e');
                      } finally {
                        setState(() => _isLoading = false);
                      }
                    },
            icon:
                _isLoading
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.save),
            label: Text(
              _isLoading ? 'Saving...' : 'Save PayMongo Configuration',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: evsuRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: OutlinedButton.icon(
            onPressed:
                _isLoading
                    ? null
                    : () {
                      setState(() {
                        _paymongoEnabled = false;
                        _pmPublicKeyController.clear();
                        _pmSecretKeyController.clear();
                        _pmWebhookSecretController.clear();
                        _paymongoProvider = 'gcash';
                      });
                    },
            icon: const Icon(Icons.refresh),
            label: const Text('Reset'),
            style: OutlinedButton.styleFrom(
              foregroundColor: evsuRed,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _saveConfiguration,
            icon:
                _isLoading
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.save),
            label: Text(_isLoading ? 'Saving...' : 'Save Configuration'),
            style: ElevatedButton.styleFrom(
              backgroundColor: evsuRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isLoading ? null : _resetConfiguration,
            icon: const Icon(Icons.refresh),
            label: const Text('Reset'),
            style: OutlinedButton.styleFrom(
              foregroundColor: evsuRed,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTestSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Configuration Status',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Current Paytaca configuration status',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    _paytacaEnabled
                        ? Colors.green.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color:
                      _paytacaEnabled
                          ? Colors.green.withOpacity(0.3)
                          : Colors.orange.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _paytacaEnabled ? Icons.check_circle : Icons.warning,
                    color: _paytacaEnabled ? Colors.green : Colors.orange,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _connectionStatus,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _getStatusColor(),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getStatusDescription(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _validateConfiguration() {
    String xpubKey = _xpubKeyController.text.trim();
    String walletHash = _walletHashController.text.trim();
    String webhookUrl = _webhookUrlController.text.trim();

    bool isValid =
        xpubKey.isNotEmpty && walletHash.isNotEmpty && webhookUrl.isNotEmpty;

    String status;
    if (_paytacaEnabled) {
      if (isValid) {
        status = 'Configured';
      } else {
        status = 'Enabled (Incomplete)';
      }
    } else {
      status = 'Disabled';
    }

    setState(() {
      _connectionStatus = status;
    });
  }

  Color _getStatusColor() {
    if (_connectionStatus == 'Configured') {
      return Colors.green;
    } else if (_connectionStatus == 'Enabled (Incomplete)') {
      return Colors.orange;
    } else if (_connectionStatus == 'Disabled') {
      return Colors.grey;
    } else {
      return Colors.orange;
    }
  }

  String _getStatusDescription() {
    if (_connectionStatus == 'Configured') {
      return 'Top-up functionality is available to users';
    } else if (_connectionStatus == 'Enabled (Incomplete)') {
      return 'Paytaca is enabled but configuration is incomplete. Fill all fields and save.';
    } else if (_connectionStatus == 'Disabled') {
      return 'Top-up functionality is disabled for users';
    } else {
      return 'Configuration status unknown';
    }
  }

  Future<void> _saveEnabledState() async {
    try {
      final response = await SupabaseService.saveApiConfiguration(
        enabled: _paytacaEnabled,
        xpubKey: _xpubKeyController.text.trim(),
        walletHash: _walletHashController.text.trim(),
        webhookUrl: _webhookUrlController.text.trim(),
      );

      if (response['success'] == true) {
        print("DEBUG: Paytaca enabled state saved: $_paytacaEnabled");
      } else {
        print("DEBUG: Error saving enabled state: ${response['message']}");
        _showToast('Error saving enabled state: ${response['message']}');
      }
    } catch (e) {
      print("DEBUG: Error saving enabled state: $e");
      _showToast('Error saving enabled state: $e');
    }
  }

  Future<void> _saveConfiguration() async {
    setState(() => _isLoading = true);

    try {
      final response = await SupabaseService.saveApiConfiguration(
        enabled: _paytacaEnabled,
        xpubKey: _xpubKeyController.text.trim(),
        walletHash: _walletHashController.text.trim(),
        webhookUrl: _webhookUrlController.text.trim(),
      );

      if (response['success'] == true) {
        _showToast('Configuration saved successfully');
        setState(() {
          _connectionStatus = _paytacaEnabled ? 'Connected' : 'Disabled';
        });
      } else {
        _showToast('Error saving configuration: ${response['message']}');
      }
    } catch (e) {
      _showToast('Error saving configuration: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _resetConfiguration() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Reset Configuration'),
            content: const Text(
              'This will reset all Paytaca settings to default. Are you sure?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  setState(() => _isLoading = true);

                  try {
                    await SupabaseService.saveApiConfiguration(
                      enabled: false,
                      xpubKey: '',
                      walletHash: '',
                      webhookUrl: '',
                    );

                    setState(() {
                      _xpubKeyController.clear();
                      _walletHashController.clear();
                      _webhookUrlController.clear();
                      _paytacaEnabled = false;
                      _connectionStatus = 'Not Connected';
                    });
                    _showToast('Configuration reset successfully');
                  } catch (e) {
                    _showToast('Error resetting configuration: $e');
                  } finally {
                    setState(() => _isLoading = false);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: evsuRed),
                child: const Text(
                  'Reset',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: evsuRed,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
