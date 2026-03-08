import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/bedrock_service.dart';
import '../../widgets/common_widgets.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});
  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  // Stages: intro | topic | loading | quiz | results
  String _stage = 'intro';
  String _difficulty = 'Moderate';
  String _topic = 'AWS Core Services';
  final _topicCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  List<Map<String, dynamic>> _questions = [];
  int _current = 0;
  int? _selected;
  bool _answered = false;
  int _score = 0;
  int _timeLeft = 30;
  Timer? _timer;

  static const _difficulties = [
    {'label': 'Easy', 'emoji': '🟢', 'xp': 25, 'desc': 'Definitions & basics'},
    {'label': 'Moderate', 'emoji': '🟡', 'xp': 50, 'desc': 'Best practices & patterns'},
    {'label': 'Hard', 'emoji': '🔴', 'xp': 100, 'desc': 'Edge cases & advanced config'},
  ];

  @override
  void dispose() { _timer?.cancel(); _topicCtrl.dispose(); super.dispose(); }

  void _startTimer() {
    _timer?.cancel();
    _timeLeft = 30;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() { _timeLeft--; });
      if (_timeLeft <= 0) _autoNext();
    });
  }

  void _autoNext() {
    if (_answered) return;
    _timer?.cancel();
    setState(() { _answered = true; _selected = null; });
    Future.delayed(const Duration(seconds: 1), _nextQuestion);
  }

  void _answer(int idx) {
    if (_answered) return;
    _timer?.cancel();
    final correct = _questions[_current]['ans'] as int;
    setState(() {
      _selected = idx;
      _answered = true;
      if (idx == correct) _score++;
    });
    Future.delayed(const Duration(milliseconds: 1400), _nextQuestion);
  }

  void _nextQuestion() {
    if (_current + 1 < _questions.length) {
      setState(() { _current++; _selected = null; _answered = false; });
      _startTimer();
    } else {
      _timer?.cancel();
      final xp = (_difficulties.firstWhere((d) => d['label'] == _difficulty)['xp'] as int);
      final earned = (xp * _score / _questions.length).round();
      context.read<AuthProvider>().addXP(earned);
      setState(() => _stage = 'results');
    }
  }

  Future<void> _loadQuestions() async {
    setState(() { _loading = true; _error = null; });
    try {
      final raw = await BedrockService().generateQuiz(
        topic: _topic,
        difficulty: _difficulty,
        count: 4,
      );
      final json = raw.replaceAll(RegExp(r'```json|```'), '').trim();
      final list = jsonDecode(json) as List;
      setState(() {
        _questions = list.map((q) => Map<String, dynamic>.from(q as Map)).toList();
        _current = 0; _score = 0; _selected = null; _answered = false;
        _loading = false; _stage = 'quiz';
      });
      _startTimer();
    } on BedrockException catch (e) {
      setState(() { _error = e.message; _loading = false; _stage = 'topic'; });
    } catch (e) {
      setState(() { _error = 'Could not generate quiz — try again.'; _loading = false; _stage = 'topic'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subColor = isDark ? AppColors.darkTextSub : AppColors.lightTextSub;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final card = isDark ? AppColors.darkCard : AppColors.lightCard;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: () {
        switch (_stage) {
          case 'intro': return _intro(textColor, subColor, card, border);
          case 'topic': return _topicPicker(textColor, subColor, card, border);
          case 'loading': return const Padding(padding: EdgeInsets.only(top: 80), child: Center(child: AppLoader(message: 'Claude is generating your quiz...')));
          case 'quiz': return _quiz(textColor, subColor, card, border);
          case 'results': return _results(textColor, subColor, card, border);
          default: return _intro(textColor, subColor, card, border);
        }
      }(),
    );
  }

  Widget _intro(Color text, Color sub, Color card, Color border) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Smart Quiz', style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w800, color: text)),
      const SizedBox(height: 4),
      Text('CogniOps generates fresh questions on any cloud topic.', style: GoogleFonts.dmSans(fontSize: 13, color: sub)),
      const SizedBox(height: 24),
      Text('Choose Difficulty', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: text)),
      const SizedBox(height: 10),
      ..._difficulties.map((d) {
        final sel = d['label'] == _difficulty;
        return GestureDetector(
          onTap: () => setState(() => _difficulty = d['label'] as String),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: sel ? AppColors.accent.withOpacity(0.08) : card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: sel ? AppColors.accent : border),
            ),
            child: Row(children: [
              Text(d['emoji'] as String, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d['label'] as String, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: text)),
                Text(d['desc'] as String, style: GoogleFonts.dmSans(fontSize: 12, color: sub)),
              ])),
              ColorBadge(label: '+${d['xp']} XP', color: AppColors.accentGreen),
            ]),
          ),
        );
      }),
      const SizedBox(height: 20),
      GradientButton(label: 'Next: Choose Topic →', width: double.infinity, onTap: () => setState(() => _stage = 'topic')),
    ]);
  }

  Widget _topicPicker(Color text, Color sub, Color card, Color border) {
    final topics = ['AWS Core Services', 'Serverless & Lambda', 'Networking & VPC', 'Security & IAM', 'Containers & ECS/EKS', 'Storage & S3', 'Databases', 'DevOps & CI/CD'];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Choose Topic', style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w800, color: text)),
      const SizedBox(height: 4),
      Text('Or enter a custom topic below.', style: GoogleFonts.dmSans(fontSize: 13, color: sub)),
      if (_error != null) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.accentAlt.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.accentAlt.withOpacity(0.3))),
          child: Text(_error!, style: GoogleFonts.dmSans(color: AppColors.accentAlt, fontSize: 12)),
        ),
      ],
      const SizedBox(height: 16),
      Wrap(spacing: 8, runSpacing: 8, children: topics.map((t) {
        final sel = t == _topic;
        return GestureDetector(
          onTap: () => setState(() { _topic = t; _topicCtrl.clear(); }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: sel ? AppColors.accent.withOpacity(0.12) : card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: sel ? AppColors.accent : border),
            ),
            child: Text(t, style: GoogleFonts.dmSans(fontSize: 12, color: sel ? AppColors.accent : sub, fontWeight: FontWeight.w600)),
          ),
        );
      }).toList()),
      const SizedBox(height: 16),
      TextField(
        controller: _topicCtrl,
        style: GoogleFonts.dmSans(color: text),
        decoration: const InputDecoration(hintText: 'Custom topic, e.g. CloudFormation', prefixIcon: Icon(Icons.edit_rounded, size: 18)),
        onChanged: (v) { if (v.isNotEmpty) setState(() => _topic = v); },
      ),
      const SizedBox(height: 20),
      GradientButton(label: 'Start $_difficulty Quiz 🚀', width: double.infinity, onTap: () { setState(() => _stage = 'loading'); _loadQuestions(); }),
    ]);
  }

  Widget _quiz(Color text, Color sub, Color card, Color border) {
    if (_questions.isEmpty) return const SizedBox.shrink();
    final q = _questions[_current];
    final opts = (q['opts'] as List).cast<String>();
    final correct = q['ans'] as int;
    final explanation = q['explanation'] as String? ?? '';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('$_difficulty · Q${_current + 1}/${_questions.length}', style: GoogleFonts.spaceMono(fontSize: 11, color: sub)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _timeLeft <= 10 ? AppColors.accentAlt.withOpacity(0.15) : AppColors.accentGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('⏱ $_timeLeft s', style: GoogleFonts.spaceMono(fontSize: 11, color: _timeLeft <= 10 ? AppColors.accentAlt : AppColors.accentGreen, fontWeight: FontWeight.w700)),
        ),
      ]),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: (_current + 1) / _questions.length,
          backgroundColor: AppColors.accent.withOpacity(0.1),
          valueColor: const AlwaysStoppedAnimation(AppColors.accent),
          minHeight: 4,
        ),
      ),
      const SizedBox(height: 20),
      Text(q['q'] as String? ?? '', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: text, height: 1.4)),
      const SizedBox(height: 18),
      ...opts.asMap().entries.map((e) {
        final i = e.key;
        final opt = e.value;
        Color? bg, bc;
        if (_answered) {
          if (i == correct) { bg = AppColors.accentGreen.withOpacity(0.12); bc = AppColors.accentGreen; }
          else if (i == _selected && i != correct) { bg = AppColors.accentAlt.withOpacity(0.12); bc = AppColors.accentAlt; }
        }
        return GestureDetector(
          onTap: _answered ? null : () => _answer(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: bg ?? card, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: bc ?? border),
            ),
            child: Row(children: [
              Container(
                width: 26, height: 26,
                decoration: BoxDecoration(
                  color: (bc ?? AppColors.accent).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(child: Text(String.fromCharCode(65 + i), style: GoogleFonts.spaceMono(fontSize: 11, color: bc ?? sub, fontWeight: FontWeight.w700))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(opt, style: GoogleFonts.dmSans(fontSize: 13, color: text))),
              if (_answered && i == correct) const Icon(Icons.check_circle_rounded, color: AppColors.accentGreen, size: 18),
              if (_answered && i == _selected && i != correct) const Icon(Icons.cancel_rounded, color: AppColors.accentAlt, size: 18),
            ]),
          ),
        );
      }),
      if (_answered && explanation.isNotEmpty) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.06), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.accent.withOpacity(0.2))),
          child: Text('💡 $explanation', style: GoogleFonts.dmSans(fontSize: 12, color: text, height: 1.4)),
        ),
      ],
    ]);
  }

  Widget _results(Color text, Color sub, Color card, Color border) {
    final pct = (_score / _questions.length * 100).round();
    final String emoji = pct >= 75 ? '🎉' : pct >= 50 ? '👍' : '💪';
    final String msg = pct >= 75 ? 'Excellent work!' : pct >= 50 ? 'Good effort!' : 'Keep practising!';
    final xp = (_difficulties.firstWhere((d) => d['label'] == _difficulty)['xp'] as int);
    final earned = (xp * _score / _questions.length).round();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(child: Text(emoji, style: const TextStyle(fontSize: 56))),
      const SizedBox(height: 12),
      Center(child: Text(msg, style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w800, color: text))),
      const SizedBox(height: 4),
      Center(child: Text('$_score/${_questions.length} correct · $pct%', style: GoogleFonts.dmSans(fontSize: 14, color: sub))),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _stat('$_score', 'Correct', AppColors.accentGreen),
          _stat('${_questions.length - _score}', 'Wrong', AppColors.accentAlt),
          _stat('+$earned', 'XP Earned', AppColors.accent),
        ]),
      ),
      const SizedBox(height: 20),
      GradientButton(label: 'Try Another Quiz 🔁', width: double.infinity, onTap: () => setState(() { _stage = 'intro'; _questions = []; })),
      const SizedBox(height: 10),
      GestureDetector(
        onTap: () { setState(() { _stage = 'topic'; }); _loadQuestions(); },
        child: Container(
          height: 44, alignment: Alignment.center,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: border)),
          child: Text('Same Topic, New Questions', style: GoogleFonts.dmSans(color: sub, fontWeight: FontWeight.w500)),
        ),
      ),
    ]);
  }

  Widget _stat(String val, String lbl, Color c) {
    return Column(children: [
      Text(val, style: GoogleFonts.spaceMono(fontSize: 22, fontWeight: FontWeight.w700, color: c)),
      Text(lbl, style: GoogleFonts.dmSans(fontSize: 11, color: c.withOpacity(0.8))),
    ]);
  }
}




