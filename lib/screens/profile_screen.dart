import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../accessibility/accessibility_labels.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../models/achievement.dart';
import '../models/book_review.dart';
import '../services/badge_refresh_notifier.dart';
import '../services/friend_code_service.dart';
import '../services/storage_service.dart';
import '../services/friend_service.dart';
import '../services/activity_stream_service.dart';
import 'account_settings_screen.dart';
import 'friends_screen.dart';
import 'qr_scanner_screen.dart';
import 'activity_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = ShelfdThemeScope.colorsOf(context);
    final isBatman = ShelfdThemeScope.of(context).theme == ShelfdTheme.batman;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: c.scaffoldBg,
        body: SafeArea(
          child: Column(
            children: [
              // Shared header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: SizedBox(
                  height: 40,
                  child: Row(
                    children: [
                    const Icon(Icons.person, size: 28),
                    const SizedBox(width: 8),
                    Image.asset(
                      'assets/images/shelfd_brand_name.png',
                      height: 18,
                      fit: BoxFit.contain,
                      excludeFromSemantics: true,
                    ),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          'Profile',
                          textAlign: TextAlign.center,
                          style: isBatman
                              ? GoogleFonts.orbitron(fontSize: 19)
                              : const TextStyle(fontSize: 19),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 96,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          icon: const Icon(Icons.settings_outlined),
                          tooltip: 'Open account settings',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AccountSettingsScreen(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                ),
              ),

              // Tabs
              TabBar(
                tabs: [
                  Tab(
                    icon: Semantics(
                      label: 'Profile details tab',
                      child: ExcludeSemantics(child: Icon(Icons.person_outline)),
                    ),
                  ),
                  Tab(
                    icon: Semantics(
                      label: 'Reading statistics tab',
                      child: ExcludeSemantics(child: Icon(Icons.bar_chart)),
                    ),
                  ),
                ],
              ),

              // Tab content
              const Expanded(
                child: TabBarView(
                  children: [
                    _UserProfileTab(),
                    _StatsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── User Profile Tab ────────────────────────────────────────────────────────

class _UserProfileTab extends StatefulWidget {
  const _UserProfileTab();

  @override
  State<_UserProfileTab> createState() => _UserProfileTabState();
}

class _UserProfileTabState extends State<_UserProfileTab> {
  final _authService = AuthService();
  String? _avatarAsset;
  String? _username;
  StreamSubscription<String?>? _usernameSub;
  List<String> _avatarAssets = [];
  int _bookCount = 0;
  int _pendingRequestCount = 0;
  int _newlyAcceptedCount = 0;
  int _newlyReceivedAcceptedCount = 0;
  int _activityCount = 0;
  String? _friendCode;
  StreamSubscription? _requestSub;
  StreamSubscription? _sentSub;
  StreamSubscription? _activitySub;
  Set<String> _seenAcceptedIds = {};
  Set<String> _seenReceivedAcceptedIds = {};
  List<Map<String, dynamic>> _lastSentDocs = [];
  List<Map<String, dynamic>> _lastReceivedDocs = [];

  @override
  void initState() {
    super.initState();
    _loadAvatar();
    _loadAvatarAssets();
    _loadBookCount();
    _loadSeenIds();
    _loadFriendCode();
    _usernameSub = _authService.usernameStream.listen((u) {
      if (mounted) setState(() => _username = u);
    });
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
      _activitySub = ActivityStreamService.unseenCountStream(myUid).listen((count) {
        if (mounted) setState(() => _activityCount = count);
      });
    }
  }

  @override
  void dispose() {
    BadgeRefreshNotifier.removeListener(_refreshSeenIds);
    _usernameSub?.cancel();
    _requestSub?.cancel();
    _sentSub?.cancel();
    _activitySub?.cancel();
    super.dispose();
  }

  Future<void> _loadSeenIds() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _seenAcceptedIds =
          Set<String>.from(prefs.getStringList('seen_accepted_ids') ?? []);
      _seenReceivedAcceptedIds =
          Set<String>.from(prefs.getStringList('seen_received_accepted_ids') ?? []);
    });
    _recalcNewlyAccepted();
    _recalcNewlyReceivedAccepted();
  }

  Future<void> _refreshSeenIds() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _seenAcceptedIds =
          Set<String>.from(prefs.getStringList('seen_accepted_ids') ?? []);
      _seenReceivedAcceptedIds =
          Set<String>.from(prefs.getStringList('seen_received_accepted_ids') ?? []);
    });
    _recalcNewlyAccepted();
    _recalcNewlyReceivedAccepted();
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

  Future<void> _loadFriendCode() async {
    final code = await FriendCodeService.getOrCreateCode();
    if (mounted) setState(() => _friendCode = code);
  }

  Future<void> _loadAvatar() async {
    final asset = await _authService.getAvatarAsset();
    if (mounted) setState(() => _avatarAsset = asset);
  }

  Future<void> _loadBookCount() async {
    final reviews = await StorageService.getReviews();
    if (mounted) setState(() => _bookCount = reviews.length);
  }

  Future<void> _loadAvatarAssets() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = manifest
        .listAssets()
        .where((key) => key.startsWith('assets/avatars/'))
        .toList()..sort();
    if (mounted) setState(() => _avatarAssets = assets);
  }

  void _showQrDialog() {
    final code = _friendCode;
    if (code == null) return;
    final c = ShelfdThemeScope.colorsOf(context);
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      barrierDismissible: true,
      builder: (_) => GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: GestureDetector(
            onTap: () {}, // prevent closing when tapping the card itself
            child: Container(
              margin: const EdgeInsets.all(32),
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height - 80,
              ),
              decoration: BoxDecoration(
                color: c.cardBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: SingleChildScrollView(
                child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Scan to add me on Shelfd',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  QrImageView(
                    data: FriendCodeService.deepLinkForCode(code),
                    version: QrVersions.auto,
                    size: 240,
                    backgroundColor: Colors.white,
                  ),
                  const SizedBox(height: 8),
                  if (_username?.isNotEmpty == true)
                    Text(
                      '@$_username',
                      style: TextStyle(
                          fontSize: 14, color: Colors.grey.shade600),
                    ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const QrScannerScreen(),
                        ));
                      },
                      icon: const Icon(Icons.qr_code_scanner, size: 18),
                      label: const Text("Scan a Friend's Code"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: c.brandColor,
                        side: BorderSide(color: c.brandColor),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap anywhere outside to dismiss',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showEnlargedAvatar() {
    final c = ShelfdThemeScope.colorsOf(context);
    final user = FirebaseAuth.instance.currentUser;
    final ImageProvider? image = _avatarAsset != null
        ? AssetImage(_avatarAsset!) as ImageProvider
        : (user?.photoURL != null ? NetworkImage(user!.photoURL!) : null);
    if (image == null) return;

    // Build the message pool: 6 generic messages + any avatar-specific ones.
    final messages = [
      'Looking good!',
      'I like it!',
      'Very stylish 😎',
      "Now that's an avatar!",
      'Iconic 👌',
      'A true Shelfd legend!',
    ];
    if (_avatarAsset != null) {
      if (_avatarAsset!.contains('sherlock')) {
        messages.add('Elementary my dear Watson');
      }
      if (_avatarAsset!.contains('godfather')) {
        messages.add("I'm going to make him an offer he can't refuse");
      }
      if (_avatarAsset!.contains('ronaldinho')) {
        messages.add('Ronaldinhoooooo :)');
      }
      if (_avatarAsset!.contains('albert')) {
        messages.add('If I were to start taking care of my grooming, I would no longer be my own self.');
      }
    }

    // Mutable state lives outside StatefulBuilder so it survives rebuilds.
    int tapCount = 0;
    DateTime? firstTapTime;
    int messageIndex = 0;
    String? visibleMessage;

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      barrierDismissible: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          void handleAvatarTap() {
            final now = DateTime.now();
            if (firstTapTime == null ||
                now.difference(firstTapTime!).inMilliseconds > 800) {
              tapCount = 1;
              firstTapTime = now;
            } else {
              tapCount++;
            }
            if (tapCount >= 3) {
              tapCount = 0;
              firstTapTime = null;
              final msg = messages[messageIndex % messages.length];
              messageIndex++;
              setDialogState(() => visibleMessage = msg);
            }
          }

          return Semantics(
            container: true,
            label: 'Profile picture preview',
            hint: 'Double tap outside the picture to close',
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              behavior: HitTestBehavior.opaque,
              child: Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Semantics(
                      button: true,
                      image: true,
                      label: 'Enlarged profile picture',
                      hint: 'Double tap to interact with the picture',
                      child: GestureDetector(
                        onTap: handleAvatarTap,
                        child: ExcludeSemantics(
                          child: themedAvatar(
                            colors: c,
                            child: CircleAvatar(
                              radius: 140,
                              backgroundImage: image,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (visibleMessage != null)
                    Positioned(
                      top: 300, // 280px avatar + 20px gap
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(ctx).size.width - 64,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.92),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Text(
                            visibleMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAvatarPicker() {
    String? pendingAvatar = _avatarAsset;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => DraggableScrollableSheet(
        initialChildSize: 0.95,
        minChildSize: 0.75,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final c = ShelfdThemeScope.colorsOf(context);
              final textScale = MediaQuery.textScalerOf(context).scale(1);
              final minAvatarExtent = (textScale > 1.2 || constraints.maxWidth < 360)
                  ? 96.0
                  : 80.0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OverflowBar(
                    alignment: MainAxisAlignment.spaceBetween,
                    overflowAlignment: OverflowBarAlignment.end,
                    overflowDirection: VerticalDirection.down,
                    spacing: 12,
                    overflowSpacing: 8,
                    children: [
                      const Text(
                        'Choose an avatar',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: () async {
                          Navigator.of(sheetContext).pop();
                          if (pendingAvatar != null && pendingAvatar != _avatarAsset) {
                            await _authService.saveAvatarAsset(pendingAvatar!);
                            if (mounted) {
                              setState(() => _avatarAsset = pendingAvatar!);
                            }
                          }
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.green,
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: GridView.builder(
                      controller: scrollController,
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: minAvatarExtent,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: _avatarAssets.length,
                      itemBuilder: (_, i) {
                        final asset = _avatarAssets[i];
                        final isSelected = pendingAvatar == asset;
                        return GestureDetector(
                          onTap: () {
                            setSheetState(() => pendingAvatar = asset);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(color: Colors.green, width: 5)
                                  : Border.all(color: Colors.transparent, width: 5),
                            ),
                            child: themedAvatar(
                              colors: c,
                              child: CircleAvatar(
                                backgroundImage: AssetImage(asset),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        ),
      ),
    );
  }

  String _ordinal(int day) {
    if (day >= 11 && day <= 13) return '${day}th';
    switch (day % 10) {
      case 1: return '${day}st';
      case 2: return '${day}nd';
      case 3: return '${day}rd';
      default: return '${day}th';
    }
  }

  String _formatJoinDate(DateTime dt) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${_ordinal(dt.day)} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final c = ShelfdThemeScope.colorsOf(context);
    final isBatman = ShelfdThemeScope.of(context).theme == ShelfdTheme.batman;
    final isHighContrast = ShelfdThemeScope.of(context).theme == ShelfdTheme.highContrast;
    final hcShape = isHighContrast
        ? RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: c.brandColor, width: 2.0),
          )
        : null;
    final user = FirebaseAuth.instance.currentUser;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),

          // Avatar
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Force the Stack's layout size to include the overflow button area
              const SizedBox(width: 124, height: 104),
              Positioned(
                left: 0,
                top: 0,
                child: Semantics(
                  button: true,
                  label: avatarSemanticLabel(isCurrentUser: true),
                  hint: 'Opens your profile picture',
                  child: GestureDetector(
                    onTap: _showEnlargedAvatar,
                    child: ExcludeSemantics(
                      child: themedAvatar(
                        colors: c,
                        child: CircleAvatar(
                          radius: 52,
                          backgroundColor: c.avatarBg,
                          backgroundImage: _avatarAsset != null
                              ? AssetImage(_avatarAsset!) as ImageProvider
                              : (user?.photoURL != null
                                  ? NetworkImage(user!.photoURL!)
                                  : null),
                          child: _avatarAsset == null && user?.photoURL == null
                              ? Icon(Icons.person, size: 52, color: c.brandColor)
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: c.primaryAccent,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.edit, size: 16, color: Colors.white),
                    tooltip: 'Edit profile picture',
                    onPressed: _showAvatarPicker,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Join date
          if (user?.metadata.creationTime != null)
            Text(
              'Date joined: ${_formatJoinDate(user!.metadata.creationTime!.toLocal())}',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),

          const SizedBox(height: 16),

          // Username card (only shown if set)
          if (_username?.isNotEmpty == true) ...[  
            Card(
              shape: hcShape,
              child: ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Username',
                    style: TextStyle(fontSize: 13, color: Colors.grey)),
                subtitle: Text(
                  _username!,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w500),
                ),
                trailing: Semantics(
                  button: _friendCode != null,
                  label: 'Show friend QR code',
                  child: GestureDetector(
                    onTap: _friendCode != null ? _showQrDialog : null,
                    child: ExcludeSemantics(
                      child: Icon(
                        Icons.qr_code_2,
                        size: MediaQuery.textScalerOf(context).scale(24),
                        color: _friendCode != null
                            ? c.brandColor
                            : Colors.grey.shade300,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Email card
          Card(
            shape: hcShape,
            child: ListTile(
              leading: const Icon(Icons.email_outlined),
              title: const Text('Email', style: TextStyle(fontSize: 13, color: Colors.grey)),
              subtitle: Text(
                user?.email ?? 'No email',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
          ),

          // ── Achievements ──────────────────────────────────────────────────
          const SizedBox(height: 32),
          Align(
            alignment: Alignment.centerLeft,
            child: Semantics(
              header: true,
              child: Text(
                'Achievements',
                style: isBatman
                    ? GoogleFonts.orbitron(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: c.brandColor)
                    : TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: c.brandColor),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 16,
            children: kAchievements
                .where((a) => !a.hidden || _bookCount >= a.threshold)
                .map((a) {
              final unlocked = _bookCount >= a.threshold;
              return _AchievementMedal(
                label: a.label,
                emoji: a.emoji,
                unlocked: unlocked,
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // ── Friends ──────────────────────────────────────────────────────
          Align(
            alignment: Alignment.centerLeft,
            child: Semantics(
              header: true,
              child: Text(
                'Friends',
                style: isBatman
                    ? GoogleFonts.orbitron(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: c.brandColor)
                    : TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: c.brandColor),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Semantics(
            button: true,
            label: 'View friends',
            hint: 'Opens your friends screen',
            excludeSemantics: true,
            child: Card(
              shape: hcShape,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FriendsScreen()),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 16, horizontal: 20),
                  child: Row(
                    children: [
                      const Text('👥',
                          style: TextStyle(fontSize: 32)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'View Friends',
                          style: isBatman
                              ? GoogleFonts.orbitron(
                                  fontSize: 16, fontWeight: FontWeight.w500)
                              : const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      ),
                      if (_pendingRequestCount + _newlyAcceptedCount + _newlyReceivedAcceptedCount > 0) ...
                        [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: c.primaryAccent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_pendingRequestCount + _newlyAcceptedCount + _newlyReceivedAcceptedCount}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                      Icon(Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.grey.shade500),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── Activity Stream ───────────────────────────────────────────────
          Align(
            alignment: Alignment.centerLeft,
            child: Semantics(
              header: true,
              child: Text(
                'Activity',
                style: isBatman
                    ? GoogleFonts.orbitron(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: c.brandColor)
                    : TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: c.brandColor),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            shape: hcShape,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ActivityScreen()),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: 16, horizontal: 20),
                child: Row(
                  children: [
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: Stack(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: c.primaryAccent.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.groups,
                                size: 22, color: c.primaryAccent),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: c.primaryAccent,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.favorite,
                                  size: 10, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Activity Stream',
                        style: isBatman
                            ? GoogleFonts.orbitron(
                                fontSize: 16, fontWeight: FontWeight.w500)
                            : const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ),
                    if (_activityCount > 0) ...[  
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: c.primaryAccent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$_activityCount',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Icon(Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.grey.shade500),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─── Change Password Dialog ───────────────────────────────────────────────────

class _ChangePasswordDialog extends StatefulWidget {
  final AuthService authService;
  const _ChangePasswordDialog({required this.authService});

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _error;
  bool _isLoading = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = ShelfdThemeScope.colorsOf(context);
    return AlertDialog(
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: const Text('Change Password'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _currentController,
              obscureText: _obscureCurrent,
              decoration: InputDecoration(
                labelText: 'Current password',
                prefixIcon: const Icon(Icons.lock_outlined),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscureCurrent
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () =>
                      setState(() => _obscureCurrent = !_obscureCurrent),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newController,
              obscureText: _obscureNew,
              decoration: InputDecoration(
                labelText: 'New password',
                prefixIcon: const Icon(Icons.lock_outlined),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscureNew
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () =>
                      setState(() => _obscureNew = !_obscureNew),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmController,
              obscureText: _obscureConfirm,
              decoration: InputDecoration(
                labelText: 'Confirm new password',
                prefixIcon: const Icon(Icons.lock_outlined),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirm
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: c.primaryAccent,
            foregroundColor: Colors.white,
          ),
          onPressed: _isLoading
              ? null
              : () async {
                  final current = _currentController.text;
                  final newPwd = _newController.text;
                  final confirm = _confirmController.text;
                  if (current.isEmpty || newPwd.isEmpty || confirm.isEmpty) {
                    setState(() => _error = 'Please fill in all fields.');
                    return;
                  }
                  if (newPwd.length < 6) {
                    setState(() => _error =
                        'New password must be at least 6 characters.');
                    return;
                  }
                  if (newPwd != confirm) {
                    setState(
                        () => _error = 'New passwords do not match.');
                    return;
                  }
                  setState(() {
                    _isLoading = true;
                    _error = null;
                  });
                  try {
                    await widget.authService.updatePassword(current, newPwd);
                    if (mounted) Navigator.of(context).pop(true);
                  } on FirebaseAuthException catch (e) {
                    final msg = e.code == 'wrong-password' ||
                            e.code == 'invalid-credential'
                        ? 'Current password is incorrect.'
                        : 'Could not update password. Please try again.';
                    if (mounted) {
                      setState(() {
                        _error = msg;
                        _isLoading = false;
                      });
                    }
                  }
                },
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Update Password'),
        ),
      ],
    );
  }
}

// ─── Stats Tab ────────────────────────────────────────────────────────────────

class _StatsTab extends StatefulWidget {
  const _StatsTab();

  @override
  State<_StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<_StatsTab> {
  List<BookReview> reviews = [];
  bool _booksExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await StorageService.getReviews();
    setState(() => reviews = data);
  }

  int get totalCompleted => reviews.length;
  int get totalPhysical =>
      reviews.where((r) => r.format == BookFormat.physical).length;
  int get totalAudiobook =>
      reviews.where((r) => r.format == BookFormat.audiobook).length;
  int get totalBraille =>
      reviews.where((r) => r.format == BookFormat.braille).length;

  List<MapEntry<String, int>> get topAuthors {
    final Map<String, int> counts = {};
    for (final r in reviews) {
      counts[r.author] = (counts[r.author] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(3).toList();
  }

  List<BookReview> get topRated {
    final sorted = List<BookReview>.from(reviews)
      ..sort((a, b) => b.rating.compareTo(a.rating));
    return sorted.take(3).toList();
  }

  List<MapEntry<int, int>> get booksByYear {
    final Map<int, int> counts = {};
    for (final r in reviews) {
      final y = r.dateAdded.year;
      counts[y] = (counts[y] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final isBatman = ShelfdThemeScope.of(context).theme == ShelfdTheme.batman;
    final c = ShelfdThemeScope.colorsOf(context);
    final isHighContrast = ShelfdThemeScope.of(context).theme == ShelfdTheme.highContrast;
    final hcShape = isHighContrast
        ? RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: c.brandColor, width: 2.0),
          )
        : null;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            shape: hcShape,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _booksExpanded = !_booksExpanded),
              child: ListTile(
                leading: const Icon(Icons.library_books),
                title: const Text("Total Books Completed"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      totalCompleted.toString(),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: _booksExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(Icons.expand_more),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: _booksExpanded
                ? Column(
                    children: [
                      const SizedBox(height: 8),
                      Card(
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        shape: hcShape,
                        child: ListTile(
                          dense: true,
                          leading: const Icon(Icons.menu_book, size: 20),
                          title: const Text("Total Books Read", style: TextStyle(fontSize: 13)),
                          trailing: Text(
                            totalPhysical.toString(),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      Card(
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        shape: hcShape,
                        child: ListTile(
                          dense: true,
                          leading: const Icon(Icons.headphones, size: 20),
                          title: const Text("Total Books Listened To", style: TextStyle(fontSize: 13)),
                          trailing: Text(
                            totalAudiobook.toString(),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      Card(
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        shape: hcShape,
                        child: ListTile(
                          dense: true,
                          leading: const Icon(Icons.grain, size: 20),
                          title: const Text("Total Books Read Braille", style: TextStyle(fontSize: 13)),
                          trailing: Text(
                            totalBraille.toString(),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 20),
          Text(
            "Top Authors",
            style: isBatman
                ? GoogleFonts.orbitron(
                    fontSize: 18, fontWeight: FontWeight.bold)
                : const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ...topAuthors.map((a) => Card(
                shape: hcShape,
                child: ListTile(
                  title: Text(a.key),
                  trailing: Text("${a.value} books"),
                ),
              )),
          const SizedBox(height: 20),
          Text(
            "Top Rated Books",
            style: isBatman
                ? GoogleFonts.orbitron(
                    fontSize: 18, fontWeight: FontWeight.bold)
                : const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ...topRated.map((b) => Card(
                color: b.isFavourite
                    ? Colors.amber.withOpacity(0.15)
                    : null,
                shape: hcShape,
                child: ListTile(
                  title: Text(b.title),
                  subtitle: Text(b.author),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 18),
                      Text('${b.rating % 1 == 0 ? b.rating.toInt() : b.rating.toStringAsFixed(1)}/10'),
                    ],
                  ),
                ),
              )),
          const SizedBox(height: 20),
          Text(
            "Stats by Year",
            style: isBatman
                ? GoogleFonts.orbitron(
                    fontSize: 18, fontWeight: FontWeight.bold)
                : const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ...booksByYear.map((entry) => Card(
                shape: hcShape,
                child: ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: Text(entry.key.toString()),
                  trailing: Text(
                    entry.value.toString(),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

// ─── Achievements ─────────────────────────────────────────────────────────────

// Achievement definitions live in lib/models/achievement.dart (kAchievements).

class _AchievementMedal extends StatelessWidget {
  final String label;
  final String emoji;
  final bool unlocked;

  static const _legendAchievementLabel =
      '1000 Books Completed.\nYou achieved it all!\nYou are a LEGEND!';

  const _AchievementMedal({
    required this.label,
    required this.emoji,
    required this.unlocked,
  });

  void _showEnlarged(BuildContext context) {
    final isLockedLegendAchievement =
        !unlocked && label == _legendAchievementLabel;
    int tapCount = 0;
    DateTime? firstTapTime;
    String? visibleMessage;

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      barrierDismissible: true,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          void handleMedalTap() {
            if (!isLockedLegendAchievement) {
              return;
            }

            final now = DateTime.now();
            if (firstTapTime == null ||
                now.difference(firstTapTime!).inMilliseconds > 500) {
              tapCount = 1;
              firstTapTime = now;
              return;
            }

            tapCount++;
            if (tapCount >= 2) {
              tapCount = 0;
              firstTapTime = null;
              setDialogState(() => visibleMessage = 'Is this even possible?!');
            }
          }

          return GestureDetector(
            onTap: () => Navigator.of(dialogContext).pop(),
            behavior: HitTestBehavior.opaque,
            child: Center(
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  GestureDetector(
                    onTap: handleMedalTap,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: unlocked
                                ? const Color(0xffFFF3CD)
                                : Colors.grey.shade200,
                            border: Border.all(
                              color: unlocked
                                  ? const Color(0xffD4A017)
                                  : Colors.grey.shade400,
                              width: 5,
                            ),
                            boxShadow: unlocked
                                ? [
                                    BoxShadow(
                                      color: const Color(0xffD4A017)
                                          .withOpacity(0.5),
                                      blurRadius: 24,
                                      offset: const Offset(0, 4),
                                    )
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: unlocked
                                ? Text(emoji,
                                    style: const TextStyle(fontSize: 72))
                                : const Icon(Icons.lock_outline,
                                    size: 72, color: Colors.grey),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color:
                                  unlocked ? Colors.white : Colors.grey.shade400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (visibleMessage != null)
                    Positioned(
                      top: 180,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(dialogContext).size.width - 64,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.92),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Text(
                            visibleMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _medalCircle({required double size, required double iconSize, required double fontSize}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: unlocked ? const Color(0xffFFF3CD) : Colors.grey.shade200,
        border: Border.all(
          color: unlocked ? const Color(0xffD4A017) : Colors.grey.shade400,
          width: 2.5,
        ),
        boxShadow: unlocked
            ? [
                BoxShadow(
                  color: const Color(0xffD4A017).withOpacity(0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ]
            : null,
      ),
      child: Center(
        child: unlocked
            ? Text(emoji, style: TextStyle(fontSize: fontSize))
            : Icon(Icons.lock_outline, size: iconSize, color: Colors.grey),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = ShelfdThemeScope.colorsOf(context);
    return Semantics(
      button: true,
      label: '${unlocked ? 'Unlocked' : 'Locked'} achievement. ${emojiSemanticLabel(emoji)}. $label',
      hint: 'Opens achievement details',
      child: GestureDetector(
        onTap: () => _showEnlarged(context),
        child: ExcludeSemantics(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _medalCircle(size: 64, iconSize: 28, fontSize: 28),
              const SizedBox(height: 6),
              SizedBox(
                width: 72,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: unlocked ? c.brandColor : Colors.grey,
                    fontWeight: unlocked ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
