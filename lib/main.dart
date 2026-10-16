import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'core/theme/mpesa_theme.dart';
import 'features/auth/presentation/login_view.dart';
import 'features/auth/presentation/pin_unlock_view.dart';
import 'features/auth/presentation/splash_screen.dart';
import 'features/student/presentation/student_main_scaffold.dart';
import 'features/admin/presentation/admin_dashboard_view.dart';
import 'features/vendor/presentation/vendor_dashboard_view.dart';
import 'features/parent/presentation/parent_dashboard_view.dart';
import 'features/deliv/presentation/deliv_driver_dashboard.dart';
import 'features/housing/presentation/housing_dashboard_view.dart';
import 'features/fundi/presentation/fundi_dashboard_view.dart';
import 'core/security/secure_storage_service.dart';
import 'core/security/session_manager.dart';

import 'package:provider/provider.dart';
import 'features/smartimer/data/hive_service.dart';
import 'features/smartimer/providers/plan_provider.dart';
import 'features/match/presentation/widgets/incoming_call_listener.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'core/services/fcm_service.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");
  // Here we can save data to Hive or SQLite for offline use
}

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Enable high-performance local Firestore persistence & unlimited caching for instant loads
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
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

class DISHIApp extends StatefulWidget {
  const DISHIApp({super.key});

  @override
  State<DISHIApp> createState() => _DISHIAppState();
}

class _DISHIAppState extends State<DISHIApp> {
  bool _isSessionLockShowing = false;

  void _handleSessionTimeout() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _isSessionLockShowing) return;

    final hasPin = await SecureStorageService.hasPinFastCheck();
    if (!hasPin) return;

    final nav = appNavigatorKey.currentState;
    if (nav == null) return;

    setState(() => _isSessionLockShowing = true);

    nav.push(
      MaterialPageRoute(
        builder: (ctx) => PinUnlockView(
          onSuccess: () {
            _isSessionLockShowing = false;
            if (mounted) setState(() {});
            Navigator.of(ctx).pop();
          },
        ),
      ),
    );
  }

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
        return SessionManager(
          timeoutDuration: const Duration(minutes: 15),
          onSessionTimeout: _handleSessionTimeout,
          child: IncomingCallListener(
            navigatorKey: appNavigatorKey,
            child: child ?? const SizedBox.shrink(),
          ),
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
      // Sync FCM token in background
      FCMService.syncToken(user.uid);

      // 1. Lightning Fast Boot Checks (L1 Cache)
      final hasPin = await SecureStorageService.hasPinFastCheck();
      
      if (mounted) {
        if (hasPin) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => PinUnlockView(
            onSuccess: () async {
              // 2. Slow Decrypt + Fetch (L2 Cache / Network) running AFTER UI renders
              final role = await SecureStorageService.getRoleFastCheck() ?? 'student';
              final userDataFuture = SecureStorageService.getUserData();
              
              if (appNavigatorKey.currentState == null) return;
              
              Widget dashboard;
              if (role == 'vendor') {
                dashboard = VendorDashboardView(user: {'uid': user.uid, 'roles': [role]});
              } else if (role == 'admin') {
                dashboard = AdminDashboardView(user: {'uid': user.uid, 'roles': [role]});
              } else if (role == 'parent') {
                dashboard = ParentDashboardView(user: {'uid': user.uid, 'roles': [role]});
              } else if (role == 'driver') {
                dashboard = DelivDriverDashboard(user: {'uid': user.uid, 'roles': [role]});
              } else if (role == 'house_owner') {
                dashboard = HousingDashboardView(user: {'uid': user.uid, 'roles': [role]});
              } else if (role == 'fundi') {
                dashboard = FundiDashboardView(user: {'uid': user.uid, 'roles': [role]});
              } else {
                dashboard = StudentMainScaffold(user: {'uid': user.uid, 'roles': [role]});
              }
              
              appNavigatorKey.currentState!.pushReplacement(MaterialPageRoute(builder: (context) => dashboard));

              // Backfill the complete user map asynchronously
              await userDataFuture;
              // Depending on implementation, you could broadcast the rich userData 
              // or just rely on Firebase's cache for subsequent reads.
            }
          )));
        } else {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginView()));
        }
      }
    } else {
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginView()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SplashScreen(onInitializationComplete: _checkInitialRoute);
  }
}

