import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../services/esp32_bluetooth_service_account.dart';
// Using service account BLE service (assigned scanner)
import 'dart:convert';
import '../services/supabase_service.dart';
import '../services/encryption_service.dart';
import '../services/session_service.dart';

class PaymentScreen extends StatefulWidget {
  final Map<String, dynamic> product;
  final String serviceName;
  final bool scannerConnected;
  final String? assignedScannerId;

  const PaymentScreen({
    Key? key,
    required this.product,
    required this.serviceName,
    this.scannerConnected = false,
    this.assignedScannerId,
  }) : super(key: key);

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  String paymentStatus = 'Ready for Payment';
  String paymentIcon = '💳';
  bool isProcessingPayment = false;
  bool paymentCompleted = false;
  Color paymentZoneColor = const Color(0xFF28A745);

  StreamSubscription? _rfidDataSubscription;
  // Map-based stream not used here; using account service string stream
  String? transactionId;
  DateTime? transactionTime;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _rotationAnimation = Tween<double>(begin: 0.0, end: 0.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.repeat(reverse: true);
    _startRealRFIDListening();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _rfidDataSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startRealRFIDListening() async {
    print("DEBUG PaymentScreen: serviceName = ${widget.serviceName}");
    print("DEBUG PaymentScreen: product = ${widget.product}");

    // Ensure connection to assigned scanner (via service account BLE)
    if (!ESP32BluetoothServiceAccount.isConnected) {
      if (widget.assignedScannerId == null ||
          widget.assignedScannerId!.isEmpty) {
        setState(() {
          paymentStatus = 'No scanner assigned to this service';
          paymentIcon = '❌';
          paymentZoneColor = Colors.red;
        });
        return;
      }

      setState(() {
        paymentStatus = 'Connecting to ${widget.assignedScannerId}...';
        paymentIcon = '🔄';
        paymentZoneColor = const Color(0xFFFFC107);
      });

      final bool connected = await _ensureConnected(widget.assignedScannerId!);

      if (!mounted) return;
      if (!connected) {
        setState(() {
          paymentStatus = 'Failed to connect to ${widget.assignedScannerId}';
          paymentIcon = '❌';
          paymentZoneColor = Colors.red;
        });
        return;
      }
    }

    // Start payment scanner for this service
    await _startPaymentScanner();

    // Listen to RFID scan results (string payload via account service)
    _rfidDataSubscription = ESP32BluetoothServiceAccount.rfidDataStream.listen((
      data,
    ) {
      if (!mounted || paymentCompleted) return;
      final String cardId = _extractRfidId(data);
      // ignore: avoid_print
      print('DEBUG PaymentScreen: parsed RFID: ' + cardId);
      if (cardId.isNotEmpty) {
        _handleRFIDTap(cardId);
      }
    });
  }

  Future<bool> _ensureConnected(String assignedScannerId) async {
    // Try for up to ~12 seconds, polling every 1s; avoid overlapping attempts
    const int maxAttempts = 12;
    for (int i = 0; i < maxAttempts; i++) {
      if (ESP32BluetoothServiceAccount.isConnected) return true;
      final bool connecting = ESP32BluetoothServiceAccount.isConnecting;
      if (!connecting) {
        // Fire a connect attempt
        // Ignore the boolean result here; we'll poll isConnected on next tick
        // to avoid treating an in-progress state as failure
        // ignore: unused_local_variable
        final _ = await ESP32BluetoothServiceAccount.connectToAssignedScanner(
          assignedScannerId,
        );
      }
      await Future.delayed(const Duration(seconds: 1));
    }
    return ESP32BluetoothServiceAccount.isConnected;
  }

  Future<void> _startPaymentScanner() async {
    try {
      // Compute amount (supports single or multiple items)
      final bool isMultipleItems = widget.product.containsKey('orderItems');
      final double amount =
          isMultipleItems
              ? (widget.product['totalAmount']?.toDouble() ?? 0.0)
              : (widget.product['price']?.toDouble() ?? 0.0);

      final String itemName =
          isMultipleItems
              ? (widget.product['title'] ?? 'Multiple Items')
              : (widget.product['name'] ?? 'Unknown Item');

      bool scannerStarted =
          await ESP32BluetoothServiceAccount.startPaymentScanner(
            widget.serviceName,
            amount,
            itemName,
          );

      if (scannerStarted) {
        setState(() {
          paymentStatus =
              'Ready - Place your RFID card on ${widget.assignedScannerId}';
          paymentIcon = '📱';
          paymentZoneColor = const Color(0xFF28A745);
        });
      } else {
        // If failed, attempt reconnect-with-retry then retry start once more
        if (!ESP32BluetoothServiceAccount.isConnected) {
          setState(() {
            paymentStatus = 'Reconnecting to ${widget.assignedScannerId}...';
            paymentIcon = '🔄';
            paymentZoneColor = const Color(0xFFFFC107);
          });

          final bool reconnected =
              widget.assignedScannerId != null &&
                      widget.assignedScannerId!.isNotEmpty
                  ? await _ensureConnected(widget.assignedScannerId!)
                  : false;

          if (reconnected) {
            scannerStarted =
                await ESP32BluetoothServiceAccount.startPaymentScanner(
                  widget.serviceName,
                  amount,
                  itemName,
                );
          }
        }

        if (!scannerStarted) {
          setState(() {
            paymentStatus = 'Failed to start scanner';
            paymentIcon = '❌';
            paymentZoneColor = Colors.red;
          });
        }
      }
    } catch (e) {
      setState(() {
        paymentStatus = 'Scanner error: $e';
        paymentIcon = '❌';
        paymentZoneColor = Colors.red;
      });
    }
  }

  void _handleRFIDTap(String cardId) {
    if (isProcessingPayment || paymentCompleted) return;

    HapticFeedback.lightImpact();
    _processPayment(cardId);
  }

  void _processPayment(String cardId) async {
    setState(() {
      isProcessingPayment = true;
      paymentStatus = 'Processing Payment...';
      paymentIcon = '🔄';
      paymentZoneColor = const Color(0xFFFFC107);
    });

    try {
      await SupabaseService.initialize();

      // Lookup student by ENCRYPTED RFID card ID in auth_students
      final enc = EncryptionService.encryptUserData({'rfid_id': cardId});
      final encryptedRfid = enc['rfid_id']?.toString() ?? '';
      final userRes =
          await SupabaseService.client
              .from('auth_students')
              .select('id, student_id, balance')
              .eq('rfid_id', encryptedRfid)
              .maybeSingle();

      if (userRes == null) {
        setState(() {
          isProcessingPayment = false;
          paymentStatus = 'RFID not registered';
          paymentIcon = '❌';
          paymentZoneColor = Colors.red;
        });
        _showDialog(
          'Card not registered',
          'This RFID is not registered yet.',
          onOk: () {
            if (mounted) {
              Navigator.pop(context, false); // Back to cashier
            }
          },
        );
        return;
      }

      final userId = (userRes['id'] as num).toInt();
      final String studentIdStr = userRes['student_id']?.toString() ?? '';
      final userBalance = (userRes['balance'] as num?)?.toDouble() ?? 0.0;

      print(
        'DEBUG: Found student - userId: $userId, studentId: $studentIdStr, balance: $userBalance',
      );

      // Compute amount
      final bool isMultipleItems = widget.product.containsKey('orderItems');
      final double amount =
          isMultipleItems
              ? (widget.product['totalAmount']?.toDouble() ?? 0.0)
              : (widget.product['price']?.toDouble() ?? 0.0);

      if (userBalance < amount) {
        setState(() {
          isProcessingPayment = false;
          paymentStatus = 'Insufficient balance';
          paymentIcon = '⚠️';
          paymentZoneColor = Colors.orange;
        });
        _showDialog(
          'Insufficient Balance',
          'The account does not have enough balance.',
          onOk: () {
            if (mounted) {
              Navigator.pop(context, false); // Back to cashier
            }
          },
        );
        return;
      }

      // Service account info
      final serviceIdStr =
          SessionService.currentUserData?['service_id']?.toString() ?? '0';
      final serviceAccountId = int.tryParse(serviceIdStr) ?? 0;
      final operationalType =
          SessionService.currentUserData?['operational_type']?.toString() ??
          'Main';

      // Prepare items for transaction
      final transactionItems =
          isMultipleItems
              ? widget.product['orderItems']
              : [
                {
                  'name': widget.product['name'],
                  'quantity': 1,
                  'price': widget.product['price'],
                  'total': widget.product['price'],
                },
              ];

      Map<String, dynamic> paymentResult;

      try {
        // Try using the atomic RPC function first
        final rpcResult = await SupabaseService.client.rpc(
          'process_service_payment',
          params: {
            'p_user_id': userId,
            'p_service_account_id': serviceAccountId,
            'p_amount': amount,
            'p_items': transactionItems,
            'p_student_id': studentIdStr, // use real student_id
          },
        );

        print('DEBUG: RPC result: $rpcResult');

        if (rpcResult != null && rpcResult['success'] == true) {
          paymentResult = Map<String, dynamic>.from(rpcResult);
          transactionId = 'TXN${paymentResult['transaction_id']}';
        } else {
          throw Exception(rpcResult?['error'] ?? 'RPC function failed');
        }
      } catch (rpcError) {
        print('DEBUG: RPC failed, using fallback method: $rpcError');

        // Fallback: Manual transaction processing
        paymentResult = await _processPaymentFallback(
          userId,
          serviceAccountId,
          operationalType,
          amount,
          transactionItems,
          studentIdStr, // use real student_id
        );

        if (!paymentResult['success']) {
          throw Exception(paymentResult['error']);
        }
      }
      transactionTime = DateTime.now();

      setState(() {
        paymentCompleted = true;
        isProcessingPayment = false;
        paymentStatus = 'Payment Successful!';
        paymentIcon = '✅';
        paymentZoneColor = const Color(0xFF28A745);
      });

      // Update SessionService with new service account balance if available
      if (paymentResult['new_service_balance'] != null) {
        final newServiceBalance =
            paymentResult['new_service_balance'].toString();
        SessionService.currentUserData?['balance'] = newServiceBalance;
        print('DEBUG: Updated session service balance to: $newServiceBalance');
      }

      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        isProcessingPayment = false;
        paymentStatus = 'Payment failed';
        paymentIcon = '❌';
        paymentZoneColor = Colors.red;
      });
      _showDialog('Payment Failed', 'An error occurred: $e');
    }
  }

  void _showDialog(String title, String message, {VoidCallback? onOk}) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  if (onOk != null) onOk();
                },
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  String _extractRfidId(dynamic payload) {
    try {
      // Normalize to string
      final String raw = payload?.toString().trim() ?? '';
      if (raw.isEmpty) return '';
      // JSON message from ESP32
      if (raw.startsWith('{') && raw.endsWith('}')) {
        final Map<String, dynamic> obj = _tryParseJson(raw);
        if (obj.isNotEmpty) {
          final candidates = [
            obj['rfid'],
            obj['cardId'],
            obj['id'],
            obj['uid'],
            (obj['data'] is Map)
                ? (obj['data']['rfid'] ?? obj['data']['id'])
                : null,
          ];
          for (final c in candidates) {
            if (c != null && c.toString().trim().isNotEmpty) {
              return _sanitizeRfid(c.toString());
            }
          }
        }
      }
      // Plain text UID (e.g., "04 A3 6B 8C 1F")
      return _sanitizeRfid(raw);
    } catch (_) {
      return '';
    }
  }

  Map<String, dynamic> _tryParseJson(String raw) {
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return const {};
    }
  }

  String _sanitizeRfid(String s) {
    // Remove spaces/colons/dashes, uppercase
    final cleaned = s.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '').toUpperCase();
    return cleaned;
  }

  /// Fallback payment processing method (if RPC function is not available)
  Future<Map<String, dynamic>> _processPaymentFallback(
    int userId,
    int serviceAccountId,
    String operationalType,
    double amount,
    List<Map<String, dynamic>> transactionItems,
    String studentId, // Real student_id from auth_students.student_id
  ) async {
    try {
      print('DEBUG: Starting fallback payment processing');
      print(
        'DEBUG: userId=$userId, serviceAccountId=$serviceAccountId, amount=$amount, studentId=$studentId',
      );

      // Get current balances
      final userResponse =
          await SupabaseService.client
              .from('auth_students')
              .select('balance')
              .eq('id', userId)
              .single();

      print('DEBUG: User response: $userResponse');

      final serviceResponse =
          await SupabaseService.client
              .from('service_accounts')
              .select('balance, main_service_id, operational_type')
              .eq('id', serviceAccountId)
              .single();

      print('DEBUG: Service response: $serviceResponse');

      final currentUserBalance = (userResponse['balance'] as num).toDouble();
      final currentServiceBalance =
          (serviceResponse['balance'] as num?)?.toDouble() ?? 0.0;
      final mainServiceId = serviceResponse['main_service_id'] as int?;
      final operationalTypeDb =
          serviceResponse['operational_type']?.toString() ?? operationalType;

      print(
        'DEBUG: Current balances - User: $currentUserBalance, Service: $currentServiceBalance',
      );

      // Determine which account receives the balance credit
      final bool isSubAccount = operationalTypeDb == 'Sub';
      final int? creditAccountId =
          isSubAccount ? mainServiceId : serviceAccountId;

      if (isSubAccount && creditAccountId == null) {
        return {
          'success': false,
          'error':
              'Fallback payment processing failed: Missing main service for Sub account',
        };
      }

      // Calculate new balances
      final newUserBalance = currentUserBalance - amount;

      print(
        'DEBUG: Updating user balance from $currentUserBalance to $newUserBalance',
      );
      // Update user balance
      final userUpdateResult = await SupabaseService.client
          .from('auth_students')
          .update({
            'balance': newUserBalance,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);

      print('DEBUG: User balance update result: $userUpdateResult');

      // Update credited account balance: Main for Sub accounts, otherwise current service
      print(
        'DEBUG: Updating credited service balance for account ${creditAccountId} (+$amount)',
      );
      final int creditedId = creditAccountId!;
      // Fetch current credited balance first
      final creditedBeforeResp =
          await SupabaseService.client
              .from('service_accounts')
              .select('balance')
              .eq('id', creditedId)
              .single();
      final creditedPrevBalance =
          (creditedBeforeResp['balance'] as num?)?.toDouble() ?? 0.0;

      final creditedNewBalance = creditedPrevBalance + amount;
      final serviceUpdateResult = await SupabaseService.client
          .from('service_accounts')
          .update({
            'balance': creditedNewBalance,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', creditedId);

      print('DEBUG: Service balance update result: $serviceUpdateResult');

      // Verify the credited account balance was actually updated
      final verifyServiceResponse =
          await SupabaseService.client
              .from('service_accounts')
              .select('balance')
              .eq('id', creditedId)
              .single();

      final actualCreditedBalance =
          (verifyServiceResponse['balance'] as num?)?.toDouble() ??
          creditedNewBalance;
      print(
        'DEBUG: Actual credited balance after update: $actualCreditedBalance (expected: $creditedNewBalance)',
      );

      if (actualCreditedBalance != creditedNewBalance) {
        print(
          'WARNING: Service balance update failed! Expected $creditedNewBalance but got $actualCreditedBalance',
        );
      }

      // Create service transaction using SupabaseService method
      final transactionResult = await SupabaseService.createServiceTransaction(
        serviceAccountId: serviceAccountId,
        operationalType: operationalTypeDb,
        studentId: studentId, // Real student_id from auth_students.student_id
        items: transactionItems,
        totalAmount: amount,
        mainServiceId: mainServiceId,
        metadata: {
          'user_id': userId,
          'student_id': studentId, // Store student_id in metadata for filtering
          'previous_user_balance': currentUserBalance,
          'new_user_balance': newUserBalance,
          'previous_service_balance': creditedPrevBalance,
          'new_service_balance': creditedNewBalance,
          'payment_method': 'RFID',
          'processed_at': DateTime.now().toIso8601String(),
          'credited_account_id': creditedId,
        },
      );

      if (transactionResult['success']) {
        final transactionData = transactionResult['data'];
        transactionId = 'TXN${transactionData['id']}';

        return {
          'success': true,
          'transaction_id': transactionData['id'],
          'user_id': userId,
          'service_account_id': serviceAccountId,
          'amount': amount,
          'previous_user_balance': currentUserBalance,
          'new_user_balance': newUserBalance,
          'previous_service_balance': creditedPrevBalance,
          'new_service_balance': creditedNewBalance,
          'credited_account_id': creditedId,
        };
      } else {
        throw Exception(transactionResult['message']);
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Fallback payment processing failed: $e',
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMultipleItems = widget.product.containsKey('orderItems');
    final totalAmount =
        isMultipleItems
            ? widget.product['totalAmount']
            : widget.product['price'];

    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final isWeb = screenWidth > 600;
    final isTablet = screenWidth > 480 && screenWidth <= 1024;

    // Responsive sizing
    final headerHeight = isWeb ? 120.0 : (isTablet ? 140.0 : 160.0);
    final horizontalPadding = isWeb ? 24.0 : (isTablet ? 20.0 : 16.0);
    final verticalPadding = isWeb ? 16.0 : 12.0;
    final maxWidth = isWeb ? 800.0 : double.infinity;
    final borderRadius =
        isWeb
            ? 12.0
            : 0.0; // Remove border radius on mobile for edge-to-edge coverage

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: Container(
                width: isWeb ? null : double.infinity,
                height: isWeb ? null : double.infinity,
                constraints: BoxConstraints(
                  maxWidth: maxWidth,
                  maxHeight: isWeb ? 900 : double.infinity,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius:
                      isWeb ? BorderRadius.circular(borderRadius) : null,
                  boxShadow:
                      isWeb
                          ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ]
                          : null,
                ),
                child: Column(
                  children: [
                    // Header Section
                    Container(
                      width: double.infinity,
                      height: headerHeight,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFB91C1C), Color(0xFF7F1D1D)],
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(borderRadius),
                          topRight: Radius.circular(borderRadius),
                        ),
                      ),
                      child: Stack(
                        children: [
                          // Back button
                          Positioned(
                            top: isWeb ? 16 : 20,
                            left: horizontalPadding,
                            child: GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Icon(
                                  Icons.arrow_back,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),

                          // Content
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: horizontalPadding,
                              vertical: verticalPadding,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'PAYMENT',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: isWeb ? 28 : (isTablet ? 26 : 24),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  widget.serviceName,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: isWeb ? 16 : (isTablet ? 15 : 14),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Main Content
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(horizontalPadding),
                        child: Column(
                          children: [
                            // Order Summary
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(isWeb ? 24 : 20),
                              margin: const EdgeInsets.only(bottom: 20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: const Color(0xFFE9ECEF),
                                ),
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
                                    'Order Summary',
                                    style: TextStyle(
                                      fontSize: isWeb ? 18 : 16,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF333333),
                                    ),
                                  ),
                                  const SizedBox(height: 15),

                                  if (isMultipleItems) ...[
                                    // Multiple items with improved layout
                                    ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxHeight: constraints.maxHeight * 0.3,
                                      ),
                                      child: ListView.builder(
                                        shrinkWrap: true,
                                        physics: const BouncingScrollPhysics(),
                                        itemCount:
                                            widget.product['orderItems'].length,
                                        itemBuilder: (context, index) {
                                          final item =
                                              widget
                                                  .product['orderItems'][index];
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 8,
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  flex: 3,
                                                  child: Text(
                                                    '${item['name']}',
                                                    style: TextStyle(
                                                      fontSize: isWeb ? 15 : 14,
                                                      color: const Color(
                                                        0xFF333333,
                                                      ),
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 1,
                                                  child: Text(
                                                    'x${item['quantity']}',
                                                    style: TextStyle(
                                                      fontSize: isWeb ? 15 : 14,
                                                      color: const Color(
                                                        0xFF666666,
                                                      ),
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 2,
                                                  child: Text(
                                                    '₱${item['total'].toStringAsFixed(2)}',
                                                    style: TextStyle(
                                                      fontSize: isWeb ? 15 : 14,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: const Color(
                                                        0xFFB91C1C,
                                                      ),
                                                    ),
                                                    textAlign: TextAlign.end,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ] else ...[
                                    // Single item
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            widget.product['name'],
                                            style: TextStyle(
                                              fontSize: isWeb ? 15 : 14,
                                              color: const Color(0xFF333333),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 2,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Text(
                                          '₱${widget.product['price'].toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontSize: isWeb ? 15 : 14,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFFB91C1C),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],

                                  const Divider(height: 20),

                                  // Total
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Total Amount',
                                        style: TextStyle(
                                          fontSize: isWeb ? 18 : 16,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF333333),
                                        ),
                                      ),
                                      Text(
                                        '₱${totalAmount.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: isWeb ? 22 : 20,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFFB91C1C),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // RFID Payment Zone
                            AnimatedBuilder(
                              animation: _animationController,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale:
                                      isProcessingPayment
                                          ? _scaleAnimation.value
                                          : 1.0,
                                  child: Transform.rotate(
                                    angle:
                                        isProcessingPayment
                                            ? _rotationAnimation.value
                                            : 0.0,
                                    child: Container(
                                      width: double.infinity,
                                      padding: EdgeInsets.all(
                                        isWeb ? 40 : (isTablet ? 35 : 30),
                                      ),
                                      margin: const EdgeInsets.only(bottom: 20),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            paymentZoneColor,
                                            paymentZoneColor.withOpacity(0.8),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: paymentZoneColor.withOpacity(
                                              0.3,
                                            ),
                                            blurRadius: 15,
                                            offset: const Offset(0, 5),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        children: [
                                          Container(
                                            width:
                                                isWeb
                                                    ? 90
                                                    : (isTablet ? 85 : 80),
                                            height:
                                                isWeb
                                                    ? 90
                                                    : (isTablet ? 85 : 80),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    isWeb ? 45 : 40,
                                                  ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.1),
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 3),
                                                ),
                                              ],
                                            ),
                                            child: Center(
                                              child: Text(
                                                paymentIcon,
                                                style: TextStyle(
                                                  fontSize:
                                                      isWeb
                                                          ? 40
                                                          : (isTablet
                                                              ? 38
                                                              : 35),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 20),
                                          Text(
                                            paymentStatus,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize:
                                                  isWeb
                                                      ? 20
                                                      : (isTablet ? 19 : 18),
                                              fontWeight: FontWeight.bold,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            isProcessingPayment
                                                ? 'Please wait...'
                                                : paymentCompleted
                                                ? 'Transaction completed successfully'
                                                : 'Tap your RFID card on the scanner',
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(
                                                0.9,
                                              ),
                                              fontSize:
                                                  isWeb
                                                      ? 16
                                                      : (isTablet ? 15 : 14),
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),

                            // Transaction Details (shown after successful payment)
                            if (paymentCompleted && transactionId != null)
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(isWeb ? 24 : 20),
                                margin: const EdgeInsets.only(bottom: 20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(
                                    color: const Color(0xFF28A745),
                                  ),
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
                                      'Transaction Details',
                                      style: TextStyle(
                                        fontSize: isWeb ? 18 : 16,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF333333),
                                      ),
                                    ),
                                    const SizedBox(height: 15),
                                    _buildDetailRow(
                                      'Transaction ID',
                                      transactionId!,
                                      isWeb,
                                    ),
                                    _buildDetailRow(
                                      'Date & Time',
                                      '${transactionTime!.day}/${transactionTime!.month}/${transactionTime!.year} ${transactionTime!.hour}:${transactionTime!.minute.toString().padLeft(2, '0')}',
                                      isWeb,
                                    ),
                                    _buildDetailRow(
                                      'Payment Method',
                                      'RFID Card',
                                      isWeb,
                                    ),
                                    _buildDetailRow(
                                      'Status',
                                      'Completed',
                                      isWeb,
                                    ),
                                  ],
                                ),
                              ),

                            // Add some bottom spacing for mobile
                            if (!isWeb) const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isWeb) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: isWeb ? 15 : 14,
                color: const Color(0xFF666666),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontSize: isWeb ? 15 : 14,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF333333),
              ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}
