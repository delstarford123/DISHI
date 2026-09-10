import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Firebase or other services here
  runApp(const SwapEatApp());
}

class SwapEatApp extends StatelessWidget {
  const SwapEatApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SwapEat',
      theme: ThemeData(
        primarySwatch: Colors.red,
      ),
      // Wrap your entire app route or specific screens with the listener
      builder: (context, child) {
        return IncomingCallListener(
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const HomeScreen(),
      routes: {
        '/incoming_call': (context) => const CallScreen(),
      },
    );
  }
}

/// A global listener that safely handles incoming events without interrupting the build phase.
class IncomingCallListener extends StatefulWidget {
  final Widget child;

  const IncomingCallListener({Key? key, required this.child}) : super(key: key);

  @override
  State<IncomingCallListener> createState() => _IncomingCallListenerState();
}

class _IncomingCallListenerState extends State<IncomingCallListener> {
  @override
  void initState() {
    super.initState();
    _initializeCallListener();
  }

  void _initializeCallListener() {
    // Replace this with your actual Twilio, WebRTC, or socket stream listener
    // callStream.listen((callData) {
    //   _handleIncomingCall(callData);
    // });
  }

  void _handleIncomingCall(dynamic callData) {
    // SAFELY defer navigation until after the widget tree is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pushNamed(
          '/incoming_call',
          arguments: callData,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Simply return the child; DO NOT execute navigation logic here.
    return widget.child;
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SwapEat Home')),
      body: const Center(child: Text('Waiting for calls...')),
    );
  }
}

class CallScreen extends StatelessWidget {
  const CallScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red.shade900,
      body: const Center(
        child: Text(
          'Incoming Call...',
          style: TextStyle(color: Colors.white, fontSize: 24),
        ),
      ),
    );
  }
}