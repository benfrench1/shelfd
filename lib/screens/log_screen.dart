import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/book_review.dart';
import '../models/book.dart';
import '../services/storage_service.dart';
import 'review_screen.dart';

class LogScreen extends StatefulWidget {
  const LogScreen({super.key});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  List<BookReview> reviews = [];
  String sortOption = 'date';

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
  }

  void sortReviews() {
    if (sortOption == 'alphabetical') {
      reviews.sort((a, b) => a.title.compareTo(b.title));
    } else if (sortOption == 'rating') {
      reviews.sort((b, a) => a.rating.compareTo(b.rating));
    } else {
      reviews.sort((b, a) => a.dateAdded.compareTo(b.dateAdded));
    }
  }

  Future<void> deleteReview(BookReview review) async {
    final index = await StorageService.findReviewIndex(
      review.title,
      review.author,
    );

    if (index == null) return;

    final current = await StorageService.getReviews();
    current.removeAt(index);

    await StorageService.saveAllReviews(current);
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
              Text("${review.rating.toStringAsFixed(1)} ⭐"),
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
                    Text(review.comment)
                  else
                    const Text(
                      "No review written",
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                ],
              ),
            )
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
                        fontSize: 22,
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
                    ],
                  ),
                ],
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
                        }),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
