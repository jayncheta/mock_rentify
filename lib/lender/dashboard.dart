import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/items_service.dart';
import 'lender_profile.dart';

class DashboardPage extends StatelessWidget {
  static const String routeName = '/lender/dashboard';
  const DashboardPage({super.key});

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
          final availableCount = items.where((item) => !item.isDisabled).length;
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
                      _buildStatCard(
                        '0',
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
                        '0',
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
