import 'dart:math';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:svgaplayer_flutter/proto/svga.pb.dart';
import 'parser.dart';

class SVGAPlayer extends StatefulWidget {
  final SVGAController controller;
  final BoxFit fit;
  final bool clearsAfterStop;
  final FilterQuality filterQuality;
  final bool allowDrawingOverflow;
  final Size? preferredSize;
  final bool autoPlay;
  final bool loop;
  final double playbackSpeed;

  const SVGAPlayer({
    super.key,
    required this.controller,
    this.fit = BoxFit.contain,
    this.filterQuality = FilterQuality.low,
    this.allowDrawingOverflow = true,
    this.clearsAfterStop = true,
    this.preferredSize,
    this.autoPlay = true,
    this.loop = false,
    this.playbackSpeed = 1.0,
  });

  @override
  State<SVGAPlayer> createState() => _SVGAPlayerState();
}

class SVGAController extends ChangeNotifier {
  MovieEntity? _video;
  final List<SVGAudioLayer> _audioLayers = [];
  bool _isDisposed = false;
  bool _needsClear = false;
  AnimationController? _animationController;
  bool _isPlaying = false;
  bool loop = false;
  double playbackSpeed = 1.0;

  SVGAController({
    required TickerProvider vsync,
    this.loop = false,
    this.playbackSpeed = 1.0,
  }) {
    _animationController = AnimationController(vsync: vsync);
    _animationController!.addListener(notifyListeners);
    _animationController!.addStatusListener(_onAnimationStatusChanged);
  }

  set video(MovieEntity? value) {
    if (_isDisposed) return;
    if (_animationController!.isAnimating) stop();
    _clearResources();

    _video = value;
    if (value != null) {
      _setupAnimation(value);
      _setupAudio(value);
    }
    notifyListeners();
  }

  MovieEntity? get video => _video;
  bool get isPlaying => _isPlaying;
  int get currentFrame => _calculateCurrentFrame();
  int get frames => _video?.params.frames ?? 0;

  void play() {
    if (_isDisposed || _video == null) return;
    _animationController!.forward(from: 0);
    _isPlaying = true;
  }

  void pause() {
    if (_isDisposed) return;
    _animationController!.stop();
    _isPlaying = false;
  }

  void resume() {
    if (_isDisposed || _video == null) return;
    _animationController!.forward();
    _isPlaying = true;
  }

  void stop() {
    _animationController!.stop();
    _isPlaying = false;
    notifyListeners();
  }

  void disposeController() {
    _clearResources();
    _animationController?.dispose();
    _isDisposed = true;
    super.dispose();
  }

  void _setupAnimation(MovieEntity video) {
    int fps = video.params.fps == 0 ? 20 : video.params.fps;
    _animationController!.duration =
        Duration(milliseconds: (video.params.frames / fps * 1000 ~/ playbackSpeed));
  }

  void _setupAudio(MovieEntity video) {
    for (var audio in video.audios) {
      _audioLayers.add(SVGAudioLayer(audio, video));
    }
  }

  void _onAnimationStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      if (loop) {
        _animationController!.forward(from: 0);
      } else if (_needsClear) {
        _needsClear = false;
        notifyListeners();
      }
    }
  }

  int _calculateCurrentFrame() {
    if (_video == null) return 0;
    return min(
      _video!.params.frames - 1,
      max(0, (_video!.params.frames.toDouble() * _animationController!.value).toInt()),
    );
  }

  void _clearResources() {
    for (var audio in _audioLayers) {
      audio.dispose();
    }
    _audioLayers.clear();
  }
}

class _SVGAPlayerState extends State<SVGAPlayer> {
  MovieEntity? _video;

  @override
  void initState() {
    super.initState();
    _video = widget.controller.video;
    widget.controller.addListener(_onControllerUpdate);
    if (widget.autoPlay) {
      widget.controller.play();
    }
  }

  @override
  void didUpdateWidget(SVGAPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerUpdate);
      widget.controller.addListener(_onControllerUpdate);
    }
  }

  void _onControllerUpdate() {
    if (mounted) {
      setState(() {
        _video = widget.controller.video;
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_video == null || !_video!.isInitialized()) return const SizedBox.shrink();
    Size viewBoxSize = Size(_video!.params.viewBoxWidth, _video!.params.viewBoxHeight);
    Size preferredSize = widget.preferredSize ?? viewBoxSize;
    return AnimatedOpacity(
      opacity: widget.controller.isPlaying ? 1.0 : 0.5,
      duration: const Duration(milliseconds: 300),
      child: CustomPaint(
        painter: _SVGAPainter(widget.controller, widget.fit, widget.filterQuality),
        size: preferredSize,
      ),
    );
  }
}

class SVGAudioLayer {
  final AudioPlayer _player = AudioPlayer();
  final AudioEntity audioItem;
  final MovieEntity _video;
  bool _isPlaying = false;

  SVGAudioLayer(this.audioItem, this._video);

  Future<void> play() async {
    if (_isPlaying) return;
    final Uint8List? audioData = _video.audiosData[audioItem.audioKey];
    if (audioData != null) {
      final filePath = await _saveTempAudio(audioData, audioItem.audioKey);
      if (filePath != null) {
        _isPlaying = true;
        await _player.play(DeviceFileSource(filePath));
        _isPlaying = false;
      }
    }
  }

  Future<String?> _saveTempAudio(Uint8List data, String key) async {
    final dir = await getApplicationCacheDirectory();
    final file = File('${dir.path}/temp_$key.mp3');
    if (!file.existsSync()) await file.writeAsBytes(data);
    return file.path;
  }

  void pause() => _player.pause();
  void stop() {
    if (_isPlaying) _player.stop();
  }

  bool isPlaying() => _player.state == PlayerState.playing;
  void dispose() {
    if (_isPlaying) stop();
    _player.dispose();
  }
}

class _SVGAPainter extends CustomPainter {
  final SVGAController controller;
  final BoxFit fit;
  final FilterQuality filterQuality;

  _SVGAPainter(this.controller, this.fit, this.filterQuality) : super(repaint: controller);

  @override
  void paint(Canvas canvas, Size size) {
    if (controller.video == null) return;
    final frame = controller.currentFrame;
    final video = controller.video!;
    final paint = Paint()..filterQuality = filterQuality;
    for (var shape in video.sprites) {
      if (shape.frames.isEmpty) continue;
      var frameData = shape.frames[frame];
      if (frameData.hasImage()) {
        var img = frameData.image;
        if (img != null) {
          canvas.drawImage(img, Offset.zero, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SVGAPainter oldDelegate) => true;
}
