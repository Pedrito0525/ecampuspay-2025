import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class TransactionsTab extends StatefulWidget {
  const TransactionsTab({super.key});

  @override
  State<TransactionsTab> createState() => _TransactionsTabState();
}

class _TransactionsTabState extends State<TransactionsTab> {
  static const Color evsuRed = Color(0xFFB01212);
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Completed'];
  final TextEditingController _searchController = TextEditingController();

  // Real data variables
  List<Map<String, dynamic>> _transactions = [];
  bool _loading = false;
  int _totalTransactions = 0;
  int _successfulTransactions = 0;
  double _totalAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
    _loadTodayStats();
  }

  Future<void> _loadTransactions() async {
    setState(() => _loading = true);
    try {
      final result = await SupabaseService.getServiceTransactions(limit: 50);
      if (result['success'] == true) {
        setState(() {
          _transactions =
              (result['data']['transactions'] as List<dynamic>?)
                  ?.cast<Map<String, dynamic>>() ??
              [];
        });
      }
    } catch (e) {
      print("Error loading transactions: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadTodayStats() async {
    try {
      final result = await SupabaseService.getTodayTransactionStats();
      if (result['success'] == true) {
        setState(() {
          _totalTransactions = result['data']['total_transactions'] ?? 0;
          _successfulTransactions =
              result['data']['successful_transactions'] ?? 0;
          _totalAmount =
              (result['data']['total_amount'] as num?)?.toDouble() ?? 0.0;
        });
      }
    } catch (e) {
      print("Error loading today's stats: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // Header and Search
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Live Transactions',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: evsuRed,
                            ),
                          ),
                          Text(
                            'Real-time transaction monitoring',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        _loadTransactions();
                        _loadTodayStats();
                      },
                      icon: const Icon(Icons.refresh, color: evsuRed),
                      tooltip: 'Refresh transactions',
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search transactions...',
                    prefixIcon: const Icon(Icons.search, color: evsuRed),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: evsuRed),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),
                const SizedBox(height: 16),

                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children:
                        _filters
                            .map(
                              (filter) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: FilterChip(
                                  label: Text(filter),
                                  selected: _selectedFilter == filter,
                                  onSelected: (selected) {
                                    setState(() => _selectedFilter = filter);
                                  },
                                  selectedColor: evsuRed.withOpacity(0.1),
                                  checkmarkColor: evsuRed,
                                  labelStyle: TextStyle(
                                    color:
                                        _selectedFilter == filter
                                            ? evsuRed
                                            : Colors.grey[700],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                  ),
                ),
              ],
            ),
          ),

          // Transaction Stats
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'Today',
                    value: _totalTransactions.toString(),
                    subtitle: 'transactions',
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    title: 'Successful',
                    value: _successfulTransactions.toString(),
                    subtitle: 'completed',
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    title: 'Total Amount',
                    value: '₱${_totalAmount.toStringAsFixed(0)}',
                    subtitle: 'today',
                    color: evsuRed,
                  ),
                ),
              ],
            ),
          ),

          // Transaction List
          Expanded(
            child:
                _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _transactions.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No transactions found',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Transactions will appear here when students make payments',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _transactions.length,
                      itemBuilder:
                          (context, index) => _TransactionItem(
                            transaction: _formatTransactionData(
                              _transactions[index],
                            ),
                            onTap:
                                () => _showTransactionDetails(context, index),
                          ),
                    ),
          ),
        ],
      ),
    );
  }

  TransactionData _formatTransactionData(Map<String, dynamic> data) {
    return TransactionData(
      id: data['id']?.toString() ?? 'Unknown',
      type: data['type']?.toString() ?? 'payment',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      status: data['status']?.toString() ?? 'completed',
      vendor: data['service_name']?.toString() ?? 'Unknown Store',
      student: data['student_name']?.toString() ?? 'Unknown Student',
      timestamp:
          DateTime.tryParse(data['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  void _showTransactionDetails(BuildContext context, int index) {
    final transaction = _formatTransactionData(_transactions[index]);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.7,
            maxChildSize: 0.9,
            minChildSize: 0.5,
            builder:
                (context, scrollController) => Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Column(
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
                      Expanded(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Transaction Details',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: evsuRed,
                                ),
                              ),
                              const SizedBox(height: 20),
                              _DetailRow('Transaction ID', transaction.id),
                              _DetailRow('Type', 'SERVICE PAYMENT'),
                              _DetailRow(
                                'Amount',
                                '₱${transaction.amount.toStringAsFixed(2)}',
                              ),
                              _DetailRow('Status', 'COMPLETED'),
                              _DetailRow('Student', transaction.student),
                              _DetailRow('Store', transaction.vendor),
                              _DetailRow(
                                'Date & Time',
                                _formatTimestamp(transaction.timestamp),
                              ),
                              const SizedBox(height: 20),
                              if (transaction.status == 'completed') ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.green.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Payment Successful',
                                        style: TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
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

  Widget _DetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hr ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  // Transaction functions removed since transactions are now completed automatically
}

class TransactionData {
  final String id;
  final String type;
  final double amount;
  final String status;
  final String vendor;
  final String student;
  final DateTime timestamp;

  TransactionData({
    required this.id,
    required this.type,
    required this.amount,
    required this.status,
    required this.vendor,
    required this.student,
    required this.timestamp,
  });
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(fontSize: 10, color: color.withOpacity(0.7)),
          ),
        ],
      ),
    );
  }
}

class _TransactionItem extends StatelessWidget {
  final TransactionData transaction;
  final VoidCallback onTap;

  const _TransactionItem({required this.transaction, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _getStatusColor().withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getTransactionIcon(),
            color: _getStatusColor(),
            size: 20,
          ),
        ),
        title: Text(
          transaction.id,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${transaction.student} • ${transaction.vendor}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    transaction.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _getStatusColor(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatTimestamp(transaction.timestamp),
                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                ),
              ],
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₱${transaction.amount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _TransactionsTabState.evsuRed,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor() {
    return Colors.green; // All transactions are completed
  }

  IconData _getTransactionIcon() {
    return Icons.payment; // All service transactions are payments
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${timestamp.day}/${timestamp.month}';
    }
  }
}
