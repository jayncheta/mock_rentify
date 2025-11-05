import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/items_service.dart' show ItemsService;
import '../browse.dart' show primaryColor;

// TODO: Replace with backend API service when ready
class BorrowRequestService {
  static final BorrowRequestService _instance =
      BorrowRequestService._internal();
  factory BorrowRequestService() => _instance;
  BorrowRequestService._internal();

  /// Fetch all pending borrow requests
  /// TODO: Replace with API call: GET /api/borrow-requests?status=pending
  Future<List<Map<String, dynamic>>> getPendingRequests() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getStringList('user_borrow_history') ?? [];

      return data
          .map((e) => jsonDecode(e) as Map<String, dynamic>)
          .where((req) => req['status'] == 'Pending')
          .toList();
    } catch (e) {
      debugPrint('Error loading pending requests: $e');
      return [];
    }
  }

  /// Update borrow request status (approve/reject)
  /// TODO: Replace with API call: PATCH /api/borrow-requests/{id}
  /// Body: { "status": "Approved|Rejected", "lenderResponse": "...", "approverId": "..." }
  Future<bool> updateRequestStatus({
    required String requestId,
    required String itemTitle,
    required String borrowerName,
    required String status,
    required String lenderResponse,
    String? approverId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getStringList('user_borrow_history') ?? [];
      final allRequests = data.map((e) => jsonDecode(e)).toList();

      String? approvedItemId;
      bool requestFound = false;

      for (final req in allRequests) {
        if (req['item']['title'] == itemTitle &&
            req['borrowerName'] == borrowerName) {
          req['status'] = status;
          req['lenderResponse'] =
              lenderResponse; // Changed from 'reason' to be more specific

          if (status == 'Approved') {
            req['approvedAt'] = DateTime.now().toIso8601String();
            req['approvedBy'] =
                approverId ?? 'Lender'; // TODO: Use actual user ID from auth
            approvedItemId = (req['item']['id'] ?? '').toString();
          } else if (status == 'Rejected') {
            req['rejectedAt'] = DateTime.now().toIso8601String();
            req['rejectedBy'] = approverId ?? 'Lender';
          }

          requestFound = true;
          break;
        }
      }

      if (!requestFound) {
        return false;
      }

      await prefs.setStringList(
        'user_borrow_history',
        allRequests.map((e) => jsonEncode(e)).toList(),
      );

      // If approved, mark the item as borrowed
      if (approvedItemId != null && approvedItemId.isNotEmpty) {
        await ItemsService.instance.setBorrowed(approvedItemId, true);
      }

      return true;
    } catch (e) {
      debugPrint('Error updating request status: $e');
      return false;
    }
  }
}

class LenderReviewScreen extends StatefulWidget {
  static const String routeName = '/lender/review';

  const LenderReviewScreen({super.key});

  @override
  State<LenderReviewScreen> createState() => _LenderReviewScreenState();
}

class _LenderReviewScreenState extends State<LenderReviewScreen> {
  final BorrowRequestService _requestService = BorrowRequestService();
  List<Map<String, dynamic>> _pendingRequests = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPendingRequests();
  }

  Future<void> _loadPendingRequests() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final requests = await _requestService.getPendingRequests();
      setState(() {
        _pendingRequests = requests;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load requests: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _updateRequestStatus(
    int index,
    String status,
    String lenderResponse,
  ) async {
    final request = _pendingRequests[index];

    setState(() => _isLoading = true);

    final success = await _requestService.updateRequestStatus(
      requestId: request['id']?.toString() ?? '', // TODO: Use actual request ID
      itemTitle: request['item']['title'],
      borrowerName: request['borrowerName'],
      status: status,
      lenderResponse: lenderResponse,
      // approverId: 'current_user_id', // TODO: Get from auth service
    );

    setState(() => _isLoading = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request ${status.toLowerCase()} successfully'),
          backgroundColor: status == 'Approved' ? Colors.green : Colors.red,
        ),
      );
      _loadPendingRequests();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update request. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showReviewDialog(int index) {
    final req = _pendingRequests[index];
    final TextEditingController reasonController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          req['item']['title'],
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(req['item']['imageUrl'], height: 150),
            const SizedBox(height: 10),
            Text(
              'Borrower name: ${req['borrowerName']}',
              style: GoogleFonts.poppins(),
            ),
            Text(
              'Borrowing date: ${req['borrowDate']}',
              style: GoogleFonts.poppins(),
            ),
            Text(
              'Return date: ${req['returnDate']}',
              style: GoogleFonts.poppins(),
            ),
            const SizedBox(height: 10),
            if (req['reason'] != null &&
                req['reason'].toString().isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: primaryColor.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Borrower\'s Reason:',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      req['reason'],
                      style: GoogleFonts.poppins(fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Your response (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              _updateRequestStatus(index, 'Approved', reasonController.text);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve'),
          ),
          ElevatedButton(
            onPressed: () {
              _updateRequestStatus(index, 'Rejected', reasonController.text);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        title: Text(
          'Pending Borrow Requests',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _isLoading ? null : _loadPendingRequests,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _pendingRequests.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: GoogleFonts.poppins(color: Colors.red[700]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadPendingRequests,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
            ),
          ],
        ),
      );
    }

    if (_pendingRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No pending requests',
              style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[700]),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: _pendingRequests.length,
          itemBuilder: (context, index) {
            final req = _pendingRequests[index];
            final item = req['item'];

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    item['imageUrl'],
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                  ),
                ),
                title: Text(
                  item['title'],
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Borrower: ${req['borrowerName']}\nReturn: ${req['returnDate']}',
                  style: GoogleFonts.poppins(fontSize: 13),
                ),
                trailing: ElevatedButton(
                  onPressed: _isLoading ? null : () => _showReviewDialog(index),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Review'),
                ),
              ),
            );
          },
        ),
        if (_isLoading && _pendingRequests.isNotEmpty)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
            ),
          ),
      ],
    );
  }
}
