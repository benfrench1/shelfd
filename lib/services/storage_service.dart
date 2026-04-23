import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/book_review.dart';
import 'wishlist_service.dart';

class StorageService {
  static CollectionReference<Map<String, dynamic>> _reviewsCollection() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('reviews');
  }

  static Future<void> saveReview(BookReview review) async {
    await _reviewsCollection().add(review.toJson());
    await WishlistService.removeByTitleAuthor(review.title, review.author);
  }

  static Future<void> updateReview(int index, BookReview review) async {
    final snapshot = await _reviewsCollection()
        .orderBy('dateAdded')
        .get();
    if (index < snapshot.docs.length) {
      await snapshot.docs[index].reference.update(review.toJson());
    }
    await WishlistService.removeByTitleAuthor(review.title, review.author);
  }

  static Future<List<BookReview>> getReviews() async {
    final snapshot = await _reviewsCollection()
        .orderBy('dateAdded')
        .get();
    return snapshot.docs
        .map((doc) => BookReview.fromJson(doc.data()))
        .toList();
  }

  static Future<int?> findReviewIndex(String title, String author) async {
    final reviews = await getReviews();
    for (int i = 0; i < reviews.length; i++) {
      if (reviews[i].title == title && reviews[i].author == author) {
        return i;
      }
    }
    return null;
  }

  static Future<void> deleteReview(String title, String author) async {
    final snapshot = await _reviewsCollection()
        .where('title', isEqualTo: title)
        .where('author', isEqualTo: author)
        .get();
    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }
}

