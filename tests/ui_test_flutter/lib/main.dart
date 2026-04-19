import 'package:flutter/material.dart';
import 'chat_screen.dart';

void main() {
  runApp(const ChatApp());
}

class ChatApp extends StatelessWidget {
  const ChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F1117),
        colorScheme: const ColorScheme.dark(
          surface: Color(0xFF0F1117),
          primary: Color(0xFF2563EB),
          onPrimary: Color(0xFFFFFFFF),
          onSurface: Color(0xFFCBD5E1),
        ),
        fontFamily: 'monospace',
      ),
      home: const LandingScreen(),
    );
  }
}

// ── Landing Screen ────────────────────────────────────────────────────────────
// The "What can I help you with?" phase shown before the chat begins.

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  // Suggestion chips shown on the landing screen
  final List<String> _suggestions = [
    'Tell me something interesting',
    'What can you help with?',
    'Write me a haiku',
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _startChat(String initialMessage) {
    if (initialMessage.trim().isEmpty) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, animation, __) =>
            ChatScreen(initialMessage: initialMessage.trim()),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                // ── Top spacer + logo area ──────────────────────────────────
                const Spacer(flex: 3),
                _buildLogo(),
                const SizedBox(height: 16),

                // ── Headline ────────────────────────────────────────────────
                const Text(
                  'What can I help\nyou with?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w300,
                    color: Color(0xFFF1F5F9),
                    height: 1.25,
                    letterSpacing: -0.5,
                  ),
                ),

                const Spacer(flex: 2),

                // ── Suggestion chips ────────────────────────────────────────
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: _suggestions
                      .map(
                        (s) => _SuggestionChip(
                          label: s,
                          onTap: () => _startChat(s),
                        ),
                      )
                      .toList(),
                ),

                const SizedBox(height: 24),

                // ── Input field ─────────────────────────────────────────────
                _LandingInput(controller: _controller, onSubmit: _startChat),

                const Spacer(flex: 1),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(0.35),
            blurRadius: 20,
            spreadRadius: 0,
          ),
        ],
      ),
      child: const Icon(
        Icons.auto_awesome_rounded,
        color: Colors.white,
        size: 26,
      ),
    );
  }
}

// ── Landing Input ─────────────────────────────────────────────────────────────

class _LandingInput extends StatelessWidget {
  final TextEditingController controller;
  final void Function(String) onSubmit;

  const _LandingInput({required this.controller, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A2030),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E2D3D), width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Ask anything…',
                hintStyle: TextStyle(color: Color(0xFF475569)),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                border: InputBorder.none,
              ),
              onSubmitted: onSubmit,
              textInputAction: TextInputAction.send,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _SendButton(onTap: () => onSubmit(controller.text)),
          ),
        ],
      ),
    );
  }
}

// ── Send Button ───────────────────────────────────────────────────────────────

class _SendButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SendButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFF2563EB),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.arrow_upward_rounded,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }
}

// ── Suggestion Chip ───────────────────────────────────────────────────────────

class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SuggestionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2030),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF1E2D3D)),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
        ),
      ),
    );
  }
}
