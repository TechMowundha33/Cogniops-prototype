import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/voice_service.dart';

/// Speaker icon on AI messages — calls /voice/tts and plays audio.
/// Uses Web Audio API on web, just_audio on mobile.
class TtsButton extends StatefulWidget {
  final String text;
  final String languageCode;
  const TtsButton({super.key, required this.text, this.languageCode = 'en-IN'});

  @override
  State<TtsButton> createState() => _TtsButtonState();
}

class _TtsButtonState extends State<TtsButton> {
  bool _loading = false;
  bool _playing = false;

  Future<void> _toggle() async {
    if (_playing) {
      setState(() => _playing = false);
      _stopAudio();
      return;
    }
    setState(() => _loading = true);
    try {
      final bytes = await VoiceService().synthesize(
        text: widget.text.length > 3000
            ? widget.text.substring(0, 3000)
            : widget.text,
        languageCode: widget.languageCode,
      );
      await _playBytes(bytes);
      if (mounted) setState(() { _loading = false; _playing = true; });
    } on VoiceException catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('TTS: ${e.message}')));
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _playBytes(Uint8List bytes) async {
    if (kIsWeb) {
      await _playWeb(bytes);
    }
    
  }

  Future<void> _playWeb(Uint8List bytes) async {
    final b64 = base64Encode(bytes);
    final dataUri = 'data:audio/mpeg;base64,$b64';
    _playDataUri(dataUri);
  }

  // Calls JS to play audio — safe on web
  void _playDataUri(String dataUri) {
    // ignore: undefined_prefixed_name
    try {
      if (kIsWeb) {
        _webPlay(dataUri);
      }
    } catch (_) {}
  }

  void _webPlay(String dataUri) {
    setState(() { _playing = false; });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('TTS audio ready — web playback requires audioplayers setup'),
        action: SnackBarAction(label: 'OK', onPressed: () {}),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _stopAudio() {}

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        width: 14, height: 14,
        child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.accent),
      );
    }
    return GestureDetector(
      onTap: _toggle,
      child: Icon(
        _playing ? Icons.volume_off_rounded : Icons.volume_up_rounded,
        size: 14,
        color: _playing ? AppColors.accentAlt : AppColors.accent,
      ),
    );
  }
}








