import 'package:flutter/material.dart';
import 'package:myapp/screens/livreur/livreur_billets_screen.dart';
import 'package:myapp/screens/livreur/livreur_profile_screen.dart';

class LivreurNavigation extends StatefulWidget {
  const LivreurNavigation({super.key});

  @override
  State<LivreurNavigation> createState() => _LivreurNavigationState();
}

class _LivreurNavigationState extends State<LivreurNavigation> {
  int _currentIndex = 0;

  final _pages = const [
    LivreurBilletsScreen(),
    LivreurProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _pages[_currentIndex]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.confirmation_num_outlined),
            activeIcon: Icon(Icons.confirmation_num),
            label: 'Mes billets',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Mon profil',
          ),
        ],
      ),
    );
  }
}
