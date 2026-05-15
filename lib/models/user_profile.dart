import 'package:cloud_firestore/cloud_firestore.dart';

// ─── Privacy Level ───────────────────────────────────────────────────────────

enum PrivacyLevel { public, friendsOnly, private }

extension PrivacyLevelExt on PrivacyLevel {
  String get value {
    switch (this) {
      case PrivacyLevel.public:
        return 'public';
      case PrivacyLevel.friendsOnly:
        return 'friends_only';
      case PrivacyLevel.private:
        return 'private';
    }
  }

  String get label {
    switch (this) {
      case PrivacyLevel.public:
        return 'Public';
      case PrivacyLevel.friendsOnly:
        return 'Friends Only';
      case PrivacyLevel.private:
        return 'Private';
    }
  }

  String get description {
    switch (this) {
      case PrivacyLevel.public:
        return 'Anyone can view your profile';
      case PrivacyLevel.friendsOnly:
        return 'Only friends can view your profile';
      case PrivacyLevel.private:
        return 'No one can view your profile';
    }
  }
}

PrivacyLevel privacyLevelFromString(String? value) {
  switch (value) {
    case 'friends_only':
      return PrivacyLevel.friendsOnly;
    case 'private':
      return PrivacyLevel.private;
    default:
      return PrivacyLevel.public;
  }
}

// ─── UserProfile ─────────────────────────────────────────────────────────────

class UserProfile {
  final String uid;
  final String? username;
  final String? avatarAsset;
  final String? photoUrl;
  final PrivacyLevel privacyLevel;
  final DateTime? createdAt;

  const UserProfile({
    required this.uid,
    this.username,
    this.avatarAsset,
    this.photoUrl,
    this.privacyLevel = PrivacyLevel.public,
    this.createdAt,
  });

  String get displayName => username?.isNotEmpty == true ? username! : 'Shelfd User';

  factory UserProfile.fromFirestore(String uid, Map<String, dynamic> data) {
    DateTime? createdAt;
    final raw = data['createdAt'];
    if (raw is Timestamp) {
      createdAt = raw.toDate();
    } else if (raw is String) {
      createdAt = DateTime.tryParse(raw);
    }

    return UserProfile(
      uid: uid,
      username: data['username'] as String?,
      avatarAsset: data['avatarAsset'] as String?,
      photoUrl: data['photoUrl'] as String?,
      privacyLevel: privacyLevelFromString(data['privacyLevel'] as String?),
      createdAt: createdAt,
    );
  }
}

// ─── Friendship ───────────────────────────────────────────────────────────────

enum FriendshipStatus { none, pendingSent, pendingReceived, accepted }

class FriendRequest {
  final String id;
  final String fromUid;
  final String toUid;
  final String? fromUsername;
  final String? toUsername;
  final FriendshipStatus status;
  final DateTime createdAt;

  const FriendRequest({
    required this.id,
    required this.fromUid,
    required this.toUid,
    this.fromUsername,
    this.toUsername,
    required this.status,
    required this.createdAt,
  });

  factory FriendRequest.fromFirestore(
      String id, String myUid, Map<String, dynamic> data) {
    final rawStatus = data['status'] as String?;
    FriendshipStatus status;
    if (rawStatus == 'accepted') {
      status = FriendshipStatus.accepted;
    } else if (data['fromUid'] == myUid) {
      status = FriendshipStatus.pendingSent;
    } else {
      status = FriendshipStatus.pendingReceived;
    }

    DateTime createdAt = DateTime.now();
    final raw = data['createdAt'];
    if (raw is Timestamp) createdAt = raw.toDate();

    return FriendRequest(
      id: id,
      fromUid: data['fromUid'] as String,
      toUid: data['toUid'] as String,
      fromUsername: data['fromUsername'] as String?,
      toUsername: data['toUsername'] as String?,
      status: status,
      createdAt: createdAt,
    );
  }

  /// The UID of the other person (not me).
  String otherUid(String myUid) => fromUid == myUid ? toUid : fromUid;

  /// The username of the other person (not me).
  String? otherUsername(String myUid) =>
      fromUid == myUid ? toUsername : fromUsername;
}
