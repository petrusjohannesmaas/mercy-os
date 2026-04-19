import 'package:flutter/material.dart';
import 'dart:math';

// ── Canned responses ──────────────────────────────────────────────────────────
// The bot picks one at random. Swap these out for anything you like.

const List<String> _cannedResponses = [
  "That's an interesting thought. I don't have a strong opinion on it yet, but I'd love to explore it further with you.",
  "Great question. The short answer is: it depends. The longer answer involves a lot of nuance that I'd be happy to unpack.",
  "I've been thinking about something similar recently. Here's my take — though I reserve the right to change my mind entirely.",
];

final _random = Random();

String _getResponse() =>
    _cannedResponses[_random.nextInt(_cannedResponses.length)];

// ── Data model ────────────────────────────────────────────────────────────────

enum MessageRole { user, bot }

class ChatMessage {
  final String text;
  final MessageRole role;
  final DateTime timestamp;

  ChatMessage({required this.text, required this.role, DateTime? timestamp})
    : timestamp = timestamp ?? DateTime.now();
}

// ── Chat Screen ───────────────────────────────────────────────────────────────

class ChatScreen extends StatefulWidget {
  final String initialMessage;

  const ChatScreen({super.key, required this.initialMessage});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false; // shows the "bot is typing" indicator

  @override
  void initState() {
    super.initState();
    // Seed with the message the user sent from the landing screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _addMessage(widget.initialMessage, MessageRole.user);
      _simulateBotReply();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Message logic ───────────────────────────────────────────────────────────

  void _addMessage(String text, MessageRole role) {
    setState(() {
      _messages.add(ChatMessage(text: text, role: role));
    });
    _scrollToBottom();
  }

  void _simulateBotReply() async {
    setState(() => _isTyping = true);
    _scrollToBottom();

    // Simulate thinking delay
    await Future.delayed(const Duration(milliseconds: 900));

    if (!mounted) return;
    setState(() => _isTyping = false);
    _addMessage(_getResponse(), MessageRole.bot);
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty || _isTyping) return;
    _controller.clear();
    _addMessage(text, MessageRole.user);
    _simulateBotReply();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Message list
          Expanded(
            child: _messages.isEmpty
                ? const SizedBox()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    itemCount: _messages.length + (_isTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        return const _TypingIndicator();
                      }
                      final msg = _messages[index];
                      return _MessageBubble(message: msg);
                    },
                  ),
          ),

          // Input bar
          _buildInputBar(),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0F1117),
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_rounded,
          color: Color(0xFF64748B),
          size: 20,
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Assistant',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: const Color(0xFF1A2030)),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F1117),
        border: Border(top: BorderSide(color: Color(0xFF1A2030))),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A2030),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF1E2D3D)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: !_isTyping,
                style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 14),
                decoration: InputDecoration(
                  hintText: _isTyping ? 'Waiting for response…' : 'Message…',
                  hintStyle: const TextStyle(color: Color(0xFF475569)),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _sendMessage(),
                textInputAction: TextInputAction.send,
                maxLines: null,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: _sendMessage,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _isTyping
                        ? const Color(0xFF1E2D3D)
                        : const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.arrow_upward_rounded,
                    color: _isTyping ? const Color(0xFF334155) : Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Message Bubble ────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  bool get isUser => message.role == MessageRole.user;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[_BotAvatar(), const SizedBox(width: 8)],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: isUser
                    ? const Color(0xFF2563EB)
                    : const Color(0xFF1A2030),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: isUser
                    ? null
                    : Border.all(color: const Color(0xFF1E2D3D)),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: isUser ? Colors.white : const Color(0xFFCBD5E1),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _BotAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.auto_awesome_rounded,
        color: Colors.white,
        size: 14,
      ),
    );
  }
}

// ── Typing Indicator ──────────────────────────────────────────────────────────

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with TickerProviderStateMixin {
  final List<AnimationController> _controllers = [];
  final List<Animation<double>> _animations = [];

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 3; i++) {
      final controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500),
      );
      final animation = Tween<double>(
        begin: 0,
        end: -6,
      ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));
      _controllers.add(controller);
      _animations.add(animation);

      // Stagger each dot's animation
      Future.delayed(Duration(milliseconds: i * 160), () {
        if (mounted) controller.repeat(reverse: true);
      });
    }
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          _BotAvatar(),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2030),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(color: const Color(0xFF1E2D3D)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                return AnimatedBuilder(
                  animation: _animations[i],
                  builder: (_, __) => Transform.translate(
                    offset: Offset(0, _animations[i].value),
                    child: Container(
                      width: 6,
                      height: 6,
                      margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                      decoration: BoxDecoration(
                        color: const Color(0xFF475569),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
