import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../services/badge_refresh_notifier.dart';
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
  int _newlyAcceptedCount = 0;
  StreamSubscription? _requestSub;
  StreamSubscription? _sentSub;
  Set<String> _seenAcceptedIds = {};
  List<Map<String, dynamic>> _lastSentDocs = [];

  @override
  void initState() {
    super.initState();
    AuthService().ensureUserProfile();
    _initStreams();
  }

  Future<void> _initStreams() async {
    final prefs = await SharedPreferences.getInstance();
    _seenAcceptedIds =
        Set<String>.from(prefs.getStringList('seen_accepted_ids') ?? []);

    _requestSub = FriendService.receivedRequestsStream().listen((snap) {
      if (!mounted) return;
      final pending =
          snap.docs.where((d) => d.data()['status'] != 'accepted').length;
      setState(() => _pendingRequestCount = pending);
    });

    _sentSub = FriendService.sentRequestsStream().listen((snap) {
      if (!mounted) return;
      _lastSentDocs = snap.docs
          .map((d) => {'id': d.id, 'status': d.data()['status'] as String?})
          .toList();
      _recalcNewlyAccepted();
    });

    BadgeRefreshNotifier.addListener(_refreshSeenIds);
  }

  void _recalcNewlyAccepted() {
    final count = _lastSentDocs
        .where((d) =>
            d['status'] == 'accepted' &&
            !_seenAcceptedIds.contains(d['id'] as String))
        .length;
    if (mounted) setState(() => _newlyAcceptedCount = count);
  }

  Future<void> _refreshSeenIds() async {
    final prefs = await SharedPreferences.getInstance();
    _seenAcceptedIds =
        Set<String>.from(prefs.getStringList('seen_accepted_ids') ?? []);
    _recalcNewlyAccepted();
  }

  @override
  void dispose() {
    BadgeRefreshNotifier.removeListener(_refreshSeenIds);
    _requestSub?.cancel();
    _sentSub?.cancel();
    super.dispose();
  }

  void onItemTapped(int index) {
    setState(() {
      selectedIndex = index;
      _searchAutoFocus = false;
    });
    // Refresh seen IDs whenever the user navigates away from the Profile tab
    if (index != 3) _refreshSeenIds();
  }

  void _navigateToSearchFocused() {
    setState(() {
      selectedIndex = 1;
      _searchAutoFocus = true;
    });
    _refreshSeenIds();
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
                if (_pendingRequestCount + _newlyAcceptedCount > 0)
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
                          '${_pendingRequestCount + _newlyAcceptedCount}',
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
