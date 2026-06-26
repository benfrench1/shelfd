import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../services/activity_stream_service.dart';
import '../theme/app_theme.dart';
import '../services/badge_refresh_notifier.dart';
import '../services/friend_code_service.dart';
import '../services/friend_service.dart';
import '../models/user_profile.dart';
import 'friends_screen.dart';
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
  int _newlyReceivedAcceptedCount = 0;
  int _activityCount = 0;
  StreamSubscription? _requestSub;
  StreamSubscription? _sentSub;
  StreamSubscription? _linkSub;
  StreamSubscription? _activitySub;
  Set<String> _seenAcceptedIds = {};
  Set<String> _seenReceivedAcceptedIds = {};
  List<Map<String, dynamic>> _lastSentDocs = [];
  List<Map<String, dynamic>> _lastReceivedDocs = [];
  // Used to deduplicate the initial deep link vs the stream re-emitting it.
  Uri? _initialDeepLink;

  // Easter egg: track rapid taps on the Future Reads tab.
  int _futureReadsTapCount = 0;
  DateTime? _firstFutureReadsTap;

  @override
  void initState() {
    super.initState();
    AuthService().ensureUserProfile();
    _initStreams();
    _setupDeepLinks();
  }

  Future<void> _initStreams() async {
    final prefs = await SharedPreferences.getInstance();
    _seenAcceptedIds =
        Set<String>.from(prefs.getStringList('seen_accepted_ids') ?? []);
    _seenReceivedAcceptedIds =
        Set<String>.from(prefs.getStringList('seen_received_accepted_ids') ?? []);

    _requestSub = FriendService.receivedRequestsStream().listen((snap) {
      if (!mounted) return;
      final pending =
          snap.docs.where((d) => d.data()['status'] != 'accepted').length;
      _lastReceivedDocs = snap.docs
          .map((d) => {'id': d.id, 'status': d.data()['status'] as String?})
          .toList();
      setState(() => _pendingRequestCount = pending);
      _recalcNewlyReceivedAccepted();
    });

    _sentSub = FriendService.sentRequestsStream().listen((snap) {
      if (!mounted) return;
      _lastSentDocs = snap.docs
          .map((d) => {'id': d.id, 'status': d.data()['status'] as String?})
          .toList();
      _recalcNewlyAccepted();
    });

    BadgeRefreshNotifier.addListener(_refreshSeenIds);

    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid != null) {
      _activitySub = ActivityStreamService.unseenCountStream(myUid)
          .listen((count) {
        if (mounted) setState(() => _activityCount = count);
      });
    }
  }

  void _recalcNewlyAccepted() {
    final count = _lastSentDocs
        .where((d) =>
            d['status'] == 'accepted' &&
            !_seenAcceptedIds.contains(d['id'] as String))
        .length;
    if (mounted) setState(() => _newlyAcceptedCount = count);
  }

  void _recalcNewlyReceivedAccepted() {
    final count = _lastReceivedDocs
        .where((d) =>
            d['status'] == 'accepted' &&
            !_seenReceivedAcceptedIds.contains(d['id'] as String))
        .length;
    if (mounted) setState(() => _newlyReceivedAcceptedCount = count);
  }

  Future<void> _refreshSeenIds() async {
    final prefs = await SharedPreferences.getInstance();
    _seenAcceptedIds =
        Set<String>.from(prefs.getStringList('seen_accepted_ids') ?? []);
    _seenReceivedAcceptedIds =
        Set<String>.from(prefs.getStringList('seen_received_accepted_ids') ?? []);
    _recalcNewlyAccepted();
    _recalcNewlyReceivedAccepted();
  }

  // ─── Deep link handling ──────────────────────────────────────────────────

  Future<void> _setupDeepLinks() async {
    final appLinks = AppLinks();
    // Handle the link that cold-started the app.
    try {
      final initial = await appLinks.getInitialLink();
      if (initial != null) {
        _initialDeepLink = initial;
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _handleDeepLink(initial));
      }
    } catch (_) {}
    // Handle links while the app is already running.
    // On some platforms/versions app_links re-emits the initial link through
    // the stream — skip it once if it matches what we already handled.
    _linkSub = appLinks.uriLinkStream.listen((uri) {
      if (_initialDeepLink != null && uri == _initialDeepLink) {
        _initialDeepLink = null; // only suppress the first duplicate
        return;
      }
      _handleDeepLink(uri);
    }, onError: (_) {});
  }

  Future<void> _handleDeepLink(Uri uri) async {
    if (uri.scheme != 'shelfd' || uri.host != 'friend') return;
    final code = uri.pathSegments.firstOrNull;
    if (code == null || code.isEmpty) return;

    // Ignore if not logged in.
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;

    final uid = await FriendCodeService.uidFromCode(code);
    if (uid == null) return;
    // Can't add yourself.
    if (uid == me.uid) return;

    final profile = await FriendService.getUserProfile(uid);
    if (profile == null || !mounted) return;

    _showQrAddDialog(profile);
  }

  void _showQrAddDialog(UserProfile profile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QrAddSheet(
        profile: profile,
        onAccepted: () {
          // Navigate to Profile tab so user sees Friends screen easily.
          setState(() => selectedIndex = 3);
        },
      ),
    );
  }

  @override
  void dispose() {
    BadgeRefreshNotifier.removeListener(_refreshSeenIds);
    _requestSub?.cancel();
    _sentSub?.cancel();
    _linkSub?.cancel();
    _activitySub?.cancel();
    super.dispose();
  }

  void onItemTapped(int index) {
    setState(() {
      selectedIndex = index;
      _searchAutoFocus = false;
    });
    // Refresh seen IDs whenever the user navigates away from the Profile tab
    if (index != 3) _refreshSeenIds();

    // Easter egg: 5 quick taps on Future Reads.
    if (index == 4) {
      final now = DateTime.now();
      if (_firstFutureReadsTap == null ||
          now.difference(_firstFutureReadsTap!) > const Duration(seconds: 3)) {
        _futureReadsTapCount = 1;
        _firstFutureReadsTap = now;
      } else {
        _futureReadsTapCount++;
        if (_futureReadsTapCount >= 5) {
          _futureReadsTapCount = 0;
          _firstFutureReadsTap = null;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: const Text(
                  'What does the future hold I wonder? Will Reading FC ever win the Champions League :)',
                ),
                duration: const Duration(seconds: 4),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                margin: const EdgeInsets.all(16),
              ),
            );
        }
      }
    } else {
      _futureReadsTapCount = 0;
      _firstFutureReadsTap = null;
    }
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
      SearchScreen(autoFocus: _searchAutoFocus, onNavigate: onItemTapped),
      const LogScreen(),
      const ProfileScreen(),
      WishlistScreen(onNavigate: onItemTapped),
    ];

    final c = ShelfdThemeScope.colorsOf(context);
    return Scaffold(
      body: screens[selectedIndex],

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: onItemTapped,
        type: BottomNavigationBarType.fixed,

        selectedItemColor: c.primaryAccent,
        unselectedItemColor: c.textSecondary,
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
                if (_pendingRequestCount + _newlyAcceptedCount + _newlyReceivedAcceptedCount + _activityCount > 0)
                  Positioned(
                    top: -4,
                    right: -6,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: c.primaryAccent,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${_pendingRequestCount + _newlyAcceptedCount + _newlyReceivedAcceptedCount + _activityCount}',
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

// ─── QR Add Friend Sheet ──────────────────────────────────────────────────────

/// Bottom sheet shown when User A scans User B's QR code.
/// Presents a simple Accept / Not Now choice and creates an instant friendship.
class _QrAddSheet extends StatefulWidget {
  final UserProfile profile;
  final VoidCallback onAccepted;

  const _QrAddSheet({required this.profile, required this.onAccepted});

  @override
  State<_QrAddSheet> createState() => _QrAddSheetState();
}

class _QrAddSheetState extends State<_QrAddSheet> {
  bool _loading = false;

  Future<void> _accept() async {
    setState(() => _loading = true);
    try {
      await FriendService.acceptViaQr(widget.profile);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Something went wrong. Please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    widget.onAccepted();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.profile.displayName} added as a friend!'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final ImageProvider? avatar = profile.avatarAsset != null
        ? AssetImage(profile.avatarAsset!) as ImageProvider
        : profile.photoUrl != null
            ? NetworkImage(profile.photoUrl!)
            : null;

    final c = ShelfdThemeScope.colorsOf(context);
    return Container(
      decoration: BoxDecoration(
        color: c.scaffoldBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Avatar
          themedAvatar(
            colors: c,
            child: CircleAvatar(
              radius: 44,
              backgroundColor: c.avatarBg,
              backgroundImage: avatar,
              child: avatar == null
                  ? Icon(Icons.person, size: 44, color: c.brandColor)
                  : null,
            ),
          ),
          const SizedBox(height: 16),

          // Name
          Text(
            profile.displayName,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          if (profile.username?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              '@${profile.username}',
              style: TextStyle(fontSize: 14, color: c.textSecondary),
            ),
          ],
          const SizedBox(height: 6),

          // QR context label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: c.primaryAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.qr_code_2, size: 14, color: c.primaryAccent),
                const SizedBox(width: 4),
                Text(
                  'Scanned via QR code',
                  style: TextStyle(fontSize: 12, color: c.primaryAccent),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _loading ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Not Now'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _loading ? null : _accept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.primaryAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Add Friend',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
