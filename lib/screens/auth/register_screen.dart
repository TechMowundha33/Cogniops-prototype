import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/bedrock_service.dart';
import '../../widgets/common_widgets.dart';

class RegisterScreen extends StatefulWidget {
  final VoidCallback onGoLogin;
  const RegisterScreen({super.key, required this.onGoLogin});
  @override State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl    = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _passCtrl    = TextEditingController();
  final _confirmCtrl = TextEditingController();
  String _role = 'student';
  bool _obscure = true;
  String? _localError;

  @override void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose();
    _passCtrl.dispose(); _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _localError = null);
    if (_passCtrl.text != _confirmCtrl.text) {
      setState(() => _localError = 'Passwords do not match.');
      return;
    }
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _localError = 'Please enter your name.');
      return;
    }
    if (_passCtrl.text.length < 8) {
      setState(() => _localError = 'Password must be at least 8 characters.');
      return;
    }
    context.read<ChatProvider>().clear();
    BedrockService.resetSession();
    await context.read<AuthProvider>().register(
      name:     _nameCtrl.text.trim(),
      email:    _emailCtrl.text.trim().toLowerCase(),
      password: _passCtrl.text,
      role:     _role,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final surface   = isDark ? AppColors.darkSurface    : AppColors.lightSurface;
    final surfaceAlt= isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurfaceAlt;
    final border    = isDark ? AppColors.darkBorder     : AppColors.lightBorder;
    final textColor = isDark ? AppColors.darkText       : AppColors.lightText;
    final subColor  = isDark ? AppColors.darkTextSub    : AppColors.lightTextSub;
    final auth      = context.watch<AuthProvider>();
    final isLoading = auth.status == AuthStatus.loading;
    final errMsg    = _localError ?? auth.error;

    return Scaffold(
      backgroundColor: surface,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              Container(width: 32, height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.accent, AppColors.accentAlt]),
                  borderRadius: BorderRadius.circular(9)),
                child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 16)),
              const SizedBox(width: 8),
              Text('CogniOps',
                  style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800, color: textColor)),
              const Spacer(),
              GestureDetector(
                onTap: () => context.read<ThemeProvider>().toggle(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: surfaceAlt,
                      borderRadius: BorderRadius.circular(8), border: Border.all(color: border)),
                  child: Icon(isDark ? Icons.wb_sunny_rounded : Icons.dark_mode_rounded,
                      color: textColor, size: 18),
                ),
              ),
            ]),
          ),
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 32),
                Text('Create Account 🚀',
                    style: GoogleFonts.dmSans(fontSize: 26, fontWeight: FontWeight.w800, color: textColor)),
                Text('Join thousands learning cloud & DevOps',
                    style: GoogleFonts.dmSans(fontSize: 13, color: subColor)),
                const SizedBox(height: 28),

                if (errMsg != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.accentAlt.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.accentAlt.withOpacity(0.3))),
                    child: Text(errMsg,
                        style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.accentAlt)),
                  ),

                // Role picker
                Text('I am a', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: subColor)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _RoleTile(
                    icon: '🎓', label: 'Student / Learner',
                    selected: _role == 'student',
                    onTap: () => setState(() => _role = 'student'),
                    border: border,
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _RoleTile(
                    icon: '💻', label: 'Developer / DevOps',
                    selected: _role == 'developer',
                    onTap: () => setState(() => _role = 'developer'),
                    border: border,
                  )),
                ]),
                const SizedBox(height: 18),

                _Field('Full Name', _nameCtrl, textColor, subColor, hint: 'Your name'),
                const SizedBox(height: 14),
                _Field('Email', _emailCtrl, textColor, subColor,
                    hint: 'you@example.com', type: TextInputType.emailAddress),
                const SizedBox(height: 14),
                _Field('Password', _passCtrl, textColor, subColor,
                    hint: '8+ chars, uppercase & symbol', obscure: _obscure,
                    toggle: () => setState(() => _obscure = !_obscure)),
                const SizedBox(height: 14),
                _Field('Confirm Password', _confirmCtrl, textColor, subColor,
                    hint: 'Repeat password', obscure: _obscure),
                const SizedBox(height: 24),

                GradientButton(
                  label: 'Create Account',
                  width: double.infinity,
                  loading: isLoading,
                  onTap: isLoading ? null : _submit,
                ),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('Already have an account? ',
                      style: GoogleFonts.dmSans(fontSize: 14, color: subColor)),
                  GestureDetector(
                    onTap: widget.onGoLogin,
                    child: Text('Sign in',
                        style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.accent,
                            fontWeight: FontWeight.w700)),
                  ),
                ]),
                const SizedBox(height: 40),
              ]),
            ),
          )),
        ]),
      ),
    );
  }

  Widget _Field(String label, TextEditingController ctrl, Color text, Color sub,
      {String hint = '', TextInputType type = TextInputType.text,
       bool obscure = false, VoidCallback? toggle}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: sub)),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl,
        style: GoogleFonts.dmSans(color: text),
        keyboardType: type,
        obscureText: obscure,
        decoration: InputDecoration(
          hintText: hint,
          suffixIcon: toggle != null
              ? GestureDetector(onTap: toggle,
                  child: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 18, color: sub))
              : null,
        ),
      ),
    ]);
  }
}

class _RoleTile extends StatelessWidget {
  final String icon, label;
  final bool selected;
  final VoidCallback onTap;
  final Color border;
  const _RoleTile({required this.icon, required this.label,
      required this.selected, required this.onTap, required this.border});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? AppColors.accent : border, width: 1.5),
        ),
        child: Column(children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 4),
          Text(label,
              style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600,
                  color: selected ? AppColors.accent : Colors.grey),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}