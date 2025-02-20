library svgaplayer_flutter_player;

import 'dart:math';
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
}

class SVGAAnimationController extends AnimationController {
  MovieEntity? _videoItem;
  final List<soundAnimation> _audioLayers = [];
  bool _canvasNeedsClear = false;
  bool _isDisposed = false;

  List<soundAnimation> get audioLayers => _audioLayers;

  SVGAAnimationController({required super.vsync}) : super(duration: Duration.zero);

  set videoItem(MovieEntity? value) {
    if (_isDisposed) return;
    if (isAnimating) stop();
    if (value == null) clear();
    _videoItem?.dispose();
    _videoItem = value;
    _audioLayers.clear();

    if (value != null) {
      final movieParams = value.params;
      assert(movieParams.viewBoxWidth >= 0 && movieParams.viewBoxHeight >= 0 && movieParams.frames >= 1, "Invalid SVGA file!");
      int fps = movieParams.fps > 0 ? movieParams.fps : 20;
      duration = Duration(milliseconds: (movieParams.frames / fps * 1000).toInt());
      for (var audio in value.audios) {
        _audioLayers.add(soundAnimation(audio, value));
      }
    } else {
      duration = Duration.zero;
    }
    reset();
  }

  @override
  void stop({bool canceled = true}) {
    for (final audio in _audioLayers) {
      audio.stopAudio();
    }
    super.stop(canceled: canceled);
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    for (final audio in _audioLayers) {
      audio.dispose();
    }
    _videoItem = null;
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
    if (!mounted) return;
    if (video == widget._controller.videoItem) {
      handleAudio();
    } else {
      setState(() {
        video = widget._controller.videoItem;
      });
    }
  }

  void _handleStatusChange(AnimationStatus status) {
    if (status == AnimationStatus.completed && widget.clearsAfterStop) {
      widget._controller.clear();
    }
  }

  void handleAudio() {
    for (final audio in widget._controller.audioLayers) {
      if (!audio.isPlaying() &&
          audio.audioItem.startFrame <= widget._controller.currentFrame &&
          audio.audioItem.endFrame >= widget._controller.currentFrame) {
        audio.playAudio();
      }
      if (audio.isPlaying() && audio.audioItem.endFrame < widget._controller.currentFrame) {
        audio.stopAudio();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final video = this.video;
    if (video == null || !video.isInitialized()) return const SizedBox.shrink();
    Size preferredSize = widget.preferredSize ?? Size(video.params.viewBoxWidth, video.params.viewBoxHeight);
    return IgnorePointer(
      child: CustomPaint(
        painter: _SVGAPainter(widget._controller, fit: widget.fit, filterQuality: widget.filterQuality, clipRect: widget.allowDrawingOverflow == false),
        size: preferredSize,
      ),
    );
  }
}

class soundAnimation {
  final AudioPlayer _player = AudioPlayer();
  final AudioEntity audioItem;
  final MovieEntity _videoItem;
  bool _isDisposed = false;

  soundAnimation(this.audioItem, this._videoItem);

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
        await _player.play(DeviceFileSource(cacheFile.path));
      } catch (e) {
        debugPrint('Failed to play audio: $e');
      }
    }
  }

  void stopAudio() {
    if (_isDisposed) return;
    _player.stop();
  }

  bool isPlaying() => _player.state == PlayerState.playing;

  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    await _player.dispose();
  }
}
