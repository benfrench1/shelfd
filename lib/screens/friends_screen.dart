import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/friend_service.dart';
import 'friend_profile_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _searchController = TextEditingController();

  String get _myUid => FirebaseAuth.instance.currentUser!.uid;

  List<FriendRequest> _sentRequests = [];
  List<FriendRequest> _receivedRequests = [];

  StreamSubscription? _sentSub;
  StreamSubscription? _receivedSub;

  UserProfile? _searchResult;
  bool _searching = false;
  String? _searchError;

  final Map<String, UserProfile> _profileCache = {};

  @override
  void initState() {
    super.initState();
    _setupStreams();
  }

  void _setupStreams() {
    final myUid = _myUid;

    _sentSub = FriendService.sentRequestsStream().listen((snap) {
      if (!mounted) return;
      final requests = snap.docs
          .map((d) => FriendRequest.fromFirestore(d.id, myUid, d.data()))
          .toList();
      setState(() => _sentRequests = requests);
      _fetchProfiles(requests.map((r) => r.otherUid(myUid)).whereType<String>());
    });

    _receivedSub = FriendService.receivedRequestsStream().listen((snap) {
      if (!mounted) return;
      final requests = snap.docs
          .map((d) => FriendRequest.fromFirestore(d.id, myUid, d.data()))
          .toList();
      setState(() => _receivedRequests = requests);
      _fetchProfiles(requests.map((r) => r.otherUid(myUid)).whereType<String>());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _sentSub?.cancel();
    _receivedSub?.cancel();
    super.dispose();
  }

  // Derived lists

  Future<void> _fetchProfiles(Iterable<String> uids) async {
    for (final uid in uids) {
      if (_profileCache.containsKey(uid)) continue;
      final profile = await FriendService.getUserProfile(uid);
      if (profile != null && mounted) {
        setState(() => _profileCache[uid] = profile);
      }
    }
  }

  List<FriendRequest> get _friends => [
        ..._sentRequests.where((r) => r.status == FriendshipStatus.accepted),
        ..._receivedRequests
            .where((r) => r.status == FriendshipStatus.accepted),
      ];

  List<FriendRequest> get _pendingReceived => _receivedRequests
      .where((r) => r.status == FriendshipStatus.pendingReceived)
      .toList();

  List<FriendRequest> get _pendingSent => _sentRequests
      .where((r) => r.status == FriendshipStatus.pendingSent)
      .toList();

  // Actions

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _searching = true;
      _searchResult = null;
      _searchError = null;
    });

    final result = await FriendService.searchByUsername(query);
    if (!mounted) return;
    setState(() {
      _searching = false;
      _searchResult = result;
      _searchError =
          result == null ? 'No user found with that username.' : null;
    });
  }

  void _viewProfile(String uid) async {
    final profile = await FriendService.getUserProfile(uid);
    if (!mounted || profile == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => FriendProfileScreen(friend: profile)),
    );
  }

  Future<void> _sendRequest(UserProfile target) async {
    await FriendService.sendRequest(target);
    if (!mounted) return;
    setState(() {
      _searchResult = null;
      _searchController.clear();
      _searchError = null;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Friend request sent to ${target.displayName}'),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ));
  }

  Future<void> _acceptRequest(FriendRequest req) async {
    await FriendService.acceptRequest(req.id);
  }

  Future<void> _confirmDelete(FriendRequest req, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: const Text('Are you sure?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed == true) await FriendService.deleteRequest(req.id);
  }

  FriendshipStatus? _statusForUid(String uid) {
    for (final r in [..._sentRequests, ..._receivedRequests]) {
      if (r.otherUid(_myUid) == uid) return r.status;
    }
    return null;
  }

  FriendRequest? _requestForUid(String uid) {
    for (final r in [..._sentRequests, ..._receivedRequests]) {
      if (r.otherUid(_myUid) == uid) return r;
    }
    return null;
  }

  void _showPendingRequestsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final pending = _pendingReceived;
            return DraggableScrollableSheet(
              initialChildSize: 0.5,
              minChildSize: 0.5,
              maxChildSize: 0.9,
              expand: false,
              builder: (_, scrollController) => SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                      child: Row(
                        children: [
                          const Text(
                            'Friend Requests',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          if (pending.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.deepOrange,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${pending.length}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: pending.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.fromLTRB(24, 8, 24, 24),
                              child: Text(
                                'No pending friend requests.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              padding: const EdgeInsets.fromLTRB(
                                  24, 0, 24, 24),
                              itemCount: pending.length,
                              itemBuilder: (_, i) {
                                final req = pending[i];
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: _buildAvatarCircle(
                                    _profileCache[req.otherUid(_myUid)]),
                                  title: Text(req.otherUsername(_myUid) ??
                                      'Shelfd User'),
                                  subtitle:
                                      const Text('Wants to be your friend'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ElevatedButton(
                                        onPressed: () async {
                                          await _acceptRequest(req);
                                          if (mounted &&
                                              _pendingReceived.isEmpty) {
                                            Navigator.of(context).pop();
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 8),
                                          visualDensity: VisualDensity.compact,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                        ),
                                        child: const Text('Accept'),
                                      ),
                                      const SizedBox(width: 8),
                                      OutlinedButton(
                                        onPressed: () async {
                                          await _confirmDelete(
                                              req, 'Decline Request');
                                          if (mounted &&
                                              _pendingReceived.isEmpty) {
                                            Navigator.of(context).pop();
                                          }
                                        },
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red,
                                          side: const BorderSide(
                                              color: Colors.red),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 8),
                                          visualDensity: VisualDensity.compact,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                        ),
                                        child: const Text('Decline'),
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    _viewProfile(req.otherUid(_myUid));
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  CircleAvatar _buildAvatarCircle(UserProfile? profile) {
    final ImageProvider? img = profile?.avatarAsset != null
        ? AssetImage(profile!.avatarAsset!) as ImageProvider
        : profile?.photoUrl != null
            ? NetworkImage(profile!.photoUrl!)
            : null;
    return CircleAvatar(
      backgroundColor: const Color(0xff5C3A1E),
      backgroundImage: img,
      child: img == null
          ? const Icon(Icons.person, color: Colors.white)
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F2ED),
      appBar: AppBar(
        backgroundColor: const Color(0xffF5F2ED),
        elevation: 0,
        title: const Text('Friends',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.person_add_outlined),
                tooltip: 'Friend Requests',
                onPressed: _showPendingRequestsSheet,
              ),
              if (_pendingReceived.isNotEmpty)
                Positioned(
                  top: 6,
                  right: 6,
                  child: IgnorePointer(
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        color: Colors.deepOrange,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${_pendingReceived.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Search card ──────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Find a Friend',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Enter exact username…',
                            isDense: true,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                          onSubmitted: (_) => _search(),
                          textInputAction: TextInputAction.search,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _searching
                          ? const SizedBox(
                              width: 36,
                              height: 36,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2))
                          : IconButton(
                              icon: const Icon(Icons.search),
                              onPressed: _search,
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.deepOrange,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(10)),
                              ),
                            ),
                    ],
                  ),
                  if (_searchError != null) ...[
                    const SizedBox(height: 8),
                    Text(_searchError!,
                        style: const TextStyle(
                            color: Colors.red, fontSize: 13)),
                  ],
                  if (_searchResult != null) ...[
                    const SizedBox(height: 12),
                    _SearchResultTile(
                      profile: _searchResult!,
                      existingStatus: _statusForUid(_searchResult!.uid),
                      onView: () => _viewProfile(_searchResult!.uid),
                      onAdd: () => _sendRequest(_searchResult!),
                      onAccept: () {
                        final req = _requestForUid(_searchResult!.uid);
                        if (req != null) _acceptRequest(req);
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Friends ───────────────────────────────────────────
          Row(
            children: [
              const Text('My Friends',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Text(
                '${_friends.length}',
                style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_friends.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'No friends yet — search for someone above!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.grey.shade500, fontSize: 14),
                ),
              ),
            )
          else
            ..._friends.map((req) => Card(
                  child: ListTile(
                    leading: _buildAvatarCircle(
                        _profileCache[req.otherUid(_myUid)]),
                    title: Text(
                        req.otherUsername(_myUid) ?? 'Shelfd User'),
                    trailing: IconButton(
                      icon: const Icon(Icons.person_remove_outlined,
                          color: Colors.red),
                      tooltip: 'Remove Friend',
                      onPressed: () =>
                          _confirmDelete(req, 'Remove Friend'),
                    ),
                    onTap: () => _viewProfile(req.otherUid(_myUid)),
                  ),
                )),

          // ── Sent pending ───────────────────────────────────────
          if (_pendingSent.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('Sent Requests',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._pendingSent.map((req) => Card(
                  child: ListTile(
                    leading: _buildAvatarCircle(
                        _profileCache[req.otherUid(_myUid)]),
                    title: Text(
                        req.otherUsername(_myUid) ?? 'Shelfd User'),
                    subtitle: const Text('Request pending…'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () =>
                              _viewProfile(req.otherUid(_myUid)),
                          child: const Text('View'),
                        ),
                        TextButton(
                          onPressed: () =>
                              _confirmDelete(req, 'Cancel Request'),
                          style: TextButton.styleFrom(
                              foregroundColor: Colors.red),
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  ),
                )),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─── Search Result Tile ──────────────────────────────────────────────────────

class _SearchResultTile extends StatelessWidget {
  final UserProfile profile;
  final FriendshipStatus? existingStatus;
  final VoidCallback onView;
  final VoidCallback onAdd;
  final VoidCallback onAccept;

  const _SearchResultTile({
    required this.profile,
    required this.existingStatus,
    required this.onView,
    required this.onAdd,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    Widget action;
    switch (existingStatus) {
      case FriendshipStatus.accepted:
        action = const Chip(
            label: Text('Friends',
                style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.green);
      case FriendshipStatus.pendingSent:
        action = Chip(
            label: const Text('Pending',
                style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.grey.shade500);
      case FriendshipStatus.pendingReceived:
        action = GestureDetector(
          onTap: onAccept,
          child: const Chip(
              label: Text('Accept?',
                  style: TextStyle(color: Colors.white)),
              backgroundColor: Colors.green),
        );
      default:
        action = ElevatedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.person_add_outlined, size: 16),
          label: const Text('Add'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepOrange,
            foregroundColor: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            visualDensity: VisualDensity.compact,
          ),
        );
    }

    final privacyIcon = switch (profile.privacyLevel) {
      PrivacyLevel.private => '🔒 Private profile',
      PrivacyLevel.friendsOnly => '👥 Friends only',
      _ => '🌐 Public profile',
    };

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xff5C3A1E),
            backgroundImage: profile.avatarAsset != null
                ? AssetImage(profile.avatarAsset!) as ImageProvider
                : profile.photoUrl != null
                    ? NetworkImage(profile.photoUrl!)
                    : null,
            child: profile.avatarAsset == null && profile.photoUrl == null
                ? const Icon(Icons.person, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profile.displayName,
                    style:
                        const TextStyle(fontWeight: FontWeight.bold)),
                Text(privacyIcon,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          TextButton(
              onPressed: onView, child: const Text('View')),
          const SizedBox(width: 4),
          action,
        ],
      ),
    );
  }
}
