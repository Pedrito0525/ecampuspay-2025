import 'package:flutter/material.dart';
import '../services/session_service.dart';
import '../services/supabase_service.dart';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';

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
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      onPressed: _exportCsvWithRange,
                      icon: Icon(
                        Icons.table_chart,
                        color: Colors.white,
                        size: isWeb ? 28 : 24,
                      ),
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
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _itemAggregates.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final entry = _itemAggregates.entries.elementAt(index);
                        final name = entry.key;
                        final qty = entry.value['quantity'] as int;
                        final total = (entry.value['total'] as double);
                        return ListTile(
                          dense: true,
                          title: Text(name),
                          trailing: Text(
                            '${qty} • ₱${total.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        );
                      },
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
                        onPressed: _exportCsvWithRange,
                        icon: const Icon(Icons.table_chart),
                        label: const Text('Export CSV'),
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
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _transactions.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final t = _transactions[index];
                        final createdAtStr = t['created_at']?.toString() ?? '';
                        final localDateTime = _formatDateTimeForDisplay(
                          createdAtStr,
                        );
                        return ListTile(
                          dense: true,
                          title: Text(
                            '$localDateTime  •  ₱${(t['total_amount'] as num).toDouble().toStringAsFixed(2)}',
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

      final localStart = DateTime(
        range.start.year,
        range.start.month,
        range.start.day,
      );
      final localEnd = DateTime(
        range.end.year,
        range.end.month,
        range.end.day,
      ).add(const Duration(days: 1));
      final from = localStart.toUtc().toIso8601String();
      final to = localEnd.toUtc().toIso8601String();

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
        'DEBUG ReportsTab: period=$_selectedPeriod, localStart=$localStart, localEnd=$localEnd',
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

  // Removed old export (non-range) method; using _exportCsvWithRange instead

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

  String _formatDateTimeForCsv(String dateTimeStr) {
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      // Convert UTC to local time (assuming UTC+8 for Philippines)
      final localDateTime = dateTime.add(const Duration(hours: 8));

      // Format for CSV: YYYY-MM-DD HH:MM:SS
      final year = localDateTime.year;
      final month = localDateTime.month.toString().padLeft(2, '0');
      final day = localDateTime.day.toString().padLeft(2, '0');
      final hour = localDateTime.hour.toString().padLeft(2, '0');
      final minute = localDateTime.minute.toString().padLeft(2, '0');
      final second = localDateTime.second.toString().padLeft(2, '0');

      return '$year-$month-$day $hour:$minute:$second';
    } catch (e) {
      return dateTimeStr; // Return original if parsing fails
    }
  }

  Future<void> _exportCsvWithRange() async {
    try {
      final now = DateTime.now();
      final initialRange =
          _dateRange ??
          DateTimeRange(start: now.subtract(const Duration(days: 6)), end: now);
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(now.year - 3),
        lastDate: DateTime(now.year + 1),
        initialDateRange: initialRange,
      );
      if (picked == null) return;

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
      final localStart = DateTime(
        picked.start.year,
        picked.start.month,
        picked.start.day,
      );
      final localEndNext = DateTime(
        picked.end.year,
        picked.end.month,
        picked.end.day,
      ).add(const Duration(days: 1));
      final from = localStart.toUtc().toIso8601String();
      final to = localEndNext.toUtc().toIso8601String();
      // ignore: avoid_print
      print(
        'DEBUG ReportsTab(export): localStart=$localStart localEndNext=$localEndNext -> UTC from=$from to=$to',
      );

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

      final tx =
          (res as List)
              .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
              .toList();

      // Build CSV rows from fetched data
      final headers = ['Date', 'Item', 'Quantity', 'Price', 'Line Total'];
      final rows = <List<String>>[];
      final itemAgg = <String, Map<String, dynamic>>{};
      double totalAmount = 0.0;
      for (final t in tx) {
        totalAmount += (t['total_amount'] as num).toDouble();
        final created = t['created_at']?.toString() ?? '';
        final localDateTime = _formatDateTimeForCsv(created);
        final items =
            (t['items'] as List)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
        for (final it in items) {
          final name = (it['name'] ?? '').toString();
          final qtyNum = (it['quantity'] as num?)?.toInt() ?? 1;
          final priceNum = (it['price'] as num?)?.toDouble() ?? 0.0;
          final lineNum =
              (it['total'] as num?)?.toDouble() ?? priceNum * qtyNum;
          rows.add([
            localDateTime,
            name,
            qtyNum.toString(),
            priceNum.toStringAsFixed(2),
            lineNum.toStringAsFixed(2),
          ]);
          final prev = itemAgg[name];
          if (prev == null) {
            itemAgg[name] = {'quantity': qtyNum, 'total': lineNum};
          } else {
            itemAgg[name] = {
              'quantity': (prev['quantity'] as int) + qtyNum,
              'total': (prev['total'] as double) + lineNum,
            };
          }
        }
      }

      // Append summary
      if (itemAgg.isNotEmpty) {
        rows.add(['', '', '', '', '']);
        rows.add(['Item', 'Total Qty', 'Total Amount', '', '']);
        for (final e in itemAgg.entries) {
          rows.add([
            e.key,
            (e.value['quantity'] as int).toString(),
            (e.value['total'] as double).toStringAsFixed(2),
            '',
            '',
          ]);
        }
        rows.add(['', '', '', '', '']);
        rows.add(['Overall Total', '', totalAmount.toStringAsFixed(2), '', '']);
      }

      final csv = StringBuffer();
      csv.writeln(headers.join(','));
      for (final r in rows) {
        csv.writeln(r.map((c) => '"${c.replaceAll('"', '""')}"').join(','));
      }
      final bytes = utf8.encode(csv.toString());

      // Try interactive save
      String defaultFileName =
          'service_transactions_${picked.start.year}-${picked.start.month.toString().padLeft(2, '0')}-${picked.start.day.toString().padLeft(2, '0')}_to_${picked.end.year}-${picked.end.month.toString().padLeft(2, '0')}-${picked.end.day.toString().padLeft(2, '0')}.csv';
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Saved CSV: ${file.path} (${bytes.length} bytes)'),
            ),
          );
          return;
        } catch (writeErr) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to save: $writeErr')));
        }
      }

      // Fallback if no path chosen
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'CSV generated (${bytes.length} bytes). Implement saving/sharing.',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('CSV export failed: $e')));
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
