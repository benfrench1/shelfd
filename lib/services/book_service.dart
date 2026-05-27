import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/book.dart';
import '../models/book_review.dart';

class BookService {
  static const _legacyRecsCacheKey = 'recommendations_cache';
  static const _legacyRecsCacheTimeKey = 'recommendations_cache_time';
  static const _cacheValidityDays = 1;

  static String _recsCacheKey(String uid) => 'recommendations_cache_$uid';
  static String _recsCacheTimeKey(String uid) => 'recommendations_cache_time_$uid';

  static String? _currentUid() => FirebaseAuth.instance.currentUser?.uid;

  /// Checks if cached recommendations are still valid (within 24 hours)
  static Future<bool> _isCacheValid(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedTime = prefs.getInt(_recsCacheTimeKey(uid));
    if (cachedTime == null) return false;

    final now = DateTime.now().millisecondsSinceEpoch;
    final cacheAgeMs = now - cachedTime;
    final validityMs = _cacheValidityDays * 24 * 60 * 60 * 1000;

    return cacheAgeMs < validityMs;
  }

  /// Retrieves cached recommendations if available
  static Future<List<Book>?> _getCachedRecommendations(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_recsCacheKey(uid));
    if (cached == null) return null;

    try {
      final List<dynamic> jsonList = jsonDecode(cached);
      return jsonList.map((json) => Book.fromJson(json)).toList();
    } catch (_) {
      return null;
    }
  }

  /// Stores recommendations to cache
  static Future<void> _setCachedRecommendations(
    String uid,
    List<Book> recommendations,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = recommendations.map((book) => book.toJson()).toList();
    await prefs.setString(_recsCacheKey(uid), jsonEncode(jsonList));
    await prefs.setInt(
      _recsCacheTimeKey(uid),
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Cleans up old global cache keys from earlier versions.
  static Future<void> _clearLegacyRecommendationsCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacyRecsCacheKey);
    await prefs.remove(_legacyRecsCacheTimeKey);
  }

  /// Clears cached recommendations (call when new review is added)
  static Future<void> clearRecommendationsCache() async {
    final uid = _currentUid();
    if (uid == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recsCacheKey(uid));
    await prefs.remove(_recsCacheTimeKey(uid));
  }

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
          await http.get(url).timeout(const Duration(seconds: 10));

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
    final response = await http.get(url).timeout(const Duration(seconds: 10));
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

  /// Returns cached recommendations if fresh, otherwise fetches fresh and caches.
  /// Call this instead of getRecommendations() for better performance.
  static Future<List<Book>> getRecommendationsWithCache(
    List<BookReview> reviews,
  ) async {
    final uid = _currentUid();
    if (uid == null) {
      return getRecommendations(reviews);
    }

    // One-time cleanup of old unscoped cache keys.
    await _clearLegacyRecommendationsCache();

    // Return cached if valid
    final isValid = await _isCacheValid(uid);
    if (isValid) {
      final cached = await _getCachedRecommendations(uid);
      if (cached != null) {
        return cached;
      }
    }

    // Fetch fresh and cache
    final fresh = await getRecommendations(reviews);
    await _setCachedRecommendations(uid, fresh);
    return fresh;
  }
}

