import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../services/bedrock_service.dart';
import '../../widgets/common_widgets.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});
  @override State<DebugScreen> createState() => _DebugScreenState();
}

class _Msg { final String text; final bool isUser; _Msg({required this.text, required this.isUser}); }

class _DebugScreenState extends State<DebugScreen> {
  final _errorCtrl   = TextEditingController();
  final _replyCtrl   = TextEditingController();
  final _scrollCtrl  = ScrollController();
  bool   _started    = false;
  bool   _loading    = false;
  String? _initError;
  final List<_Msg> _msgs = [];
  String _originalError = '';

  @override
  void dispose() { _errorCtrl.dispose(); _replyCtrl.dispose(); _scrollCtrl.dispose(); super.dispose(); }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _startSession() async {
    if (_errorCtrl.text.trim().isEmpty) return;
    _originalError = _errorCtrl.text.trim();
    setState(() { _loading = true; _initError = null; _started = true; _msgs.clear(); });
    try {
      final reply = await BedrockService().socratiDebug(
        errorDescription: _originalError, conversationHistory: []);
      setState(() { _msgs.add(_Msg(text: reply, isUser: false)); _loading = false; });
      _scrollToBottom();
    } on BedrockException catch (e) {
      setState(() { _initError = e.message; _loading = false; _started = false; });
    } catch (e) {
      setState(() { _initError = 'Debug session failed — try again.'; _loading = false; _started = false; });
    }
  }

  Future<void> _sendReply() async {
    if (_replyCtrl.text.trim().isEmpty) return;
    final text = _replyCtrl.text.trim();
    _replyCtrl.clear();
    setState(() { _msgs.add(_Msg(text: text, isUser: true)); _loading = true; });
    _scrollToBottom();
    try {
      final history = _msgs.map((m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.text}).toList();
      final response = await BedrockService().socratiDebug(
        errorDescription: _originalError, conversationHistory: history);
      setState(() { _msgs.add(_Msg(text: response, isUser: false)); _loading = false; });
      _scrollToBottom();
    } catch (_) {
      setState(() { _loading = false; });
    }
  }

  void _clear() => setState(() { _started = false; _msgs.clear(); _errorCtrl.clear(); _originalError = ''; });

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkText    : AppColors.lightText;
    final subColor  = isDark ? AppColors.darkTextSub  : AppColors.lightTextSub;
    final border    = isDark ? AppColors.darkBorder   : AppColors.lightBorder;
    final card      = isDark ? AppColors.darkCard     : AppColors.lightCard;
    final surface   = isDark ? AppColors.darkSurface  : AppColors.lightSurface;
    final surfaceAlt= isDark ? AppColors.darkSurfaceAlt: AppColors.lightSurfaceAlt;

    return Column(children: [
      // ── Header ──────────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        decoration: BoxDecoration(color: surface, border: Border(bottom: BorderSide(color: border))),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFDC2626), Color(0xFFEA580C)]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.bug_report_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Debug Session', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800, color: textColor)),
            Text('Socratic AI debugging — describe your error to get diagnosed',
                style: GoogleFonts.dmSans(fontSize: 11, color: subColor)),
          ])),
          if (_started)
            GestureDetector(
              onTap: _clear,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: AppColors.accentAlt.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.accentAlt.withOpacity(0.3))),
                child: Text('Clear', style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.accentAlt, fontWeight: FontWeight.w700)),
              ),
            ),
        ]),
      ),

      // ── Input (only shown before session starts) ───────────────
      if (!_started) ...[
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              // Tips
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.accentAmber.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.accentAmber.withOpacity(0.25)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('💡', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Tips for best results', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: textColor)),
                    const SizedBox(height: 6),
                    ...['Include the exact error message or HTTP status code',
                        'Mention the AWS service involved (Lambda, EC2, S3…)',
                        'Describe what you expected vs what happened',
                    ].map((t) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('• ', style: GoogleFonts.dmSans(color: AppColors.accentAmber)),
                        Expanded(child: Text(t, style: GoogleFonts.dmSans(fontSize: 12, color: subColor, height: 1.4))),
                      ]),
                    )),
                  ])),
                ]),
              ),
              const SizedBox(height: 20),

              // Error input
              Container(
                decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  TextField(
                    controller: _errorCtrl,
                    minLines: 4, maxLines: 8,
                    style: GoogleFonts.dmSans(color: textColor, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'e.g. "My Lambda function is returning 403 when calling S3. Error: Access Denied on PutObject"',
                      hintStyle: GoogleFonts.dmSans(fontSize: 12, color: subColor),
                      border: InputBorder.none,
                    ),
                  ),
                  if (_initError != null) ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: Text(
                        _initError!.contains('504') || _initError!.contains('timed out')
                            ? '⏱ Timed out — describe error more briefly.'
                            : _initError!,
                        style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.accentAlt))),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _startSession,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: AppColors.accentAlt.withOpacity(0.15), borderRadius: BorderRadius.circular(7)),
                          child: Text('Retry', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.accentAlt)),
                        ),
                      ),
                    ]),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _startSession,
                      icon: _loading
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.search_rounded, size: 18),
                      label: Text(_loading ? 'Analysing…' : 'Start Debug Session 🔍',
                          style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, fontSize: 14)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ] else ...[
        // ── Conversation ─────────────────────────────────────────
        Expanded(
          child: ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            itemCount: _msgs.length + (_loading ? 1 : 0),
            itemBuilder: (_, i) {
              if (_loading && i == _msgs.length) {
                return _typingBubble(surfaceAlt);
              }
              final m = _msgs[i];
              return _bubble(m, textColor, subColor, surfaceAlt, card);
            },
          ),
        ),

        // ── Reply input ──────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(color: surface, border: Border(top: BorderSide(color: border))),
          child: SafeArea(
            top: false,
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _replyCtrl,
                  minLines: 1, maxLines: 3,
                  style: GoogleFonts.dmSans(color: textColor, fontSize: 14),
                  onSubmitted: (_) => _sendReply(),
                  decoration: InputDecoration(
                    hintText: 'Answer CogniOps\'s question…',
                    hintStyle: GoogleFonts.dmSans(fontSize: 13, color: subColor),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _loading ? null : _sendReply,
                child: Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    gradient: _loading ? null : const LinearGradient(colors: [Color(0xFFDC2626), Color(0xFFEA580C)]),
                    color: _loading ? AppColors.darkBorder : null,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ),
            ]),
          ),
        ),
      ],
    ]);
  }

  Widget _bubble(_Msg m, Color textColor, Color subColor, Color surfaceAlt, Color card) {
    final isUser = m.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFDC2626), Color(0xFFEA580C)]),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.bug_report_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: isUser ? const LinearGradient(colors: [AppColors.accent, AppColors.accentAlt]) : null,
                color: isUser ? null : surfaceAlt,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14), topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(isUser ? 14 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 14),
                ),
              ),
              child: isUser
                  ? Text(m.text, style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white, height: 1.5))
                  : MarkdownBody(
                      data: m.text,
                      styleSheet: MarkdownStyleSheet(
                        p:          GoogleFonts.dmSans(fontSize: 14, color: textColor, height: 1.7),
                        strong:     GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: textColor),
                        listBullet: GoogleFonts.dmSans(fontSize: 14, color: const Color(0xFFDC2626)),
                        h3:         GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: textColor),
                        blockSpacing: 12,
                        listIndent:   20,
                        code: GoogleFonts.sourceCodePro(fontSize: 12, color: AppColors.accent, backgroundColor: AppColors.codeBg),
                        codeblockDecoration: BoxDecoration(color: AppColors.codeBg, borderRadius: BorderRadius.circular(8)),
                        codeblockPadding: const EdgeInsets.all(12),
                      ),
                    ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _typingBubble(Color surfaceAlt) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(children: [
        Container(width: 32, height: 32,
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFDC2626), Color(0xFFEA580C)]), borderRadius: BorderRadius.circular(9)),
            child: const Icon(Icons.bug_report_rounded, color: Colors.white, size: 16)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: surfaceAlt, borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(14), topRight: Radius.circular(14),
            bottomRight: Radius.circular(14), bottomLeft: Radius.circular(4))),
          child: Row(children: [
            _Dot(delay: 0), const SizedBox(width: 4),
            _Dot(delay: 200), const SizedBox(width: 4),
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
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
  late final Animation<double>   _a = Tween(begin: 0.3, end: 1.0).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  @override void initState() { super.initState(); Future.delayed(Duration(milliseconds: widget.delay), () { if (mounted) _c.repeat(reverse: true); }); }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => FadeTransition(opacity: _a,
    child: Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFFDC2626), shape: BoxShape.circle)));
}