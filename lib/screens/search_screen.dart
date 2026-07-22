import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../accessibility/accessibility_labels.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/book_service.dart';
import '../services/storage_service.dart';
import '../services/wishlist_service.dart';
import '../models/book.dart';
import '../models/book_review.dart';
import 'public_reviews_screen.dart';
import 'review_screen.dart';

class SearchScreen extends StatefulWidget {
  final bool autoFocus;
  final Function(int) onNavigate;

  const SearchScreen({
    super.key,
    this.autoFocus = false,
    required this.onNavigate,
  });

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
  String? _searchError;

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

  Future<void> _openIsbnScanner() async {
    final isbn = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _IsbnScannerSheet(),
    );
    if (isbn == null || !mounted) return;
    controller.text = isbn;
    setState(() {
      isLoading = true;
      _searchError = null;
    });
    try {
      final results = await BookService.searchByIsbn(isbn);
      await loadReviews();
      setState(() {
        books = results;
        isLoading = false;
      });
      if (results.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No book found for that barcode. Try searching by title instead.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      setState(() {
        isLoading = false;
        _searchError =
            'The book could not be found right now. Please check your internet connection and try again.';
      });
    }
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

  Future<void> search() async {
    setState(() {
      isLoading = true;
      _searchError = null;
    });

    try {
      final results = await BookService.searchBooks(controller.text);
      await loadReviews();
      setState(() {
        books = results;
        isLoading = false;
      });
    } catch (_) {
      setState(() {
        isLoading = false;
        _searchError =
            'The book could not be found right now. Please check your internet connection and try again.';
      });
    }
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

  // ─── Book list tile (shared by both search tabs) ──────────────────────────
  //
  // [reviewMode: false]  Tab 1 — Log / Review: wishlist button, taps to ReviewScreen
  // [reviewMode: true]   Tab 2 — Community reviews: no wishlist button, taps to PublicReviewsScreen
  Widget _buildBookTile(Book book, {required bool reviewMode}) {
    final review = findReview(book);
    return Semantics(
      container: true,
      label:
          '${book.title} by ${book.author}. Published in ${_spokenYear(book.year)}.',
      hint: reviewMode ? 'Tap to view community reviews' : null,
      child: ExcludeSemantics(
        child: ListTile(
          leading: getCoverUrl(book.coverId) != null
              ? Image.network(
                  getCoverUrl(book.coverId)!,
                  width: 40,
                  excludeFromSemantics: true,
                  errorBuilder: (_, __, ___) => const SizedBox(
                    width: 40,
                    child: Icon(Icons.book),
                  ),
                )
              : const SizedBox(width: 40, child: Icon(Icons.book)),
          title: Text(book.title),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${book.author} (${book.year})'),
              if (review != null)
                Row(
                  children: [
                    const Icon(Icons.check, size: 16, color: Colors.green),
                    const SizedBox(width: 6),
                    Text(
                      'Already logged \u2014 ${review.rating.toStringAsFixed(1)} / 10',
                      style: const TextStyle(color: Colors.green),
                    ),
                  ],
                ),
            ],
          ),
          trailing: reviewMode
              ? null
              : (review == null
                  ? _WishlistButton(
                      book: book,
                      isWishlisted: _wishlistedKeys.contains(
                        '${book.title.toLowerCase()}|||${book.author.toLowerCase()}',
                      ),
                      onChanged: loadReviews,
                    )
                  : null),
          onTap: reviewMode
              ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PublicReviewsScreen(book: book),
                    ),
                  )
              : (review == null
                  ? () async {
                      final idx = await StorageService.findReviewIndex(
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
                    }
                  : null),
          onLongPress: (!reviewMode && review != null)
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = ShelfdThemeScope.colorsOf(context);
    final isBatman = ShelfdThemeScope.of(context).theme == ShelfdTheme.batman;
    return Scaffold(
      backgroundColor: c.scaffoldBg,

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
                        'assets/images/shelfd_brand_name.png',
                        height: 36,
                        fit: BoxFit.contain,
                        excludeFromSemantics: true,
                      ),
                      const Spacer(),
                      Semantics(
                        button: true,
                        label: avatarSemanticLabel(isCurrentUser: true),
                        hint: 'Opens your profile screen',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: () => widget.onNavigate(3),
                          child: ExcludeSemantics(
                              child: themedAvatar(
                                colors: c,
                                child: CircleAvatar(
                                  radius: 20,
                                  backgroundColor: c.avatarBg,
                                  backgroundImage: _avatarAsset != null
                                      ? AssetImage(_avatarAsset!) as ImageProvider
                                      : (FirebaseAuth.instance.currentUser?.photoURL != null
                                          ? NetworkImage(FirebaseAuth.instance.currentUser!.photoURL!)
                                          : null),
                                  child: _avatarAsset == null &&
                                          FirebaseAuth.instance.currentUser?.photoURL == null
                                      ? Icon(Icons.person, size: 20, color: c.brandColor)
                                      : null,
                                ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Search field
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: c.cardBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
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
                        IconButton(
                          icon: _BarcodeIcon(
                            color: c.brandColor,
                            size: MediaQuery.textScalerOf(context).scale(22),
                          ),
                          tooltip: 'Scan ISBN barcode',
                          onPressed: _openIsbnScanner,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.primaryAccent,
                        padding: const EdgeInsets.all(14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: search,
                      child: Text(
                        "Search",
                        style: isBatman
                            ? GoogleFonts.orbitron(
                                color: Colors.white, fontSize: 15)
                            : const TextStyle(
                                color: Colors.white, fontSize: 15),
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
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  // ── Mode tab bar ─────────────────────────────────────────
                  Builder(builder: (ctx) {
                    final tc = ShelfdThemeScope.colorsOf(ctx);
                    return TabBar(
                      labelColor: tc.primaryAccent,
                      unselectedLabelColor: tc.textSecondary,
                      indicatorColor: tc.primaryAccent,
                      tabs: [
                        Tab(
                          icon: Semantics(
                            label: 'Log and review books',
                            child: const ExcludeSemantics(
                              child: Icon(Icons.menu_book_outlined),
                            ),
                          ),
                        ),
                        Tab(
                          icon: Semantics(
                            label: 'Browse community reviews',
                            child: const ExcludeSemantics(
                              child: Icon(Icons.rate_review_outlined),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                  // ── Tab content ──────────────────────────────────────────
                  Expanded(
                    child: _searchError != null
                        ? SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 2),
                                  child: Icon(Icons.wifi_off,
                                      color: Colors.grey),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _searchError!,
                                    style:
                                        const TextStyle(color: Colors.grey),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : TabBarView(
                            children: [
                              // Tab 1 — Log / Review
                              books.isEmpty
                                  ? const _SearchEmptyState(
                                      icon: Icons.menu_book_outlined,
                                      message: 'Search for books to log',
                                    )
                                  : ListView.builder(
                                      itemCount: books.length,
                                      itemBuilder: (ctx, i) => _buildBookTile(
                                          books[i],
                                          reviewMode: false),
                                    ),
                              // Tab 2 — Community reviews
                              books.isEmpty
                                  ? const _SearchEmptyState(
                                      icon: Icons.rate_review_outlined,
                                      message:
                                          'Search community ratings and reviews',
                                    )
                                  : ListView.builder(
                                      itemCount: books.length,
                                      itemBuilder: (ctx, i) => _buildBookTile(
                                          books[i],
                                          reviewMode: true),
                                    ),
                            ],
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
}

// ─── Search empty state ──────────────────────────────────────────────────────────

class _SearchEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _SearchEmptyState({
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final c = ShelfdThemeScope.colorsOf(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(icon, size: 64, color: Colors.grey.shade300),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.textMuted,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── ISBN Barcode Scanner Sheet ───────────────────────────────────────────────

class _IsbnScannerSheet extends StatefulWidget {
  const _IsbnScannerSheet();

  @override
  State<_IsbnScannerSheet> createState() => _IsbnScannerSheetState();
}

class _IsbnScannerSheetState extends State<_IsbnScannerSheet> {
  final _controller = MobileScannerController();
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null) return;
    // Books use EAN-13 (ISBN-13) or EAN-8; also accept Code-128 for older editions
    final format = barcode.format;
    if (format != BarcodeFormat.ean13 &&
        format != BarcodeFormat.ean8 &&
        format != BarcodeFormat.code128) return;
    final raw = barcode.rawValue;
    if (raw == null || raw.isEmpty) return;
    _handled = true;
    Navigator.of(context).pop(raw);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: Stack(
          children: [
            MobileScanner(controller: _controller, onDetect: _onDetect),

            // Close button
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),

            // Header label
            Positioned(
              top: 20,
              left: 0,
              right: 60,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Scan ISBN Barcode',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                  ),
                ),
              ),
            ),

            // Bottom instruction
            Positioned(
              bottom: 36,
              left: 24,
              right: 24,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Point the camera at the barcode on the back of the book',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
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
              Flexible(child: Text(_wishlisted ? 'Added to Future Reads' : 'Removed from Future Reads')),
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
    final c = ShelfdThemeScope.colorsOf(context);
    return IconButton(
      tooltip: _wishlisted ? "Remove from Future Reads" : "Add to Future Reads",
      icon: Icon(
        _wishlisted ? Icons.bookmark : Icons.bookmark_add_outlined,
        color: _wishlisted ? c.primaryAccent : c.textSecondary,
      ),
      onPressed: () => _toggle(context),
    );
  }
}

// ─── Barcode icon ─────────────────────────────────────────────────────────────

class _BarcodeIcon extends StatelessWidget {
  final Color color;
  final double size;
  const _BarcodeIcon({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _BarcodePainter(color)),
    );
  }
}

class _BarcodePainter extends CustomPainter {
  final Color color;
  const _BarcodePainter(this.color);

  // Widths of alternating bar/gap pairs (1 = narrow, 2 = wide).
  // Represents a realistic-looking barcode pattern.
  static const List<int> _pattern = [
    2, 1, 1, 2, 1, 1, 2, 1, 2, 1,
    1, 2, 1, 1, 1, 2, 2, 1, 1, 2,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final unit = size.width / (_pattern.fold(0, (a, b) => a + b));
    const barHeightFraction = 0.75;
    final barTop = size.height * (1 - barHeightFraction) / 2;
    final barBottom = barTop + size.height * barHeightFraction;

    double x = 0;
    for (int i = 0; i < _pattern.length; i++) {
      final w = _pattern[i] * unit;
      if (i.isEven) {
        // Even indices = bars (filled)
        canvas.drawRect(Rect.fromLTRB(x, barTop, x + w, barBottom), paint);
      }
      // Odd indices = gaps (skip)
      x += w;
    }
  }

  @override
  bool shouldRepaint(_BarcodePainter old) => old.color != color;
}
