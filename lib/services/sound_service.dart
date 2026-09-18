import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme_data.dart';

class SoundService {
  static final SoundService instance = SoundService._internal();
  
  final AudioPlayer _player = AudioPlayer();
  final Map<SoundPreset, Uint8List> _soundCache = {};
  bool isSoundEnabled = true;
  bool isSentSoundEnabled = true;
  bool isReceivedSoundEnabled = true;
  final Map<String, DateTime?> _mutedConversations = {}; // conversationId -> muteUntil (null = forever)

  static const String _keySfxEnabled = 'sfx_sounds_enabled';
  static const String _keySentSoundEnabled = 'sfx_sent_sound_enabled';
  static const String _keyReceivedSoundEnabled = 'sfx_received_sound_enabled';

  SoundService._internal() {
    _init();
  }

  void _init() async {
    try {
      await _player.setPlayerMode(PlayerMode.lowLatency);
      final prefs = await SharedPreferences.getInstance();
      isSoundEnabled = prefs.getBool(_keySfxEnabled) ?? true;
      isSentSoundEnabled = prefs.getBool(_keySentSoundEnabled) ?? true;
      isReceivedSoundEnabled = prefs.getBool(_keyReceivedSoundEnabled) ?? true;
    } catch (_) {}
    _preloadAll();
  }

  void _preloadAll() {
    for (final preset in SoundPreset.values) {
      if (preset != SoundPreset.none) {
        _getPresetWav(preset);
      }
    }
  }

  Future<void> setSoundEnabled(bool enabled) async {
    isSoundEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keySfxEnabled, enabled);
    } catch (_) {}
  }

  Future<void> setSentSoundEnabled(bool enabled) async {
    isSentSoundEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keySentSoundEnabled, enabled);
    } catch (_) {}
  }

  Future<void> setReceivedSoundEnabled(bool enabled) async {
    isReceivedSoundEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyReceivedSoundEnabled, enabled);
    } catch (_) {}
  }

  void setMuted(String conversationId, {Duration? duration}) {
    if (duration == null) {
      _mutedConversations[conversationId] = null; // until unmuted
    } else {
      _mutedConversations[conversationId] = DateTime.now().add(duration);
    }
  }

  void unmute(String conversationId) {
    _mutedConversations.remove(conversationId);
  }

  bool isMuted(String conversationId) {
    if (!_mutedConversations.containsKey(conversationId)) return false;
    final until = _mutedConversations[conversationId];
    if (until == null) return true;
    if (DateTime.now().isAfter(until)) {
      _mutedConversations.remove(conversationId);
      return false;
    }
    return true;
  }

  // Generate PCM 16-bit 44.1kHz mono WAV bytes dynamically
  Uint8List _generateWav({
    required double durationSec,
    required double startFreq,
    required double endFreq,
    required double decayRate,
    double harmonicMix = 0.0,
    double harmonicMultiplier = 2.0,
  }) {
    const sampleRate = 44100;
    final numSamples = (sampleRate * durationSec).toInt();
    final dataSize = numSamples * 2;
    final totalSize = 44 + dataSize;

    final bytes = Uint8List(totalSize);
    final view = ByteData.view(bytes.buffer);

    // 1. RIFF chunk descriptor
    bytes.setRange(0, 4, 'RIFF'.codeUnits);
    view.setUint32(4, totalSize - 8, Endian.little);
    bytes.setRange(8, 12, 'WAVE'.codeUnits);

    // 2. fmt sub-chunk
    bytes.setRange(12, 16, 'fmt '.codeUnits);
    view.setUint32(16, 16, Endian.little); // Subchunk1Size (16 for PCM)
    view.setUint16(20, 1, Endian.little);  // AudioFormat (1 for PCM)
    view.setUint16(22, 1, Endian.little);  // NumChannels (1 = Mono)
    view.setUint32(24, sampleRate, Endian.little); // SampleRate
    view.setUint32(28, sampleRate * 2, Endian.little); // ByteRate (SampleRate * NumChannels * BitsPerSample/8)
    view.setUint16(32, 2, Endian.little);  // BlockAlign
    view.setUint16(34, 16, Endian.little); // BitsPerSample

    // 3. data sub-chunk
    bytes.setRange(36, 40, 'data'.codeUnits);
    view.setUint32(40, dataSize, Endian.little);

    // 4. Sample data generation (harmonic synthesis with exponential decay)
    var offset = 44;
    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      final progress = i / numSamples;
      final currentFreq = startFreq + (endFreq - startFreq) * progress;

      // Primary tone
      var sample = math.sin(2 * math.pi * currentFreq * t);

      // Harmonic tone
      if (harmonicMix > 0.0) {
        sample += harmonicMix * math.sin(2 * math.pi * (currentFreq * harmonicMultiplier) * t);
      }

      // Smooth decay envelope
      final envelope = math.exp(-decayRate * progress);
      sample *= envelope;

      // Soft clip / master gain
      final sampleInt16 = (sample * 26000).toInt().clamp(-32767, 32767);
      view.setInt16(offset, sampleInt16, Endian.little);
      offset += 2;
    }

    return bytes;
  }

  Uint8List _getPresetWav(SoundPreset preset) {
    if (_soundCache.containsKey(preset)) {
      return _soundCache[preset]!;
    }

    Uint8List wav;
    switch (preset) {
      case SoundPreset.softPop:
        // Pleasant rising bubble pop: 540Hz -> 920Hz in 90ms
        wav = _generateWav(
          durationSec: 0.09,
          startFreq: 540,
          endFreq: 920,
          decayRate: 4.5,
          harmonicMix: 0.15,
        );
        break;

      case SoundPreset.glass:
        // Crystalline bell chime: 1320Hz with pure octave harmonic 2640Hz in 160ms
        wav = _generateWav(
          durationSec: 0.16,
          startFreq: 1320,
          endFreq: 1320,
          decayRate: 5.0,
          harmonicMix: 0.35,
          harmonicMultiplier: 2.0,
        );
        break;

      case SoundPreset.pulse:
        // Soft rounded warm tone: 320Hz warm pulse in 120ms
        wav = _generateWav(
          durationSec: 0.12,
          startFreq: 320,
          endFreq: 260,
          decayRate: 3.8,
          harmonicMix: 0.1,
        );
        break;

      case SoundPreset.minimal:
        // Modern crisp UI tick: 1100Hz in 40ms
        wav = _generateWav(
          durationSec: 0.04,
          startFreq: 1100,
          endFreq: 1250,
          decayRate: 8.0,
        );
        break;

      case SoundPreset.classic:
        // Dual-harmonic chime: 680Hz -> 880Hz in 140ms
        wav = _generateWav(
          durationSec: 0.14,
          startFreq: 680,
          endFreq: 880,
          decayRate: 4.0,
          harmonicMix: 0.25,
        );
        break;

      case SoundPreset.softClick:
        // Snappy tactile switch click: 820Hz in 35ms
        wav = _generateWav(
          durationSec: 0.035,
          startFreq: 820,
          endFreq: 600,
          decayRate: 9.0,
        );
        break;

      case SoundPreset.none:
        wav = Uint8List(0);
        break;
    }

    _soundCache[preset] = wav;
    return wav;
  }

  // Play sound for a given preset
  Future<void> playPreset(SoundPreset preset, {bool enabled = true, String? conversationId}) async {
    if (!isSoundEnabled || !enabled || preset == SoundPreset.none) return;
    if (conversationId != null && isMuted(conversationId)) return;

    try {
      final wavBytes = _getPresetWav(preset);
      if (wavBytes.isEmpty) return;

      _player.play(BytesSource(wavBytes), mode: PlayerMode.lowLatency);
    } catch (e) {
      debugPrint('Sound play error: $e');
    }
  }

  // Play sent message chime
  Future<void> playSentSound({SoundPreset preset = SoundPreset.softPop, bool enabled = true}) async {
    if (!isSentSoundEnabled) return;
    await playPreset(preset, enabled: enabled);
  }

  // Play received message chime
  Future<void> playReceivedSound({
    SoundPreset preset = SoundPreset.glass,
    bool enabled = true,
    String? conversationId,
  }) async {
    if (!isReceivedSoundEnabled) return;
    await playPreset(preset, enabled: enabled, conversationId: conversationId);
  }

  void dispose() {
    _player.dispose();
  }
}
