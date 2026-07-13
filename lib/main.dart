// lib/main.dart - MediSmart Phase 2 Complete

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:medismart/firebase/firebase_options.dart';
import 'package:medismart/services/auth_service.dart';
import 'package:medismart/services/notification_service.dart';
import 'package:medismart/screens/auth/login_screen.dart';
import 'package:medismart/screens/home/main_navigation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (!kIsWeb) await NotificationService().initialize();
  runApp(const MediSmartApp());
}

class MediSmartApp extends StatelessWidget {
  const MediSmartApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AuthService())],
      child: MaterialApp(
        title: 'MediSmart',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          primaryColor: const Color(0xFF2196F3),
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2196F3), primary: const Color(0xFF2196F3)),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF2196F3), foregroundColor: Colors.white, elevation: 0),
          elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2196F3), foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true, fillColor: const Color(0xFFF9F9F9)),
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});
  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    return StreamBuilder(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData) return const MainNavigation();
        return const LoginScreen();
      },
    );
  }
}
