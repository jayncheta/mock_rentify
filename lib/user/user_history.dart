import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/user_service.dart';

class UserHistoryPage extends StatefulWidget {
  static const String routeName = '/user/history';
  const UserHistoryPage({super.key});

  @override
  State<UserHistoryPage> createState() => _UserHistoryPageState();
}

class _UserHistoryPageState extends State<UserHistoryPage> {
  final UserBorrowService _borrowService = UserBorrowService();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allHistory = [];
  List<Map<String, dynamic>> _filteredHistory = [];
  bool _isLoading = false;
  String? _errorMessage;

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
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // TODO: Get userId from auth service
      final history = await _borrowService.getUserHistory(
        userId: 'current_user_id',
      );

      if (mounted) {
        setState(() {
          _allHistory = history;
          _filteredHistory = history;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load history: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _filterHistory() {
    final query = _searchController.text.trim();
    setState(() {
      if (query.isEmpty) {
        _filteredHistory = _allHistory;
      } else {
        // Use the service's search capability
        _loadHistoryWithSearch(query);
      }
    });
  }

  Future<void> _loadHistoryWithSearch(String query) async {
    try {
      // TODO: Get userId from auth service
      final history = await _borrowService.getUserHistory(
        userId: 'current_user_id',
        searchQuery: query,
      );

      if (mounted) {
        setState(() {
          _filteredHistory = history;
        });
      }
    } catch (e) {
      // Keep current filtered results on error
      debugPrint('Error searching history: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text('Rent History', style: GoogleFonts.poppins()),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadHistory,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _allHistory.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: GoogleFonts.poppins(color: Colors.red[700]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadHistory,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Padding(
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
                          ? 'No borrow history yet.'
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
                      final borrowerName = rec['borrowerName'] ?? 'You';
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
                        statusText = 'Active';
                        statusColor = Colors.orange;
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
                            '${returnedAt != null ? 'Returned: ${returnedAt.toString().split('T')[0]}' : 'Status: Active'}',
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
    );
  }
}
