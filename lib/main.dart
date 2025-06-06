// lib/main.dart

import 'package:flutter/material.dart';
import 'pages/login_page.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'database/database_helper.dart';
import 'pages/vinyl_home_page.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize database first
  try {
    final databaseHelper = DatabaseHelper();
    await databaseHelper.database; // This creates tables
    print('Database initialized successfully');
  } catch (e) {
    print('Database initialization error: $e');
  }
  
  // Initialize notification service and wait for completion
  try {
    print('Starting notification service initialization...');
    await NotificationService().initialize();
    print('Notification service initialization completed');
    
    // Verify initialization
    if (NotificationService().isInitialized) {
      print('✅ Notification service is ready');
    } else {
      print('❌ Notification service failed to initialize');
    }
  } catch (e) {
    print('Error initializing notification service: $e');
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vinyl Store',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepOrange,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkAuthAndInitialize(),
      builder: (context, snapshot) {
        // Show loading while checking authentication
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading...'),
                ],
              ),
            ),
          );
        }

        // If user is logged in, show home page
        if (snapshot.data == true) {
          return const VinylHomePage();
        }

        // Otherwise, show login page
        return const LoginPage();
      },
    );
  }

  Future<bool> _checkAuthAndInitialize() async {
    try {
      // Check if user is logged in
      final isLoggedIn = await AuthService().isLoggedIn();
      
      if (isLoggedIn) {
        // Ensure notification service is initialized before scheduling
        if (!NotificationService().isInitialized) {
          print('Re-initializing notification service...');
          await NotificationService().initialize();
        }
        
        // Schedule notifications for logged-in user
        if (NotificationService().isInitialized) {
          await NotificationService().scheduleAllUserNotifications();
          print('User notifications scheduled');
        } else {
          print('Cannot schedule notifications - service not initialized');
        }
      }
      
      return isLoggedIn;
    } catch (e) {
      print('Error during auth check and initialization: $e');
      return false;
    }
  }
}