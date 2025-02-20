import 'dart:developer';
import 'package:flutter/widgets.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:math';
import 'proto/svga.pb.dart';
import 'parser.dart';
part 'painter.dart';
part 'simple_player.dart';

class SVGAAudioLayer {
  final AudioPlayer _player = AudioPlayer();
  late final AudioEntity audioItem;
  late final MovieEntity _videoItem;
  bool _isReady = false;

  SVGAAudioLayer(this.audioItem, this._videoItem);

  Future<void> playAudio() async {
    final audioData = _videoItem.audiosData[audioItem.audioKey];
    if (audioData != null) {
      final cacheDir = await getApplicationCacheDirectory();
      final cacheFile = File('${cacheDir.path}/temp_${audioItem.audioKey}.mp3');

      if (!cacheFile.existsSync()) {
        await cacheFile.writeAsBytes(audioData);
      }

      try {
        if (!_isReady) {
          _isReady = true;
          await _player.play(DeviceFileSource(cacheFile.path));
          _isReady = false;
        }
      } catch (e) {
        log('Failed to play audio: $e');
      }
    }
  }

  void pauseAudio() => _player.pause();
  void resumeAudio() => _player.resume();
  void stopAudio() {
    if (isPlaying() || isPaused()) _player.stop();
  }

  bool isPlaying() => _player.state == PlayerState.playing;
  bool isPaused() => _player.state == PlayerState.paused;

  Future<void> dispose() async {
    if (isPlaying()) stopAudio();
    await _player.dispose();
  }
}

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
  final List<SVGAAudioLayer> _audioLayers = [];
  bool _canvasNeedsClear = false;

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
      int fps = movieParams.fps == 0 ? 20 : movieParams.fps;
      duration = Duration(milliseconds: (movieParams.frames / fps * 1000).toInt());

      for (var audio in value.audios) {
        _audioLayers.add(SVGAAudioLayer(audio, value));
      }
    } else {
      duration = Duration.zero;
    }
    reset();
  }

  MovieEntity? get videoItem => _videoItem;
  int get currentFrame => _videoItem == null ? 0 : min(_videoItem!.params.frames - 1, max(0, (_videoItem!.params.frames.toDouble() * value).toInt()));
  int get frames => _videoItem?.params.frames ?? 0;

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
        handleAudio();
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

  void handleAudio() {
    final audioLayers = widget._controller._audioLayers;
    for (final audio in audioLayers) {
      if (!audio.isPlaying() && audio.audioItem.startFrame <= widget._controller.currentFrame && audio.audioItem.endFrame >= widget._controller.currentFrame) {
        audio.playAudio();
      }
      if (audio.isPlaying() && audio.audioItem.endFrame <= widget._controller.currentFrame) {
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
    final Size viewBoxSize = (video == null || !video.isInitialized()) ? Size.zero : Size(video.params.viewBoxWidth, video.params.viewBoxHeight);

    if (viewBoxSize.isEmpty) {
      return const SizedBox.shrink();
    }

    Size preferredSize = widget.preferredSize ?? viewBoxSize;
    return IgnorePointer(
      child: CustomPaint(
        painter: _SVGAPainter(widget._controller, fit: widget.fit, filterQuality: widget.filterQuality, clipRect: widget.allowDrawingOverflow == false),
        size: preferredSize,
      ),
    );
  }
}
