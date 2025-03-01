import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:svgaplayer_flutter/proto/svga.pb.dart';
import 'package:svgaplayer_flutter/parser.dart';
import 'package:svgaplayer_flutter/player.dart';

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
      forward(from: 0.0);
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
  final String assetPath;
  
  const SVGAImage({Key? key, required this.controller, required this.assetPath}) : super(key: key);

  @override
  _SVGAImageState createState() => _SVGAImageState();
}

class _SVGAImageState extends State<SVGAImage> {
  MovieEntity? video;
  SVGAParser parser = SVGAParser();
  AudioPlayer? _audioPlayer;
  bool _isAudioPlaying = false;

  @override
  void initState() {
    super.initState();
    _loadAnimation();
    widget.controller.onUpdate = _handleChange;
    widget.controller.addListener(_handleChange);
    widget.controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.controller.repeat();
      }
    });
  }

  Future<void> _loadAnimation() async {
    parser.decodeFromAssets(widget.assetPath, onSuccess: (movie) {
      if (mounted) {
        setState(() {
          video = movie;
          widget.controller.videoItem = movie;
        });
        _playAudio();
      }
    });
  }

  void _handleChange() {
    if (mounted) {
      setState(() {});
    }
  }

  void _playAudio() {
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
    if (video == null) return Center(child: CircularProgressIndicator());

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: widget.controller,
        builder: (_, __) {
          return SVGASimpleImage(video!);
        },
      ),
    );
  }
}
