# Backend Integration Guide - User Module

## Overview
All user-related files have been refactored to be backend-ready. The business logic has been extracted into a service layer (`UserBorrowService`) that currently uses SharedPreferences but is designed to be easily replaced with HTTP API calls.

## Files Updated

### 1. **Service Layer**
- `lib/services/user_service.dart` - New centralized service for all user borrow operations

### 2. **User UI Files** 
- `lib/user/borrow_request.dart` - Borrow request form
- `lib/user/user_borrowing.dart` - Confirmation screen with submit functionality
- `lib/user/user_profile.dart` - User profile with statistics
- `lib/user/user_request.dart` - Active requests list
- `lib/user/user_history.dart` - Completed rentals history

### 3. **Lender Files**
- `lib/lender/lender_review.dart` - Already updated with `BorrowRequestService`

## Service Architecture

### UserBorrowService Methods

All methods are clearly documented with TODO comments showing the exact API endpoints to implement.

#### 1. **Create Borrow Request**
```dart
Future<bool> createBorrowRequest({
  required String userId,
  required Map<String, dynamic> item,
  required String borrowerName,
  required String borrowDate,
  required String pickUpTime,
  required String returnDate,
  required String returnTime,
  required String reason,
})
```
**Backend API:** `POST /api/borrow-requests`

**Request Body:**
```json
{
  "userId": "user_id",
  "itemId": "item_id",
  "borrowDate": "01/12/24",
  "returnDate": "05/12/24",
  "pickUpTime": "10:00",
  "returnTime": "15:00",
  "reason": "Need for class presentation"
}
```

**Response:**
```json
{
  "id": "req_123",
  "status": "Pending",
  "createdAt": "2024-12-01T10:00:00Z"
}
```

---

#### 2. **Get User Borrow Requests**
```dart
Future<List<Map<String, dynamic>>> getUserBorrowRequests({
  String? userId,
  String? status,
  bool includeReturned = true,
})
```
**Backend API:** `GET /api/users/{userId}/borrow-requests`

**Query Parameters:**
- `status` - Optional: "Pending", "Approved", "Rejected"
- `includeReturned` - Boolean to include completed rentals

**Response:**
```json
{
  "data": [
    {
      "id": "req_123",
      "userId": "user_id",
      "item": {
        "id": "item_id",
        "title": "MacBook Pro",
        "imageUrl": "...",
        "category": "Laptops"
      },
      "borrowerName": "John Doe",
      "borrowDate": "01/12/24",
      "returnDate": "05/12/24",
      "pickUpTime": "10:00",
      "returnTime": "15:00",
      "reason": "Need for class presentation",
      "status": "Pending",
      "createdAt": "2024-12-01T10:00:00Z",
      "approvedAt": null,
      "returnedAt": null,
      "lateReturn": false
    }
  ]
}
```

---

#### 3. **Get User Statistics**
```dart
Future<Map<String, int>> getUserStats({String? userId})
```
**Backend API:** `GET /api/users/{userId}/borrow-stats`

**Response:**
```json
{
  "currentlyRenting": 2,
  "lateReturns": 1,
  "onTimeReturns": 5,
  "totalRentHistory": 6,
  "hasActiveLate": false
}
```

---

#### 4. **Check Active Late Returns**
```dart
Future<bool> hasActiveLateReturn({String? userId})
```
**Backend API:** `GET /api/users/{userId}/has-active-late`

**Response:**
```json
{
  "hasActiveLate": true
}
```

---

#### 5. **Cancel Borrow Request**
```dart
Future<bool> cancelBorrowRequest({
  required String requestId,
  String? userId,
})
```
**Backend API:** `DELETE /api/borrow-requests/{requestId}`
OR `PATCH /api/borrow-requests/{requestId}` with `status: "Cancelled"`

**Response:**
```json
{
  "success": true,
  "message": "Request cancelled successfully"
}
```

---

#### 6. **Get User History**
```dart
Future<List<Map<String, dynamic>>> getUserHistory({
  String? userId,
  String? searchQuery,
})
```
**Backend API:** `GET /api/users/{userId}/borrow-history`

**Query Parameters:**
- `search` - Optional search term for filtering

**Response:** Same structure as getUserBorrowRequests

---

## UI Features Implemented

### ✅ Loading States
- CircularProgressIndicator shown during data fetch
- LinearProgressIndicator for background refreshes
- Buttons disabled during operations

### ✅ Error Handling
- Error messages displayed to users
- Retry buttons for failed operations
- Fallback to empty states

### ✅ Success Feedback
- SnackBar notifications for successful operations
- Color-coded feedback (green = success, red = error)
- Automatic navigation after success

### ✅ User Experience
- Pull-to-refresh capability
- Search functionality
- Tab filtering (All, Pending, Approved, Rejected)
- Empty state messages
- Confirmation dialogs for destructive actions

---

## Migration Steps

### Step 1: Add HTTP Package
```yaml
# pubspec.yaml
dependencies:
  http: ^1.1.0  # or latest version
```

### Step 2: Create API Service Base
```dart
// lib/services/api_service.dart
import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiService {
  static const String baseUrl = 'https://your-api.com';
  
  // Add auth token from your auth service
  static String? _authToken;
  
  static void setAuthToken(String token) {
    _authToken = token;
  }
  
  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    if (_authToken != null) 'Authorization': 'Bearer $_authToken',
  };
  
  static Future<Map<String, dynamic>> get(String endpoint) async {
    final response = await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: headers,
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load data: ${response.statusCode}');
    }
  }
  
  static Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: headers,
      body: jsonEncode(body),
    );
    
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to post data: ${response.statusCode}');
    }
  }
  
  // Add patch, delete methods similarly
}
```

### Step 3: Update UserBorrowService
Replace SharedPreferences calls with API calls:

```dart
// Example: Update createBorrowRequest
Future<bool> createBorrowRequest({
  required String userId,
  required Map<String, dynamic> item,
  required String borrowerName,
  required String borrowDate,
  required String pickUpTime,
  required String returnDate,
  required String returnTime,
  required String reason,
}) async {
  try {
    final response = await ApiService.post(
      '/api/borrow-requests',
      {
        'userId': userId,
        'itemId': item['id'],
        'borrowDate': borrowDate,
        'returnDate': returnDate,
        'pickUpTime': pickUpTime,
        'returnTime': returnTime,
        'reason': reason,
      },
    );
    
    debugPrint('✅ Borrow request created: ${response['id']}');
    return true;
  } catch (e) {
    debugPrint('❌ Error creating borrow request: $e');
    return false;
  }
}

// Example: Update getUserBorrowRequests
Future<List<Map<String, dynamic>>> getUserBorrowRequests({
  String? userId,
  String? status,
  bool includeReturned = true,
}) async {
  try {
    final queryParams = <String, String>{};
    if (status != null) queryParams['status'] = status;
    if (!includeReturned) queryParams['includeReturned'] = 'false';
    
    final query = queryParams.entries
        .map((e) => '${e.key}=${e.value}')
        .join('&');
    
    final endpoint = '/api/users/$userId/borrow-requests${query.isNotEmpty ? '?$query' : ''}';
    final response = await ApiService.get(endpoint);
    
    return List<Map<String, dynamic>>.from(response['data']);
  } catch (e) {
    debugPrint('❌ Error loading user borrow requests: $e');
    return [];
  }
}
```

### Step 4: Add Authentication Integration
Update all `userId: 'current_user_id'` placeholders:

```dart
// Example in user_borrowing.dart
final success = await _borrowService.createBorrowRequest(
  userId: AuthService.instance.currentUserId, // Get from your auth service
  item: {...},
  borrowerName: AuthService.instance.currentUserName, // Get from your auth service
  // ... rest of parameters
);
```

### Step 5: Test Integration
1. Test each endpoint individually
2. Handle network errors gracefully
3. Add timeout handling
4. Test with slow network conditions
5. Verify error messages are user-friendly

---

## Benefits of This Architecture

### 🎯 **Single Source of Truth**
All data operations go through `UserBorrowService` - easy to maintain and debug

### 🔄 **Easy Migration**
UI code doesn't need changes when switching from local to remote data

### 🛡️ **Error Handling**
Centralized error handling with consistent user feedback

### 📱 **Better UX**
Loading states, error states, and success feedback built in

### 🧪 **Testable**
Service layer can be mocked for unit testing

### 📝 **Well Documented**
Every method has clear API endpoint documentation with request/response examples

---

## Current State

✅ All user files refactored  
✅ Service layer created  
✅ Loading/error states implemented  
✅ API endpoints documented  
✅ Success/error feedback added  
✅ Search functionality integrated  
✅ No breaking changes to existing features  

## Next Steps

1. Set up backend API server
2. Create API endpoints matching the documented structure
3. Add `http` package to pubspec.yaml
4. Create `ApiService` base class
5. Replace SharedPreferences calls in `UserBorrowService`
6. Add authentication token management
7. Test all endpoints
8. Deploy and monitor

---

## Notes

- All TODO comments in the code mark areas that need backend integration
- Current implementation still works with SharedPreferences as fallback
- No UI changes needed when migrating to backend
- Debug logging (debugPrint) added for development tracking
- Consider adding retry logic and request queuing for offline support
- Add response caching for better performance
- Implement proper error types for different failure scenarios

---

**Ready for Backend Integration! 🚀**
