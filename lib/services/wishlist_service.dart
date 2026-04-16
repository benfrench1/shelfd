import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/book.dart';

class WishlistService {
  static const String _key = "future_reads";

  static Future<List<Book>> getWishlist() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key);
    if (json == null) return [];
    final List decoded = jsonDecode(json);
    return decoded.map((j) => Book.fromJson(j)).toList();
  }

  static Future<void> addBook(Book book) async {
    final list = await getWishlist();
    final alreadyAdded = list.any(
      (b) => b.title.toLowerCase() == book.title.toLowerCase() &&
          b.author.toLowerCase() == book.author.toLowerCase(),
    );
    if (alreadyAdded) return;
    list.add(book);
    await _save(list);
  }

  static Future<void> removeBook(Book book) async {
    final list = await getWishlist();
    list.removeWhere(
      (b) => b.title.toLowerCase() == book.title.toLowerCase() &&
          b.author.toLowerCase() == book.author.toLowerCase(),
    );
    await _save(list);
  }

  static Future<bool> isWishlisted(Book book) async {
    final list = await getWishlist();
    return list.any(
      (b) => b.title.toLowerCase() == book.title.toLowerCase() &&
          b.author.toLowerCase() == book.author.toLowerCase(),
    );
  }

  static Future<void> removeByTitleAuthor(
      String title, String author) async {
    final list = await getWishlist();
    list.removeWhere(
      (b) => b.title.toLowerCase() == title.toLowerCase() &&
          b.author.toLowerCase() == author.toLowerCase(),
    );
    await _save(list);
  }

  static Future<void> _save(List<Book> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(list.map((b) => b.toJson()).toList()),
    );
  }
}
