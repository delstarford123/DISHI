import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'core/theme/mpesa_theme.dart';
import 'features/auth/presentation/signup_view.dart';
import 'features/auth/presentation/pin_unlock_view.dart';
import 'features/auth/presentation/splash_screen.dart';
import 'features/student/presentation/student_main_scaffold.dart';
import 'features/admin/presentation/admin_dashboard_view.dart';
import 'features/vendor/presentation/vendor_dashboard_view.dart';
import 'features/parent/presentation/parent_dashboard_view.dart';
import 'features/delivery/presentation/deliv_driver_dashboard.dart';
import 'features/housing/presentation/housing_dashboard_view.dart';
import 'core/security/secure_storage_service.dart';

import 'package:provider/provider.dart';
import 'features/smartimer/data/hive_service.dart';
import 'features/smartimer/providers/plan_provider.dart';
import 'features/match/presentation/widgets/incoming_call_listener.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/services/fcm_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");
  // Here we can save data to Hive or SQLite for offline use
}

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await SmartiHiveService.init();
    
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await FCMService.initialize();
  } catch (e) {
    debugPrint('Initialization error: $e');
  }

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
      final pin = await SecureStorageService.getHashedPin();
      if (mounted) {
        if (pin != null && pin.isNotEmpty) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => PinUnlockView(
            onSuccess: () async {
              final userData = await SecureStorageService.getUserData();
              final role = userData['role'] ?? 'student';
              final userMap = {'roles': [role]};
              if (!mounted) return;
              
              Widget dashboard;
              if (role == 'vendor') {
                dashboard = VendorDashboardView(user: userMap);
              } else if (role == 'admin') {
                dashboard = AdminDashboardView(user: userMap);
              } else if (role == 'parent') {
                dashboard = ParentDashboardView(user: userMap);
              } else if (role == 'driver') {
                dashboard = DelivDriverDashboard(user: userMap);
              } else if (role == 'house_owner') {
                dashboard = HousingDashboardView(user: userMap);
              } else {
                dashboard = StudentMainScaffold(user: userMap);
              }
              
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => dashboard));
            }
          )));
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
    return SplashScreen(onInitializationComplete: _checkInitialRoute);
  }
}

