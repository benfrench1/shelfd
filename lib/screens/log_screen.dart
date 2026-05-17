import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/book_review.dart';
import '../models/book.dart';
import '../models/user_profile.dart';
import '../services/friend_service.dart';
import '../services/reaction_service.dart';
import '../services/storage_service.dart';
import 'review_screen.dart';

const _kReactionEmojis = ['❤️', '🔥', '😂', '🥹', '🤙', '🫶'];

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
            ShaderMask(
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
            )
          else
            Text(
              widget.text,
              style: const TextStyle(fontSize: 14, height: 1.55),
            ),
          if (overflows) ...[  
            const SizedBox(height: 6),
            GestureDetector(
              onTap: _showFullReview,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: Colors.deepOrange, width: 1.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Read all',
                  style: TextStyle(
                    color: Colors.deepOrange,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
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

class LogScreen extends StatefulWidget {
  const LogScreen({super.key});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  List<BookReview> reviews = [];
  String sortOption = 'date';
  final Map<String, ({Map<String, int> counts, List<String> mine})> _reactions = {};

  @override
  void initState() {
    super.initState();
    loadReviews();
  }

  Future<void> loadReviews() async {
    final data = await StorageService.getReviews();

    setState(() {
      reviews = data;
      sortReviews();
    });

    await _loadAllReactions();
  }

  Future<void> _loadAllReactions() async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;

    final reviewsWithComments = reviews
        .where((r) => r.comment.isNotEmpty && r.id != null)
        .toList();
    if (reviewsWithComments.isEmpty) return;

    try {
      final results = await Future.wait(
          reviewsWithComments.map((r) => ReactionService.getReactions(myUid, r.id!)));
      if (!mounted) return;
      setState(() {
        for (var i = 0; i < reviewsWithComments.length; i++) {
          _reactions[reviewsWithComments[i].id!] = results[i];
        }
      });
    } catch (_) {
      // Reactions unavailable — fail silently
    }
  }

  /// Returns the last word of an author string, used for surname sorting.
  String _surname(String author) {
    final parts = author.trim().split(RegExp(r'\s+'));
    return parts.last.toLowerCase();
  }

  void sortReviews() {
    if (sortOption == 'alphabetical') {
      reviews.sort((a, b) => a.title.compareTo(b.title));
    } else if (sortOption == 'rating') {
      reviews.sort((b, a) => a.rating.compareTo(b.rating));
    } else if (sortOption == 'author') {
      reviews.sort((a, b) {
        final surnameCompare = _surname(a.author).compareTo(_surname(b.author));
        if (surnameCompare != 0) return surnameCompare;
        // Same surname — sort by full author name, then by title
        final authorCompare = a.author.toLowerCase().compareTo(b.author.toLowerCase());
        if (authorCompare != 0) return authorCompare;
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
    } else {
      reviews.sort((b, a) => a.dateAdded.compareTo(b.dateAdded));
    }
  }

  Future<void> deleteReview(BookReview review) async {
    await StorageService.deleteReview(review.title, review.author);
    await loadReviews();
  }

  void editReview(BookReview review) async {
    final index = await StorageService.findReviewIndex(
      review.title,
      review.author,
    );

    if (index == null) return;

    final book = Book(
      title: review.title,
      author: review.author,
      year: review.year,
      coverId: review.coverId,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReviewScreen(
          book: book,
          existingReview: review,
          reviewIndex: index,
        ),
      ),
    ).then((_) => loadReviews());
  }

  Map<String, List<BookReview>> groupReviews() {
    final Map<String, List<BookReview>> grouped = {};

    for (final review in reviews) {
      final key =
          "${_monthName(review.dateAdded.month)} ${review.dateAdded.year}";
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(review);
    }

    return grouped;
  }

  String _monthName(int month) {
    const months = [
      'January','February','March','April','May','June',
      'July','August','September','October','November','December'
    ];
    return months[month - 1];
  }

  void showOptions(BookReview review) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Review'),
                onTap: () {
                  Navigator.pop(context);
                  editReview(review);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Delete Review'),
                onTap: () async {
                  Navigator.pop(context);
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Review'),
                      content: const Text(
                          'Are you sure you want to delete this review?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('No'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text(
                            'Yes',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) await deleteReview(review);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String? getCoverUrl(int? id) {
    if (id == null) return null;
    return "https://covers.openlibrary.org/b/id/$id-M.jpg";
  }

  Widget _buildReactionRow(String reviewId) {
    final counts = _reactions[reviewId]?.counts ?? {};
    final activeEmojis =
        _kReactionEmojis.where((e) => (counts[e] ?? 0) > 0).toList();
    if (activeEmojis.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: activeEmojis.map((emoji) {
          return GestureDetector(
            onTap: () => _showReactorSheet(reviewId, emoji),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.deepOrange, width: 2),
              ),
              child: Text('$emoji ${counts[emoji]}',
                  style: const TextStyle(fontSize: 14)),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showReactorSheet(String reviewId, String emoji) {
    final myUid = FirebaseAuth.instance.currentUser!.uid;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ReactorSheet(
        ownerUid: myUid,
        reviewId: reviewId,
        emoji: emoji,
      ),
    );
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

  Widget buildCard(BookReview review) {
    final coverUrl = getCoverUrl(review.coverId);

    return GestureDetector(
      onLongPress: () => showOptions(review),
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
                coverUrl != null
                    ? Image.network(
                        coverUrl,
                        width: 50,
                        height: 70,
                        fit: BoxFit.cover,
                      )
                    : const SizedBox(
                        width: 50,
                        height: 70,
                        child: Icon(Icons.book, size: 40),
                      ),
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      _formatIcon(review.format),
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          title: Text(
            "${review.title} (${review.year})",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(review.author),
              const SizedBox(height: 2),
              Text("${review.rating % 1 == 0 ? review.rating.toInt() : review.rating.toStringAsFixed(1)}/10 ⭐"),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ONLY review comment shown in expanded view
                  if (review.comment.isNotEmpty)
                    _ExpandableReviewText(
                      text: review.comment,
                      bookTitle: '${review.title} (${review.year})',
                    )
                  else
                    const Text(
                      "No review written",
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                ],
              ),
            ),
            if (review.id != null)
              _buildReactionRow(review.id!),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grouped = groupReviews();

    return Scaffold(
      backgroundColor: const Color(0xffF5F2ED),
      body: SafeArea(
        child: Column(
          children: [
            // Header row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: SizedBox(
                height: 40,
                child: Row(
                  children: [
                    const Icon(Icons.menu_book, size: 28),
                    const SizedBox(width: 8),
                    Text(
                      'Shelfd',
                      style: GoogleFonts.fredoka(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xff5C3A1E),
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'Reading Log',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 19,
                        ),
                      ),
                    ),
                    DropdownButton<String>(
                      value: sortOption,
                      isDense: true,
                      underline: const SizedBox(),
                      onChanged: (value) {
                        setState(() {
                          sortOption = value!;
                          sortReviews();
                        });
                      },
                      items: const [
                        DropdownMenuItem(value: 'date', child: Text('Sort: Date')),
                        DropdownMenuItem(value: 'alphabetical', child: Text('Sort: A–Z')),
                        DropdownMenuItem(value: 'rating', child: Text('Sort: Rating')),
                        DropdownMenuItem(value: 'author', child: Text('Sort: Author')),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Body
            Expanded(
              child: reviews.isEmpty
                  ? const Center(child: Text('No books logged yet'))
                  : ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        Text(
                          'Total books: ${reviews.length}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (sortOption == 'date')
                          ...grouped.entries.map((entry) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Text(
                                    entry.key,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                ...entry.value.map(buildCard),
                              ],
                            );
                          })
                        else if (sortOption == 'author') ...() {
                          // Group by author (preserving sort order)
                          final List<Widget> items = [];
                          String? lastAuthor;
                          for (final review in reviews) {
                            if (review.author != lastAuthor) {
                              lastAuthor = review.author;
                              items.add(
                                Padding(
                                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                                  child: Text(
                                    review.author,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xff5C3A1E),
                                    ),
                                  ),
                                ),
                              );
                            }
                            items.add(buildCard(review));
                          }
                          return items;
                        }()
                        else
                          ...reviews.map(buildCard),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Reactor Sheet ────────────────────────────────────────────────────────────

class _ReactorSheet extends StatefulWidget {
  final String ownerUid;
  final String reviewId;
  final String emoji;

  const _ReactorSheet({
    required this.ownerUid,
    required this.reviewId,
    required this.emoji,
  });

  @override
  State<_ReactorSheet> createState() => _ReactorSheetState();
}

class _ReactorSheetState extends State<_ReactorSheet> {
  List<({String display, bool isPrivate, bool isFriend, String? avatarAsset, String? photoUrl})>? _entries;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final myUid = FirebaseAuth.instance.currentUser!.uid;
    final reactorMap = await ReactionService.getReactorMap(
        widget.ownerUid, widget.reviewId);

    final reactorUids = reactorMap.entries
        .where((e) => e.value.contains(widget.emoji))
        .map((e) => e.key)
        .toList();

    // Fetch all profiles and friendship statuses in parallel
    final results = await Future.wait(reactorUids.map((uid) async {
      if (uid == myUid) {
        return (display: 'You', isPrivate: false, isFriend: false, avatarAsset: null, photoUrl: null);
      }

      final profile = await FriendService.getUserProfile(uid);
      if (profile == null) {
        return (display: 'Unknown user', isPrivate: true, isFriend: false, avatarAsset: null, photoUrl: null);
      }

      final friendResult = await FriendService.getFriendshipStatus(uid);
      final isFriend = friendResult.status == FriendshipStatus.accepted;

      if (profile.privacyLevel == PrivacyLevel.public || isFriend) {
        return (
          display: profile.username?.isNotEmpty == true
              ? profile.username!
              : profile.displayName,
          isPrivate: false,
          isFriend: isFriend,
          avatarAsset: profile.avatarAsset,
          photoUrl: profile.photoUrl,
        );
      } else {
        return (display: 'Private user · Not a friend', isPrivate: true, isFriend: false, avatarAsset: null, photoUrl: null);
      }
    }));

    final entries = results.toList();

    if (mounted) setState(() => _entries = entries);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.75,
      expand: false,
      builder: (_, scrollController) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Text(
              '${widget.emoji} reacted by',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: _entries == null
                ? const Center(child: CircularProgressIndicator())
                : _entries!.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No reactions yet.',
                            style: TextStyle(color: Colors.grey)),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        itemCount: _entries!.length,
                        itemBuilder: (_, i) {
                          final e = _entries![i];
                          final ImageProvider? avatar = e.avatarAsset != null
                              ? AssetImage(e.avatarAsset!) as ImageProvider
                              : e.photoUrl != null
                                  ? NetworkImage(e.photoUrl!)
                                  : null;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: e.isPrivate
                                ? CircleAvatar(
                                    backgroundColor: Colors.grey.shade200,
                                    child: Icon(Icons.lock_outline,
                                        size: 20,
                                        color: Colors.grey.shade500),
                                  )
                                : CircleAvatar(
                                    backgroundColor:
                                        const Color(0xff5C3A1E).withOpacity(0.12),
                                    backgroundImage: avatar,
                                    child: avatar == null
                                        ? Icon(Icons.person,
                                            size: 20,
                                            color: const Color(0xff5C3A1E))
                                        : null,
                                  ),
                            title: Text(
                              e.display,
                              style: TextStyle(
                                color: e.isPrivate ? Colors.grey : null,
                                fontStyle:
                                    e.isPrivate ? FontStyle.italic : null,
                              ),
                            ),
                            trailing: e.isFriend
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.deepOrange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: Colors.deepOrange.withOpacity(0.4)),
                                    ),
                                    child: const Text(
                                      'Friend',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.deepOrange,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  )
                                : null,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
