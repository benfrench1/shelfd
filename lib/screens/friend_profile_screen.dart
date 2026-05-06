import 'package:flutter/material.dart';

import '../models/book_review.dart';
import '../models/user_profile.dart';
import '../models/achievement.dart';
import '../models/book.dart';
import '../services/friend_service.dart';
import '../services/wishlist_service.dart';

class FriendProfileScreen extends StatefulWidget {
  final UserProfile friend;

  const FriendProfileScreen({super.key, required this.friend});

  @override
  State<FriendProfileScreen> createState() => _FriendProfileScreenState();
}

class _FriendProfileScreenState extends State<FriendProfileScreen> {
  List<BookReview>? _reviews; // null = loading
  bool _accessDenied = false;
  FriendshipStatus _friendshipStatus = FriendshipStatus.none;
  String? _requestId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final privacy = widget.friend.privacyLevel;

    if (privacy == PrivacyLevel.private) {
      setState(() {
        _accessDenied = true;
        _reviews = [];
      });
      return;
    }

    final result = await FriendService.getFriendshipStatus(widget.friend.uid);
    if (!mounted) return;

    if (privacy == PrivacyLevel.friendsOnly &&
        result.status != FriendshipStatus.accepted) {
      setState(() {
        _accessDenied = true;
        _reviews = [];
        _friendshipStatus = result.status;
        _requestId = result.requestId;
      });
      return;
    }

    setState(() {
      _friendshipStatus = result.status;
      _requestId = result.requestId;
    });

    final reviews = await FriendService.getFriendReviews(widget.friend.uid);
    if (!mounted) return;
    setState(() => _reviews = reviews);
  }

  Future<void> _sendRequest() async {
    await FriendService.sendRequest(widget.friend);
    if (!mounted) return;
    final result = await FriendService.getFriendshipStatus(widget.friend.uid);
    if (!mounted) return;
    setState(() {
      _friendshipStatus = result.status;
      _requestId = result.requestId;
    });
  }

  Future<void> _cancelRequest() async {
    if (_requestId == null) return;
    await FriendService.deleteRequest(_requestId!);
    if (!mounted) return;
    setState(() {
      _friendshipStatus = FriendshipStatus.none;
      _requestId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final friend = widget.friend;
    final reviews = _reviews;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xffF5F2ED),
        appBar: AppBar(
          backgroundColor: const Color(0xffF5F2ED),
          elevation: 0,
          title: Text(
            friend.displayName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          bottom: _accessDenied
              ? null
              : const TabBar(
                  tabs: [
                    Tab(icon: Icon(Icons.person_outline)),
                    Tab(icon: Icon(Icons.menu_book_outlined)),
                    Tab(icon: Icon(Icons.bar_chart)),
                  ],
                ),
        ),
        body: _accessDenied
            ? _PrivateProfileView(
                friend: friend,
                isFriendsOnly: friend.privacyLevel == PrivacyLevel.friendsOnly,
                friendshipStatus: _friendshipStatus,
                onAdd: _sendRequest,
                onCancel: _cancelRequest,
              )
            : reviews == null
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    children: [
                      _OverviewTab(
                        friend: friend,
                        reviews: reviews,
                        friendshipStatus: _friendshipStatus,
                        onAdd: _sendRequest,
                        onCancel: _cancelRequest,
                      ),
                      _ReadingLogTab(reviews: reviews),
                      _StatsTab(reviews: reviews),
                    ],
                  ),
      ),
    );
  }
}

// ─── Private Profile View ────────────────────────────────────────────────────

class _PrivateProfileView extends StatelessWidget {
  final UserProfile friend;
  final bool isFriendsOnly;
  final FriendshipStatus friendshipStatus;
  final VoidCallback onAdd;
  final VoidCallback onCancel;

  const _PrivateProfileView({
    required this.friend,
    required this.isFriendsOnly,
    required this.friendshipStatus,
    required this.onAdd,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isFriendsOnly ? Icons.group_outlined : Icons.lock_outline,
              size: 72,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              isFriendsOnly
                  ? 'This profile is friends only'
                  : 'This profile is private',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isFriendsOnly
                  ? 'Send a friend request to view ${friend.displayName}\'s profile.'
                  : '${friend.displayName} has chosen not to share their profile.',
              style:
                  TextStyle(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            if (isFriendsOnly) ...[  
              const SizedBox(height: 24),
              _FriendActionButton(
                status: friendshipStatus,
                onAdd: onAdd,
                onCancel: onCancel,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Overview Tab ────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  final UserProfile friend;
  final List<BookReview> reviews;
  final FriendshipStatus friendshipStatus;
  final VoidCallback onAdd;
  final VoidCallback onCancel;

  const _OverviewTab({
    required this.friend,
    required this.reviews,
    required this.friendshipStatus,
    required this.onAdd,
    required this.onCancel,
  });

  String _ordinal(int day) {
    if (day >= 11 && day <= 13) return '${day}th';
    switch (day % 10) {
      case 1:
        return '${day}st';
      case 2:
        return '${day}nd';
      case 3:
        return '${day}rd';
      default:
        return '${day}th';
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
    final bookCount = reviews.length;

    // Avatar — asset or network photo
    final ImageProvider? avatarImage = friend.avatarAsset != null
        ? AssetImage(friend.avatarAsset!) as ImageProvider
        : (friend.photoUrl != null ? NetworkImage(friend.photoUrl!) : null);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),

          // Avatar (read-only, tap to enlarge)
          GestureDetector(
            onTap: avatarImage == null
                ? null
                : () => showDialog(
                      context: context,
                      barrierColor: Colors.black87,
                      barrierDismissible: true,
                      builder: (_) => GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        behavior: HitTestBehavior.opaque,
                        child: Center(
                          child: GestureDetector(
                            onTap: () {},
                            child: CircleAvatar(
                              radius: 140,
                              backgroundImage: avatarImage,
                            ),
                          ),
                        ),
                      ),
                    ),
            child: CircleAvatar(
              radius: 52,
              backgroundColor:
                  const Color(0xff5C3A1E).withOpacity(0.15),
              backgroundImage: avatarImage,
              child: avatarImage == null
                  ? const Icon(Icons.person,
                      size: 52, color: Color(0xff5C3A1E))
                  : null,
            ),
          ),

          const SizedBox(height: 16),

          // Friend action button (hidden when already friends)
          if (friendshipStatus != FriendshipStatus.accepted)
            _FriendActionButton(
              status: friendshipStatus,
              onAdd: onAdd,
              onCancel: onCancel,
            ),

          const SizedBox(height: 16),
          if (friend.createdAt != null)
            Text(
              'Joined: ${_formatJoinDate(friend.createdAt!.toLocal())}',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),

          const SizedBox(height: 16),

          // Username card
          if (friend.username?.isNotEmpty == true) ...[
            Card(
              child: ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Username',
                    style:
                        TextStyle(fontSize: 13, color: Colors.grey)),
                subtitle: Text(
                  friend.username!,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Reading count chip
          Chip(
            avatar: const Icon(Icons.menu_book, size: 16),
            label: Text('$bookCount book${bookCount == 1 ? '' : 's'} read'),
          ),

          // ── Achievements ──────────────────────────────────────
          const SizedBox(height: 32),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Achievements',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff5C3A1E)),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 16,
            children: kAchievements
                .where((a) => !a.hidden || bookCount >= a.threshold)
                .map((a) {
              final unlocked = bookCount >= a.threshold;
              return _ReadOnlyMedal(
                  label: a.label,
                  emoji: a.emoji,
                  unlocked: unlocked);
            }).toList(),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─── Reading Log Tab ─────────────────────────────────────────────────────────

class _ReadingLogTab extends StatelessWidget {
  final List<BookReview> reviews;

  const _ReadingLogTab({required this.reviews});

  String? _coverUrl(int? id) {
    if (id == null) return null;
    return 'https://covers.openlibrary.org/b/id/$id-M.jpg';
  }

  IconData _formatIcon(BookFormat format) {
    switch (format) {
      case BookFormat.audiobook:
        return Icons.headphones;
      case BookFormat.braille:
        return Icons.grain;
      case BookFormat.physical:
      default:
        return Icons.menu_book;
    }
  }

  void _addToWishlist(BuildContext context, BookReview review) async {
    final book = Book(
      title: review.title,
      author: review.author,
      year: review.year,
      coverId: review.coverId,
    );
    final isAlready = await WishlistService.isWishlisted(book);

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                isAlready
                    ? Icons.bookmark_remove_outlined
                    : Icons.bookmark_add_outlined,
                color: isAlready ? Colors.red : Colors.deepOrange,
              ),
              title: Text(isAlready
                  ? 'Remove from Future Reads'
                  : 'Add to Future Reads'),
              subtitle: Text(
                book.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () async {
                Navigator.pop(ctx);
                if (isAlready) {
                  await WishlistService.removeBook(book);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(SnackBar(
                        content: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bookmark_remove,
                                color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text('Removed from Future Reads'),
                          ],
                        ),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        margin: const EdgeInsets.all(16),
                      ));
                  }
                } else {
                  await WishlistService.addBook(book);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(SnackBar(
                        content: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bookmark_added,
                                color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text('Added to your Future Reads'),
                          ],
                        ),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        margin: const EdgeInsets.all(16),
                      ));
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) {
      return const Center(
        child: Text(
          'No books logged yet.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    // Group by month/year (newest first)
    final sorted = List<BookReview>.from(reviews)
      ..sort((a, b) => b.dateAdded.compareTo(a.dateAdded));

    final grouped = <String, List<BookReview>>{};
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    for (final r in sorted) {
      final key = '${months[r.dateAdded.month - 1]} ${r.dateAdded.year}';
      grouped.putIfAbsent(key, () => []).add(r);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final entry in grouped.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(entry.key,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          for (final review in entry.value)
            GestureDetector(
              onLongPress: () => _addToWishlist(context, review),
              child: Card(
                color: review.isFavourite
                    ? Colors.amber.withOpacity(0.15)
                    : null,
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ExpansionTile(
                  leading: SizedBox(
                    width: 50,
                    height: 70,
                    child: Stack(
                      children: [
                        _coverUrl(review.coverId) != null
                            ? Image.network(
                                _coverUrl(review.coverId)!,
                                width: 50,
                                height: 70,
                                fit: BoxFit.cover,
                              )
                            : const SizedBox(
                                width: 50,
                                height: 70,
                                child: Icon(Icons.book, size: 40)),
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            padding: const EdgeInsets.all(2),
                            child: Icon(_formatIcon(review.format),
                                size: 14, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  title: Text('${review.title} (${review.year})',
                      style:
                          const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(review.author),
                      Text(
                          '${review.rating % 1 == 0 ? review.rating.toInt() : review.rating.toStringAsFixed(1)}/10 ⭐'),
                    ],
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: review.comment.isNotEmpty
                          ? Text(review.comment)
                          : const Text('No review written.',
                              style: TextStyle(
                                  fontStyle: FontStyle.italic)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

// ─── Stats Tab ────────────────────────────────────────────────────────────────

class _StatsTab extends StatelessWidget {
  final List<BookReview> reviews;

  const _StatsTab({required this.reviews});

  int get _totalPhysical =>
      reviews.where((r) => r.format == BookFormat.physical).length;
  int get _totalAudio =>
      reviews.where((r) => r.format == BookFormat.audiobook).length;
  int get _totalBraille =>
      reviews.where((r) => r.format == BookFormat.braille).length;

  List<MapEntry<String, int>> get _topAuthors {
    final counts = <String, int>{};
    for (final r in reviews) {
      counts[r.author] = (counts[r.author] ?? 0) + 1;
    }
    return (counts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(3)
        .toList();
  }

  List<BookReview> get _topRated {
    return (List<BookReview>.from(reviews)
          ..sort((a, b) => b.rating.compareTo(a.rating)))
        .take(3)
        .toList();
  }

  List<MapEntry<int, int>> get _byYear {
    final counts = <int, int>{};
    for (final r in reviews) {
      counts[r.dateAdded.year] = (counts[r.dateAdded.year] ?? 0) + 1;
    }
    return (counts.entries.toList()
          ..sort((a, b) => b.key.compareTo(a.key)));
  }

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) {
      return const Center(
        child: Text('No stats yet.', style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.library_books),
            title: const Text('Total Books Completed'),
            trailing: Text(
              '${reviews.length}',
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        Card(
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.menu_book, size: 20),
            title: const Text('Books Read',
                style: TextStyle(fontSize: 13)),
            trailing: Text('$_totalPhysical',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ),
        Card(
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.headphones, size: 20),
            title: const Text('Books Listened To',
                style: TextStyle(fontSize: 13)),
            trailing: Text('$_totalAudio',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ),
        Card(
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.grain, size: 20),
            title: const Text('Books Read Braille',
                style: TextStyle(fontSize: 13)),
            trailing: Text('$_totalBraille',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 20),
        const Text('Top Authors',
            style:
                TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        ..._topAuthors.map((a) => Card(
              child: ListTile(
                title: Text(a.key),
                trailing: Text('${a.value} books'),
              ),
            )),
        const SizedBox(height: 20),
        const Text('Top Rated Books',
            style:
                TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        ..._topRated.map((b) => Card(
              color: b.isFavourite
                  ? Colors.amber.withOpacity(0.15)
                  : null,
              child: ListTile(
                title: Text(b.title),
                subtitle: Text(b.author),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star,
                        color: Colors.amber, size: 18),
                    Text(
                        '${b.rating % 1 == 0 ? b.rating.toInt() : b.rating.toStringAsFixed(1)}/10'),
                  ],
                ),
              ),
            )),
        const SizedBox(height: 20),
        const Text('Books by Year',
            style:
                TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        ..._byYear.map((e) => Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_today),
                title: Text('${e.key}'),
                trailing: Text(
                  '${e.value}',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            )),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ─── Read-only Achievement Medal ─────────────────────────────────────────────

class _ReadOnlyMedal extends StatelessWidget {
  final String label;
  final String emoji;
  final bool unlocked;

  const _ReadOnlyMedal({
    required this.label,
    required this.emoji,
    required this.unlocked,
  });

  void _showEnlarged(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      barrierDismissible: true,
      builder: (_) => GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: GestureDetector(
            onTap: () {},
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
                      color: unlocked
                          ? Colors.white
                          : Colors.grey.shade400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showEnlarged(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: unlocked
                  ? const Color(0xffFFF3CD)
                  : Colors.grey.shade200,
              border: Border.all(
                color: unlocked
                    ? const Color(0xffD4A017)
                    : Colors.grey.shade400,
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
                  ? Text(emoji,
                      style: const TextStyle(fontSize: 28))
                  : Icon(Icons.lock_outline,
                      size: 28, color: Colors.grey),
            ),
          ),
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
                color: unlocked
                    ? const Color(0xff5C3A1E)
                    : Colors.grey,
                fontWeight: unlocked
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Friend Action Button ────────────────────────────────────────────────────

class _FriendActionButton extends StatelessWidget {
  final FriendshipStatus status;
  final VoidCallback onAdd;
  final VoidCallback onCancel;

  const _FriendActionButton({
    required this.status,
    required this.onAdd,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case FriendshipStatus.pendingSent:
        return OutlinedButton.icon(
          onPressed: onCancel,
          icon: const Icon(Icons.hourglass_top_outlined, size: 16),
          label: const Text('Request Sent'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.grey.shade600,
            side: BorderSide(color: Colors.grey.shade400),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
          ),
        );
      case FriendshipStatus.pendingReceived:
        return ElevatedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.check, size: 16),
          label: const Text('Accept Request'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
          ),
        );
      default: // none
        return ElevatedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.person_add_outlined, size: 16),
          label: const Text('Add Friend'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepOrange,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
          ),
        );
    }
  }
}
