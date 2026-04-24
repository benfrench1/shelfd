import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../models/book_review.dart';
import '../services/storage_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xffF5F2ED),
        body: SafeArea(
          child: Column(
            children: [
              // Shared header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    const Icon(Icons.person, size: 28),
                    const SizedBox(width: 8),
                    Text(
                      'Shelfd',
                      style: GoogleFonts.fredoka(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xff5C3A1E),
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'Profile',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 19),
                      ),
                    ),
                    const SizedBox(width: 96),
                  ],
                ),
              ),

              // Tabs
              const TabBar(
                tabs: [
                  Tab(icon: Icon(Icons.person_outline)),
                  Tab(icon: Icon(Icons.bar_chart)),
                ],
              ),

              // Tab content
              const Expanded(
                child: TabBarView(
                  children: [
                    _UserProfileTab(),
                    _StatsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── User Profile Tab ────────────────────────────────────────────────────────

class _UserProfileTab extends StatelessWidget {
  const _UserProfileTab();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final authService = AuthService();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),

          // Avatar
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 52,
                backgroundColor: const Color(0xff5C3A1E).withOpacity(0.15),
                backgroundImage: user?.photoURL != null
                    ? NetworkImage(user!.photoURL!)
                    : null,
                child: user?.photoURL == null
                    ? const Icon(Icons.person, size: 52, color: Color(0xff5C3A1E))
                    : null,
              ),
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.deepOrange,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                  tooltip: 'Change profile picture',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Profile picture upload coming soon.'),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Email card
          Card(
            child: ListTile(
              leading: const Icon(Icons.email_outlined),
              title: const Text('Email', style: TextStyle(fontSize: 13, color: Colors.grey)),
              subtitle: Text(
                user?.email ?? 'No email',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Verified badge
          Card(
            child: ListTile(
              leading: Icon(
                user?.emailVerified == true
                    ? Icons.verified_user_outlined
                    : Icons.warning_amber_outlined,
                color: user?.emailVerified == true ? Colors.green : Colors.orange,
              ),
              title: Text(
                user?.emailVerified == true
                    ? 'Email verified'
                    : 'Email not verified',
                style: TextStyle(
                  color: user?.emailVerified == true ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Sign out
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Sign Out'),
                    content: const Text('Are you sure you want to sign out?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('No'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text(
                          'Yes',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await authService.signOut();
                }
              },
              icon: const Icon(Icons.logout, color: Colors.white),
              label: const Text(
                'Sign Out',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stats Tab ────────────────────────────────────────────────────────────────

class _StatsTab extends StatefulWidget {
  const _StatsTab();

  @override
  State<_StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<_StatsTab> {
  List<BookReview> reviews = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await StorageService.getReviews();
    setState(() => reviews = data);
  }

  int get totalCompleted => reviews.length;
  int get totalPhysical =>
      reviews.where((r) => r.format == BookFormat.physical).length;
  int get totalAudiobook =>
      reviews.where((r) => r.format == BookFormat.audiobook).length;
  int get totalBraille =>
      reviews.where((r) => r.format == BookFormat.braille).length;

  List<MapEntry<String, int>> get topAuthors {
    final Map<String, int> counts = {};
    for (final r in reviews) {
      counts[r.author] = (counts[r.author] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(5).toList();
  }

  List<BookReview> get topRated {
    final sorted = List<BookReview>.from(reviews)
      ..sort((a, b) => b.rating.compareTo(a.rating));
    return sorted.take(3).toList();
  }

  List<MapEntry<int, int>> get booksByYear {
    final Map<int, int> counts = {};
    for (final r in reviews) {
      final y = r.dateAdded.year;
      counts[y] = (counts[y] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.library_books),
              title: const Text("Total Books Completed"),
              trailing: Text(
                totalCompleted.toString(),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            margin: const EdgeInsets.symmetric(vertical: 3),
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.menu_book, size: 20),
              title: const Text("Total Books Read", style: TextStyle(fontSize: 13)),
              trailing: Text(
                totalPhysical.toString(),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(vertical: 3),
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.headphones, size: 20),
              title: const Text("Total Books Listened To", style: TextStyle(fontSize: 13)),
              trailing: Text(
                totalAudiobook.toString(),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(vertical: 3),
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.grain, size: 20),
              title: const Text("Total Books Read Braille", style: TextStyle(fontSize: 13)),
              trailing: Text(
                totalBraille.toString(),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Top Authors",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ...topAuthors.map((a) => Card(
                child: ListTile(
                  title: Text(a.key),
                  trailing: Text("${a.value} books"),
                ),
              )),
          const SizedBox(height: 20),
          const Text(
            "Top Rated Books",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ...topRated.map((b) => Card(
                color: b.isFavourite
                    ? Colors.amber.withOpacity(0.15)
                    : null,
                child: ListTile(
                  title: Text(b.title),
                  subtitle: Text(b.author),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 18),
                      Text(b.rating.toString()),
                    ],
                  ),
                ),
              )),
          const SizedBox(height: 20),
          const Text(
            "Stats by Year",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ...booksByYear.map((entry) => Card(
                child: ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: Text(entry.key.toString()),
                  trailing: Text(
                    entry.value.toString(),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
