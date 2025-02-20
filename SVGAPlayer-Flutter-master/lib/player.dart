library svgaplayer_flutter_player;

import 'dart:math';
import 'dart:developer' as developer;

import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:path_drawing/path_drawing.dart';
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

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Listenable>('controller', _controller));
  }
}

class SVGAAnimationController extends AnimationController {
  MovieEntity? _videoItem;
  final List<soundAnimation> _audioLayers = [];
  bool _canvasNeedsClear = false;

 List<soundAnimation> get audioLayers => _audioLayers;
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
        _audioLayers.add(soundAnimation(audio, value));
      }
    } else {
      duration = Duration.zero;
    }
    reset();
  }

  MovieEntity? get videoItem => _videoItem;

  int get currentFrame {
    final videoItem = _videoItem;
    if (videoItem == null) return 0;
    return min(videoItem.params.frames - 1, max(0, (videoItem.params.frames.toDouble() * value).toInt()));
  }

  int get frames {
    final videoItem = _videoItem;
    if (videoItem == null) return 0;
    return videoItem.params.frames;
  }

  void clear() {
    _canvasNeedsClear = true;
    if (!_isDisposed) notifyListeners();
  }

  @override
  TickerFuture forward({double? from}) {
    assert(_videoItem != null, 'SVGAAnimationController.forward() called after dispose()?');
    return super.forward(from: from);
  }

  @override
  void stop({bool canceled = true}) {
    for (final audio in _audioLayers) {
      audio.pauseAudio();
    }
    super.stop(canceled: canceled);
  }

  bool _isDisposed = false;
  @override
  void dispose() {
    for (final audio in _audioLayers) {
      audio.dispose();
    }
    videoItem = null;
    _isDisposed = true;
    super.dispose();
  }
}

class _SVGAImageState extends State<SVGAImage> {
  MovieEntity? video;

  @override
  void initState() {
    super.initState();
    video = widget._controller.videoItem;
    widget._controller.addListener(_handleChange);
    widget._controller.addStatusListener(_handleStatusChange);
  }

  @override
  void didUpdateWidget(SVGAImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget._controller != widget._controller) {
      oldWidget._controller.removeListener(_handleChange);
      oldWidget._controller.removeStatusListener(_handleStatusChange);
      video = widget._controller.videoItem;
      widget._controller.addListener(_handleChange);
      widget._controller.addStatusListener(_handleStatusChange);
    }
  }

  void _handleChange() {
    if (mounted) {
      if (video == widget._controller.videoItem) {
        manageAudioPlayback();
      } else if (!widget._controller._isDisposed) {
        setState(() {
          video = widget._controller.videoItem;
        });
      }
    }
  }

  void _handleStatusChange(AnimationStatus status) {
    if (status == AnimationStatus.completed && widget.clearsAfterStop) {
      widget._controller.clear();
    }
  }

  void manageAudioPlayback() {
  final audioLayers = widget._controller.audioLayers;
  final currentFrame = widget._controller.currentFrame;

  for (final audio in audioLayers) {
    final audioItem = audio.audioItem;
    final isPlaying = audio.isPlaying();

    if (!isPlaying && audioItem.startFrame <= currentFrame && audioItem.endFrame >= currentFrame) {
      audio.playAudio();
    } 
    else if (isPlaying && audioItem.endFrame < currentFrame) {
      audio.stopAudio();
    }
  }
}


  @override
  void dispose() {
    video = null;
    widget._controller.removeListener(_handleChange);
    widget._controller.removeStatusListener(_handleStatusChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final video = this.video;
    final Size viewBoxSize;
    if (video == null || !video.isInitialized()) {
      viewBoxSize = Size.zero;
    } else {
      viewBoxSize = Size(video.params.viewBoxWidth, video.params.viewBoxHeight);
    }
    if (viewBoxSize.isEmpty) {
      return const SizedBox.shrink();
    }
    Size preferredSize = viewBoxSize;
    if (widget.preferredSize != null) {
      preferredSize = BoxConstraints.tight(widget.preferredSize!).constrain(viewBoxSize);
    }
    return IgnorePointer(
      child: CustomPaint(
        painter: _SVGAPainter(
          widget._controller,
          fit: widget.fit,
          filterQuality: widget.filterQuality,
          clipRect: widget.allowDrawingOverflow == false,
        ),
        size: preferredSize,
      ),
    );
  }
}

class soundAnimation {
  final AudioPlayer _player = AudioPlayer();
  late final AudioEntity audioItem;
  late final MovieEntity _videoItem;
  bool _isReady = false;
  bool _isDisposed = false;

  // تعريف _audioLayers لمنع الأخطاء
  List<soundAnimation> _audioLayers = [];

  // تعريف videoItem لمنع الأخطاء
  MovieEntity? videoItem;

  soundAnimation(this.audioItem, this._videoItem);

  Future<void> playAudio() async {
    if (_isDisposed || isPlaying()) return;

    final audioData = _videoItem.audiosData[audioItem.audioKey];
    if (audioData == null) {
      debugPrint('❌ Audio data is null for key: ${audioItem.audioKey}');
      return;
    }

    final cacheDir = await getApplicationCacheDirectory();
    final cacheFile = File('${cacheDir.path}/temp_${audioItem.audioKey}.mp3');

    if (!cacheFile.existsSync()) {
      await cacheFile.writeAsBytes(audioData);
      debugPrint('✅ Audio file created: ${cacheFile.path}');
    } else {
      debugPrint('🔍 Audio file already exists: ${cacheFile.path}');
    }

    try {
      if (!_isReady) {
        _isReady = true;
        await _player.play(DeviceFileSource(cacheFile.path));
        debugPrint('🔊 Playing audio from: ${cacheFile.path}');
        _isReady = false;
      }
    } catch (e) {
      debugPrint('❌ Failed to play audio: $e');
    }
  }

  void pauseAudio() => _player.pause();
  void resumeAudio() => _player.resume();

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

void dispose() {
  if (_isDisposed) return;

  // التأكد من إيقاف جميع الأصوات قبل التخلص
  for (final audio in _audioLayers) {
    audio.stopAudio();
  }

  // إلغاء مرجع الفيديو
  videoItem = null;

  // التأكد من أن _player لم يتم التخلص منه مسبقًا قبل استدعاء dispose
  try {
    if (_player.state != PlayerState.disposed) {
      _player.dispose();
    }
  } catch (e) {
    debugPrint('Error while disposing AudioPlayer: $e');
  }

  _isDisposed = true;
}

}
