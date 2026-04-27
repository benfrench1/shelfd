import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../services/book_service.dart';
import '../services/storage_service.dart';
import '../services/wishlist_service.dart';
import '../models/book.dart';
import '../models/book_review.dart';
import 'review_screen.dart';

class SearchScreen extends StatefulWidget {
  final bool autoFocus;
  const SearchScreen({super.key, this.autoFocus = false});

  @override
  State<SearchScreen> createState() =>
      _SearchScreenState();
}

class _SearchScreenState
    extends State<SearchScreen> {
  final controller = TextEditingController();
  late final FocusNode _focusNode;

  List<Book> books = [];
  List<BookReview> reviews = [];
  Set<String> _wishlistedKeys = {};
  String? _avatarAsset;
  final _authService = AuthService();
  StreamSubscription<String?>? _avatarSub;

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    loadReviews();
    _avatarSub = _authService.avatarAssetStream.listen((asset) {
      if (mounted) setState(() => _avatarAsset = asset);
    });
    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.autoFocus && !oldWidget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _avatarSub?.cancel();
    super.dispose();
  }

  Future<void> loadReviews() async {
    reviews = await StorageService.getReviews();
    final wishlist = await WishlistService.getWishlist();
    setState(() {
      _wishlistedKeys = wishlist
          .map((b) => '${b.title.toLowerCase()}|||${b.author.toLowerCase()}')
          .toSet();
    });
  }

  Future<void> search() async {
    setState(() {
      isLoading = true;
    });

    final results =
        await BookService.searchBooks(controller.text);

    await loadReviews();

    setState(() {
      books = results;
      isLoading = false;
    });
  }

  BookReview? findReview(Book book) {
    try {
      return reviews.firstWhere(
        (r) => r.title == book.title && r.author == book.author,
      );
    } catch (_) {
      return null;
    }
  }

  String? getCoverUrl(int? id) {
    if (id == null) return null;
    return "https://covers.openlibrary.org/b/id/$id-M.jpg";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F2ED),

      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo row — matches home screen exactly
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

                  // Search field
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: controller,
                      focusNode: _focusNode,
                      decoration: const InputDecoration(
                        icon: Icon(Icons.search),
                        hintText: "Search books, authors, genres...",
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => search(),
                    ),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        padding: const EdgeInsets.all(14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: search,
                      child: const Text(
                        "Search",
                        style: TextStyle(color: Colors.white, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),

          Expanded(
            child: ListView.builder(
              itemCount: books.length,
              itemBuilder: (context, index) {
                final book = books[index];
                final review = findReview(book);

                return ListTile(
                  leading: getCoverUrl(book.coverId) != null
                      ? Image.network(
                          getCoverUrl(book.coverId)!,
                          width: 40,
                        )
                      : const Icon(Icons.book),

                  title: Text(book.title),

                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("${book.author} (${book.year})"),

                      if (review != null)
                        Row(
                          children: [
                            const Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "Already logged — ${review.rating.toStringAsFixed(1)} / 10",
                              style: const TextStyle(
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),

                  trailing: review == null
                      ? _WishlistButton(
                          book: book,
                          isWishlisted: _wishlistedKeys.contains(
                            '${book.title.toLowerCase()}|||${book.author.toLowerCase()}',
                          ),
                          onChanged: loadReviews,
                        )
                      : null,

                  onTap: review == null
                      ? () async {
                          final index =
                              await StorageService.findReviewIndex(
                            book.title,
                            book.author,
                          );

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ReviewScreen(
                                book: book,
                                reviewIndex: index,
                                existingReview: review,
                              ),
                            ),
                          ).then((_) => loadReviews());
                        }
                      : null,

                  onLongPress: review != null
                      ? () {
                          showModalBottomSheet(
                            context: context,
                            builder: (context) => SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading: const Icon(Icons.edit),
                                    title: const Text('Edit Review'),
                                    onTap: () async {
                                      Navigator.pop(context);
                                      final idx =
                                          await StorageService.findReviewIndex(
                                        book.title,
                                        book.author,
                                      );
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ReviewScreen(
                                            book: book,
                                            reviewIndex: idx,
                                            existingReview: review,
                                          ),
                                        ),
                                      ).then((_) => loadReviews());
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
  }
}

class _WishlistButton extends StatefulWidget {
  final Book book;
  final bool isWishlisted;
  final VoidCallback onChanged;

  const _WishlistButton({
    required this.book,
    required this.isWishlisted,
    required this.onChanged,
  });

  @override
  State<_WishlistButton> createState() => _WishlistButtonState();
}

class _WishlistButtonState extends State<_WishlistButton> {
  late bool _wishlisted;

  @override
  void initState() {
    super.initState();
    _wishlisted = widget.isWishlisted;
  }

  @override
  void didUpdateWidget(_WishlistButton old) {
    super.didUpdateWidget(old);
    _wishlisted = widget.isWishlisted;
  }

  Future<void> _toggle(BuildContext context) async {
    if (_wishlisted) {
      await WishlistService.removeBook(widget.book);
    } else {
      await WishlistService.addBook(widget.book);
    }
    setState(() {
      _wishlisted = !_wishlisted;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _wishlisted ? Icons.bookmark_added : Icons.bookmark_remove,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(_wishlisted ? 'Added to Future Reads' : 'Removed from Future Reads'),
            ],
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: _wishlisted ? "Remove from Future Reads" : "Add to Future Reads",
      icon: Icon(
        _wishlisted ? Icons.bookmark : Icons.bookmark_add_outlined,
        color: _wishlisted ? Colors.deepOrange : Colors.grey,
      ),
      onPressed: () => _toggle(context),
    );
  }
}
