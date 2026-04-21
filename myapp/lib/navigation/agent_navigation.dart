import 'package:flutter/material.dart';
import 'package:myapp/screens/admin/admin_dashboard_screen.dart';
import 'package:myapp/screens/admin/admin_profile_screen.dart';
import 'package:myapp/screens/agent/agent_new_booking_screen.dart';
import 'package:myapp/screens/agent/agent_reservations_screen.dart';

class AgentNavigation extends StatefulWidget {
  const AgentNavigation({super.key});

  @override
  State<AgentNavigation> createState() => _AgentNavigationState();
}

class _AgentNavigationState extends State<AgentNavigation> {
  int _currentIndex = 0;
  int _bookingKey = 0;

  void _onBookingCreated() {
    setState(() {
      _currentIndex = 1;
      _bookingKey++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const AdminDashboardScreen(),
      AgentReservationsScreen(key: ValueKey(_bookingKey)),
      AgentNewBookingScreen(onBookingCreated: _onBookingCreated),
      const AdminProfileScreen(),
    ];

    return Scaffold(
      body: SafeArea(child: pages[_currentIndex]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() {
          _currentIndex = i;
          if (i == 1) _bookingKey++;
        }),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined),   activeIcon: Icon(Icons.dashboard),    label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), activeIcon: Icon(Icons.receipt_long), label: 'Réservations'),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline),    activeIcon: Icon(Icons.add_circle),   label: 'Nouveau'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline),        activeIcon: Icon(Icons.person),       label: 'Profil'),
        ],
      ),
    );
  }
}
