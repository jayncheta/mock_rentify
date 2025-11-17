import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'lender_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardPage extends StatefulWidget {
  static const String routeName = '/lender/dashboard';
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int? _lenderId;

  @override
  void initState() {
    super.initState();
    _loadLenderInfo();
  }

  Future<void> _loadLenderInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('current_user');
    if (userDataString != null) {
      final userData = jsonDecode(userDataString) as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _lenderId = userData['lender_id'] ?? userData['id'];
        });
      }
    }
  }

  Future<int> _getBorrowedTodayCount() async {
    if (_lenderId == null) return 0;

    try {
      final response = await http.get(
        Uri.parse('http://10.2.8.26:3000/borrow-requests'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> requests = jsonDecode(response.body);

        // Count currently borrowed items (Approved and not yet returned)
        return requests.where((req) {
          // Filter by lender_id
          if (req['lender_id'] != _lenderId) return false;
          if (req['status'] != 'Approved') return false;
          if (req['returned_at'] != null)
            return false; // Exclude returned items
          return true;
        }).length;
      }
    } catch (e) {
      // Ignore error
    }
    return 0;
  }

  Future<int> _getPendingRequestCount() async {
    if (_lenderId == null) return 0;

    try {
      final response = await http.get(
        Uri.parse('http://10.2.8.26:3000/borrow-requests'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> requests = jsonDecode(response.body);
        return requests
            .where(
              (req) =>
                  req['lender_id'] == _lenderId && req['status'] == 'Pending',
            )
            .length;
      }
    } catch (e) {
      // Ignore error
    }
    return 0;
  }

  Future<Map<String, int>> _getItemCounts() async {
    try {
      final response = await http.get(
        Uri.parse('http://10.2.8.26:3000/items?includeDisabled=true'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> items = jsonDecode(response.body);
        int available = 0;
        int disabled = 0;

        for (var item in items) {
          final status = item['availability_status'] ?? '';
          if (status == 'Available') {
            available++;
          } else if (status == 'Unavailable' || status == 'Disabled') {
            disabled++;
          }
        }

        return {'available': available, 'disabled': disabled};
      }
    } catch (e) {
      // Ignore error
    }
    return {'available': 0, 'disabled': 0};
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
      body: Padding(
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
              child: FutureBuilder<Map<String, int>>(
                future: _getItemCounts(),
                builder: (context, itemSnapshot) {
                  final itemCounts =
                      itemSnapshot.data ?? {'available': 0, 'disabled': 0};
                  final availableCount = itemCounts['available'] ?? 0;
                  final disabledCount = itemCounts['disabled'] ?? 0;

                  return GridView.count(
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
