// svga_player.dart

import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart' show decodeImageFromList;
import 'package:audioplayers/audioplayers.dart';
import 'package:svgaplayer_flutter/proto/svga.pb.dart';
import 'package:svgaplayer_flutter/parser.dart';

class SVGAAnimationController extends AnimationController {
  MovieEntity? _videoItem;
  bool _isDisposed = false;
  VoidCallback? onUpdate;

  SVGAAnimationController({required TickerProvider vsync})
      : super(vsync: vsync, duration: Duration.zero) {
    addListener(() {
      if (!_isDisposed && onUpdate != null) {
        onUpdate!();
      }
    });
  }

  set videoItem(MovieEntity? value) {
    if (_isDisposed) return;
    if (isAnimating) stop();
    _videoItem = value;
    if (value != null) {
      int fps = value.params.fps > 0 ? value.params.fps : 20;
      duration = Duration(milliseconds: (value.params.frames / fps * 1000).toInt());
    } else {
      duration = Duration.zero;
    }
    reset();
  }

  MovieEntity? get videoItem => _videoItem;

  @override
  void dispose() {
    _videoItem = null;
    _isDisposed = true;
    super.dispose();
  }
}

class SVGAImage extends StatefulWidget {
  final SVGAAnimationController controller;
  const SVGAImage(this.controller, {Key? key}) : super(key: key);

  @override
  _SVGAImageState createState() => _SVGAImageState();
}

class _SVGAImageState extends State<SVGAImage> {
  MovieEntity? video;
  AudioPlayer? _audioPlayer;
  bool _isAudioPlaying = false;

  @override
  void initState() {
    super.initState();
    video = widget.controller.videoItem;
    widget.controller.onUpdate = _handleChange;
    widget.controller.addListener(_handleChange);
    widget.controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.controller.repeat();
      }
    });
  }

  void _handleChange() {
    if (mounted) {
      setState(() {
        video = widget.controller.videoItem;
      });
    }
    if (video?.audiosData.isNotEmpty == true && !_isAudioPlaying) {
      _audioPlayer = AudioPlayer();
      final audioKey = video!.audiosData.keys.first;
      final audioData = video!.audiosData[audioKey];
      if (audioData != null) {
        _audioPlayer!.play(BytesSource(audioData));
        _isAudioPlaying = true;
      }
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleChange);
    _audioPlayer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (video == null) return const SizedBox.shrink();

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: widget.controller,
        builder: (_, __) {
          return CustomPaint(
            painter: _SVGAPainter(video!, widget.controller.value),
            size: Size(video!.params.viewBoxWidth, video!.params.viewBoxHeight),
          );
        },
      ),
    );
  }
}

class _SVGAPainter extends CustomPainter {
  final MovieEntity video;
  final double progress;
  _SVGAPainter(this.video, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    // رسم الإطارات هنا
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
