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

    // Count across ALL items. Currently renting is the actual count of active approved rentals.
    int currentlyRenting = 0;
    int lateReturns = 0;
    int onTimeReturns = 0;
    int rentHistory = 0;

    final df = DateFormat('dd/MM/yy');

    for (final s in list) {
      Map<String, dynamic> r;
      try {
        r = jsonDecode(s) as Map<String, dynamic>;
      } catch (_) {
        continue;
      }

      // Basic item structure check
      final itm = r['item'];
      if (itm is! Map<String, dynamic>) continue;

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

      final isFlaggedLate = (r['lateReturn'] ?? false) == true;

      if (returnedAt != null) {
        // Completed rentals only
        rentHistory += 1;

        // Determine late strictly by due date vs returnedAt when available.
        // Fallback: if no plannedReturn provided, treat explicit 'Late Return' status/flag as late.
        final bool isLateByDate =
            plannedReturn != null && returnedAt.isAfter(plannedReturn);
        final bool explicitLate =
            (r['status']?.toString() == 'Late Return') || isFlaggedLate;

        if (isLateByDate || (plannedReturn == null && explicitLate)) {
          lateReturns += 1;
        } else {
          onTimeReturns += 1;
        }
      } else {
        // Active rentals: only contribute to 'Currently Renting' (binary), not late/on-time counters
        if (status == 'Approved') {
          // Count as currently renting regardless of due date status; do not add to Rent History
          currentlyRenting += 1;
        }
      }
    }

    // currentlyRenting already holds the count of active rentals

    return {
      'currently': currentlyRenting,
      'late': lateReturns,
      'history': rentHistory,
      'ontime': onTimeReturns,
    };
  }

  Future<bool> _hasActiveLate() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('user_borrow_history') ?? [];
    for (final s in list) {
      try {
        final r = jsonDecode(s) as Map<String, dynamic>;
        final status = (r['status'] ?? '').toString();
        final returnedAt = r['returnedAt'];
        final late = (r['lateReturn'] ?? false) == true;
        if (status == 'Approved' &&
            (returnedAt == null || returnedAt.toString().isEmpty) &&
            late) {
          return true;
        }
      } catch (_) {
        continue;
      }
    }
    return false;
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
                Navigator.pushNamed(context, '/user/request');
              },
              child: Text(
                'Request',
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
            const SizedBox(height: 8),
            FutureBuilder<bool>(
              future: _hasActiveLate(),
              builder: (context, snapshot) {
                final show = snapshot.data == true;
                if (!show) return const SizedBox.shrink();
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.redAccent),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You have an item late for return',
                          style: GoogleFonts.poppins(
                            color: Colors.red[900],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
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
                      GestureDetector(
                        onTap: () =>
                            Navigator.pushNamed(context, '/user/history'),
                        child: _buildStatCard(
                          '${counts['history']}',
                          'Rent History',
                          const Color(0xFF00BFA6),
                        ),
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
