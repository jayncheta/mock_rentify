import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/items_service.dart';

class StaffDashboardPage extends StatelessWidget {
  static const String routeName = '/staff/dashboard';
  const StaffDashboardPage({super.key});

  Future<int> _getBorrowedTodayCount() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('user_borrow_history') ?? <String>[];
    final now = DateTime.now();
    int count = 0;
    for (final s in list) {
      try {
        final rec = jsonDecode(s) as Map<String, dynamic>;
        final status = (rec['status'] ?? '').toString();
        if (status != 'Approved') continue;
        DateTime? when;
        final approvedAtStr = (rec['approvedAt'] ?? '').toString();
        if (approvedAtStr.isNotEmpty) {
          when = DateTime.tryParse(approvedAtStr);
        }
        when ??= DateTime.tryParse((rec['createdAt'] ?? '').toString());
        if (when == null) continue;
        if (when.year == now.year &&
            when.month == now.month &&
            when.day == now.day) {
          count++;
        }
      } catch (_) {
        // ignore bad record
      }
    }
    return count;
  }

  Future<int> _getPendingRequestCount() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('user_borrow_history') ?? <String>[];
    int count = 0;
    for (final s in list) {
      try {
        final rec = jsonDecode(s) as Map<String, dynamic>;
        final status = (rec['status'] ?? '').toString();
        if (status == 'Pending') {
          count++;
        }
      } catch (_) {
        // ignore bad record
      }
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: Colors.grey[200],
            child: IconButton(
              icon: const Icon(Icons.person),
              onPressed: () {
                // Already on dashboard
              },
            ),
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
              Navigator.pushNamed(context, '/staff/return');
            },
            child: Text(
              'Return',
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
      body: ValueListenableBuilder(
        valueListenable: ItemsService.instance.items,
        builder: (context, items, child) {
          // Calculate stats
          final availableCount = items
              .where((item) => !item.isDisabled && !item.isBorrowed)
              .length;
          final disabledCount = items.where((item) => item.isDisabled).length;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dashboard',
                  style: GoogleFonts.poppins(
                    fontSize: 50,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),

                // --- Grid of Stats ---
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1,
                    children: [
                      FutureBuilder<int>(
                        future: _getBorrowedTodayCount(),
                        builder: (context, snapshot) {
                          final borrowedToday = snapshot.data ?? 0;
                          return _buildStatCard(
                            '$borrowedToday',
                            'Borrowed Today',
                            const Color(0xFFFF8C42),
                          );
                        },
                      ),
                      _buildStatCard(
                        '$availableCount',
                        'Available',
                        const Color(0xFF00BFA6),
                      ),
                      _buildStatCard(
                        '$disabledCount',
                        'Disabled',
                        const Color(0xFFE53935),
                      ),
                      FutureBuilder<int>(
                        future: _getPendingRequestCount(),
                        builder: (context, snapshot) {
                          final pendingCount = snapshot.data ?? 0;
                          return _buildStatCard(
                            '$pendingCount',
                            'Pending Request',
                            const Color(0xFF26A69A),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String number, String label, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              number,
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
