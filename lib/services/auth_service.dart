import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_profile.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signIn(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    if (credential.user != null && !credential.user!.emailVerified) {
      await _auth.signOut();
      throw FirebaseAuthException(code: 'email-not-verified');
    }
    return credential;
  }

  Future<void> register(String email, String password) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await credential.user?.sendEmailVerification();
    await _auth.signOut();
  }

  Future<void> signOut() async {
    final isGoogleUser = _auth.currentUser?.providerData
            .any((p) => p.providerId == 'google.com') ??
        false;
    if (isGoogleUser) {
      await _googleSignIn.signOut();
    }
    await _auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> saveAvatarAsset(String assetPath) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _firestore
        .collection('users')
        .doc(uid)
        .set({'avatarAsset': assetPath}, SetOptions(merge: true));
  }

  Future<String?> getAvatarAsset() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data()?['avatarAsset'] as String?;
  }

  Stream<String?> get avatarAssetStream {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.data()?['avatarAsset'] as String?);
  }

  Future<String?> getUsername() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data()?['username'] as String?;
  }

  /// Saves a username atomically.
  /// Throws [UsernameUnavailableException] if already taken by another user.
  /// Throws [ProfanityException] if the username contains blocked language.
  /// Pass an empty string to clear the username.
  Future<void> saveUsername(String username) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw FirebaseAuthException(code: 'no-user');

    final trimmed = username.trim();

    if (trimmed.isNotEmpty && _containsProfanity(trimmed)) {
      throw const ProfanityException();
    }
    // Fetch the current username so we can release the old reservation
    final userDoc = await _firestore.collection('users').doc(uid).get();
    final oldUsername = userDoc.data()?['username'] as String?;

    if (trimmed.isEmpty) {
      // Clearing the username
      await _firestore.runTransaction((tx) async {
        if (oldUsername != null && oldUsername.isNotEmpty) {
          tx.delete(_firestore.collection('usernames').doc(oldUsername));
        }
        tx.update(_firestore.collection('users').doc(uid),
            {'username': FieldValue.delete()});
      });
      return;
    }

    if (trimmed == oldUsername) return; // no change

    final usernameRef = _firestore.collection('usernames').doc(trimmed);

    // Return false from the transaction rather than throwing inside it —
    // Firebase can wrap/swallow non-Firebase exceptions during retries.
    final available = await _firestore.runTransaction<bool>((tx) async {
      final existing = await tx.get(usernameRef);
      if (existing.exists && existing.data()?['uid'] != uid) {
        return false;
      }
      // Release old username slot
      if (oldUsername != null && oldUsername.isNotEmpty) {
        tx.delete(_firestore.collection('usernames').doc(oldUsername));
      }
      // Reserve new username
      tx.set(usernameRef, {'uid': uid});
      // Save on user doc
      tx.set(_firestore.collection('users').doc(uid),
          {'username': trimmed}, SetOptions(merge: true));
      return true;
    });

    if (!available) throw const UsernameUnavailableException();
  }

  Stream<String?> get usernameStream {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.data()?['username'] as String?);
  }

  Future<void> updatePassword(String currentPassword, String newPassword) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) throw FirebaseAuthException(code: 'no-user');
    // Re-authenticate first (required by Firebase)
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  Future<void> deleteAccount({String? password}) async {
    final user = _auth.currentUser;
    if (user == null) throw FirebaseAuthException(code: 'no-user');

    final isGoogleUser =
        user.providerData.any((p) => p.providerId == 'google.com');

    // Re-authenticate before deletion (Firebase requirement)
    if (isGoogleUser) {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) throw FirebaseAuthException(code: 'cancelled');
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await user.reauthenticateWithCredential(credential);
    } else {
      if (password == null || password.isEmpty) {
        throw FirebaseAuthException(code: 'missing-password');
      }
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
    }

    // Delete Firestore data then the auth account
    final uid = user.uid;
    // Also clean up the username reservation if one exists
    final userDoc = await _firestore.collection('users').doc(uid).get();
    final existingUsername = userDoc.data()?['username'] as String?;
    if (existingUsername != null && existingUsername.isNotEmpty) {
      await _firestore.collection('usernames').doc(existingUsername).delete();
    }
    await _firestore.collection('users').doc(uid).delete();
    if (isGoogleUser) await _googleSignIn.signOut();
    await user.delete();
  }

  Future<UserCredential?> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null; // user cancelled

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    return await _auth.signInWithCredential(credential);
  }

  /// Ensures the user's Firestore document has a createdAt timestamp,
  /// a default privacyLevel, and (for Google users) their photoUrl stored.
  /// Safe to call multiple times — only writes missing fields.
  Future<void> ensureUserProfile() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final doc = await _firestore.collection('users').doc(uid).get();
    final data = doc.data() ?? {};

    final updates = <String, dynamic>{};

    if (data['createdAt'] == null) {
      final creationTime = _auth.currentUser?.metadata.creationTime;
      updates['createdAt'] = creationTime != null
          ? Timestamp.fromDate(creationTime)
          : FieldValue.serverTimestamp();
    }

    if (data['privacyLevel'] == null) {
      updates['privacyLevel'] = 'public';
    }

    final photoUrl = _auth.currentUser?.photoURL;
    if (photoUrl != null && data['photoUrl'] == null) {
      updates['photoUrl'] = photoUrl;
    }

    if (updates.isNotEmpty) {
      await _firestore
          .collection('users')
          .doc(uid)
          .set(updates, SetOptions(merge: true));
    }
  }

  Future<PrivacyLevel> getPrivacyLevel() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return PrivacyLevel.public;
    final doc = await _firestore.collection('users').doc(uid).get();
    return privacyLevelFromString(doc.data()?['privacyLevel'] as String?);
  }

  Future<void> setPrivacyLevel(PrivacyLevel level) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _firestore
        .collection('users')
        .doc(uid)
        .set({'privacyLevel': level.value}, SetOptions(merge: true));
  }
}

class UsernameUnavailableException implements Exception {
  const UsernameUnavailableException();
}

class ProfanityException implements Exception {
  const ProfanityException();
}

// ─── Profanity blocklist ───────────────────────────────────────────────────────
// Words are matched against individual segments of a username after splitting
// on underscores, dots, hyphens, and digit runs (whole-segment matching).
// This means "shite_bookworm" → ["shite", "bookworm"] → blocked,
// but "shitebookworm" (no separator) is treated as one segment → also blocked.
// Add or remove words here as needed. All comparisons are case-insensitive.
const List<String> _blockedTerms = [
  // ── Tier 1: unambiguous slurs & strongest profanity ──
  'nigger', 'nigga', 'chink', 'spic', 'kike', 'wetback', 'gook', 'raghead',
  'tranny', 'faggot', 'fag', 'dyke', 'retard', 'cripple',
  // ── Tier 2: common strong profanity ──
  'fuck', 'fucker', 'fucking', 'motherfucker', 'motherfucking',
  'cunt', 'cunts', 'cock', 'cocks', 'cocksucker',
  'shit', 'shits', 'shitter', 'bullshit',
  'ass', 'arse', 'asshole', 'arsehole', 'asswipe', 'arsewipe',
  'bitch', 'bitches', 'bastard', 'bastards',
  'whore', 'whores', 'slut', 'sluts',
  'piss', 'pissed', 'pisser',
  'dick', 'dicks', 'dickhead',
  'pussy', 'pussies',
  'twat', 'twats',
  'wanker', 'wank',
  'tit', 'tits', 'titties',
  'prick', 'pricks',
  'shite', 'bollock', 'bollocks',
  'knob', 'knobs', 'knobhead',
  // ── Tier 3: sexual / explicit ──
  'porn', 'porno', 'xxx', 'dildo', 'vibrator', 'blowjob', 'handjob',
  'cumshot', 'cum', 'orgasm', 'jizz', 'spunk',
  // ── Tier 4: hate / extremist ──
  'nazi', 'hitler', 'jihad', 'terrorist', 'isis',
];

bool _containsProfanity(String username) {
  // Split on underscores, dots, hyphens, and runs of digits, then also check
  // the whole unsplit string — catches both "bad_word" and "badword".
  final segments = username
      .toLowerCase()
      .split(RegExp(r'[_\.\-0-9]+'))
      ..add(username.toLowerCase());
  for (final segment in segments) {
    if (segment.isEmpty) continue;
    if (_blockedTerms.contains(segment)) return true;
  }
  return false;
}
