import 'dart:async';

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/friend_service.dart';
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
  int _pendingRequestCount = 0;
  StreamSubscription? _requestSub;

  @override
  void initState() {
    super.initState();
    // Backfill createdAt + privacyLevel for existing users on first launch
    AuthService().ensureUserProfile();
    _requestSub = FriendService.receivedRequestsStream().listen((snap) {
      if (!mounted) return;
      final pending =
          snap.docs.where((d) => d.data()['status'] != 'accepted').length;
      setState(() => _pendingRequestCount = pending);
    });
  }

  @override
  void dispose() {
    _requestSub?.cancel();
    super.dispose();
  }

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
        selectedFontSize: 11,
        unselectedFontSize: 10,

        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: "Home",
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: "Search",
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.menu_book),
            label: "Log",
          ),
          BottomNavigationBarItem(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.person_outline),
                if (_pendingRequestCount > 0)
                  Positioned(
                    top: -4,
                    right: -6,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: Colors.deepOrange,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$_pendingRequestCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            label: "Profile",
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.travel_explore),
            label: "Future Reads",
          ),
        ],
      ),
    );
  }
}
