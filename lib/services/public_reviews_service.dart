import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/book.dart';
import '../models/book_review.dart';
import '../models/user_profile.dart';
import 'friend_service.dart';
import 'reaction_service.dart';

// ─── Public Entry ─────────────────────────────────────────────────────────────

/// A single review from any Shelfd user, bundled with their profile and
/// reaction state. Fields are intentionally mutable so the screen can update
/// them in-place after async loads.
class PublicEntry {
  final BookReview review;
  final String ownerUid;
  UserProfile? profile;
  int totalReactions;
  Map<String, int> reactionCounts;
  List<String> myReactions;

  PublicEntry({
    required this.review,
    required this.ownerUid,
    this.profile,
    this.totalReactions = 0,
    Map<String, int>? reactionCounts,
    List<String>? myReactions,
  })  : reactionCounts = reactionCounts ?? {},
        myReactions = myReactions ?? [];

  bool get isPrivate => profile?.privacyLevel == PrivacyLevel.private;
  String get displayName => profile?.displayName ?? 'Shelfd User';
}

// ─── Hardcover Review ────────────────────────────────────────────────────────

class HardcoverReview {
  final String? username;
  final String? displayName;
  final double? rating; // out of 5
  final String? reviewText;
  final int likedByCount;

  const HardcoverReview({
    this.username,
    this.displayName,
    this.rating,
    this.reviewText,
    this.likedByCount = 0,
  });
}

// ─── Public Reviews Service ──────────────────────────────────────────────────

class PublicReviewsService {
  static final _fs = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String get _myUid => _auth.currentUser!.uid;

  // ─────────────────────────────────────────────────────────────────────────
  // Shelfd reviews
  // ─────────────────────────────────────────────────────────────────────────

  /// Fetch all Shelfd reviews for [book] across every user, excluding the
  /// current user's own review.
  ///
  /// Uses a Firestore collection-group query on 'reviews'.
  ///
  /// ⚠ Requires Firestore rules:
  ///   match /{path=**}/reviews/{reviewId} {
  ///     allow read: if request.auth != null;
  ///   }
  /// And a Firestore single-field index exemption (or composite index) on
  /// collectionGroup('reviews') for 'workId' ascending.
  static Future<List<PublicEntry>> fetchForBook(Book book) async {
    // Deduplicate across both queries by document path.
    final seen = <String>{};
    final allDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

    // ── Query 1: by workId ────────────────────────────────────────────────
    // Precise match. Throws if the collection-group index on 'workId' is
    // missing (the caller surfaces the error with a link to create it).
    if (book.workId != null && book.workId!.isNotEmpty) {
      final snap = await _fs
          .collectionGroup('reviews')
          .where('workId', isEqualTo: book.workId)
          .get();
      for (final doc in snap.docs) {
        if (seen.add(doc.reference.path)) allDocs.add(doc);
      }
    }

    // ── Query 2: by title (fallback for reviews with null/missing workId) ──
    // Catches reviews saved before workId was reliably populated (e.g. older
    // reviews). Silently skipped if the collection-group index for 'title'
    // hasn't been created yet — a debug message explains what to do.
    //
    // To enable: Firebase Console → Firestore → Indexes → Single field →
    // Add exemption → collection "reviews", field "title",
    // scope "Collection group", Ascending ✓.
    try {
      final snap = await _fs
          .collectionGroup('reviews')
          .where('title', isEqualTo: book.title)
          .get();
      for (final doc in snap.docs) {
        // Author guard: skip docs whose author clearly differs to avoid
        // false-positive matches on books that happen to share a title.
        final docAuthor = (doc.data()['author'] as String? ?? '').toLowerCase();
        final bookAuthor = book.author.toLowerCase();
        if (bookAuthor.isNotEmpty &&
            docAuthor.isNotEmpty &&
            docAuthor != bookAuthor) {
          continue;
        }
        if (seen.add(doc.reference.path)) allDocs.add(doc);
      }
    } catch (e) {
      debugPrint(
        '[PublicReviews] title fallback skipped — to surface reviews saved '
        'without a workId, add a collection-group index exemption for field '
        '"title" on the "reviews" collection group: Firebase Console → '
        'Firestore → Indexes → Single field → Add exemption.\nError: $e',
      );
      // Only rethrow if we also have no workId results (nothing to show at all)
      if (allDocs.isEmpty && (book.workId == null || book.workId!.isEmpty)) {
        rethrow;
      }
    }

    final entries = <PublicEntry>[];
    final Set<String> uidsToFetch = {};

    for (final doc in allDocs) {
      // Extract ownerUid from path: users/{uid}/reviews/{reviewId}
      final segments = doc.reference.path.split('/');
      if (segments.length < 4) continue;
      final ownerUid = segments[1];

      // Skip the current user's own review
      if (ownerUid == _myUid) continue;

      final review = BookReview.fromJson(doc.data(), id: doc.id);
      entries.add(PublicEntry(review: review, ownerUid: ownerUid));
      uidsToFetch.add(ownerUid);
    }

    // Sort by date descending (newest first)
    entries.sort((a, b) => b.review.dateAdded.compareTo(a.review.dateAdded));

    // Batch-fetch user profiles
    if (uidsToFetch.isNotEmpty) {
      try {
        final profileFutures = uidsToFetch.map(
          (uid) => FriendService.getUserProfile(uid).then((p) => MapEntry(uid, p)),
        );
        final profileResults = await Future.wait(profileFutures);
        final profileMap = Map.fromEntries(profileResults);
        for (final entry in entries) {
          entry.profile = profileMap[entry.ownerUid];
        }
      } catch (_) {
        // Profiles unavailable — entries still show with fallback display name
      }
    }

    return entries;
  }

  /// Returns the set of UIDs of accepted friends for the current user.
  ///
  /// Uses single-field queries (no composite index needed) and filters
  /// status == 'accepted' on the client to avoid requiring extra Firestore indexes.
  static Future<Set<String>> getFriendUids() async {
    final myUid = _myUid;
    try {
      // Single-field queries — these use the same indexes as the existing
      // sentRequestsStream / receivedRequestsStream in FriendService.
      final results = await Future.wait([
        _fs
            .collection('friendRequests')
            .where('fromUid', isEqualTo: myUid)
            .get(),
        _fs
            .collection('friendRequests')
            .where('toUid', isEqualTo: myUid)
            .get(),
      ]);

      final uids = <String>{};
      for (final snap in results) {
        for (final doc in snap.docs) {
          // Filter accepted status client-side — no composite index required
          if (doc.data()['status'] != 'accepted') continue;
          final from = doc.data()['fromUid'] as String?;
          final to = doc.data()['toUid'] as String?;
          if (from != null && from != myUid) uids.add(from);
          if (to != null && to != myUid) uids.add(to);
        }
      }
      return uids;
    } catch (e) {
      debugPrint('[PublicReviews] getFriendUids error: $e');
      return {};
    }
  }

  /// Batch-loads reaction counts and current user's reactions into each entry
  /// in-place. Call this after [fetchForBook] to populate Tab 2 sort data.
  static Future<void> loadReactions(List<PublicEntry> entries) async {
    final withId = entries
        .where((e) => e.review.id != null && e.review.comment.isNotEmpty)
        .toList();
    if (withId.isEmpty) return;

    try {
      final results = await Future.wait(
        withId.map((e) => ReactionService.getReactions(e.ownerUid, e.review.id!)),
      );

      for (var i = 0; i < withId.length; i++) {
        final r = results[i];
        withId[i].reactionCounts = r.counts;
        withId[i].myReactions = r.mine;
        withId[i].totalReactions = r.counts.values.fold(0, (a, b) => a + b);
      }
    } catch (_) {
      // Reactions unavailable — silently ignore
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Hardcover reviews
  // ─────────────────────────────────────────────────────────────────────────

  /// Your Hardcover API token. Obtain a free token at:
  ///   https://hardcover.app/account/api
  /// Leave blank to disable the Hardcover fallback.
  static const String _kHardcoverToken = '';

  static const String _kHardcoverEndpoint =
      'https://api.hardcover.app/v1/graphql';

  /// Returns HardCover reviews for [book], or an empty list if unavailable
  /// (no token configured, network error, or book not found).
  static Future<List<HardcoverReview>> fetchHardcoverReviews(Book book) async {
    if (_kHardcoverToken.isEmpty) return [];

    // Step 1: find the book id by title
    final searchPayload = jsonEncode({
      'query': r'''
        query SearchBook($title: String!) {
          books(where: { title: { _ilike: $title } }, limit: 1) {
            id
            title
          }
        }
      ''',
      'variables': {'title': book.title},
    });

    try {
      final searchResp = await http
          .post(
            Uri.parse(_kHardcoverEndpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_kHardcoverToken',
            },
            body: searchPayload,
          )
          .timeout(const Duration(seconds: 10));

      if (searchResp.statusCode != 200) return [];

      final searchData = jsonDecode(searchResp.body) as Map<String, dynamic>;
      final books = (searchData['data']?['books'] as List<dynamic>?) ?? [];
      if (books.isEmpty) return [];
      final bookId = books.first['id'];

      // Step 2: fetch reviews for that book id
      final reviewPayload = jsonEncode({
        'query': r'''
          query BookReviews($bookId: Int!) {
            books(where: { id: { _eq: $bookId } }, limit: 1) {
              user_books(
                where: {
                  rating: { _is_null: false }
                }
                order_by: { liked_by_count: desc }
                limit: 50
              ) {
                rating
                review
                liked_by_count
                user {
                  username
                  name
                }
              }
            }
          }
        ''',
        'variables': {'bookId': bookId},
      });

      final reviewResp = await http
          .post(
            Uri.parse(_kHardcoverEndpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_kHardcoverToken',
            },
            body: reviewPayload,
          )
          .timeout(const Duration(seconds: 10));

      if (reviewResp.statusCode != 200) return [];

      final reviewData = jsonDecode(reviewResp.body) as Map<String, dynamic>;
      final booksResult =
          (reviewData['data']?['books'] as List<dynamic>?) ?? [];
      if (booksResult.isEmpty) return [];

      final userBooks =
          (booksResult.first['user_books'] as List<dynamic>?) ?? [];

      return userBooks.map((ub) {
        final user = ub['user'] as Map<String, dynamic>?;
        final rawRating = ub['rating'];
        return HardcoverReview(
          username: user?['username'] as String?,
          displayName: (user?['name'] as String?)?.isNotEmpty == true
              ? user!['name'] as String
              : user?['username'] as String?,
          rating: rawRating != null ? (rawRating as num).toDouble() : null,
          reviewText: ub['review'] as String?,
          likedByCount: (ub['liked_by_count'] as num?)?.toInt() ?? 0,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Returns true if a Hardcover token is configured.
  static bool get hardcoverEnabled => _kHardcoverToken.isNotEmpty;
}
