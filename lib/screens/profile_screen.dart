import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _UserProfileTab extends StatefulWidget {
  const _UserProfileTab();

  @override
  State<_UserProfileTab> createState() => _UserProfileTabState();
}

class _UserProfileTabState extends State<_UserProfileTab> {
  final _authService = AuthService();
  String? _avatarAsset;
  List<String> _avatarAssets = [];

  @override
  void initState() {
    super.initState();
    _loadAvatar();
    _loadAvatarAssets();
  }

  Future<void> _loadAvatar() async {
    final asset = await _authService.getAvatarAsset();
    if (mounted) setState(() => _avatarAsset = asset);
  }

  Future<void> _loadAvatarAssets() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = manifest
        .listAssets()
        .where((key) => key.startsWith('assets/avatars/'))
        .toList()..sort();
    if (mounted) setState(() => _avatarAssets = assets);
  }

  void _showEnlargedAvatar() {
    final user = FirebaseAuth.instance.currentUser;
    final ImageProvider? image = _avatarAsset != null
        ? AssetImage(_avatarAsset!) as ImageProvider
        : (user?.photoURL != null ? NetworkImage(user!.photoURL!) : null);
    if (image == null) return;

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      barrierDismissible: true,
      builder: (_) => GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: GestureDetector(
            onTap: () {}, // prevent tap on image from closing
            child: CircleAvatar(
              radius: 140,
              backgroundImage: image,
            ),
          ),
        ),
      ),
    );
  }

  void _showAvatarPicker() {
    String? pendingAvatar = _avatarAsset;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => DraggableScrollableSheet(
        initialChildSize: 0.95,
        minChildSize: 0.75,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Choose an avatar',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: () async {
                      Navigator.of(sheetContext).pop();
                      if (pendingAvatar != null && pendingAvatar != _avatarAsset) {
                        await _authService.saveAvatarAsset(pendingAvatar!);
                        if (mounted) setState(() => _avatarAsset = pendingAvatar!);
                      }
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.green,
                      textStyle: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    child: const Text('Done'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  controller: scrollController,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _avatarAssets.length,
                  itemBuilder: (_, i) {
                    final asset = _avatarAssets[i];
                    final isSelected = pendingAvatar == asset;
                    return GestureDetector(
                      onTap: () {
                        setSheetState(() => pendingAvatar = asset);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: Colors.green, width: 5)
                              : Border.all(color: Colors.transparent, width: 5),
                        ),
                        child: CircleAvatar(
                          backgroundImage: AssetImage(asset),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),

          // Avatar
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Force the Stack's layout size to include the overflow button area
              const SizedBox(width: 124, height: 104),
              Positioned(
                left: 0,
                top: 0,
                child: GestureDetector(
                  onTap: _showEnlargedAvatar,
                  child: CircleAvatar(
                    radius: 52,
                    backgroundColor: const Color(0xff5C3A1E).withOpacity(0.15),
                    backgroundImage: _avatarAsset != null
                        ? AssetImage(_avatarAsset!) as ImageProvider
                        : (user?.photoURL != null
                            ? NetworkImage(user!.photoURL!)
                            : null),
                    child: _avatarAsset == null && user?.photoURL == null
                        ? const Icon(Icons.person, size: 52, color: Color(0xff5C3A1E))
                        : null,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.deepOrange,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.edit, size: 16, color: Colors.white),
                    tooltip: 'Change profile picture',
                    onPressed: _showAvatarPicker,
                  ),
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
                  await _authService.signOut();
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

          // Change Password — only for email/password users
          if (user?.providerData.any((p) => p.providerId == 'password') == true) ...
            [
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final success = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) =>
                          _ChangePasswordDialog(authService: _authService),
                    );
                    if (success == true) {
                      messenger
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          SnackBar(
                            content: const Row(
                              children: [
                                Icon(Icons.check_circle_outline,
                                    color: Colors.white, size: 20),
                                SizedBox(width: 10),
                                Text('Password updated successfully!'),
                              ],
                            ),
                            duration: const Duration(seconds: 4),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            margin: const EdgeInsets.all(16),
                          ),
                        );
                    }
                  },
                  icon: const Icon(Icons.lock_reset),
                  label: const Text(
                    'Change Password',
                    style: TextStyle(fontSize: 16),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xff5C3A1E),
                    side: const BorderSide(color: Color(0xff5C3A1E)),
                    padding: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
        ],
      ),
    );
  }
}

// ─── Change Password Dialog ───────────────────────────────────────────────────

class _ChangePasswordDialog extends StatefulWidget {
  final AuthService authService;
  const _ChangePasswordDialog({required this.authService});

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _error;
  bool _isLoading = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: const Text('Change Password'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _currentController,
              obscureText: _obscureCurrent,
              decoration: InputDecoration(
                labelText: 'Current password',
                prefixIcon: const Icon(Icons.lock_outlined),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscureCurrent
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () =>
                      setState(() => _obscureCurrent = !_obscureCurrent),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newController,
              obscureText: _obscureNew,
              decoration: InputDecoration(
                labelText: 'New password',
                prefixIcon: const Icon(Icons.lock_outlined),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscureNew
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () =>
                      setState(() => _obscureNew = !_obscureNew),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmController,
              obscureText: _obscureConfirm,
              decoration: InputDecoration(
                labelText: 'Confirm new password',
                prefixIcon: const Icon(Icons.lock_outlined),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirm
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepOrange,
            foregroundColor: Colors.white,
          ),
          onPressed: _isLoading
              ? null
              : () async {
                  final current = _currentController.text;
                  final newPwd = _newController.text;
                  final confirm = _confirmController.text;
                  if (current.isEmpty || newPwd.isEmpty || confirm.isEmpty) {
                    setState(() => _error = 'Please fill in all fields.');
                    return;
                  }
                  if (newPwd.length < 6) {
                    setState(() => _error =
                        'New password must be at least 6 characters.');
                    return;
                  }
                  if (newPwd != confirm) {
                    setState(
                        () => _error = 'New passwords do not match.');
                    return;
                  }
                  setState(() {
                    _isLoading = true;
                    _error = null;
                  });
                  try {
                    await widget.authService.updatePassword(current, newPwd);
                    if (mounted) Navigator.of(context).pop(true);
                  } on FirebaseAuthException catch (e) {
                    final msg = e.code == 'wrong-password' ||
                            e.code == 'invalid-credential'
                        ? 'Current password is incorrect.'
                        : 'Could not update password. Please try again.';
                    if (mounted) {
                      setState(() {
                        _error = msg;
                        _isLoading = false;
                      });
                    }
                  }
                },
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Update Password'),
        ),
      ],
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
