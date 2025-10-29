import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/items_service.dart' show ItemsService;
import '../browse.dart' show primaryColor;

class LenderReviewScreen extends StatefulWidget {
  static const String routeName = '/lender/review';

  const LenderReviewScreen({super.key});

  @override
  State<LenderReviewScreen> createState() => _LenderReviewScreenState();
}

class _LenderReviewScreenState extends State<LenderReviewScreen> {
  List<Map<String, dynamic>> _pendingRequests = [];

  @override
  void initState() {
    super.initState();
    _loadPendingRequests();
  }

  Future<void> _loadPendingRequests() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('user_borrow_history') ?? [];

    setState(() {
      _pendingRequests = data
          .map((e) => jsonDecode(e) as Map<String, dynamic>)
          .where((req) => req['status'] == 'Pending')
          .toList();
    });
  }

  Future<void> _updateRequestStatus(
    int index,
    String status,
    String reason,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('user_borrow_history') ?? [];

    // Find the matching request
    final request = _pendingRequests[index];
    final allRequests = data.map((e) => jsonDecode(e)).toList();

    String? approvedItemId;
    for (final req in allRequests) {
      if (req['item']['title'] == request['item']['title'] &&
          req['borrowerName'] == request['borrowerName']) {
        req['status'] = status;
        req['reason'] = reason;
        if (status == 'Approved') {
          req['approvedAt'] = DateTime.now().toIso8601String();
          // TODO: Replace with actual approver identity when auth is added
          req['approvedBy'] = 'Lender';
          approvedItemId = (req['item']['id'] ?? '').toString();
        }
        break;
      }
    }

    await prefs.setStringList(
      'user_borrow_history',
      allRequests.map((e) => jsonEncode(e)).toList(),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Request ${status.toLowerCase()} successfully')),
    );

    // If approved, mark the item as borrowed (yellow status)
    if (approvedItemId != null && approvedItemId.isNotEmpty) {
      await ItemsService.instance.setBorrowed(approvedItemId, true);
    }

    _loadPendingRequests(); // Refresh the screen
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
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
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
      ),
      body: _pendingRequests.isEmpty
          ? Center(
              child: Text(
                'No pending requests',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
              ),
            )
          : ListView.builder(
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
                      onPressed: () => _showReviewDialog(index),
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
    );
  }
}
