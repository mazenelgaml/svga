library svgaplayer_flutter_player;

import 'dart:math';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:svgaplayer_flutter/proto/svga.pb.dart';
import 'parser.dart';

part 'painter.dart';
part 'simple_player.dart';

class SVGAImage extends StatefulWidget {
  final SVGAAnimationController _controller;
  final BoxFit fit;
  final bool clearsAfterStop;
  final FilterQuality filterQuality;
  final bool? allowDrawingOverflow;
  final Size? preferredSize;

  const SVGAImage(
    this._controller, {
    super.key,
    this.fit = BoxFit.contain,
    this.filterQuality = FilterQuality.low,
    this.allowDrawingOverflow,
    this.clearsAfterStop = true,
    this.preferredSize,
  });

  @override
  State<StatefulWidget> createState() => _SVGAImageState();
}

class SVGAAnimationController extends AnimationController {
  MovieEntity? _videoItem;
  final List<SoundAnimation> _audioLayers = [];
  bool _canvasNeedsClear = false;
  bool _isDisposed = false;

  List<SoundAnimation> get audioLayers => _audioLayers;
  
  SVGAAnimationController({required super.vsync}) : super(duration: Duration.zero);

  set videoItem(MovieEntity? value) {
    assert(!_isDisposed, '$this has been disposed!');
    if (_isDisposed) return;
    if (isAnimating) stop();
    if (value == null) clear();
    if (_videoItem != null && _videoItem!.autorelease) _videoItem!.dispose();
    
    _videoItem = value;
    if (value != null) {
      final movieParams = value.params;
      assert(movieParams.viewBoxWidth >= 0 && movieParams.viewBoxHeight >= 0 && movieParams.frames >= 1, "Invalid SVGA file!");
      int fps = movieParams.fps;
      if (fps == 0) fps = 20;
      duration = Duration(milliseconds: (movieParams.frames / fps * 1000).toInt());

      for (var audio in value.audios) {
        _audioLayers.add(SoundAnimation(audio, value));
      }
    } else {
      duration = Duration.zero;
    }
    reset();
  }

  void clear() {
    _canvasNeedsClear = true;
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    for (final audio in _audioLayers) {
      audio.dispose();
    }
    videoItem = null;
    super.dispose();
  }
}

class SoundAnimation {
  final AudioPlayer _player = AudioPlayer();
  final AudioEntity audioItem;
  final MovieEntity _videoItem;
  bool _isDisposed = false;

  SoundAnimation(this.audioItem, this._videoItem);

  Future<void> playAudio() async {
    if (_isDisposed || isPlaying()) return;
    final audioData = _videoItem.audiosData[audioItem.audioKey];
    if (audioData != null) {
      final cacheDir = await getApplicationCacheDirectory();
      final cacheFile = File('${cacheDir.path}/temp_${audioItem.audioKey}.mp3');
      if (!cacheFile.existsSync()) {
        await cacheFile.writeAsBytes(audioData);
      }
      try {
        if (!_isDisposed) {
          await _player.play(DeviceFileSource(cacheFile.path));
        }
      } catch (e) {
        debugPrint('Failed to play audio: $e'); 
      }
    }
  }

  void pauseAudio() {
    if (_isDisposed) return;
    _player.pause();
  }

  void stopAudio() {
    if (_isDisposed || (!isPlaying() && !isPaused())) return;
    _player.stop();
  }

  void setVolume(double volume) {
    if (_isDisposed) return;
    _player.setVolume(volume);
  }

  void muteAudio(bool mute) {
    if (_isDisposed) return;
    _player.setVolume(mute ? 0 : 1);
  }

  bool isPlaying() => _player.state == PlayerState.playing;
  bool isPaused() => _player.state == PlayerState.paused;

  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    if (isPlaying()) stopAudio();
    await _player.dispose();
  }
}
