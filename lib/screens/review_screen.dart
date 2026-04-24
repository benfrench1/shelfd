import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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

  bool _globalRatingLoading = true;
  double? _globalRating;
  int? _globalRatingsCount;


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
    // Try two queries: exact intitle/inauthor first, then plain title+author
    final queries = [
      'intitle:${widget.book.title} inauthor:${widget.book.author}',
      '${widget.book.title} ${widget.book.author}',
    ];
    try {
      for (final q in queries) {
        final url = Uri.https('www.googleapis.com', '/books/v1/volumes', {
          'q': q,
          'maxResults': '5',
        });
        final response = await http.get(url);
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final items = data['items'] as List?;
          if (items != null && items.isNotEmpty) {
            // Pick the first item that has a rating
            for (final item in items) {
              final info = item['volumeInfo'] as Map<String, dynamic>;
              final r = (info['averageRating'] as num?)?.toDouble();
              final c = info['ratingsCount'] as int?;
              if (r != null) {
                if (mounted) {
                  setState(() {
                    _globalRating = r;
                    _globalRatingsCount = c;
                    _globalRatingLoading = false;
                  });
                }
                return;
              }
            }
          }
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
    final review = BookReview(
      title: widget.book.title,
      author: widget.book.author,
      year: widget.book.year,
      rating: rating,
      comment: commentController.text,
      coverId: widget.book.coverId,
      isFavourite: isFavourite,
      format: _format,
    );

    if (widget.reviewIndex != null) {
      await StorageService.updateReview(
        widget.reviewIndex!,
        review,
      );
    } else {
      await StorageService.saveReview(review);
    }

    if (mounted) {
      Navigator.pop(context);
    }
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
                child: Image.network(
                  getCoverUrl(book.coverId)!,
                  height: 160,
                ),
              ),

            const SizedBox(height: 16),

            Text(
              book.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
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
                  : Text(
                      _globalRating != null
                          ? '${_globalRating!.toStringAsFixed(1)} / 5 ★  |  ${_formatCount(_globalRatingsCount ?? 0)} ratings  (Google Books)'
                          : 'Global rating not available',
                      style: const TextStyle(
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

                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: Colors.deepOrange,
                        inactiveTrackColor: Colors.deepOrange.withOpacity(0.25),
                        thumbColor: Colors.deepOrange,
                        overlayColor: Colors.deepOrange.withOpacity(0.15),
                        valueIndicatorColor: Colors.deepOrange,
                      ),
                      child: Slider(
                        value: rating,
                        min: 0,
                        max: 10,
                        divisions: 100,
                        label: (rating == 0 || rating == 10)
                            ? rating.toInt().toString()
                            : rating.toStringAsFixed(1),
                        onChanged: (value) {
                          setState(() {
                            rating = value;
                          });
                        },
                      ),
                    ),

                    Text(
                      (rating == 0 || rating == 10)
                          ? "${rating.toInt()} / 10"
                          : "${rating.toStringAsFixed(1)} / 10",
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      controller: commentController,
                      maxLines: 3,
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
                onPressed: saveReview,
                child: const Text(
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
