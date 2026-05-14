import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Manages the random, non-guessable friend codes used for QR-based friend
/// adding. The code itself is URL-safe and contains no personally identifiable
/// information — it is only a random token that maps to a UID in Firestore.
class FriendCodeService {
  FriendCodeService._();

  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  // 20 lowercase alphanumeric chars (base-36) ≈ 103 bits of entropy.
  static const _chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  static final _rng = Random.secure();

  static String _generate() =>
      List.generate(20, (_) => _chars[_rng.nextInt(_chars.length)]).join();

  /// Returns the current user's friend code, creating and persisting one if it
  /// does not yet exist. Safe to call multiple times — idempotent.
  static Future<String> getOrCreateCode() async {
    final uid = _auth.currentUser!.uid;

    final userDoc = await _firestore.collection('users').doc(uid).get();
    final existing = userDoc.data()?['friendCode'] as String?;
    if (existing != null && existing.isNotEmpty) return existing;

    final code = _generate();

    // Atomically write the code onto the user document AND into the lookup
    // index so that uidFromCode() can resolve it without querying the full
    // users collection.
    final batch = _firestore.batch();
    batch.update(
      _firestore.collection('users').doc(uid),
      {'friendCode': code},
    );
    batch.set(
      _firestore.collection('friendCodes').doc(code),
      {'uid': uid},
    );
    await batch.commit();

    return code;
  }

  /// Resolves a friend code to the owning user's UID.
  /// Returns null if the code does not exist.
  static Future<String?> uidFromCode(String code) async {
    final doc = await _firestore
        .collection('friendCodes')
        .doc(code.toLowerCase())
        .get();
    return doc.data()?['uid'] as String?;
  }

  /// The deep-link URI that is embedded in the user's QR code.
  /// Format: shelfd://friend/{code}
  static String deepLinkForCode(String code) => 'shelfd://friend/$code';
}
