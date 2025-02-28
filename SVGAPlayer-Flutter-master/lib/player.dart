import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:svgaplayer_flutter/proto/svga.pb.dart';
import 'package:svgaplayer_flutter/parser.dart';
import 'package:svgaplayer_flutter/svgaplayer_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import 'audio_handler.dart';

class SVGAImage extends StatefulWidget {
  final String assetName;

  const SVGAImage(this.assetName, {Key? key}) : super(key: key);

  @override
  _SVGAImageState createState() => _SVGAImageState();
}

class SVGAAnimationController extends AnimationController {
  MovieEntity? _videoItem;
  bool _isDisposed = false;

  SVGAAnimationController({required TickerProvider vsync}) : super(vsync: vsync, duration: Duration.zero);

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

  void clear() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _videoItem = null;
    _isDisposed = true;
    super.dispose();
  }
}

class _SVGAImageState extends State<SVGAImage> with SingleTickerProviderStateMixin {
  late SVGAAnimationController _animationController;
  final SVGAParser _parser = SVGAParser();
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _animationController = SVGAAnimationController(vsync: this);
    _loadAnimation();
    _playAudio();
  }

  void _loadAnimation() async {
    try {
      final videoItem = await _parser.decodeFromAssets(widget.assetName);
      if (mounted) {
        setState(() {
          _animationController.videoItem = videoItem;
        });
        _animationController.repeat();
      }
    } catch (e) {
      print("Error loading SVGA: $e");
    }
  }

  void _playAudio() async {
    try {
      await _audioPlayer.setSource(AssetSource('audio/sound.mp3'));
      _audioPlayer.resume();
    } catch (e) {
      print("Error playing audio: $e");
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 200,
        height: 200,
        child: _animationController.videoItem != null
            ? SVGASimpleImage(controller: _animationController)
            : CircularProgressIndicator(),
      ),
    );
  }
}
