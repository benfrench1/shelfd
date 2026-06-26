import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../accessibility/accessibility_labels.dart';
import '../theme/app_theme.dart';
import '../services/activity_stream_service.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final String _myUid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void dispose() {
    // Mark all as seen when the user leaves the screen.
    ActivityStreamService.markAllSeen(_myUid);
    super.dispose();
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final c = ShelfdThemeScope.colorsOf(context);
    return Scaffold(
      backgroundColor: c.scaffoldBg,
      appBar: AppBar(
        backgroundColor: c.scaffoldBg,
        elevation: 0,
        title: const Text('Activity',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Stream
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: ActivityStreamService.stream(_myUid),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snap.data?.docs ?? [];

                  if (docs.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome,
                                size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text(
                              'No activity yet',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade500),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'When someone reacts to your reviews,\nit will appear here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey.shade400),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final data = docs[i].data();
                      return _ActivityCard(data: data);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _ActivityCard({required this.data});

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    final ts = dt;
    return '${ts.day}/${ts.month}/${ts.year}';
  }

  @override
  Widget build(BuildContext context) {
    final c = ShelfdThemeScope.colorsOf(context);
    final seen = data['seen'] as bool? ?? false;
    final isPrivate = data['reactorIsPrivate'] as bool? ?? false;
    final isFriend = data['reactorIsFriend'] as bool? ?? false;
    final showAsPrivate = isPrivate && !isFriend;
    final username = data['reactorUsername'] as String?;
    final avatarAsset = data['reactorAvatarAsset'] as String?;
    final photoUrl = data['reactorPhotoUrl'] as String?;
    final bookTitle = data['bookTitle'] as String? ?? 'Unknown book';
    final emojis = List<String>.from(data['emojis'] ?? []);
    final ts = data['timestamp'];
    DateTime? time;
    if (ts is Timestamp) time = ts.toDate();

    final ImageProvider? avatar = avatarAsset != null
        ? AssetImage(avatarAsset) as ImageProvider
        : photoUrl != null
            ? NetworkImage(photoUrl)
            : null;
    final actorName = showAsPrivate
        ? 'Private user'
        : (username?.isNotEmpty == true ? '@$username' : 'Shelfd User');
    final reactionSummary = emojis.isEmpty
        ? 'No reactions'
        : emojis.map(emojiSemanticLabel).join(', ');

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: seen ? 0.55 : 1.0,
      child: Semantics(
        container: true,
        label: '$actorName reacted to your review of $bookTitle. Reactions: $reactionSummary.${seen ? '' : ' New activity.'}',
        child: ExcludeSemantics(
          child: Card(
            color: seen ? null : c.primaryAccent.withValues(alpha: 0.07),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: seen
                  ? BorderSide.none
                  : BorderSide(
                      color: c.primaryAccent.withValues(alpha: 0.25), width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              // Avatar / private icon
              if (showAsPrivate)
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey.shade200,
                  ),
                  child: Icon(Icons.lock_outline,
                      size: 22, color: Colors.grey.shade500),
                )
              else
                CircleAvatar(
                  radius: 22,
                  backgroundColor:
                      c.avatarBg,
                  backgroundImage: avatar,
                  child: avatar == null
                      ? Icon(Icons.person,
                          size: 22, color: c.brandColor)
                      : null,
                ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: TextStyle(
                            fontSize: 14, color: c.textPrimary),
                        children: [
                          TextSpan(
                            text: showAsPrivate
                                ? 'Private user'
                                : (username?.isNotEmpty == true
                                    ? '@$username'
                                    : 'Shelfd User'),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold),
                          ),
                          const TextSpan(text: ' reacted to your review of '),
                          TextSpan(
                            text: bookTitle,
                            style: const TextStyle(
                                fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Emoji chips
                    Wrap(
                      spacing: 6,
                      children: emojis
                          .map((e) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: c.primaryAccent.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color:
                                        c.primaryAccent.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Text(e,
                                    style: const TextStyle(fontSize: 18)),
                              ))
                          .toList(),
                    ),
                    if (time != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _timeAgo(time),
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ],
                ),
              ),

              // New indicator dot
              if (!seen)
                Padding(
                  padding: const EdgeInsets.only(top: 2, left: 4),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: c.primaryAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
