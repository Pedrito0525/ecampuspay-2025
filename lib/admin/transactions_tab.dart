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
  final List<String> _filters = ['All', 'Transactions', 'Top-Ups', 'Loans'];
  final TextEditingController _searchController = TextEditingController();

  // Real data variables
  List<Map<String, dynamic>> _allTransactions = [];
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTransactions() async {
    setState(() => _loading = true);
    try {
      final result = await SupabaseService.getServiceTransactions(limit: 150);
      if (result['success'] == true) {
        final fetchedTransactions =
            (result['data']['transactions'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>() ??
            [];
        final topUpGcashCount =
            fetchedTransactions.where((transaction) {
              return (transaction['transaction_type']?.toString() ?? '')
                      .toLowerCase() ==
                  'top_up_gcash';
            }).length;
        // Debug insights for missing GCASH top-ups
        // ignore: avoid_print
        print(
          '[TransactionsTab] Loaded ${fetchedTransactions.length} records '
          '(top_up_gcash: $topUpGcashCount)',
        );
        if (mounted) {
          setState(() {
            _allTransactions = fetchedTransactions;
            _transactions = _filterTransactions();
          });
        }
      }
    } catch (e) {
      print("Error loading transactions: $e");
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  List<Map<String, dynamic>> _filterTransactions() {
    final String normalizedFilter = _selectedFilter.toLowerCase();
    final String categoryFilter = _categoryFromFilter(normalizedFilter);
    final String query = _searchController.text.trim().toLowerCase();

    return _allTransactions.where((transaction) {
      final String category =
          transaction['category']?.toString().toLowerCase() ?? 'transactions';
      final bool matchesFilter =
          categoryFilter == 'all' || category == categoryFilter;

      if (!matchesFilter) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      final String studentId =
          transaction['student_id']?.toString().toLowerCase() ?? '';
      final String studentName =
          transaction['student_name']?.toString().toLowerCase() ?? '';
      final String serviceName =
          transaction['service_name']?.toString().toLowerCase() ?? '';
      final String processedBy =
          transaction['processed_by']?.toString().toLowerCase() ?? '';
      final String transactionType =
          transaction['transaction_type']?.toString().toLowerCase() ?? '';

      return studentId.contains(query) ||
          studentName.contains(query) ||
          serviceName.contains(query) ||
          processedBy.contains(query) ||
          transactionType.contains(query);
    }).toList();
  }

  void _applyFilters() {
    if (!mounted) {
      return;
    }
    setState(() {
      _transactions = _filterTransactions();
    });
  }

  String _categoryFromFilter(String filter) {
    switch (filter) {
      case 'top-ups':
        return 'top_up';
      case 'loans':
        return 'loan';
      case 'transactions':
        return 'transactions';
      default:
        return 'all';
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
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _searchController,
                  builder: (context, value, _) {
                    return TextField(
                      controller: _searchController,
                      onChanged: (_) => _applyFilters(),
                      decoration: InputDecoration(
                        hintText: 'Search by student ID or service name...',
                        prefixIcon: const Icon(Icons.search, color: evsuRed),
                        suffixIcon:
                            value.text.isEmpty
                                ? null
                                : IconButton(
                                  tooltip: 'Clear search',
                                  onPressed: () {
                                    _searchController.clear();
                                    _applyFilters();
                                  },
                                  icon: const Icon(Icons.close, color: evsuRed),
                                ),
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
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children:
                        _filters.map((filter) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(filter),
                              selected: _selectedFilter == filter,
                              onSelected: (selected) {
                                if (!selected) {
                                  return;
                                }
                                setState(() {
                                  _selectedFilter = filter;
                                  _transactions = _filterTransactions();
                                });
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
                          );
                        }).toList(),
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

  String _safeString(dynamic value, {String fallback = 'N/A'}) {
    if (value == null) {
      return fallback;
    }
    final text = value.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') {
      return fallback;
    }
    return text;
  }

  String? _optionalString(dynamic value) {
    if (value == null) {
      return null;
    }
    final text = value.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') {
      return null;
    }
    return text;
  }

  TransactionData _formatTransactionData(Map<String, dynamic> data) {
    final String category =
        _safeString(data['category'], fallback: 'transactions').toLowerCase();
    final String transactionType =
        _safeString(
          data['transaction_type'],
          fallback: 'service_payment',
        ).toLowerCase();

    return TransactionData(
      id: _safeString(data['id'], fallback: 'Unknown'),
      transactionType: transactionType,
      category: category,
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      status: _safeString(data['status'], fallback: 'completed'),
      vendor: _safeString(data['service_name'], fallback: 'Unknown Source'),
      student: _safeString(data['student_name'], fallback: 'Unknown Student'),
      studentId: _safeString(data['student_id'], fallback: 'Unknown ID'),
      notes: _optionalString(data['notes']),
      processedBy: _optionalString(data['processed_by']),
      previousBalance: (data['previous_balance'] as num?)?.toDouble(),
      newBalance: (data['new_balance'] as num?)?.toDouble(),
      timestamp:
          DateTime.tryParse(_safeString(data['created_at'], fallback: '')) ??
          DateTime.now(),
    );
  }

  static Color categoryColor(String category) {
    switch (category) {
      case 'top_up':
        return const Color(0xFF2563EB);
      case 'loan':
        return const Color(0xFFF59E0B);
      default:
        return Colors.green;
    }
  }

  static IconData categoryIcon(String category) {
    switch (category) {
      case 'top_up':
        return Icons.account_balance_wallet;
      case 'loan':
        return Icons.request_quote;
      default:
        return Icons.payment;
    }
  }

  void _showTransactionDetails(BuildContext context, int index) {
    final transaction = _formatTransactionData(_transactions[index]);
    final Color highlightColor = categoryColor(transaction.category);
    final IconData highlightIcon = categoryIcon(transaction.category);
    final bool hasNotes =
        transaction.notes != null && transaction.notes!.isNotEmpty;
    final bool showProcessedBy =
        transaction.processedBy != null &&
        transaction.processedBy!.isNotEmpty &&
        transaction.processedBy!.toLowerCase() !=
            transaction.vendor.toLowerCase();
    final bool hasPreviousBalance = transaction.previousBalance != null;
    final bool hasNewBalance = transaction.newBalance != null;

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
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: highlightColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: highlightColor.withOpacity(0.25),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      highlightIcon,
                                      color: highlightColor,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            transaction.transactionTypeLabel,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: highlightColor,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Recorded ${_formatTimestamp(transaction.timestamp)}',
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
                              const SizedBox(height: 20),
                              _DetailRow('Transaction ID', transaction.id),
                              _DetailRow('Category', transaction.categoryLabel),
                              _DetailRow(
                                'Type',
                                transaction.transactionTypeLabel,
                              ),
                              _DetailRow('Status', transaction.statusLabel),
                              _DetailRow(
                                'Amount',
                                '₱${transaction.amount.toStringAsFixed(2)}',
                              ),
                              _DetailRow('Student', transaction.student),
                              _DetailRow('Student ID', transaction.studentId),
                              _DetailRow(
                                'Service / Source',
                                transaction.vendor,
                              ),
                              if (showProcessedBy)
                                _DetailRow(
                                  'Processed By',
                                  transaction.processedBy!,
                                ),
                              _DetailRow(
                                'Recorded On',
                                _formatFullTimestamp(transaction.timestamp),
                              ),
                              if (hasPreviousBalance)
                                _DetailRow(
                                  'Previous Balance',
                                  '₱${transaction.previousBalance!.toStringAsFixed(2)}',
                                ),
                              if (hasNewBalance)
                                _DetailRow(
                                  'New Balance',
                                  '₱${transaction.newBalance!.toStringAsFixed(2)}',
                                ),
                              if (hasNotes) ...[
                                const SizedBox(height: 16),
                                Text(
                                  'Notes',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Text(
                                    transaction.notes!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[800],
                                    ),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool useColumn = constraints.maxWidth < 360;

        if (useColumn) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  softWrap: true,
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                flex: 3,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                flex: 5,
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  softWrap: true,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes <= 0) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hr ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  String _formatFullTimestamp(DateTime timestamp) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');

    final date =
        '${timestamp.year}-${twoDigits(timestamp.month)}-${twoDigits(timestamp.day)}';
    final time =
        '${twoDigits(timestamp.hour)}:${twoDigits(timestamp.minute)}:${twoDigits(timestamp.second)}';

    return '$date • $time';
  }

  // Transaction functions removed since transactions are now completed automatically
}

class TransactionData {
  final String id;
  final String transactionType;
  final String category;
  final double amount;
  final String status;
  final String vendor;
  final String student;
  final String studentId;
  final DateTime timestamp;
  final String? notes;
  final String? processedBy;
  final double? previousBalance;
  final double? newBalance;

  TransactionData({
    required this.id,
    required this.transactionType,
    required this.category,
    required this.amount,
    required this.status,
    required this.vendor,
    required this.student,
    required this.studentId,
    required this.timestamp,
    this.notes,
    this.processedBy,
    this.previousBalance,
    this.newBalance,
  });

  String get categoryLabel {
    switch (category) {
      case 'top_up':
        return 'Top-Up';
      case 'loan':
        return 'Loan';
      default:
        return 'Transaction';
    }
  }

  String get transactionTypeLabel {
    return transactionType.replaceAll('_', ' ').toUpperCase();
  }

  String get statusLabel => status.toUpperCase();
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
    final Color categoryColor = _TransactionsTabState.categoryColor(
      transaction.category,
    );
    final IconData categoryIcon = _TransactionsTabState.categoryIcon(
      transaction.category,
    );
    final bool showVendor =
        transaction.vendor.isNotEmpty &&
        transaction.vendor.toLowerCase() != 'unknown source';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: categoryColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(categoryIcon, color: categoryColor, size: 22),
        ),
        title: Text(
          transaction.student,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'ID: ${transaction.studentId}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildTag(
                  label: transaction.categoryLabel,
                  background: categoryColor.withOpacity(0.12),
                  textColor: categoryColor,
                  borderColor: categoryColor.withOpacity(0.28),
                ),
                _buildTag(
                  label: transaction.transactionTypeLabel,
                  background: Colors.grey.shade100,
                  textColor: Colors.grey.shade700,
                  borderColor: Colors.grey.shade300,
                ),
              ],
            ),
            if (showVendor) ...[
              const SizedBox(height: 4),
              Text(
                'Via ${transaction.vendor}',
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 4),
            Text(
              _formatTimestamp(transaction.timestamp),
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
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
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: _TransactionsTabState.evsuRed,
              ),
            ),
            const SizedBox(height: 6),
            _buildTag(
              label: transaction.statusLabel,
              background: categoryColor.withOpacity(0.12),
              textColor: categoryColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag({
    required String label,
    required Color background,
    required Color textColor,
    Color borderColor = Colors.transparent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes <= 0) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hr ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}
