import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class ChatScreen extends StatefulWidget {
  final String chatRoomId;
  final String currentUid;
  final String currentUsername;
  final String friendName;
  final String friendUid;
  final Color avatarColor;

  const ChatScreen({
    super.key,
    required this.chatRoomId,
    required this.currentUid,
    required this.currentUsername,
    required this.friendName,
    required this.friendUid,
    required this.avatarColor,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _isTyping = false;
  bool _friendTyping = false;

  @override
  void initState() {
    super.initState();
    _msgCtrl.addListener(_onTypingChanged);
    _listenFriendTyping();
    _markMessagesRead();
  }

  @override
  void dispose() {
    _setTyping(false);
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onTypingChanged() {
    final typing = _msgCtrl.text.isNotEmpty;
    if (typing != _isTyping) {
      _isTyping = typing;
      _setTyping(typing);
    }
  }

  Future<void> _setTyping(bool val) async {
    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatRoomId)
          .set({
        'typing_${widget.currentUid}': val,
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  void _listenFriendTyping() {
    FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatRoomId)
        .snapshots()
        .listen((snap) {
      if (snap.exists && mounted) {
        final data = snap.data() as Map<String, dynamic>;
        final ft = data['typing_${widget.friendUid}'] ?? false;
        if (ft != _friendTyping) {
          setState(() => _friendTyping = ft);
        }
      }
    });
  }

  Future<void> _markMessagesRead() async {
    final msgs = await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatRoomId)
        .collection('messages')
        .where('senderId', isEqualTo: widget.friendUid)
        .where('read', isEqualTo: false)
        .get();

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in msgs.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  Future<void> _sendMessage({String? text, String type = 'text'}) async {
    final msgText = text ?? _msgCtrl.text.trim();
    if (msgText.isEmpty) return;
    _msgCtrl.clear();

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatRoomId)
        .collection('messages')
        .add({
      'senderId': widget.currentUid,
      'senderName': widget.currentUsername,
      'text': msgText,
      'type': type,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
      'reactions': {},
    });

    // Scroll to bottom
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _addReaction(String msgId, String emoji) async {
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatRoomId)
        .collection('messages')
        .doc(msgId)
        .update({
      'reactions.${widget.currentUid}': emoji,
    });
  }

  void _showReactionPicker(String msgId) {
    const emojis = ['❤️', '😂', '👻', '🔥', '👍', '😮', '😢', '🎉'];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: emojis
              .map((e) => GestureDetector(
                    onTap: () {
                      _addReaction(msgId, e);
                      Navigator.pop(context);
                    },
                    child: Text(e, style: const TextStyle(fontSize: 32)),
                  ))
              .toList(),
        ),
      ),
    );
  }

  String _formatTime(Timestamp? ts) {
    if (ts == null) return '';
    return DateFormat('HH:mm').format(ts.toDate());
  }

  String _formatDate(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final now = DateTime.now();
    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      return 'Today';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.day == yesterday.day) return 'Yesterday';
    return DateFormat('MMM d, yyyy').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final initials = widget.friendName
        .substring(0, widget.friendName.length > 1 ? 2 : 1)
        .toUpperCase();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: widget.avatarColor.withOpacity(0.25),
              child: Text(
                initials,
                style: TextStyle(
                  color: widget.avatarColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.friendName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _friendTyping ? 'typing...' : 'ghost channel',
                  style: TextStyle(
                    color: _friendTyping
                        ? const Color(0xFFA78BFA)
                        : const Color(0xFF8B8AA8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone_outlined, size: 20),
            onPressed: () => _showSnack('Voice calls coming soon!'),
          ),
          IconButton(
            icon: const Icon(Icons.videocam_outlined, size: 22),
            onPressed: () => _showSnack('Video calls coming soon!'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.chatRoomId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (ctx, snap) {
                if (!snap.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFFA78BFA)),
                  );
                }

                final docs = snap.data!.docs;

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('👻', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 12),
                        Text(
                          'Secure channel open',
                          style: GoogleFonts.spaceMono(
                            color: const Color(0xFF8B8AA8),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Send the first message!',
                          style: TextStyle(color: Color(0xFF8B8AA8), fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollCtrl,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: docs.length,
                  itemBuilder: (ctx, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final docId = docs[i].id;
                    final isMe = data['senderId'] == widget.currentUid;
                    final ts = data['timestamp'] as Timestamp?;
                    final reactions = data['reactions'] as Map<String, dynamic>? ?? {};

                    // Date separator
                    bool showDate = false;
                    if (i == docs.length - 1) {
                      showDate = true;
                    } else {
                      final prevTs = docs[i + 1]['timestamp'] as Timestamp?;
                      if (ts != null && prevTs != null) {
                        final curr = ts.toDate();
                        final prev = prevTs.toDate();
                        if (curr.day != prev.day) showDate = true;
                      }
                    }

                    return Column(
                      children: [
                        if (showDate)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              _formatDate(ts),
                              style: const TextStyle(
                                color: Color(0xFF8B8AA8),
                                fontSize: 11,
                              ),
                            ),
                          ),
                        GestureDetector(
                          onLongPress: () {
                            HapticFeedback.mediumImpact();
                            _showReactionPicker(docId);
                          },
                          child: _MessageBubble(
                            text: data['text'] ?? '',
                            isMe: isMe,
                            time: _formatTime(ts),
                            isRead: data['read'] ?? false,
                            reactions: reactions,
                            avatarColor: widget.avatarColor,
                            initials: initials,
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // Typing indicator
          if (_friendTyping)
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 4),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: widget.avatarColor.withOpacity(0.2),
                    child: Text(
                      initials,
                      style: TextStyle(color: widget.avatarColor, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E2E),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const _TypingDots(),
                  ),
                ],
              ),
            ),

          // Input area
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: const BoxDecoration(
              color: Color(0xFF161622),
              border: Border(top: BorderSide(color: Color(0xFF2A2A3E))),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: Color(0xFF8B8AA8)),
                  onPressed: () => _showAttachmentMenu(),
                  padding: EdgeInsets.zero,
                ),
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    maxLines: 4,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    decoration: const InputDecoration(
                      hintText: 'Ghost message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(22)),
                        borderSide: BorderSide(color: Color(0xFF2A2A3E)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(22)),
                        borderSide: BorderSide(color: Color(0xFF2A2A3E)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(22)),
                        borderSide: BorderSide(color: Color(0xFFA78BFA), width: 1.5),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF7C3AED), Color(0xFFA78BFA)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _attachOption(Icons.image, 'Photo', () {
                  Navigator.pop(context);
                  _sendMessage(text: '📷 [Photo shared]');
                }),
                _attachOption(Icons.mic, 'Voice', () {
                  Navigator.pop(context);
                  _sendMessage(text: '🎤 [Voice message]');
                }),
                _attachOption(Icons.timer, 'Self-Destruct', () {
                  Navigator.pop(context);
                  _showSelfDestructPicker();
                }),
                _attachOption(Icons.location_on, 'Location', () {
                  Navigator.pop(context);
                  _sendMessage(text: '📍 [Location shared]');
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _attachOption(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFFA78BFA), size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Color(0xFF8B8AA8), fontSize: 12)),
        ],
      ),
    );
  }

  void _showSelfDestructPicker() {
    final options = ['30 seconds', '1 minute', '5 minutes', '1 hour'];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Self-destruct timer',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          ...options.map((o) => ListTile(
                title: Text(o, style: const TextStyle(color: Colors.white)),
                trailing: const Icon(Icons.timer, color: Color(0xFFA78BFA)),
                onTap: () {
                  Navigator.pop(context);
                  _msgCtrl.text = '⏱️ [Self-destruct: $o]';
                },
              )),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFF7C3AED),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final String time;
  final bool isRead;
  final Map<String, dynamic> reactions;
  final Color avatarColor;
  final String initials;

  const _MessageBubble({
    required this.text,
    required this.isMe,
    required this.time,
    required this.isRead,
    required this.reactions,
    required this.avatarColor,
    required this.initials,
  });

  @override
  Widget build(BuildContext context) {
    final uniqueReactions = reactions.values.toSet().toList();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: avatarColor.withOpacity(0.2),
              child: Text(initials, style: TextStyle(color: avatarColor, fontSize: 9, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 6),
          ],
          Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.65,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isMe ? const Color(0xFF7C3AED) : const Color(0xFF1E1E2E),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isMe ? 18 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 18),
                  ),
                  border: !isMe
                      ? Border.all(color: const Color(0xFF2A2A3E), width: 0.8)
                      : null,
                ),
                child: Text(
                  text,
                  style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
                ),
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(time, style: const TextStyle(color: Color(0xFF8B8AA8), fontSize: 10)),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(
                      isRead ? Icons.done_all : Icons.done,
                      size: 14,
                      color: isRead ? const Color(0xFFA78BFA) : const Color(0xFF8B8AA8),
                    ),
                  ],
                ],
              ),
              if (uniqueReactions.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E2E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF2A2A3E)),
                  ),
                  child: Text(
                    uniqueReactions.join(' '),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
      (i) => AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
        ..repeat(reverse: true),
    );
    for (var i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (mounted) _controllers[i].repeat(reverse: true);
      });
    }
    _anims = _controllers
        .map((c) => Tween<double>(begin: 0.3, end: 1.0).animate(c))
        .toList();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _anims[i],
          builder: (_, __) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: const Color(0xFFA78BFA).withOpacity(_anims[i].value),
              shape: BoxShape.circle,
            ),
          ),
        );
      }),
    );
  }
}
