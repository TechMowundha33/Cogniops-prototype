import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../services/bedrock_service.dart';
import '../../widgets/common_widgets.dart';

class TerraformScreen extends StatefulWidget {
  const TerraformScreen({super.key});
  @override State<TerraformScreen> createState() => _TerraformScreenState();
}

class _TerraformScreenState extends State<TerraformScreen> with SingleTickerProviderStateMixin {
  final _ctrl = TextEditingController();
  late final TabController _tabs = TabController(length: 2, vsync: this);
  bool    _loading = false;
  String? _hcl;
  List    _notes   = [];
  String? _error;

  @override
  void dispose() { _ctrl.dispose(); _tabs.dispose(); super.dispose(); }

  Future<void> _generate() async {
    if (_ctrl.text.trim().isEmpty) return;
    setState(() { _loading = true; _hcl = null; _notes = []; _error = null; });
    try {
      final result = await BedrockService().generateTerraform(_ctrl.text.trim());
      final data   = jsonDecode(result) as Map<String, dynamic>;

      String hcl = (data['terraform'] as String? ?? '');
      // Ensure newlines are real
      hcl = hcl.replaceAll('\\n', '\n').replaceAll('\\"', '"').replaceAll('\\\\', '\\');
      hcl = hcl.replaceAll(RegExp(r'```hcl|```terraform|```'), '').trim();

      final notesList = data['notes'] as List? ?? [];

      setState(() {
        _hcl   = hcl;
        _notes = notesList;
        _loading = false;
      });
    } on BedrockException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Generation failed — try again.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkText    : AppColors.lightText;
    final subColor  = isDark ? AppColors.darkTextSub  : AppColors.lightTextSub;
    final border    = isDark ? AppColors.darkBorder   : AppColors.lightBorder;
    final card      = isDark ? AppColors.darkCard     : AppColors.lightCard;
    final codeBg    = isDark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        //  Header 
        Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.code_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Terraform Generator',
                style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w800, color: textColor)),
            Text('Production-ready HCL in seconds',
                style: GoogleFonts.dmSans(fontSize: 12, color: subColor)),
          ]),
        ]),
        const SizedBox(height: 24),

        // ── Input card ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
          child: Column(children: [
            TextField(
              controller: _ctrl,
              minLines: 3, maxLines: 5,
              style: GoogleFonts.dmSans(color: textColor, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'e.g. "EC2 instance with VPC, security group, and S3 bucket"',
                hintStyle: GoogleFonts.dmSans(fontSize: 13, color: subColor),
                border: InputBorder.none,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _generate,
                icon: _loading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.bolt_rounded, size: 18),
                label: Text(_loading ? 'Generating…' : 'Generate Terraform ⚡',
                    style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ]),
        ),

        if (_error != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accentAlt.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.accentAlt.withOpacity(0.3)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Text(
                _error!.contains('504') || _error!.contains('timed out')
                    ? '⏱ Timed out — try a shorter description.'
                    : _error!,
                style: GoogleFonts.dmSans(color: AppColors.accentAlt, fontSize: 13))),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _generate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.accentAlt.withOpacity(0.2), borderRadius: BorderRadius.circular(7)),
                  child: Text('Retry', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accentAlt)),
                ),
              ),
            ]),
          ),
        ],

        // Results 
        if (_hcl != null) ...[
          const SizedBox(height: 24),

          // Tabs
          Container(
            decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(10), border: Border.all(color: border)),
            child: TabBar(
              controller: _tabs,
              indicator: BoxDecoration(
                color: AppColors.accent, borderRadius: BorderRadius.circular(8)),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: subColor,
              labelStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 13),
              tabs: const [
                Tab(text: 'HCL Code'),
                Tab(text: 'Notes'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          SizedBox(
            height: 500,
            child: TabBarView(controller: _tabs, children: [

              // ── HCL Code tab ────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: codeBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: border),
                ),
                child: Column(children: [
                  // Code toolbar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: border)),
                    ),
                    child: Row(children: [
                      // Traffic lights
                      Row(children: [
                        Container(width: 12, height: 12, decoration: BoxDecoration(color: const Color(0xFFFF5F56), shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Container(width: 12, height: 12, decoration: BoxDecoration(color: const Color(0xFFFFBD2E), shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Container(width: 12, height: 12, decoration: BoxDecoration(color: const Color(0xFF27C93F), shape: BoxShape.circle)),
                      ]),
                      const SizedBox(width: 12),
                      Text('main.tf',
                          style: GoogleFonts.sourceCodePro(fontSize: 12, color: subColor)),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: _hcl!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Copied to clipboard!',
                                style: GoogleFonts.dmSans()), duration: const Duration(seconds: 2)));
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.copy_rounded, size: 13, color: AppColors.accent),
                            const SizedBox(width: 4),
                            Text('Copy', style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      ),
                    ]),
                  ),
                  // Code content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: SelectableText(
                        _hcl!,
                        style: GoogleFonts.sourceCodePro(
                          fontSize: 12,
                          color: isDark ? const Color(0xFFE6EDF3) : const Color(0xFF24292F),
                          height: 1.6,
                        ),
                      ),
                    ),
                  ),
                ]),
              ),

              //  Notes tab 
              Container(
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: border),
                ),
                child: _notes.isEmpty
                    ? Center(child: Text('No notes available',
                        style: GoogleFonts.dmSans(fontSize: 13, color: subColor)))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _notes.length,
                        separatorBuilder: (_, __) => Divider(color: border, height: 20),
                        itemBuilder: (_, i) => Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 22, height: 22,
                              decoration: BoxDecoration(
                                color: AppColors.accent.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Center(child: Text('${i+1}',
                                  style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.accent, fontWeight: FontWeight.w700))),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text(_notes[i].toString(),
                                style: GoogleFonts.dmSans(fontSize: 13, color: textColor, height: 1.5))),
                          ],
                        ),
                      ),
              ),
            ]),
          ),
        ],
        const SizedBox(height: 80),
      ]),
    );
  }
}


