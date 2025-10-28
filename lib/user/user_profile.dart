import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePage extends StatelessWidget {
  static const String routeName = '/user/profile';
  const ProfilePage({super.key});

  Future<Map<String, int>> _getCounts() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('user_borrow_history') ?? [];

    // We'll count only Windows laptop entries and make currently renting binary (0/1).
    int currentlyRenting = 0;
    int lateReturns = 0;
    int onTimeReturns = 0;
    int rentHistory = 0;

    final df = DateFormat('dd/MM/yy');
    final today = DateTime.now();
    final todayDateOnly = DateTime(today.year, today.month, today.day);

    bool hasActiveCurrent =
        false; // track if any active Windows laptop rental exists

    for (final s in list) {
      Map<String, dynamic> r;
      try {
        r = jsonDecode(s) as Map<String, dynamic>;
      } catch (_) {
        continue;
      }

      // Filter to Windows laptop only
      final itm = r['item'];
      if (itm is! Map<String, dynamic>) continue;
      final title = (itm['title'] ?? '').toString().toLowerCase();
      if (!title.contains('windows laptop')) continue;

      final status = (r['status'] ?? '').toString();

      // planned return date
      DateTime? plannedReturn;
      final plannedReturnStr = (r['returnDate'] ?? '').toString();
      if (plannedReturnStr.isNotEmpty) {
        try {
          plannedReturn = df.parse(plannedReturnStr);
        } catch (_) {}
      }

      // if present, indicates a completed rental
      DateTime? returnedAt;
      final returnedAtStr = (r['returnedAt'] ?? '').toString();
      if (returnedAtStr.isNotEmpty) {
        try {
          returnedAt = DateTime.parse(returnedAtStr);
        } catch (_) {}
      }

      if (returnedAt != null) {
        // Count only Windows laptop returns
        rentHistory += 1;
        if (plannedReturn != null && returnedAt.isAfter(plannedReturn)) {
          lateReturns += 1;
        } else {
          onTimeReturns += 1;
        }
      } else {
        // Not returned yet; consider as active only when approved and not past planned return
        if (status == 'Approved') {
          if (plannedReturn == null || !plannedReturn.isBefore(todayDateOnly)) {
            hasActiveCurrent = true;
          }
        }
      }
    }

    // Binary currently renting: 1 if any active approved Windows laptop rental exists, else 0
    currentlyRenting = hasActiveCurrent ? 1 : 0;

    return {
      'currently': currentlyRenting,
      'late': lateReturns,
      'history': rentHistory,
      'ontime': onTimeReturns,
    };
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
                onPressed: () {},
              ),
            ),
          ),
          title: const SizedBox.shrink(),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, '/browse');
              },
              child: Text(
                'Browse',
                style: GoogleFonts.poppins(color: Colors.black),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, '/user/history');
              },
              child: Text(
                'History',
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
              },
              child: Text(
                'Logout',
                style: GoogleFonts.poppins(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Profile',
              style: GoogleFonts.poppins(
                fontSize: 50,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // --- Grid of Stats (live) ---
            Expanded(
              child: FutureBuilder<Map<String, int>>(
                future: _getCounts(),
                builder: (context, snapshot) {
                  final counts =
                      snapshot.data ??
                      {'currently': 0, 'late': 0, 'history': 0, 'ontime': 0};
                  return GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1,
                    children: [
                      _buildStatCard(
                        '${counts['currently']}',
                        'Currently Renting',
                        const Color(0xFFFF8C42),
                      ),
                      _buildStatCard(
                        '${counts['late']}',
                        'Late Returns',
                        const Color(0xFFE53935),
                      ),
                      _buildStatCard(
                        '${counts['history']}',
                        'Rent History',
                        const Color(0xFF00BFA6),
                      ),
                      _buildStatCard(
                        '${counts['ontime']}',
                        'On time Returns',
                        const Color(0xFF26A69A),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
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
