import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'chat_screen.dart';
import 'auth_screen.dart';

class HomeScreen extends StatefulWidget {
  final String currentUid;
  final String currentUsername;

  const HomeScreen({
    super.key,
    required this.currentUid,
    required this.currentUsername,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _setOnline(true);
  }

  @override
  void dispose() {
    _setOnline(false);
    super.dispose();
  }

  Future<void> _setOnline(bool online) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUid)
          .update({
        'status': online ? 'online' : 'offline',
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Future<void> _logout() async {
    await _setOnline(false);
    await FirebaseAuth.instance.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AuthScreen()),
    );
  }

  String _getChatRoomId(String friendUid) {
    final ids = [widget.currentUid, friendUid]..sort();
    return ids.join('_');
  }

  String _formatTime(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('MMM d').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFFA78BFA)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.all_inclusive, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GhostChat',
                  style: GoogleFonts.spaceMono(
                    color: const Color(0xFFA78BFA),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '@${widget.currentUsername}',
                  style: const TextStyle(color: Color(0xFF8B8AA8), fontSize: 11),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.radar, color: Color(0xFFA78BFA)),
            onPressed: () {},
            tooltip: 'Nearby Ghosts',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Color(0xFF8B8AA8)),
            color: const Color(0xFF1E1E2E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (val) {
              if (val == 'logout') _logout();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Color(0xFFA78BFA), size: 18),
                    SizedBox(width: 10),
                    Text('Logout', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .orderBy('lastSeen', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFA78BFA)),
            );
          }

          final docs = snap.data!.docs
              .where((d) => d.id != widget.currentUid)
              .toList();

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.all_inclusive, size: 64, color: Color(0xFF2A2A3E)),
                  const SizedBox(height: 16),
                  Text(
                    'No ghosts found yet',
                    style: GoogleFonts.spaceMono(
                      color: const Color(0xFF8B8AA8),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Share the app with friends to start chatting!',
                    style: TextStyle(color: Color(0xFF8B8AA8), fontSize: 12),
                  ),
                ],
              ),
            );
          }

          final online = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            return data['status'] == 'online';
          }).toList();

          final offline = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            return data['status'] != 'online';
          }).toList();

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            children: [
              if (online.isNotEmpty) ...[
                _sectionLabel('ONLINE NOW', online.length),
                ...online.map((d) => _userTile(d, true)),
                const SizedBox(height: 10),
              ],
              if (offline.isNotEmpty) ...[
                _sectionLabel('RECENTLY SEEN', offline.length),
                ...offline.map((d) => _userTile(d, false)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _sectionLabel(String label, int count) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.spaceMono(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF8B8AA8),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(color: Color(0xFFA78BFA), fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _userTile(QueryDocumentSnapshot doc, bool isOnline) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['username'] ?? 'Ghost';
    final uid = data['uid'] ?? doc.id;
    final initials = name.substring(0, name.length > 1 ? 2 : 1).toUpperCase();
    final colorHex = data['avatarColor'] ?? '7C3AED';
    final color = Color(int.parse('FF$colorHex', radix: 16));
    final lastSeen = data['lastSeen'] as Timestamp?;
    final bio = data['bio'] ?? '';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .doc(_getChatRoomId(uid))
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .snapshots(),
      builder: (ctx, msgSnap) {
        String lastMsg = 'Tap to connect';
        String lastMsgTime = '';
        int unread = 0;

        if (msgSnap.hasData && msgSnap.data!.docs.isNotEmpty) {
          final lastData = msgSnap.data!.docs.first.data() as Map<String, dynamic>;
          lastMsg = lastData['text'] ?? lastData['type'] ?? 'Message';
          lastMsgTime = _formatTime(lastData['timestamp'] as Timestamp?);
          // Unread count (simplified)
          if (lastData['senderId'] != widget.currentUid &&
              lastData['read'] == false) {
            unread = 1;
          }
        }

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatScreen(
                  chatRoomId: _getChatRoomId(uid),
                  currentUid: widget.currentUid,
                  currentUsername: widget.currentUsername,
                  friendName: name,
                  friendUid: uid,
                  avatarColor: color,
                ),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF161622),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2A2A3E), width: 0.8),
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: color.withOpacity(0.3),
                      child: Text(
                        initials,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: isOnline ? const Color(0xFF34D399) : const Color(0xFF8B8AA8),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF161622), width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        lastMsg,
                        style: TextStyle(
                          color: unread > 0 ? const Color(0xFFA78BFA) : const Color(0xFF8B8AA8),
                          fontSize: 12,
                          fontWeight: unread > 0 ? FontWeight.w500 : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      lastMsgTime,
                      style: const TextStyle(color: Color(0xFF8B8AA8), fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    if (unread > 0)
                      Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          color: Color(0xFF7C3AED),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '$unread',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      )
                    else
                      const Icon(Icons.bolt, color: Color(0xFF2A2A3E), size: 18),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
