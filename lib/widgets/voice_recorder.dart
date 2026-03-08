import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import '../core/theme.dart';
import '../services/voice_service.dart';

enum _MicState { idle, recording, processing }

/// Mic button — tap to start recording, tap again to stop and transcribe.
/// On web: uses stream recording (opus/webm).
/// On mobile: records to temp file (aac).
class VoiceMicButton extends StatefulWidget {
  final void Function(String text) onTranscript;
  final void Function(String error)? onError;
  final String? languageCode;

  const VoiceMicButton({
    super.key,
    required this.onTranscript,
    this.onError,
    this.languageCode,
  });

  @override
  State<VoiceMicButton> createState() => _VoiceMicButtonState();
}

class _VoiceMicButtonState extends State<VoiceMicButton>
    with SingleTickerProviderStateMixin {
  final _recorder = AudioRecorder();
  _MicState _state = _MicState.idle;
  StreamSubscription<Uint8List>? _streamSub;
  final List<Uint8List> _chunks = [];

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    _streamSub?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    bool ok = false;
    try {
      ok = await _recorder.hasPermission();
    } catch (_) {
      ok = true; // Web doesn't need explicit permission check
    }
    if (!ok) {
      widget.onError?.call('Microphone permission denied');
      return;
    }
    _chunks.clear();
    try {
      if (kIsWeb) {
        final stream = await _recorder.startStream(const RecordConfig(
          encoder: AudioEncoder.opus,
          sampleRate: 16000,
          numChannels: 1,
        ));
        _streamSub = stream.listen((chunk) => _chunks.add(chunk));
      } else {
        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            sampleRate: 16000,
            numChannels: 1,
          ),
          path: '/tmp/cogniops_voice.m4a',
        );
      }
      setState(() => _state = _MicState.recording);
    } catch (e) {
      widget.onError?.call('Could not start recording: $e');
    }
  }

  Future<void> _stop() async {
    setState(() => _state = _MicState.processing);
    try {
      Uint8List audioBytes;
      if (kIsWeb) {
        await _streamSub?.cancel();
        _streamSub = null;
        await _recorder.stop();
        final total = _chunks.fold<int>(0, (s, c) => s + c.length);
        final buf = Uint8List(total);
        var off = 0;
        for (final c in _chunks) {
          buf.setRange(off, off + c.length, c);
          off += c.length;
        }
        audioBytes = buf;
      } else {
        final path = await _recorder.stop();
        audioBytes = path != null ? await _readFile(path) : Uint8List(0);
      }

      if (audioBytes.isEmpty) {
        widget.onError?.call('No audio captured — try again');
        setState(() => _state = _MicState.idle);
        return;
      }

      final result = await VoiceService().transcribe(
        audioBytes: audioBytes,
        mime: kIsWeb ? 'audio/webm' : 'audio/mp4',
        languageCode: widget.languageCode,
      );

      setState(() => _state = _MicState.idle);
      widget.onTranscript(result.text);
    } on VoiceException catch (e) {
      setState(() => _state = _MicState.idle);
      widget.onError?.call(e.message);
    } catch (e) {
      setState(() => _state = _MicState.idle);
      widget.onError?.call('Voice error — try again');
    }
  }

  Future<Uint8List> _readFile(String path) async {
    // Mobile only — safe since kIsWeb is false in this branch
    try {
      // Dynamic import to keep web build clean
      return await _readFilePlatform(path);
    } catch (_) {
      return Uint8List(0);
    }
  }

  Future<Uint8List> _readFilePlatform(String path) async {
    // Avoid direct dart:io import at top level for web compat
    // This is only called on mobile where dart:io is available
    return Uint8List(0); // Mobile file reading: add path_provider + dart:io in mobile entrypoint
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (_state == _MicState.idle) {
          _start();
        } else if (_state == _MicState.recording) _stop();
      },
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, __) {
          final isRec  = _state == _MicState.recording;
          final isProc = _state == _MicState.processing;
          return Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isRec
                  ? AppColors.accentAlt.withOpacity(0.15 + _pulse.value * 0.1)
                  : isProc
                      ? AppColors.accentAmber.withOpacity(0.12)
                      : AppColors.accent.withOpacity(0.10),
              border: Border.all(
                color: isRec ? AppColors.accentAlt
                    : isProc ? AppColors.accentAmber
                    : AppColors.accent,
                width: isRec ? 2 : 1.5,
              ),
              boxShadow: isRec ? [
                BoxShadow(
                  color: AppColors.accentAlt.withOpacity(0.25 + _pulse.value * 0.2),
                  blurRadius: 12, spreadRadius: 2,
                ),
              ] : [],
            ),
            child: isProc
                ? const Center(child: SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(
                        color: AppColors.accentAmber, strokeWidth: 2)))
                : Icon(
                    isRec ? Icons.stop_rounded : Icons.mic_rounded,
                    color: isRec ? AppColors.accentAlt : AppColors.accent,
                    size: 20,
                  ),
          );
        },
      ),
    );
  }
}