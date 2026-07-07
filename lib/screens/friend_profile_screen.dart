import 'package:flutter/material.dart';

import '../accessibility/accessibility_labels.dart';
import '../models/book_review.dart';
import '../models/user_profile.dart';
import '../models/achievement.dart';
import '../models/book.dart';
import '../services/friend_service.dart';
import '../services/reaction_service.dart';
import '../services/activity_stream_service.dart';
import '../services/wishlist_service.dart';
import '../theme/app_theme.dart';

const _kReactionEmojis = ['❤️', '🔥', '😂', '🥹', '🤙', '🫶'];

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

    final result = await FriendService.getFriendshipStatus(widget.friend.uid);
    if (!mounted) return;

    if (privacy == PrivacyLevel.private &&
        result.status != FriendshipStatus.accepted) {
      setState(() {
        _accessDenied = true;
        _reviews = [];
        _friendshipStatus = result.status;
        _requestId = result.requestId;
      });
      return;
    }

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

  Future<void> _acceptRequest() async {
    if (_requestId == null) return;
    await FriendService.acceptRequest(_requestId!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Friend added!'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
    setState(() {
      _accessDenied = false;
      _reviews = null;
      _friendshipStatus = FriendshipStatus.accepted;
    });
    await _loadData();
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
    final c = ShelfdThemeScope.colorsOf(context);
    final friend = widget.friend;
    final reviews = _reviews;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: c.scaffoldBg,
        appBar: AppBar(
          backgroundColor: c.scaffoldBg,
          elevation: 0,
          title: Text(
            friend.displayName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          bottom: _accessDenied
              ? null
              : TabBar(
                  tabs: [
                    Tab(
                      icon: Semantics(
                        label: 'Overview tab for ${friend.displayName}',
                        child: const ExcludeSemantics(
                          child: Icon(Icons.person_outline),
                        ),
                      ),
                    ),
                    Tab(
                      icon: Semantics(
                        label: 'Reading log tab for ${friend.displayName}',
                        child: const ExcludeSemantics(
                          child: Icon(Icons.menu_book_outlined),
                        ),
                      ),
                    ),
                    Tab(
                      icon: Semantics(
                        label: 'Stats tab for ${friend.displayName}',
                        child: const ExcludeSemantics(
                          child: Icon(Icons.bar_chart),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
        body: _accessDenied
            ? _PrivateProfileView(
                friend: friend,
                isFriendsOnly: friend.privacyLevel == PrivacyLevel.friendsOnly,
                friendshipStatus: _friendshipStatus,
                onAdd: _sendRequest,
                onAccept: _acceptRequest,
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
                        onAccept: _acceptRequest,
                        onCancel: _cancelRequest,
                      ),
                      _ReadingLogTab(
                          reviews: reviews, ownerUid: friend.uid),
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
  final VoidCallback onAccept;
  final VoidCallback onCancel;

  const _PrivateProfileView({
    required this.friend,
    required this.isFriendsOnly,
    required this.friendshipStatus,
    required this.onAdd,
    required this.onAccept,
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
                onAccept: onAccept,
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
  final VoidCallback onAccept;
  final VoidCallback onCancel;

  const _OverviewTab({
    required this.friend,
    required this.reviews,
    required this.friendshipStatus,
    required this.onAdd,
    required this.onAccept,
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
    final c = ShelfdThemeScope.colorsOf(context);
    final isHighContrast =
        ShelfdThemeScope.of(context).theme == ShelfdTheme.highContrast;
    final hcShape = isHighContrast
        ? RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: c.brandColor, width: 2.0),
          )
        : null;
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
          Semantics(
            button: avatarImage != null,
            label: avatarSemanticLabel(name: friend.displayName),
            hint: avatarImage != null ? 'Opens profile picture preview' : null,
            child: GestureDetector(
              onTap: avatarImage == null
                  ? null
                  : () => showDialog(
                        context: context,
                        barrierColor: Colors.black87,
                        barrierDismissible: true,
                        builder: (_) => Semantics(
                          container: true,
                          label: '${friend.displayName} profile picture preview',
                          hint: 'Double tap outside the picture to close',
                          child: GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            behavior: HitTestBehavior.opaque,
                            child: Center(
                              child: Semantics(
                                button: true,
                                image: true,
                                label:
                                    'Enlarged profile picture for ${friend.displayName}',
                                hint: 'Double tap to interact with the picture',
                                child: GestureDetector(
                                  onTap: () {},
                                  child: ExcludeSemantics(
                                    child: CircleAvatar(
                                      radius: 140,
                                      backgroundImage: avatarImage,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
              child: ExcludeSemantics(
                child: CircleAvatar(
                  radius: 52,
                  backgroundColor:
                      c.avatarBg,
                  backgroundImage: avatarImage,
                  child: avatarImage == null
                      ? Icon(Icons.person,
                          size: 52, color: c.brandColor)
                      : null,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Friend action button (hidden when already friends)
          if (friendshipStatus != FriendshipStatus.accepted)
            _FriendActionButton(
              status: friendshipStatus,
              onAdd: onAdd,
              onAccept: onAccept,
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
              shape: hcShape,
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
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Achievements',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: c.brandColor),
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

class _ReadingLogTab extends StatefulWidget {
  final List<BookReview> reviews;
  final String ownerUid;

  const _ReadingLogTab({required this.reviews, required this.ownerUid});

  @override
  State<_ReadingLogTab> createState() => _ReadingLogTabState();
}

class _ReadingLogTabState extends State<_ReadingLogTab> {
  // reviewId → { counts, mine }
  final Map<String, ({Map<String, int> counts, List<String> mine})>
      _reactions = {};
  String _searchQuery = '';
  bool _searchVisible = false;
  final TextEditingController _searchController = TextEditingController();

  Widget _buildMonthBanner(String label, AppColors c) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: c.brandColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.brandColor.withValues(alpha: 0.7)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadAllReactions();
  }

  Future<void> _loadAllReactions() async {
    final reviewsWithComments = widget.reviews
        .where((r) => r.comment.isNotEmpty && r.id != null)
        .toList();
    if (reviewsWithComments.isEmpty) return;

    try {
      final results = await Future.wait(reviewsWithComments
          .map((r) => ReactionService.getReactions(widget.ownerUid, r.id!)));

      if (!mounted) return;
      setState(() {
        for (var i = 0; i < reviewsWithComments.length; i++) {
          _reactions[reviewsWithComments[i].id!] = results[i];
        }
      });
    } catch (_) {
      // Reactions unavailable (e.g. Firestore rules not yet updated) — fail silently
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _toggleReaction(String reviewId, String emoji) async {
    final current = _reactions[reviewId]?.mine ?? [];
    try {
      final result = await ReactionService.toggleReaction(
          widget.ownerUid, reviewId, emoji, current);
      if (mounted) setState(() => _reactions[reviewId] = result);
    } catch (_) {}
  }

  Future<void> _saveReactionActivity(String reviewId) async {
    try {
      final finalEmojis = _reactions[reviewId]?.mine ?? [];
      final bookTitle = widget.reviews
          .firstWhere((r) => r.id == reviewId,
              orElse: () => widget.reviews.first)
          .title;
      await ActivityStreamService.upsertReactionActivity(
        ownerUid: widget.ownerUid,
        reviewId: reviewId,
        bookTitle: bookTitle,
        emojis: finalEmojis,
        isFriend: true,
      );
    } catch (_) {}
  }

  Future<void> _showEmojiPicker(BuildContext context, String reviewId) async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final c = ShelfdThemeScope.colorsOf(ctx);
          final mine = _reactions[reviewId]?.mine ?? [];
          final atMax = mine.length >= 3;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Add a reaction',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    atMax
                        ? 'You\'ve used 3/3 reactions — tap one to remove it'
                        : 'Tap an emoji to react (up to 3)',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: _kReactionEmojis.map((emoji) {
                      final selected = mine.contains(emoji);
                      final disabled = atMax && !selected;
                      final isLast = emoji == _kReactionEmojis.last;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: isLast ? 0 : 6),
                          child: Semantics(
                            button: !disabled,
                            enabled: !disabled,
                            label: '${selected ? 'Selected' : 'Add'} ${emojiSemanticLabel(emoji)} reaction',
                            child: GestureDetector(
                              onTap: disabled
                                  ? null
                                  : () async {
                                      await _toggleReaction(reviewId, emoji);
                                      if (ctx.mounted) setSheet(() {});
                                    },
                              child: ExcludeSemantics(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? c.primaryAccent.withValues(alpha: 0.12)
                                        : c.subtleBg,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: selected
                                          ? c.primaryAccent
                                          : Colors.grey.shade300,
                                      width: selected ? 2 : 1,
                                    ),
                                  ),
                                  child: Center(
                                    child: Opacity(
                                      opacity: disabled ? 0.35 : 1.0,
                                      child: Text(emoji,
                                          style: const TextStyle(fontSize: 26)),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    // Panel closed — write the final reaction state to the activity stream once.
    await _saveReactionActivity(reviewId);
  }

  String _twoDigitWords(int n) {
    const underTwenty = [
      'zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight',
      'nine', 'ten', 'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen',
      'sixteen', 'seventeen', 'eighteen', 'nineteen'
    ];
    const tens = [
      '', '', 'twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy',
      'eighty', 'ninety'
    ];
    if (n < 20) return underTwenty[n];
    final t = n ~/ 10;
    final u = n % 10;
    return u == 0 ? tens[t] : '${tens[t]} ${underTwenty[u]}';
  }

  String _spokenYear(int year) {
    if (year >= 1900 && year <= 1999) {
      final yy = year % 100;
      return yy == 0 ? 'nineteen hundred' : 'nineteen ${_twoDigitWords(yy)}';
    }
    if (year >= 2000 && year <= 2099) {
      final yy = year % 100;
      if (yy == 0) return 'two thousand';
      if (yy < 10) return 'two thousand ${_twoDigitWords(yy)}';
      return 'twenty ${_twoDigitWords(yy)}';
    }
    return year.toString();
  }

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
              leading: Builder(builder: (bCtx) {
                final bc = ShelfdThemeScope.colorsOf(bCtx);
                return Icon(
                  isAlready
                      ? Icons.bookmark_remove_outlined
                      : Icons.bookmark_add_outlined,
                  color: isAlready ? Colors.red : bc.primaryAccent,
                );
              }),
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
                            Flexible(child: Text('Removed from Future Reads')),
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
                            Flexible(child: Text('Added to your Future Reads')),
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
    final c = ShelfdThemeScope.colorsOf(context);
    final isHighContrast =
        ShelfdThemeScope.of(context).theme == ShelfdTheme.highContrast;
    final hcShape = isHighContrast
        ? RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: c.brandColor, width: 2.0),
          )
        : null;
    if (widget.reviews.isEmpty) {
      return const Center(
        child: Text(
          'No books logged yet.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    // Group by month/year (newest first)
    final sorted = List<BookReview>.from(widget.reviews)
      ..sort((a, b) => b.dateAdded.compareTo(a.dateAdded));

    // Filter by search query
    final displayed = _searchQuery.isEmpty
        ? sorted
        : () {
            final q = _searchQuery.toLowerCase().trim();
            return sorted
                .where((r) =>
                    r.title.toLowerCase().contains(q) ||
                    r.author.toLowerCase().contains(q))
                .toList();
          }();

    final grouped = <String, List<BookReview>>{};
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    for (final r in displayed) {
      final key = '${months[r.dateAdded.month - 1]} ${r.dateAdded.year}';
      grouped.putIfAbsent(key, () => []).add(r);
    }

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      behavior: HitTestBehavior.translucent,
      child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Total books: ${widget.reviews.length}',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Semantics(
              button: true,
              label: _searchVisible ? 'Close search' : 'Search books',
              child: IconButton(
                icon: Icon(
                  _searchVisible ? Icons.search_off : Icons.search,
                  color: _searchVisible ? c.primaryAccent : null,
                ),
                tooltip: _searchVisible ? 'Close search' : 'Search books',
                onPressed: () {
                  setState(() {
                    _searchVisible = !_searchVisible;
                    if (!_searchVisible) {
                      _searchQuery = '';
                      _searchController.clear();
                    }
                  });
                },
              ),
            ),
          ],
        ),
        if (_searchVisible)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search by title or author…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'Clear search',
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _searchController.clear();
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                isDense: true,
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
          ),
        const SizedBox(height: 4),
        if (_searchQuery.isNotEmpty && displayed.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Center(
              child: Text(
                'No results for "$_searchQuery"',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ),
          )
        else for (final entry in grouped.entries) ...[
          _buildMonthBanner(entry.key, c),
          for (final review in entry.value)
            GestureDetector(
              onLongPress: () => _addToWishlist(context, review),
              child: Card(
                shape: hcShape,
                color: review.isFavourite
                    ? Colors.amber.withOpacity(0.15)
                    : null,
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: Semantics(
                  container: true,
                  label:
                      '${review.title} by ${review.author}. Published in ${_spokenYear(review.year)}. Rated ${review.rating % 1 == 0 ? review.rating.toInt() : review.rating.toStringAsFixed(1)} out of 10.${review.isFavourite ? ' Marked as favourite.' : ''}',
                  hint: 'Long press for wishlist options',
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
                                  excludeFromSemantics: true,
                                  errorBuilder: (_, __, ___) => const SizedBox(
                                    width: 50,
                                    height: 70,
                                    child: Icon(Icons.book, size: 40),
                                  ),
                                )
                              : const SizedBox(
                                  width: 50,
                                  height: 70,
                                  child: Icon(Icons.book, size: 40)),
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: ExcludeSemantics(
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
                          ),
                        ],
                      ),
                    ),
                    title: Semantics(
                      label:
                          '${review.title}. Published in ${_spokenYear(review.year)}',
                      child: ExcludeSemantics(
                        child: Text('${review.title} (${review.year})',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(review.author),
                        Semantics(
                          label:
                              'Rated ${review.rating % 1 == 0 ? review.rating.toInt() : review.rating.toStringAsFixed(1)} out of 10',
                          child: ExcludeSemantics(
                            child: Text(
                                '${review.rating % 1 == 0 ? review.rating.toInt() : review.rating.toStringAsFixed(1)}/10 ⭐'),
                          ),
                        ),
                      ],
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                        child: review.comment.isNotEmpty
                            ? _ExpandableReviewText(
                                text: review.comment,
                                bookTitle: '${review.title} (${review.year})',
                              )
                            : const Text('No review written.',
                                style: TextStyle(
                                    fontStyle: FontStyle.italic)),
                      ),
                      // Reaction row — only shown when a comment exists
                      if (review.comment.isNotEmpty && review.id != null)
                        _ReactionRow(
                          counts: _reactions[review.id]?.counts ?? {},
                          mine: _reactions[review.id]?.mine ?? [],
                          onToggle: (emoji) =>
                              _toggleReaction(review.id!, emoji),
                          onPickerOpen: () =>
                              _showEmojiPicker(context, review.id!),
                        ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ],
      ),
    );
  }
}

// ─── Expandable review text ───────────────────────────────────────────────────

class _ExpandableReviewText extends StatefulWidget {
  final String text;
  final String bookTitle;
  const _ExpandableReviewText({required this.text, required this.bookTitle});

  @override
  State<_ExpandableReviewText> createState() => _ExpandableReviewTextState();
}

class _ExpandableReviewTextState extends State<_ExpandableReviewText> {
  static const int _maxLines = 32;
  // Fade begins at the start of the last 2 lines.
  static const double _fadeStart = 1.0 - 2.0 / _maxLines;

  void _showFullReview() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                widget.bookTitle,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: Text(widget.text,
                    style: const TextStyle(fontSize: 14, height: 1.55)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final c = ShelfdThemeScope.colorsOf(context);
      final span = TextSpan(
          text: widget.text, style: const TextStyle(fontSize: 14));
      final tp = TextPainter(
          text: span,
          maxLines: _maxLines,
          textDirection: TextDirection.ltr)
        ..layout(maxWidth: constraints.maxWidth);
      final overflows = tp.didExceedMaxLines;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (overflows)
            Semantics(
              container: true,
              label: 'Review for ${widget.bookTitle}. ${widget.text}',
              child: ExcludeSemantics(
                child: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black, Colors.black, Colors.transparent],
                    stops: [0.0, _fadeStart, 1.0],
                  ).createShader(bounds),
                  blendMode: BlendMode.dstIn,
                  child: Text(
                    widget.text,
                    maxLines: _maxLines,
                    overflow: TextOverflow.clip,
                    style: const TextStyle(fontSize: 14, height: 1.55),
                  ),
                ),
              ),
            )
          else
            Semantics(
              container: true,
              label: 'Review for ${widget.bookTitle}. ${widget.text}',
              child: ExcludeSemantics(
                child: Text(
                  widget.text,
                  style: const TextStyle(fontSize: 14, height: 1.55),
                ),
              ),
            ),
          if (overflows) ...[
            const SizedBox(height: 6),
            Semantics(
              button: true,
              label: 'Read full review for ${widget.bookTitle}',
              child: GestureDetector(
                onTap: _showFullReview,
                child: ExcludeSemantics(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: c.primaryAccent, width: 1.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Read all',
                      style: TextStyle(
                        color: c.primaryAccent,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      );
    });
  }
}

// ─── Reaction Row ─────────────────────────────────────────────────────────────

class _ReactionRow extends StatelessWidget {
  final Map<String, int> counts;
  final List<String> mine;
  final void Function(String emoji) onToggle;
  final VoidCallback onPickerOpen;

  const _ReactionRow({
    required this.counts,
    required this.mine,
    required this.onToggle,
    required this.onPickerOpen,
  });

  @override
  Widget build(BuildContext context) {
    final c = ShelfdThemeScope.colorsOf(context);
    final activeEmojis =
        _kReactionEmojis.where((e) => (counts[e] ?? 0) > 0).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ...activeEmojis.map((emoji) {
            final isMine = mine.contains(emoji);
            return Semantics(
              button: true,
              label: '${isMine ? 'Selected' : ''} ${emojiSemanticLabel(emoji)} reaction, ${counts[emoji]}',
              child: GestureDetector(
                onTap: () => onToggle(emoji),
                child: ExcludeSemantics(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isMine
                          ? c.primaryAccent.withValues(alpha: 0.07)
                          : c.subtleBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color:
                            isMine ? c.primaryAccent : Colors.grey.shade300,
                        width: isMine ? 2 : 1,
                      ),
                    ),
                    child: Text('$emoji ${counts[emoji]}',
                        style: const TextStyle(fontSize: 14)),
                  ),
                ),
              ),
            );
          }),
          // "Add reaction" button
          Semantics(
            button: true,
            label: 'Add reaction',
            child: GestureDetector(
              onTap: onPickerOpen,
              child: ExcludeSemantics(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade500),
                  ),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(Icons.sentiment_satisfied_outlined,
                            size: 18, color: Colors.grey.shade700),
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.add,
                                size: 11, color: Colors.grey.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stats Tab ────────────────────────────────────────────────────────────────

class _StatsTab extends StatefulWidget {
  final List<BookReview> reviews;

  const _StatsTab({required this.reviews});

  @override
  State<_StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<_StatsTab> {
  bool _booksExpanded = false;

  int get _totalPhysical =>
      widget.reviews.where((r) => r.format == BookFormat.physical).length;
  int get _totalAudio =>
      widget.reviews.where((r) => r.format == BookFormat.audiobook).length;
  int get _totalBraille =>
      widget.reviews.where((r) => r.format == BookFormat.braille).length;

  List<MapEntry<String, int>> get _topAuthors {
    final counts = <String, int>{};
    for (final r in widget.reviews) {
      counts[r.author] = (counts[r.author] ?? 0) + 1;
    }
    return (counts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(3)
        .toList();
  }

  List<BookReview> get _topRated {
    return (List<BookReview>.from(widget.reviews)
          ..sort((a, b) => b.rating.compareTo(a.rating)))
        .take(3)
        .toList();
  }

  List<MapEntry<int, int>> get _byYear {
    final counts = <int, int>{};
    for (final r in widget.reviews) {
      counts[r.dateAdded.year] = (counts[r.dateAdded.year] ?? 0) + 1;
    }
    return (counts.entries.toList()
          ..sort((a, b) => b.key.compareTo(a.key)));
  }

  @override
  Widget build(BuildContext context) {
    final c = ShelfdThemeScope.colorsOf(context);
    final isHighContrast =
        ShelfdThemeScope.of(context).theme == ShelfdTheme.highContrast;
    final hcShape = isHighContrast
        ? RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: c.brandColor, width: 2.0),
          )
        : null;
    if (widget.reviews.isEmpty) {
      return const Center(
        child: Text('No stats yet.', style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          shape: hcShape,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _booksExpanded = !_booksExpanded),
            child: ListTile(
              leading: const Icon(Icons.library_books),
              title: const Text('Total Books Completed'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${widget.reviews.length}',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
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
                      shape: hcShape,
                      margin: const EdgeInsets.symmetric(vertical: 3),
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
                      shape: hcShape,
                      margin: const EdgeInsets.symmetric(vertical: 3),
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
                      shape: hcShape,
                      margin: const EdgeInsets.symmetric(vertical: 3),
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
                  ],
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 20),
        const Text('Top Authors',
            style:
                TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        ..._topAuthors.map((a) => Card(
              shape: hcShape,
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
              shape: hcShape,
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
              shape: hcShape,
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
    final c = ShelfdThemeScope.colorsOf(context);
    return Semantics(
      button: true,
      label:
          '${unlocked ? 'Unlocked' : 'Locked'} achievement. ${emojiSemanticLabel(emoji)}. $label',
      hint: 'Opens achievement details',
      child: GestureDetector(
        onTap: () => _showEnlarged(context),
        child: ExcludeSemantics(
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
                        ? c.brandColor
                        : Colors.grey,
                    fontWeight: unlocked
                        ? FontWeight.w600
                        : FontWeight.normal,
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

// ─── Friend Action Button ────────────────────────────────────────────────────

class _FriendActionButton extends StatelessWidget {
  final FriendshipStatus status;
  final VoidCallback onAdd;
  final VoidCallback onAccept;
  final VoidCallback onCancel;

  const _FriendActionButton({
    required this.status,
    required this.onAdd,
    required this.onAccept,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final c = ShelfdThemeScope.colorsOf(context);
    switch (status) {
      case FriendshipStatus.pendingSent:
        return OutlinedButton.icon(
          onPressed: null,
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
        return ElevatedButton(
          onPressed: onAccept,
          style: ElevatedButton.styleFrom(
            backgroundColor: c.primaryAccent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
          ),
          child: const Text('Accept Request ?'),
        );
      default: // none
        return ElevatedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.person_add_outlined, size: 16),
          label: const Text('Add Friend'),
          style: ElevatedButton.styleFrom(
            backgroundColor: c.primaryAccent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
          ),
        );
    }
  }
}
