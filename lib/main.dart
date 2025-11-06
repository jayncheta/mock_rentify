import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'browse.dart';
import 'staff/add.dart';
import 'staff/edit.dart';
import 'staff/disable.dart';
import 'staff/staff_browse.dart';
import 'staff/all_history.dart';
import 'staff/staff_dashboard.dart';
import 'staff/return_item.dart';
import 'user/user_request.dart';
import 'user/user_profile.dart';
import 'user/user_history.dart';
import 'user/borrow_request.dart';
import 'user/user_borrowing.dart';
import 'lender/lender_profile.dart';
import 'lender/dashboard.dart';
import 'lender/lender_browse.dart';
import 'lender/lender_review.dart';
import 'lender/lender_history.dart';
import 'services/user_service.dart';

class UserAccount {
  final String username;
  final String password;
  final String role;
  const UserAccount(this.username, this.password, this.role);
}

const List<UserAccount> validTestAccounts = [
  UserAccount('User', 'user1234', 'User'),
  UserAccount('Staff', 'staff1234', 'Staff'),
  UserAccount('Lender', 'lender1234', 'Lender'),
];

void main() => runApp(const RentifyApp());

void _showAlertDialog(
  BuildContext context,
  String title,
  String message, {
  bool success = false,
  UserAccount? user,
}) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              success ? Icons.check_circle : Icons.error,
              color: success ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 10),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            child: const Text('OK'),
            onPressed: () {
              Navigator.of(context).pop();
              if (success) {
                if (user != null && user.role.toLowerCase() == 'staff') {
                  Navigator.pushReplacementNamed(
                    context,
                    AddItemsScreen.routeName,
                  );
                } else {
                  Navigator.pushReplacementNamed(
                    context,
                    BrowseScreen.routeName,
                  );
                }
              }
            },
          ),
        ],
      );
    },
  );
}

class RentifyApp extends StatelessWidget {
  const RentifyApp({super.key});
  static const Color primaryColor = Color(0xFFF96A38);

  static ThemeData get _appTheme => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
      primary: primaryColor,
    ),
    primaryColor: primaryColor,
    scaffoldBackgroundColor: Colors.white,
    textTheme: GoogleFonts.poppinsTextTheme(),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryColor,
        side: const BorderSide(color: primaryColor, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      filled: true,
      fillColor: Colors.grey[50],
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: GoogleFonts.poppins(color: Colors.grey[600]),
    ),

    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: const IconThemeData(color: Colors.black),
      titleTextStyle: GoogleFonts.poppins(
        color: Colors.black,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rentify App',
      debugShowCheckedModeBanner: false,
      theme: _appTheme,
      initialRoute: WelcomeScreen.routeName,
      routes: {
        WelcomeScreen.routeName: (context) => const WelcomeScreen(),
        LoginScreen.routeName: (context) => const LoginScreen(),
        SignUpScreen.routeName: (context) => const SignUpScreen(),
        BrowseScreen.routeName: (context) => const BrowseScreen(),
        AddItemsScreen.routeName: (context) => const AddItemsScreen(),
        EditItemsScreen.routeName: (context) => const EditItemsScreen(),
        DisableItemsScreen.routeName: (context) => const DisableItemsScreen(),
        StaffBrowseScreen.routeName: (context) => const StaffBrowseScreen(),
        StaffHistoryPage.routeName: (context) => const StaffHistoryPage(),
        StaffDashboardPage.routeName: (context) => const StaffDashboardPage(),
        StaffReturnScreen.routeName: (context) => const StaffReturnScreen(),
        UserRequestPage.routeName: (context) => const UserRequestPage(),
        ProfilePage.routeName: (context) => const ProfilePage(),
        UserHistoryPage.routeName: (context) => const UserHistoryPage(),
        LenderProfilePage.routeName: (context) => const LenderProfilePage(),
        DashboardPage.routeName: (context) => const DashboardPage(),
        LenderBrowseScreen.routeName: (context) => const LenderBrowseScreen(),
        LenderReviewScreen.routeName: (context) => const LenderReviewScreen(),
        LenderHistoryPage.routeName: (context) => const LenderHistoryPage(),

        BorrowRequestScreen.routeName: (context) {
          final item = ModalRoute.of(context)!.settings.arguments as Item;
          return BorrowRequestScreen(item: item);
        },
        UserBorrowingScreen.routeName: (context) {
          final map =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>;
          return UserBorrowingScreen(
            item: map['item'],
            borrowDate: map['borrowDate'],
            pickUpTime: map['pickUpTime'],
            returnDate: map['returnDate'],
            returnTime: map['returnTime'],
            reason: map['reason'],
          );
        },
      },
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  static const String routeName = '/';
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Text(
                'Rentify',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 60,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              Text(
                'Your trusted asset borrowing app simplified.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () =>
                    Navigator.pushNamed(context, LoginScreen.routeName),
                child: const Text('Sign in'),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () =>
                    Navigator.pushNamed(context, SignUpScreen.routeName),
                child: const Text('Sign up'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  static const String routeName = '/login';
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _isLoading = false;

  Future<void> _login() async {
    final enteredUsername = _usernameController.text.trim();
    final enteredPassword = _passwordController.text;

    if (enteredUsername.isEmpty || enteredPassword.isEmpty) {
      _showAlertDialog(
        context,
        'Missing Fields',
        'Please enter both a username and a password.',
      );
      return;
    }

    // Show loading state
    setState(() {
      _isLoading = true;
    });

    try {
      // Call backend API
      final userData = await UserBorrowService().login(
        username: enteredUsername,
        password: enteredPassword,
      );

      setState(() {
        _isLoading = false;
      });

      if (userData != null) {
        // Login successful
        final role = userData['role']?.toString().toLowerCase() ?? '';

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Welcome, ${userData['username']}!')),
        );

        // Navigate based on role
        if (role == 'staff') {
          Navigator.pushReplacementNamed(context, AddItemsScreen.routeName);
        } else if (role == 'lender') {
          Navigator.pushReplacementNamed(context, LenderProfilePage.routeName);
        } else {
          Navigator.pushReplacementNamed(context, BrowseScreen.routeName);
        }
      } else {
        // Login failed
        if (!mounted) return;
        _showAlertDialog(
          context,
          'Login Failed',
          'Invalid username or password. Please check your credentials and try again.',
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (!mounted) return;
      _showAlertDialog(
        context,
        'Connection Error',
        'Could not connect to server. Please make sure the backend is running at http://10.2.8.30:3000',
      );
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login'), centerTitle: true),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Text(
                'Welcome to Rentify',
                style: GoogleFonts.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 20.0),
                child: Text(
                  'User - user1234, Staff - staff1234, Lender - lender1234',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: RentifyApp.primaryColor,
                  ),
                ),
              ),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Username'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _login(),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        onChanged: (value) =>
                            setState(() => _rememberMe = value!),
                        activeColor: RentifyApp.primaryColor,
                      ),
                      const Text('Remember me'),
                    ],
                  ),
                  TextButton(
                    onPressed: () {},
                    child: const Text('Forgot password?'),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _isLoading ? null : _login,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text('Sign in'),
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account? "),
                  TextButton(
                    onPressed: () => Navigator.pushReplacementNamed(
                      context,
                      SignUpScreen.routeName,
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Sign up'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SignUpScreen extends StatefulWidget {
  static const String routeName = '/signup';
  const SignUpScreen({super.key});
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _agreeTerms = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    // Validation
    if (username.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      _showAlertDialog(context, 'Missing Fields', 'Please fill in all fields.');
      return;
    }

    if (!email.contains('@')) {
      _showAlertDialog(
        context,
        'Invalid Email',
        'Please enter a valid email address.',
      );
      return;
    }

    if (password != confirmPassword) {
      _showAlertDialog(
        context,
        'Password Mismatch',
        'Passwords do not match. Please try again.',
      );
      return;
    }

    if (password.length < 6) {
      _showAlertDialog(
        context,
        'Weak Password',
        'Password must be at least 6 characters long.',
      );
      return;
    }

    if (!_agreeTerms) {
      _showAlertDialog(
        context,
        'Terms Required',
        'Please agree to the terms and conditions.',
      );
      return;
    }

    // Show loading
    setState(() {
      _isLoading = true;
    });

    try {
      // Call backend API
      final userData = await UserBorrowService().signup(
        username: username,
        email: email,
        password: password,
        fullName: username,
      );

      setState(() {
        _isLoading = false;
      });

      if (userData != null) {
        // Signup successful
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Welcome, ${userData['username']}! Account created successfully.',
            ),
          ),
        );

        // Navigate to browse screen (default user role)
        Navigator.pushReplacementNamed(context, BrowseScreen.routeName);
      } else {
        // Signup failed
        if (!mounted) return;
        _showAlertDialog(
          context,
          'Signup Failed',
          'Username or email already exists. Please try different credentials.',
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (!mounted) return;
      _showAlertDialog(
        context,
        'Connection Error',
        'Could not connect to server. Please make sure the backend is running at http://10.2.8.30:3000',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign up'), centerTitle: true),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Text(
                'Create account',
                style: GoogleFonts.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 40),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Username'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                ),
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _agreeTerms ? _handleSignup() : null,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Checkbox(
                    value: _agreeTerms,
                    onChanged: (value) => setState(() => _agreeTerms = value!),
                    activeColor: RentifyApp.primaryColor,
                  ),
                  const Expanded(
                    child: Text('I agree with terms and conditions'),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: (_agreeTerms && !_isLoading) ? _handleSignup : null,
                style: (_agreeTerms && !_isLoading)
                    ? null
                    : ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                        foregroundColor: Colors.grey[600],
                      ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text('Register'),
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Already have an account? "),
                  TextButton(
                    onPressed: () => Navigator.pushReplacementNamed(
                      context,
                      LoginScreen.routeName,
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Login'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
