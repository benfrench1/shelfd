import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/book_review.dart';
import 'wishlist_service.dart';

class StorageService {
  static const String key =
      "book_reviews";

  static Future<void> saveReview(
      BookReview review) async {
    final prefs =
        await SharedPreferences
            .getInstance();

    final reviews =
        await getReviews();

    reviews.add(review);

    await saveAllReviews(reviews);
    await WishlistService.removeByTitleAuthor(review.title, review.author);
  }

  static Future<void> updateReview(
      int index,
      BookReview review) async {
    final reviews =
        await getReviews();

    reviews[index] = review;
    await WishlistService.removeByTitleAuthor(review.title, review.author);

    await saveAllReviews(reviews);
  }

  static Future<void> saveAllReviews(
      List<BookReview> reviews) async {
    final prefs =
        await SharedPreferences
            .getInstance();

    final jsonList =
        reviews
            .map((r) => r.toJson())
            .toList();

    await prefs.setString(
      key,
      jsonEncode(jsonList),
    );
  }

  static Future<List<BookReview>>
      getReviews() async {
    final prefs =
        await SharedPreferences
            .getInstance();

    final jsonString =
        prefs.getString(key);

    if (jsonString == null) {
      return [];
    }

    final List decoded =
        jsonDecode(jsonString);

    return decoded
        .map((json) =>
            BookReview.fromJson(json))
        .toList();
  }

  static Future<int?> findReviewIndex(
      String title,
      String author) async {
    final reviews =
        await getReviews();

    for (int i = 0;
        i < reviews.length;
        i++) {
      final r = reviews[i];

      if (r.title == title &&
          r.author == author) {
        return i;
      }
    }

    return null;
  }
}
