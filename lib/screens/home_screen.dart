import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/book.dart';
import '../models/book_review.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../services/book_service.dart';
import '../services/quote_service.dart';
import '../services/wishlist_service.dart';

class HomeScreen extends StatefulWidget {
  final Function(int) onNavigate;
  final VoidCallback? onSearchTapped;

  const HomeScreen({super.key, required this.onNavigate, this.onSearchTapped});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<BookReview> _recentReviews = [];
  List<Book> _recommendations = [];
  bool _loadingRecs = true;
  DailyQuote? _quote;
  bool _loadingQuote = true;
  String? _avatarAsset;
  final _authService = AuthService();
  StreamSubscription<String?>? _avatarSub;

  @override
  void initState() {
    super.initState();
    _loadData();
    _avatarSub = _authService.avatarAssetStream.listen((asset) {
      if (mounted) setState(() => _avatarAsset = asset);
    });
  }

  @override
  void dispose() {
    _avatarSub?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final all = await StorageService.getReviews();
    final sorted = List<BookReview>.from(all)
      ..sort((a, b) => b.dateAdded.compareTo(a.dateAdded));

    setState(() {
      _recentReviews = sorted.take(5).toList();
    });

    final recs = await BookService.getRecommendations(all);
    final quote = await QuoteService.getQuoteOfTheDay();

    if (mounted) {
      setState(() {
        _recommendations = recs;
        _loadingRecs = false;
        _quote = quote;
        _loadingQuote = false;
      });
    }
  }

  String? _coverUrl(int? id) {
    if (id == null) return null;
    return "https://covers.openlibrary.org/b/id/$id-M.jpg";
  }

  void _showAddToWishlist(BuildContext context, Book book) async {
    final isAlready = await WishlistService.isWishlisted(book);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                isAlready ? Icons.bookmark_added : Icons.bookmark_add_outlined,
                color: Colors.deepOrange,
              ),
              title: Text(isAlready ? 'Already in Future Reads' : 'Add to Future Reads'),
              subtitle: Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: isAlready
                  ? null
                  : () async {
                      Navigator.pop(context);
                      await WishlistService.addBook(book);
                      if (mounted) {
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            SnackBar(
                              content: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.bookmark_added, color: Colors.white, size: 18),
                                  SizedBox(width: 8),
                                  Text('Added to Future Reads'),
                                ],
                              ),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              margin: const EdgeInsets.all(16),
                            ),
                          );
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
    return Scaffold(
      backgroundColor: const Color(0xffF5F2ED),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              // App bar row — full logo + wordmark
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/shelfd_app_tile.png',
                    height: 48,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Shelfd',
                    style: GoogleFonts.fredoka(
                      fontSize: 35,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xff5C3A1E),
                    ),
                  ),
                  const Spacer(),
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xff5C3A1E).withOpacity(0.15),
                    backgroundImage: _avatarAsset != null
                        ? AssetImage(_avatarAsset!) as ImageProvider
                        : (FirebaseAuth.instance.currentUser?.photoURL != null
                            ? NetworkImage(FirebaseAuth.instance.currentUser!.photoURL!)
                            : null),
                    child: _avatarAsset == null &&
                            FirebaseAuth.instance.currentUser?.photoURL == null
                        ? const Icon(Icons.person, size: 20, color: Color(0xff5C3A1E))
                        : null,
                  ),
                ],
              ),

              const SizedBox(height: 20),

              const Text(
                "Your Reading Dashboard",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

              // Search bar — tapping jumps to Search tab
              GestureDetector(
                onTap: () {
                  widget.onNavigate(1);
                  widget.onSearchTapped?.call();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const TextField(
                    enabled: false,
                    decoration: InputDecoration(
                      icon: Icon(Icons.search),
                      hintText: "Search books, authors, genres...",
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ── Recently Rated ──────────────────────────────────────
              const Text(
                "Recently Rated",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              _recentReviews.isEmpty
                  ? _emptyCard("Nothing recently rated.")
                  : SizedBox(
                      height: 240,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _recentReviews.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final review = _recentReviews[index];
                          final url = _coverUrl(review.coverId);

                          return _bookCard(
                            title: review.title,
                            subtitle: review.author,
                            footer:
                                "${review.rating % 1 == 0 ? review.rating.toInt() : review.rating.toStringAsFixed(1)}/10 ⭐",
                            coverUrl: url,
                            isFavourite: review.isFavourite,
                          );
                        },
                      ),
                    ),

              const SizedBox(height: 28),

              // ── Recommended for You ────────────────────────────────
              const Text(
                "Recommended for You",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              _loadingRecs
                  ? const SizedBox(
                      height: 60,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _recommendations.isEmpty
                      ? _emptyCard(
                          "No recommendations yet — log some books first :)")
                      : SizedBox(
                          height: 240,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _recommendations.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, index) {
                              final book = _recommendations[index];
                              final url = _coverUrl(book.coverId);

                              return GestureDetector(
                                onLongPress: () => _showAddToWishlist(context, book),
                                child: _bookCard(
                                  title: book.title,
                                  subtitle: book.author,
                                  footer: book.year > 0
                                      ? "${book.year}"
                                      : "",
                                  coverUrl: url,
                                  isFavourite: false,
                                ),
                              );
                            },
                          ),
                        ),

              const SizedBox(height: 28),

              // ── Quote of the Day ───────────────────────────────────
              const Text(
                "Quote of the Day",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              _loadingQuote
                  ? const SizedBox(
                      height: 60,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xffd6d9d6),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '"${_quote!.text}"',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 15,
                              height: 1.5,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "— ${_quote!.author}",
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

              const SizedBox(height: 28),

              // Discover button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    padding: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => widget.onNavigate(1),
                  child: const Text(
                    "Discover New Books",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  /// Shared card widget for both sections.
  Widget _bookCard({
    required String title,
    required String subtitle,
    required String footer,
    required String? coverUrl,
    required bool isFavourite,
  }) {
    return Container(
      width: 150,
      decoration: BoxDecoration(
        color: isFavourite
            ? Colors.amber.withOpacity(0.15)
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image
            Stack(
              children: [
                coverUrl != null
                    ? Image.network(
                        coverUrl,
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        height: 120,
                        width: double.infinity,
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: Icon(
                            Icons.book,
                            size: 40,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                if (isFavourite)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.star,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),

            // Details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                      ),
                    ),
                    const Spacer(),
                    if (footer.isNotEmpty)
                      Text(
                        footer,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Colors.black45,
          fontSize: 14,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
