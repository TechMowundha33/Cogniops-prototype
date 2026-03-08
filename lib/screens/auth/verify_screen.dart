import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common_widgets.dart';

class VerifyScreen extends StatefulWidget {
  const VerifyScreen({super.key});
  @override State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override void dispose() { _codeCtrl.dispose(); super.dispose(); }

  Future<void> _verify() async {
    if (_codeCtrl.text.trim().length < 6) {
      setState(() => _error = 'Enter the 6-digit code from your email.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    final auth  = context.read<AuthProvider>();
    final ok    = await auth.confirmSignUp(
      email: auth.pendingEmail,
      code:  _codeCtrl.text.trim(),
    );
    if (!ok && mounted) {
      setState(() { _loading = false; _error = auth.error ?? 'Verification failed.'; });
    }
  }

  Future<void> _resend() async {
    final auth = context.read<AuthProvider>();
    await auth.resendCode(auth.pendingEmail);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Verification code resent!')),
    );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final surface  = isDark ? AppColors.darkSurface    : AppColors.lightSurface;
    final textCol  = isDark ? AppColors.darkText        : AppColors.lightText;
    final subCol   = isDark ? AppColors.darkTextSub     : AppColors.lightTextSub;
    final border   = isDark ? AppColors.darkBorder      : AppColors.lightBorder;
    final auth     = context.watch<AuthProvider>();
    final email    = auth.pendingEmail;

    return Scaffold(
      backgroundColor: surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Verify Email 📧',
                  style: GoogleFonts.dmSans(fontSize: 28, fontWeight: FontWeight.w800, color: textCol)),
              const SizedBox(height: 8),
              Text('We sent a 6-digit code to\n$email',
                  style: GoogleFonts.dmSans(fontSize: 14, color: subCol, height: 1.5)),
              const SizedBox(height: 32),

              if (_error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.accentAlt.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.accentAlt.withOpacity(0.3)),
                  ),
                  child: Text(_error!, style: GoogleFonts.dmSans(color: AppColors.accentAlt, fontSize: 13)),
                ),

              TextField(
                controller: _codeCtrl,
                style: GoogleFonts.dmSans(fontSize: 24, fontWeight: FontWeight.w700,
                    color: textCol, letterSpacing: 8),
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '000000',
                  hintStyle: GoogleFonts.dmSans(fontSize: 24, color: subCol, letterSpacing: 8),
                ),
              ),
              const SizedBox(height: 24),

              GradientButton(
                label: 'Verify & Continue',
                width: double.infinity,
                loading: _loading,
                onTap: _loading ? null : _verify,
              ),
              const SizedBox(height: 16),

              Center(child: GestureDetector(
                onTap: _resend,
                child: Text('Resend code',
                    style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.accent,
                        fontWeight: FontWeight.w600)),
              )),
            ],
          ),
        ),
      ),
    );
  }
}