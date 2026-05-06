import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReactionService {
  static final _fs = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String get _myUid => _auth.currentUser!.uid;

  static CollectionReference<Map<String, dynamic>> _ref(
          String ownerUid, String reviewId) =>
      _fs
          .collection('users')
          .doc(ownerUid)
          .collection('reviews')
          .doc(reviewId)
          .collection('reactions');

  /// Load all reactions for a review.
  /// Returns aggregate emoji counts and the current user's selected emojis.
  static Future<({Map<String, int> counts, List<String> mine})> getReactions(
      String ownerUid, String reviewId) async {
    final snap = await _ref(ownerUid, reviewId).get();
    final counts = <String, int>{};
    var mine = <String>[];
    for (final doc in snap.docs) {
      final emojis = List<String>.from(doc.data()['emojis'] ?? []);
      if (doc.id == _myUid) mine = emojis;
      for (final e in emojis) {
        counts[e] = (counts[e] ?? 0) + 1;
      }
    }
    return (counts: counts, mine: mine);
  }

  /// Toggle an emoji reaction (add or remove). Returns the updated state.
  /// A user may have at most 3 different emojis per review.
  static Future<({Map<String, int> counts, List<String> mine})> toggleReaction(
      String ownerUid,
      String reviewId,
      String emoji,
      List<String> currentMine) async {
    final ref = _ref(ownerUid, reviewId).doc(_myUid);
    final List<String> newMine;

    if (currentMine.contains(emoji)) {
      // Remove this emoji
      newMine = List.from(currentMine)..remove(emoji);
    } else {
      // At max — return unchanged
      if (currentMine.length >= 3) {
        return await getReactions(ownerUid, reviewId);
      }
      newMine = List.from(currentMine)..add(emoji);
    }

    if (newMine.isEmpty) {
      await ref.delete();
    } else {
      await ref.set({
        'emojis': newMine,
        'reactorUid': _myUid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    return await getReactions(ownerUid, reviewId);
  }
}
