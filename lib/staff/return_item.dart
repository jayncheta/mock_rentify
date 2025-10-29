import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../browse.dart' show Item;
import '../services/items_service.dart' show ItemsService;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class StaffReturnScreen extends StatefulWidget {
  const StaffReturnScreen({super.key});
  static const String routeName = '/staff/return';

  @override
  State<StaffReturnScreen> createState() => _StaffReturnScreenState();
}

class _StaffReturnScreenState extends State<StaffReturnScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Ensure flags are applied so borrowed items are accurate
    ItemsService.instance.loadDisabledFlags();
    ItemsService.instance.loadBorrowedFlags();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
        title: Text(
          'Return Item',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pushNamed(context, '/staff/history');
            },
            child: Text(
              'History',
              style: GoogleFonts.poppins(color: Colors.black),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pushNamed(context, '/staff/browse');
            },
            child: Text(
              'Browse',
              style: GoogleFonts.poppins(color: Colors.black),
            ),
          ),
          TextButton(
            onPressed: () {
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
            },
            child: Text(
              'Logout',
              style: GoogleFonts.poppins(color: Colors.red),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          children: [
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
    return ValueListenableBuilder<List<Item>>(
      valueListenable: ItemsService.instance.items,
      builder: (context, items, _) {
        final query = _searchController.text.trim().toLowerCase();
        final borrowed = items.where((it) => it.isBorrowed).where((it) {
          if (query.isEmpty) return true;
          return it.title.toLowerCase().contains(query) ||
              it.id.toLowerCase().contains(query);
        }).toList();

        if (borrowed.isEmpty) {
          return Center(
            child: Text(
              'No borrowed items found',
              style: GoogleFonts.poppins(),
            ),
          );
        }

        return ListView.separated(
          itemCount: borrowed.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final it = borrowed[index];
            return _ReturnCard(item: it, onConfirm: () => _confirmReturn(it));
          },
        );
      },
    );
  }

  Future<void> _confirmReturn(Item item) async {
    // 1) Mark item as available
    await ItemsService.instance.setBorrowed(item.id, false);

    // 2) Update user_borrow_history: set returnedAt for latest approved, not-returned record for this item
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('user_borrow_history') ?? <String>[];
    bool updated = false;
    for (int i = list.length - 1; i >= 0; i--) {
      try {
        final Map<String, dynamic> rec = jsonDecode(list[i]);
        final recItem = rec['item'];
        if (recItem is Map<String, dynamic>) {
          final id = (recItem['id'] ?? '').toString();
          final status = (rec['status'] ?? '').toString();
          final returnedAt = rec['returnedAt'];
          if (id == item.id &&
              status == 'Approved' &&
              (returnedAt == null || (returnedAt as String).isEmpty)) {
            rec['returnedAt'] = DateTime.now().toIso8601String();
            list[i] = jsonEncode(rec);
            updated = true;
            break;
          }
        }
      } catch (_) {
        // ignore bad record
      }
    }
    if (updated) {
      await prefs.setStringList('user_borrow_history', list);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Return confirmed and status set to available'),
        ),
      );
    }
  }
}

class _ReturnCard extends StatefulWidget {
  final Item item;
  final VoidCallback onConfirm;
  const _ReturnCard({required this.item, required this.onConfirm});

  @override
  State<_ReturnCard> createState() => _ReturnCardState();
}

class _ReturnCardState extends State<_ReturnCard> {
  bool isChecked = false;

  Future<Map<String, String>> _loadTimes() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('user_borrow_history') ?? <String>[];
    String pickUpTime = '';
    String returnTime = '';
    String borrowerName = '';
    String returnDate = '';
    String approvedBy = '';
    for (int i = list.length - 1; i >= 0; i--) {
      try {
        final Map<String, dynamic> rec = jsonDecode(list[i]);
        final item = rec['item'];
        if (item is Map<String, dynamic>) {
          final id = (item['id'] ?? '').toString();
          final status = (rec['status'] ?? '').toString();
          final returnedAt = rec['returnedAt'];
          if (id == widget.item.id &&
              status == 'Approved' &&
              (returnedAt == null || (returnedAt as String).isEmpty)) {
            pickUpTime = (rec['pickUpTime'] ?? '').toString();
            returnTime = (rec['returnTime'] ?? '').toString();
            borrowerName = (rec['borrowerName'] ?? '').toString();
            returnDate = (rec['returnDate'] ?? '').toString();
            approvedBy = (rec['approvedBy'] ?? '').toString();
            break;
          }
        }
      } catch (_) {
        // ignore malformed entries
      }
    }
    return {
      'pickUpTime': pickUpTime,
      'returnTime': returnTime,
      'borrowerName': borrowerName,
      'returnDate': returnDate,
      'approvedBy': approvedBy,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFBE7D7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Return Confirmation',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          // Borrower name above Item
          FutureBuilder<Map<String, String>>(
            future: _loadTimes(),
            builder: (context, snapshot) {
              final borrowerName = snapshot.data?['borrowerName'] ?? '';
              return _buildDetail(
                'Borrower: '
                '${borrowerName.isNotEmpty ? borrowerName : 'Unknown'}',
              );
            },
          ),
          _buildDetail('Item: ${widget.item.title}'),
          _buildDetail('Item ID: ${widget.item.id}'),
          FutureBuilder<Map<String, String>>(
            future: _loadTimes(),
            builder: (context, snapshot) {
              final returnDate = snapshot.data?['returnDate'] ?? '';
              final pickUpTime = snapshot.data?['pickUpTime'] ?? '';
              final returnTime = snapshot.data?['returnTime'] ?? '';
              final approvedBy = snapshot.data?['approvedBy'] ?? '';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetail(
                    'Return date: '
                    '${returnDate.isNotEmpty ? returnDate : 'Not set'}',
                  ),
                  _buildDetail(
                    'Pick-up time: '
                    '${pickUpTime.isNotEmpty ? pickUpTime : 'Not set'}',
                  ),
                  _buildDetail(
                    'Return time: '
                    '${returnTime.isNotEmpty ? returnTime : 'Not set'}',
                  ),
                  _buildDetail(
                    'Approved by: '
                    '${approvedBy.isNotEmpty ? approvedBy : 'Lender'}',
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Checkbox(
                activeColor: Colors.green,
                value: isChecked,
                onChanged: (value) =>
                    setState(() => isChecked = value ?? false),
              ),
              Text(
                'Item is in good condition',
                style: GoogleFonts.poppins(fontSize: 14),
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
                      horizontal: 24,
                      vertical: 10,
                    ),
                  ),
                  onPressed: () {
                    showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(
                          'Flag as Late Return',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        content: Text(
                          'Flag this item as late return? Action needs to be taken after flagging this item as Late Return',
                          style: GoogleFonts.poppins(),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text('No', style: GoogleFonts.poppins()),
                          ),
                          TextButton(
                            onPressed: () async {
                              // Persist 'lateReturn' flag on the latest approved, not-returned record for this item
                              final prefs =
                                  await SharedPreferences.getInstance();
                              final list =
                                  prefs.getStringList('user_borrow_history') ??
                                  <String>[];
                              bool updated = false;
                              for (int i = list.length - 1; i >= 0; i--) {
                                try {
                                  final Map<String, dynamic> rec = jsonDecode(
                                    list[i],
                                  );
                                  final recItem = rec['item'];
                                  if (recItem is Map<String, dynamic>) {
                                    final id = (recItem['id'] ?? '').toString();
                                    final status = (rec['status'] ?? '')
                                        .toString();
                                    final returnedAt = rec['returnedAt'];
                                    if (id == widget.item.id &&
                                        status == 'Approved' &&
                                        (returnedAt == null ||
                                            (returnedAt as String).isEmpty)) {
                                      rec['lateReturn'] = true;
                                      rec['lateFlaggedAt'] = DateTime.now()
                                          .toIso8601String();
                                      list[i] = jsonEncode(rec);
                                      updated = true;
                                      break;
                                    }
                                  }
                                } catch (_) {
                                  // ignore
                                }
                              }
                              if (updated) {
                                await prefs.setStringList(
                                  'user_borrow_history',
                                  list,
                                );
                              }

                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Item flagged as late return'),
                                ),
                              );
                            },
                            child: Text(
                              'Yes',
                              style: GoogleFonts.poppins(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Text(
                    'Flag as Late',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
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
                      horizontal: 24,
                      vertical: 10,
                    ),
                  ),
                  onPressed: isChecked ? widget.onConfirm : null,
                  child: Text(
                    'Confirm Return (Set Status to Available)',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
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

  Widget _buildDetail(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(text, style: GoogleFonts.poppins(fontSize: 14)),
    );
  }
}
