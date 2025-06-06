import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import '../models/user_model.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final DatabaseHelper _databaseHelper = DatabaseHelper();
  
  // Session keys
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _userIdKey = 'user_id';
  static const String _usernameKey = 'username';
  static const String _sessionTokenKey = 'session_token';

  User? _currentUser;

  // Generate salt for password hashing
  String _generateSalt() {
    final random = Random.secure();
    final saltBytes = List<int>.generate(32, (i) => random.nextInt(256));
    return base64.encode(saltBytes);
  }

  // Hash password with salt
  String _hashPassword(String password, String salt) {
    final bytes = utf8.encode(password + salt);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Generate session token
  String _generateSessionToken() {
    final random = Random.secure();
    final tokenBytes = List<int>.generate(32, (i) => random.nextInt(256));
    return base64.encode(tokenBytes);
  }

  // Validate email format
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  // Validate password strength
  bool _isValidPassword(String password) {
    // Password must be at least 6 characters long
    if (password.length < 6) return false;
    
    // Password must contain at least one letter and one number
    final hasLetter = RegExp(r'[a-zA-Z]').hasMatch(password);
    final hasNumber = RegExp(r'\d').hasMatch(password);
    
    return hasLetter && hasNumber;
  }

  // Register new user
  Future<AuthResult> register({
    required String username,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    try {
      // Validate input
      if (username.trim().isEmpty) {
        return AuthResult.failure('Username cannot be empty');
      }
      
      if (username.length < 3) {
        return AuthResult.failure('Username must be at least 3 characters long');
      }
      
      if (!_isValidEmail(email)) {
        return AuthResult.failure('Please enter a valid email address');
      }
      
      if (!_isValidPassword(password)) {
        return AuthResult.failure(
          'Password must be at least 6 characters long and contain both letters and numbers'
        );
      }
      
      if (password != confirmPassword) {
        return AuthResult.failure('Passwords do not match');
      }

      // Check if username already exists
      if (await _databaseHelper.usernameExists(username.trim())) {
        return AuthResult.failure('Username already exists');
      }

      // Check if email already exists
      if (await _databaseHelper.emailExists(email.trim().toLowerCase())) {
        return AuthResult.failure('Email already exists');
      }

      // Generate salt and hash password
      final salt = _generateSalt();
      final passwordHash = _hashPassword(password, salt);
      final saltedHash = '$salt:$passwordHash'; // Store salt with hash

      // Create new user
      final user = User(
        username: username.trim(),
        email: email.trim().toLowerCase(),
        passwordHash: saltedHash,
        createdAt: DateTime.now(),
      );

      // Insert user into database
      final userId = await _databaseHelper.insertUser(user);
      
      if (userId > 0) {
        final createdUser = user.copyWith(id: userId);
        return AuthResult.success('Account created successfully', createdUser);
      } else {
        return AuthResult.failure('Failed to create account');
      }
    } catch (e) {
      print('Registration error: $e');
      return AuthResult.failure('An error occurred during registration');
    }
  }

  // Login user
  Future<AuthResult> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    try {
      if (usernameOrEmail.trim().isEmpty || password.isEmpty) {
        return AuthResult.failure('Please enter username/email and password');
      }

      User? user;
      
      // Try to find user by username or email
      if (_isValidEmail(usernameOrEmail)) {
        user = await _databaseHelper.getUserByEmail(usernameOrEmail.trim().toLowerCase());
      } else {
        user = await _databaseHelper.getUserByUsername(usernameOrEmail.trim());
      }

      if (user == null) {
        return AuthResult.failure('Invalid username/email or password');
      }

      // Verify password
      final passwordParts = user.passwordHash.split(':');
      if (passwordParts.length != 2) {
        return AuthResult.failure('Invalid password format');
      }

      final salt = passwordParts[0];
      final storedHash = passwordParts[1];
      final enteredHash = _hashPassword(password, salt);

      if (enteredHash != storedHash) {
        return AuthResult.failure('Invalid username/email or password');
      }

      // Update last login time
      await _databaseHelper.updateLastLogin(user.id!);

      // Save session
      await _saveSession(user);

      _currentUser = user;
      return AuthResult.success('Login successful', user);
    } catch (e) {
      print('Login error: $e');
      return AuthResult.failure('An error occurred during login');
    }
  }

  // Save user session
  Future<void> _saveSession(User user) async {
    final prefs = await SharedPreferences.getInstance();
    final sessionToken = _generateSessionToken();
    
    await prefs.setBool(_isLoggedInKey, true);
    await prefs.setInt(_userIdKey, user.id!);
    await prefs.setString(_usernameKey, user.username);
    await prefs.setString(_sessionTokenKey, sessionToken);
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;
      
      if (isLoggedIn) {
        final userId = prefs.getInt(_userIdKey);
        if (userId != null) {
          _currentUser = await _databaseHelper.getUserById(userId);
          return _currentUser != null;
        }
      }
      
      return false;
    } catch (e) {
      print('Error checking login status: $e');
      return false;
    }
  }

  // Get current user
  User? getCurrentUser() {
    return _currentUser;
  }

  // Load current user from session
  Future<User?> loadCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt(_userIdKey);
      
      if (userId != null) {
        _currentUser = await _databaseHelper.getUserById(userId);
        return _currentUser;
      }
      
      return null;
    } catch (e) {
      print('Error loading current user: $e');
      return null;
    }
  }

  // Update profile photo
  Future<AuthResult> updateProfilePhoto(String? profilePhotoPath) async {
    try {
      if (_currentUser == null) {
        return AuthResult.failure('User not logged in');
      }

      // Validate file exists if path is provided
      if (profilePhotoPath != null) {
        final file = File(profilePhotoPath);
        if (!await file.exists()) {
          return AuthResult.failure('Profile photo file not found');
        }
      }

      // Update in database
      final updateResult = await _databaseHelper.updateUserProfilePhoto(
        _currentUser!.id!,
        profilePhotoPath,
      );

      if (updateResult > 0) {
        // Update current user object
        _currentUser = _currentUser!.copyWith(profilePhoto: profilePhotoPath);
        
        final message = profilePhotoPath != null 
          ? 'Profile photo updated successfully'
          : 'Profile photo removed successfully';
        
        return AuthResult.success(message, _currentUser);
      } else {
        return AuthResult.failure('Failed to update profile photo');
      }
    } catch (e) {
      print('Error updating profile photo: $e');
      return AuthResult.failure('An error occurred while updating profile photo');
    }
  }

  // Delete profile photo file and update database
  Future<AuthResult> deleteProfilePhoto() async {
    try {
      if (_currentUser == null) {
        return AuthResult.failure('User not logged in');
      }

      // Delete the file if it exists
      if (_currentUser!.profilePhoto != null) {
        final file = File(_currentUser!.profilePhoto!);
        if (await file.exists()) {
          await file.delete();
        }
      }

      // Update database to remove profile photo reference
      return await updateProfilePhoto(null);
    } catch (e) {
      print('Error deleting profile photo: $e');
      return AuthResult.failure('An error occurred while deleting profile photo');
    }
  }

  // Logout user
  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Clear all session data
      await prefs.remove(_isLoggedInKey);
      await prefs.remove(_userIdKey);
      await prefs.remove(_usernameKey);
      await prefs.remove(_sessionTokenKey);
      
      _currentUser = null;
    } catch (e) {
      print('Error during logout: $e');
    }
  }

  // Change password
  Future<AuthResult> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmNewPassword,
  }) async {
    try {
      if (_currentUser == null) {
        return AuthResult.failure('User not logged in');
      }

      if (!_isValidPassword(newPassword)) {
        return AuthResult.failure(
          'New password must be at least 6 characters long and contain both letters and numbers'
        );
      }

      if (newPassword != confirmNewPassword) {
        return AuthResult.failure('New passwords do not match');
      }

      // Verify current password
      final passwordParts = _currentUser!.passwordHash.split(':');
      if (passwordParts.length != 2) {
        return AuthResult.failure('Invalid current password format');
      }

      final salt = passwordParts[0];
      final storedHash = passwordParts[1];
      final currentHash = _hashPassword(currentPassword, salt);

      if (currentHash != storedHash) {
        return AuthResult.failure('Current password is incorrect');
      }

      // Generate new salt and hash for new password
      final newSalt = _generateSalt();
      final newPasswordHash = _hashPassword(newPassword, newSalt);
      final newSaltedHash = '$newSalt:$newPasswordHash';

      // Update user password
      final updatedUser = _currentUser!.copyWith(passwordHash: newSaltedHash);
      final updateResult = await _databaseHelper.updateUser(updatedUser);

      if (updateResult > 0) {
        _currentUser = updatedUser;
        return AuthResult.success('Password changed successfully');
      } else {
        return AuthResult.failure('Failed to change password');
      }
    } catch (e) {
      print('Error changing password: $e');
      return AuthResult.failure('An error occurred while changing password');
    }
  }

  // Update user profile (username, email)
  Future<AuthResult> updateProfile({
    String? newUsername,
    String? newEmail,
  }) async {
    try {
      if (_currentUser == null) {
        return AuthResult.failure('User not logged in');
      }

      // Validate inputs
      if (newUsername != null) {
        if (newUsername.trim().isEmpty) {
          return AuthResult.failure('Username cannot be empty');
        }
        if (newUsername.trim().length < 3) {
          return AuthResult.failure('Username must be at least 3 characters long');
        }
        // Check if username is taken by another user
        final existingUser = await _databaseHelper.getUserByUsername(newUsername.trim());
        if (existingUser != null && existingUser.id != _currentUser!.id) {
          return AuthResult.failure('Username already exists');
        }
      }

      if (newEmail != null) {
        if (!_isValidEmail(newEmail)) {
          return AuthResult.failure('Please enter a valid email address');
        }
        // Check if email is taken by another user
        final existingUser = await _databaseHelper.getUserByEmail(newEmail.trim().toLowerCase());
        if (existingUser != null && existingUser.id != _currentUser!.id) {
          return AuthResult.failure('Email already exists');
        }
      }

      // Update user object
      final updatedUser = _currentUser!.copyWith(
        username: newUsername?.trim() ?? _currentUser!.username,
        email: newEmail?.trim().toLowerCase() ?? _currentUser!.email,
      );

      // Update in database
      final updateResult = await _databaseHelper.updateUser(updatedUser);

      if (updateResult > 0) {
        _currentUser = updatedUser;
        return AuthResult.success('Profile updated successfully', _currentUser);
      } else {
        return AuthResult.failure('Failed to update profile');
      }
    } catch (e) {
      print('Error updating profile: $e');
      return AuthResult.failure('An error occurred while updating profile');
    }
  }

  // Reset/Clear all data (for testing)
  Future<void> clearAllData() async {
    await logout();
    await _databaseHelper.deleteDatabase();
  }
}

// Auth result class
class AuthResult {
  final bool success;
  final String message;
  final User? user;

  AuthResult._({
    required this.success,
    required this.message,
    this.user,
  });

  factory AuthResult.success(String message, [User? user]) {
    return AuthResult._(
      success: true,
      message: message,
      user: user,
    );
  }

  factory AuthResult.failure(String message) {
    return AuthResult._(
      success: false,
      message: message,
    );
  }
}