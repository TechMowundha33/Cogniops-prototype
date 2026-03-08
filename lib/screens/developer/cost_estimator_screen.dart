import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../services/bedrock_service.dart';
import '../../widgets/common_widgets.dart';

class CostEstimatorScreen extends StatefulWidget {
  const CostEstimatorScreen({super.key});
  @override State<CostEstimatorScreen> createState() => _CostEstimatorScreenState();
}

// Manual calculator service model
class _Svc {
  final String name, unit;
  final double basePrice;
  double qty;
  bool enabled;
  _Svc(this.name, this.unit, this.basePrice, {this.qty = 1, this.enabled = false});
  double get cost => enabled ? basePrice * qty : 0;
}

class _CostEstimatorScreenState extends State<CostEstimatorScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  //  AI tab 
  final _aiCtrl = TextEditingController();
  bool _aiLoading = false;
  String? _aiError;
  Map<String, dynamic>? _aiResult;

  // Manual calculator tab 
  final List<_Svc> _services = [
    _Svc('Lambda',           'Million requests',    0.20),
    _Svc('API Gateway',      'Million API calls',   3.50),
    _Svc('EC2 t3.micro',     'Hours (730/mo)',      0.0104),
    _Svc('EC2 t3.small',     'Hours (730/mo)',      0.0208),
    _Svc('EC2 t3.medium',    'Hours (730/mo)',      0.0416),
    _Svc('EC2 t3.large',     'Hours (730/mo)',      0.0832),
    _Svc('RDS db.t3.micro',  'Hours (730/mo)',      0.017),
    _Svc('RDS db.t3.medium', 'Hours (730/mo)',      0.068),
    _Svc('DynamoDB',         'GB stored',           0.25),
    _Svc('S3 Storage',       'GB stored',           0.023),
    _Svc('CloudFront',       'TB data transfer',    85.0),
    _Svc('ECS Fargate',      'vCPU-hours',          0.04048),
    _Svc('ElastiCache t3',   'Hours (730/mo)',      0.017),
    _Svc('SQS',              'Million requests',    0.40),
    _Svc('SNS',              'Million publishes',   0.50),
    _Svc('Cognito',          'Monthly active users',0.0055),
    _Svc('Secrets Manager',  'Secrets stored',      0.40),
    _Svc('CloudWatch',       'GB logs ingested',    0.50),
  ];

  @override
  void dispose() { _tabs.dispose(); _aiCtrl.dispose(); super.dispose(); }

  // Safe cost parser — handles String/int/double from Lambda
  static double _safeCost(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
  }

  Future<void> _aiEstimate() async {
    if (_aiCtrl.text.trim().isEmpty) return;
    setState(() { _aiLoading = true; _aiError = null; _aiResult = null; });
    try {
      final raw  = await BedrockService().estimateCost(_aiCtrl.text.trim());
      final data = jsonDecode(raw.replaceAll(RegExp(r'```json|```'), '').trim()) as Map<String, dynamic>;
      setState(() { _aiResult = data; _aiLoading = false; });
    } on BedrockException catch (e) {
      setState(() { _aiError = e.message; _aiLoading = false; });
    } catch (e) {
      setState(() { _aiError = 'Estimation failed — try again.'; _aiLoading = false; });
    }
  }

  double get _manualTotal => _services.fold(0.0, (s, v) => s + v.cost);

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkText    : AppColors.lightText;
    final subColor  = isDark ? AppColors.darkTextSub  : AppColors.lightTextSub;
    final border    = isDark ? AppColors.darkBorder   : AppColors.lightBorder;
    final card      = isDark ? AppColors.darkCard     : AppColors.lightCard;
    final surface   = isDark ? AppColors.darkSurface  : AppColors.lightSurface;

    return Column(children: [
      // Header
      Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        color: surface,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 42, height: 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFEF4444)]),
                borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.attach_money_rounded, color: Colors.white, size: 24)),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Cost Estimator', style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w800, color: textColor)),
              Text('AI-powered or manual AWS cost estimation', style: GoogleFonts.dmSans(fontSize: 12, color: subColor)),
            ]),
          ]),
          const SizedBox(height: 16),
          TabBar(
            controller: _tabs,
            labelColor: AppColors.accent,
            unselectedLabelColor: subColor,
            indicatorColor: AppColors.accent,
            indicatorWeight: 2,
            labelStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w700, fontSize: 13),
            unselectedLabelStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w500, fontSize: 13),
            tabs: const [Tab(text: '🤖 AI Estimate'), Tab(text: '🧮 Manual Calculator')],
          ),
        ]),
      ),

      Expanded(
        child: TabBarView(controller: _tabs, children: [
          _aiTab(textColor, subColor, border, card),
          _manualTab(textColor, subColor, border, card),
        ]),
      ),
    ]);
  }

  // AI Tab 
  Widget _aiTab(Color textColor, Color subColor, Color border, Color card) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Input
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
          child: Column(children: [
            TextField(
              controller: _aiCtrl,
              maxLines: 4, minLines: 2,
              style: GoogleFonts.dmSans(color: textColor, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'e.g. "A SaaS app with 10K users, Lambda APIs, RDS Postgres, S3 storage, CloudFront CDN"',
                hintStyle: GoogleFonts.dmSans(fontSize: 12, color: subColor),
                border: InputBorder.none,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _aiLoading ? null : _aiEstimate,
                icon: _aiLoading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.calculate_rounded, size: 18),
                label: Text(_aiLoading ? 'Estimating…' : 'Estimate with AI ⚡',
                    style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ]),
        ),

        if (_aiError != null) ...[
          const SizedBox(height: 12),
          Container(padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.accentAlt.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.accentAlt.withOpacity(0.3))),
            child: Text(_aiError!, style: GoogleFonts.dmSans(color: AppColors.accentAlt, fontSize: 13))),
        ],

        if (_aiLoading) ...[
          const SizedBox(height: 40),
          const Center(child: AppLoader(message: 'Claude is estimating costs…')),
        ],

        if (_aiResult != null) ...[
          const SizedBox(height: 24),
          // Total banner
          Container(
            width: double.infinity, padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1E1B4B), Color(0xFF312E81)]),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Estimated Monthly Cost', style: GoogleFonts.dmSans(fontSize: 12, color: Colors.white60)),
              const SizedBox(height: 6),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('\$${_safeCost(_aiResult!['estimateMonthlyUSD']).toStringAsFixed(2)}',
                    style: GoogleFonts.spaceMono(fontSize: 38, fontWeight: FontWeight.w800, color: Colors.white)),
                Padding(padding: const EdgeInsets.only(bottom: 6, left: 4),
                    child: Text('/mo', style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white60))),
              ]),
              Text('\$${(_safeCost(_aiResult!['estimateMonthlyUSD']) * 12).toStringAsFixed(0)}/year',
                  style: GoogleFonts.dmSans(fontSize: 12, color: Colors.white38)),
            ]),
          ),
          const SizedBox(height: 20),

          // Assumptions
          if ((_aiResult!['assumptions'] as List?)?.isNotEmpty == true) ...[
            _sectionTitle('📋 Assumptions', textColor),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(12), border: Border.all(color: border)),
              child: Column(children: (_aiResult!['assumptions'] as List).map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('• ', style: GoogleFonts.dmSans(color: subColor)),
                  Expanded(child: Text(a.toString(), style: GoogleFonts.dmSans(fontSize: 13, color: textColor, height: 1.4))),
                ]),
              )).toList()),
            ),
            const SizedBox(height: 20),
          ],

          // Breakdown
          if ((_aiResult!['breakdown'] as List?)?.isNotEmpty == true) ...[
            _sectionTitle('💰 Service Breakdown', textColor),
            const SizedBox(height: 10),
            ...(_aiResult!['breakdown'] as List).map((item) {
              final s = item.toString();
              final match = RegExp(r'\$(\d+(?:\.\d+)?)').firstMatch(s);
              final cost  = match != null ? double.tryParse(match.group(1) ?? '') : null;
              final total = _safeCost(_aiResult!['estimateMonthlyUSD']);
              final pct   = cost != null && total > 0 ? (cost / total).clamp(0.0, 1.0) : 0.0;
              final isHigh = pct > 0.25;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(12), border: Border.all(color: border)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(s, style: GoogleFonts.dmSans(fontSize: 13, color: textColor, height: 1.4))),
                    if (isHigh) Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.accentAlt.withOpacity(0.15), borderRadius: BorderRadius.circular(5)),
                      child: Text('High', style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.accentAlt, fontWeight: FontWeight.w700)),
                    ),
                  ]),
                  if (pct > 0) ...[
                    const SizedBox(height: 8),
                    ClipRRect(borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct, minHeight: 4, backgroundColor: border,
                        valueColor: AlwaysStoppedAnimation(isHigh ? AppColors.accentAlt : AppColors.accentGreen),
                      )),
                  ],
                ]),
              );
            }),
            const SizedBox(height: 20),
          ],

          // Cheaper alternatives
          if ((_aiResult!['cheaperAlternatives'] as List?)?.isNotEmpty == true) ...[
            _sectionTitle('💡 Optimization Tips', textColor),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.accentGreen.withOpacity(0.07), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.accentGreen.withOpacity(0.3))),
              child: Column(children: (_aiResult!['cheaperAlternatives'] as List).map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.savings_rounded, size: 16, color: AppColors.accentGreen),
                  const SizedBox(width: 8),
                  Expanded(child: Text(a.toString(), style: GoogleFonts.dmSans(fontSize: 13, color: textColor, height: 1.4))),
                ]),
              )).toList()),
            ),
          ],
        ],
        const SizedBox(height: 80),
      ]),
    );
  }

  //  Manual Calculator Tab 
  Widget _manualTab(Color textColor, Color subColor, Color border, Color card) {
    final total    = _manualTotal;
    final active   = _services.where((s) => s.enabled).toList();
    final highCost = active.where((s) => total > 0 && s.cost / total > 0.25).toList();

    return Column(children: [
      // Sticky total bar
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF1E1B4B), Color(0xFF312E81)]),
        ),
        child: Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Monthly Total', style: GoogleFonts.dmSans(fontSize: 11, color: Colors.white60)),
            Text('\$${total.toStringAsFixed(2)}',
                style: GoogleFonts.spaceMono(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
          ]),
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('\$${(total * 12).toStringAsFixed(0)}/year', style: GoogleFonts.dmSans(fontSize: 11, color: Colors.white60)),
            if (highCost.isNotEmpty)
              Text('${highCost.length} high-cost', style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.accentAlt)),
          ]),
        ]),
      ),

      // Service list
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          itemCount: _services.length,
          itemBuilder: (_, i) {
            final svc = _services[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: svc.enabled ? AppColors.accent.withOpacity(0.06) : card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: svc.enabled ? AppColors.accent.withOpacity(0.3) : border),
              ),
              child: Column(children: [
                Row(children: [
                  // Toggle
                  GestureDetector(
                    onTap: () => setState(() => svc.enabled = !svc.enabled),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 40, height: 22,
                      decoration: BoxDecoration(
                        color: svc.enabled ? AppColors.accent : border,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: AnimatedAlign(
                        duration: const Duration(milliseconds: 200),
                        alignment: svc.enabled ? Alignment.centerRight : Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Container(width: 18, height: 18, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(svc.name, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: textColor)),
                    Text(svc.unit, style: GoogleFonts.dmSans(fontSize: 11, color: subColor)),
                  ])),
                  if (svc.enabled)
                    Text('\$${svc.cost.toStringAsFixed(2)}/mo',
                        style: GoogleFonts.spaceMono(fontSize: 13, color: AppColors.accentGreen, fontWeight: FontWeight.w700)),
                ]),

                // Quantity slider (only when enabled)
                if (svc.enabled) ...[
                  const SizedBox(height: 10),
                  Row(children: [
                    Text('${svc.qty.toStringAsFixed(svc.qty < 10 ? 1 : 0)} ${svc.unit}',
                        style: GoogleFonts.dmSans(fontSize: 11, color: subColor)),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: AppColors.accent,
                          inactiveTrackColor: border,
                          thumbColor: AppColors.accent,
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                        ),
                        child: Slider(
                          value: svc.qty,
                          min: 0.1,
                          max: svc.name.contains('EC2') || svc.name.contains('RDS') ? 730
                              : svc.name.contains('CloudFront') ? 10
                              : svc.name.contains('Cognito') ? 100000
                              : 100,
                          onChanged: (v) => setState(() => svc.qty = v),
                        ),
                      ),
                    ),
                    Text('\$${svc.basePrice}/unit', style: GoogleFonts.dmSans(fontSize: 10, color: subColor)),
                  ]),
                ],
              ]),
            );
          },
        ),
      ),
    ]);
  }

  Widget _sectionTitle(String t, Color c) =>
      Text(t, style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w800, color: c));
}


























