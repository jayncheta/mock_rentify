# Login Troubleshooting Guide

## ✅ What I Fixed

### 1. **Backend (`app_fixed.js`)**
- ✅ Added debug logging to see login attempts
- ✅ Changed password check to handle both plain text and hashed passwords
- ✅ Better error messages
- ✅ Server now binds to `0.0.0.0` to accept connections from emulator

### 2. **Flutter App (`main.dart`)**
- ✅ Login now uses `UserBorrowService().login()` to connect to backend
- ✅ Added loading indicator while logging in
- ✅ Better error messages (shows if backend is unreachable)
- ✅ Properly handles different user roles (Staff, Lender, User)

## 🚀 How to Test Login

### Step 1: Make Sure Backend is Running
```powershell
cd "c:\Users\Jay\Desktop\MFU\mock_rentify\mock_rentify\backend"
node app_fixed.js
```

You should see:
```
Server is running on port 3000
Accessible at http://172.25.7.206:3000
Connected to the database.
```

### Step 2: Test Backend Directly
Open a new PowerShell terminal and run:
```powershell
# Test the items endpoint
Invoke-RestMethod -Uri "http://localhost:3000/items" -Method Get

# Test login with your database user
$body = @{
    username = "your_username"
    password = "your_password"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:3000/login" -Method Post -Body $body -ContentType "application/json"
```

### Step 3: Check Your Database Users
Make sure you have users in your database. Run this in MySQL:
```sql
SELECT user_id, username, password_hash, role FROM users;
```

### Step 4: Run Flutter App
```powershell
cd "c:\Users\Jay\Desktop\MFU\mock_rentify\mock_rentify"
flutter run
```

Select your LDPlayer emulator when prompted.

## 🔧 Common Issues and Solutions

### Issue 1: "Could not connect to server"
**Symptoms:** Flutter app shows connection error

**Solutions:**
1. **Check if backend is running** - Look for the "Server is running" message
2. **Use localhost for Android emulator** - Android emulators use special IP
   - Update `user_service.dart` line 14:
   ```dart
   // For Android Emulator (including LDPlayer)
   static const String _baseUrl = 'http://10.0.2.2:3000';
   
   // OR for localhost testing
   // static const String _baseUrl = 'http://localhost:3000';
   ```
3. **Check Windows Firewall** - Run as Administrator:
   ```powershell
   New-NetFirewallRule -DisplayName "Node.js Backend" -Direction Inbound -Protocol TCP -LocalPort 3000 -Action Allow
   ```

### Issue 2: "Invalid username or password"
**Symptoms:** Login fails even with correct credentials

**Solutions:**
1. **Check the backend console** - It will show:
   ```
   Login attempt: { username: 'youruser', password: 'yourpass' }
   Query results: [ { user_id: 1, username: 'youruser', ... } ]
   ```

2. **Verify password field** in database:
   - The backend expects `password_hash` column
   - If your database uses a different column name (like `password`), update `app_fixed.js` line 68

3. **Check password format**:
   - Plain text: stored as-is in database
   - Hashed: you'll need to hash the password before comparing

### Issue 3: Database Connection Failed
**Symptoms:** Backend shows "Error connecting to the database"

**Solutions:**
1. **Check MySQL is running**:
   ```powershell
   Get-Service -Name "MySQL*"
   ```

2. **Verify database credentials** in `app_fixed.js` line 10-14:
   ```javascript
   const db = mysql.createConnection({
       host: 'localhost',
       user: 'root',
       password: '',  // Your MySQL password
       database: 'rentify'
   });
   ```

3. **Create database if needed**:
   ```sql
   CREATE DATABASE rentify;
   ```

## 📊 Database Schema Reference

Your `users` table should have these columns:
```sql
CREATE TABLE users (
    user_id INT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(100),
    email VARCHAR(100),
    role ENUM('User', 'Staff', 'Lender') DEFAULT 'User'
);
```

### Sample Test Users
```sql
INSERT INTO users (username, password_hash, full_name, email, role) VALUES
('testuser', 'user123', 'Test User', 'user@test.com', 'User'),
('teststaff', 'staff123', 'Test Staff', 'staff@test.com', 'Staff'),
('testlender', 'lender123', 'Test Lender', 'lender@test.com', 'Lender');
```

## 🔍 Debug Mode

The backend now logs all login attempts. Watch the backend console to see:
- Login attempts with username/password
- Database query results
- Success/failure messages

Example output:
```
Login attempt: { username: 'testuser', password: 'user123' }
Query results: [
  {
    user_id: 1,
    username: 'testuser',
    full_name: 'Test User',
    email: 'user@test.com',
    role: 'User',
    password_hash: 'user123'
  }
]
Login successful for user: testuser
```

## 🌐 Network Configuration for LDPlayer

### Option 1: Use Android Emulator Special IP (Recommended)
Update `lib/services/user_service.dart`:
```dart
static const String _baseUrl = 'http://10.0.2.2:3000';
```

### Option 2: Use Your PC's Network IP
1. Find your IP: `ipconfig` in PowerShell
2. Use that IP in `user_service.dart`:
```dart
static const String _baseUrl = 'http://192.168.x.x:3000';
```

### Option 3: Use Bridge Mode in LDPlayer
1. Open LDPlayer Settings
2. Go to Network Settings
3. Change to Bridge Mode
4. Use your PC's network IP

## 📱 Testing Login in Flutter App

When you try to login, the app will:
1. Show loading spinner on the Sign In button
2. Send request to backend at `http://172.25.7.206:3000/login`
3. If successful: Navigate to appropriate screen based on role
4. If failed: Show error message

Watch the backend console for debug logs!

## ✨ Quick Test Checklist

- [ ] Backend server running (see "Server is running" message)
- [ ] MySQL database running
- [ ] Users exist in database
- [ ] Flutter app compiled and running on LDPlayer
- [ ] Network connectivity between emulator and backend
- [ ] Try login with database credentials

## 🆘 Still Having Issues?

Check these:
1. Backend console output - what does it show?
2. Flutter app error message - what exactly does it say?
3. Can you access `http://localhost:3000/items` in a browser?
4. Does `SELECT * FROM users;` in MySQL show your users?

Good luck! 🎉
