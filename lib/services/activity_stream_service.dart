import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ActivityStreamService {
  static final _fs = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String get _myUid => _auth.currentUser!.uid;

  static CollectionReference<Map<String, dynamic>> _col(String ownerUid) =>
      _fs.collection('users').doc(ownerUid).collection('activityStream');

  // ─── Write ──────────────────────────────────────────────────────────────

  /// Called after every reaction toggle. Upserts (or deletes) one activity
  /// doc per reactor+review pair in the review owner's activityStream.
  ///
  /// [emojis] is the reactor's current full emoji list after the toggle.
  /// Pass an empty list to delete the activity entry (all emojis removed).
  static Future<void> upsertReactionActivity({
    required String ownerUid,
    required String reviewId,
    required String bookTitle,
    required List<String> emojis,
    bool isFriend = false,
  }) async {
    final myUid = _myUid;
    // Don't create activity for your own reviews.
    if (myUid == ownerUid) return;

    final docId = '${myUid}_$reviewId';
    final ref = _col(ownerUid).doc(docId);

    if (emojis.isEmpty) {
      await ref.delete();
      return;
    }

    // Fetch reactor's own profile for display denormalization.
    final myDoc = await _fs.collection('users').doc(myUid).get();
    final data = myDoc.data() ?? {};
    final reactorUsername = data['username'] as String?;
    final reactorAvatarAsset = data['avatarAsset'] as String?;
    final reactorPhotoUrl = data['photoUrl'] as String?;
    final reactorIsPrivate = (data['privacyLevel'] as String?) == 'private';

    await ref.set({
      'type': 'reaction',
      'reviewId': reviewId,
      'bookTitle': bookTitle,
      'reactorUid': myUid,
      'reactorUsername': reactorUsername,
      'reactorAvatarAsset': reactorAvatarAsset,
      'reactorPhotoUrl': reactorPhotoUrl,
      'reactorIsPrivate': reactorIsPrivate,
      'reactorIsFriend': isFriend,
      'emojis': emojis,
      'timestamp': FieldValue.serverTimestamp(),
      'seen': false,
    });
  }

  // ─── Read ───────────────────────────────────────────────────────────────

  /// Live stream of the 20 most recent activity docs for [ownerUid].
  static Stream<QuerySnapshot<Map<String, dynamic>>> stream(String ownerUid) =>
      _col(ownerUid)
          .orderBy('timestamp', descending: true)
          .limit(20)
          .snapshots();

  /// Stream of the unseen activity count (for badge display).
  static Stream<int> unseenCountStream(String ownerUid) => _col(ownerUid)
      .where('seen', isEqualTo: false)
      .snapshots()
      .map((s) => s.docs.length);

  // ─── Mark seen ──────────────────────────────────────────────────────────

  /// Marks all unseen activity docs as seen for [ownerUid].
  static Future<void> markAllSeen(String ownerUid) async {
    final snap =
        await _col(ownerUid).where('seen', isEqualTo: false).get();
    if (snap.docs.isEmpty) return;
    final batch = _fs.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'seen': true});
    }
    await batch.commit();
  }
}
