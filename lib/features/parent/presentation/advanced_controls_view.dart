import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'core/theme/mpesa_theme.dart';
import 'features/auth/presentation/signup_view.dart';
import 'features/auth/presentation/pin_unlock_view.dart';
import 'core/services/secure_storage_service.dart';
import 'features/smartimer/data/hive_service.dart';
import 'features/smartimer/providers/plan_provider.dart';
import 'features/match/presentation/widgets/incoming_call_listener.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await SmartiHiveService.init(); 
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SmartiPlanProvider()),
      ],
      child: const DISHIApp(),
    ),
  );
}

class DISHIApp extends StatelessWidget {
  const DISHIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DISHI',
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      theme: MPesaTheme.lightTheme,
      darkTheme: MPesaTheme.darkTheme,
      themeMode: ThemeMode.system,
      builder: (context, child) {
        return IncomingCallListener(
          navigatorKey: appNavigatorKey,
          child: child ?? const SizedBox.shrink(),
        );
      },
      // Set the FutureBuilder widget as the direct home
      home: const InitialRouter(),
    );
  }
}

class InitialRouter extends StatelessWidget {
  const InitialRouter({super.key});

  /// Evaluates auth and offline pin state asynchronously
  Future<Widget> _resolveInitialScreen() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final pin = await SecureStorageService.getOfflinePin();
      if (pin != null && pin.isNotEmpty) {
        return const PinUnlockView();
      }
    }
    return const SignupView();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _resolveInitialScreen(),
      builder: (context, snapshot) {
        // Show splash screen while resolving auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: MPesaTheme.primaryGreen,
            body: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }
        
        // Return the resolved screen directly, avoiding Navigator pushes
        if (snapshot.hasData) {
          return snapshot.data!;
        }
        
        // Fallback
        return const SignupView();
      },
    );
  }
}