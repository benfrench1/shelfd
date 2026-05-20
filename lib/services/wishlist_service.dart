import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/book.dart';

class WishlistService {
  static CollectionReference<Map<String, dynamic>> _wishlistCollection() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('wishlist');
  }

  static Future<List<Book>> getWishlist() async {
    final snapshot = await _wishlistCollection().orderBy('title').get();
    return snapshot.docs.map((doc) => Book.fromJson(doc.data())).toList();
  }

  static Future<void> addBook(Book book) async {
    final already = await isWishlisted(book);
    if (already) return;
    await _wishlistCollection().add(book.toJson());
  }

  static Future<void> removeBook(Book book) async {
    final snapshot = await _wishlistCollection()
        .where('title', isEqualTo: book.title)
        .where('author', isEqualTo: book.author)
        .get();
    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  static Future<bool> isWishlisted(Book book) async {
    final snapshot = await _wishlistCollection()
        .where('title', isEqualTo: book.title)
        .where('author', isEqualTo: book.author)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  static Future<void> removeByTitleAuthor(String title, String author) async {
    final snapshot = await _wishlistCollection()
        .where('title', isEqualTo: title)
        .where('author', isEqualTo: author)
        .get(const GetOptions(source: Source.cache));
    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }
}

