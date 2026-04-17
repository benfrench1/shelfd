import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/book_review.dart';
import '../services/storage_service.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  List<BookReview> reviews = [];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final data = await StorageService.getReviews();

    setState(() {
      reviews = data;
    });
  }

  int get totalCompleted => reviews.length;

  int get totalPhysical =>
      reviews.where((r) => r.format == BookFormat.physical).length;

  int get totalAudiobook =>
      reviews.where((r) => r.format == BookFormat.audiobook).length;

  int get totalBraille =>
      reviews.where((r) => r.format == BookFormat.braille).length;

  List<MapEntry<String, int>> get topAuthors {
    final Map<String, int> counts = {};

    for (final r in reviews) {
      counts[r.author] = (counts[r.author] ?? 0) + 1;
    }

    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(5).toList();
  }

  List<BookReview> get topRated {
    final sorted = List<BookReview>.from(reviews)
      ..sort((a, b) => b.rating.compareTo(a.rating));

    return sorted.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
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
                  const Icon(Icons.bar_chart, size: 28),
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
                      'Your Reading Stats',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 19,
                      ),
                    ),
                  ),
                  const SizedBox(width: 96),
                ],
              ),
            ),

            // Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

            // TOTAL COMPLETED
            Card(
              child: ListTile(
                leading: const Icon(Icons.library_books),
                title: const Text("Total Books Completed"),
                trailing: Text(
                  totalCompleted.toString(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // FORMAT BREAKDOWN (smaller cards)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 3),
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.menu_book, size: 20),
                title: const Text(
                  "Total Books Read",
                  style: TextStyle(fontSize: 13),
                ),
                trailing: Text(
                  totalPhysical.toString(),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            Card(
              margin: const EdgeInsets.symmetric(vertical: 3),
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.headphones, size: 20),
                title: const Text(
                  "Total Books Listened To",
                  style: TextStyle(fontSize: 13),
                ),
                trailing: Text(
                  totalAudiobook.toString(),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            Card(
              margin: const EdgeInsets.symmetric(vertical: 3),
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.grain, size: 20),
                title: const Text(
                  "Total Books Read Braille",
                  style: TextStyle(fontSize: 13),
                ),
                trailing: Text(
                  totalBraille.toString(),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // TOP AUTHORS
            const Text(
              "Top Authors",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            ...topAuthors.map((a) => Card(
                  child: ListTile(
                    title: Text(a.key),
                    trailing: Text("${a.value} books"),
                  ),
                )),

            const SizedBox(height: 20),

            // TOP RATED BOOKS
            const Text(
              "Top Rated Books",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            ...topRated.map((r) => Card(
                          color: r.isFavourite
                              ? Colors.amber.withOpacity(0.15)
                              : null,
                          child: ListTile(
                            title: Text(r.title),
                            subtitle: Text(r.author),
                            trailing: Text(
                              "${r.rating.toStringAsFixed(1)} ⭐",
                            ),
                          ),
                        )),
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
