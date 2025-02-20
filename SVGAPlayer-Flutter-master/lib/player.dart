library svgaplayer_flutter_player;
import 'package:svgaplayer_flutter/audio_layer.dart';
import 'dart:math';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:svgaplayer_flutter/proto/svga.pb.dart';
import 'proto/svga.pbserver.dart';
import 'dart:typed_data';
import 'package:path_drawing/path_drawing.dart';
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
  final List<SVGAAudioLayer> _audioLayers = [];
  bool _canvasNeedsClear = false;

  SVGAAnimationController({required super.vsync}) : super(duration: Duration.zero);

  set videoItem(MovieEntity? value) {
    if (isAnimating) {
      stop();
    }
    if (value == null) {
      clear();
    }
    _videoItem = value;
    if (value != null) {
      final movieParams = value.params;
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
    notifyListeners();
  }

  @override
  TickerFuture forward({double? from}) {
    return super.forward(from: from);
  }

  @override
  void stop({bool canceled = true}) {
    for (final audio in _audioLayers) {
      audio.pauseAudio();
    }
    super.stop(canceled: canceled);
  }

  @override
  void dispose() {
    for (final audio in _audioLayers) {
      audio.dispose();
    }
    videoItem = null;
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

  handleAudio() {
    final audioLayers = widget._controller._audioLayers;
    for (final audio in audioLayers) {
      if (!audio.isPlaying() &&
          audio.audioItem.startFrame <= widget._controller.currentFrame &&
          audio.audioItem.endFrame >= widget._controller.currentFrame) {
        audio.playAudio();
      }
      if (audio.isPlaying() &&
          audio.audioItem.endFrame <= widget._controller.currentFrame) {
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
