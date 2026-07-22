import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../accessibility/accessibility_labels.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/book.dart';
import '../models/book_review.dart';
import '../models/user_profile.dart';
import '../services/activity_stream_service.dart';
import '../services/auth_service.dart';
import '../services/public_reviews_service.dart';
import '../services/reaction_service.dart';
import '../theme/app_theme.dart';
import 'profile_screen.dart';

const _kReactionEmojis = ['❤️', '🔥', '😂', '🥹', '🤙', '🫶'];

// ─── Screen ───────────────────────────────────────────────────────────────────

class PublicReviewsScreen extends StatefulWidget {
  final Book book;

  const PublicReviewsScreen({super.key, required this.book});

  @override
  State<PublicReviewsScreen> createState() => _PublicReviewsScreenState();
}

class _PublicReviewsScreenState extends State<PublicReviewsScreen> {
  List<PublicEntry>? _entries; // null = loading
  Set<String> _friendUids = {};
  bool _reactionsLoaded = false;
  String? _error;
  String? _avatarAsset;
  StreamSubscription<String?>? _avatarSub;
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _avatarSub = _authService.avatarAssetStream.listen((asset) {
      if (mounted) setState(() => _avatarAsset = asset);
    });
    _loadData();
  }

  @override
  void dispose() {
    _avatarSub?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _entries = null;
        _error = null;
        _reactionsLoaded = false;
      });
    }

    try {
      // Start both futures in parallel
      final entriesFuture = PublicReviewsService.fetchForBook(widget.book);
      final friendUidsFuture = PublicReviewsService.getFriendUids();

      final entries = await entriesFuture;
      final friendUids = await friendUidsFuture;

      if (!mounted) return;
      setState(() {
        _entries = entries;
        _friendUids = friendUids;
      });

      // Load reactions in background (needed for Tab 2 sort)
      await PublicReviewsService.loadReactions(entries);
      if (!mounted) return;
      setState(() => _reactionsLoaded = true);
    } catch (e, st) {
      // Log the real Firestore error — if it mentions "index", follow the URL
      // printed below to create the required collection-group index.
      debugPrint('[PublicReviews] load error: $e');
      debugPrint('[PublicReviews] stack: $st');
      if (!mounted) return;
      setState(() => _error = 'Could not load reviews. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = ShelfdThemeScope.colorsOf(context);
    final isBatman = ShelfdThemeScope.of(context).theme == ShelfdTheme.batman;
    final textScale = MediaQuery.of(context).textScaler.scale(1.0);
    final isLargeText = textScale > 1.3;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: c.scaffoldBg,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header (matches wishlist_screen pattern) ─────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: SizedBox(
                  height: isLargeText ? 52 : 40,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Left: explore icon + brand name
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Icon(Icons.rate_review_outlined, size: 28),
                          const SizedBox(width: 8),
                          Image.asset(
                            'assets/images/shelfd_brand_name.png',
                            height: 18,
                            fit: BoxFit.contain,
                            excludeFromSemantics: true,
                          ),
                          const Spacer(),
                        ],
                      ),
                      // Centre: screen title
                      Semantics(
                        header: true,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 110),
                          child: Text(
                            "Reviews",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: isBatman
                                ? GoogleFonts.orbitron(fontSize: 16)
                                : const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                          ),
                        ),
                      ),
                      // Right: current-user avatar → profile
                      Align(
                        alignment: Alignment.centerRight,
                        child: Semantics(
                          button: true,
                          label: avatarSemanticLabel(isCurrentUser: true),
                          hint: 'Opens your profile screen',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(22),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const ProfileScreen()),
                            ),
                            child: ExcludeSemantics(
                              child: themedAvatar(
                                colors: c,
                                child: CircleAvatar(
                                  radius: 20,
                                  backgroundColor: c.avatarBg,
                                  backgroundImage: _avatarAsset != null
                                      ? AssetImage(_avatarAsset!)
                                          as ImageProvider
                                      : (FirebaseAuth.instance.currentUser
                                                  ?.photoURL !=
                                              null
                                          ? NetworkImage(FirebaseAuth.instance
                                              .currentUser!.photoURL!)
                                          : null),
                                  child: _avatarAsset == null &&
                                          FirebaseAuth.instance.currentUser
                                                  ?.photoURL ==
                                              null
                                      ? Icon(Icons.person,
                                          size: 20, color: c.brandColor)
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Back arrow row ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Semantics(
                    button: true,
                    label: 'Go back',
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'Back',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
              ),

              // ── Book title sub-header ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Semantics(
                  header: true,
                  child: Text(
                    widget.book.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: c.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

              // ── Tab bar ───────────────────────────────────────────────────
              TabBar(
                labelColor: c.primaryAccent,
                unselectedLabelColor: c.textSecondary,
                indicatorColor: c.primaryAccent,
                tabs: const [
                  Tab(
                    icon: Icon(Icons.access_time_outlined, size: 18),
                    text: 'Latest',
                  ),
                  Tab(
                    icon: Icon(Icons.emoji_events_outlined, size: 18),
                    text: 'Top Reviews',
                  ),
                  Tab(
                    icon: Icon(Icons.group_outlined, size: 18),
                    text: 'Friends',
                  ),
                ],
              ),

              // ── Tab content ───────────────────────────────────────────────
              Expanded(
                child: _error != null
                    ? _ErrorView(error: _error!, onRetry: _loadData)
                    : _entries == null
                        ? const Center(child: CircularProgressIndicator())
                        : TabBarView(
                            children: [
                              // Tab 1 — Latest
                              _LatestTab(
                                book: widget.book,
                                entries: _entries!,
                                friendUids: _friendUids,
                                onReactionChanged: () =>
                                    setState(() {}),
                              ),
                              // Tab 2 — Top Reviews
                              _TopReviewsTab(
                                book: widget.book,
                                entries: _entries!,
                                friendUids: _friendUids,
                                reactionsLoaded: _reactionsLoaded,
                                onReactionChanged: () =>
                                    setState(() {}),
                              ),
                              // Tab 3 — Friends
                              _FriendsTab(
                                book: widget.book,
                                entries: _entries!,
                                friendUids: _friendUids,
                                onReactionChanged: () =>
                                    setState(() {}),
                              ),
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

// ─── Error view ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final c = ShelfdThemeScope.colorsOf(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textMuted),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Tab 1 — Latest ───────────────────────────────────────────────────────────

class _LatestTab extends StatefulWidget {
  final Book book;
  final List<PublicEntry> entries;
  final Set<String> friendUids;
  final VoidCallback onReactionChanged;

  const _LatestTab({
    required this.book,
    required this.entries,
    required this.friendUids,
    required this.onReactionChanged,
  });

  @override
  State<_LatestTab> createState() => _LatestTabState();
}

class _LatestTabState extends State<_LatestTab> {
  // Sorted by date desc (already sorted by service)
  List<PublicEntry> get _sorted => widget.entries;

  @override
  Widget build(BuildContext context) {
    if (_sorted.isEmpty) {
      return _EmptyState(book: widget.book);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      itemCount: _sorted.length + (widget.entries.length < 6 ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i < _sorted.length) {
          return _ReviewCard(
            entry: _sorted[i],
            isFriend: widget.friendUids.contains(_sorted[i].ownerUid),
            onReactionUpdated: () {
              if (mounted) setState(() {});
              widget.onReactionChanged();
            },
          );
        }
        return _OutsideReviewsSection(book: widget.book);
      },
    );
  }
}

// ─── Tab 2 — Top Reviews ──────────────────────────────────────────────────────

class _TopReviewsTab extends StatefulWidget {
  final Book book;
  final List<PublicEntry> entries;
  final Set<String> friendUids;
  final bool reactionsLoaded;
  final VoidCallback onReactionChanged;

  const _TopReviewsTab({
    required this.book,
    required this.entries,
    required this.friendUids,
    required this.reactionsLoaded,
    required this.onReactionChanged,
  });

  @override
  State<_TopReviewsTab> createState() => _TopReviewsTabState();
}

class _TopReviewsTabState extends State<_TopReviewsTab> {
  List<PublicEntry> get _sortedByReactions {
    final copy = List<PublicEntry>.from(widget.entries);
    copy.sort((a, b) => b.totalReactions.compareTo(a.totalReactions));
    return copy;
  }

  @override
  Widget build(BuildContext context) {
    final c = ShelfdThemeScope.colorsOf(context);

    if (widget.entries.isEmpty) {
      return _EmptyState(book: widget.book);
    }

    if (!widget.reactionsLoaded) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Loading reaction counts…',
              style: TextStyle(color: c.textMuted, fontSize: 13),
            ),
          ],
        ),
      );
    }

    final sorted = _sortedByReactions;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      itemCount: sorted.length + (widget.entries.length < 6 ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i < sorted.length) {
          return _ReviewCard(
            entry: sorted[i],
            showReactionTotal: true,
            isFriend: widget.friendUids.contains(sorted[i].ownerUid),
            onReactionUpdated: () {
              if (mounted) setState(() {});
              widget.onReactionChanged();
            },
          );
        }
        return _OutsideReviewsSection(book: widget.book);
      },
    );
  }
}

// ─── Tab 3 — Friends ─────────────────────────────────────────────────────────

class _FriendsTab extends StatefulWidget {
  final Book book;
  final List<PublicEntry> entries;
  final Set<String> friendUids;
  final VoidCallback onReactionChanged;

  const _FriendsTab({
    required this.book,
    required this.entries,
    required this.friendUids,
    required this.onReactionChanged,
  });

  @override
  State<_FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends State<_FriendsTab> {
  List<PublicEntry> get _friendEntries => widget.entries
      .where((e) => widget.friendUids.contains(e.ownerUid))
      .toList();

  @override
  Widget build(BuildContext context) {
    final friends = _friendEntries;

    if (friends.isEmpty) {
      return _EmptyState(
        book: widget.book,
        isFriendsTab: true,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      itemCount: friends.length,
      itemBuilder: (ctx, i) => _ReviewCard(
        entry: friends[i],
        isFriend: true,
        onReactionUpdated: () {
          if (mounted) setState(() {});
          widget.onReactionChanged();
        },
      ),
    );
  }
}

// ─── Outside reviews section (non-empty tabs) ─────────────────────────────────

class _OutsideReviewsSection extends StatefulWidget {
  final Book book;
  const _OutsideReviewsSection({required this.book});

  @override
  State<_OutsideReviewsSection> createState() =>
      _OutsideReviewsSectionState();
}

class _OutsideReviewsSectionState
    extends State<_OutsideReviewsSection> {
  bool _expanded = false;

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = ShelfdThemeScope.colorsOf(context);
    final searchQuery = Uri.encodeComponent(
        '${widget.book.title} ${widget.book.author}');
    final goodreadsSearchUrl =
        'https://www.goodreads.com/search?q=$searchQuery';

    if (!_expanded) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
        child: Column(
          children: [
            const Divider(),
            const SizedBox(height: 4),
            Semantics(
              button: true,
              label: 'View outside reviews',
              child: OutlinedButton.icon(
                icon: const Icon(Icons.public_outlined),
                label: const Text('Outside reviews'),
                onPressed: () => setState(() => _expanded = true),
                style: OutlinedButton.styleFrom(
                  foregroundColor: c.primaryAccent,
                  side: BorderSide(
                      color: c.primaryAccent.withValues(alpha: 0.6)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        const Divider(height: 24),
        Semantics(
          button: true,
          label: 'Read reviews on Goodreads for ${widget.book.title}',
          child: ListTile(
            leading: Icon(Icons.open_in_new, color: c.primaryAccent),
            title: Text(
              'Read reviews on Goodreads',
              style: TextStyle(
                  color: c.primaryAccent, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              widget.book.title,
              style: TextStyle(fontSize: 12, color: c.textSubtle),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => _launch(goodreadsSearchUrl),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatefulWidget {
  final Book book;
  final bool isFriendsTab;

  const _EmptyState({required this.book, this.isFriendsTab = false});

  @override
  State<_EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<_EmptyState> {
  bool _outsideExpanded = false;

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = ShelfdThemeScope.colorsOf(context);

    // Dynamic Goodreads search URL: title + author as query
    final searchQuery = Uri.encodeComponent(
        '${widget.book.title} ${widget.book.author}');
    final goodreadsSearchUrl =
        'https://www.goodreads.com/search?q=$searchQuery';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          ExcludeSemantics(
            child: Icon(
              widget.isFriendsTab
                  ? Icons.group_outlined
                  : Icons.rate_review_outlined,
              size: 56,
              color: Colors.grey.shade300,
            ),
          ),
          const SizedBox(height: 16),
          Semantics(
            label: widget.isFriendsTab
                ? 'None of your friends have reviewed this book on Shelfd yet.'
                : 'No ratings or reviews for this book on Shelfd yet. Be the first to do so.',
            child: ExcludeSemantics(
              child: Text(
                widget.isFriendsTab
                    ? 'None of your friends have reviewed this book on Shelfd yet.'
                    : 'No ratings or reviews for this book on Shelfd yet.\nBe the first to do so :)',
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: c.textMuted, fontSize: 14, height: 1.5),
              ),
            ),
          ),

          // ── Outside reviews ────────────────────────────────────────────────
          if (!widget.isFriendsTab) ...[
            const SizedBox(height: 32),
            if (!_outsideExpanded)
              Semantics(
                button: true,
                label: 'View outside reviews',
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.public_outlined),
                  label: const Text('Outside reviews'),
                  onPressed: () =>
                      setState(() => _outsideExpanded = true),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.primaryAccent,
                    side: BorderSide(
                        color: c.primaryAccent.withValues(alpha: 0.6)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                ),
              )
            else ...[
              const Divider(),
              const SizedBox(height: 8),
              // Dynamic link — takes the user directly to the book search
              Semantics(
                button: true,
                label:
                    'Read reviews on Goodreads for ${widget.book.title}',
                child: ListTile(
                  leading: Icon(Icons.open_in_new,
                      color: c.primaryAccent),
                  title: Text(
                    'Read reviews on Goodreads',
                    style: TextStyle(
                        color: c.primaryAccent,
                        fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    widget.book.title,
                    style: TextStyle(
                        fontSize: 12, color: c.textSubtle),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _launch(goodreadsSearchUrl),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// ─── Review Card (Shelfd) ─────────────────────────────────────────────────────

class _ReviewCard extends StatefulWidget {
  final PublicEntry entry;
  final bool showReactionTotal;
  final bool isFriend;
  final VoidCallback onReactionUpdated;

  const _ReviewCard({
    required this.entry,
    this.showReactionTotal = false,
    this.isFriend = false,
    required this.onReactionUpdated,
  });

  @override
  State<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<_ReviewCard> {
  bool get _hasComment => widget.entry.review.comment.trim().isNotEmpty;

  Future<void> _toggleReaction(String emoji) async {
    final entry = widget.entry;
    if (entry.review.id == null) return;
    try {
      final result = await ReactionService.toggleReaction(
        entry.ownerUid,
        entry.review.id!,
        emoji,
        entry.myReactions,
      );
      entry.reactionCounts = result.counts;
      entry.myReactions = result.mine;
      entry.totalReactions = result.counts.values.fold(0, (a, b) => a + b);
      if (mounted) setState(() {});
      widget.onReactionUpdated();
    } catch (_) {}
  }

  Future<void> _saveReactionActivity() async {
    final entry = widget.entry;
    if (entry.review.id == null) return;
    try {
      await ActivityStreamService.upsertReactionActivity(
        ownerUid: entry.ownerUid,
        reviewId: entry.review.id!,
        bookTitle: entry.review.title,
        emojis: entry.myReactions,
        isFriend: widget.isFriend,
      );
    } catch (_) {}
  }

  Future<void> _showEmojiPicker() async {
    final entry = widget.entry;
    if (entry.review.id == null) return;

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final c = ShelfdThemeScope.colorsOf(ctx);
          final mine = entry.myReactions;
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
                        ? "You've used 3/3 reactions — tap one to remove it"
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
                            label:
                                '${selected ? 'Selected' : 'Add'} ${emojiSemanticLabel(emoji)} reaction',
                            child: GestureDetector(
                              onTap: disabled
                                  ? null
                                  : () async {
                                      await _toggleReaction(emoji);
                                      if (ctx.mounted) setSheet(() {});
                                    },
                              child: ExcludeSemantics(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? c.primaryAccent
                                            .withValues(alpha: 0.12)
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
                                          style: const TextStyle(
                                              fontSize: 26)),
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

    // Sheet closed — persist activity
    await _saveReactionActivity();
  }

  @override
  Widget build(BuildContext context) {
    final c = ShelfdThemeScope.colorsOf(context);
    final isHighContrast =
        ShelfdThemeScope.of(context).theme == ShelfdTheme.highContrast;
    final entry = widget.entry;
    final review = entry.review;
    final profile = entry.profile;

    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final bool isOwnReview = entry.ownerUid == myUid;
    final bool showAsPrivate = entry.isPrivate && !widget.isFriend && !isOwnReview;

    final ImageProvider? avatarImage = showAsPrivate
        ? null
        : profile?.avatarAsset != null
            ? AssetImage(profile!.avatarAsset!) as ImageProvider
            : (profile?.photoUrl != null
                ? NetworkImage(profile!.photoUrl!)
                : null);

    final hcShape = isHighContrast
        ? RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: c.brandColor, width: 2.0),
          )
        : null;

    // Relative date string
    final now = DateTime.now();
    final diff = now.difference(review.dateAdded);
    final dateLabel = _relativeDate(diff, review.dateAdded);

    return Semantics(
      container: true,
      label: '${isOwnReview ? 'Your review' : showAsPrivate ? 'Private user' : entry.displayName}. '
          'Rated ${review.rating % 1 == 0 ? review.rating.toInt() : review.rating.toStringAsFixed(1)} out of 10. '
          '${_hasComment ? review.comment : ''}',
      child: Card(
        shape: hcShape,
        margin: const EdgeInsets.symmetric(vertical: 6),
        color: isOwnReview
            ? Colors.amber.withOpacity(0.15)
            : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Avatar + name + date row ────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Avatar / padlock
                  ExcludeSemantics(
                    child: showAsPrivate
                        ? Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: c.subtleBg,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.lock_outline,
                                size: 20, color: c.textSecondary),
                          )
                        : CircleAvatar(
                            radius: 20,
                            backgroundColor: c.avatarBg,
                            backgroundImage: avatarImage,
                            child: avatarImage == null
                                ? Icon(Icons.person,
                                    size: 20, color: c.brandColor)
                                : null,
                          ),
                  ),
                  const SizedBox(width: 10),
                  // Name
                  Expanded(
                    child: Text(
                      isOwnReview
                          ? 'You'
                          : showAsPrivate
                              ? 'Private User'
                              : entry.displayName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: c.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Date
                  Text(
                    dateLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: c.textSubtle,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // ── Rating ──────────────────────────────────────────────────
              Semantics(
                label:
                    'Rated ${review.rating % 1 == 0 ? review.rating.toInt() : review.rating.toStringAsFixed(1)} out of 10',
                child: ExcludeSemantics(
                  child: Text(
                    '${review.rating % 1 == 0 ? review.rating.toInt() : review.rating.toStringAsFixed(1)} / 10  ⭐',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                    ),
                  ),
                ),
              ),

              // ── Comment (truncated to 4 lines) ──────────────────────────
              if (_hasComment) ...[
                const SizedBox(height: 6),
                _TruncatedComment(
                  text: review.comment,
                  bookTitle: '${review.title} (${review.year})',
                ),
              ],

              // ── Top Reviews: total reaction badge ───────────────────────
              if (widget.showReactionTotal && entry.totalReactions > 0) ...[
                const SizedBox(height: 6),
                Semantics(
                  label:
                      '${entry.totalReactions} total emoji reaction${entry.totalReactions == 1 ? '' : 's'}',
                  child: ExcludeSemantics(
                    child: Row(
                      children: [
                        Icon(Icons.emoji_emotions_outlined,
                            size: 14, color: c.textSubtle),
                        const SizedBox(width: 4),
                        Text(
                          '${entry.totalReactions} reaction${entry.totalReactions == 1 ? '' : 's'}',
                          style: TextStyle(
                              fontSize: 12, color: c.textSubtle),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // ── Reaction row (only if comment exists) ───────────────────
              if (_hasComment && review.id != null) ...[
                const SizedBox(height: 4),
                _ReactionRow(
                  counts: entry.reactionCounts,
                  mine: entry.myReactions,
                  onToggle: _toggleReaction,
                  onPickerOpen: _showEmojiPicker,
                  canReact: !isOwnReview,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _relativeDate(Duration diff, DateTime date) {
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
    return '${(diff.inDays / 365).floor()}y ago';
  }
}

// ─── Truncated comment (4-line preview + "Read all") ─────────────────────────

class _TruncatedComment extends StatelessWidget {
  final String text;
  final String bookTitle;

  const _TruncatedComment({required this.text, required this.bookTitle});

  void _showFullReview(BuildContext context) {
    final c = ShelfdThemeScope.colorsOf(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
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
              child: Semantics(
                header: true,
                child: Text(
                  bookTitle,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Semantics(
                label: 'Full review for $bookTitle. $text',
                child: SingleChildScrollView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  child: ExcludeSemantics(
                    child: Text(text,
                        style:
                            const TextStyle(fontSize: 14, height: 1.55)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = ShelfdThemeScope.colorsOf(context);
    return LayoutBuilder(builder: (context, constraints) {
      const int maxLines = 4;
      final span = TextSpan(
          text: text, style: const TextStyle(fontSize: 13, height: 1.5));
      final tp = TextPainter(
        text: span,
        maxLines: maxLines,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: constraints.maxWidth);

      final overflows = tp.didExceedMaxLines;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            label: 'Review: $text',
            child: ExcludeSemantics(
              child: Text(
                text,
                maxLines: overflows ? maxLines : null,
                overflow:
                    overflows ? TextOverflow.ellipsis : TextOverflow.clip,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: c.textPrimary,
                ),
              ),
            ),
          ),
          if (overflows) ...[
            const SizedBox(height: 4),
            Semantics(
              button: true,
              label: 'Read full review for $bookTitle',
              child: GestureDetector(
                onTap: () => _showFullReview(context),
                child: ExcludeSemantics(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      border:
                          Border.all(color: c.primaryAccent, width: 1.2),
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

// ─── Reaction row ─────────────────────────────────────────────────────────────

class _ReactionRow extends StatelessWidget {
  final Map<String, int> counts;
  final List<String> mine;
  final void Function(String emoji) onToggle;
  final VoidCallback onPickerOpen;
  final bool canReact;

  const _ReactionRow({
    required this.counts,
    required this.mine,
    required this.onToggle,
    required this.onPickerOpen,
    this.canReact = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = ShelfdThemeScope.colorsOf(context);
    final activeEmojis =
        _kReactionEmojis.where((e) => (counts[e] ?? 0) > 0).toList();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ...activeEmojis.map((emoji) {
          final isMine = mine.contains(emoji);
          return Semantics(
            button: canReact,
            label:
                '${isMine ? 'Selected' : ''} ${emojiSemanticLabel(emoji)} reaction, ${counts[emoji]}',
            child: GestureDetector(
              onTap: canReact ? () => onToggle(emoji) : null,
              child: ExcludeSemantics(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
        // "Add reaction" button — hidden on own review
        if (canReact)
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
    );
  }
}

