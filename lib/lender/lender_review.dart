import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../browse.dart' show primaryColor;

class BorrowRequestService {
  static final BorrowRequestService _instance =
      BorrowRequestService._internal();
  factory BorrowRequestService() => _instance;
  BorrowRequestService._internal();

  static const String _baseUrl = 'http://10.2.8.26:3000';

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    try {
      return DateTime.parse(value.toString());
    } catch (_) {
      return null;
    }
  }

  /// Fetch all pending borrow requests for a specific lender
  Future<List<Map<String, dynamic>>> getPendingRequests(int lenderId) async {
    try {
      debugPrint('🔍 Fetching requests for lender_id: $lenderId');
      // Fetch all borrow requests then filter locally; could be optimized with query params later
      final response = await http.get(Uri.parse('$_baseUrl/borrow-requests'));

      debugPrint('📡 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> allRequests = jsonDecode(response.body);
        debugPrint('📦 Total requests from API: ${allRequests.length}');

        // Log each request for debugging
        for (var req in allRequests) {
          debugPrint(
            '  Request: lender_id=${req['lender_id']}, status=${req['status']}, item=${req['item_name']}',
          );
        }

        // Filter requests for this lender that are pending
        final now = DateTime.now();
        final filtered = allRequests
            .where((req) {
              // Must match lender
              if (req['lender_id'] != lenderId) return false;
              // Status must be Pending (still awaiting review)
              if (req['status'] != 'Pending') return false;
              // Optional: hide requests whose intended borrow_date is in the past? (keeping all for now)
              return true;
            })
            .map((req) {
              // Normalize keys for UI consistency
              return {
                ...req as Map<String, dynamic>,
                'item_name': req['item_name'] ?? req['title'] ?? 'Unknown Item',
                'borrower_name': req['borrower_name'] ?? req['full_name'],
                // Derive simple flag if overdue before approval (edge case)
                'is_overdue_preapproval':
                    _parseDate(req['return_date'])?.isBefore(now) == true,
              };
            })
            .toList();

        debugPrint(
          '✅ Filtered pending requests for lender $lenderId: ${filtered.length}',
        );
        return filtered;
      } else {
        debugPrint('❌ Error fetching requests: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('💥 Error loading pending requests: $e');
      return [];
    }
  }

  /// Update borrow request status (approve/reject)
  Future<bool> updateRequestStatus({
    required int requestId,
    required String status,
    required String lenderResponse,
  }) async {
    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl/borrow-requests/$requestId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': status, 'lender_response': lenderResponse}),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Request $requestId updated to $status');
        return true;
      } else {
        debugPrint('❌ Error updating request: ${response.statusCode}');
        return false;
      }
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
  int? _lenderId;

  @override
  void initState() {
    super.initState();
    _loadLenderData();
  }

  Future<void> _loadLenderData() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('current_user');

    debugPrint('👤 Loading lender data...');
    debugPrint('userData string: $userDataString');

    if (userDataString != null) {
      final userData = jsonDecode(userDataString);
      _lenderId = userData['lender_id'] ?? userData['id'];
      debugPrint('✅ Lender ID loaded: $_lenderId');
    } else {
      debugPrint('⚠️ No userData found in SharedPreferences');
    }

    _loadPendingRequests();
  }

  Future<void> _loadPendingRequests() async {
    if (_lenderId == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final requests = await _requestService.getPendingRequests(_lenderId!);
      // Ensure lender_name present for display consistency
      for (final r in requests) {
        r['lender_name'] = r['lender_name'] ?? 'Yaya'; // fallback
      }
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
      requestId: request['request_id'] ?? 0,
      status: status,
      lenderResponse: lenderResponse,
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
          req['item_name'] ?? 'Item',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (req['image_url'] != null)
              Image.network(
                'http://10.2.8.26:3000${req['image_url']}',
                height: 150,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.image_not_supported, size: 150),
              ),
            const SizedBox(height: 10),
            Text(
              'Borrower name: ${req['borrower_name'] ?? 'Unknown'}',
              style: GoogleFonts.poppins(),
            ),
            Text(
              'Borrowing date: ${req['borrow_date'] ?? 'N/A'}',
              style: GoogleFonts.poppins(),
            ),
            Text(
              'Return date: ${req['return_date'] ?? 'N/A'}',
              style: GoogleFonts.poppins(),
            ),
            const SizedBox(height: 10),
            if (req['borrower_reason'] != null &&
                req['borrower_reason'].toString().isNotEmpty) ...[
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
                      req['borrower_reason'],
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
                  child: req['image_url'] != null
                      ? Image.network(
                          'http://10.2.8.26:3000${req['image_url']}',
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.image_not_supported),
                        )
                      : const Icon(Icons.image_not_supported),
                ),
                title: Text(
                  req['item_name'] ?? 'Item',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Borrower: ${req['borrower_name'] ?? 'Unknown'}\nReturn: ${req['return_date'] ?? 'N/A'}',
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
