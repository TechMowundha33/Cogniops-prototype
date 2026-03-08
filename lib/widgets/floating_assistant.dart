import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import '../services/bedrock_service.dart';


class FloatingAssistant extends StatefulWidget {
  const FloatingAssistant({super.key});

  @override
  State<FloatingAssistant> createState() => _FloatingAssistantState();
}

class _FloatingAssistantState extends State<FloatingAssistant>
    with SingleTickerProviderStateMixin {
  bool _open = false;
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_Msg> _messages = [
    _Msg(isUser: false, text: 'Hi! Got a quick question? I\'m here 🤖'),
  ];
  bool _typing = false;

  late final AnimationController _animController;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _scaleAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOutBack);
  }

  @override
  void dispose() {
    _animController.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    if (_open) {
      _animController.forward();
    } else {
      _animController.reverse();
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_Msg(isUser: true, text: text));
      _controller.clear();
      _typing = true;
    });
    _scrollToBottom();

    try {
      final reply = await BedrockService().quickAsk(text);
      if (!mounted) return;
      setState(() { _messages.add(_Msg(isUser: false, text: reply)); _typing = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _messages.add(_Msg(isUser: false, text: '⚠️ Could not reach Bedrock. Check api_config.dart.')); _typing = false; });
    }
    _scrollToBottom();
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final surfaceAlt = isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurfaceAlt;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_open)
          ScaleTransition(
            scale: _scaleAnim,
            alignment: Alignment.bottomRight,
            child: Container(
              width: 300,
              height: 360,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [AppColors.accent, AppColors.accentAlt]),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Quick Ask',
                        style: GoogleFonts.dmSans(
                          color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _toggle,
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                    ),
                  ]),
                ),
                // Messages
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length + (_typing ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (_typing && i == _messages.length) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: surfaceAlt,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              _dot(0), _dot(1), _dot(2),
                            ]),
                          ),
                        );
                      }
                      final msg = _messages[i];
                      return Align(
                        alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          constraints: const BoxConstraints(maxWidth: 220),
                          decoration: BoxDecoration(
                            color: msg.isUser ? AppColors.accent : surfaceAlt,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: msg.isUser
                              ? Text(msg.text,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 12,
                                    color: Colors.white,
                                    height: 1.5,
                                  ),
                                )
                              : MarkdownBody(
                                  data: msg.text,
                                  styleSheet: MarkdownStyleSheet(
                                    p: GoogleFonts.dmSans(fontSize: 12, color: textColor, height: 1.5),
                                    strong: GoogleFonts.dmSans(fontSize: 12, color: textColor, fontWeight: FontWeight.w700),
                                    em: GoogleFonts.dmSans(fontSize: 12, color: textColor, fontStyle: FontStyle.italic),
                                    listBullet: GoogleFonts.dmSans(fontSize: 12, color: textColor),
                                    code: GoogleFonts.sourceCodePro(fontSize: 11, color: AppColors.accent),
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
                ),
                // Input
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: border)),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                          hintText: 'Ask anything...',
                          hintStyle: GoogleFonts.dmSans(fontSize: 12),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppColors.accent),
                          ),
                          filled: true,
                          fillColor: surfaceAlt,
                        ),
                        style: GoogleFonts.dmSans(fontSize: 12, color: textColor),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _send,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.send_rounded, color: Colors.white, size: 16),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        // FAB
        GestureDetector(
          onTap: _toggle,
          child: Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.accent, AppColors.accentAlt],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withOpacity(0.45),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                _open ? Icons.close_rounded : Icons.smart_toy_rounded,
                color: Colors.white, size: 24,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _dot(int i) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0.4, end: 1.0),
    duration: Duration(milliseconds: 500 + i * 150),
    builder: (_, v, __) => Opacity(
      opacity: v,
      child: Container(
        width: 6, height: 6,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: const BoxDecoration(
          color: AppColors.accent,
          shape: BoxShape.circle,
        ),
      ),
    ),
  );
}

class _Msg {
  final bool isUser;
  final String text;
  _Msg({required this.isUser, required this.text});
}