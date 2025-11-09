import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/notification_service.dart';
import '../services/session_service.dart';

class WithdrawalRequestsTab extends StatefulWidget {
  const WithdrawalRequestsTab({super.key});

  @override
  State<WithdrawalRequestsTab> createState() => _WithdrawalRequestsTabState();
}

class _WithdrawalRequestsTabState extends State<WithdrawalRequestsTab> {
  static const Color evsuRed = Color(0xFFB91C1C);

  List<Map<String, dynamic>> _pendingRequests = [];
  List<Map<String, dynamic>> _allRequests = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _selectedFilter =
      'Pending'; // 'Pending', 'Approved', 'Rejected', 'All'

  @override
  void initState() {
    super.initState();
    _loadWithdrawalRequests();
  }

  Future<void> _loadWithdrawalRequests() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print(
        '🔍 [DEBUG] Loading withdrawal requests - Always loading ALL requests (filter will be applied client-side)',
      );
      // Always load ALL requests regardless of filter, then filter client-side
      final result = await SupabaseService.getAllWithdrawalRequests(
        status: null, // Always load all statuses
        limit: 100,
      );

      print('📊 [DEBUG] API Response - success: ${result['success']}');
      print('📊 [DEBUG] API Response - message: ${result['message']}');

      if (result['success'] == true) {
        final requests = List<Map<String, dynamic>>.from(result['data'] ?? []);
        print('📦 [DEBUG] Total requests loaded: ${requests.length}');

        // Debug: Print status breakdown
        final statusCounts = <String, int>{};
        for (var request in requests) {
          final status = request['status']?.toString() ?? 'Unknown';
          statusCounts[status] = (statusCounts[status] ?? 0) + 1;
        }
        print('📈 [DEBUG] Status breakdown: $statusCounts');

        // Get user details for each request
        for (var request in requests) {
          final studentId = request['student_id']?.toString();
          if (studentId != null) {
            try {
              final userResult = await SupabaseService.getUserByStudentId(
                studentId,
              );
              if (userResult['success'] == true) {
                final userData = userResult['data'];
                request['user_name'] = userData['name'] ?? 'Unknown User';
                request['user_course'] = userData['course'] ?? '';
              }
            } catch (e) {
              print('⚠️ [DEBUG] Error loading user data for $studentId: $e');
              request['user_name'] = 'Unknown User';
            }
          }
        }

        final pendingRequests =
            requests.where((r) => r['status'] == 'Pending').toList();
        final approvedRequests =
            requests.where((r) => r['status'] == 'Approved').toList();
        final rejectedRequests =
            requests.where((r) => r['status'] == 'Rejected').toList();

        print('✅ [DEBUG] Pending requests: ${pendingRequests.length}');
        print('✅ [DEBUG] Approved requests: ${approvedRequests.length}');
        print('✅ [DEBUG] Rejected requests: ${rejectedRequests.length}');

        // Debug: Print first few request details
        if (requests.isNotEmpty) {
          print('🔍 [DEBUG] Sample request details:');
          for (
            var i = 0;
            i < (requests.length > 3 ? 3 : requests.length);
            i++
          ) {
            final req = requests[i];
            print(
              '  Request $i: id=${req['id']}, status=${req['status']}, student_id=${req['student_id']}, amount=${req['amount']}',
            );
          }
        }

        setState(() {
          _allRequests = requests;
          _pendingRequests = pendingRequests;
          _isLoading = false;
        });

        print(
          '💾 [DEBUG] State updated - _allRequests: ${_allRequests.length}, _pendingRequests: ${_pendingRequests.length}',
        );
      } else {
        print('❌ [DEBUG] API call failed: ${result['message']}');
        setState(() {
          _errorMessage =
              result['message'] ?? 'Failed to load withdrawal requests';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('💥 [DEBUG] Exception in _loadWithdrawalRequests: $e');
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isSmallScreen = screenWidth < 400;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth > 600 ? 24.0 : 16.0,
            vertical: 16.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Withdrawal Requests',
                style: TextStyle(
                  fontSize: isSmallScreen ? 20 : (isMobile ? 24 : 28),
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                'Review and manage student withdrawal requests',
                style: TextStyle(
                  fontSize: isSmallScreen ? 12 : 14,
                  color: Colors.grey,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        // Filter Tabs
        Container(
          margin: EdgeInsets.symmetric(
            horizontal: screenWidth > 600 ? 24.0 : 16.0,
          ),
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
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('Pending', _pendingRequests.length),
                _buildFilterChip('Approved', 0),
                _buildFilterChip('Rejected', 0),
                _buildFilterChip('All', _allRequests.length),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Content
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadWithdrawalRequests,
            color: evsuRed,
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage != null
                    ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: isSmallScreen ? 48 : 64,
                              color: Colors.red[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage!,
                              style: TextStyle(
                                fontSize: isSmallScreen ? 14 : 16,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 5,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadWithdrawalRequests,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: evsuRed,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                    : Builder(
                      builder: (context) {
                        final filtered = _getFilteredRequests();
                        print(
                          '🎨 [DEBUG] Building list view - Filter: $_selectedFilter, Filtered count: ${filtered.length}, Total: ${_allRequests.length}',
                        );

                        if (filtered.isEmpty) {
                          print(
                            '⚠️ [DEBUG] No requests to display for filter: $_selectedFilter',
                          );
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.account_balance_wallet_outlined,
                                  size: isSmallScreen ? 48 : 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No ${_selectedFilter.toLowerCase()} withdrawal requests',
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 16 : 18,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Text(
                                    _selectedFilter == 'All'
                                        ? 'Withdrawal requests will appear here'
                                        : 'No ${_selectedFilter.toLowerCase()} requests found',
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 12 : 14,
                                      color: Colors.grey[500],
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (_allRequests.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Total requests: ${_allRequests.length}',
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 11 : 12,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }

                        print(
                          '✅ [DEBUG] Building ListView with ${filtered.length} items',
                        );
                        return ListView.builder(
                          padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final request = filtered[index];
                            print(
                              '🏗️ [DEBUG] Building request card $index: id=${request['id']}, status="${request['status']}"',
                            );
                            return _buildRequestCard(request, isMobile);
                          },
                        );
                      },
                    ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, int count) {
    final isSelected = _selectedFilter == label;

    // Calculate actual counts for each filter
    int displayCount;
    if (label == 'Pending') {
      displayCount = _pendingRequests.length;
    } else if (label == 'Approved') {
      displayCount =
          _allRequests
              .where((r) => r['status']?.toString() == 'Approved')
              .length;
    } else if (label == 'Rejected') {
      displayCount =
          _allRequests
              .where((r) => r['status']?.toString() == 'Rejected')
              .length;
    } else {
      displayCount = _allRequests.length;
    }

    print(
      '🏷️ [DEBUG] Filter chip "$label": displayCount=$displayCount, _allRequests=${_allRequests.length}',
    );

    return GestureDetector(
      onTap: () {
        print(
          '🖱️ [DEBUG] Filter chip tapped: "$label" (previous: "$_selectedFilter")',
        );
        setState(() {
          _selectedFilter = label;
        });
        print('🔄 [DEBUG] Filter changed to: "$_selectedFilter"');
        final filtered = _getFilteredRequests();
        print(
          '📊 [DEBUG] After filter change - Filtered requests count: ${filtered.length}',
        );
      },
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? evsuRed : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? evsuRed : Colors.grey[300]!,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
            if (displayCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color:
                      isSelected
                          ? Colors.white.withOpacity(0.3)
                          : evsuRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  displayCount.toString(),
                  style: TextStyle(
                    color: isSelected ? Colors.white : evsuRed,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getFilteredRequests() {
    List<Map<String, dynamic>> filtered;

    if (_selectedFilter == 'Pending') {
      filtered = _pendingRequests;
    } else if (_selectedFilter == 'Approved') {
      filtered =
          _allRequests.where((r) {
            final status = r['status']?.toString() ?? '';
            final isApproved = status == 'Approved';
            if (isApproved) {
              print(
                '✅ [DEBUG] Found approved request: id=${r['id']}, student_id=${r['student_id']}',
              );
            }
            return isApproved;
          }).toList();
    } else if (_selectedFilter == 'Rejected') {
      filtered =
          _allRequests.where((r) {
            final status = r['status']?.toString() ?? '';
            final isRejected = status == 'Rejected';
            if (isRejected) {
              print(
                '❌ [DEBUG] Found rejected request: id=${r['id']}, student_id=${r['student_id']}',
              );
            }
            return isRejected;
          }).toList();
    } else {
      filtered = _allRequests;
    }

    print(
      '🔍 [DEBUG] _getFilteredRequests - Filter: $_selectedFilter, Total: ${_allRequests.length}, Filtered: ${filtered.length}',
    );

    // Debug: Print status of all requests when filtering
    if (_selectedFilter == 'Approved' || _selectedFilter == 'Rejected') {
      print('🔍 [DEBUG] All request statuses in _allRequests:');
      for (var req in _allRequests) {
        print(
          '  - id=${req['id']}, status="${req['status']}" (type: ${req['status'].runtimeType})',
        );
      }
    }

    return filtered;
  }

  Widget _buildRequestCard(Map<String, dynamic> request, bool isMobile) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;
    final amount = (request['amount'] as num?)?.toDouble() ?? 0.0;
    final status = request['status']?.toString() ?? 'Pending';
    final transferType = request['transfer_type']?.toString() ?? '';
    final userName = request['user_name']?.toString() ?? 'Unknown User';
    final studentId = request['student_id']?.toString() ?? '';
    final createdAt = request['created_at']?.toString();
    final gcashNumber = request['gcash_number']?.toString();
    final gcashAccountName = request['gcash_account_name']?.toString();
    final adminNotes = request['admin_notes']?.toString();

    DateTime? dateTime;
    if (createdAt != null) {
      dateTime = DateTime.tryParse(createdAt);
    }

    String formattedDate = 'Unknown date';
    String formattedTime = '';
    if (dateTime != null) {
      formattedDate = _formatDate(dateTime);
      formattedTime = _formatTime(dateTime);
    }

    Color statusColor;
    String statusText;
    Color statusBgColor;

    if (status == 'Pending') {
      statusColor = Colors.orange;
      statusText = 'Pending';
      statusBgColor = Colors.orange[50]!;
    } else if (status == 'Approved') {
      statusColor = Colors.green;
      statusText = 'Approved';
      statusBgColor = Colors.green[50]!;
    } else {
      statusColor = Colors.red;
      statusText = 'Rejected';
      statusBgColor = Colors.red[50]!;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: status == 'Pending' ? Colors.orange[200]! : Colors.grey[200]!,
          width: status == 'Pending' ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 12 : (isMobile ? 16 : 20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
                  decoration: BoxDecoration(
                    color:
                        transferType == 'Gcash'
                            ? Colors.blue[50]
                            : Colors.green[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    transferType == 'Gcash'
                        ? Icons.account_balance_wallet
                        : Icons.money,
                    color: transferType == 'Gcash' ? Colors.blue : Colors.green,
                    size: isSmallScreen ? 20 : 24,
                  ),
                ),
                SizedBox(width: isSmallScreen ? 12 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: TextStyle(
                          fontSize: isSmallScreen ? 16 : 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Student ID: $studentId',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 11 : 13,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: isSmallScreen ? 4 : 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₱${amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 16 : 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 6 : 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusBgColor,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: statusColor),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 10 : 12,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            Divider(height: 1, color: Colors.grey[200]),

            const SizedBox(height: 16),

            // Details
            isSmallScreen
                ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailItem(
                      icon: Icons.payment,
                      label: 'Transfer Type',
                      value:
                          transferType == 'Gcash' ? 'GCash' : 'Cash (Onsite)',
                      isSmallScreen: isSmallScreen,
                    ),
                    const SizedBox(height: 12),
                    _buildDetailItem(
                      icon: Icons.calendar_today,
                      label: 'Date',
                      value: formattedDate,
                      isSmallScreen: isSmallScreen,
                    ),
                    const SizedBox(height: 12),
                    _buildDetailItem(
                      icon: Icons.access_time,
                      label: 'Time',
                      value: formattedTime,
                      isSmallScreen: isSmallScreen,
                    ),
                  ],
                )
                : Row(
                  children: [
                    Expanded(
                      child: _buildDetailItem(
                        icon: Icons.payment,
                        label: 'Transfer Type',
                        value:
                            transferType == 'Gcash' ? 'GCash' : 'Cash (Onsite)',
                        isSmallScreen: isSmallScreen,
                      ),
                    ),
                    Expanded(
                      child: _buildDetailItem(
                        icon: Icons.calendar_today,
                        label: 'Date',
                        value: formattedDate,
                        isSmallScreen: isSmallScreen,
                      ),
                    ),
                    Expanded(
                      child: _buildDetailItem(
                        icon: Icons.access_time,
                        label: 'Time',
                        value: formattedTime,
                        isSmallScreen: isSmallScreen,
                      ),
                    ),
                  ],
                ),

            // GCash Details (if applicable)
            if (transferType == 'Gcash' && gcashNumber != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet,
                          size: 16,
                          color: Colors.blue[700],
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'GCash Details',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 12 : 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue[900],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Number: $gcashNumber',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 12 : 13,
                        color: Colors.blue[900],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (gcashAccountName != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Account Name: $gcashAccountName',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 12 : 13,
                          color: Colors.blue[900],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // Admin Notes (if rejected)
            if (status == 'Rejected' && adminNotes != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.red[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rejection Reason',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 12 : 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.red[900],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            adminNotes,
                            style: TextStyle(
                              fontSize: isSmallScreen ? 12 : 13,
                              color: Colors.red[900],
                            ),
                            maxLines: 5,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Action Buttons (only for pending requests)
            if (status == 'Pending') ...[
              const SizedBox(height: 16),
              isSmallScreen
                  ? Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _showRejectDialog(request),
                          icon: Icon(
                            Icons.close,
                            size: isSmallScreen ? 16 : 18,
                          ),
                          label: const Text('Reject'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: EdgeInsets.symmetric(
                              vertical: isSmallScreen ? 10 : 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _showApproveDialog(request),
                          icon: Icon(
                            Icons.check,
                            size: isSmallScreen ? 16 : 18,
                          ),
                          label: const Text('Approve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              vertical: isSmallScreen ? 10 : 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                  : Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showRejectDialog(request),
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('Reject'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showApproveDialog(request),
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Approve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
    bool isSmallScreen = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: isSmallScreen ? 12 : 14, color: Colors.grey[600]),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: isSmallScreen ? 11 : 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: isSmallScreen ? 12 : 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    const months = [
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
    return '${months[date.month - 1]} ${date.day.toString().padLeft(2, '0')}, ${date.year}';
  }

  String _formatTime(DateTime date) {
    final hour =
        date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  void _showApproveDialog(Map<String, dynamic> request) {
    final transferType = request['transfer_type']?.toString() ?? '';
    final amount = (request['amount'] as num?)?.toDouble() ?? 0.0;
    final userName = request['user_name']?.toString() ?? 'Unknown User';
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            contentPadding: EdgeInsets.all(isSmallScreen ? 16 : 24),
            title: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: isSmallScreen ? 24 : 28,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Approve Withdrawal',
                    style: TextStyle(fontSize: isSmallScreen ? 16 : 20),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Are you sure you want to approve this withdrawal request?',
                    style: TextStyle(fontSize: isSmallScreen ? 13 : 14),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSummaryRow('User', userName),
                        _buildSummaryRow(
                          'Amount',
                          '₱${amount.toStringAsFixed(2)}',
                        ),
                        _buildSummaryRow(
                          'Method',
                          transferType == 'Gcash' ? 'GCash' : 'Cash (Onsite)',
                        ),
                        if (transferType == 'Gcash' &&
                            request['gcash_number'] != null)
                          _buildSummaryRow(
                            'GCash Number',
                            request['gcash_number'],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (transferType == 'Gcash')
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Colors.blue[700],
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Please send ₱${amount.toStringAsFixed(2)} to the provided GCash number.',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 11 : 12,
                                color: Colors.blue[900],
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Colors.green[700],
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Mark as ready for pickup. User will collect cash in person.',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 11 : 12,
                                color: Colors.green[900],
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _approveRequest(request);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Approve'),
              ),
            ],
          ),
    );
  }

  void _showRejectDialog(Map<String, dynamic> request) {
    final TextEditingController reasonController = TextEditingController();
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            contentPadding: EdgeInsets.all(isSmallScreen ? 16 : 24),
            title: Row(
              children: [
                Icon(
                  Icons.cancel,
                  color: Colors.red,
                  size: isSmallScreen ? 24 : 28,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Reject Withdrawal',
                    style: TextStyle(fontSize: isSmallScreen ? 16 : 20),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Are you sure you want to reject this withdrawal request?',
                    style: TextStyle(fontSize: isSmallScreen ? 13 : 14),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: reasonController,
                    decoration: const InputDecoration(
                      labelText: 'Rejection Reason (Optional)',
                      hintText: 'Enter reason for rejection...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _rejectRequest(request, reasonController.text.trim());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Reject'),
              ),
            ],
          ),
    );
  }

  Future<void> _approveRequest(Map<String, dynamic> request) async {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            contentPadding: EdgeInsets.all(isSmallScreen ? 16 : 24),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: evsuRed),
                SizedBox(height: isSmallScreen ? 12 : 16),
                Text(
                  'Processing approval...',
                  style: TextStyle(fontSize: isSmallScreen ? 13 : 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
    );

    try {
      final requestId = request['id'] as int;
      final adminName =
          SessionService.currentUserData?['name']?.toString() ?? 'Admin';

      final result = await SupabaseService.approveWithdrawalRequest(
        requestId: requestId,
        processedBy: adminName,
        adminNotes: null,
      );

      // Close loading dialog if still open
      if (Navigator.of(context).canPop()) {
        Navigator.pop(context);
      }

      if (result['success'] == true) {
        // Create notification for user
        final studentId = request['student_id']?.toString();
        final transferType = request['transfer_type']?.toString() ?? '';
        final amount = (request['amount'] as num?)?.toDouble() ?? 0.0;

        if (studentId != null) {
          try {
            await NotificationService.createNotification(
              studentId: studentId,
              type: 'withdrawal_approved',
              title: 'Withdrawal Approved',
              message:
                  transferType == 'Gcash'
                      ? 'Your withdrawal of ₱${amount.toStringAsFixed(2)} has been approved. Funds will be transferred to your GCash account shortly.'
                      : 'Your withdrawal of ₱${amount.toStringAsFixed(2)} is ready for pickup. Please visit the admin office to collect your cash.',
              actionData:
                  'request_id:$requestId|amount:$amount|transfer_type:$transferType',
            );
          } catch (e) {
            print('Error creating notification: $e');
          }
        }

        // Refresh requests
        _loadWithdrawalRequests();

        // Show success dialog
        final screenWidth = MediaQuery.of(context).size.width;
        final isSmallScreen = screenWidth < 400;
        final userName = request['user_name']?.toString() ?? 'Unknown User';
        final studentIdDisplay = request['student_id']?.toString() ?? '';

        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                contentPadding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                title: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: isSmallScreen ? 24 : 28,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Approval Successful',
                        style: TextStyle(fontSize: isSmallScreen ? 16 : 20),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildStudentInfoRow(
                              'Student Name',
                              userName,
                              isSmallScreen,
                            ),
                            const SizedBox(height: 8),
                            _buildStudentInfoRow(
                              'Student ID',
                              studentIdDisplay,
                              isSmallScreen,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        transferType == 'Gcash'
                            ? 'Withdrawal approved. Please send ₱${amount.toStringAsFixed(2)} to the user\'s GCash account.'
                            : 'Withdrawal approved. User can now collect cash from the admin office.',
                        style: TextStyle(fontSize: isSmallScreen ? 13 : 14),
                        textAlign: TextAlign.left,
                      ),
                    ],
                  ),
                ),
                actions: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: isSmallScreen ? 10 : 12,
                        ),
                      ),
                      child: const Text('OK'),
                    ),
                  ),
                ],
              ),
        );
      } else {
        // Check if it was auto-rejected due to insufficient balance
        final autoRejected = result['auto_rejected'] == true;
        final studentId = request['student_id']?.toString();
        final amount = (request['amount'] as num?)?.toDouble() ?? 0.0;
        final currentBalance = result['current_balance'] as double? ?? 0.0;

        if (autoRejected && studentId != null) {
          // Create notification for user about auto-rejection
          try {
            await NotificationService.createNotification(
              studentId: studentId,
              type: 'withdrawal_rejected',
              title: 'Withdrawal Request Rejected',
              message:
                  'Your withdrawal request of ₱${amount.toStringAsFixed(2)} was rejected due to insufficient balance. Your current balance is ₱${currentBalance.toStringAsFixed(2)}.',
              actionData:
                  'request_id:$requestId|amount:$amount|reason:Insufficient balance',
            );
          } catch (e) {
            print('Error creating notification: $e');
          }

          // Refresh requests
          _loadWithdrawalRequests();

          // Show auto-rejection dialog
          final screenWidth = MediaQuery.of(context).size.width;
          final isSmallScreen = screenWidth < 400;
          final userName = request['user_name']?.toString() ?? 'Unknown User';
          final studentIdDisplay = request['student_id']?.toString() ?? '';

          showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
                  contentPadding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                  title: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange,
                        size: isSmallScreen ? 24 : 28,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Auto-Rejected',
                          style: TextStyle(fontSize: isSmallScreen ? 16 : 20),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildStudentInfoRow(
                                'Student Name',
                                userName,
                                isSmallScreen,
                              ),
                              const SizedBox(height: 8),
                              _buildStudentInfoRow(
                                'Student ID',
                                studentIdDisplay,
                                isSmallScreen,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'The withdrawal request was automatically rejected due to insufficient balance.',
                          style: TextStyle(fontSize: isSmallScreen ? 13 : 14),
                          textAlign: TextAlign.left,
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildBalanceRow(
                                'Requested Amount',
                                '₱${amount.toStringAsFixed(2)}',
                                isSmallScreen,
                              ),
                              const SizedBox(height: 8),
                              _buildBalanceRow(
                                'Current Balance',
                                '₱${currentBalance.toStringAsFixed(2)}',
                                isSmallScreen,
                              ),
                              const SizedBox(height: 8),
                              _buildBalanceRow(
                                'Shortage',
                                '₱${(amount - currentBalance).toStringAsFixed(2)}',
                                isSmallScreen,
                                isShortage: true,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'The user has been notified about the rejection.',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 12 : 13,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.left,
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            vertical: isSmallScreen ? 10 : 12,
                          ),
                        ),
                        child: const Text('OK'),
                      ),
                    ),
                  ],
                ),
          );
        } else {
          // Regular error (not auto-rejection)
          throw Exception(result['message'] ?? 'Failed to approve request');
        }
      }
    } catch (e) {
      // Close loading dialog if still open
      if (Navigator.of(context).canPop()) {
        Navigator.pop(context);
      }

      // Show error dialog
      final screenWidth = MediaQuery.of(context).size.width;
      final isSmallScreen = screenWidth < 400;

      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              contentPadding: EdgeInsets.all(isSmallScreen ? 16 : 24),
              title: Row(
                children: [
                  Icon(
                    Icons.error,
                    color: Colors.red,
                    size: isSmallScreen ? 24 : 28,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Approval Failed',
                      style: TextStyle(fontSize: isSmallScreen ? 16 : 20),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Text(
                  'Failed to approve request: ${e.toString()}',
                  style: TextStyle(fontSize: isSmallScreen ? 13 : 14),
                  textAlign: TextAlign.left,
                ),
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        vertical: isSmallScreen ? 10 : 12,
                      ),
                    ),
                    child: const Text('OK'),
                  ),
                ),
              ],
            ),
      );
    }
  }

  Future<void> _rejectRequest(
    Map<String, dynamic> request,
    String reason,
  ) async {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            contentPadding: EdgeInsets.all(isSmallScreen ? 16 : 24),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: evsuRed),
                SizedBox(height: isSmallScreen ? 12 : 16),
                Text(
                  'Processing rejection...',
                  style: TextStyle(fontSize: isSmallScreen ? 13 : 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
    );

    try {
      final requestId = request['id'] as int;
      final adminName =
          SessionService.currentUserData?['name']?.toString() ?? 'Admin';

      final result = await SupabaseService.rejectWithdrawalRequest(
        requestId: requestId,
        processedBy: adminName,
        adminNotes: reason.isEmpty ? null : reason,
      );

      // Close loading dialog if still open
      if (Navigator.of(context).canPop()) {
        Navigator.pop(context);
      }

      if (result['success'] == true) {
        // Create notification for user
        final studentId = request['student_id']?.toString();
        final amount = (request['amount'] as num?)?.toDouble() ?? 0.0;

        if (studentId != null) {
          try {
            await NotificationService.createNotification(
              studentId: studentId,
              type: 'withdrawal_rejected',
              title: 'Withdrawal Rejected',
              message:
                  reason.isEmpty
                      ? 'Your withdrawal request of ₱${amount.toStringAsFixed(2)} has been rejected.'
                      : 'Your withdrawal request of ₱${amount.toStringAsFixed(2)} has been rejected. Reason: $reason',
              actionData: 'request_id:$requestId|amount:$amount|reason:$reason',
            );
          } catch (e) {
            print('Error creating notification: $e');
          }
        }

        // Refresh requests
        _loadWithdrawalRequests();

        // Show success dialog
        final screenWidth = MediaQuery.of(context).size.width;
        final isSmallScreen = screenWidth < 400;
        final userName = request['user_name']?.toString() ?? 'Unknown User';
        final studentIdDisplay = request['student_id']?.toString() ?? '';

        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                contentPadding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                title: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: isSmallScreen ? 24 : 28,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Rejection Successful',
                        style: TextStyle(fontSize: isSmallScreen ? 16 : 20),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildStudentInfoRow(
                              'Student Name',
                              userName,
                              isSmallScreen,
                            ),
                            const SizedBox(height: 8),
                            _buildStudentInfoRow(
                              'Student ID',
                              studentIdDisplay,
                              isSmallScreen,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Withdrawal request has been rejected. User has been notified.',
                        style: TextStyle(fontSize: isSmallScreen ? 13 : 14),
                        textAlign: TextAlign.left,
                      ),
                    ],
                  ),
                ),
                actions: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: isSmallScreen ? 10 : 12,
                        ),
                      ),
                      child: const Text('OK'),
                    ),
                  ),
                ],
              ),
        );
      } else {
        throw Exception(result['message'] ?? 'Failed to reject request');
      }
    } catch (e) {
      // Close loading dialog if still open
      if (Navigator.of(context).canPop()) {
        Navigator.pop(context);
      }

      // Show error dialog
      final screenWidth = MediaQuery.of(context).size.width;
      final isSmallScreen = screenWidth < 400;

      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              contentPadding: EdgeInsets.all(isSmallScreen ? 16 : 24),
              title: Row(
                children: [
                  Icon(
                    Icons.error,
                    color: Colors.red,
                    size: isSmallScreen ? 24 : 28,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Rejection Failed',
                      style: TextStyle(fontSize: isSmallScreen ? 16 : 20),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Text(
                  'Failed to reject request: ${e.toString()}',
                  style: TextStyle(fontSize: isSmallScreen ? 13 : 14),
                  textAlign: TextAlign.left,
                ),
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        vertical: isSmallScreen ? 10 : 12,
                      ),
                    ),
                    child: const Text('OK'),
                  ),
                ),
              ],
            ),
      );
    }
  }

  Widget _buildSummaryRow(String label, String value) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isSmallScreen ? 12 : 13,
                color: Colors.grey[600],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 2,
            child: Text(
              value,
              style: TextStyle(
                fontSize: isSmallScreen ? 12 : 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceRow(
    String label,
    String value,
    bool isSmallScreen, {
    bool isShortage = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isSmallScreen ? 12 : 13,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isSmallScreen ? 13 : 14,
            fontWeight: FontWeight.bold,
            color: isShortage ? Colors.red : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildStudentInfoRow(String label, String value, bool isSmallScreen) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: isSmallScreen ? 12 : 13,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          flex: 2,
          child: Text(
            value,
            style: TextStyle(
              fontSize: isSmallScreen ? 13 : 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.end,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
