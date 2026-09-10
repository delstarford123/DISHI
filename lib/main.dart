import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'core/theme/mpesa_theme.dart';
import 'features/auth/presentation/signup_view.dart';
import 'features/auth/presentation/pin_unlock_view.dart';
import 'core/services/secure_storage_service.dart';

import 'package:provider/provider.dart';
import 'features/smartimer/data/hive_service.dart';
import 'features/smartimer/providers/plan_provider.dart';
import 'features/match/presentation/widgets/incoming_call_listener.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await SmartiHiveService.init(); // Initialize Hive for Smartimer
  
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
      home: const InitialRouter(),
    );
  }
}

class InitialRouter extends StatefulWidget {
  const InitialRouter({super.key});
  @override
  State<InitialRouter> createState() => _InitialRouterState();
}

class _InitialRouterState extends State<InitialRouter> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInitialRoute();
    });
  }

  Future<void> _checkInitialRoute() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final pin = await SecureStorageService.getOfflinePin();
      if (mounted) {
        if (pin != null && pin.isNotEmpty) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const PinUnlockView()));
        } else {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const SignupView()));
        }
      }
    } else {
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const SignupView()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: MPesaTheme.primaryGreen,
      body: Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }
}

