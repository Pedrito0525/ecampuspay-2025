import 'dart:io';
import 'package:excel/excel.dart' as excel;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../services/supabase_service.dart';

class ReportsTab extends StatefulWidget {
  const ReportsTab({super.key});

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  static const Color evsuRed = Color(0xFFB01212);
  String _selectedPeriod = 'Daily';
  final List<String> _periods = ['Daily', 'Weekly', 'Monthly', 'Yearly'];

  bool _loading = false;
  double _topUpIncome = 0.0;
  double _loanIncome = 0.0;
  double _totalIncome = 0.0;
  int _topupCount = 0;
  int _loanDisbursementCount = 0;
  double _manualTopUpTotal = 0.0;
  double _gcashTopUpTotal = 0.0;
  int _manualTopUpCount = 0;
  int _gcashTopUpCount = 0;

  // Balance overview data
  double _totalStudentBalance = 0.0;
  double _totalServiceBalance = 0.0;
  double _totalSystemBalance = 0.0;
  int _studentCount = 0;
  int _serviceCount = 0;
  bool _balanceLoading = false;

  // Analysis data
  List<Map<String, dynamic>> _topupAnalysis = [];
  List<Map<String, dynamic>> _loanAnalysis = [];
  List<Map<String, dynamic>> _vendorTransactionCount = [];
  bool _analysisLoading = false;
  bool _exportingExcel = false;

  @override
  void initState() {
    super.initState();
    _loadIncome();
    _loadBalanceOverview();
    _loadAnalysisData();
  }

  Future<void> _loadIncome() async {
    setState(() => _loading = true);
    try {
      final range = _getDateRangeFor(_selectedPeriod);

      double topUpIncome = _topUpIncome;
      double loanIncome = _loanIncome;
      double totalIncome = _totalIncome;
      int topupCount = _topupCount;
      int loanDisbursementCount = _loanDisbursementCount;
      double manualTopUpTotal = _manualTopUpTotal;
      double gcashTopUpTotal = _gcashTopUpTotal;
      int manualTopUpCount = _manualTopUpCount;
      int gcashTopUpCount = _gcashTopUpCount;

      final incomeResult = await SupabaseService.getIncomeSummary(
        start: range['start'],
        end: range['end'],
      );
      if (incomeResult['success'] == true) {
        final data = incomeResult['data'] as Map<String, dynamic>;
        topUpIncome = (data['top_up_income'] as num?)?.toDouble() ?? 0.0;
        loanIncome = (data['loan_income'] as num?)?.toDouble() ?? 0.0;
        totalIncome = (data['total_income'] as num?)?.toDouble() ?? 0.0;
        final counts = data['counts'] as Map<String, dynamic>?;
        topupCount = counts != null ? (counts['topups'] as int? ?? 0) : 0;
        loanDisbursementCount =
            counts != null ? (counts['paid_loans'] as int? ?? 0) : 0;
      }

      final channelResult = await SupabaseService.getTopUpChannelTotals(
        start: range['start'],
        end: range['end'],
      );
      if (channelResult['success'] == true) {
        final channelData = channelResult['data'] as Map<String, dynamic>;
        manualTopUpTotal =
            (channelData['manual_total'] as num?)?.toDouble() ?? 0.0;
        manualTopUpCount = channelData['manual_count'] as int? ?? 0;
        gcashTopUpTotal =
            (channelData['gcash_total'] as num?)?.toDouble() ?? 0.0;
        gcashTopUpCount = channelData['gcash_count'] as int? ?? 0;
      }

      if (mounted) {
        setState(() {
          _topUpIncome = topUpIncome;
          _loanIncome = loanIncome;
          _totalIncome = totalIncome;
          _topupCount = topupCount;
          _loanDisbursementCount = loanDisbursementCount;
          _manualTopUpTotal = manualTopUpTotal;
          _manualTopUpCount = manualTopUpCount;
          _gcashTopUpTotal = gcashTopUpTotal;
          _gcashTopUpCount = gcashTopUpCount;
        });
      }
    } catch (_) {
      // no-op UI fallback
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadBalanceOverview() async {
    setState(() => _balanceLoading = true);
    try {
      final res = await SupabaseService.getBalanceOverview();
      if (res['success'] == true) {
        final data = res['data'] as Map<String, dynamic>;
        setState(() {
          _totalStudentBalance =
              (data['total_student_balance'] as num?)?.toDouble() ?? 0.0;
          _totalServiceBalance =
              (data['total_service_balance'] as num?)?.toDouble() ?? 0.0;
          _totalSystemBalance =
              (data['total_system_balance'] as num?)?.toDouble() ?? 0.0;
          _studentCount = data['student_count'] as int? ?? 0;
          _serviceCount = data['service_count'] as int? ?? 0;
        });
      }
    } catch (_) {
      // no-op UI fallback
    } finally {
      if (mounted) setState(() => _balanceLoading = false);
    }
  }

  Future<void> _loadAnalysisData() async {
    setState(() => _analysisLoading = true);
    try {
      final range = _getDateRangeFor(_selectedPeriod);

      // Load all analysis data in parallel
      final results = await Future.wait([
        SupabaseService.getTopUpAnalysis(
          start: range['start'],
          end: range['end'],
        ),
        SupabaseService.getLoanAnalysis(
          start: range['start'],
          end: range['end'],
        ),
        SupabaseService.getVendorTransactionCountAnalysis(
          start: range['start'],
          end: range['end'],
        ),
      ]);

      if (mounted) {
        setState(() {
          // Top-up analysis
          if (results[0]['success'] == true) {
            _topupAnalysis =
                (results[0]['data']['topups'] as List<dynamic>?)
                    ?.cast<Map<String, dynamic>>() ??
                [];
          }

          // Loan analysis
          if (results[1]['success'] == true) {
            _loanAnalysis =
                (results[1]['data']['loans'] as List<dynamic>?)
                    ?.cast<Map<String, dynamic>>() ??
                [];
          }

          // Vendor transaction count analysis
          if (results[2]['success'] == true) {
            _vendorTransactionCount =
                (results[2]['data']['vendors'] as List<dynamic>?)
                    ?.cast<Map<String, dynamic>>() ??
                [];
          }
        });
      }
    } catch (_) {
      // no-op UI fallback
    } finally {
      if (mounted) setState(() => _analysisLoading = false);
    }
  }

  Map<String, DateTime?> _getDateRangeFor(String period) {
    final now = DateTime.now();
    switch (period) {
      case 'Daily':
        final start = DateTime(now.year, now.month, now.day);
        final end = start.add(const Duration(days: 1));
        return {'start': start, 'end': end};
      case 'Weekly':
        final start = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: now.weekday - 1));
        final end = start.add(const Duration(days: 7));
        return {'start': start, 'end': end};
      case 'Monthly':
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month + 1, 1);
        return {'start': start, 'end': end};
      case 'Yearly':
        final start = DateTime(now.year, 1, 1);
        final end = DateTime(now.year + 1, 1, 1);
        return {'start': start, 'end': end};
      default:
        return {'start': null, 'end': null};
    }
  }

  String _formatCurrency(double value) {
    return '₱${value.toStringAsFixed(2)}';
  }

  String _formatDateForExport(DateTime dateTime) {
    final local = dateTime.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '$year-$month-$day $hour:$minute';
  }

  void _showSnackBarMessage(
    String message, {
    Color backgroundColor = evsuRed,
    SnackBarAction? action,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        action: action,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reports & Analytics',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: evsuRed,
                        ),
                      ),
                      Text(
                        'System performance overview',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                _exportingExcel
                    ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          evsuRed,
                        ),
                      ),
                    )
                    : IconButton(
                      onPressed: _exportReports,
                      icon: const Icon(Icons.file_download, color: evsuRed),
                    ),
              ],
            ),
            const SizedBox(height: 24),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            if (_loading) const SizedBox(height: 16),

            // Period Selector
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children:
                    _periods
                        .map(
                          (period) => Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _selectedPeriod = period);
                                _loadIncome();
                                _loadAnalysisData();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      _selectedPeriod == period
                                          ? evsuRed
                                          : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
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
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
              ),
            ),
            const SizedBox(height: 24),

            // Key Metrics
            Container(
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
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_selectedPeriod Overview',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: evsuRed,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Total Income (Full Width)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: evsuRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: evsuRed.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Total Income',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: evsuRed,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatCurrency(_totalIncome),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: evsuRed,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Top-up and Loan Disbursement Overview
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 600;

                      if (isMobile) {
                        // Mobile: Stack vertically
                        return Column(
                          children: [
                            _IncomeMetricItem(
                              title: 'Top-up Income',
                              value: _formatCurrency(_topUpIncome),
                              count: _topupCount,
                              countLabel: 'Top-ups',
                              color: Colors.blue,
                              icon: Icons.account_balance_wallet,
                            ),
                            const SizedBox(height: 12),
                            _IncomeMetricItem(
                              title: 'Loan Income',
                              value: _formatCurrency(_loanIncome),
                              count: _loanDisbursementCount,
                              countLabel: 'Loan Disbursements',
                              color: Colors.green,
                              icon: Icons.credit_card,
                            ),
                            const SizedBox(height: 12),
                            _TopUpChannelBreakdown(
                              manualTotal: _formatCurrency(_manualTopUpTotal),
                              manualCount: _manualTopUpCount,
                              gcashTotal: _formatCurrency(_gcashTopUpTotal),
                              gcashCount: _gcashTopUpCount,
                            ),
                          ],
                        );
                      } else {
                        // Desktop: Side by side
                        return Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _IncomeMetricItem(
                                    title: 'Top-up Income',
                                    value: _formatCurrency(_topUpIncome),
                                    count: _topupCount,
                                    countLabel: 'Top-ups',
                                    color: Colors.blue,
                                    icon: Icons.account_balance_wallet,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _IncomeMetricItem(
                                    title: 'Loan Income',
                                    value: _formatCurrency(_loanIncome),
                                    count: _loanDisbursementCount,
                                    countLabel: 'Loan Disbursements',
                                    color: Colors.green,
                                    icon: Icons.credit_card,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _TopUpChannelBreakdown(
                              manualTotal: _formatCurrency(_manualTopUpTotal),
                              manualCount: _manualTopUpCount,
                              gcashTotal: _formatCurrency(_gcashTopUpTotal),
                              gcashCount: _gcashTopUpCount,
                            ),
                          ],
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Balance Overview Section
            Container(
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
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.account_balance_wallet, color: evsuRed),
                      const SizedBox(width: 8),
                      const Text(
                        'Balance Overview',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: evsuRed,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: _loadBalanceOverview,
                        icon: const Icon(Icons.refresh, color: evsuRed),
                        tooltip: 'Refresh balance data',
                      ),
                      if (_balanceLoading)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Track your actual cash flow - money you handle should equal total balances',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Total System Balance
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: evsuRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: evsuRed.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.money, color: evsuRed, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Total System Balance',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: evsuRed,
                                ),
                              ),
                              Text(
                                _formatCurrency(_totalSystemBalance),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: evsuRed,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '₱${_totalSystemBalance.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: evsuRed,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Balance Breakdown
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 600;

                      if (isMobile) {
                        // Mobile: Stack vertically
                        return Column(
                          children: [
                            _BalanceItem(
                              title: 'Student Balances',
                              value: _formatCurrency(_totalStudentBalance),
                              count: _studentCount,
                              color: Colors.blue,
                              icon: Icons.school,
                            ),
                            const SizedBox(height: 12),
                            _BalanceItem(
                              title: 'Service Balances',
                              value: _formatCurrency(_totalServiceBalance),
                              count: _serviceCount,
                              color: Colors.green,
                              icon: Icons.store,
                            ),
                          ],
                        );
                      } else {
                        // Desktop: Side by side
                        return Row(
                          children: [
                            Expanded(
                              child: _BalanceItem(
                                title: 'Student Balances',
                                value: _formatCurrency(_totalStudentBalance),
                                count: _studentCount,
                                color: Colors.blue,
                                icon: Icons.school,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _BalanceItem(
                                title: 'Service Balances',
                                value: _formatCurrency(_totalServiceBalance),
                                count: _serviceCount,
                                color: Colors.green,
                                icon: Icons.store,
                              ),
                            ),
                          ],
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Balance Verification
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          _totalSystemBalance ==
                                  (_totalStudentBalance + _totalServiceBalance)
                              ? Colors.green.withOpacity(0.1)
                              : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            _totalSystemBalance ==
                                    (_totalStudentBalance +
                                        _totalServiceBalance)
                                ? Colors.green.withOpacity(0.3)
                                : Colors.orange.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _totalSystemBalance ==
                                  (_totalStudentBalance + _totalServiceBalance)
                              ? Icons.check_circle
                              : Icons.warning,
                          color:
                              _totalSystemBalance ==
                                      (_totalStudentBalance +
                                          _totalServiceBalance)
                                  ? Colors.green
                                  : Colors.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _totalSystemBalance ==
                                    (_totalStudentBalance +
                                        _totalServiceBalance)
                                ? 'Balance verification: ✓ All balances match'
                                : 'Balance verification: ⚠ Balances do not match',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color:
                                  _totalSystemBalance ==
                                          (_totalStudentBalance +
                                              _totalServiceBalance)
                                      ? Colors.green.shade700
                                      : Colors.orange.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Top-up Analysis
            Container(
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
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Top-up Analysis',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: evsuRed,
                        ),
                      ),
                      const Spacer(),
                      if (_analysisLoading)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_topupAnalysis.isEmpty && !_analysisLoading)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.account_balance_wallet,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No top-up data available',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Top-up transactions will appear here',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _topupAnalysis.length,
                      itemBuilder: (context, index) {
                        final item = _topupAnalysis[index];
                        return _TopUpItem(
                          amount: _formatCurrency(item['amount'] as double),
                          count: item['count'] as int,
                          percentage: item['percentage'] as double,
                        );
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Loan Analysis
            Container(
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
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Loan Analysis',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: evsuRed,
                        ),
                      ),
                      const Spacer(),
                      if (_analysisLoading)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_loanAnalysis.isEmpty && !_analysisLoading)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.credit_card,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No loan data available',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Paid loan transactions will appear here',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _loanAnalysis.length,
                      itemBuilder: (context, index) {
                        final item = _loanAnalysis[index];
                        return _LoanItem(
                          amount: _formatCurrency(item['amount'] as double),
                          count: item['count'] as int,
                          percentage: item['percentage'] as double,
                        );
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Vendor Transaction Count Analysis
            Container(
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
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Vendor Transaction Count Analysis',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: evsuRed,
                          ),
                        ),
                      ),
                      if (_analysisLoading)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Which vendors have the most transaction activity',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_vendorTransactionCount.isEmpty && !_analysisLoading)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.analytics,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No transaction data available',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Transaction count analysis will appear here',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _vendorTransactionCount.length,
                      itemBuilder: (context, index) {
                        final vendor = _vendorTransactionCount[index];
                        return _VendorTransactionCountItem(
                          name: vendor['service_name'] as String,
                          totalTransactions:
                              vendor['total_transactions'] as int,
                          rank: index + 1,
                        );
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Export Options
            Container(
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
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Export Reports',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: evsuRed,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _ExportButton(
                          title: 'PDF Report',
                          icon: Icons.picture_as_pdf,
                          onTap: () => _exportAs('PDF'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ExportButton(
                          title: 'Excel Export',
                          icon: Icons.table_chart,
                          onTap: () => _exportAs('Excel'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 100), // Space for bottom nav
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

  Future<void> _exportAs(String format) async {
    if (format == 'Excel') {
      await _exportSummaryAsExcel();
      return;
    }

    _showSnackBarMessage('Exporting $_selectedPeriod report as $format...');
  }

  Future<void> _exportSummaryAsExcel() async {
    if (_exportingExcel) {
      _showSnackBarMessage('An export is already in progress. Please wait...');
      return;
    }

    if (mounted) {
      setState(() => _exportingExcel = true);
    }

    try {
      final balanceResult = await SupabaseService.getBalanceOverview();
      if (balanceResult['success'] != true) {
        throw Exception(
          balanceResult['message'] ?? 'Failed to fetch balance overview',
        );
      }

      final channelResult = await SupabaseService.getTopUpChannelTotals(
        start: null,
        end: null,
      );
      if (channelResult['success'] != true) {
        throw Exception(
          channelResult['message'] ?? 'Failed to fetch top-up totals',
        );
      }

      final balanceData =
          (balanceResult['data'] as Map<String, dynamic>?) ??
          <String, dynamic>{};
      final channelData =
          (channelResult['data'] as Map<String, dynamic>?) ??
          <String, dynamic>{};

      final double totalStudentBalance =
          (balanceData['total_student_balance'] as num?)?.toDouble() ?? 0.0;
      final double totalServiceBalance =
          (balanceData['total_service_balance'] as num?)?.toDouble() ?? 0.0;
      final double totalSystemBalance =
          (balanceData['total_system_balance'] as num?)?.toDouble() ??
          (totalStudentBalance + totalServiceBalance);
      final double manualTopUpTotal =
          (channelData['manual_total'] as num?)?.toDouble() ?? 0.0;
      final double gcashTopUpTotal =
          (channelData['gcash_total'] as num?)?.toDouble() ?? 0.0;
      final double totalTopUps = manualTopUpTotal + gcashTopUpTotal;

      final excel.Excel workbook = excel.Excel.createExcel();
      const String sheetName = 'Summary';
      final excel.Sheet sheet = workbook[sheetName];
      workbook.setDefaultSheet(sheetName);

      final DateTime now = DateTime.now();

      int rowIndex = 0;
      // Title row - make it bigger by merging cells
      final titleCell = sheet.cell(
        excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
      );
      titleCell.value = excel.TextCellValue('Overall Balance Reports');
      // Merge title across 2 columns for bigger appearance
      sheet.merge(
        excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
        excel.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex),
      );
      rowIndex++;
      rowIndex++;
      sheet
          .cell(
            excel.CellIndex.indexByColumnRow(
              columnIndex: 0,
              rowIndex: rowIndex,
            ),
          )
          .value = excel.TextCellValue('Generated At');
      sheet
          .cell(
            excel.CellIndex.indexByColumnRow(
              columnIndex: 1,
              rowIndex: rowIndex,
            ),
          )
          .value = excel.TextCellValue(_formatDateForExport(now));

      rowIndex += 2;
      sheet
          .cell(
            excel.CellIndex.indexByColumnRow(
              columnIndex: 0,
              rowIndex: rowIndex,
            ),
          )
          .value = excel.TextCellValue('Metric');
      sheet
          .cell(
            excel.CellIndex.indexByColumnRow(
              columnIndex: 1,
              rowIndex: rowIndex,
            ),
          )
          .value = excel.TextCellValue('Amount (PHP)');
      rowIndex++;

      void writeMetric(String label, double value) {
        sheet
            .cell(
              excel.CellIndex.indexByColumnRow(
                columnIndex: 0,
                rowIndex: rowIndex,
              ),
            )
            .value = excel.TextCellValue(label);
        sheet
            .cell(
              excel.CellIndex.indexByColumnRow(
                columnIndex: 1,
                rowIndex: rowIndex,
              ),
            )
            .value = excel.DoubleCellValue(
          double.parse(value.toStringAsFixed(2)),
        );
        rowIndex++;
      }

      writeMetric('Total Student Balance', totalStudentBalance);
      writeMetric('Total Service Balance', totalServiceBalance);
      writeMetric('Total System Balance', totalSystemBalance);
      writeMetric('Manual Top-up Total', manualTopUpTotal);
      writeMetric('GCash Top-up Total', gcashTopUpTotal);
      writeMetric('Overall Top-up Total', totalTopUps);

      final List<int>? bytes = workbook.encode();
      if (bytes == null) {
        throw Exception('Failed to generate Excel file data');
      }

      final String timestampSuffix =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final String defaultFileName =
          'overall_balance_reports_$timestampSuffix.xlsx';

      Directory? downloadsDir;
      try {
        if (Platform.isAndroid) {
          downloadsDir = Directory('/storage/emulated/0/Download');
          if (!await downloadsDir.exists()) {
            downloadsDir = await getExternalStorageDirectory();
          }
        } else if (Platform.isIOS) {
          downloadsDir = await getApplicationDocumentsDirectory();
        } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
          downloadsDir = await getDownloadsDirectory();
        }
      } catch (_) {
        downloadsDir = null;
      }

      bool saved = false;
      String? savedPath;

      if (downloadsDir != null) {
        try {
          final file = File('${downloadsDir.path}/$defaultFileName');
          await file.writeAsBytes(bytes, flush: true);
          saved = true;
          savedPath = file.path;
        } catch (_) {
          saved = false;
          savedPath = null;
        }
      }

      if (!saved) {
        try {
          final outputPath = await FilePicker.platform.saveFile(
            dialogTitle: 'Save Excel report',
            fileName: defaultFileName,
            type: FileType.custom,
            allowedExtensions: ['xlsx'],
          );

          if (outputPath != null && outputPath.trim().isNotEmpty) {
            final file = File(outputPath);
            await file.writeAsBytes(bytes, flush: true);
            saved = true;
            savedPath = file.path;
          }
        } catch (_) {
          saved = false;
          savedPath = null;
        }
      }

      if (!saved) {
        throw Exception('Unable to save Excel file. Please try again.');
      }

      SnackBarAction? action;
      if (savedPath != null && savedPath.isNotEmpty) {
        final String resolvedPath = savedPath;
        if (Platform.isWindows) {
          action = SnackBarAction(
            label: 'Open',
            onPressed: () {
              try {
                Process.run('explorer', ['/select,', resolvedPath]);
              } catch (_) {}
            },
          );
        } else if (Platform.isMacOS) {
          action = SnackBarAction(
            label: 'Open',
            onPressed: () {
              try {
                Process.run('open', ['-R', resolvedPath]);
              } catch (_) {}
            },
          );
        } else if (Platform.isLinux) {
          action = SnackBarAction(
            label: 'Open',
            onPressed: () {
              try {
                final directoryPath = File(resolvedPath).parent.path;
                Process.run('xdg-open', [directoryPath]);
              } catch (_) {}
            },
          );
        }
      }

      _showSnackBarMessage(
        'Excel summary exported to ${savedPath ?? 'selected location'}.',
        action: action,
      );
    } catch (e) {
      _showSnackBarMessage(
        'Excel export failed: $e',
        backgroundColor: Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() => _exportingExcel = false);
      }
    }
  }

  void _emailReport() {
    _showSnackBarMessage('Preparing email report...');
  }
}

class _TopUpItem extends StatelessWidget {
  static const Color evsuRed = Color(0xFFB01212);
  final String amount;
  final int count;
  final double percentage;

  const _TopUpItem({
    required this.amount,
    required this.count,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: evsuRed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                amount,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: evsuRed,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count transactions',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  height: 4,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: percentage / 100,
                    child: Container(
                      decoration: BoxDecoration(
                        color: _TopUpItem.evsuRed,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${percentage.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoanItem extends StatelessWidget {
  final String amount;
  final int count;
  final double percentage;

  const _LoanItem({
    required this.amount,
    required this.count,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                amount,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count loans',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  height: 4,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: percentage / 100,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${percentage.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _IncomeMetricItem extends StatelessWidget {
  final String title;
  final String value;
  final int count;
  final String countLabel;
  final Color color;
  final IconData icon;

  const _IncomeMetricItem({
    required this.title,
    required this.value,
    required this.count,
    required this.countLabel,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.trending_up, color: color.withOpacity(0.7), size: 16),
              const SizedBox(width: 4),
              Text(
                '$count $countLabel',
                style: TextStyle(
                  fontSize: 12,
                  color: color.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TopUpChannelBreakdown extends StatelessWidget {
  final String manualTotal;
  final int manualCount;
  final String gcashTotal;
  final int gcashCount;

  const _TopUpChannelBreakdown({
    required this.manualTotal,
    required this.manualCount,
    required this.gcashTotal,
    required this.gcashCount,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 600;
    final isTablet = screenSize.width >= 600 && screenSize.width < 1024;

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.payments,
                color: _TopUpItem.evsuRed,
                size: isMobile ? 18 : 20,
              ),
              SizedBox(width: isMobile ? 6 : 8),
              Text(
                'Top-up Channels',
                style: TextStyle(
                  fontSize: isMobile ? 13 : 14,
                  fontWeight: FontWeight.w700,
                  color: _TopUpItem.evsuRed,
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 12 : 16),
          LayoutBuilder(
            builder: (context, constraints) {
              if (isMobile) {
                // Mobile: Stack vertically
                return Column(
                  children: [
                    _TopUpChannelTile(
                      label: 'Cash Desk',
                      total: manualTotal,
                      count: manualCount,
                      color: Colors.blue,
                      icon: Icons.attach_money,
                      isMobile: true,
                    ),
                    SizedBox(height: isMobile ? 10 : 12),
                    _TopUpChannelTile(
                      label: 'GCash Verified',
                      total: gcashTotal,
                      count: gcashCount,
                      color: Colors.deepPurple,
                      icon: Icons.qr_code_scanner,
                      isMobile: true,
                    ),
                  ],
                );
              } else {
                // Tablet/Desktop: Side by side
                return Row(
                  children: [
                    Expanded(
                      child: _TopUpChannelTile(
                        label: 'Cash Desk',
                        total: manualTotal,
                        count: manualCount,
                        color: Colors.blue,
                        icon: Icons.attach_money,
                        isMobile: false,
                      ),
                    ),
                    SizedBox(width: isTablet ? 10 : 12),
                    Expanded(
                      child: _TopUpChannelTile(
                        label: 'GCash Verified',
                        total: gcashTotal,
                        count: gcashCount,
                        color: Colors.deepPurple,
                        icon: Icons.qr_code_scanner,
                        isMobile: false,
                      ),
                    ),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

class _TopUpChannelTile extends StatelessWidget {
  final String label;
  final String total;
  final int count;
  final Color color;
  final IconData icon;
  final bool isMobile;

  const _TopUpChannelTile({
    required this.label,
    required this.total,
    required this.count,
    required this.color,
    required this.icon,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.12), color.withOpacity(0.06)],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: color, size: isMobile ? 18 : 20),
              ),
              SizedBox(width: isMobile ? 8 : 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 12 : 14),
          Text(
            total,
            style: TextStyle(
              fontSize: isMobile ? 16 : 18,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
          SizedBox(height: isMobile ? 4 : 6),
          Row(
            children: [
              Icon(
                Icons.receipt_long,
                size: isMobile ? 12 : 14,
                color: color.withOpacity(0.7),
              ),
              SizedBox(width: isMobile ? 4 : 6),
              Flexible(
                child: Text(
                  '$count ${count == 1 ? 'transaction' : 'transactions'}',
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 12,
                    color: color.withOpacity(0.75),
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BalanceItem extends StatelessWidget {
  final String title;
  final String value;
  final int count;
  final Color color;
  final IconData icon;

  const _BalanceItem({
    required this.title,
    required this.value,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$count accounts',
            style: TextStyle(fontSize: 12, color: color.withOpacity(0.7)),
          ),
        ],
      ),
    );
  }
}

class _VendorTransactionCountItem extends StatelessWidget {
  static const Color evsuRed = Color(0xFFB01212);
  final String name;
  final int totalTransactions;
  final int rank;

  const _VendorTransactionCountItem({
    required this.name,
    required this.totalTransactions,
    required this.rank,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: rank <= 3 ? evsuRed.withOpacity(0.05) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: rank <= 3 ? evsuRed.withOpacity(0.3) : Colors.grey.shade200,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: rank <= 3 ? evsuRed : Colors.grey[300],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      rank.toString(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: rank <= 3 ? Colors.white : Colors.grey[600],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: rank <= 3 ? evsuRed : Colors.black87,
                        ),
                      ),
                      Text(
                        '$totalTransactions total transactions',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  totalTransactions.toString(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: rank <= 3 ? evsuRed : Colors.grey[700],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  static const Color evsuRed = Color(0xFFB01212);
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _ExportButton({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: _ExportButton.evsuRed.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: _ExportButton.evsuRed),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _ExportButton.evsuRed,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
