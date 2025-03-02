import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:svgaplayer_flutter/proto/svga.pb.dart';

class AudioHandler {
  final AudioPlayer _player = AudioPlayer();
  bool _isMuted = false;
  bool _isPlaying = false;
  File? _audioFile;

  AudioHandler._privateConstructor();
  static final AudioHandler _instance = AudioHandler._privateConstructor();
  
  factory AudioHandler() {
    return _instance;
  }

  // Play audio from the SVGA MovieEntity, and listen for SVGA completion
  Future<void> playAudioFromSVGA(MovieEntity videoItem, Function onFinish) async {
    if (videoItem.audios.isEmpty) return;

    final audioData = videoItem.audiosData[videoItem.audios.first.audioKey];
    if (audioData == null) {
      print('❌ No audio data found.');
      return;
    }

    final cacheDir = await getTemporaryDirectory();
    _audioFile = File('${cacheDir.path}/temp_audio.mp3');

    if (!_audioFile!.existsSync()) {
      await _audioFile!.writeAsBytes(audioData);
    }

    // Ensure the audio is played from the correct file and unmuted
    await _player.setVolume(_isMuted ? 0 : 1);  // Set volume based on mute state
    await _player.play(DeviceFileSource(_audioFile!.path));
    _isPlaying = true;

    // Trigger onFinish callback when the SVGA animation finishes
    onFinish();
  }

  void muteAudio(bool mute) {
    _isMuted = mute;
    _player.setVolume(mute ? 0 : 1); // Adjust audio volume
  }

  void pauseAudio() {
    if (_isPlaying) {
      _player.pause();
      _isPlaying = false;
    }
  }

  void resumeAudio() {
    if (!_isPlaying) {
      _player.resume();
      _isPlaying = true;
    }
  }

  void dispose() {
    _player.dispose();
    if (_audioFile != null && _audioFile!.existsSync()) {
      _audioFile!.delete();
    }
  }
}
