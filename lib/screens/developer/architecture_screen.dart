import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../services/bedrock_service.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/voice_recorder.dart';

class ArchitectureScreen extends StatefulWidget {
  const ArchitectureScreen({super.key});
  @override State<ArchitectureScreen> createState() => _ArchitectureScreenState();
}

class _ArchitectureScreenState extends State<ArchitectureScreen>
    with SingleTickerProviderStateMixin {
  final _ctrl = TextEditingController();
  late final TabController _tabs = TabController(length: 4, vsync: this);

  // Loading states — each tab loads independently
  bool _loadingArch      = false;
  bool _loadingTerraform = false;
  bool _loadingCost      = false;

  String? _error;

  // Results
  Map<String, dynamic>? _archResult;   // overview + diagram
  String?               _terraformHcl;
  List                  _tfNotes     = [];
  Map<String, dynamic>? _costResult;

  // Chat history for this architecture session
  final List<Map<String, String>> _chatHistory = [];

  @override
  void dispose() { _ctrl.dispose(); _tabs.dispose(); super.dispose(); }

  String _mermaidUrl(String code) =>
      'https://mermaid.ink/img/${base64Url.encode(utf8.encode(code))}';

  // ── Step 1: Generate Architecture + Diagram ───────────────────────────────
  Future<void> _generateArchitecture() async {
    if (_ctrl.text.trim().isEmpty) return;
    setState(() {
      _loadingArch = true; _error = null;
      _archResult = null; _terraformHcl = null; _costResult = null;
      _chatHistory.clear();
    });
    _tabs.animateTo(0);
    try {
      final raw  = await BedrockService().generateArchitecture(_ctrl.text.trim());
      final data = jsonDecode(raw.replaceAll(RegExp(r'```json|```'), '').trim())
          as Map<String, dynamic>;
      _chatHistory.add({'role': 'user', 'content': _ctrl.text.trim()});
      _chatHistory.add({'role': 'assistant', 'content': data['assistantText'] as String? ?? ''});
      setState(() { _archResult = data; _loadingArch = false; });
      // Auto-kick terraform + cost in background
      _generateTerraform();
      _generateCost();
    } on BedrockException catch (e) {
      setState(() { _error = e.message; _loadingArch = false; });
    } catch (e) {
      setState(() { _error = 'Generation failed — try rephrasing.'; _loadingArch = false; });
    }
  }

  // ── Step 2: Generate Terraform (separate call) ────────────────────────────
  Future<void> _generateTerraform() async {
    if (_archResult == null) return;
    setState(() { _loadingTerraform = true; });
    try {
      final services = (_archResult!['services'] as List? ?? [])
          .map((s) => s is Map ? (s['name'] as String? ?? s.toString()) : s.toString())
          .where((s) => s.isNotEmpty).join(', ');
      final prompt = 'Generate Terraform HCL for: ${_ctrl.text.trim()}. AWS services: $services';
      final raw  = await BedrockService().generateTerraform(prompt);
      final data = jsonDecode(raw) as Map<String, dynamic>;
      String hcl = (data['terraform'] as String? ?? '')
          .replaceAll('\\n', '\n').replaceAll('\\"', '"').replaceAll('\\\\', '\\')
          .replaceAll(RegExp(r'```hcl|```terraform|```'), '').trim();
      setState(() {
        _terraformHcl = hcl.isNotEmpty ? hcl : '# No Terraform generated';
        _tfNotes = data['notes'] as List? ?? [];
        _loadingTerraform = false;
      });
    } catch (_) {
      setState(() { _terraformHcl = '# Terraform generation failed — tap retry'; _loadingTerraform = false; });
    }
  }

  // ── Step 3: Generate Cost (separate call) ─────────────────────────────────
  Future<void> _generateCost() async {
    if (_archResult == null) return;
    setState(() { _loadingCost = true; });
    try {
      final services = (_archResult!['services'] as List? ?? [])
          .map((s) => s is Map ? (s['name'] as String? ?? s.toString()) : s.toString())
          .where((s) => s.isNotEmpty).join(', ');
      final raw  = await BedrockService().estimateCost(
          'App: ${_ctrl.text.trim()}. AWS services used: $services');
      final data = jsonDecode(raw) as Map<String, dynamic>;
      setState(() { _costResult = data; _loadingCost = false; });
    } catch (_) {
      setState(() { _loadingCost = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkText    : AppColors.lightText;
    final subColor  = isDark ? AppColors.darkTextSub  : AppColors.lightTextSub;
    final border    = isDark ? AppColors.darkBorder   : AppColors.lightBorder;
    final card      = isDark ? AppColors.darkCard     : AppColors.lightCard;

    return Column(children: [
      // ── Input header ──────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          border: Border(bottom: BorderSide(color: border)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFFEC4899)]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.architecture_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Architecture Generator',
                  style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800, color: textColor)),
              Text('Describe your app → get architecture, diagram, Terraform & cost',
                  style: GoogleFonts.dmSans(fontSize: 11, color: subColor)),
            ]),
          ]),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(12), border: Border.all(color: border)),
            child: TextField(
              controller: _ctrl,
              maxLines: 3, minLines: 2,
              style: GoogleFonts.dmSans(color: textColor, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'e.g. A food delivery app with real-time tracking, user auth, payments and driver dashboard',
                hintStyle: GoogleFonts.dmSans(fontSize: 12, color: subColor),
                contentPadding: const EdgeInsets.all(14),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loadingArch ? null : _generateArchitecture,
              icon: _loadingArch
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.bolt_rounded, size: 18),
              label: Text(_loadingArch ? 'Designing Architecture…' : 'Generate Architecture ⚡',
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, fontSize: 14)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.accentAlt.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.accentAlt.withOpacity(0.3))),
              child: Text(_error!, style: GoogleFonts.dmSans(color: AppColors.accentAlt, fontSize: 12)),
            ),
          ],
        ]),
      ),

      // ── Tabs (only shown after generation) ───────────────────────
      if (_archResult != null || _loadingArch) ...[
        Container(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          child: TabBar(
            controller: _tabs,
            isScrollable: false,
            labelColor: AppColors.accent,
            unselectedLabelColor: subColor,
            indicatorColor: AppColors.accent,
            indicatorWeight: 2,
            labelStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w700, fontSize: 12),
            unselectedLabelStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w500, fontSize: 12),
            tabs: [
              const Tab(text: '🏗 Overview'),
              const Tab(text: '📊 Diagram'),
              Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Text('⚙️ Terraform'),
                if (_loadingTerraform) ...[const SizedBox(width: 4), const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.accent))],
              ])),
              Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Text('💰 Cost'),
                if (_loadingCost) ...[const SizedBox(width: 4), const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.accent))],
              ])),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(controller: _tabs, children: [
            _loadingArch ? const Center(child: AppLoader(message: 'Designing architecture…')) : _overviewTab(textColor, subColor, card, border),
            _loadingArch ? const Center(child: AppLoader(message: 'Generating diagram…'))    : _diagramTab(textColor, subColor, card, border),
            _terraformTab(textColor, subColor, card, border),
            _costTab(textColor, subColor, card, border),
          ]),
        ),
      ] else
        Expanded(
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.architecture_rounded, size: 64, color: subColor.withOpacity(0.3)),
              const SizedBox(height: 16),
              Text('Describe your app above to generate\na complete AWS architecture',
                  style: GoogleFonts.dmSans(fontSize: 14, color: subColor, height: 1.5),
                  textAlign: TextAlign.center),
            ]),
          ),
        ),
    ]);
  }

  // ── Overview Tab ─────────────────────────────────────────────────────────
  Widget _overviewTab(Color text, Color sub, Color card, Color border) {
    if (_archResult == null) return const SizedBox();
    final summary  = (_archResult!['assistantText'] as String? ??
                      _archResult!['architectureSummary'] as String? ?? '').trim();
    final services = (_archResult!['services'] as List? ?? []);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Summary card
        if (summary.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.accent.withOpacity(0.07), AppColors.accentAlt.withOpacity(0.04)]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.accent.withOpacity(0.2)),
            ),
            child: MarkdownBody(
              data: summary, selectable: true,
              styleSheet: MarkdownStyleSheet(
                p:          GoogleFonts.dmSans(fontSize: 13, color: text, height: 1.6),
                strong:     GoogleFonts.dmSans(fontSize: 13, color: text, fontWeight: FontWeight.w700),
                listBullet: GoogleFonts.dmSans(fontSize: 13, color: AppColors.accent),
                h3:         GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: text),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],

        // AWS Services grid
        if (services.isNotEmpty) ...[
          Text('AWS Services Used',
              style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w800, color: text)),
          const SizedBox(height: 12),
          ...services.map((s) {
            final name    = s is Map ? (s['name'] as String? ?? s.toString()) : s.toString();
            final purpose = s is Map ? (s['purpose'] as String? ?? s['description'] as String? ?? '') : '';
            final emoji   = s is Map ? (s['emoji'] as String? ?? '☁️') : '☁️';
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: card, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: border),
              ),
              child: Row(children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(child: Text(emoji, style: const TextStyle(fontSize: 20))),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: text)),
                  if (purpose.isNotEmpty)
                    Text(purpose, style: GoogleFonts.dmSans(fontSize: 11, color: sub, height: 1.4)),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accentGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('AWS', style: GoogleFonts.dmSans(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.accentGreen)),
                ),
              ]),
            );
          }),
        ],

        // If services is plain string list (Lambda returns strings not objects)
        if (services.isEmpty) ...[
          // Try assistantText line-by-line
          ...summary.split('\n').where((l) => l.trim().startsWith('-')).map((l) =>
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(10), border: Border.all(color: border)),
              child: Row(children: [
                const Text('☁️', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(child: Text(l.trim().replaceFirst('-', '').trim(),
                    style: GoogleFonts.dmSans(fontSize: 13, color: text))),
              ]),
            )),
        ],
        const SizedBox(height: 80),
      ]),
    );
  }

  // ── Diagram Tab ──────────────────────────────────────────────────────────
  Widget _diagramTab(Color text, Color sub, Color card, Color border) {
    final mermaid = _archResult?['mermaid'] as String? ?? '';
    final diagUrl = _archResult?['diagramUrl'] as String? ?? '';
    final url     = diagUrl.isNotEmpty ? diagUrl
        : mermaid.isNotEmpty ? _mermaidUrl(mermaid) : '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Architecture Diagram',
              style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w800, color: text)),
          const Spacer(),
          if (mermaid.isNotEmpty)
            GestureDetector(
              onTap: () { Clipboard.setData(ClipboardData(text: mermaid));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Mermaid code copied!', style: GoogleFonts.dmSans()), duration: const Duration(seconds: 2)));
              },
              child: Row(children: [
                const Icon(Icons.copy_rounded, size: 13, color: AppColors.accent),
                const SizedBox(width: 4),
                Text('Copy code', style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.w600)),
              ]),
            ),
        ]),
        const SizedBox(height: 14),

        if (url.isNotEmpty) ...[
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 4))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _MermaidDiagramWidget(
                mermaidCode: mermaid,
                diagramUrl:  url,
                sub: sub, card: card, border: border,
                onFallback: () => _diagramFallback(mermaid, text, sub, card, border),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // View raw Mermaid code
          Container(
            decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(10), border: Border.all(color: border)),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              title: Text('View Mermaid Code', style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.w600)),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: const BoxDecoration(color: AppColors.codeBg, borderRadius: BorderRadius.vertical(bottom: Radius.circular(10))),
                  child: SelectableText(mermaid, style: GoogleFonts.sourceCodePro(fontSize: 11, color: AppColors.codeText, height: 1.6)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Open in mermaid.live
          GestureDetector(
            onTap: () {
              final encoded = base64Url.encode(utf8.encode(mermaid));
              Clipboard.setData(ClipboardData(text: 'https://mermaid.live/edit#base64:$encoded'));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('mermaid.live link copied — open in browser!', style: GoogleFonts.dmSans()), duration: const Duration(seconds: 3)));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.accent.withOpacity(0.4)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.open_in_new_rounded, size: 14, color: AppColors.accent),
                const SizedBox(width: 6),
                Text('Open in mermaid.live for full-screen view',
                    style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ] else
          _diagramFallback('', text, sub, card, border),

        const SizedBox(height: 80),
      ]),
    );
  }

  Widget _diagramFallback(String mermaid, Color text, Color sub, Color card, Color border) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
      child: Column(children: [
        const Icon(Icons.account_tree_rounded, color: AppColors.accent, size: 40),
        const SizedBox(height: 12),
        Text('Diagram rendering unavailable', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: text)),
        const SizedBox(height: 6),
        Text('Copy the Mermaid code and paste it at mermaid.live to view your diagram',
            style: GoogleFonts.dmSans(fontSize: 12, color: sub, height: 1.5), textAlign: TextAlign.center),
        if (mermaid.isNotEmpty) ...[
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () { Clipboard.setData(ClipboardData(text: mermaid));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied!')));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.accent, AppColors.accentAlt]), borderRadius: BorderRadius.circular(8)),
              child: Text('Copy Mermaid Code', style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ),
        ],
      ]),
    );
  }

  // ── Terraform Tab ────────────────────────────────────────────────────────
  Widget _terraformTab(Color text, Color sub, Color card, Color border) {
    if (_loadingTerraform) {
      return const Center(child: AppLoader(message: 'Generating Terraform HCL…'));
    }
    if (_terraformHcl == null) {
      return Center(child: Text('Generate architecture first', style: GoogleFonts.dmSans(fontSize: 13, color: sub)));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Terraform HCL', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w800, color: text)),
          const Spacer(),
          GestureDetector(
            onTap: () { Clipboard.setData(ClipboardData(text: _terraformHcl!));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied!')));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(7), border: Border.all(color: AppColors.accent.withOpacity(0.3))),
              child: Row(children: [
                const Icon(Icons.copy_rounded, size: 13, color: AppColors.accent),
                const SizedBox(width: 4),
                Text('Copy', style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _generateTerraform,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: AppColors.accentGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(7), border: Border.all(color: AppColors.accentGreen.withOpacity(0.3))),
              child: Row(children: [
                const Icon(Icons.refresh_rounded, size: 13, color: AppColors.accentGreen),
                const SizedBox(width: 4),
                Text('Retry', style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.accentGreen, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        // Code block
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF0D1117),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border),
          ),
          child: Column(children: [
            // Toolbar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white12))),
              child: Row(children: [
                Row(children: [
                  Container(width: 11, height: 11, decoration: const BoxDecoration(color: Color(0xFFFF5F56), shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Container(width: 11, height: 11, decoration: const BoxDecoration(color: Color(0xFFFFBD2E), shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Container(width: 11, height: 11, decoration: const BoxDecoration(color: Color(0xFF27C93F), shape: BoxShape.circle)),
                ]),
                const SizedBox(width: 12),
                Text('main.tf', style: GoogleFonts.sourceCodePro(fontSize: 11, color: Colors.white38)),
              ]),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SelectableText(_terraformHcl!,
                  style: GoogleFonts.sourceCodePro(fontSize: 12, color: const Color(0xFFE6EDF3), height: 1.6)),
            ),
          ]),
        ),
        if (_tfNotes.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Notes & Customization', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: text)),
          const SizedBox(height: 10),
          ..._tfNotes.asMap().entries.map((e) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(10), border: Border.all(color: border)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 20, height: 20, decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), shape: BoxShape.circle),
                  child: Center(child: Text('${e.key+1}', style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.accent, fontWeight: FontWeight.w700)))),
              const SizedBox(width: 10),
              Expanded(child: Text(e.value.toString(), style: GoogleFonts.dmSans(fontSize: 12, color: text, height: 1.5))),
            ]),
          )),
        ],
        const SizedBox(height: 80),
      ]),
    );
  }

  // ── Cost Tab ─────────────────────────────────────────────────────────────
  Widget _costTab(Color text, Color sub, Color card, Color border) {
    if (_loadingCost) {
      return const Center(child: AppLoader(message: 'Estimating costs…'));
    }
    if (_costResult == null) {
      return Center(child: Text('Generate architecture first', style: GoogleFonts.dmSans(fontSize: 13, color: sub)));
    }

    final est       = _costResult!['estimateMonthlyUSD'];
    final monthly   = est is num ? est.toDouble() : double.tryParse(est.toString()) ?? 0;
    final breakdown = _costResult!['breakdown'] as List? ?? [];
    final alts      = _costResult!['cheaperAlternatives'] as List? ?? [];
    final assumptions = _costResult!['assumptions'] as List? ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Total banner
        Container(
          width: double.infinity, padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF1E1B4B), Color(0xFF312E81)]),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Estimated Monthly Cost', style: GoogleFonts.dmSans(fontSize: 12, color: Colors.white60)),
              const SizedBox(height: 4),
              Text('\$${monthly.toStringAsFixed(2)}/mo',
                  style: GoogleFonts.spaceMono(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white)),
              Text('\$${(monthly * 12).toStringAsFixed(0)}/year',
                  style: GoogleFonts.dmSans(fontSize: 12, color: Colors.white60)),
            ])),
            const Text('💰', style: TextStyle(fontSize: 40)),
          ]),
        ),
        const SizedBox(height: 20),

        // Breakdown
        if (breakdown.isNotEmpty) ...[
          Text('Service Breakdown', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: text)),
          const SizedBox(height: 10),
          ...breakdown.map((item) {
            final s = item.toString();
            // Try to extract cost from strings like "EC2: $50/month"
            final costMatch = RegExp(r'\$(\d+(?:\.\d+)?)').firstMatch(s);
            final cost = costMatch != null ? double.tryParse(costMatch.group(1) ?? '') : null;
            final pct  = cost != null && monthly > 0 ? cost / monthly : 0.0;
            final isHigh = pct > 0.3;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(12), border: Border.all(color: border)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(s.split(':').first.trim(),
                      style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: text))),
                  if (isHigh) Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.accentAlt.withOpacity(0.15), borderRadius: BorderRadius.circular(5)),
                    child: Text('High', style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.accentAlt, fontWeight: FontWeight.w700)),
                  ),
                  if (cost != null) ...[
                    const SizedBox(width: 8),
                    Text('\$${cost.toStringAsFixed(2)}/mo',
                        style: GoogleFonts.spaceMono(fontSize: 12, color: isHigh ? AppColors.accentAlt : AppColors.accentGreen, fontWeight: FontWeight.w700)),
                  ],
                ]),
                if (s.contains(':') && s.split(':').length > 1) ...[
                  const SizedBox(height: 4),
                  Text(s.split(':').sublist(1).join(':').trim(),
                      style: GoogleFonts.dmSans(fontSize: 11, color: sub)),
                ],
                if (cost != null && pct > 0) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct.clamp(0.0, 1.0),
                      backgroundColor: border,
                      valueColor: AlwaysStoppedAnimation(isHigh ? AppColors.accentAlt : AppColors.accentGreen),
                      minHeight: 4,
                    ),
                  ),
                ],
              ]),
            );
          }),
          const SizedBox(height: 20),
        ],

        // Cheaper alternatives
        if (alts.isNotEmpty) ...[
          Text('💡 Cost Optimization Tips', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: text)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.accentGreen.withOpacity(0.07), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.accentGreen.withOpacity(0.3))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: alts.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.savings_rounded, size: 16, color: AppColors.accentGreen),
                  const SizedBox(width: 8),
                  Expanded(child: Text(a.toString(), style: GoogleFonts.dmSans(fontSize: 13, color: text, height: 1.4))),
                ]),
              )).toList(),
            ),
          ),
        ],
        const SizedBox(height: 80),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mermaid Diagram Widget — tries mermaid.ink, then mermaid.live fallback
// ─────────────────────────────────────────────────────────────────────────────
class _MermaidDiagramWidget extends StatefulWidget {
  final String mermaidCode, diagramUrl;
  final Color sub, card, border;
  final Widget Function() onFallback;
  const _MermaidDiagramWidget({
    required this.mermaidCode, required this.diagramUrl,
    required this.sub, required this.card, required this.border,
    required this.onFallback,
  });
  @override State<_MermaidDiagramWidget> createState() => _MermaidDiagramWidgetState();
}

class _MermaidDiagramWidgetState extends State<_MermaidDiagramWidget> {
  bool _inkFailed  = false;
  bool _loading    = true;

  // Try multiple mermaid.ink formats
  String get _url1 => widget.diagramUrl; // base64
  String get _url2 {
    // Try svg format instead of img
    final code = widget.mermaidCode.trim();
    final encoded = base64Url.encode(utf8.encode(code));
    return 'https://mermaid.ink/svg/$encoded';
  }

  @override
  Widget build(BuildContext context) {
    if (_inkFailed) return widget.onFallback();

    return Stack(children: [
      Image.network(
        _inkFailed ? _url2 : _url1,
        fit: BoxFit.contain,
        width: double.infinity,
        headers: const {'User-Agent': 'Mozilla/5.0'},
        loadingBuilder: (_, child, progress) {
          if (progress == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _loading = false);
            });
            return child;
          }
          return Container(
            height: 280, color: const Color(0xFF0f0f1a),
            alignment: Alignment.center,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2),
              const SizedBox(height: 12),
              Text('Rendering diagram…',
                  style: GoogleFonts.dmSans(fontSize: 12, color: widget.sub)),
            ]),
          );
        },
        errorBuilder: (_, __, ___) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _inkFailed = true);
          });
          return widget.onFallback();
        },
      ),
    ]);
  }
}



















//  claude response-might be final


// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:flutter_markdown/flutter_markdown.dart';
// import 'package:flutter/services.dart';
// import 'package:google_fonts/google_fonts.dart';
// import '../../core/theme.dart';
// import '../../services/bedrock_service.dart';
// import '../../widgets/common_widgets.dart';
// import '../../widgets/voice_recorder.dart';
// import 'terraform_screen.dart';

// class ArchitectureScreen extends StatefulWidget {
//   const ArchitectureScreen({super.key});
//   @override State<ArchitectureScreen> createState() => _ArchitectureScreenState();
// }

// class _ArchitectureScreenState extends State<ArchitectureScreen>
//     with SingleTickerProviderStateMixin {
//   final _ctrl = TextEditingController();
//   late final TabController _tabs = TabController(length: 4, vsync: this);

//   // Loading states — each tab loads independently
//   bool _loadingArch      = false;
//   bool _loadingTerraform = false;
//   bool _loadingCost      = false;

//   String? _error;

//   // Results
//   Map<String, dynamic>? _archResult;   // overview + diagram
//   String?               _terraformHcl;
//   List                  _tfNotes     = [];
//   Map<String, dynamic>? _costResult;

//   // Chat history for this architecture session
//   final List<Map<String, String>> _chatHistory = [];

//   @override
//   void dispose() { _ctrl.dispose(); _tabs.dispose(); super.dispose(); }

//   String _mermaidUrl(String code) =>
//       'https://mermaid.ink/img/${base64Url.encode(utf8.encode(code))}';

//   // ── Step 1: Generate Architecture + Diagram ───────────────────────────────
//   Future<void> _generateArchitecture() async {
//     if (_ctrl.text.trim().isEmpty) return;
//     setState(() {
//       _loadingArch = true; _error = null;
//       _archResult = null; _terraformHcl = null; _costResult = null;
//       _chatHistory.clear();
//     });
//     _tabs.animateTo(0);
//     try {
//       final raw  = await BedrockService().generateArchitecture(_ctrl.text.trim());
//       final data = jsonDecode(raw.replaceAll(RegExp(r'```json|```'), '').trim())
//           as Map<String, dynamic>;
//       _chatHistory.add({'role': 'user', 'content': _ctrl.text.trim()});
//       _chatHistory.add({'role': 'assistant', 'content': data['assistantText'] as String? ?? ''});
//       setState(() { _archResult = data; _loadingArch = false; });
//       // Auto-kick terraform + cost in background
//       _generateTerraform();
//       _generateCost();
//     } on BedrockException catch (e) {
//       setState(() { _error = e.message; _loadingArch = false; });
//     } catch (e) {
//       setState(() { _error = 'Generation failed — try rephrasing.'; _loadingArch = false; });
//     }
//   }

//   // ── Step 2: Generate Terraform (separate call) ────────────────────────────
//   Future<void> _generateTerraform() async {
//     if (_archResult == null) return;
//     setState(() { _loadingTerraform = true; });
//     try {
//       final services = (_archResult!['services'] as List? ?? [])
//           .map((s) => s is Map ? (s['name'] as String? ?? s.toString()) : s.toString())
//           .where((s) => s.isNotEmpty).join(', ');
//       final prompt = 'Generate Terraform HCL for: ${_ctrl.text.trim()}. AWS services: $services';
//       final raw  = await BedrockService().generateTerraform(prompt);
//       final data = jsonDecode(raw.replaceAll(RegExp(r'```json|```'), '').trim()) as Map<String, dynamic>;
//       String hcl = (data['terraform'] as String? ?? '')
//           .replaceAll(r'\n', '\n').replaceAll(r'\"', '"')
//           .replaceAll(RegExp(r'```hcl|```terraform|```'), '').trim();
//       // If hcl still looks like JSON, try extracting from it
//       if (hcl.isEmpty || hcl.startsWith('{')) {
//         try {
//           final j = jsonDecode(hcl.isEmpty ? raw : hcl) as Map<String, dynamic>;
//           final inner = j['terraform'] ?? j['hcl'] ?? (j['data'] as Map?)?['terraform'];
//           if (inner is String && inner.isNotEmpty) {
//             hcl = inner.replaceAll(r'\n', '\n').replaceAll(RegExp(r'```hcl|```'), '').trim();
//           }
//         } catch (_) {}
//       }
//       setState(() {
//         _terraformHcl = hcl.isNotEmpty ? hcl : '# No Terraform generated';
//         _tfNotes = data['notes'] as List? ?? [];
//         _loadingTerraform = false;
//       });        _loadingTerraform = false;
//       });
//     } catch (_) {
//       setState(() { _terraformHcl = '# Terraform generation failed — tap retry'; _loadingTerraform = false; });
//     }
//   }

//   // ── Step 3: Generate Cost (separate call) ─────────────────────────────────
//   Future<void> _generateCost() async {
//     if (_archResult == null) return;
//     setState(() { _loadingCost = true; });
//     try {
//       final services = (_archResult!['services'] as List? ?? [])
//           .map((s) => s is Map ? (s['name'] as String? ?? s.toString()) : s.toString())
//           .where((s) => s.isNotEmpty).join(', ');
//       final raw  = await BedrockService().estimateCost(
//           'App: ${_ctrl.text.trim()}. AWS services used: $services');
//       final data = jsonDecode(raw) as Map<String, dynamic>;
//       setState(() { _costResult = data; _loadingCost = false; });
//     } catch (_) {
//       setState(() { _loadingCost = false; });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final isDark    = Theme.of(context).brightness == Brightness.dark;
//     final textColor = isDark ? AppColors.darkText    : AppColors.lightText;
//     final subColor  = isDark ? AppColors.darkTextSub  : AppColors.lightTextSub;
//     final border    = isDark ? AppColors.darkBorder   : AppColors.lightBorder;
//     final card      = isDark ? AppColors.darkCard     : AppColors.lightCard;

//     return Column(children: [
//       // ── Input header ──────────────────────────────────────────────
//       Container(
//         padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
//         decoration: BoxDecoration(
//           color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
//           border: Border(bottom: BorderSide(color: border)),
//         ),
//         child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//           Row(children: [
//             Container(
//               width: 38, height: 38,
//               decoration: BoxDecoration(
//                 gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFFEC4899)]),
//                 borderRadius: BorderRadius.circular(10),
//               ),
//               child: const Icon(Icons.architecture_rounded, color: Colors.white, size: 20),
//             ),
//             const SizedBox(width: 10),
//             Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//               Text('Architecture Generator',
//                   style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800, color: textColor)),
//               Text('Describe your app → get architecture, diagram, Terraform & cost',
//                   style: GoogleFonts.dmSans(fontSize: 11, color: subColor)),
//             ]),
//           ]),
//           const SizedBox(height: 14),
//           Container(
//             decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(12), border: Border.all(color: border)),
//             child: TextField(
//               controller: _ctrl,
//               maxLines: 3, minLines: 2,
//               style: GoogleFonts.dmSans(color: textColor, fontSize: 13),
//               decoration: InputDecoration(
//                 hintText: 'e.g. A food delivery app with real-time tracking, user auth, payments and driver dashboard',
//                 hintStyle: GoogleFonts.dmSans(fontSize: 12, color: subColor),
//                 contentPadding: const EdgeInsets.all(14),
//                 border: InputBorder.none,
//               ),
//             ),
//           ),
//           const SizedBox(height: 10),
//           SizedBox(
//             width: double.infinity,
//             child: ElevatedButton.icon(
//               onPressed: _loadingArch ? null : _generateArchitecture,
//               icon: _loadingArch
//                   ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
//                   : const Icon(Icons.bolt_rounded, size: 18),
//               label: Text(_loadingArch ? 'Designing Architecture…' : 'Generate Architecture ⚡',
//                   style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, fontSize: 14)),
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: AppColors.accent, foregroundColor: Colors.white,
//                 padding: const EdgeInsets.symmetric(vertical: 13),
//                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//               ),
//             ),
//           ),
//           if (_error != null) ...[
//             const SizedBox(height: 10),
//             Container(
//               padding: const EdgeInsets.all(10),
//               decoration: BoxDecoration(color: AppColors.accentAlt.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.accentAlt.withOpacity(0.3))),
//               child: Text(_error!, style: GoogleFonts.dmSans(color: AppColors.accentAlt, fontSize: 12)),
//             ),
//           ],
//         ]),
//       ),

//       // ── Tabs (only shown after generation) ───────────────────────
//       if (_archResult != null || _loadingArch) ...[
//         Container(
//           color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
//           child: TabBar(
//             controller: _tabs,
//             isScrollable: false,
//             labelColor: AppColors.accent,
//             unselectedLabelColor: subColor,
//             indicatorColor: AppColors.accent,
//             indicatorWeight: 2,
//             labelStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w700, fontSize: 12),
//             unselectedLabelStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w500, fontSize: 12),
//             tabs: [
//               const Tab(text: '🏗 Overview'),
//               const Tab(text: '📊 Diagram'),
//               Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
//                 const Text('⚙️ Terraform'),
//                 if (_loadingTerraform) ...[const SizedBox(width: 4), const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.accent))],
//               ])),
//               Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
//                 const Text('💰 Cost'),
//                 if (_loadingCost) ...[const SizedBox(width: 4), const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.accent))],
//               ])),
//             ],
//           ),
//         ),
//         Expanded(
//           child: TabBarView(controller: _tabs, children: [
//             _loadingArch ? const Center(child: AppLoader(message: 'Designing architecture…')) : _overviewTab(textColor, subColor, card, border),
//             _loadingArch ? const Center(child: AppLoader(message: 'Generating diagram…'))    : _diagramTab(textColor, subColor, card, border),
//             _terraformTab(textColor, subColor, card, border),
//             _costTab(textColor, subColor, card, border),
//           ]),
//         ),
//       ] else
//         Expanded(
//           child: Center(
//             child: Column(mainAxisSize: MainAxisSize.min, children: [
//               Icon(Icons.architecture_rounded, size: 64, color: subColor.withOpacity(0.3)),
//               const SizedBox(height: 16),
//               Text('Describe your app above to generate\na complete AWS architecture',
//                   style: GoogleFonts.dmSans(fontSize: 14, color: subColor, height: 1.5),
//                   textAlign: TextAlign.center),
//             ]),
//           ),
//         ),
//     ]);
//   }

//   // ── Overview Tab ─────────────────────────────────────────────────────────
//   Widget _overviewTab(Color text, Color sub, Color card, Color border) {
//     if (_archResult == null) return const SizedBox();
//     final summary  = (_archResult!['assistantText'] as String? ??
//                       _archResult!['architectureSummary'] as String? ?? '').trim();
//     final services = (_archResult!['services'] as List? ?? []);

//     return SingleChildScrollView(
//       padding: const EdgeInsets.all(20),
//       child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

//         // Summary card
//         if (summary.isNotEmpty) ...[
//           Container(
//             width: double.infinity,
//             padding: const EdgeInsets.all(16),
//             decoration: BoxDecoration(
//               gradient: LinearGradient(colors: [AppColors.accent.withOpacity(0.07), AppColors.accentAlt.withOpacity(0.04)]),
//               borderRadius: BorderRadius.circular(14),
//               border: Border.all(color: AppColors.accent.withOpacity(0.2)),
//             ),
//             child: MarkdownBody(
//               data: summary, selectable: true,
//               styleSheet: MarkdownStyleSheet(
//                 p:          GoogleFonts.dmSans(fontSize: 13, color: text, height: 1.6),
//                 strong:     GoogleFonts.dmSans(fontSize: 13, color: text, fontWeight: FontWeight.w700),
//                 listBullet: GoogleFonts.dmSans(fontSize: 13, color: AppColors.accent),
//                 h3:         GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: text),
//               ),
//             ),
//           ),
//           const SizedBox(height: 20),
//         ],

//         // AWS Services grid
//         if (services.isNotEmpty) ...[
//           Text('AWS Services Used',
//               style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w800, color: text)),
//           const SizedBox(height: 12),
//           ...services.map((s) {
//             final name    = s is Map ? (s['name'] as String? ?? s.toString()) : s.toString();
//             final purpose = s is Map ? (s['purpose'] as String? ?? s['description'] as String? ?? '') : '';
//             final emoji   = s is Map ? (s['emoji'] as String? ?? '☁️') : '☁️';
//             return Container(
//               margin: const EdgeInsets.only(bottom: 10),
//               padding: const EdgeInsets.all(14),
//               decoration: BoxDecoration(
//                 color: card, borderRadius: BorderRadius.circular(12),
//                 border: Border.all(color: border),
//               ),
//               child: Row(children: [
//                 Container(
//                   width: 42, height: 42,
//                   decoration: BoxDecoration(
//                     color: AppColors.accent.withOpacity(0.1),
//                     borderRadius: BorderRadius.circular(10),
//                   ),
//                   child: Center(child: Text(emoji, style: const TextStyle(fontSize: 20))),
//                 ),
//                 const SizedBox(width: 12),
//                 Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//                   Text(name, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: text)),
//                   if (purpose.isNotEmpty)
//                     Text(purpose, style: GoogleFonts.dmSans(fontSize: 11, color: sub, height: 1.4)),
//                 ])),
//                 Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
//                   decoration: BoxDecoration(
//                     color: AppColors.accentGreen.withOpacity(0.1),
//                     borderRadius: BorderRadius.circular(6),
//                   ),
//                   child: Text('AWS', style: GoogleFonts.dmSans(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.accentGreen)),
//                 ),
//               ]),
//             );
//           }),
//         ],

//         // If services is plain string list (Lambda returns strings not objects)
//         if (services.isEmpty) ...[
//           // Try assistantText line-by-line
//           ...summary.split('\n').where((l) => l.trim().startsWith('-')).map((l) =>
//             Container(
//               margin: const EdgeInsets.only(bottom: 8),
//               padding: const EdgeInsets.all(12),
//               decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(10), border: Border.all(color: border)),
//               child: Row(children: [
//                 const Text('☁️', style: TextStyle(fontSize: 18)),
//                 const SizedBox(width: 10),
//                 Expanded(child: Text(l.trim().replaceFirst('-', '').trim(),
//                     style: GoogleFonts.dmSans(fontSize: 13, color: text))),
//               ]),
//             )),
//         ],
//         const SizedBox(height: 80),
//       ]),
//     );
//   }

//   // ── Diagram Tab ──────────────────────────────────────────────────────────
//   Widget _diagramTab(Color text, Color sub, Color card, Color border) {
//     final mermaid = _archResult?['mermaid'] as String? ?? '';
//     final diagUrl = _archResult?['diagramUrl'] as String? ?? '';
//     final url     = diagUrl.isNotEmpty ? diagUrl
//         : mermaid.isNotEmpty ? _mermaidUrl(mermaid) : '';

//     return SingleChildScrollView(
//       padding: const EdgeInsets.all(20),
//       child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//         Row(children: [
//           Text('Architecture Diagram',
//               style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w800, color: text)),
//           const Spacer(),
//           if (mermaid.isNotEmpty)
//             GestureDetector(
//               onTap: () { Clipboard.setData(ClipboardData(text: mermaid));
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   SnackBar(content: Text('Mermaid code copied!', style: GoogleFonts.dmSans()), duration: const Duration(seconds: 2)));
//               },
//               child: Row(children: [
//                 const Icon(Icons.copy_rounded, size: 13, color: AppColors.accent),
//                 const SizedBox(width: 4),
//                 Text('Copy code', style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.w600)),
//               ]),
//             ),
//         ]),
//         const SizedBox(height: 14),

//         if (url.isNotEmpty) ...[
//           Container(
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(16),
//               border: Border.all(color: border),
//               boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 4))],
//             ),
//             child: ClipRRect(
//               borderRadius: BorderRadius.circular(16),
//               child: _MermaidDiagramWidget(
//                 mermaidCode: mermaid,
//                 diagramUrl:  url,
//                 sub: sub, card: card, border: border,
//                 onFallback: () => _diagramFallback(mermaid, text, sub, card, border),
//               ),
//             ),
//           ),
//           const SizedBox(height: 16),
//           // View raw Mermaid code
//           Container(
//             decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(10), border: Border.all(color: border)),
//             child: ExpansionTile(
//               tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
//               title: Text('View Mermaid Code', style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.w600)),
//               children: [
//                 Container(
//                   width: double.infinity,
//                   padding: const EdgeInsets.all(14),
//                   decoration: const BoxDecoration(color: AppColors.codeBg, borderRadius: BorderRadius.vertical(bottom: Radius.circular(10))),
//                   child: SelectableText(mermaid, style: GoogleFonts.sourceCodePro(fontSize: 11, color: AppColors.codeText, height: 1.6)),
//                 ),
//               ],
//             ),
//           ),
//           const SizedBox(height: 12),
//           // Open in mermaid.live
//           GestureDetector(
//             onTap: () {
//               final encoded = base64Url.encode(utf8.encode(mermaid));
//               Clipboard.setData(ClipboardData(text: 'https://mermaid.live/edit#base64:$encoded'));
//               ScaffoldMessenger.of(context).showSnackBar(
//                 SnackBar(content: Text('mermaid.live link copied — open in browser!', style: GoogleFonts.dmSans()), duration: const Duration(seconds: 3)));
//             },
//             child: Container(
//               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//               decoration: BoxDecoration(
//                 border: Border.all(color: AppColors.accent.withOpacity(0.4)),
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               child: Row(mainAxisSize: MainAxisSize.min, children: [
//                 const Icon(Icons.open_in_new_rounded, size: 14, color: AppColors.accent),
//                 const SizedBox(width: 6),
//                 Text('Open in mermaid.live for full-screen view',
//                     style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.w600)),
//               ]),
//             ),
//           ),
//         ] else
//           _diagramFallback('', text, sub, card, border),

//         const SizedBox(height: 80),
//       ]),
//     );
//   }

//   Widget _diagramFallback(String mermaid, Color text, Color sub, Color card, Color border) {
//     return Container(
//       padding: const EdgeInsets.all(24),
//       decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
//       child: Column(children: [
//         const Icon(Icons.account_tree_rounded, color: AppColors.accent, size: 40),
//         const SizedBox(height: 12),
//         Text('Diagram rendering unavailable', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: text)),
//         const SizedBox(height: 6),
//         Text('Copy the Mermaid code and paste it at mermaid.live to view your diagram',
//             style: GoogleFonts.dmSans(fontSize: 12, color: sub, height: 1.5), textAlign: TextAlign.center),
//         if (mermaid.isNotEmpty) ...[
//           const SizedBox(height: 14),
//           GestureDetector(
//             onTap: () { Clipboard.setData(ClipboardData(text: mermaid));
//               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied!')));
//             },
//             child: Container(
//               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//               decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.accent, AppColors.accentAlt]), borderRadius: BorderRadius.circular(8)),
//               child: Text('Copy Mermaid Code', style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
//             ),
//           ),
//         ],
//       ]),
//     );
//   }

//   // ── Terraform Tab ────────────────────────────────────────────────────────
//   Widget _terraformTab(Color text, Color sub, Color card, Color border) {
//     if (_loadingTerraform) {
//       return const Center(child: AppLoader(message: 'Generating Terraform HCL…'));
//     }
//     if (_terraformHcl == null) {
//       return Center(child: Text('Generate architecture first', style: GoogleFonts.dmSans(fontSize: 13, color: sub)));
//     }
//     return SingleChildScrollView(
//       padding: const EdgeInsets.all(20),
//       child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//         Row(children: [
//           Text('Terraform HCL', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w800, color: text)),
//           const Spacer(),
//           GestureDetector(
//             onTap: () { Clipboard.setData(ClipboardData(text: _terraformHcl!));
//               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied!')));
//             },
//             child: Container(
//               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//               decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(7), border: Border.all(color: AppColors.accent.withOpacity(0.3))),
//               child: Row(children: [
//                 const Icon(Icons.copy_rounded, size: 13, color: AppColors.accent),
//                 const SizedBox(width: 4),
//                 Text('Copy', style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.w700)),
//               ]),
//             ),
//           ),
//           const SizedBox(width: 8),
//           GestureDetector(
//             onTap: _generateTerraform,
//             child: Container(
//               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//               decoration: BoxDecoration(color: AppColors.accentGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(7), border: Border.all(color: AppColors.accentGreen.withOpacity(0.3))),
//               child: Row(children: [
//                 const Icon(Icons.refresh_rounded, size: 13, color: AppColors.accentGreen),
//                 const SizedBox(width: 4),
//                 Text('Retry', style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.accentGreen, fontWeight: FontWeight.w700)),
//               ]),
//             ),
//           ),
//         ]),
//         const SizedBox(height: 12),
//         // Code block
//         Container(
//           width: double.infinity,
//           decoration: BoxDecoration(
//             color: const Color(0xFF0D1117),
//             borderRadius: BorderRadius.circular(14),
//             border: Border.all(color: border),
//           ),
//           child: Column(children: [
//             // Toolbar
//             Container(
//               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//               decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white12))),
//               child: Row(children: [
//                 Row(children: [
//                   Container(width: 11, height: 11, decoration: const BoxDecoration(color: Color(0xFFFF5F56), shape: BoxShape.circle)),
//                   const SizedBox(width: 5),
//                   Container(width: 11, height: 11, decoration: const BoxDecoration(color: Color(0xFFFFBD2E), shape: BoxShape.circle)),
//                   const SizedBox(width: 5),
//                   Container(width: 11, height: 11, decoration: const BoxDecoration(color: Color(0xFF27C93F), shape: BoxShape.circle)),
//                 ]),
//                 const SizedBox(width: 12),
//                 Text('main.tf', style: GoogleFonts.sourceCodePro(fontSize: 11, color: Colors.white38)),
//               ]),
//             ),
//             SingleChildScrollView(
//               padding: const EdgeInsets.all(16),
//               child: SelectableText(_terraformHcl!,
//                   style: GoogleFonts.sourceCodePro(fontSize: 12, color: const Color(0xFFE6EDF3), height: 1.6)),
//             ),
//           ]),
//         ),
//         if (_tfNotes.isNotEmpty) ...[
//           const SizedBox(height: 20),
//           Text('Notes & Customization', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: text)),
//           const SizedBox(height: 10),
//           ..._tfNotes.asMap().entries.map((e) => Container(
//             margin: const EdgeInsets.only(bottom: 8),
//             padding: const EdgeInsets.all(12),
//             decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(10), border: Border.all(color: border)),
//             child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
//               Container(width: 20, height: 20, decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), shape: BoxShape.circle),
//                   child: Center(child: Text('${e.key+1}', style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.accent, fontWeight: FontWeight.w700)))),
//               const SizedBox(width: 10),
//               Expanded(child: Text(e.value.toString(), style: GoogleFonts.dmSans(fontSize: 12, color: text, height: 1.5))),
//             ]),
//           )),
//         ],
//         const SizedBox(height: 80),
//       ]),
//     );
//   }

//   // ── Cost Tab ─────────────────────────────────────────────────────────────
//   Widget _costTab(Color text, Color sub, Color card, Color border) {
//     if (_loadingCost) {
//       return const Center(child: AppLoader(message: 'Estimating costs…'));
//     }
//     if (_costResult == null) {
//       return Center(child: Text('Generate architecture first', style: GoogleFonts.dmSans(fontSize: 13, color: sub)));
//     }

//     final est       = _costResult!['estimateMonthlyUSD'];
//     final monthly   = est is num ? est.toDouble() : double.tryParse(est.toString()) ?? 0;
//     final breakdown = _costResult!['breakdown'] as List? ?? [];
//     final alts      = _costResult!['cheaperAlternatives'] as List? ?? [];
//     final assumptions = _costResult!['assumptions'] as List? ?? [];

//     return SingleChildScrollView(
//       padding: const EdgeInsets.all(20),
//       child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//         // Total banner
//         Container(
//           width: double.infinity, padding: const EdgeInsets.all(20),
//           decoration: BoxDecoration(
//             gradient: const LinearGradient(colors: [Color(0xFF1E1B4B), Color(0xFF312E81)]),
//             borderRadius: BorderRadius.circular(16),
//           ),
//           child: Row(children: [
//             Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//               Text('Estimated Monthly Cost', style: GoogleFonts.dmSans(fontSize: 12, color: Colors.white60)),
//               const SizedBox(height: 4),
//               Text('\$${monthly.toStringAsFixed(2)}/mo',
//                   style: GoogleFonts.spaceMono(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white)),
//               Text('\$${(monthly * 12).toStringAsFixed(0)}/year',
//                   style: GoogleFonts.dmSans(fontSize: 12, color: Colors.white60)),
//             ])),
//             const Text('💰', style: TextStyle(fontSize: 40)),
//           ]),
//         ),
//         const SizedBox(height: 20),

//         // Breakdown
//         if (breakdown.isNotEmpty) ...[
//           Text('Service Breakdown', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: text)),
//           const SizedBox(height: 10),
//           ...breakdown.map((item) {
//             final s = item.toString();
//             // Try to extract cost from strings like "EC2: $50/month"
//             final costMatch = RegExp(r'\$(\d+(?:\.\d+)?)').firstMatch(s);
//             final cost = costMatch != null ? double.tryParse(costMatch.group(1) ?? '') : null;
//             final pct  = cost != null && monthly > 0 ? cost / monthly : 0.0;
//             final isHigh = pct > 0.3;
//             return Container(
//               margin: const EdgeInsets.only(bottom: 8),
//               padding: const EdgeInsets.all(14),
//               decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(12), border: Border.all(color: border)),
//               child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//                 Row(children: [
//                   Expanded(child: Text(s.split(':').first.trim(),
//                       style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: text))),
//                   if (isHigh) Container(
//                     padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
//                     decoration: BoxDecoration(color: AppColors.accentAlt.withOpacity(0.15), borderRadius: BorderRadius.circular(5)),
//                     child: Text('High', style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.accentAlt, fontWeight: FontWeight.w700)),
//                   ),
//                   if (cost != null) ...[
//                     const SizedBox(width: 8),
//                     Text('\$${cost.toStringAsFixed(2)}/mo',
//                         style: GoogleFonts.spaceMono(fontSize: 12, color: isHigh ? AppColors.accentAlt : AppColors.accentGreen, fontWeight: FontWeight.w700)),
//                   ],
//                 ]),
//                 if (s.contains(':') && s.split(':').length > 1) ...[
//                   const SizedBox(height: 4),
//                   Text(s.split(':').sublist(1).join(':').trim(),
//                       style: GoogleFonts.dmSans(fontSize: 11, color: sub)),
//                 ],
//                 if (cost != null && pct > 0) ...[
//                   const SizedBox(height: 8),
//                   ClipRRect(
//                     borderRadius: BorderRadius.circular(4),
//                     child: LinearProgressIndicator(
//                       value: pct.clamp(0.0, 1.0),
//                       backgroundColor: border,
//                       valueColor: AlwaysStoppedAnimation(isHigh ? AppColors.accentAlt : AppColors.accentGreen),
//                       minHeight: 4,
//                     ),
//                   ),
//                 ],
//               ]),
//             );
//           }),
//           const SizedBox(height: 20),
//         ],

//         // Cheaper alternatives
//         if (alts.isNotEmpty) ...[
//           Text('💡 Cost Optimization Tips', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: text)),
//           const SizedBox(height: 10),
//           Container(
//             padding: const EdgeInsets.all(16),
//             decoration: BoxDecoration(color: AppColors.accentGreen.withOpacity(0.07), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.accentGreen.withOpacity(0.3))),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: alts.map((a) => Padding(
//                 padding: const EdgeInsets.only(bottom: 8),
//                 child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
//                   const Icon(Icons.savings_rounded, size: 16, color: AppColors.accentGreen),
//                   const SizedBox(width: 8),
//                   Expanded(child: Text(a.toString(), style: GoogleFonts.dmSans(fontSize: 13, color: text, height: 1.4))),
//                 ]),
//               )).toList(),
//             ),
//           ),
//         ],
//         const SizedBox(height: 80),
//       ]),
//     );
//   }
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // Mermaid Diagram Widget — tries mermaid.ink, then mermaid.live fallback
// // ─────────────────────────────────────────────────────────────────────────────
// class _MermaidDiagramWidget extends StatefulWidget {
//   final String mermaidCode, diagramUrl;
//   final Color sub, card, border;
//   final Widget Function() onFallback;
//   const _MermaidDiagramWidget({
//     required this.mermaidCode, required this.diagramUrl,
//     required this.sub, required this.card, required this.border,
//     required this.onFallback,
//   });
//   @override State<_MermaidDiagramWidget> createState() => _MermaidDiagramWidgetState();
// }

// class _MermaidDiagramWidgetState extends State<_MermaidDiagramWidget> {
//   bool _inkFailed  = false;
//   bool _loading    = true;

//   // Try multiple mermaid.ink formats
//   String get _url1 => widget.diagramUrl; // base64
//   String get _url2 {
//     // Try svg format instead of img
//     final code = widget.mermaidCode.trim();
//     final encoded = base64Url.encode(utf8.encode(code));
//     return 'https://mermaid.ink/svg/$encoded';
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (_inkFailed) return widget.onFallback();

//     return Stack(children: [
//       Image.network(
//         _inkFailed ? _url2 : _url1,
//         fit: BoxFit.contain,
//         width: double.infinity,
//         headers: const {'User-Agent': 'Mozilla/5.0'},
//         loadingBuilder: (_, child, progress) {
//           if (progress == null) {
//             WidgetsBinding.instance.addPostFrameCallback((_) {
//               if (mounted) setState(() => _loading = false);
//             });
//             return child;
//           }
//           return Container(
//             height: 280, color: const Color(0xFF0f0f1a),
//             alignment: Alignment.center,
//             child: Column(mainAxisSize: MainAxisSize.min, children: [
//               const CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2),
//               const SizedBox(height: 12),
//               Text('Rendering diagram…',
//                   style: GoogleFonts.dmSans(fontSize: 12, color: widget.sub)),
//             ]),
//           );
//         },
//         errorBuilder: (_, __, ___) {
//           WidgetsBinding.instance.addPostFrameCallback((_) {
//             if (mounted) setState(() => _inkFailed = true);
//           });
//           return widget.onFallback();
//         },
//       ),
//     ]);
//   }
// }


