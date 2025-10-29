import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/items_service.dart';
import 'lender_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class DashboardPage extends StatelessWidget {
  static const String routeName = '/lender/dashboard';
  const DashboardPage({super.key});

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
        // ignore malformed record
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
        if (status == 'Pending') count++;
      } catch (_) {
        // ignore malformed record
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pushNamed(context, LenderProfilePage.routeName);
          },
        ),
      ),
      body: ValueListenableBuilder(
        valueListenable: ItemsService.instance.items,
        builder: (context, items, child) {
          // Calculate stats
          // Available means not disabled and not borrowed
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
