import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserHistoryPage extends StatefulWidget {
  static const String routeName = '/user/history';
  const UserHistoryPage({super.key});

  @override
  State<UserHistoryPage> createState() => _UserHistoryPageState();
}

class _UserHistoryPageState extends State<UserHistoryPage> {
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
        // Show what the user has borrowed: include approved and returned
        if (status == 'Approved' || (rec['returnedAt'] != null)) {
          history.add(rec);
        }
      } catch (_) {
        // ignore bad record
      }
    }

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
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text('Rent History', style: GoogleFonts.poppins()),
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
                            ? 'No borrow history yet.'
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
                        final borrowerName = rec['borrowerName'] ?? 'You';
                        final borrowDate = rec['borrowDate'] ?? '';
                        final returnDate = rec['returnDate'] ?? '';
                        final returnedAt = rec['returnedAt'];
                        final lateReturn = rec['lateReturn'] ?? false;

                        // Determine status text and color
                        String statusText;
                        Color statusColor;
                        if (returnedAt != null) {
                          if (lateReturn == true) {
                            statusText = 'Returned as Late';
                            statusColor = Colors.red;
                          } else {
                            statusText = 'Returned';
                            statusColor = Colors.green;
                          }
                        } else {
                          statusText = 'Active';
                          statusColor = Colors.orange;
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
                              '${returnedAt != null ? 'Returned: ${returnedAt.toString().split('T')[0]}' : 'Status: Active'}',
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
