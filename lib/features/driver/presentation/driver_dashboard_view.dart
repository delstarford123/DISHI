import 'package:flutter/material.dart';
import '../../deliv/presentation/deliv_driver_dashboard.dart';

class DriverDashboardView extends StatelessWidget {
  final Map<String, dynamic> user;
  const DriverDashboardView({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return DelivDriverDashboard(user: user);
  }
}
