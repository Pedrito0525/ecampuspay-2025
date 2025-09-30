import 'package:flutter/material.dart';
import '../services/session_service.dart';
import '../services/supabase_service.dart';
import 'dart:convert';

class ServiceReportsTab extends StatefulWidget {
  const ServiceReportsTab({super.key});

  @override
  State<ServiceReportsTab> createState() => _ServiceReportsTabState();
}

class _ServiceReportsTabState extends State<ServiceReportsTab> {
  static const Color evsuRed = Color(0xFFB91C1C);
  String _selectedPeriod = 'Daily';
  final List<String> _periods = ['Daily', 'Weekly', 'Monthly', 'Yearly'];
  DateTimeRange? _dateRange;
  // loading flag removed; overview loads immediately on period tap
  List<Map<String, dynamic>> _transactions = [];
  double _totalAmount = 0.0;
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    // Default to today's range for "Daily". Data loads when user taps Generate.
    _applyQuickRange(_selectedPeriod);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTransactions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final isWeb = screenWidth > 600;
    final isTablet = screenWidth > 480 && screenWidth <= 1024;

    // Responsive sizing
    final horizontalPadding = isWeb ? 24.0 : (isTablet ? 20.0 : 16.0);
    final verticalPadding = isWeb ? 20.0 : (isTablet ? 16.0 : 12.0);
    // final crossAxisCount = isWeb ? 3 : (isTablet ? 2 : 1);

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(isWeb ? 24 : 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [evsuRed, Color(0xFF7F1D1D)],
                ),
                borderRadius: BorderRadius.circular(isWeb ? 16 : 12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reports & Analytics',
                          style: TextStyle(
                            fontSize: isWeb ? 28 : (isTablet ? 24 : 22),
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: isWeb ? 8 : 6),
                        Text(
                          'System performance overview',
                          style: TextStyle(
                            fontSize: isWeb ? 16 : (isTablet ? 15 : 14),
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      onPressed: _exportReports,
                      icon: Icon(
                        Icons.file_download,
                        color: Colors.white,
                        size: isWeb ? 28 : 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: isWeb ? 30 : 24),

            // Period Selector (auto-load overview on tap)
            Container(
              padding: EdgeInsets.all(isWeb ? 6 : 4),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(isWeb ? 16 : 12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children:
                    _periods
                        .map(
                          (period) => Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                setState(() {
                                  _selectedPeriod = period;
                                  _applyQuickRange(period);
                                });
                                await _loadTransactions();
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  vertical: isWeb ? 16 : (isTablet ? 14 : 12),
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      _selectedPeriod == period
                                          ? evsuRed
                                          : Colors.transparent,
                                  borderRadius: BorderRadius.circular(
                                    isWeb ? 12 : 8,
                                  ),
                                  boxShadow:
                                      _selectedPeriod == period
                                          ? [
                                            BoxShadow(
                                              color: evsuRed.withOpacity(0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                          : null,
                                ),
                                child: Text(
                                  period,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color:
                                        _selectedPeriod == period
                                            ? Colors.white
                                            : Colors.grey[700],
                                    fontWeight: FontWeight.w600,
                                    fontSize: isWeb ? 16 : (isTablet ? 15 : 14),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
              ),
            ),

            SizedBox(height: isWeb ? 30 : 24),

            // Key Metrics (from fetched data)
            Container(
              padding: EdgeInsets.all(isWeb ? 24 : 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(isWeb ? 16 : 12),
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
                    '$_selectedPeriod Overview',
                    style: TextStyle(
                      fontSize: isWeb ? 22 : (isTablet ? 20 : 18),
                      fontWeight: FontWeight.bold,
                      color: evsuRed,
                    ),
                  ),
                  SizedBox(height: isWeb ? 20 : 16),

                  if (isWeb)
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                      childAspectRatio: 2.5,
                      children: [
                        _MetricItem(
                          title: 'Total Revenue',
                          value: '₱' + _totalAmount.toStringAsFixed(2),
                          change: '',
                          isPositive: true,
                          isWeb: isWeb,
                        ),
                        _MetricItem(
                          title: 'Transactions',
                          value: _totalCount.toString(),
                          change: '',
                          isPositive: true,
                          isWeb: isWeb,
                        ),
                        _MetricItem(
                          title: 'Average Amount',
                          value:
                              _totalCount == 0
                                  ? '₱0.00'
                                  : '₱' +
                                      (_totalAmount / _totalCount)
                                          .toStringAsFixed(2),
                          change: '',
                          isPositive: true,
                          isWeb: isWeb,
                        ),
                        const SizedBox.shrink(),
                      ],
                    )
                  else
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _MetricItem(
                                title: 'Total Revenue',
                                value: '₱' + _totalAmount.toStringAsFixed(2),
                                change: '',
                                isPositive: true,
                                isWeb: isWeb,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _MetricItem(
                                title: 'Transactions',
                                value: _totalCount.toString(),
                                change: '',
                                isPositive: true,
                                isWeb: isWeb,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _MetricItem(
                                title: 'Average Amount',
                                value:
                                    _totalCount == 0
                                        ? '₱0.00'
                                        : '₱' +
                                            (_totalAmount / _totalCount)
                                                .toStringAsFixed(2),
                                change: '',
                                isPositive: true,
                                isWeb: isWeb,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(child: SizedBox.shrink()),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
            ),

            SizedBox(height: isWeb ? 30 : 24),

            // Transactions + Export
            Container(
              padding: EdgeInsets.all(isWeb ? 24 : 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(isWeb ? 16 : 12),
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Transactions',
                          style: TextStyle(
                            fontSize: isWeb ? 20 : (isTablet ? 18 : 16),
                            fontWeight: FontWeight.bold,
                            color: evsuRed,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _transactions.isEmpty ? null : _exportExcel,
                        icon: const Icon(Icons.table_chart),
                        label: const Text('Export Excel'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_transactions.isEmpty)
                    Text(
                      'No data. Pick a date range and tap Generate.',
                      style: TextStyle(color: Colors.grey[600]),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _transactions.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final t = _transactions[index];
                        return ListTile(
                          dense: true,
                          title: Text(
                            '${t['created_at'] ?? ''}  •  ₱${(t['total_amount'] as num).toDouble().toStringAsFixed(2)}',
                          ),
                          subtitle: Text(
                            'Items: ' + (t['items'] as List).length.toString(),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),

            SizedBox(height: isWeb ? 60 : 100), // Space for bottom nav
          ],
        ),
      ),
    );
  }

  void _exportReports() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            margin: const EdgeInsets.all(16),
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
                    'Export Options',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: evsuRed,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _dateRange == null
                              ? 'Select export date range'
                              : _formatRange(_dateRange!),
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _pickRange,
                        icon: const Icon(Icons.date_range),
                        label: const Text('Pick Range'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                  title: const Text('Export as PDF'),
                  onTap: () {
                    Navigator.pop(context);
                    _exportAs('PDF');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.table_chart, color: Colors.green),
                  title: const Text('Export as Excel'),
                  onTap: () {
                    Navigator.pop(context);
                    _exportAs('Excel');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.email, color: evsuRed),
                  title: const Text('Email Report'),
                  onTap: () {
                    Navigator.pop(context);
                    _emailReport();
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
    );
  }

  void _exportAs(String format) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exporting $_selectedPeriod report as $format...'),
        backgroundColor: evsuRed,
      ),
    );
  }

  void _emailReport() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Preparing email report...'),
        backgroundColor: evsuRed,
      ),
    );
  }

  void _applyQuickRange(String period) {
    final now = DateTime.now();
    DateTime start;
    DateTime end;
    switch (period) {
      case 'Weekly':
        start = now.subtract(const Duration(days: 6));
        end = now;
        break;
      case 'Monthly':
        start = DateTime(now.year, now.month, 1);
        end = now;
        break;
      case 'Yearly':
        start = DateTime(now.year, 1, 1);
        end = now;
        break;
      default:
        start = DateTime(now.year, now.month, now.day);
        end = now;
    }
    _dateRange = DateTimeRange(start: start, end: end);
  }

  String _formatRange(DateTimeRange range) {
    String f(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return '${f(range.start)} to ${f(range.end)}';
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final initial =
        _dateRange ??
        DateTimeRange(start: now.subtract(const Duration(days: 6)), end: now);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
      initialDateRange: initial,
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
    }
  }

  Future<void> _loadTransactions() async {
    if (_dateRange == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please pick a date range')));
      return;
    }
    // start fetch
    try {
      final serviceIdStr =
          SessionService.currentUserData?['service_id']?.toString() ?? '0';
      final serviceId = int.tryParse(serviceIdStr) ?? 0;

      await SupabaseService.initialize();
      final from =
          DateTime(
            _dateRange!.start.year,
            _dateRange!.start.month,
            _dateRange!.start.day,
          ).toIso8601String();
      final to = _dateRange!.end.add(const Duration(days: 1)).toIso8601String();

      final res = await SupabaseService.client
          .from('service_transactions')
          .select('id, created_at, items, total_amount')
          .eq('service_account_id', serviceId)
          .gte('created_at', from)
          .lt('created_at', to)
          .order('created_at', ascending: false);

      final tx =
          (res as List)
              .map<Map<String, dynamic>>(
                (e) => Map<String, dynamic>.from(e as Map),
              )
              .toList();
      double total = 0.0;
      for (final t in tx) {
        total += (t['total_amount'] as num).toDouble();
      }
      setState(() {
        _transactions = tx;
        _totalAmount = total;
        _totalCount = tx.length;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load transactions: $e')),
      );
    } finally {
      // done
    }
  }

  void _exportExcel() {
    final headers = ['Date', 'Item', 'Quantity', 'Price', 'Line Total'];
    final rows = <List<String>>[];
    for (final t in _transactions) {
      final created = t['created_at']?.toString() ?? '';
      final items =
          (t['items'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
      for (final it in items) {
        final name = (it['name'] ?? '').toString();
        final qty = (it['quantity'] ?? 1).toString();
        final price = ((it['price'] as num?)?.toDouble() ?? 0.0)
            .toStringAsFixed(2);
        final line = ((it['total'] as num?)?.toDouble() ??
                ((it['price'] as num?)?.toDouble() ?? 0.0) *
                    (it['quantity'] ?? 1))
            .toStringAsFixed(2);
        rows.add([created, name, qty, price, line]);
      }
    }
    final csv = StringBuffer();
    csv.writeln(headers.join(','));
    for (final r in rows) {
      csv.writeln(r.map((c) => '"${c.replaceAll('"', '""')}"').join(','));
    }

    final bytes = utf8.encode(csv.toString());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Excel CSV generated (${bytes.length} bytes). Implement saving/sharing as needed.',
        ),
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  final String title;
  final String value;
  final String change;
  final bool isPositive;
  final bool isWeb;

  const _MetricItem({
    required this.title,
    required this.value,
    required this.change,
    required this.isPositive,
    required this.isWeb,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isWeb ? 20 : 16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: isWeb ? 14 : 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: isWeb ? 8 : 6),
          Text(
            value,
            style: TextStyle(
              fontSize: isWeb ? 24 : 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF333333),
            ),
          ),
          SizedBox(height: isWeb ? 6 : 4),
          Row(
            children: [
              Icon(
                isPositive ? Icons.trending_up : Icons.trending_down,
                size: isWeb ? 18 : 16,
                color: isPositive ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 4),
              Text(
                change,
                style: TextStyle(
                  fontSize: isWeb ? 14 : 12,
                  color: isPositive ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// (no extra components)
