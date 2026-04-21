import 'package:flutter/material.dart';
import 'package:myapp/api.dart';
import 'package:myapp/navigation/admin_navigation.dart';
import 'package:myapp/navigation/agent_navigation.dart';
import 'package:myapp/navigation/main_navigation.dart';

void main() {
  runApp(const FlightApp());
}

class FlightApp extends StatelessWidget {
  const FlightApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Gestion de Vols',
      theme: ThemeData(
        primaryColor: const Color(0xFF039BE5),
        scaffoldBackgroundColor: const Color(0xFFF8F9FB),
        fontFamily: 'sans-serif',
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final ApiClient _api = ApiClient();
  bool _checking = true;
  String _role = 'client';

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final loggedIn = await _api.isLoggedIn;
    if (loggedIn) {
      try {
        final profile = await _api.getProfile();
        _role = profile['role']?.toString() ?? 'client';
      } catch (_) {}
    }
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_role == 'admin') return const AdminNavigation();
    if (_role == 'agent') return const AgentNavigation();
    return const MainNavigation();
  }
}
