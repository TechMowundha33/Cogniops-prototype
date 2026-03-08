import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../services/bedrock_service.dart';
import '../../widgets/common_widgets.dart';

class ConceptScreen extends StatefulWidget {
  const ConceptScreen({super.key});
  @override
  State<ConceptScreen> createState() => _ConceptScreenState();
}

class _ConceptScreenState extends State<ConceptScreen> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;
  bool _askFlash = false;
  List<Map<String, String>>? _flashcards;
  final Set<int> _flipped = {};

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _explain() async {
    if (_ctrl.text.trim().isEmpty) return;
    setState(() { _loading = true; _result = null; _flashcards = null; _askFlash = false; _error = null; });
    try {
      final raw = await BedrockService().explainConcept(_ctrl.text.trim());
      final json = raw.replaceAll(RegExp(r'```json|```'), '').trim();
      final data = jsonDecode(json) as Map<String, dynamic>;
      setState(() {
        _result = data;
        _loading = false;
        _askFlash = data.containsKey('flashcards') && (data['flashcards'] as List).isNotEmpty;
        // If flashcards already returned, use them
        if (_askFlash) {
          _flashcards = (data['flashcards'] as List)
              .map((f) => Map<String, String>.from(f as Map))
              .toList();
          _askFlash = false;
        }
      });
    } on BedrockException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Parsing error — please try again.'; _loading = false; });
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Concept Explainer', style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w800, color: textColor)),
        const SizedBox(height: 4),
        Text('Enter any cloud concept and CogniOps will break it down for you.',
            style: GoogleFonts.dmSans(fontSize: 13, color: subColor)),
        const SizedBox(height: 20),

        // Input row
        Row(children: [
          GestureDetector(
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Voice input — add speech_to_text plugin'))),
            child: Container(
              padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.accent.withOpacity(0.3))),
              child: const Icon(Icons.mic_rounded, color: AppColors.accent, size: 20),
            ),
          ),
          Expanded(child: TextField(
            controller: _ctrl, style: GoogleFonts.dmSans(color: textColor),
            decoration: const InputDecoration(hintText: 'e.g. AWS VPC Peering'),
            onSubmitted: (_) => _explain(),
          )),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _loading ? null : _explain,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.accent, AppColors.accentAlt]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: _loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
            ),
          ),
        ]),

        if (_error != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.accentAlt.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.accentAlt.withOpacity(0.3))),
            child: Text(_error!, style: GoogleFonts.dmSans(color: AppColors.accentAlt, fontSize: 13)),
          ),
        ],

        if (_loading) ...[
          const SizedBox(height: 60),
          const Center(child: AppLoader(message: 'CogniOps is explaining...')),
        ],

        if (_result != null) ...[
          const SizedBox(height: 24),
          Text(_result!['title'] as String? ?? _ctrl.text,
              style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w800, color: textColor)),
          const SizedBox(height: 6),
          Text(_result!['summary'] as String? ?? '',
              style: GoogleFonts.dmSans(fontSize: 13, color: subColor, height: 1.5)),
          const SizedBox(height: 16),

          // Sections
          ...(_result!['sections'] as List? ?? []).asMap().entries.map((e) {
            final s = e.value as Map<String, dynamic>;
            final colors = [AppColors.accent, AppColors.accentGreen, AppColors.accentAmber, AppColors.accentAlt];
            final c = colors[e.key % colors.length];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                  child: Text(s['title'] as String? ?? '', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: c)),
                ),
                const SizedBox(height: 8),
                Text(s['content'] as String? ?? '', style: GoogleFonts.dmSans(fontSize: 13, color: textColor, height: 1.5)),
              ]),
            );
          }),
        ],

        // Flashcards section
        if (_flashcards != null && _flashcards!.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Flashcards', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800, color: textColor)),
          const SizedBox(height: 4),
          Text('Tap to reveal the answer', style: GoogleFonts.dmSans(fontSize: 12, color: subColor)),
          const SizedBox(height: 12),
          ..._flashcards!.asMap().entries.map((e) {
            final i = e.key;
            final fc = e.value;
            final flipped = _flipped.contains(i);
            return GestureDetector(
              onTap: () => setState(() { flipped ? _flipped.remove(i) : _flipped.add(i); }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: flipped ? AppColors.accent.withOpacity(0.1) : card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: flipped ? AppColors.accent.withOpacity(0.4) : border),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    ColorBadge(label: flipped ? 'Answer' : 'Q${i + 1}', color: flipped ? AppColors.accentGreen : AppColors.accent),
                    const Spacer(),
                    Icon(flipped ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 16, color: subColor),
                  ]),
                  const SizedBox(height: 10),
                  Text(flipped ? (fc['a'] ?? '') : (fc['q'] ?? ''),
                      style: GoogleFonts.dmSans(fontSize: 13, color: flipped ? textColor : textColor, fontWeight: flipped ? FontWeight.w500 : FontWeight.w400, height: 1.4)),
                ]),
              ),
            );
          }),
        ],

        const SizedBox(height: 80),
      ]),
    );
  }
}
