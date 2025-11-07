import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

/// Service for all user borrow operations - Connected to backend
class UserBorrowService {
  static final UserBorrowService _instance = UserBorrowService._internal();
  factory UserBorrowService() => _instance;
  UserBorrowService._internal();

  // Backend API base URL - Your server IP address
  static const String _baseUrl = 'http://172.27.9.184:3000';

  /// Create a new borrow request
  /// Connects to: POST /borrow-request
  Future<bool> createBorrowRequest({
    required String userId,
    required Map<String, dynamic> item,
    required String borrowerName,
    required String borrowDate,
    required String returnDate,
    required String reason,
  }) async {
    try {
      final itemId = item['id']?.toString() ?? '';
      final lenderId = item['lenderId']?.toString() ?? '1'; // Default lender ID

      final response = await http.post(
        Uri.parse('$_baseUrl/borrow-request'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'item_id': itemId,
          'borrower_id': userId,
          'lender_id': lenderId,
          'borrower_reason': reason,
          'borrow_date': borrowDate,
          'return_date': returnDate,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('✅ Borrow request created: ${data['request_id']}');
        return true;
      } else {
        debugPrint('❌ Error creating borrow request: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error creating borrow request: $e');
      return false;
    }
  }

  /// Login user
  /// Connects to: POST /login
  Future<Map<String, dynamic>?> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body) as Map<String, dynamic>;

        // Store user info locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('current_user', jsonEncode(userData));

        debugPrint('✅ Login successful: ${userData['username']}');
        return userData;
      } else if (response.statusCode == 403) {
        debugPrint('❌ Invalid login credentials');
        return null;
      } else {
        debugPrint('❌ Login error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error during login: $e');
      return null;
    }
  }

  /// Get current logged-in user from local storage
  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userStr = prefs.getString('current_user');
      if (userStr != null) {
        final user = jsonDecode(userStr) as Map<String, dynamic>;
        debugPrint('👤 Current user data: $user');
        debugPrint('👤 User ID: ${user['id']} or ${user['user_id']}');
        return user;
      }
      debugPrint('⚠️ No user data found in SharedPreferences');
      return null;
    } catch (e) {
      debugPrint('❌ Error getting current user: $e');
      return null;
    }
  }

  /// Get user info by ID
  /// Connects to: GET /users/:id
  Future<Map<String, dynamic>?> getUserInfo(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/users/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('✅ User info retrieved: ${userData['username']}');
        return userData;
      } else if (response.statusCode == 404) {
        debugPrint('❌ User not found');
        return null;
      } else {
        debugPrint('❌ Error getting user info: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error getting user info: $e');
      return null;
    }
  }

  /// Logout user
  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('current_user');
      debugPrint('✅ User logged out');
    } catch (e) {
      debugPrint('❌ Error during logout: $e');
    }
  }

  /// Sign up new user
  /// Connects to: POST /signup
  Future<Map<String, dynamic>?> signup({
    required String username,
    required String email,
    required String password,
    String? fullName,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
          'full_name': fullName ?? username,
        }),
      );

      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body) as Map<String, dynamic>;

        // Store user info locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('current_user', jsonEncode(userData));

        debugPrint('✅ Signup successful: ${userData['username']}');
        return userData;
      } else if (response.statusCode == 409) {
        debugPrint('❌ Username or email already exists');
        return null;
      } else if (response.statusCode == 400) {
        debugPrint('❌ Missing required fields');
        return null;
      } else {
        debugPrint('❌ Signup error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error during signup: $e');
      return null;
    }
  }

  /// Get all borrow requests for a user
  /// Query params: ?status=Pending|Approved|Rejected&includeReturned=true
  Future<List<Map<String, dynamic>>> getUserBorrowRequests({
    String? userId,
    String? status,
    bool includeReturned = true,
  }) async {
    try {
      // Get user ID if not provided
      String? uid = userId;
      if (uid == null) {
        final user = await getCurrentUser();
        // Try both 'id' and 'user_id' fields
        uid = user?['id']?.toString() ?? user?['user_id']?.toString();
        debugPrint('🔍 Retrieved user ID from getCurrentUser: $uid');
      }

      if (uid == null) {
        debugPrint('⚠️ No user ID available');
        return [];
      }

      debugPrint('🔄 Fetching borrow requests from backend for user $uid...');

      // Build the URL with optional status filter
      String url = '$_baseUrl/users/$uid/borrow-requests';
      if (status != null) {
        url += '?status=$status';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        debugPrint('✅ Fetched ${data.length} borrow requests from backend');

        // Convert to List<Map<String, dynamic>>
        List<Map<String, dynamic>> requests = data
            .map((e) => e as Map<String, dynamic>)
            .toList();

        // Filter out returned items if specified
        if (!includeReturned) {
          requests = requests.where((req) {
            final reqStatus = req['status']?.toString().toLowerCase();
            return reqStatus != 'returned';
          }).toList();
        }

        return requests;
      } else {
        debugPrint('❌ Failed to fetch borrow requests: ${response.statusCode}');
        debugPrint('Response: ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('❌ Error loading user borrow requests: $e');
      return [];
    }
  }

  /// Get user statistics
  /// Response: {
  ///   "currentlyRenting": 2,
  ///   "lateReturns": 1,
  ///   "onTimeReturns": 5,
  ///   "totalRentHistory": 6,
  ///   "hasActiveLate": false
  /// }
  Future<Map<String, int>> getUserStats({String? userId}) async {
    try {
      // Get user ID if not provided
      String? uid = userId;
      if (uid == null) {
        final user = await getCurrentUser();
        uid = user?['id']?.toString() ?? user?['user_id']?.toString();
      }

      if (uid == null) {
        debugPrint('⚠️ No user ID available for stats');
        return {'currently': 0, 'late': 0, 'history': 0, 'ontime': 0};
      }

      // Fetch borrow requests from backend
      final requests = await getUserBorrowRequests(userId: uid);

      int currentlyRenting = 0;
      int lateReturns = 0;
      int onTimeReturns = 0;
      int rentHistory = 0;

      for (final request in requests) {
        final status = (request['status'] ?? '').toString();

        // Count based on status
        if (status == 'Approved') {
          currentlyRenting += 1;
        } else if (status == 'Returned') {
          rentHistory += 1;
          onTimeReturns += 1; // Assume on-time for now
        }
      }

      debugPrint(
        '📊 User stats: currently=$currentlyRenting, late=$lateReturns, history=$rentHistory, ontime=$onTimeReturns',
      );

      return {
        'currently': currentlyRenting,
        'late': lateReturns,
        'history': rentHistory,
        'ontime': onTimeReturns,
      };
    } catch (e) {
      debugPrint('❌ Error getting user stats: $e');
      return {'currently': 0, 'late': 0, 'history': 0, 'ontime': 0};
    }
  }

  /// Check if user has any active late returns
  Future<bool> hasActiveLateReturn({String? userId}) async {
    try {
      // Get user ID if not provided
      String? uid = userId;
      if (uid == null) {
        final user = await getCurrentUser();
        uid = user?['id']?.toString() ?? user?['user_id']?.toString();
      }

      if (uid == null) {
        debugPrint('⚠️ No user ID available for late check');
        return false;
      }

      // Fetch borrow requests from backend
      final requests = await getUserBorrowRequests(userId: uid);

      // Check if any approved request is marked as late
      for (final request in requests) {
        final status = (request['status'] ?? '').toString();
        final late = (request['lateReturn'] ?? false) == true;

        if (status == 'Approved' && late) {
          return true;
        }
      }

      return false;
    } catch (e) {
      debugPrint('❌ Error checking active late returns: $e');
      return false;
    }
  }

  /// Cancel a pending borrow request
  /// PATCH /borrow-requests/{requestId} with status: "Canceled"
  Future<bool> cancelBorrowRequest({required String requestId}) async {
    try {
      debugPrint('🔄 Canceling borrow request $requestId...');

      final response = await http.patch(
        Uri.parse('$_baseUrl/borrow-requests/$requestId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': 'Canceled'}),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Borrow request $requestId canceled successfully');
        return true;
      } else {
        debugPrint('❌ Failed to cancel request: ${response.statusCode}');
        debugPrint('Response: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error canceling borrow request: $e');
      return false;
    }
  }

  /// Get borrow history (completed rentals only)
  Future<List<Map<String, dynamic>>> getUserHistory({
    String? userId,
    String? searchQuery,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('user_borrow_history') ?? [];
      final history = <Map<String, dynamic>>[];

      for (final s in list) {
        try {
          final rec = jsonDecode(s) as Map<String, dynamic>;
          final status = (rec['status'] ?? '').toString();

          // Include approved and returned items
          if (status == 'Approved' || (rec['returnedAt'] != null)) {
            // Apply search filter if provided
            if (searchQuery != null && searchQuery.isNotEmpty) {
              final item = rec['item'];
              if (item is Map<String, dynamic>) {
                final id = (item['id'] ?? '').toString().toLowerCase();
                final title = (item['title'] ?? '').toString().toLowerCase();
                final query = searchQuery.toLowerCase();

                if (id.contains(query) || title.contains(query)) {
                  history.add(rec);
                }
              }
            } else {
              history.add(rec);
            }
          }
        } catch (_) {
          continue;
        }
      }

      return history;
    } catch (e) {
      debugPrint('❌ Error loading user history: $e');
      return [];
    }
  }
}
