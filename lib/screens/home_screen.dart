import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../accessibility/accessibility_labels.dart';
import '../theme/app_theme.dart';
import '../models/book.dart';
import '../models/book_review.dart';
import '../models/literary_quiz_question.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../services/book_service.dart';
import '../services/literary_quiz_service.dart';
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
  int _quoteTapCount = 0;
  DateTime? _firstQuoteTapTime;

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
    // Load quote independently so it is not blocked by recommendation refresh.
    final quoteFuture = QuoteService.getQuoteOfTheDay();
    quoteFuture.then((quote) {
      if (!mounted) return;
      setState(() {
        _quote = quote;
        _loadingQuote = false;
      });
    });

    final all = await StorageService.getReviews();
    final sorted = List<BookReview>.from(all)
      ..sort((a, b) => b.dateAdded.compareTo(a.dateAdded));

    setState(() {
      _recentReviews = sorted.take(5).toList();
    });

    final recs = await BookService.getRecommendationsWithCache(all);

    if (mounted) {
      setState(() {
        _recommendations = recs;
        _loadingRecs = false;
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
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                isAlready ? Icons.bookmark_remove_outlined : Icons.bookmark_add_outlined,
                color: isAlready ? Colors.red : Colors.deepOrange,
              ),
              title: Text(isAlready ? 'Remove from Future Reads' : 'Add to Future Reads'),
              subtitle: Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(sheetContext);
                if (isAlready) {
                  await WishlistService.removeBook(book);
                  if (mounted) {
                    messenger
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(
                          content: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bookmark_remove, color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Flexible(child: Text('Removed from Future Reads')),
                            ],
                          ),
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          margin: const EdgeInsets.all(16),
                        ),
                      );
                  }
                } else {
                  await WishlistService.addBook(book);
                  if (mounted) {
                    messenger
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(
                          content: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bookmark_added, color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Flexible(child: Text('Added to Future Reads')),
                            ],
                          ),
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          margin: const EdgeInsets.all(16),
                        ),
                      );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleQuoteTap() async {
    final now = DateTime.now();
    if (_firstQuoteTapTime == null ||
        now.difference(_firstQuoteTapTime!).inMilliseconds > 1500) {
      _quoteTapCount = 1;
      _firstQuoteTapTime = now;
      return;
    }

    _quoteTapCount++;
    if (_quoteTapCount < 5) {
      return;
    }

    _quoteTapCount = 0;
    _firstQuoteTapTime = null;

    final alreadyDone = await LiteraryQuizService.isQuizCompletedToday();
    if (!mounted) return;

    if (alreadyDone) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text("That's the secret quiz done :)... for today"),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      return;
    }

    final shouldStart = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Text('Secret Quiz'),
        content: const Text(
          'Would you like to partake in today\'s literature quiz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('No thanks'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text("Let's try it!"),
          ),
        ],
      ),
    );

    if (shouldStart != true || !mounted) {
      return;
    }

    final score = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _LiteraryQuizDialog(
        questions: LiteraryQuizService.getQuizForToday(),
      ),
    );

    if (score == null || !mounted) {
      return;
    }

    await LiteraryQuizService.markQuizCompletedToday();
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Text('Quiz Complete'),
        content: Text('You scored $score out of 5.'),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Nice'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = ShelfdThemeScope.colorsOf(context);
    return Scaffold(
      backgroundColor: c.scaffoldBg,

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
                ],
              ),

              const SizedBox(height: 20),


              Semantics(
                header: true,
                child: Text(
                  "Your Reading Dashboard",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Search bar — tapping jumps to Search tab
              Semantics(
                button: true,
                label: 'Open search',
                hint: 'Search books, authors, or genres',
                child: GestureDetector(
                  onTap: () {
                    widget.onNavigate(1);
                    widget.onSearchTapped?.call();
                  },
                  child: ExcludeSemantics(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: c.cardBg,
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
                ),
              ),

              const SizedBox(height: 28),

              // ── Recently Rated ──────────────────────────────────────
              Semantics(
                header: true,
                child: Text(
                  "Recently Rated",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              _recentReviews.isEmpty
                  ? _emptyCard("Nothing recently rated.")
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final textScale = MediaQuery.of(context).textScaleFactor;
                        final containerHeight = textScale > 1.5 ? 300.0 : (textScale > 1.2 ? 260.0 : 240.0);
                        return SizedBox(
                          height: containerHeight,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _recentReviews.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final review = _recentReviews[index];
                          final url = _coverUrl(review.coverId);

                          return Semantics(
                            container: true,
                            label: bookSemanticLabel(
                              title: review.title,
                              author: review.author,
                              year: review.year,
                              rating: review.rating,
                              isFavourite: review.isFavourite,
                            ),
                            child: ExcludeSemantics(
                              child: _bookCard(
                                title: review.title,
                                subtitle: review.author,
                                footer:
                                    "${review.rating % 1 == 0 ? review.rating.toInt() : review.rating.toStringAsFixed(1)}/10 ⭐",
                                coverUrl: url,
                                isFavourite: review.isFavourite,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                      },
                    ),

              const SizedBox(height: 28),

              // ── Recommended for You ────────────────────────────────
              Semantics(
                header: true,
                child: Text(
                  "Recommended for You",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
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
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final textScale = MediaQuery.of(context).textScaleFactor;
                            final containerHeight = textScale > 1.5 ? 300.0 : (textScale > 1.2 ? 260.0 : 240.0);
                            return SizedBox(
                              height: containerHeight,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _recommendations.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 12),
                            itemBuilder: (context, index) {
                              final book = _recommendations[index];
                              final url = _coverUrl(book.coverId);

                              return Semantics(
                                container: true,
                                label: bookSemanticLabel(
                                  title: book.title,
                                  author: book.author,
                                  year: book.year,
                                ),
                                hint: 'Long press to add this book to Future Reads',
                                child: ExcludeSemantics(
                                  child: GestureDetector(
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
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                          },
                        ),

              const SizedBox(height: 28),

              // ── Quote of the Day ───────────────────────────────────
              Semantics(
                header: true,
                child: Text(
                  "Quote of the Day",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              _loadingQuote
                  ? const SizedBox(
                      height: 60,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : Semantics(
                      container: true,
                      label: 'Quote of the day. ${_quote!.text}. By ${_quote!.author}.',
                      child: GestureDetector(
                        onTap: _handleQuoteTap,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: c.quoteBoxBg,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ExcludeSemantics(
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
                                  '— ${_quote!.author}',
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

              const SizedBox(height: 28),

              // Discover button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.primaryAccent,
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final c = ShelfdThemeScope.colorsOf(context);
        // Adjust card width and text wrapping based on text scale factor
        final textScale = MediaQuery.of(context).textScaleFactor;
        final isLargeText = textScale > 1.5;
        final cardWidth = isLargeText ? 240.0 : (textScale > 1.2 ? 190.0 : 150.0);
        final titleMaxLines = isLargeText ? 2 : 2;
        final subtitleMaxLines = 1;
        final coverHeight = isLargeText ? 100.0 : 120.0;

        // Reduce padding at high text scales to save space
        final padding = isLargeText ? 6.0 : 10.0;

        return Container(
          width: cardWidth,
          decoration: BoxDecoration(
            color: isFavourite
                ? Colors.amber.withValues(alpha: 0.15)
                : c.cardBg,
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
                        height: coverHeight,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        excludeFromSemantics: true,
                        errorBuilder: (_, __, ___) => Container(
                              height: coverHeight,
                              width: double.infinity,
                                color: c.subtleBg,
                                child: const Center(
                                  child: Icon(Icons.book, size: 40, color: Colors.grey),
                                ),
                              ),
                          )
                        : Container(
                            height: coverHeight,
                            width: double.infinity,
                            color: c.subtleBg,
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
                    padding: EdgeInsets.all(padding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: titleMaxLines,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: subtitleMaxLines,
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
      },
    );
  }

  Widget _emptyCard(String message) {
    return Builder(builder: (context) {
      final c = ShelfdThemeScope.colorsOf(context);
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: c.cardBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          message,
          style: TextStyle(
            color: c.textMuted,
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
      );
    });
  }
}

class _LiteraryQuizDialog extends StatefulWidget {
  final List<LiteraryQuizQuestion> questions;

  const _LiteraryQuizDialog({required this.questions});

  @override
  State<_LiteraryQuizDialog> createState() => _LiteraryQuizDialogState();
}

class _LiteraryQuizDialogState extends State<_LiteraryQuizDialog> {
  int _questionIndex = 0;
  int _score = 0;
  int? _selectedIndex;
  bool _answered = false;

  LiteraryQuizQuestion get _currentQuestion => widget.questions[_questionIndex];

  void _answerQuestion(int index) {
    if (_answered) return;

    setState(() {
      _selectedIndex = index;
      _answered = true;
      if (index == _currentQuestion.correctIndex) {
        _score++;
      }
    });
  }

  void _goNext() {
    if (_questionIndex == widget.questions.length - 1) {
      Navigator.of(context).pop(_score);
      return;
    }

    setState(() {
      _questionIndex++;
      _selectedIndex = null;
      _answered = false;
    });
  }

  Color? _optionColor(int index) {
    if (!_answered) return null;
    if (index == _currentQuestion.correctIndex) {
      return Colors.green.shade100;
    }
    if (index == _selectedIndex) {
      return Colors.red.shade100;
    }
    return null;
  }

  Color? _optionBorderColor(int index) {
    if (!_answered) return Colors.grey.shade300;
    if (index == _currentQuestion.correctIndex) {
      return Colors.green;
    }
    if (index == _selectedIndex) {
      return Colors.red;
    }
    return Colors.grey.shade300;
  }

  @override
  Widget build(BuildContext context) {
    final c = ShelfdThemeScope.colorsOf(context);
    final maxContentHeight = MediaQuery.of(context).size.height * 0.55;

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Text('Literary Quiz ${_questionIndex + 1}/5'),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxContentHeight),
        child: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentQuestion.question,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                ...List.generate(_currentQuestion.options.length, (index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _answerQuestion(index),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: _optionColor(index),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _optionBorderColor(index)!,
                            width: 1.5,
                          ),
                        ),
                        child: Text(_currentQuestion.options[index]),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Exit Quiz'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: c.primaryAccent,
            foregroundColor: Colors.white,
          ),
          onPressed: _answered ? _goNext : null,
          child: Text(_questionIndex == widget.questions.length - 1 ? 'Finish' : 'Next'),
        ),
      ],
    );
  }
}
