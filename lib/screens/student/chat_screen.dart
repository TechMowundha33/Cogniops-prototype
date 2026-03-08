import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../core/theme.dart';
import '../../providers/chat_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/chat_message.dart';
import '../../widgets/voice_recorder.dart';
import '../../widgets/tts_button.dart';
import 'dart:convert';
import '../../services/bedrock_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ctrl        = TextEditingController();
  final _scrollCtrl  = ScrollController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool   _voiceError = false;
  String _voiceMsg   = '';

  @override
  void initState() {
    super.initState();
    final chat = context.read<ChatProvider>();
    final user = context.read<AuthProvider>().user!;
    if (chat.messages.isEmpty) {
      user.isDeveloper ? chat.initDeveloper() : chat.initStudent();
    } else {
      chat.loadSessions();
    }
  }

  @override
  void dispose() { _ctrl.dispose(); _scrollCtrl.dispose(); super.dispose(); }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send([String? override]) async {
    final text = override ?? _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    setState(() { _voiceError = false; _voiceMsg = ''; });
    final user = context.read<AuthProvider>().user!;
    await context.read<ChatProvider>().sendMessage(text, isDeveloper: user.isDeveloper);
    _scrollToBottom();
  }

  void _onTranscript(String text) {
    _ctrl.text = text;
    _ctrl.selection = TextSelection.fromPosition(TextPosition(offset: text.length));
    setState(() { _voiceError = false; _voiceMsg = '🎤 "$text"'; });
    Future.delayed(const Duration(milliseconds: 600), () => _send());
  }

  void _onVoiceError(String err) => setState(() { _voiceError = true; _voiceMsg = err; });

  @override
  Widget build(BuildContext context) {
    final isDark     = Theme.of(context).brightness == Brightness.dark;
    final surface    = isDark ? AppColors.darkSurface    : AppColors.lightSurface;
    final surfaceAlt = isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurfaceAlt;
    final border     = isDark ? AppColors.darkBorder     : AppColors.lightBorder;
    final textColor  = isDark ? AppColors.darkText       : AppColors.lightText;
    final subColor   = isDark ? AppColors.darkTextSub    : AppColors.lightTextSub;
    final user       = context.read<AuthProvider>().user!;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: surface,

      //  History Drawer 
      drawer: _HistoryDrawer(
        onNewChat: () {
          Navigator.pop(context);
          context.read<ChatProvider>().newChat();
        },
        onSelectSession: (id) {
          Navigator.pop(context);
          context.read<ChatProvider>().loadSession(id);
        },
      ),

      body: Column(children: [
        //  Header 
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: surface, border: Border(bottom: BorderSide(color: border))),
          child: Row(children: [
            // History icon
            GestureDetector(
              onTap: () => _scaffoldKey.currentState?.openDrawer(),
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: surfaceAlt, borderRadius: BorderRadius.circular(8), border: Border.all(color: border)),
                child: Icon(Icons.history_rounded, size: 18, color: textColor),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.accent, AppColors.accentAlt]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(user.isDeveloper ? 'CogniBot Dev' : 'CogniBot Student',
                  style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: textColor)),
              Row(children: [
                Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.accentGreen, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Text('Powered by Claude on Bedrock', style: GoogleFonts.dmSans(fontSize: 9, color: subColor)),
              ]),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(color: surfaceAlt, borderRadius: BorderRadius.circular(6), border: Border.all(color: border)),
              child: Text('EN/TA/HI', style: GoogleFonts.spaceMono(fontSize: 9, color: subColor)),
            ),
            const SizedBox(width: 8),
            // New chat
            GestureDetector(
              onTap: () => context.read<ChatProvider>().newChat(),
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: surfaceAlt, borderRadius: BorderRadius.circular(8), border: Border.all(color: border)),
                child: Icon(Icons.add_comment_outlined, size: 16, color: subColor),
              ),
            ),
          ]),
        ),

        //  Voice banner 
        if (_voiceMsg.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: (_voiceError ? AppColors.accentAlt : AppColors.accentGreen).withOpacity(0.1),
            child: Text(_voiceMsg,
              style: GoogleFonts.dmSans(fontSize: 12,
                  color: _voiceError ? AppColors.accentAlt : AppColors.accentGreen)),
          ),

        //  Messages 
        Expanded(
          child: Consumer<ChatProvider>(builder: (_, chat, __) {
            if (chat.loadingHistory) {
              return const Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2));
            }
            WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
            return ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              itemCount: chat.messages.length + (chat.isTyping ? 1 : 0),
              itemBuilder: (ctx, i) {
                if (chat.isTyping && i == chat.messages.length) {
                  return _TypingBubble(surfaceAlt: surfaceAlt);
                }
                return _MessageBubble(
                  message:     chat.messages[i],
                  surfaceAlt:  surfaceAlt,
                  textColor:   textColor,
                  subColor:    subColor,
                  isDeveloper: context.read<AuthProvider>().user?.isDeveloper ?? false,
                );
              },
            );
          }),
        ),

        //  Input 
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(color: surface, border: Border(top: BorderSide(color: border))),
          child: SafeArea(
            top: false,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              VoiceMicButton(onTranscript: _onTranscript, onError: _onVoiceError),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  minLines: 1, maxLines: 4,
                  style: GoogleFonts.dmSans(color: textColor, fontSize: 14),
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'Type or tap 🎤 to speak…',
                    hintStyle: GoogleFonts.dmSans(fontSize: 13, color: subColor),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Consumer<ChatProvider>(
                builder: (_, chat, __) => GestureDetector(
                  onTap: chat.isTyping ? null : () => _send(),
                  child: Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      gradient: chat.isTyping ? null
                          : const LinearGradient(colors: [AppColors.accent, AppColors.accentAlt]),
                      color: chat.isTyping ? AppColors.darkBorder : null,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}


// History Drawer — like ChatGPT sidebar

class _HistoryDrawer extends StatelessWidget {
  final VoidCallback onNewChat;
  final ValueChanged<String> onSelectSession;
  const _HistoryDrawer({required this.onNewChat, required this.onSelectSession});

  @override
  Widget build(BuildContext context) {
    final isDark     = Theme.of(context).brightness == Brightness.dark;
    final surface    = isDark ? AppColors.darkSurface    : AppColors.lightSurface;
    final surfaceAlt = isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurfaceAlt;
    final border     = isDark ? AppColors.darkBorder     : AppColors.lightBorder;
    final textColor  = isDark ? AppColors.darkText       : AppColors.lightText;
    final subColor   = isDark ? AppColors.darkTextSub    : AppColors.lightTextSub;
    final cardColor  = isDark ? AppColors.darkCard       : AppColors.lightCard;

    return Drawer(
      backgroundColor: surface,
      width: 280,
      child: SafeArea(
        child: Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: border))),
            child: Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.accent, AppColors.accentAlt]),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Text('Chat History',
                  style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Icon(Icons.close_rounded, color: subColor, size: 20),
              ),
            ]),
          ),

          // New Chat button
          Padding(
            padding: const EdgeInsets.all(12),
            child: GestureDetector(
              onTap: onNewChat,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.accent, AppColors.accentAlt]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 6),
                  Text('New Chat', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                ]),
              ),
            ),
          ),

          // Sessions list
          Expanded(
            child: Consumer<ChatProvider>(builder: (_, chat, __) {
              if (chat.loadingSessions) {
                return const Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2));
              }
              if (chat.sessions.isEmpty) {
                return Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.chat_bubble_outline_rounded, color: subColor, size: 40),
                    const SizedBox(height: 12),
                    Text('No chats yet\nStart a conversation!',
                        style: GoogleFonts.dmSans(fontSize: 13, color: subColor, height: 1.5),
                        textAlign: TextAlign.center),
                  ]),
                ));
              }

              // Group by time label
              final grouped = <String, List<ChatSession>>{};
              for (final s in chat.sessions) {
                grouped.putIfAbsent(s.timeLabel, () => []).add(s);
              }

              return RefreshIndicator(
                onRefresh: () => chat.loadSessions(),
                color: AppColors.accent,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: [
                    for (final group in grouped.entries) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
                        child: Text(group.key,
                            style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700,
                                color: subColor, letterSpacing: 0.5)),
                      ),
                      for (final session in group.value)
                        _SessionTile(
                          session: session,
                          isActive: chat.activeSessionId == session.id,
                          textColor: textColor,
                          subColor: subColor,
                          cardColor: cardColor,
                          border: border,
                          onTap: () => onSelectSession(session.id),
                          onDelete: () => chat.deleteSessionLocally(session.id),
                        ),
                    ],
                    const SizedBox(height: 20),
                  ],
                ),
              );
            }),
          ),
        ]),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final ChatSession session;
  final bool isActive;
  final Color textColor, subColor, cardColor, border;
  final VoidCallback onTap, onDelete;
  const _SessionTile({required this.session, required this.isActive,
      required this.textColor, required this.subColor, required this.cardColor,
      required this.border, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? AppColors.accent.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? AppColors.accent.withOpacity(0.4) : Colors.transparent,
          ),
        ),
        child: Row(children: [
          Icon(Icons.chat_bubble_outline_rounded,
              size: 15, color: isActive ? AppColors.accent : subColor),
          const SizedBox(width: 10),
          Expanded(child: Text(session.title,
              style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w500,
                  color: isActive ? AppColors.accent : textColor),
              maxLines: 1, overflow: TextOverflow.ellipsis)),
          GestureDetector(
            onTap: onDelete,
            child: Icon(Icons.close_rounded, size: 14, color: subColor),
          ),
        ]),
      ),
    );
  }
}


// Message bubble

class _MessageBubble extends StatefulWidget {
  final ChatMessage message;
  final Color surfaceAlt, textColor, subColor;
  final bool isDeveloper;
  const _MessageBubble({required this.message, required this.surfaceAlt,
      required this.textColor, required this.subColor, this.isDeveloper = false});
  @override State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  bool _showingFlashcards = false;
  bool _loadingCards      = false;
  bool _dismissed         = false;
  List<Map<String, String>> _cards = [];

  Future<void> _generateCards() async {
    final topic = widget.message.topic ?? '';
    if (topic.isEmpty) return;
    setState(() { _loadingCards = true; _dismissed = true; });
    try {
      final raw  = await BedrockService().generateFlashcards(topic);
      final cleaned = raw.replaceAll(RegExp(r'```json|```'), '').trim();
      final data = jsonDecode(cleaned) as Map<String, dynamic>;
      
      // Try multiple locations for cards array
      List? cardsList;
      final dataBlock = data['data'];
      if (dataBlock is Map) {
        cardsList = dataBlock['cards'] as List?;
      }
      cardsList ??= data['cards'] as List?;
      // Also check top-level 'flashcards' key
      cardsList ??= data['flashcards'] as List?;
      
      final cards = cardsList ?? [];
      setState(() {
        _cards = cards.map((c) {
          final m = c as Map<String, dynamic>;
          return {
            'front': m['front'] as String? ?? m['q'] as String? ?? m['term'] as String? ?? '',
            'back':  m['back']  as String? ?? m['a'] as String? ?? m['definition'] as String? ?? '',
          };
        }).where((c) => (c['front'] as String).isNotEmpty).toList();
        _showingFlashcards = _cards.isNotEmpty;
        _loadingCards      = false;
        if (_cards.isEmpty) _dismissed = false; // show button again if no cards
      });
    } catch (_) {
      setState(() { _loadingCards = false; _dismissed = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.isUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.accent, AppColors.accentAlt]),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Main message bubble 
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: isUser
                        ? const LinearGradient(colors: [AppColors.accent, AppColors.accentAlt])
                        : null,
                    color: isUser ? null : widget.surfaceAlt,
                    borderRadius: BorderRadius.only(
                      topLeft:     const Radius.circular(14),
                      topRight:    const Radius.circular(14),
                      bottomLeft:  Radius.circular(isUser ? 14 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 14),
                    ),
                  ),
                  child: isUser
                      ? Text(widget.message.text,
                          style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white, height: 1.5))
                      : MarkdownBody(
                          data: widget.message.text,
                          styleSheet: MarkdownStyleSheet(
                            p:       GoogleFonts.dmSans(fontSize: 14, color: widget.textColor, height: 1.6),
                            strong:  GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: widget.textColor),
                            em:      GoogleFonts.dmSans(fontSize: 14, fontStyle: FontStyle.italic, color: widget.textColor),
                            code:    GoogleFonts.sourceCodePro(fontSize: 12, color: AppColors.accent, backgroundColor: AppColors.codeBg),
                            h1:      GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w800, color: widget.textColor),
                            h2:      GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: widget.textColor),
                            h3:      GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: widget.textColor),
                            listBullet: GoogleFonts.dmSans(fontSize: 14, color: AppColors.accent),
                            codeblockDecoration: BoxDecoration(color: AppColors.codeBg, borderRadius: BorderRadius.circular(8)),
                            codeblockPadding: const EdgeInsets.all(12),
                          ),
                        ),
                ),

                //  Inline mermaid diagram (architecture responses) 
                if (!isUser && widget.message.isArchitecture &&
                    widget.message.mermaid != null && widget.message.mermaid!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _InlineMermaid(mermaidCode: widget.message.mermaid!),
                ],

                //  Flashcard chip (only on concept messages, only in student mode) 
                if (!isUser && widget.message.isConcept && !_dismissed && !_showingFlashcards && !widget.isDeveloper) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    GestureDetector(
                      onTap: _loadingCards ? null : _generateCards,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.3), blurRadius: 8, offset: const Offset(0,3))],
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          _loadingCards
                              ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('🃏', style: TextStyle(fontSize: 13)),
                          const SizedBox(width: 6),
                          Text(
                            _loadingCards ? 'Generating…' : 'Generate Flashcards',
                            style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() => _dismissed = true),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: border.withOpacity(0.5), shape: BoxShape.circle),
                        child: Icon(Icons.close_rounded, size: 12, color: widget.subColor),
                      ),
                    ),
                  ]),
                ],

                //  Inline flashcard deck 
                if (_showingFlashcards && _cards.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : AppColors.lightCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: _InlineFlashcardDeck(cards: _cards),
                  ),
                ],

                const SizedBox(height: 4),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(widget.message.timeFormatted,
                      style: GoogleFonts.dmSans(fontSize: 10, color: widget.subColor)),
                  if (!isUser) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => Clipboard.setData(ClipboardData(text: widget.message.text)),
                      child: Icon(Icons.copy_rounded, size: 13, color: widget.subColor),
                    ),
                    const SizedBox(width: 8),
                    TtsButton(text: widget.message.text),
                  ],
                ]),
              ],
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}


// Typing indicator

class _TypingBubble extends StatelessWidget {
  final Color surfaceAlt;
  const _TypingBubble({required this.surfaceAlt});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.accent, AppColors.accentAlt]),
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: surfaceAlt,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14), topRight: Radius.circular(14),
              bottomRight: Radius.circular(14), bottomLeft: Radius.circular(4),
            ),
          ),
          child: const Row(children: [
            _Dot(delay: 0), SizedBox(width: 4),
            _Dot(delay: 200), SizedBox(width: 4),
            _Dot(delay: 400),
          ]),
        ),
      ]),
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});
  @override State<_Dot> createState() => _DotState();
}
class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600));
  late final Animation<double> _a = Tween<double>(begin: 0.3, end: 1.0)
      .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _c.repeat(reverse: true);
    });
  }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _a,
    child: Container(width: 7, height: 7,
        decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle)),
  );
}


// Inline Flashcard Deck — tap to flip, swipe left/right

class _InlineFlashcardDeck extends StatefulWidget {
  final List<Map<String, String>> cards;
  const _InlineFlashcardDeck({required this.cards});
  @override State<_InlineFlashcardDeck> createState() => _InlineFlashcardDeckState();
}

class _InlineFlashcardDeckState extends State<_InlineFlashcardDeck>
    with SingleTickerProviderStateMixin {
  int    _current = 0;
  bool   _flipped = false;
  double _dragDx  = 0;
  final Set<int> _known    = {};
  final Set<int> _learning = {};

  late final AnimationController _flipCtrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 360));
  late final Animation<double> _flipAnim =
      Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _flipCtrl, curve: Curves.easeInOut));

  @override
  void dispose() { _flipCtrl.dispose(); super.dispose(); }

  void _flip() {
    _flipped ? _flipCtrl.reverse() : _flipCtrl.forward();
    setState(() => _flipped = !_flipped);
  }

  void _advance({required bool knew}) {
    if (knew) {
      _known.add(_current);
    } else {
      _learning.add(_current);
    }
    if (_current < widget.cards.length - 1) {
      _flipCtrl.reset();
      setState(() { _current++; _flipped = false; _dragDx = 0; });
    } else {
      setState(() { _current = 0; _flipped = false; _known.clear(); _learning.clear(); _dragDx = 0; _flipCtrl.reset(); });
    }
  }

  void _onDragEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (_dragDx > 80 || v > 400) {
      _advance(knew: true);
    } else if (_dragDx < -80 || v < -400) _advance(knew: false);
    else setState(() => _dragDx = 0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkText    : AppColors.lightText;
    final subColor  = isDark ? AppColors.darkTextSub  : AppColors.lightTextSub;
    final border    = isDark ? AppColors.darkBorder   : AppColors.lightBorder;
    final total     = widget.cards.length;
    final card      = widget.cards[_current];
    final swipeR    = _dragDx > 40;
    final swipeL    = _dragDx < -40;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Header row
      Row(children: [
        Text('🃏 Flashcards', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w800, color: textColor)),
        const Spacer(),
        if (_current > 0)
          GestureDetector(
            onTap: () => setState(() { _current--; _flipped = false; _flipCtrl.reset(); _dragDx = 0; }),
            child: Icon(Icons.arrow_back_ios_rounded, size: 14, color: subColor),
          ),
        const SizedBox(width: 6),
        Text('${_current + 1}/$total', style: GoogleFonts.spaceMono(fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 8),

      // Progress bar
      ClipRRect(borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: total > 1 ? _current / (total - 1) : 1.0,
          minHeight: 3, backgroundColor: border,
          valueColor: const AlwaysStoppedAnimation(AppColors.accent),
        )),
      const SizedBox(height: 12),

      // Swipe labels
      Row(children: [
        AnimatedOpacity(opacity: swipeL ? 1.0 : 0.0, duration: const Duration(milliseconds: 100),
          child: Text('🔄 Still learning', style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.accentAmber, fontWeight: FontWeight.w700))),
        const Spacer(),
        AnimatedOpacity(opacity: swipeR ? 1.0 : 0.0, duration: const Duration(milliseconds: 100),
          child: Text('✅ Got it!', style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.accentGreen, fontWeight: FontWeight.w700))),
      ]),
      const SizedBox(height: 6),

      // Card
      GestureDetector(
        onTap: _flip,
        onHorizontalDragUpdate: (d) => setState(() => _dragDx += d.delta.dx),
        onHorizontalDragEnd: _onDragEnd,
        child: AnimatedBuilder(
          animation: _flipAnim,
          builder: (_, __) {
            final showFront = _flipAnim.value < 0.5;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..translate(_dragDx, 0.0)
                ..rotateZ(_dragDx * 0.003)
                ..setEntry(3, 2, 0.001)
                ..rotateY(_flipAnim.value * 3.14159265),
              child: showFront
                  ? _MiniCard(
                      label: 'Q${_current + 1}', labelColor: AppColors.accent,
                      text: card['front'] ?? '',
                      hint: 'Tap to flip',
                      colors: const [Color(0xFF1E1B4B), Color(0xFF312E81)],
                      overlay: swipeR ? AppColors.accentGreen.withOpacity(0.25) : swipeL ? AppColors.accentAmber.withOpacity(0.25) : null,
                    )
                  : Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..rotateY(3.14159),
                      child: _MiniCard(
                        label: 'Answer', labelColor: AppColors.accentGreen,
                        text: card['back'] ?? '',
                        hint: 'Swipe → Got it  •  Swipe ← Still learning',
                        colors: const [Color(0xFF052E16), Color(0xFF14532D)],
                        overlay: swipeR ? AppColors.accentGreen.withOpacity(0.25) : swipeL ? AppColors.accentAmber.withOpacity(0.25) : null,
                      ),
                    ),
            );
          },
        ),
      ),
      const SizedBox(height: 12),

      // Buttons (visible after flip)
      if (_flipped)
        Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _advance(knew: false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(color: AppColors.accentAmber.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.accentAmber.withOpacity(0.4))),
                child: Center(child: Text('🔄 Still learning', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accentAmber))),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => _advance(knew: true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(color: AppColors.accentGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.accentGreen.withOpacity(0.4))),
                child: Center(child: Text('✅ Got it!', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accentGreen))),
              ),
            ),
          ),
        ])
      else
        Center(child: Text('Tap card to reveal answer', style: GoogleFonts.dmSans(fontSize: 11, color: subColor))),
    ]);
  }
}

class _MiniCard extends StatelessWidget {
  final String label, text, hint;
  final Color labelColor;
  final List<Color> colors;
  final Color? overlay;
  const _MiniCard({required this.label, required this.labelColor, required this.text, required this.hint, required this.colors, this.overlay});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity, height: 160,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: colors.last.withOpacity(0.3), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: Stack(children: [
        if (overlay != null)
          Container(decoration: BoxDecoration(color: overlay, borderRadius: BorderRadius.circular(16))),
        Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: labelColor.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
              child: Text(label, style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700, color: labelColor)),
            ),
            const Spacer(),
            Text(text, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white, height: 1.4), maxLines: 4, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Text(hint, style: GoogleFonts.dmSans(fontSize: 9, color: Colors.white38)),
          ]),
        ),
      ]),
    );
  }
}


// Inline Mermaid Widget — renders architecture diagram in chat bubble
// Uses mermaid.ink with base64Url encoding + copy fallback

class _InlineMermaid extends StatelessWidget {
  final String mermaidCode;
  const _InlineMermaid({required this.mermaidCode});

  String get _url {
    final encoded = base64Url.encode(utf8.encode(mermaidCode));
    return 'https://mermaid.ink/img/$encoded';
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final border  = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final sub     = isDark ? AppColors.darkTextSub : AppColors.lightTextSub;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Label bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            color: const Color(0xFF6366F1).withOpacity(0.1),
            child: Row(children: [
              const Icon(Icons.account_tree_rounded, size: 13, color: Color(0xFF6366F1)),
              const SizedBox(width: 6),
              Text('Architecture Diagram', style: GoogleFonts.dmSans(
                  fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF6366F1))),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: mermaidCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Mermaid code copied! Paste at mermaid.live',
                        style: GoogleFonts.dmSans(fontSize: 12)),
                        backgroundColor: AppColors.accentGreen,
                        duration: const Duration(seconds: 2)),
                  );
                },
                child: Text('Copy code', style: GoogleFonts.dmSans(
                    fontSize: 10, color: AppColors.accent, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
          // Diagram image
          Image.network(
            _url,
            fit: BoxFit.contain,
            width: double.infinity,
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return Container(
                height: 160, alignment: Alignment.center,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2),
                  const SizedBox(height: 8),
                  Text('Rendering diagram…', style: GoogleFonts.dmSans(fontSize: 11, color: sub)),
                ]),
              );
            },
            errorBuilder: (_, __, ___) => Container(
              height: 100, alignment: Alignment.center,
              color: const Color(0xFFF8F8FF),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('📊', style: TextStyle(fontSize: 28)),
                const SizedBox(height: 6),
                Text('Diagram generated — copy code to view at mermaid.live',
                    style: GoogleFonts.dmSans(fontSize: 11, color: sub), textAlign: TextAlign.center),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}









