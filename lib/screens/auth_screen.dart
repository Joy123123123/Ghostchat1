import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  final TextEditingController _nickController = TextEditingController();
  bool _isLoading = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _nickController.dispose();
    super.dispose();
  }

  Future<void> _createGhostAccount() async {
    final username = _nickController.text.trim();
    if (username.isEmpty || username.length < 3) {
      _showSnack('নিকনেম কমপক্ষে ৩ অক্ষরের হতে হবে!');
      return;
    }
    if (username.length > 20) {
      _showSnack('নিকনেম সর্বোচ্চ ২০ অক্ষরের হতে পারবে!');
      return;
    }

    // নিকনেম আগে থেকে নেওয়া কিনা চেক করা
    final existing = await FirebaseFirestore.instance
        .collection('users')
        .where('username', isEqualTo: username)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      _showSnack('এই নিকনেম আগেই নেওয়া হয়েছে! অন্য নাম বেছে নিন।');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Anonymous-style login — ইমেইল/পাসওয়ার্ড অটো-জেনারেট
      final epoch = DateTime.now().millisecondsSinceEpoch;
      final fakeEmail = '${username.toLowerCase().replaceAll(' ', '_')}$epoch@ghost.void';
      const fakePass = 'GhostPass@2024!';

      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: fakeEmail, password: fakePass);

      final uid = credential.user!.uid;

      // Firestore-এ ইউজার প্রোফাইল সেভ
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'username': username,
        'email': fakeEmail,
        'status': 'online',
        'lastSeen': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'bio': 'Just a ghost 👻',
        'avatarColor': _randomColor(),
      });

      // লোকাল সেশন সেভ
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('uid', uid);
      await prefs.setString('username', username);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomeScreen(currentUid: uid, currentUsername: username),
        ),
      );
    } on FirebaseAuthException catch (e) {
      _showSnack('Error: ${e.message}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _randomColor() {
    const colors = ['7C3AED', '0F766E', '9D174D', '92400E', '1D4ED8', '065F46'];
    colors.shuffle();
    return colors.first;
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF7C3AED),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 50),
              // লোগো
              ScaleTransition(
                scale: _pulseAnim,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7C3AED), Color(0xFFC4B5FD)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7C3AED).withOpacity(0.4),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.all_inclusive, size: 56, color: Colors.white),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'GHOSTCHAT',
                style: GoogleFonts.spaceMono(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFA78BFA),
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'No phone. No email. Just a nickname.',
                style: TextStyle(color: Color(0xFF8B8AA8), fontSize: 14),
              ),
              const SizedBox(height: 50),

              // Features row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _featureChip(Icons.lock_outline, 'Anonymous'),
                  _featureChip(Icons.bolt, 'Real-time'),
                  _featureChip(Icons.security, 'Secure'),
                ],
              ),
              const SizedBox(height: 40),

              // নিকনেম ইনপুট
              TextField(
                controller: _nickController,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                textCapitalization: TextCapitalization.none,
                decoration: const InputDecoration(
                  hintText: 'Choose your ghost name...',
                  prefixIcon: Icon(Icons.alternate_email, color: Color(0xFFA78BFA)),
                  counterText: '',
                ),
                maxLength: 20,
                onSubmitted: (_) => _createGhostAccount(),
              ),
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '  Min 3 chars · No spaces · Unique forever',
                  style: TextStyle(color: Color(0xFF8B8AA8), fontSize: 11),
                ),
              ),
              const SizedBox(height: 24),

              // বাটন
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _isLoading ? null : _createGhostAccount,
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'ENTER THE VOID →',
                          style: GoogleFonts.spaceMono(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 40),

              // Privacy note
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF161622),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF2A2A3E)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_outlined, color: Color(0xFFA78BFA), size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'আমরা কোনো ব্যক্তিগত তথ্য সংগ্রহ করি না। শুধু একটি নিকনেম দিয়েই শুরু করুন।',
                        style: TextStyle(color: Color(0xFF8B8AA8), fontSize: 12, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _featureChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF161622),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2A2A3E)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFFA78BFA), size: 16),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(color: Color(0xFFA78BFA), fontSize: 12)),
        ],
      ),
    );
  }
}
