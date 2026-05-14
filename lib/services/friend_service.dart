import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/book_review.dart';
import '../models/user_profile.dart';

class FriendService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String get _myUid => _auth.currentUser!.uid;

  // ─── Search ────────────────────────────────────────────────────────────────

  /// Search for a user by exact username. Returns null if not found or is self.
  static Future<UserProfile?> searchByUsername(String username) async {
    final usernameDoc =
        await _firestore.collection('usernames').doc(username.trim()).get();
    if (!usernameDoc.exists) return null;

    final uid = usernameDoc.data()?['uid'] as String?;
    if (uid == null || uid == _myUid) return null;

    final userDoc = await _firestore.collection('users').doc(uid).get();
    if (!userDoc.exists) return null;

    return UserProfile.fromFirestore(uid, userDoc.data() ?? {});
  }

  // ─── Requests ──────────────────────────────────────────────────────────────

  /// Send a friend request. No-ops if a request already exists either way.
  static Future<void> sendRequest(UserProfile target) async {
    final myUid = _myUid;

    // Check both directions for an existing request.
    for (final query in [
      _firestore
          .collection('friendRequests')
          .where('fromUid', isEqualTo: myUid)
          .where('toUid', isEqualTo: target.uid),
      _firestore
          .collection('friendRequests')
          .where('fromUid', isEqualTo: target.uid)
          .where('toUid', isEqualTo: myUid),
    ]) {
      final snap = await query.limit(1).get();
      if (snap.docs.isNotEmpty) return;
    }

    final myDoc = await _firestore.collection('users').doc(myUid).get();
    final myUsername = myDoc.data()?['username'] as String?;

    await _firestore.collection('friendRequests').add({
      'fromUid': myUid,
      'toUid': target.uid,
      'fromUsername': myUsername,
      'toUsername': target.username,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Accept a pending friend request.
  static Future<void> acceptRequest(String requestId) async {
    await _firestore
        .collection('friendRequests')
        .doc(requestId)
        .update({'status': 'accepted'});
  }

  /// Create an instant, already-accepted friendship via QR code scan.
  ///
  /// Any existing request between the two users (in either direction, any
  /// status) is deleted first so there are no duplicate docs.  A fresh doc
  /// with status `accepted` is then created atomically in the same batch.
  static Future<void> acceptViaQr(UserProfile target) async {
    final myUid = _myUid;

    final batch = _firestore.batch();

    // Delete any existing request in EITHER direction.
    for (final query in [
      _firestore
          .collection('friendRequests')
          .where('fromUid', isEqualTo: myUid)
          .where('toUid', isEqualTo: target.uid),
      _firestore
          .collection('friendRequests')
          .where('fromUid', isEqualTo: target.uid)
          .where('toUid', isEqualTo: myUid),
    ]) {
      final snap = await query.get();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
    }

    final myDoc = await _firestore.collection('users').doc(myUid).get();
    final myUsername = myDoc.data()?['username'] as String?;

    // Create a single accepted friendship doc.
    final newRef = _firestore.collection('friendRequests').doc();
    batch.set(newRef, {
      'fromUid': myUid,
      'toUid': target.uid,
      'fromUsername': myUsername,
      'toUsername': target.username,
      'status': 'accepted',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Cancel, decline, or remove a friendship.
  static Future<void> deleteRequest(String requestId) async {
    await _firestore.collection('friendRequests').doc(requestId).delete();
  }

  // ─── Streams ───────────────────────────────────────────────────────────────

  /// Live stream of all requests sent by the current user.
  static Stream<QuerySnapshot<Map<String, dynamic>>> sentRequestsStream() =>
      _firestore
          .collection('friendRequests')
          .where('fromUid', isEqualTo: _myUid)
          .snapshots();

  /// Live stream of all requests received by the current user.
  static Stream<QuerySnapshot<Map<String, dynamic>>>
      receivedRequestsStream() =>
          _firestore
              .collection('friendRequests')
              .where('toUid', isEqualTo: _myUid)
              .snapshots();

  // ─── Status ────────────────────────────────────────────────────────────────

  /// Returns the friendship status and request doc id with another user.
  static Future<({FriendshipStatus status, String? requestId})>
      getFriendshipStatus(String otherUid) async {
    final myUid = _myUid;

    final sent = await _firestore
        .collection('friendRequests')
        .where('fromUid', isEqualTo: myUid)
        .where('toUid', isEqualTo: otherUid)
        .limit(1)
        .get();

    if (sent.docs.isNotEmpty) {
      final doc = sent.docs.first;
      final status = doc.data()['status'] == 'accepted'
          ? FriendshipStatus.accepted
          : FriendshipStatus.pendingSent;
      return (status: status, requestId: doc.id);
    }

    final received = await _firestore
        .collection('friendRequests')
        .where('fromUid', isEqualTo: otherUid)
        .where('toUid', isEqualTo: myUid)
        .limit(1)
        .get();

    if (received.docs.isNotEmpty) {
      final doc = received.docs.first;
      final status = doc.data()['status'] == 'accepted'
          ? FriendshipStatus.accepted
          : FriendshipStatus.pendingReceived;
      return (status: status, requestId: doc.id);
    }

    return (status: FriendshipStatus.none, requestId: null);
  }

  // ─── Data ──────────────────────────────────────────────────────────────────

  /// Fetch another user's full profile document.
  static Future<UserProfile?> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserProfile.fromFirestore(uid, doc.data() ?? {});
  }

  /// Fetch another user's reviews (caller must verify privacy level first).
  static Future<List<BookReview>> getFriendReviews(String uid) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('reviews')
        .orderBy('dateAdded')
        .get();
    return snapshot.docs
        .map((doc) => BookReview.fromJson(doc.data(), id: doc.id))
        .toList();
  }
}
