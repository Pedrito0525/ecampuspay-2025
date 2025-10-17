import 'package:flutter/material.dart';
import '../services/session_service.dart';
import '../services/supabase_service.dart';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as excel;
import 'package:path_provider/path_provider.dart';

class ServiceReportsTab extends StatefulWidget {
  const ServiceReportsTab({super.key});

  @override
  State<ServiceReportsTab> createState() => _ServiceReportsTabState();
}

class _ServiceReportsTabState extends State<ServiceReportsTab> {
  static const Color evsuRed = Color(0xFFB91C1C);

  // Period selection
  String _selectedPeriod = 'Today';
  DateTimeRange? _dateRange;

  // Service data
  Map<String, String> _serviceNames = {}; // service_id -> service_name

  // Data
  List<Map<String, dynamic>> _transactions = [];
  double _totalAmount = 0.0;
  int _totalCount = 0;
  // Aggregations
  Map<String, Map<String, dynamic>> _itemAggregates = {};
  // Map<String, int> _dailyCounts = {}; // reserved for future daily chart

  @override
  void initState() {
    super.initState();
    // Default to today's range
    _applyPeriodRange('Today');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadServiceNames();
      _loadTransactions();
    });
  }

  @override
  Widget build(BuildContext context) {
    // DEBUG: current state for UI sections
    // ignore: avoid_print
    print(
      'DEBUG ReportsTab(build): totalCount=${_totalCount}, totalAmount=${_totalAmount.toStringAsFixed(2)}, items=${_itemAggregates.length}, tx=${_transactions.length}',
    );
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
                  // Export buttons with responsive layout
                  if (isWeb)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // CSV Export button
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            onPressed: () => _exportWithRange('CSV'),
                            icon: Icon(
                              Icons.table_chart,
                              color: Colors.white,
                              size: 28,
                            ),
                            tooltip: 'Export CSV',
                          ),
                        ),
                        SizedBox(width: 8),
                        // Excel Export button
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            onPressed: () => _exportWithRange('Excel'),
                            icon: Icon(
                              Icons.table_view,
                              color: Colors.white,
                              size: 28,
                            ),
                            tooltip: 'Export Excel',
                          ),
                        ),
                      ],
                    )
                  else
                    // Mobile/Tablet: Single export button with dropdown or stack
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: PopupMenuButton<String>(
                        icon: Icon(
                          Icons.file_download,
                          color: Colors.white,
                          size: 24,
                        ),
                        tooltip: 'Export Reports',
                        onSelected: (format) => _exportWithRange(format),
                        itemBuilder:
                            (context) => [
                              PopupMenuItem(
                                value: 'CSV',
                                child: Row(
                                  children: [
                                    Icon(Icons.table_chart, size: 20),
                                    SizedBox(width: 8),
                                    Text('Export CSV'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'Excel',
                                child: Row(
                                  children: [
                                    Icon(Icons.table_view, size: 20),
                                    SizedBox(width: 8),
                                    Text('Export Excel'),
                                  ],
                                ),
                              ),
                            ],
                      ),
                    ),
                ],
              ),
            ),

            SizedBox(height: isWeb ? 30 : 24),

            // Period Selector
            Container(
              padding: EdgeInsets.all(isWeb ? 20 : 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(isWeb ? 16 : 12),
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
                  Text(
                    'Period Overview',
                    style: TextStyle(
                      fontSize: isWeb ? 18 : 16,
                      fontWeight: FontWeight.bold,
                      color: evsuRed,
                    ),
                  ),
                  SizedBox(height: isWeb ? 16 : 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        ['Today', 'Week', 'Month', 'Year'].map((period) {
                          final isSelected = _selectedPeriod == period;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedPeriod = period;
                                _applyPeriodRange(period);
                              });
                              _loadTransactions();
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isWeb ? 16 : 12,
                                vertical: isWeb ? 10 : 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected ? evsuRed : Colors.grey[100],
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color:
                                      isSelected ? evsuRed : Colors.grey[300]!,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                period,
                                style: TextStyle(
                                  color:
                                      isSelected
                                          ? Colors.white
                                          : Colors.grey[700],
                                  fontSize: isWeb ? 14 : 13,
                                  fontWeight:
                                      isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                  ),
                ],
              ),
            ),

            SizedBox(height: isWeb ? 24 : 20),

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

            // Item Breakdown (Selected Range)
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
                    'Item Breakdown ($_selectedPeriod)',
                    style: TextStyle(
                      fontSize: isWeb ? 20 : (isTablet ? 18 : 16),
                      fontWeight: FontWeight.bold,
                      color: evsuRed,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_itemAggregates.isEmpty)
                    Builder(
                      builder: (context) {
                        // ignore: avoid_print
                        print('DEBUG ReportsTab(build): Item breakdown empty');
                        return Text(
                          'No items in this period.',
                          style: TextStyle(color: Colors.grey[600]),
                        );
                      },
                    )
                  else
                    Container(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.3,
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: _itemAggregates.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final entry = _itemAggregates.entries.elementAt(
                            index,
                          );
                          final name = entry.key;
                          final qty = entry.value['quantity'] as int;
                          final total = (entry.value['total'] as double);
                          return ListTile(
                            dense: true,
                            title: Text(
                              name,
                              style: TextStyle(
                                fontSize: isWeb ? 14 : (isTablet ? 13 : 12),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Text(
                              '${qty} • ₱${total.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: isWeb ? 13 : (isTablet ? 12 : 11),
                              ),
                            ),
                          );
                        },
                      ),
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
                  // Transactions header with responsive export buttons
                  if (isWeb)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Transactions',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: evsuRed,
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton.icon(
                              onPressed: () => _exportWithRange('CSV'),
                              icon: Icon(Icons.table_chart),
                              label: Text('Export CSV'),
                            ),
                            SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: () => _exportWithRange('Excel'),
                              icon: Icon(Icons.table_view),
                              label: Text('Export Excel'),
                            ),
                          ],
                        ),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Transactions',
                          style: TextStyle(
                            fontSize: isTablet ? 18 : 16,
                            fontWeight: FontWeight.bold,
                            color: evsuRed,
                          ),
                        ),
                        SizedBox(height: 12),
                        // Export buttons in a row for mobile/tablet
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            TextButton.icon(
                              onPressed: () => _exportWithRange('CSV'),
                              icon: Icon(Icons.table_chart, size: 16),
                              label: Text('CSV'),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => _exportWithRange('Excel'),
                              icon: Icon(Icons.table_view, size: 16),
                              label: Text('Excel'),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  if (_transactions.isEmpty)
                    Builder(
                      builder: (context) {
                        // ignore: avoid_print
                        print(
                          'DEBUG ReportsTab(build): Transactions empty for today',
                        );
                        return Text(
                          'No transactions today.',
                          style: TextStyle(color: Colors.grey[600]),
                        );
                      },
                    )
                  else
                    Container(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.4,
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: _transactions.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final t = _transactions[index];
                          final createdAtStr =
                              t['created_at']?.toString() ?? '';
                          final localDateTime = _formatDateTimeForDisplay(
                            createdAtStr,
                          );
                          return ListTile(
                            dense: true,
                            title: Text(
                              '$localDateTime  •  ₱${(t['total_amount'] as num).toDouble().toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: isWeb ? 14 : (isTablet ? 13 : 12),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              'Items: ' +
                                  (t['items'] as List).length.toString(),
                              style: TextStyle(
                                fontSize: isWeb ? 12 : (isTablet ? 11 : 10),
                              ),
                            ),
                          );
                        },
                      ),
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

  // Export modal removed; direct CSV export is provided via buttons

  // Removed unused export/email helpers

  void _applyPeriodRange(String period) {
    final now = DateTime.now();
    DateTime start;
    DateTime end = now;

    switch (period) {
      case 'Today':
        start = DateTime(now.year, now.month, now.day);
        break;
      case 'Week':
        // Start of current week (Monday)
        final weekday = now.weekday;
        start = now.subtract(Duration(days: weekday - 1));
        start = DateTime(start.year, start.month, start.day);
        break;
      case 'Month':
        // Start of current month
        start = DateTime(now.year, now.month, 1);
        break;
      case 'Year':
        // Start of current year
        start = DateTime(now.year, 1, 1);
        break;
      default:
        start = DateTime(now.year, now.month, now.day);
    }

    _dateRange = DateTimeRange(start: start, end: end);
  }

  // Removed unused date range helpers

  Future<void> _loadTransactions() async {
    // start fetch
    try {
      // Use the selected date range
      final range = _dateRange;
      if (range == null) return;

      // Convert PHT (UTC+8) to UTC for Supabase query
      final phtStart = DateTime(
        range.start.year,
        range.start.month,
        range.start.day,
        0,
        0,
        0,
      );
      final phtEnd = DateTime(
        range.end.year,
        range.end.month,
        range.end.day,
        23,
        59,
        59,
      );

      // Convert PHT to UTC (subtract 8 hours)
      final utcStart = phtStart.subtract(const Duration(hours: 8));
      final utcEnd = phtEnd.subtract(const Duration(hours: 8));

      final from = utcStart.toIso8601String();
      final to = utcEnd.toIso8601String();

      final serviceIdStr =
          SessionService.currentUserData?['service_id']?.toString() ?? '0';
      final serviceId = int.tryParse(serviceIdStr) ?? 0;
      final operationalType =
          SessionService.currentUserData?['operational_type']?.toString() ??
          'Main';
      final mainServiceIdStr =
          SessionService.currentUserData?['main_service_id']?.toString();
      final rootMainId =
          operationalType == 'Sub'
              ? (int.tryParse(mainServiceIdStr ?? '') ?? serviceId)
              : serviceId;
      // DEBUG: Inputs
      // ignore: avoid_print
      print(
        'DEBUG ReportsTab: period=$_selectedPeriod, PHT range: $phtStart to $phtEnd',
      );
      print(
        'DEBUG ReportsTab: UTC range from=$from to=$to, rootMainId=$rootMainId',
      );

      await SupabaseService.initialize();

      final res = await SupabaseService.client
          .from('service_transactions')
          .select(
            'id, created_at, items, total_amount, service_account_id, main_service_id',
          )
          .or(
            'main_service_id.eq.${rootMainId},service_account_id.eq.${rootMainId}',
          )
          .gte('created_at', from)
          .lt('created_at', to)
          .order('created_at', ascending: false);
      // DEBUG: raw result length
      // ignore: avoid_print
      print('DEBUG ReportsTab: query returned ${(res as List).length} rows');

      final tx =
          (res as List)
              .map<Map<String, dynamic>>(
                (e) => Map<String, dynamic>.from(e as Map),
              )
              .toList();
      // DEBUG: first few rows
      for (int i = 0; i < (tx.length > 3 ? 3 : tx.length); i++) {
        final t = tx[i];
        // ignore: avoid_print
        print(
          'DEBUG ReportsTab: row[$i] id=${t['id']} created_at=${t['created_at']} total_amount=${t['total_amount']}',
        );
      }
      double total = 0.0;
      final itemAgg = <String, Map<String, dynamic>>{};
      final daily = <String, int>{};
      for (final t in tx) {
        total += (t['total_amount'] as num).toDouble();
        final created = DateTime.tryParse(t['created_at']?.toString() ?? '');
        if (created != null) {
          final key =
              '${created.year}-${created.month.toString().padLeft(2, '0')}-${created.day.toString().padLeft(2, '0')}';
          daily[key] = (daily[key] ?? 0) + 1;
        }
        final items =
            (t['items'] as List)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
        for (final it in items) {
          final name = (it['name'] ?? '').toString();
          final qty = (it['quantity'] as num?)?.toInt() ?? 1;
          final lineTotal =
              (it['total'] as num?)?.toDouble() ??
              ((it['price'] as num?)?.toDouble() ?? 0.0) * qty;
          final prev = itemAgg[name];
          if (prev == null) {
            itemAgg[name] = {'quantity': qty, 'total': lineTotal};
          } else {
            itemAgg[name] = {
              'quantity': (prev['quantity'] as int) + qty,
              'total': (prev['total'] as double) + lineTotal,
            };
          }
        }
      }
      // DEBUG: aggregates
      // ignore: avoid_print
      print(
        'DEBUG ReportsTab: totalAmount=$total, txCount=${tx.length}, distinctItems=${itemAgg.length}',
      );
      setState(() {
        _transactions = tx;
        _totalAmount = total;
        _totalCount = tx.length;
        _itemAggregates = itemAgg;
        // _dailyCounts = daily;
      });
    } catch (e) {
      if (!mounted) return;
      // ignore: avoid_print
      print('DEBUG ReportsTab: load error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load transactions: $e')),
      );
    } finally {
      // done
    }
  }

  /// Show date selection dialog with option for single date or date range
  Future<void> _showDateSelectionDialog(
    DateTimeRange initialRange,
    String format,
  ) async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Select Date Range'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Choose the date range for export:'),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _showDateRangePicker(initialRange, format);
                      },
                      icon: Icon(Icons.date_range),
                      label: Text('Date Range'),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _showSingleDatePicker(format);
                      },
                      icon: Icon(Icons.calendar_today),
                      label: Text('Single Date'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  /// Show date range picker
  Future<void> _showDateRangePicker(
    DateTimeRange initialRange,
    String format,
  ) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
      initialDateRange: initialRange,
    );
    if (picked != null) {
      await _performExport(picked, format);
    }
  }

  /// Show single date picker
  Future<void> _showSingleDatePicker(String format) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) {
      // Convert single date to date range (same day)
      final dateRange = DateTimeRange(start: picked, end: picked);
      await _performExport(dateRange, format);
    }
  }

  /// Perform the actual export with the selected date range
  Future<void> _performExport(DateTimeRange dateRange, String format) async {
    try {
      // Determine root main id
      final serviceIdStr =
          SessionService.currentUserData?['service_id']?.toString() ?? '0';
      final serviceId = int.tryParse(serviceIdStr) ?? 0;
      final operationalType =
          SessionService.currentUserData?['operational_type']?.toString() ??
          'Main';
      final mainServiceIdStr =
          SessionService.currentUserData?['main_service_id']?.toString();
      final rootMainId =
          operationalType == 'Sub'
              ? (int.tryParse(mainServiceIdStr ?? '') ?? serviceId)
              : serviceId;

      await SupabaseService.initialize();

      // Convert PHT (UTC+8) to UTC for Supabase query
      final phtStart = DateTime(
        dateRange.start.year,
        dateRange.start.month,
        dateRange.start.day,
        0,
        0,
        0,
      );
      final phtEnd = DateTime(
        dateRange.end.year,
        dateRange.end.month,
        dateRange.end.day,
        23,
        59,
        59,
      );

      // Convert PHT to UTC (subtract 8 hours)
      final utcStart = phtStart.subtract(const Duration(hours: 8));
      final utcEnd = phtEnd.subtract(const Duration(hours: 8));

      final from = utcStart.toIso8601String();
      final to = utcEnd.toIso8601String();

      // ignore: avoid_print
      print(
        'DEBUG ReportsTab(export): PHT range: $phtStart to $phtEnd -> UTC range: $utcStart to $utcEnd',
      );

      final res = await SupabaseService.client
          .from('service_transactions')
          .select(
            'id, created_at, items, total_amount, service_account_id, main_service_id',
          )
          .eq(
            'main_service_id',
            rootMainId,
          ) // Only transactions for the main service
          .gte('created_at', from)
          .lt('created_at', to)
          .order('created_at', ascending: false);

      final tx =
          (res as List)
              .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
              .toList();

      // Group data by service_account_id and items
      final groupedData = <String, Map<String, dynamic>>{};
      double totalAmount = 0.0;

      for (final t in tx) {
        totalAmount += (t['total_amount'] as num).toDouble();
        final serviceAccountId =
            t['service_account_id']?.toString() ?? 'Unknown';
        final serviceAccountName =
            _serviceNames[serviceAccountId] ?? 'Unknown Service';
        final mainServiceName =
            _serviceNames[rootMainId.toString()] ?? 'Unknown Main Service';

        final items =
            (t['items'] as List)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();

        for (final item in items) {
          final itemName = (item['name'] ?? '').toString();
          final qtyNum = (item['quantity'] as num?)?.toInt() ?? 1;
          final lineTotal =
              (item['total'] as num?)?.toDouble() ??
              ((item['price'] as num?)?.toDouble() ?? 0.0) * qtyNum;

          // Create unique key for grouping
          final groupKey = '${serviceAccountId}_${itemName}';

          if (groupedData.containsKey(groupKey)) {
            final existing = groupedData[groupKey]!;
            groupedData[groupKey] = {
              'service_transaction': serviceAccountName,
              'main_transaction': mainServiceName,
              'item': itemName,
              'total_count': (existing['total_count'] as int) + qtyNum,
              'total_amount': (existing['total_amount'] as double) + lineTotal,
            };
          } else {
            groupedData[groupKey] = {
              'service_transaction': serviceAccountName,
              'main_transaction': mainServiceName,
              'item': itemName,
              'total_count': qtyNum,
              'total_amount': lineTotal,
            };
          }
        }
      }

      // Use the provided format
      if (format == 'Excel') {
        await _exportToExcel(groupedData, totalAmount, dateRange);
      } else {
        await _exportToCsv(groupedData, totalAmount, dateRange);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  /// Load service names for display in exports
  Future<void> _loadServiceNames() async {
    try {
      await SupabaseService.initialize();

      final response = await SupabaseService.client
          .from('service_accounts')
          .select('id, service_name')
          .eq('is_active', true);

      final serviceMap = <String, String>{};
      for (final service in response) {
        serviceMap[service['id'].toString()] =
            service['service_name'] as String;
      }

      if (mounted) {
        setState(() {
          _serviceNames = serviceMap;
        });
      }
    } catch (e) {
      // ignore: avoid_print
      print('DEBUG ReportsTab: Failed to load service names: $e');
    }
  }

  // Removed old export (non-range) method; using _exportWithRange instead

  String _formatDateTimeForDisplay(String dateTimeStr) {
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      // Convert UTC to local time (assuming UTC+8 for Philippines)
      final localDateTime = dateTime.add(const Duration(hours: 8));

      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];

      final dateStr =
          '${months[localDateTime.month - 1]} ${localDateTime.day}, ${localDateTime.year}';

      // Format time as "9:56 am"
      final hour =
          localDateTime.hour == 0
              ? 12
              : (localDateTime.hour > 12
                  ? localDateTime.hour - 12
                  : localDateTime.hour);
      final minute = localDateTime.minute.toString().padLeft(2, '0');
      final amPm = localDateTime.hour < 12 ? 'am' : 'pm';
      final timeStr = '$hour:$minute $amPm';

      return '$dateStr $timeStr';
    } catch (e) {
      return dateTimeStr; // Return original if parsing fails
    }
  }

  Future<void> _exportWithRange(String format) async {
    try {
      final now = DateTime.now();
      final initialRange =
          _dateRange ??
          DateTimeRange(start: now.subtract(const Duration(days: 6)), end: now);

      // Show date selection dialog
      await _showDateSelectionDialog(initialRange, format);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _exportToCsv(
    Map<String, Map<String, dynamic>> groupedData,
    double totalAmount,
    DateTimeRange dateRange,
  ) async {
    try {
      // Build CSV headers and rows
      final headers = [
        'Service Transaction',
        'Main Transaction',
        'Item',
        'Total Count',
        'Total Amount',
      ];
      final rows = <List<String>>[];

      // Add grouped data rows
      for (final entry in groupedData.entries) {
        final data = entry.value;
        rows.add([
          data['service_transaction'] as String,
          data['main_transaction'] as String,
          data['item'] as String,
          (data['total_count'] as int).toString(),
          (data['total_amount'] as double).toStringAsFixed(2),
        ]);
      }

      // Add summary row
      if (groupedData.isNotEmpty) {
        rows.add(['', '', '', '', '']);
        rows.add(['TOTAL', '', '', '', totalAmount.toStringAsFixed(2)]);
      }

      final csv = StringBuffer();
      csv.writeln(headers.join(','));
      for (final r in rows) {
        csv.writeln(r.map((c) => '"${c.replaceAll('"', '""')}"').join(','));
      }
      final bytes = utf8.encode(csv.toString());

      // Auto-save to downloads folder
      String defaultFileName =
          'service_transactions_${dateRange.start.year}-${dateRange.start.month.toString().padLeft(2, '0')}-${dateRange.start.day.toString().padLeft(2, '0')}_to_${dateRange.end.year}-${dateRange.end.month.toString().padLeft(2, '0')}-${dateRange.end.day.toString().padLeft(2, '0')}.csv';

      try {
        // Get downloads directory
        Directory? downloadsDir;
        if (Platform.isAndroid) {
          downloadsDir = Directory('/storage/emulated/0/Download');
          if (!await downloadsDir.exists()) {
            downloadsDir = await getExternalStorageDirectory();
          }
        } else if (Platform.isIOS) {
          downloadsDir = await getApplicationDocumentsDirectory();
        } else {
          // For desktop platforms
          downloadsDir = await getDownloadsDirectory();
        }

        if (downloadsDir != null) {
          final file = File('${downloadsDir.path}/$defaultFileName');
          await file.writeAsBytes(bytes, flush: true);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('CSV saved to: ${file.path}'),
              duration: Duration(seconds: 4),
              action: SnackBarAction(
                label: 'Open',
                onPressed: () {
                  // Try to open the file location
                  if (Platform.isWindows) {
                    Process.run('explorer', ['/select,', file.path]);
                  } else if (Platform.isMacOS) {
                    Process.run('open', ['-R', file.path]);
                  } else if (Platform.isLinux) {
                    Process.run('xdg-open', [downloadsDir!.path]);
                  }
                },
              ),
            ),
          );
          return;
        }
      } catch (saveErr) {
        // ignore: avoid_print
        print('DEBUG: Auto-save failed: $saveErr');
      }

      // Fallback: Try file picker
      String? outputPath;
      try {
        outputPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save CSV report',
          fileName: defaultFileName,
          type: FileType.custom,
          allowedExtensions: ['csv'],
        );
      } catch (_) {
        outputPath = null;
      }

      if (outputPath != null && outputPath.trim().isNotEmpty) {
        try {
          final file = File(outputPath);
          await file.writeAsBytes(bytes, flush: true);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('CSV saved to: ${file.path}')));
          return;
        } catch (writeErr) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to save: $writeErr')));
        }
      }

      // Final fallback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save CSV file. Please try again.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('CSV export failed: $e')));
    }
  }

  Future<void> _exportToExcel(
    Map<String, Map<String, dynamic>> groupedData,
    double totalAmount,
    DateTimeRange dateRange,
  ) async {
    try {
      // Create Excel workbook
      final excelWorkbook = excel.Excel.createExcel();
      final sheet = excelWorkbook['Service Transactions'];

      // Set headers
      final headers = [
        'Service Transaction',
        'Main Transaction',
        'Item',
        'Total Count',
        'Total Amount',
      ];
      for (int i = 0; i < headers.length; i++) {
        sheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
            .value = excel.TextCellValue(headers[i]);
      }

      // Add data rows
      int rowIndex = 1;
      for (final entry in groupedData.entries) {
        final data = entry.value;
        sheet
            .cell(
              excel.CellIndex.indexByColumnRow(
                columnIndex: 0,
                rowIndex: rowIndex,
              ),
            )
            .value = excel.TextCellValue(data['service_transaction'] as String);
        sheet
            .cell(
              excel.CellIndex.indexByColumnRow(
                columnIndex: 1,
                rowIndex: rowIndex,
              ),
            )
            .value = excel.TextCellValue(data['main_transaction'] as String);
        sheet
            .cell(
              excel.CellIndex.indexByColumnRow(
                columnIndex: 2,
                rowIndex: rowIndex,
              ),
            )
            .value = excel.TextCellValue(data['item'] as String);
        sheet
            .cell(
              excel.CellIndex.indexByColumnRow(
                columnIndex: 3,
                rowIndex: rowIndex,
              ),
            )
            .value = excel.IntCellValue(data['total_count'] as int);
        sheet
            .cell(
              excel.CellIndex.indexByColumnRow(
                columnIndex: 4,
                rowIndex: rowIndex,
              ),
            )
            .value = excel.DoubleCellValue(data['total_amount'] as double);
        rowIndex++;
      }

      // Add total row
      if (groupedData.isNotEmpty) {
        rowIndex++;
        sheet
            .cell(
              excel.CellIndex.indexByColumnRow(
                columnIndex: 0,
                rowIndex: rowIndex,
              ),
            )
            .value = excel.TextCellValue('TOTAL');
        sheet
            .cell(
              excel.CellIndex.indexByColumnRow(
                columnIndex: 4,
                rowIndex: rowIndex,
              ),
            )
            .value = excel.DoubleCellValue(totalAmount);
      }

      // Save Excel file
      final bytes = excelWorkbook.encode();
      if (bytes == null) {
        throw Exception('Failed to encode Excel file');
      }

      String defaultFileName =
          'service_transactions_${dateRange.start.year}-${dateRange.start.month.toString().padLeft(2, '0')}-${dateRange.start.day.toString().padLeft(2, '0')}_to_${dateRange.end.year}-${dateRange.end.month.toString().padLeft(2, '0')}-${dateRange.end.day.toString().padLeft(2, '0')}.xlsx';

      try {
        // Get downloads directory
        Directory? downloadsDir;
        if (Platform.isAndroid) {
          downloadsDir = Directory('/storage/emulated/0/Download');
          if (!await downloadsDir.exists()) {
            downloadsDir = await getExternalStorageDirectory();
          }
        } else if (Platform.isIOS) {
          downloadsDir = await getApplicationDocumentsDirectory();
        } else {
          // For desktop platforms
          downloadsDir = await getDownloadsDirectory();
        }

        if (downloadsDir != null) {
          final file = File('${downloadsDir.path}/$defaultFileName');
          await file.writeAsBytes(bytes, flush: true);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Excel saved to: ${file.path}'),
              duration: Duration(seconds: 4),
              action: SnackBarAction(
                label: 'Open',
                onPressed: () {
                  // Try to open the file location
                  if (Platform.isWindows) {
                    Process.run('explorer', ['/select,', file.path]);
                  } else if (Platform.isMacOS) {
                    Process.run('open', ['-R', file.path]);
                  } else if (Platform.isLinux) {
                    Process.run('xdg-open', [downloadsDir!.path]);
                  }
                },
              ),
            ),
          );
          return;
        }
      } catch (saveErr) {
        // ignore: avoid_print
        print('DEBUG: Auto-save failed: $saveErr');
      }

      // Fallback: Try file picker
      String? outputPath;
      try {
        outputPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Excel report',
          fileName: defaultFileName,
          type: FileType.custom,
          allowedExtensions: ['xlsx'],
        );
      } catch (_) {
        outputPath = null;
      }

      if (outputPath != null && outputPath.trim().isNotEmpty) {
        try {
          final file = File(outputPath);
          await file.writeAsBytes(bytes, flush: true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Excel saved to: ${file.path}')),
          );
          return;
        } catch (writeErr) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to save: $writeErr')));
        }
      }

      // Final fallback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save Excel file. Please try again.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Excel export failed: $e')));
    }
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
