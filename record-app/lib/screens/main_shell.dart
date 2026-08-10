import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

import 'home_screen.dart';
import 'diet_screen.dart';
import 'run_screen.dart';
import 'profile_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _idx = 0;
  late final _pages = const [HomeScreen(), DietScreen(), RunScreen(), ProfileScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _idx, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _idx,
        onTap: (i) => setState(() => _idx = i),
        selectedIconTheme: const IconThemeData(color: C.ink),
        unselectedIconTheme: const IconThemeData(color: C.slate),
        selectedLabelStyle: T.caption.copyWith(color: C.ink, fontWeight: FontWeight.w600),
        unselectedLabelStyle: T.caption.copyWith(color: C.slate),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: '首页'),
          BottomNavigationBarItem(icon: Icon(Icons.restaurant_outlined), activeIcon: Icon(Icons.restaurant), label: '饮食'),
          BottomNavigationBarItem(icon: Icon(Icons.directions_run_outlined), activeIcon: Icon(Icons.directions_run), label: '跑步'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: '我的'),
        ],
      ),
    );
  }
}
