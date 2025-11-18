import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'add.dart' show AddItemsScreen;

class StaffReturnScreen extends StatefulWidget {
  const StaffReturnScreen({super.key});
  static const String routeName = '/staff/return';

  @override
  State<StaffReturnScreen> createState() => _StaffReturnScreenState();
}

class _StaffReturnScreenState extends State<StaffReturnScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _borrowedItems = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadBorrowedItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBorrowedItems() async {
    setState(() => _isLoading = true);

    try {
      final response = await http.get(
        Uri.parse('http://10.2.8.26:3000/borrow-requests'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> requests = jsonDecode(response.body);

        // Filter for approved items that haven't been returned yet
        final borrowed = requests
            .where(
              (req) =>
                  req['status'] == 'Approved' && req['returned_at'] == null,
            )
            .map<Map<String, dynamic>>(
              (req) => {
                'request_id': req['request_id'],
                'item_id': req['item_id'],
                'item_name': req['item_name'],
                'borrower_name': req['borrower_name'],
                'borrow_date': req['borrow_date'],
                'return_date': req['return_date'],
                'image_url': req['image_url'],
                'borrower_reason': req['borrower_reason'],
              },
            )
            .toList();

        if (mounted) {
          setState(() {
            _borrowedItems = borrowed;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading borrowed items: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        automaticallyImplyLeading: false,
        elevation: 0,
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
                  // Already on return screen
                  break;
                case 'history':
                  Navigator.pushNamed(context, '/staff/history');
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
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                      content: Text(
                        'Are you sure you want to logout?',
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
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title between profile icon (in AppBar) and the search bar
            Text(
              'Return Item',
              style: GoogleFonts.poppins(
                fontSize: 40,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildSearchBar(),
            const SizedBox(height: 16),
            Expanded(child: _buildBorrowedList()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search by Item ID or Name',
        hintStyle: GoogleFonts.poppins(color: Colors.black.withOpacity(0.5)),
        prefixIcon: const Icon(Icons.search, color: Colors.black54),
        filled: true,
        fillColor: const Color(0xFFF0F0F0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildBorrowedList() {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = _borrowedItems.where((item) {
      if (query.isEmpty) return true;
      return item['item_name'].toString().toLowerCase().contains(query) ||
          item['item_id'].toString().toLowerCase().contains(query);
    }).toList();

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          query.isEmpty ? 'No borrowed items found' : 'No matching items found',
          style: GoogleFonts.poppins(),
        ),
      );
    }

    return ListView.separated(
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = filtered[index];
        return _ReturnCard(
          item: item,
          onConfirm: () => _confirmReturn(item),
          onRefresh: _loadBorrowedItems,
        );
      },
    );
  }

  Future<void> _confirmReturn(Map<String, dynamic> item) async {
    try {
      // Get staff ID from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('current_user');
      int? staffId;

      if (userDataString != null) {
        final userData = jsonDecode(userDataString);
        staffId = userData['staff_id'] ?? userData['id'];
      }

      // Move item from borrow_requests to history
      final response = await http.patch(
        Uri.parse(
          'http://10.2.8.26:3000/borrow-requests/${item['request_id']}',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'status': 'Approved',
          'return_item': true, // Flag to move to history
          'late_return': false,
          'staff_processed_return_id': staffId,
        }),
      );

      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Return confirmed successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadBorrowedItems(); // Refresh the list
      } else {
        throw Exception('Failed to confirm return');
      }
    } catch (e) {
      debugPrint('Error confirming return: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

class _ReturnCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final VoidCallback onConfirm;
  final VoidCallback onRefresh;
  const _ReturnCard({
    required this.item,
    required this.onConfirm,
    required this.onRefresh,
  });

  @override
  State<_ReturnCard> createState() => _ReturnCardState();
}

class _ReturnCardState extends State<_ReturnCard> {
  bool isChecked = false;

  @override
  Widget build(BuildContext context) {
    final itemName = widget.item['item_name'] ?? 'Unknown Item';
    final itemId = widget.item['item_id']?.toString() ?? '';
    final borrowerName = widget.item['borrower_name'] ?? 'Unknown';
    final borrowDate = widget.item['borrow_date'] ?? '';
    final returnDate = widget.item['return_date'] ?? '';
    final imageUrl = widget.item['image_url'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFBE7D7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item image if available
          if (imageUrl != null)
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  'http://10.2.8.26:3000$imageUrl',
                  height: 120,
                  width: 120,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.image_not_supported, size: 120),
                ),
              ),
            ),
          if (imageUrl != null) const SizedBox(height: 10),
          Text(
            'Return Confirmation',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          _buildDetail('Borrower: $borrowerName'),
          _buildDetail('Item: $itemName'),
          _buildDetail('Item ID: $itemId'),
          _buildDetail('Borrowed: ${borrowDate.split('T')[0]}'),
          _buildDetail('Expected Return: ${returnDate.split('T')[0]}'),
          const SizedBox(height: 10),
          Row(
            children: [
              Checkbox(
                activeColor: Colors.green,
                value: isChecked,
                onChanged: (value) =>
                    setState(() => isChecked = value ?? false),
              ),
              Expanded(
                child: Text(
                  'Item is in good condition',
                  style: GoogleFonts.poppins(fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  onPressed: () => _markAsLateReturn(context),
                  child: Text(
                    'Late Return',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  onPressed: isChecked ? widget.onConfirm : null,
                  child: Text(
                    'Confirm Return',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _markAsLateReturn(BuildContext context) async {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Mark as Late Return?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'This will flag the return as late.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () async {
              try {
                // Get staff ID
                final prefs = await SharedPreferences.getInstance();
                final userDataString = prefs.getString('current_user');
                int? staffId;

                if (userDataString != null) {
                  final userData = jsonDecode(userDataString);
                  staffId = userData['staff_id'] ?? userData['id'];
                }

                // Move to history with late_return flag
                final response = await http.patch(
                  Uri.parse(
                    'http://10.2.8.26:3000/borrow-requests/${widget.item['request_id']}',
                  ),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({
                    'status': 'Approved',
                    'return_item': true, // Move to history
                    'late_return': true, // Flag as late
                    'staff_processed_return_id': staffId,
                  }),
                );

                Navigator.of(context).pop();

                if (response.statusCode == 200) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Marked as Late Return'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  widget.onRefresh();
                }
              } catch (e) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text(
              'Yes, Mark Late',
              style: GoogleFonts.poppins(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetail(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(text, style: GoogleFonts.poppins(fontSize: 14)),
    );
  }
}
