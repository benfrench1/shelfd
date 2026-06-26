import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/user_profile.dart';
import '../services/friend_code_service.dart';
import '../services/friend_service.dart';

enum _ScanState { scanning, loading, confirm, adding }

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final _controller = MobileScannerController();
  _ScanState _state = _ScanState.scanning;
  UserProfile? _scannedProfile;
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;

    final uri = Uri.tryParse(raw);
    if (uri == null || uri.scheme != 'shelfd' || uri.host != 'friend') return;
    final code = uri.pathSegments.firstOrNull;
    if (code == null || code.isEmpty) return;

    _handled = true;
    await _controller.stop();
    if (mounted) setState(() => _state = _ScanState.loading);

    final me = FirebaseAuth.instance.currentUser;
    if (me == null) {
      _reset();
      return;
    }

    final uid = await FriendCodeService.uidFromCode(code);
    if (uid == null) {
      _showError('This QR code is not valid.');
      return;
    }
    if (uid == me.uid) {
      _showError("You can't scan your own QR code.");
      return;
    }

    final profile = await FriendService.getUserProfile(uid);
    if (profile == null) {
      _showError('User not found.');
      return;
    }

    if (mounted) {
      setState(() {
        _scannedProfile = profile;
        _state = _ScanState.confirm;
      });
    }
  }

  void _reset() {
    _handled = false;
    _controller.start();
    if (mounted) setState(() => _state = _ScanState.scanning);
  }

  void _showError(String message) {
    _reset();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _addFriend() async {
    final profile = _scannedProfile;
    if (profile == null) return;
    setState(() => _state = _ScanState.adding);
    try {
      await FriendService.acceptViaQr(profile);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${profile.displayName} added as a friend!'),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
        ),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Something went wrong. Please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _state = _ScanState.confirm);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan QR Code'),
      ),
      body: (_state == _ScanState.confirm || _state == _ScanState.adding)
          ? _buildConfirm()
          : _buildScanner(),
    );
  }

  Widget _buildScanner() {
    return Stack(
      children: [
        MobileScanner(controller: _controller, onDetect: _onDetect),
        // Viewfinder overlay
        Center(
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.deepOrange, width: 3),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        if (_state == _ScanState.loading)
          const Center(
            child: CircularProgressIndicator(color: Colors.deepOrange),
          ),
        Positioned(
          bottom: 56,
          left: 0,
          right: 0,
          child: Center(
            child: Text(
              'Point the camera at a Shelfd QR code',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.8), fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirm() {
    final profile = _scannedProfile!;
    final ImageProvider? avatar = profile.avatarAsset != null
        ? AssetImage(profile.avatarAsset!) as ImageProvider
        : profile.photoUrl != null
            ? NetworkImage(profile.photoUrl!)
            : null;
    final adding = _state == _ScanState.adding;

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Semantics(
            container: true,
            label: 'Scanned profile for ${profile.displayName}${profile.username?.isNotEmpty == true ? ', username ${profile.username}' : ''}.',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  image: true,
                  label: '${profile.displayName} profile picture',
                  child: ExcludeSemantics(
                    child: CircleAvatar(
                      radius: 52,
                      backgroundColor:
                          const Color(0xff5C3A1E).withOpacity(0.15),
                      backgroundImage: avatar,
                      child: avatar == null
                          ? const Icon(Icons.person,
                              size: 52, color: Color(0xff5C3A1E))
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  profile.displayName,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                if (profile.username?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(
                    '@${profile.username}',
                    style: const TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                ],
                const SizedBox(height: 16),
                ExcludeSemantics(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.deepOrange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.qr_code_2,
                            size: 14, color: Colors.deepOrange),
                        SizedBox(width: 6),
                        Text(
                          'Scanned via QR code',
                          style: TextStyle(
                              fontSize: 12, color: Colors.deepOrange),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 36),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: adding
                            ? null
                            : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white38),
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Not Now'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: adding ? null : _addFriend,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepOrange,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: adding
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white),
                              )
                            : const Text('Add Friend',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
