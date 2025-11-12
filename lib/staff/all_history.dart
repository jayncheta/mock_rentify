import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'add.dart' show AddItemsScreen;

class StaffHistoryPage extends StatefulWidget {
  static const String routeName = '/staff/history';
  const StaffHistoryPage({super.key});

  @override
  State<StaffHistoryPage> createState() => _StaffHistoryPageState();
}

class _StaffHistoryPageState extends State<StaffHistoryPage> {
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
    try {
      final response = await http.get(
        Uri.parse('http://10.2.8.21:3000/borrow-requests'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> requests = jsonDecode(response.body);
        final history = <Map<String, dynamic>>[];

        for (var req in requests) {
          // Only show approved or completed rentals
          if (req['status'] == 'Approved' || req['returned_at'] != null) {
            history.add({
              'item': {
                'id': req['item_id']?.toString() ?? '',
                'itemName': req['item_name'] ?? 'Unknown Item',
              },
              'borrowerName': req['borrower_name'] ?? 'Unknown',
              'borrowDate': req['borrow_date'] ?? '',
              'returnDate': req['return_date'] ?? '',
              'returnedAt': req['returned_at'],
              'status': req['status'] ?? 'Pending',
            });
          }
        }

        if (mounted) {
          setState(() {
            _allHistory = history;
            _filteredHistory = history;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading history: $e');
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
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black),
          leading: Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircleAvatar(
              backgroundColor: Colors.grey[200],
              child: IconButton(
                icon: const Icon(Icons.person),
                onPressed: () {
                  Navigator.pushNamed(context, '/staff/dashboard');
                },
              ),
            ),
          ),
          title: const SizedBox.shrink(),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.menu, color: Colors.black),
              onSelected: (value) {
                switch (value) {
                  case 'staff':
                    Navigator.pushNamed(context, AddItemsScreen.routeName);
                    break;
                  case 'return':
                    Navigator.pushNamed(context, '/staff/return');
                    break;
                  case 'history':
                    // Already on history screen
                    break;
                  case 'browse':
                    Navigator.pushNamed(context, '/staff/browse');
                    break;
                  case 'logout':
                    showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(
                          'Logout',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        content: Text(
                          'Are you sure you want to logout from this device?',
                          style: GoogleFonts.poppins(),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text('Cancel', style: GoogleFonts.poppins()),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Logged out')),
                              );
                              Navigator.pushNamedAndRemoveUntil(
                                context,
                                '/',
                                (route) => false,
                              );
                            },
                            child: Text(
                              'Logout',
                              style: GoogleFonts.poppins(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                    break;
                }
              },
              itemBuilder: (BuildContext context) => [
                PopupMenuItem<String>(
                  value: 'staff',
                  child: Text('Staff', style: GoogleFonts.poppins()),
                ),
                PopupMenuItem<String>(
                  value: 'return',
                  child: Text('Return', style: GoogleFonts.poppins()),
                ),
                PopupMenuItem<String>(
                  value: 'history',
                  child: Text('History', style: GoogleFonts.poppins()),
                ),
                PopupMenuItem<String>(
                  value: 'browse',
                  child: Text('Browse', style: GoogleFonts.poppins()),
                ),
                PopupMenuItem<String>(
                  value: 'logout',
                  child: Text(
                    'Logout',
                    style: GoogleFonts.poppins(color: Colors.red),
                  ),
                ),
              ],
            ),
          ],
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
                        if (returnedAt != null) {
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
                              '${returnedAt != null ? 'Returned: ${returnedAt.toString().split('T')[0]}' : 'Status: $statusText'}',
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
