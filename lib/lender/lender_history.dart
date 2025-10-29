import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../browse.dart' show primaryColor;

class LenderHistoryPage extends StatefulWidget {
  static const String routeName = '/lender/history';
  const LenderHistoryPage({super.key});

  @override
  State<LenderHistoryPage> createState() => _LenderHistoryPageState();
}

class _LenderHistoryPageState extends State<LenderHistoryPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allHistory = [];
  List<Map<String, dynamic>> _filteredHistory = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _searchController.addListener(_filterHistory);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('user_borrow_history') ?? <String>[];
    final history = <Map<String, dynamic>>[];

    for (final s in list) {
      try {
        final rec = jsonDecode(s) as Map<String, dynamic>;
        final status = (rec['status'] ?? '').toString();
        final item = rec['item'];
        final returnedAt = rec['returnedAt'];

        // Include any record that has actually been rented:
        // - Active rentals: status Approved or Late Return (returnedAt is null)
        // - Completed rentals: any record with returnedAt set
        final bool isActiveRental =
            (status == 'Approved' || status == 'Late Return') &&
            (returnedAt == null ||
                (returnedAt is String && returnedAt.isEmpty));
        final bool isCompletedRental =
            returnedAt != null &&
            (!(returnedAt is String) || returnedAt.isNotEmpty);

        if (item is Map<String, dynamic> &&
            (isActiveRental || isCompletedRental)) {
          history.add(rec);
        }
      } catch (_) {
        // ignore bad record
      }
    }

    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      final s = v.toString();
      try {
        return DateTime.parse(s);
      } catch (_) {
        return null;
      }
    }

    history.sort((a, b) {
      final aApproved = parseDate(a['approvedAt']);
      final bApproved = parseDate(b['approvedAt']);
      final aBorrow = aApproved ?? parseDate(a['borrowDate']);
      final bBorrow = bApproved ?? parseDate(b['borrowDate']);
      final aTime = aBorrow?.millisecondsSinceEpoch ?? 0;
      final bTime = bBorrow?.millisecondsSinceEpoch ?? 0;
      return bTime.compareTo(aTime);
    });

    if (mounted) {
      setState(() {
        _allHistory = history;
        _filteredHistory = history;
      });
    }
  }

  void _filterHistory() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredHistory = _allHistory;
      } else {
        _filteredHistory = _allHistory.where((rec) {
          final item = rec['item'];
          if (item is Map<String, dynamic>) {
            final id = (item['id'] ?? '').toString().toLowerCase();
            final title = (item['title'] ?? '').toString().toLowerCase();
            return id.contains(query) || title.contains(query);
          }
          return false;
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        // Back arrow only (no extra actions)
        title: Text(
          'Lend History',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search by Item ID or Name',
                hintStyle: GoogleFonts.poppins(fontSize: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[200],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _filteredHistory.isEmpty
                  ? Center(
                      child: Text(
                        _searchController.text.trim().isEmpty
                            ? 'No rental history yet.'
                            : 'No matching items found.',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredHistory.length,
                      itemBuilder: (context, index) {
                        final rec = _filteredHistory[index];
                        final item = rec['item'];
                        final borrowerName = rec['borrowerName'] ?? 'Unknown';
                        final borrowDate = rec['borrowDate'] ?? '';
                        final returnDate = rec['returnDate'] ?? '';
                        final returnedAt = rec['returnedAt'];
                        final lateReturn = rec['lateReturn'] ?? false;

                        // Determine status text and color
                        String statusText;
                        Color statusColor;
                        if (returnedAt != null &&
                            returnedAt.toString().isNotEmpty) {
                          if (lateReturn == true) {
                            statusText = 'Returned as Late';
                            statusColor = Colors.red;
                          } else {
                            statusText = 'Returned';
                            statusColor = Colors.green;
                          }
                        } else {
                          final isLateActive =
                              (rec['status']?.toString() == 'Late Return');
                          statusText = isLateActive ? 'Late Return' : 'Active';
                          statusColor = isLateActive
                              ? Colors.red
                              : Colors.orange;
                        }

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: item is Map<String, dynamic>
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.asset(
                                      item['imageUrl'] ?? '',
                                      width: 56,
                                      height: 56,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const Icon(Icons.broken_image),
                                    ),
                                  )
                                : const Icon(Icons.inventory),
                            title: Text(
                              item is Map<String, dynamic>
                                  ? (item['title'] ?? 'Unknown Item')
                                  : 'Unknown Item',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'Borrower: $borrowerName\n'
                              'Borrowed: $borrowDate\n'
                              'Expected Return: $returnDate\n'
                              '${(returnedAt != null && returnedAt.toString().isNotEmpty) ? 'Returned: ${returnedAt.toString().split('T')[0]}' : 'Status: $statusText'}',
                              style: GoogleFonts.poppins(fontSize: 12),
                            ),
                            isThreeLine: true,
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                statusText,
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
