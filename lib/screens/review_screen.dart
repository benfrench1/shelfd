import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/achievement.dart';
import '../models/book.dart';
import '../models/book_review.dart';
import '../services/storage_service.dart';
import '../services/wishlist_service.dart';

class ReviewScreen extends StatefulWidget {
  final Book book;
  final int? reviewIndex;
  final BookReview? existingReview;

  const ReviewScreen({
    super.key,
    required this.book,
    this.reviewIndex,
    this.existingReview,
  });

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final commentController = TextEditingController();

  double rating = 5.0;

  bool isFavourite = false;
  bool _isWishlisted = false;
  bool _isSaving = false;

  bool _globalRatingLoading = true;
  double? _globalRating;
  int? _globalRatingsCount;
  String? _globalRatingSource;


  BookFormat _format = BookFormat.physical;

  @override
  void initState() {
    super.initState();

    // If editing existing review, preload values
    if (widget.existingReview != null) {
      rating = widget.existingReview!.rating;
      commentController.text = widget.existingReview!.comment;
      isFavourite = widget.existingReview!.isFavourite;
      _format = widget.existingReview!.format;
    }

    // Only check wishlist state for new reviews
    if (widget.reviewIndex == null) {
      WishlistService.isWishlisted(widget.book).then((val) {
        if (mounted) setState(() => _isWishlisted = val);
      });
    }

    _fetchGlobalRating();
  }

  Future<void> _fetchGlobalRating() async {
    if (widget.book.workId == null) {
      if (mounted) setState(() => _globalRatingLoading = false);
      return;
    }
    try {
      final url = Uri.https(
        'openlibrary.org',
        '/works/${widget.book.workId}/ratings.json',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final d = jsonDecode(response.body);
        final avg = (d['summary']?['average'] as num?)?.toDouble();
        final cnt = d['summary']?['count'] as int?;
        if (avg != null && mounted) {
          setState(() {
            _globalRating = avg;
            _globalRatingsCount = cnt;
            _globalRatingSource = 'Open Library';
            _globalRatingLoading = false;
          });
          return;
        }
      }
    } catch (_) {
      // silently fail — global rating is non-critical
    }
    if (mounted) setState(() => _globalRatingLoading = false);
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}m';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }

  String _numberToWords(int n) {
    const ones = [
      'zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight',
      'nine', 'ten', 'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen',
      'sixteen', 'seventeen', 'eighteen', 'nineteen'
    ];
    const tens = [
      '', '', 'twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy',
      'eighty', 'ninety'
    ];

    if (n < 20) return ones[n];
    if (n < 100) {
      final t = n ~/ 10;
      final u = n % 10;
      return u == 0 ? tens[t] : '${tens[t]} ${ones[u]}';
    }
    if (n < 1000) {
      final h = n ~/ 100;
      final rest = n % 100;
      final result = '${ones[h]} hundred';
      if (rest == 0) return result;
      return '$result ${_numberToWords(rest)}';
    }
    if (n < 1000000) {
      final t = n ~/ 1000;
      final rest = n % 1000;
      final result = '${_numberToWords(t)} thousand';
      if (rest == 0) return result;
      return '$result ${_numberToWords(rest)}';
    }
    return n.toString();
  }

  String _spokenGlobalRating(double rating, int count, String source) {
    final ratingStr = rating % 1 == 0
        ? _numberToWords(rating.toInt())
        : '${_numberToWords((rating * 10).round() ~/ 10)} point ${_numberToWords(((rating * 10).round() % 10))}';
    final countStr = _numberToWords(count);
    return '$ratingStr out of five, with $countStr ratings from $source';
  }

  void _showSnack(String message, {IconData? icon}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, color: Colors.white, size: 18), const SizedBox(width: 8)],
              Text(message),
            ],
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
  }

  void saveReview() async {
    setState(() => _isSaving = true);

    final review = BookReview(
      title: widget.book.title,
      author: widget.book.author,
      year: widget.book.year,
      rating: rating,
      comment: commentController.text,
      coverId: widget.book.coverId,
      workId: widget.book.workId,
      isFavourite: isFavourite,
      format: _format,
      dateAdded: widget.existingReview?.dateAdded,
    );

    final isNewReview = widget.reviewIndex == null;

    // Get count from cache before the save starts — instant, works offline
    int? countBefore;
    if (isNewReview) {
      try {
        countBefore = (await StorageService.getReviewsFromCache()).length;
      } catch (_) {
        // Cache unavailable — achievement check skipped for this save
      }
    }

    // Determine which achievements will unlock
    final toUnlock = (isNewReview && countBefore != null)
        ? kAchievements
            .where((a) => a.threshold > 0 && a.threshold == countBefore! + 1)
            .toList()
        : <Achievement>[];

    // Start the save in the background — timeout clock begins now
    bool showOfflineMessage = false;
    final saveFuture = _doSave(review).timeout(
      const Duration(seconds: 6),
      onTimeout: () {
        showOfflineMessage = true;
      },
    );

    // Show achievement dialogs immediately while the save runs in the background
    for (final achievement in toUnlock) {
      if (!mounted) break;
      await _showAchievementDialog(achievement);
      if (!mounted) return;
    }

    // Now wait for the save to finish (may already be done, or still counting down)
    try {
      await saveFuture;
    } catch (_) {
      showOfflineMessage = true;
    }

    if (mounted) {
      setState(() => _isSaving = false);
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      if (showOfflineMessage) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Review saved offline. It will sync automatically when your connection is restored.',
            ),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _doSave(BookReview review) async {
    if (widget.reviewIndex != null) {
      await StorageService.updateReview(widget.reviewIndex!, review);
    } else {
      await StorageService.saveReview(review);
    }
  }

  Future<void> _showAchievementDialog(Achievement achievement) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      barrierDismissible: true,
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.of(ctx).pop(),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: GestureDetector(
            onTap: () {}, // prevent tap on medal from closing
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Achievement Unlocked!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xffFFF3CD),
                    border: Border.all(
                      color: const Color(0xffD4A017),
                      width: 5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xffD4A017).withOpacity(0.55),
                        blurRadius: 32,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      achievement.emoji,
                      style: const TextStyle(fontSize: 72),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    achievement.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text(
                    'Awesome!',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xffD4A017),
                      fontWeight: FontWeight.bold,
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

  String? getCoverUrl(int? id) {
    if (id == null) return null;
    return "https://covers.openlibrary.org/b/id/$id-M.jpg";
  }

  @override
  Widget build(BuildContext context) {
    final book = widget.book;

    return Scaffold(
      backgroundColor: const Color(0xffF5F2ED),
      appBar: AppBar(
        backgroundColor: const Color(0xffF5F2ED),
        elevation: 0,
        title: Text(
          widget.reviewIndex != null ? "Edit Review" : "Review Book",
        ),

        actions: [
          if (widget.reviewIndex == null)
            IconButton(
              tooltip: _isWishlisted ? 'Remove from Future Reads' : 'Add to Future Reads',
              icon: Icon(
                _isWishlisted ? Icons.bookmark_added : Icons.bookmark_add_outlined,
                color: Colors.deepOrange,
              ),
              onPressed: () async {
                if (_isWishlisted) {
                  await WishlistService.removeBook(widget.book);
                  if (mounted) _showSnack('Removed from Future Reads', icon: Icons.bookmark_remove);
                } else {
                  await WishlistService.addBook(widget.book);
                  if (mounted) _showSnack('Added to Future Reads', icon: Icons.bookmark_added);
                }
                if (mounted) setState(() => _isWishlisted = !_isWishlisted);
              },
            ),
          IconButton(
            tooltip: isFavourite ? 'Remove favourite' : 'Mark as favourite',
            icon: Icon(
              isFavourite ? Icons.star : Icons.star_border,
              color: Colors.amber,
            ),
            onPressed: () {
              final nowFavourite = !isFavourite;
              setState(() => isFavourite = nowFavourite);
              _showSnack(
                nowFavourite ? 'Starred' : 'Unstarred',
                icon: nowFavourite ? Icons.star : Icons.star_border,
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (getCoverUrl(book.coverId) != null)
              Center(
                child: Semantics(
                  button: true,
                  label: 'Book cover for ${book.title}',
                  hint: 'Opens a larger book cover image',
                  child: GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        barrierColor: Colors.black87,
                        barrierDismissible: true,
                        builder: (ctx) => GestureDetector(
                          onTap: () => Navigator.of(ctx).pop(),
                          behavior: HitTestBehavior.opaque,
                          child: Center(
                            child: GestureDetector(
                              onTap: () {},
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  getCoverUrl(book.coverId)!,
                                  height: 360,
                                  fit: BoxFit.contain,
                                  semanticLabel: 'Large book cover for ${book.title}',
                                  errorBuilder: (_, __, ___) => const SizedBox(
                                    height: 360,
                                    child: Center(
                                      child: Icon(Icons.book, size: 80, color: Colors.grey),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    child: Image.network(
                      getCoverUrl(book.coverId)!,
                      height: 160,
                      semanticLabel: 'Book cover for ${book.title}',
                      errorBuilder: (_, __, ___) => const SizedBox(
                        height: 160,
                        child: Center(
                          child: Icon(Icons.book, size: 60, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 16),

            Semantics(
              header: true,
              child: Text(
                book.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            Text("${book.author} (${book.year})"),

            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _globalRatingLoading
                  ? const SizedBox(
                      height: 14,
                      width: 14,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    )
                  : _globalRating != null
                      ? Semantics(
                          label: _spokenGlobalRating(
                              _globalRating!, _globalRatingsCount ?? 0, _globalRatingSource ?? 'Open Library'),
                          child: ExcludeSemantics(
                            child: Text(
                              '${_globalRating!.toStringAsFixed(1)} / 5 ★  |  ${_formatCount(_globalRatingsCount ?? 0)} ratings  ($_globalRatingSource)',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        )
                      : const Text(
                          'Global rating not available',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                        ),
            ),

            const SizedBox(height: 24),

            // Rating & comment card
            Card(
              color: const Color(0xffD9D4CB),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Your Rating",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),

                    const SizedBox(height: 34),
                    Row(
                      children: [
                        // Decrement button
                        _RatingStepButton(
                          label: '−',
                          onTap: () => setState(() {
                            rating = double.parse(
                              (rating - 0.1).clamp(0.0, 10.0).toStringAsFixed(1),
                            );
                          }),
                        ),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              const double trackPad = 12.0;
                              final double w = constraints.maxWidth;
                              final double thumbLeft =
                                  trackPad + (rating / 10.0) * (w - 2 * trackPad);
                              final String bubbleLabel = (rating == 0 || rating == 10)
                                  ? rating.toInt().toString()
                                  : rating.toStringAsFixed(1);
                              return Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      activeTrackColor: Colors.deepOrange,
                                      inactiveTrackColor:
                                          Colors.deepOrange.withOpacity(0.25),
                                      thumbColor: Colors.deepOrange,
                                      overlayColor:
                                          Colors.deepOrange.withOpacity(0.15),
                                      overlayShape: const RoundSliderOverlayShape(
                                          overlayRadius: 12),
                                      showValueIndicator: ShowValueIndicator.never,
                                    ),
                                    child: Slider(
                                      value: rating,
                                      min: 0,
                                      max: 10,
                                      divisions: 100,
                                      label: bubbleLabel,
                                      onChanged: (value) {
                                        setState(() {
                                          rating = value;
                                        });
                                      },
                                    ),
                                  ),
                                  Positioned(
                                    top: -30,
                                    left: thumbLeft - 16,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.deepOrange,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        bubbleLabel,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        // Increment button
                        _RatingStepButton(
                          label: '+',
                          onTap: () => setState(() {
                            rating = double.parse(
                              (rating + 0.1).clamp(0.0, 10.0).toStringAsFixed(1),
                            );
                          }),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),
                    Text(
                      (rating == 0 || rating == 10)
                          ? "${rating.toInt()} / 10"
                          : "${rating.toStringAsFixed(1)} / 10",
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      controller: commentController,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      spellCheckConfiguration: const SpellCheckConfiguration(),
                      decoration: const InputDecoration(
                        labelText: "Comment",
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Color(0xffF5F2ED),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              "Format",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            SegmentedButton<BookFormat>(
              segments: const [
                ButtonSegment(
                  value: BookFormat.physical,
                  label: Text("Physical"),
                  icon: Icon(Icons.menu_book),
                ),
                ButtonSegment(
                  value: BookFormat.audiobook,
                  label: Text("Audiobook"),
                  icon: Icon(Icons.headphones),
                ),
                ButtonSegment(
                  value: BookFormat.braille,
                  label: Text("Braille"),
                  icon: Icon(Icons.grain),
                ),
              ],
              selected: {_format},
              onSelectionChanged: (value) {
                setState(() {
                  _format = value.first;
                });
              },
            ),

            const SizedBox(height: 20),

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
                onPressed: _isSaving ? null : saveReview,
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        "Save Review",
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Rating step button (− / +) ──────────────────────────────────────────────

class _RatingStepButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _RatingStepButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.deepOrange,
            fontSize: 32,
            fontWeight: FontWeight.bold,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}
