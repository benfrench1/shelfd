import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/book.dart';
import '../models/book_review.dart';

class BookService {
  static Future<List<Book>>
      searchBooks(String query) async {
    if (query.isEmpty) {
      return [];
    }

    final attempts = [
      query,
      "$query*",
      query.split(" ").last,
    ];

    for (final attempt in attempts) {
      final url =
          Uri.parse(
              "https://openlibrary.org/search.json?q=$attempt");

      final response =
          await http.get(url);

      if (response.statusCode ==
          200) {
        final data =
            jsonDecode(
                response.body);

        final docs =
            data['docs'] as List;

        if (docs.isNotEmpty) {
          return docs
              .take(20)
              .map((json) =>
                  Book.fromJson(
                      json))
              .toList();
        }
      }
    }

    return [];
  }

  /// Looks up a single book by ISBN (ISBN-10 or ISBN-13).
  /// Uses OpenLibrary's ISBN-specific search endpoint for more accurate results.
  static Future<List<Book>> searchByIsbn(String isbn) async {
    final url = Uri.parse(
        'https://openlibrary.org/search.json?isbn=$isbn');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final docs = data['docs'] as List;
      if (docs.isNotEmpty) {
        return docs.take(5).map((json) => Book.fromJson(json)).toList();
      }
    }
    return [];
  }

  /// Returns up to 5 recommended books based on the user's reading log.
  /// Searches OpenLibrary for books by the user's most-read authors and
  /// filters out titles already in the log.
  static Future<List<Book>> getRecommendations(
    List<BookReview> reviews,
  ) async {
    if (reviews.isEmpty) return [];

    // Count reads per author and pick top 2
    final Map<String, int> authorCounts = {};
    for (final r in reviews) {
      authorCounts[r.author] = (authorCounts[r.author] ?? 0) + 1;
    }
    final topAuthors = (authorCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(2)
        .map((e) => e.key)
        .toList();

    final readTitles = reviews.map((r) => r.title.toLowerCase()).toSet();
    final List<Book> results = [];
    final seenTitles = <String>{};

    for (final author in topAuthors) {
      try {
        final url = Uri.parse(
          "https://openlibrary.org/search.json?author=${Uri.encodeComponent(author)}&limit=20",
        );
        final response = await http.get(url);
        if (response.statusCode != 200) continue;

        final docs = (jsonDecode(response.body)['docs'] as List)
            .map((j) => Book.fromJson(j))
            .where((b) =>
                b.title.isNotEmpty &&
                !readTitles.contains(b.title.toLowerCase()) &&
                !seenTitles.contains(b.title.toLowerCase()))
            .toList();

        // Sort by popularity (edition count)
        docs.sort((a, b) =>
            (b.editionCount ?? 0).compareTo(a.editionCount ?? 0));

        for (final book in docs.take(3)) {
          seenTitles.add(book.title.toLowerCase());
          results.add(book);
        }
      } catch (_) {
        continue;
      }
    }

    return results.take(5).toList();
  }
}
