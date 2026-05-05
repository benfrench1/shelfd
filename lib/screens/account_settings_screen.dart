import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final _authService = AuthService();
  String? _username;
  PrivacyLevel _privacyLevel = PrivacyLevel.public;

  @override
  void initState() {
    super.initState();
    _loadUsername();
    _loadPrivacy();
  }

  Future<void> _loadUsername() async {
    final u = await _authService.getUsername();
    if (mounted) setState(() => _username = u);
  }

  Future<void> _loadPrivacy() async {
    final level = await _authService.getPrivacyLevel();
    if (mounted) setState(() => _privacyLevel = level);
  }  bool get _isGoogleUser =>
      FirebaseAuth.instance.currentUser?.providerData
          .any((p) => p.providerId == 'google.com') ??
      false;

  // ── Username ────────────────────────────────────────────────────────────────

  void _showEditUsernameSheet() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _UsernameEditSheet(initial: _username),
    );
    // result is the saved value (or null if dismissed); refresh local state
    if (result != null && mounted) {
      setState(() => _username = result.isEmpty ? null : result);
    }
  }

  // ── Change Password ─────────────────────────────────────────────────────────

  void _showChangePasswordSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ChangePasswordSheet(authService: _authService),
    ).then((success) {
      if (success == true && mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
            content: Text('Password updated successfully'),
            behavior: SnackBarBehavior.floating,
          ));
      }
    });
  }

  // ── Delete Account ───────────────────────────────────────────────────────────

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This will permanently delete your account and all associated data. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              if (_isGoogleUser) {
                _confirmDeleteAccount();
              } else {
                _showPasswordConfirmDeleteSheet();
              }
            },
            child: const Text('Delete My Account'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAccount({String? password}) async {
    try {
      await _authService.deleteAccount(password: password);
      // Pop entire navigation stack — the StreamBuilder in main.dart will
      // render LoginScreen now that the user is null.
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final msg = e.code == 'cancelled'
          ? 'Deletion cancelled.'
          : e.code == 'wrong-password' || e.code == 'invalid-credential'
              ? 'Incorrect password. Account not deleted.'
              : 'Failed to delete account. Please try again.';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ));
    }
  }

  // ── Privacy ─────────────────────────────────────────────────────────────────

  void _showPrivacySheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text('Profile Privacy',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 4),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                      'Control who can view your profile information.',
                      style: TextStyle(fontSize: 13, color: Colors.grey)),
                ),
                const SizedBox(height: 16),
                for (final level in PrivacyLevel.values)
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 24),
                    leading: Icon(
                      level == PrivacyLevel.public
                          ? Icons.public
                          : level == PrivacyLevel.friendsOnly
                              ? Icons.group_outlined
                              : Icons.lock_outline,
                      color: _privacyLevel == level
                          ? Colors.deepOrange
                          : null,
                    ),
                    title: Text(level.label,
                        style: TextStyle(
                          fontWeight: _privacyLevel == level
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: _privacyLevel == level
                              ? Colors.deepOrange
                              : null,
                        )),
                    subtitle: Text(level.description,
                        style: const TextStyle(fontSize: 12)),
                    trailing: _privacyLevel == level
                        ? const Icon(Icons.check_circle,
                            color: Colors.deepOrange)
                        : null,
                    onTap: () async {
                      Navigator.of(context).pop();
                      await _authService.setPrivacyLevel(level);
                      if (mounted) {
                        setState(() => _privacyLevel = level);
                      }
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPasswordConfirmDeleteSheet() async {    // Use a proper StatefulWidget so the TextEditingController is disposed
    // by Flutter only after the route animation fully completes, not earlier.
    final password = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _PasswordConfirmSheet(),
    );

    if (password != null && password.isNotEmpty) {
      await _confirmDeleteAccount(password: password);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xffF5F2ED),
      appBar: AppBar(
        backgroundColor: const Color(0xffF5F2ED),
        elevation: 0,
        title: const Text('Account Settings',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // ── Email ──────────────────────────────────────────────────
          Card(
            child: ListTile(
              leading: const Icon(Icons.email_outlined),
              title: const Text('Email',
                  style: TextStyle(fontSize: 13, color: Colors.grey)),
              subtitle: Text(
                user?.email ?? 'No email',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
          ),

          const SizedBox(height: 8),
          // ── Email verified ───────────────────────────────────
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

          const SizedBox(height: 8),
          // ── Change Password (email users only) ─────────────────────
          if (!_isGoogleUser) ...[
            Card(
              child: ListTile(
                leading: const Icon(Icons.lock_outlined),
                title: const Text('Change Password'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _showChangePasswordSheet,
              ),
            ),
            const SizedBox(height: 8),
          ],

          if (_isGoogleUser) ...[
            Card(
              child: ListTile(
                leading: Image.asset('assets/images/g_google_logo.png',
                    height: 20, width: 20),
                title: const Text('Signed in with Google'),
                subtitle: const Text(
                    'Password changes are managed via your Google account.',
                    style: TextStyle(fontSize: 12)),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // ── Username ───────────────────────────────────────────────
          Card(
            child: ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Username',
                  style: TextStyle(fontSize: 13, color: Colors.grey)),
              subtitle: Text(
                _username?.isNotEmpty == true ? _username! : 'Not set',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: _username?.isNotEmpty == true
                      ? null
                      : Colors.grey.shade400,
                ),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: _showEditUsernameSheet,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ── Privacy ────────────────────────────────────────────────
          Card(
            child: ListTile(
              leading: Icon(
                _privacyLevel == PrivacyLevel.public
                    ? Icons.public
                    : _privacyLevel == PrivacyLevel.friendsOnly
                        ? Icons.group_outlined
                        : Icons.lock_outline,
              ),
              title: const Text('Profile Privacy',
                  style: TextStyle(fontSize: 13, color: Colors.grey)),
              subtitle: Text(
                _privacyLevel.label,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w500),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _showPrivacySheet,
            ),
          ),

          const SizedBox(height: 24),

          // ── Sign Out ────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Sign Out'),
                    content: const Text('Are you sure you want to sign out?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('No'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text(
                          'Yes',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm == true && mounted) {
                  final nav = Navigator.of(context);
                  await _authService.signOut();
                  nav.popUntil((r) => r.isFirst);
                }
              },
              icon: const Icon(Icons.logout, color: Colors.white),
              label: const Text(
                'Sign Out',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                padding: const EdgeInsets.all(20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),

          const SizedBox(height: 8),

          const Divider(height: 32),

          // ── Delete Account ─────────────────────────────────────────
          Card(
            color: Colors.red.shade50,
            child: ListTile(
              leading:
                  const Icon(Icons.delete_forever_outlined, color: Colors.red),
              title: const Text('Delete Account',
                  style: TextStyle(
                      color: Colors.red, fontWeight: FontWeight.w600)),
              subtitle: const Text('Permanently remove your account and data.',
                  style: TextStyle(fontSize: 12)),
              trailing:
                  const Icon(Icons.chevron_right, color: Colors.red),
              onTap: _showDeleteAccountDialog,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Change Password Sheet ─────────────────────────────────────────────────────
// Proper StatefulWidget — avoids the Android animation timing assertion that
// fires when StatefulBuilder + whenComplete disposes controllers too early.

class _ChangePasswordSheet extends StatefulWidget {
  final AuthService authService;
  const _ChangePasswordSheet({required this.authService});

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  String? _errorMsg;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Change Password',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _currentCtrl,
              obscureText: _obscureCurrent,
              decoration: InputDecoration(
                labelText: 'Current password',
                prefixIcon: const Icon(Icons.lock_outlined),
                suffixIcon: IconButton(
                  icon: Icon(_obscureCurrent
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () =>
                      setState(() => _obscureCurrent = !_obscureCurrent),
                ),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _newCtrl,
              obscureText: _obscureNew,
              decoration: InputDecoration(
                labelText: 'New password',
                prefixIcon: const Icon(Icons.lock_outlined),
                suffixIcon: IconButton(
                  icon: Icon(_obscureNew
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () =>
                      setState(() => _obscureNew = !_obscureNew),
                ),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (v.length < 6) return 'Minimum 6 characters';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmCtrl,
              obscureText: _obscureConfirm,
              decoration: InputDecoration(
                labelText: 'Confirm new password',
                prefixIcon: const Icon(Icons.lock_outlined),
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirm
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (v != _newCtrl.text) return 'Passwords do not match';
                return null;
              },
            ),
            if (_errorMsg != null) ...[
              const SizedBox(height: 12),
              Text(_errorMsg!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _loading
                  ? null
                  : () async {
                      if (!_formKey.currentState!.validate()) return;
                      setState(() {
                        _loading = true;
                        _errorMsg = null;
                      });
                      try {
                        await widget.authService.updatePassword(
                          _currentCtrl.text,
                          _newCtrl.text,
                        );
                        if (mounted) Navigator.of(context).pop(true);
                      } on FirebaseAuthException catch (e) {
                        setState(() {
                          _loading = false;
                          _errorMsg = e.code == 'wrong-password' ||
                                  e.code == 'invalid-credential'
                              ? 'Current password is incorrect.'
                              : 'Failed to update password. Please try again.';
                        });
                      }
                    },
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Update Password',
                      style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Password Confirm Sheet ────────────────────────────────────────────────────
// A proper StatefulWidget so TextEditingController.dispose() is called by
// Flutter after the route animation fully completes on all platforms.

class _PasswordConfirmSheet extends StatefulWidget {
  const _PasswordConfirmSheet();

  @override
  State<_PasswordConfirmSheet> createState() => _PasswordConfirmSheetState();
}

class _PasswordConfirmSheetState extends State<_PasswordConfirmSheet> {
  final _ctrl = TextEditingController();
  bool _obscure = true;
  String? _errorMsg;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Confirm Deletion',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
          ),
          const SizedBox(height: 8),
          const Text('Enter your password to permanently delete your account.'),
          const SizedBox(height: 20),
          TextFormField(
            controller: _ctrl,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: IconButton(
                icon: Icon(_obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          if (_errorMsg != null) ...[
            const SizedBox(height: 12),
            Text(_errorMsg!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              if (_ctrl.text.isEmpty) {
                setState(() => _errorMsg = 'Please enter your password.');
                return;
              }
              Navigator.of(context).pop(_ctrl.text);
            },
            child: const Text('Delete My Account',
                style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}

// ── Username Edit Sheet ───────────────────────────────────────────────────────

class _UsernameEditSheet extends StatefulWidget {
  final String? initial;
  const _UsernameEditSheet({this.initial});

  @override
  State<_UsernameEditSheet> createState() => _UsernameEditSheetState();
}

class _UsernameEditSheetState extends State<_UsernameEditSheet> {
  static const int _maxLength = 30;

  late final TextEditingController _ctrl;
  String? _errorMsg;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial ?? '');
    _ctrl.addListener(() => setState(() => _errorMsg = null));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String? _validate(String value) {
    if (value.isEmpty) return null; // blank = clear username, allowed
    if (value.contains('/')) return 'Username cannot contain a forward slash (/).';
    if (value.length > _maxLength) return 'Username cannot exceed $_maxLength characters.';
    return null;
  }

  Future<void> _save() async {
    final value = _ctrl.text.trim();
    final validationError = _validate(value);
    if (validationError != null) {
      setState(() => _errorMsg = validationError);
      return;
    }
    setState(() { _saving = true; _errorMsg = null; });
    try {
      await AuthService().saveUsername(value);
      if (mounted) Navigator.of(context).pop(value);
    } on UsernameUnavailableException {
      setState(() {
        _saving = false;
        _errorMsg = 'That username is already taken. Please choose another.';
      });
    } catch (_) {
      setState(() {
        _saving = false;
        _errorMsg = 'Something went wrong. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _maxLength - _ctrl.text.length;
    final overLimit = remaining < 0;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Set Username',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('Leave blank to remove your username.'),
          const SizedBox(height: 20),
          TextField(
            controller: _ctrl,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              labelText: 'Username',
              prefixIcon: const Icon(Icons.person_outline),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              // live character counter suffix
              suffixText: '${_ctrl.text.length}/$_maxLength',
              suffixStyle: TextStyle(
                fontSize: 12,
                color: overLimit ? Colors.red : Colors.grey,
              ),
            ),
          ),
          if (_errorMsg != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorMsg!,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Save', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
