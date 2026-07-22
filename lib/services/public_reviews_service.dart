import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
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
}
