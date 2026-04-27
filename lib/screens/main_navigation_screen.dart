import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'search_screen.dart';
import 'log_screen.dart';
import 'profile_screen.dart';
import 'wishlist_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState
    extends State<MainNavigationScreen> {
  int selectedIndex = 0;
  bool _searchAutoFocus = false;

  void onItemTapped(int index) {
    setState(() {
      selectedIndex = index;
      _searchAutoFocus = false;
    });
  }

  void _navigateToSearchFocused() {
    setState(() {
      selectedIndex = 1;
      _searchAutoFocus = true;
    });
    // Reset after the frame so didUpdateWidget fires only once
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _searchAutoFocus = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      HomeScreen(onNavigate: onItemTapped, onSearchTapped: _navigateToSearchFocused),
      SearchScreen(autoFocus: _searchAutoFocus),
      const LogScreen(),
      const ProfileScreen(),
      const WishlistScreen(),
    ];

    return Scaffold(
      body: screens[selectedIndex],

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: onItemTapped,
        type: BottomNavigationBarType.fixed,

        selectedItemColor: Colors.deepOrange,
        unselectedItemColor: Colors.grey,

        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: "Search",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book),
            label: "Log",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: "Profile",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.travel_explore),
            label: "Future Reads",
          ),
        ],
      ),
    );
  }
}
