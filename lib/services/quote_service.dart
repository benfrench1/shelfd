import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class DailyQuote {
  final String text;
  final String author;

  const DailyQuote({required this.text, required this.author});
}

class QuoteService {
  static const _quoteKey = 'quote_text';
  static const _authorKey = 'quote_author';
  static const _dateKey = 'quote_date';

  // Fallback literary quotes shown when the API is unavailable
  static const List<DailyQuote> _fallbacks = [
    DailyQuote(
      text: "Not all those who wander are lost.",
      author: "J.R.R. Tolkien",
    ),
    DailyQuote(
      text: "It is a truth universally acknowledged, that a single man in possession of a good fortune, must be in want of a wife.",
      author: "Jane Austen",
    ),
    DailyQuote(
      text: "So it goes.",
      author: "Kurt Vonnegut",
    ),
    DailyQuote(
      text: "Until I feared I would lose it, I never loved to read. One does not love breathing.",
      author: "Harper Lee",
    ),
    DailyQuote(
      text: "The more that you read, the more things you will know.",
      author: "Dr. Seuss",
    ),
  ];

  /// Returns today's quote — fetched from ZenQuotes or cached locally.
  static Future<DailyQuote> getQuoteOfTheDay() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final cachedDate = prefs.getString(_dateKey);

    // Return cache if it's still today's quote
    if (cachedDate == today) {
      final text = prefs.getString(_quoteKey);
      final author = prefs.getString(_authorKey);
      if (text != null && author != null) {
        return DailyQuote(text: text, author: author);
      }
    }

    // Fetch from ZenQuotes
    try {
      final response = await http
          .get(Uri.parse("https://zenquotes.io/api/today"))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          final text = data[0]['q'] as String;
          final author = data[0]['a'] as String;

          await prefs.setString(_quoteKey, text);
          await prefs.setString(_authorKey, author);
          await prefs.setString(_dateKey, today);

          return DailyQuote(text: text, author: author);
        }
      }
    } catch (_) {
      // Fall through to fallback
    }

    // Use a deterministic fallback based on day-of-year
    final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year)).inDays;
    return _fallbacks[dayOfYear % _fallbacks.length];
  }
}
