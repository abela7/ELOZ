import 'dart:io';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';

/// Service for playing notification sounds on specific audio streams.
/// 
/// Uses flutter_ringtone_player with asAlarm: true to bypass silent mode.
/// Falls back to just_audio for non-alarm streams.
class SoundPlayerService {
  static final SoundPlayerService _instance = SoundPlayerService._internal();
  factory SoundPlayerService() => _instance;
  SoundPlayerService._internal();

  final FlutterRingtonePlayer _ringtonePlayer = FlutterRingtonePlayer();
  AudioPlayer? _player;
  bool _initialized = false;

  /// Initialize the sound player service
  Future<void> initialize() async {
    if (_initialized) return;
    
    _player = AudioPlayer();
    _initialized = true;
    print('🔊 SoundPlayerService: Initialized');
  }

  /// Play a notification sound on the specified audio stream.
  /// 
  /// For 'alarm' stream, uses flutter_ringtone_player with asAlarm: true
  /// which bypasses silent mode on Android.
  Future<void> playSound({
    required String stream,
    required String soundKey,
  }) async {
    if (!_initialized) await initialize();
    
    if (soundKey == 'silent') {
      print('🔊 SoundPlayerService: Sound is silent, skipping');
      return;
    }

    print('🔊 SoundPlayerService: Playing $soundKey on $stream stream');

    // For ALARM stream, use flutter_ringtone_player with asAlarm: true
    // This is the most reliable way to bypass silent mode
    if (stream == 'alarm') {
      await _playWithRingtonePlayer(soundKey);
      return;
    }

    // For other streams, use just_audio with audio_session
    await _playWithJustAudio(stream, soundKey);
  }

  /// Play using flutter_ringtone_player (bypasses silent mode)
  Future<void> _playWithRingtonePlayer(String soundKey) async {
    try {
      // Stop any previous sound
      await _ringtonePlayer.stop();
      
      // Check if it's a custom URI (user-selected sound)
      if (soundKey.startsWith('content://') || soundKey.startsWith('file://')) {
        print('🔊 Playing custom sound with asAlarm: $soundKey');
        // For custom URIs, use the URI directly
        // Note: flutter_ringtone_player may not support content:// URIs directly
        // Fall back to just_audio for custom sounds but with alarm session
        await _playCustomSoundAsAlarm(soundKey);
        return;
      }
      
      // For built-in sound keys, use the appropriate ringtone player method
      switch (soundKey) {
        case 'alarm':
          print('🔊 Playing system ALARM sound with asAlarm: true');
          await _ringtonePlayer.play(
            android: AndroidSounds.alarm,
            ios: IosSounds.alarm,
            looping: false,
            volume: 1.0,
            asAlarm: true, // THIS IS THE KEY - bypasses silent mode!
          );
          break;
        case 'bell':
        case 'ring':
          print('🔊 Playing system RINGTONE with asAlarm: true');
          await _ringtonePlayer.play(
            android: AndroidSounds.ringtone,
            ios: IosSounds.electronic,
            looping: false,
            volume: 1.0,
            asAlarm: true,
          );
          break;
        case 'gentle':
        case 'chime':
        case 'notification':
          print('🔊 Playing system NOTIFICATION with asAlarm: true');
          await _ringtonePlayer.play(
            android: AndroidSounds.notification,
            ios: IosSounds.triTone,
            looping: false,
            volume: 1.0,
            asAlarm: true,
          );
          break;
        case 'default':
        default:
          print('🔊 Playing DEFAULT alarm sound with asAlarm: true');
          await _ringtonePlayer.play(
            android: AndroidSounds.alarm,
            ios: IosSounds.alarm,
            looping: false,
            volume: 1.0,
            asAlarm: true,
          );
          break;
      }
      
      print('🔊 SoundPlayerService: Ringtone player started');
    } catch (e) {
      print('⚠️ SoundPlayerService: Ringtone player error: $e');
      // Fall back to just_audio
      await _playWithJustAudio('alarm', soundKey);
    }
  }

  /// Play custom sound (content:// URI) with alarm audio session
  Future<void> _playCustomSoundAsAlarm(String soundUri) async {
    if (_player == null) return;
    
    try {
      await _player!.stop();
      
      // Configure for alarm stream
      if (Platform.isAndroid) {
        final session = await AudioSession.instance;
        await session.configure(AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.sonification,
            usage: AndroidAudioUsage.alarm,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        ));
      }
      
      await _player!.setUrl(soundUri);
      await _player!.play();
      
      // Wait for completion
      await _player!.playerStateStream.firstWhere(
        (state) => state.processingState == ProcessingState.completed,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => _player!.playerState,
      );
      
      print('🔊 Custom sound playback complete');
    } catch (e) {
      print('⚠️ Custom sound error: $e');
    }
  }

  /// Play using just_audio with audio_session (for non-alarm streams)
  Future<void> _playWithJustAudio(String stream, String soundKey) async {
    if (_player == null) return;
    
    try {
      await _player!.stop();
      await _configureAudioSession(stream);
      
      final soundUri = _getSoundUri(soundKey);
      if (soundUri == null) {
        print('⚠️ SoundPlayerService: No sound URI for key: $soundKey');
        return;
      }
      
      print('🔊 Playing with just_audio: $soundUri');
      await _player!.setUrl(soundUri);
      await _player!.play();
      
      await _player!.playerStateStream.firstWhere(
        (state) => state.processingState == ProcessingState.completed,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => _player!.playerState,
      );
      
      print('🔊 just_audio playback complete');
    } catch (e) {
      print('⚠️ SoundPlayerService: just_audio error: $e');
    }
  }

  /// Configure the audio session for the specified stream
  Future<void> _configureAudioSession(String stream) async {
    if (!Platform.isAndroid) return;
    
    final session = await AudioSession.instance;
    
    AndroidAudioUsage usage;
    AndroidAudioContentType contentType;
    AndroidAudioFocusGainType focusType;
    
    switch (stream) {
      case 'alarm':
        usage = AndroidAudioUsage.alarm;
        contentType = AndroidAudioContentType.sonification;
        focusType = AndroidAudioFocusGainType.gain;
        break;
      case 'ring':
        usage = AndroidAudioUsage.notificationRingtone;
        contentType = AndroidAudioContentType.sonification;
        focusType = AndroidAudioFocusGainType.gain;
        break;
      case 'media':
        usage = AndroidAudioUsage.media;
        contentType = AndroidAudioContentType.music;
        focusType = AndroidAudioFocusGainType.gainTransientMayDuck;
        break;
      case 'notification':
      default:
        usage = AndroidAudioUsage.notification;
        contentType = AndroidAudioContentType.sonification;
        focusType = AndroidAudioFocusGainType.gainTransientMayDuck;
        break;
    }
    
    await session.configure(AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.duckOthers,
      avAudioSessionMode: AVAudioSessionMode.defaultMode,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: contentType,
        usage: usage,
      ),
      androidAudioFocusGainType: focusType,
      androidWillPauseWhenDucked: false,
    ));
    
    print('🔊 Audio session configured for $stream');
  }

  /// Get the system sound URI for the given sound key
  String? _getSoundUri(String soundKey) {
    if (!Platform.isAndroid) return null;
    
    if (soundKey.startsWith('content://') || soundKey.startsWith('file://')) {
      return soundKey;
    }
    
    switch (soundKey) {
      case 'alarm':
        return 'content://settings/system/alarm_alert';
      case 'bell':
      case 'ring':
        return 'content://settings/system/ringtone';
      case 'gentle':
      case 'chime':
      case 'notification':
        return 'content://settings/system/notification_sound';
      case 'default':
      default:
        return 'content://settings/system/notification_sound';
    }
  }

  /// Stop any currently playing sound
  Future<void> stop() async {
    try {
      await _ringtonePlayer.stop();
      await _player?.stop();
    } catch (e) {
      print('⚠️ SoundPlayerService stop error: $e');
    }
  }

  /// Dispose the player when no longer needed
  Future<void> dispose() async {
    await stop();
    await _player?.dispose();
    _player = null;
    _initialized = false;
  }
}
