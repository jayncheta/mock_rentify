import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../services/user_service.dart';
import 'add.dart' show AddItemsScreen;

class StaffDashboardPage extends StatefulWidget {
  static const String routeName = '/staff/dashboard';
  const StaffDashboardPage({super.key});

  @override
  State<StaffDashboardPage> createState() => _StaffDashboardPageState();
}

class _StaffDashboardPageState extends State<StaffDashboardPage> {
  String _staffName = 'Staff';

  @override
  void initState() {
    super.initState();
    _loadStaffName();
  }

  Future<void> _loadStaffName() async {
    try {
      final user = await UserBorrowService().getCurrentUser();
      if (user != null && mounted) {
        setState(() {
          _staffName = user['full_name'] ?? user['username'] ?? 'Staff';
        });
      }
    } catch (e) {
      // Use default name
    }
  }

  Future<int> _getBorrowedTodayCount() async {
    try {
      final response = await http.get(
        Uri.parse('http://10.2.8.26:3000/borrow-requests'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> requests = jsonDecode(response.body);

        // Count currently borrowed items (Approved and not yet returned)
        return requests.where((req) {
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
    try {
      final response = await http.get(
        Uri.parse('http://10.2.8.26:3000/borrow-requests'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> requests = jsonDecode(response.body);
        return requests.where((req) => req['status'] == 'Pending').length;
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
        int borrowed = 0;
        int disabled = 0;

        for (var item in items) {
          final status = item['availability_status'] ?? '';
          if (status == 'Available')
            available++;
          else if (status == 'Borrowed')
            borrowed++;
          else if (status == 'Disabled')
            disabled++;
        }

        return {
          'available': available,
          'borrowed': borrowed,
          'disabled': disabled,
          'total': items.length,
        };
      }
    } catch (e) {
      // Ignore error
    }
    return {'available': 0, 'borrowed': 0, 'disabled': 0, 'total': 0};
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
      body: FutureBuilder<Map<String, dynamic>>(
        future:
            Future.wait([
              _getBorrowedTodayCount(),
              _getPendingRequestCount(),
              _getItemCounts(),
            ]).then((results) {
              return {
                'borrowedToday': results[0] as int,
                'pendingRequests': results[1] as int,
                'itemCounts': results[2] as Map<String, int>,
              };
            }),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!;
          final borrowedToday = data['borrowedToday'] as int;
          final pendingRequests = data['pendingRequests'] as int;
          final itemCounts = data['itemCounts'] as Map<String, int>;
          final availableCount = itemCounts['available'] ?? 0;
          final disabledCount = itemCounts['disabled'] ?? 0;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_staffName\'s Dashboard',
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
                      _buildStatCard(
                        '$borrowedToday',
                        'Borrowed Today',
                        const Color(0xFFFF8C42),
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
                      _buildStatCard(
                        '$pendingRequests',
                        'Pending Request',
                        const Color(0xFF26A69A),
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
