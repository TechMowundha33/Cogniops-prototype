import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../services/bedrock_service.dart';
import '../../widgets/common_widgets.dart';

class BackendDesignerScreen extends StatefulWidget {
  const BackendDesignerScreen({super.key});
  @override State<BackendDesignerScreen> createState() => _BackendDesignerScreenState();
}

class _BackendDesignerScreenState extends State<BackendDesignerScreen> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _analyze() async {
    final input = _ctrl.text.trim();
    if (input.isEmpty) return;
    setState(() { _loading = true; _result = null; _error = null; });
    try {
      final raw  = await BedrockService().designBackend(input);
      final data = jsonDecode(raw.replaceAll(RegExp(r'```json|```'), '').trim()) as Map<String, dynamic>;
      setState(() { _result = data; _loading = false; });
    } on BedrockException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Analysis failed — try again.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkText    : AppColors.lightText;
    final subColor  = isDark ? AppColors.darkTextSub  : AppColors.lightTextSub;
    final border    = isDark ? AppColors.darkBorder   : AppColors.lightBorder;
    final card      = isDark ? AppColors.darkCard     : AppColors.lightCard;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Header
        Row(children: [
          Container(width: 42, height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF0EA5E9), Color(0xFF6366F1)]),
              borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.code_rounded, color: Colors.white, size: 22)),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Backend Designer', style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w800, color: textColor)),
            Text('Paste code or describe your app → get AWS backend stack', style: GoogleFonts.dmSans(fontSize: 12, color: subColor)),
          ]),
        ]),
        const SizedBox(height: 20),

        // Input
        Container(
          decoration: BoxDecoration(color: AppColors.codeBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
          child: Column(children: [
            // Code toolbar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white12))),
              child: Row(children: [
                Row(children: [
                  Container(width: 11, height: 11, decoration: const BoxDecoration(color: Color(0xFFFF5F56), shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Container(width: 11, height: 11, decoration: const BoxDecoration(color: Color(0xFFFFBD2E), shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Container(width: 11, height: 11, decoration: const BoxDecoration(color: Color(0xFF27C93F), shape: BoxShape.circle)),
                ]),
                const SizedBox(width: 12),
                Text('paste_code_or_describe.txt', style: GoogleFonts.sourceCodePro(fontSize: 11, color: Colors.white38)),
              ]),
            ),
            TextField(
              controller: _ctrl,
              maxLines: 10, minLines: 5,
              style: GoogleFonts.sourceCodePro(fontSize: 12, color: AppColors.codeText, height: 1.6),
              decoration: InputDecoration(
                hintText: '// Option 1: Paste your code\n// Option 2: Describe your app\n// e.g. "A ride-sharing app with user auth, real-time location, and payment processing"',
                hintStyle: GoogleFonts.sourceCodePro(fontSize: 11, color: subColor.withOpacity(0.4)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 14),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _loading ? null : _analyze,
            icon: _loading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.bolt_rounded, size: 18),
            label: Text(_loading ? 'Analysing…' : 'Analyze & Design Backend ⚡',
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, fontSize: 14)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0EA5E9), foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),

        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.accentAlt.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.accentAlt.withOpacity(0.3))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Text(
                _error!.contains('504') || _error!.contains('timed out')
                    ? '⏱ Timed out — try a shorter description.'
                    : _error!,
                style: GoogleFonts.dmSans(color: AppColors.accentAlt, fontSize: 13))),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _analyze,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.accentAlt.withOpacity(0.2), borderRadius: BorderRadius.circular(7)),
                  child: Text('Retry', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accentAlt)),
                ),
              ),
            ]),
          ),
        ],

        if (_loading) ...[
          const SizedBox(height: 40),
          const Center(child: AppLoader(message: 'Claude is analysing your code…')),
        ],

        if (_result != null) ...[
          const SizedBox(height: 28),

          // Assistant intro
          if ((_result!['assistantText'] as String? ?? '').isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0EA5E9).withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF0EA5E9).withOpacity(0.2)),
              ),
              child: Text(_result!['assistantText'] as String,
                  style: GoogleFonts.dmSans(fontSize: 13, color: textColor, height: 1.6)),
            ),
            const SizedBox(height: 20),
          ],

          // Suggested Services
          _buildSection('☁️ Recommended AWS Services', card, border, textColor,
            child: Wrap(spacing: 8, runSpacing: 8,
              children: ((_result!['suggestedServices'] as List?) ?? []).map((s) {
                final str = s.toString();
                final name = str.contains(' - ') ? str.split(' - ').first : str;
                final desc = str.contains(' - ') ? str.split(' - ').sublist(1).join(' - ') : '';
                return Tooltip(
                  message: desc,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                    ),
                    child: Text(name, style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.w600)),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),

          // API Endpoints
          if ((_result!['apiEndpoints'] as List?)?.isNotEmpty == true) ...[
            _buildSection('🔌 API Endpoints', card, border, textColor,
              child: Column(
                children: ((_result!['apiEndpoints'] as List)).map((e) {
                  final s = e.toString();
                  final method = s.startsWith('POST') ? 'POST'
                      : s.startsWith('GET') ? 'GET'
                      : s.startsWith('PUT') ? 'PUT'
                      : s.startsWith('DELETE') ? 'DELETE' : 'API';
                  final color = method == 'POST' ? const Color(0xFF22C55E)
                      : method == 'GET' ? const Color(0xFF3B82F6)
                      : method == 'PUT' ? const Color(0xFFF59E0B)
                      : const Color(0xFFEF4444);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: color.withOpacity(0.06), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.2))),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(5)),
                        child: Text(method, style: GoogleFonts.sourceCodePro(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(s.replaceFirst(method, '').trim(),
                          style: GoogleFonts.sourceCodePro(fontSize: 12, color: textColor))),
                    ]),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Database
          if ((_result!['db'] as List?)?.isNotEmpty == true) ...[
            _buildSection('🗄️ Database Suggestions', card, border, textColor,
              child: Column(
                children: ((_result!['db'] as List)).map((d) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.storage_rounded, size: 16, color: AppColors.accentGreen),
                    const SizedBox(width: 8),
                    Expanded(child: Text(d.toString(), style: GoogleFonts.dmSans(fontSize: 13, color: textColor, height: 1.4))),
                  ]),
                )).toList(),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Notes
          if ((_result!['notes'] as List?)?.isNotEmpty == true)
            _buildSection('📝 Implementation Notes', card, border, textColor,
              child: Column(
                children: ((_result!['notes'] as List)).asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(width: 20, height: 20,
                        decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), shape: BoxShape.circle),
                        child: Center(child: Text('${e.key+1}', style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.accent, fontWeight: FontWeight.w700)))),
                    const SizedBox(width: 10),
                    Expanded(child: Text(e.value.toString(), style: GoogleFonts.dmSans(fontSize: 13, color: textColor, height: 1.5))),
                  ]),
                )).toList(),
              ),
            ),
        ],
        const SizedBox(height: 80),
      ]),
    );
  }

  Widget _buildSection(String title, Color card, Color border, Color textColor, {required Widget child}) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: textColor)),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }
}