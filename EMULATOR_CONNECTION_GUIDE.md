# Emulator Connection Guide - LDPlayer

## Backend Server Configuration
- **Server IP**: `172.25.7.206`
- **Server Port**: `3000`
- **Base URL**: `http://172.25.7.206:3000`

## Prerequisites
1. Your backend server must be running on `http://172.25.7.206:3000`
2. LDPlayer emulator must be running
3. Your PC firewall should allow connections on port 3000

## Starting Your Backend Server
```bash
cd c:\Users\Jay\Desktop\MFU\mock_rentify\mock_rentify\backend
npm start
```

The server should start and show:
```
Server is running on port 3000
Connected to the database.
```

## Running the Flutter App on LDPlayer
```bash
cd c:\Users\Jay\Desktop\MFU\mock_rentify\mock_rentify
flutter run
```

Select the LDPlayer device when prompted.

## Testing the Connection

### 1. Test Backend Connection (from PowerShell)
```powershell
# Test if backend is accessible
Invoke-WebRequest -Uri "http://172.25.7.206:3000/items" -Method GET
```

### 2. Available API Endpoints

#### Get Available Items
```
GET http://172.25.7.206:3000/items
```

#### Login
```
POST http://172.25.7.206:3000/login
Body: {
  "username": "your_username",
  "password": "your_password"
}
```

#### Get User Info
```
GET http://172.25.7.206:3000/users/{id}
```

#### Create Borrow Request
```
POST http://172.25.7.206:3000/borrow-request
Body: {
  "item_id": "item_id",
  "borrower_id": "user_id",
  "lender_id": "lender_id",
  "borrower_reason": "reason for borrowing"
}
```

## Updated Service Methods

### UserBorrowService Methods Connected to Backend:

1. **login()** - Authenticates user and stores session
   ```dart
   final userData = await UserBorrowService().login(
     username: 'testuser',
     password: 'password123',
   );
   ```

2. **createBorrowRequest()** - Creates a borrow request in database
   ```dart
   final success = await UserBorrowService().createBorrowRequest(
     userId: '1',
     item: {'id': 'item123', 'title': 'MacBook'},
     borrowerName: 'John Doe',
     borrowDate: '01/11/25',
     pickUpTime: '10:00 AM',
     returnDate: '05/11/25',
     returnTime: '5:00 PM',
     reason: 'Need for project work',
   );
   ```

3. **getUserInfo()** - Fetches user details from database
   ```dart
   final userInfo = await UserBorrowService().getUserInfo('1');
   ```

4. **getCurrentUser()** - Gets currently logged-in user from local storage
   ```dart
   final currentUser = await UserBorrowService().getCurrentUser();
   ```

5. **logout()** - Clears user session
   ```dart
   await UserBorrowService().logout();
   ```

## Troubleshooting

### Connection Refused
- Make sure backend server is running
- Check if IP address `172.25.7.206` is correct
- Verify firewall allows connections on port 3000

### Timeout Error
- Check network connectivity between emulator and PC
- LDPlayer might need network bridge mode enabled in settings

### Can't Connect from Emulator
1. Check LDPlayer network settings
2. Try using `10.0.2.2` if `172.25.7.206` doesn't work (Android emulator's special alias for host)
3. Make sure Windows Firewall allows inbound connections on port 3000

### To Allow Windows Firewall
```powershell
# Run PowerShell as Administrator
New-NetFirewallRule -DisplayName "Node.js Backend" -Direction Inbound -Protocol TCP -LocalPort 3000 -Action Allow
```

## Next Steps (Optional Backend Enhancements)

To make the other methods work (getUserBorrowRequests, getUserStats, etc.), you'll need to add these endpoints to your `app.js`:

1. `GET /users/:id/borrow-requests` - Get user's borrow requests
2. `GET /users/:id/stats` - Get user statistics
3. `DELETE /borrow-requests/:id` - Cancel a request
4. `GET /users/:id/history` - Get borrow history

Let me know if you need help adding these endpoints!
