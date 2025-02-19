import 'dart:developer';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'proto/svga.pb.dart';
import 'dart:io';

class SVGAAudioLayer {
  final AudioPlayer _player = AudioPlayer();
  late final AudioEntity audioItem;
  late final MovieEntity _videoItem;
  bool _isReady = false;

  SVGAAudioLayer(this.audioItem, this._videoItem);

  Future<void> playAudio() async {
    final audioData = _videoItem.audiosData[audioItem.audioKey];
    if (audioData != null) {
      try {
        if (!_isReady) {
          _isReady = true;
          await _player.play(BytesSource(audioData)).then((_) {
            _isReady = false;
          }).catchError((e) {
            log('Audio play error: $e');
            _isReady = false;
          });
        }
      } catch (e) {
        log('Failed to play audio: $e');
      }
    }
  }

  void pauseAudio() {
    _player.pause();
  }

  void resumeAudio() {
    _player.resume();
  }

  void stopAudio() {
    if (isPlaying() || isPaused()) _player.stop();
  }

  bool isPlaying() {
    return _player.state == PlayerState.playing;
  }

  bool isPaused() {
    return _player.state == PlayerState.paused;
  }

  Future<void> dispose() async {
    if (_player.state != PlayerState.stopped) {
      await _player.stop();
    }
    await _player.dispose();
  }
}
