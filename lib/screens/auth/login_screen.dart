import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/bedrock_service.dart';
import '../../widgets/common_widgets.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onGoRegister;
  const LoginScreen({super.key, required this.onGoRegister});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _obscure = true;

  @override void dispose() { _emailCtrl.dispose(); _passCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (_emailCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) return;
    // Clear previous session
    context.read<ChatProvider>().clear();
    BedrockService.resetSession();
    await context.read<AuthProvider>().login(
      _emailCtrl.text.trim().toLowerCase(),
      _passCtrl.text,
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

    return Scaffold(
      backgroundColor: surface,
      body: SafeArea(
        child: Column(children: [
          // Top bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              Container(width: 32, height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.accent, AppColors.accentAlt]),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 16)),
              const SizedBox(width: 8),
              Text('CogniOps',
                  style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800, color: textColor)),
              const Spacer(),
              GestureDetector(
                onTap: () => context.read<ThemeProvider>().toggle(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: surfaceAlt, borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: border)),
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
                const SizedBox(height: 40),
                Text('Welcome back 👋',
                    style: GoogleFonts.dmSans(fontSize: 28, fontWeight: FontWeight.w800, color: textColor)),
                const SizedBox(height: 6),
                Text('Sign in to continue your cloud journey',
                    style: GoogleFonts.dmSans(fontSize: 14, color: subColor)),
                const SizedBox(height: 36),

                if (auth.error != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.accentAlt.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.accentAlt.withOpacity(0.3)),
                    ),
                    child: Text(auth.error!,
                        style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.accentAlt)),
                  ),

                // Email
                Text('Email', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: subColor)),
                const SizedBox(height: 6),
                TextField(
                  controller: _emailCtrl,
                  style: GoogleFonts.dmSans(color: textColor),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(hintText: 'you@example.com'),
                ),
                const SizedBox(height: 16),

                // Password
                Text('Password', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: subColor)),
                const SizedBox(height: 6),
                TextField(
                  controller: _passCtrl,
                  style: GoogleFonts.dmSans(color: textColor),
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    suffixIcon: GestureDetector(
                      onTap: () => setState(() => _obscure = !_obscure),
                      child: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 18, color: subColor),
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                GradientButton(
                  label: 'Sign In',
                  width: double.infinity,
                  loading: isLoading,
                  onTap: isLoading ? null : _submit,
                ),
                const SizedBox(height: 20),

                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text("Don't have an account? ",
                      style: GoogleFonts.dmSans(fontSize: 14, color: subColor)),
                  GestureDetector(
                    onTap: widget.onGoRegister,
                    child: Text('Sign up',
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
}
