import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:svgaplayer_flutter/proto/svga.pb.dart';
import 'package:svgaplayer_flutter/parser.dart';
import 'package:svgaplayer_flutter/svgaplayer_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import 'audio_handler.dart';

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

class SVGADisplayScreen extends StatefulWidget {
  final String svgaUrl;
  const SVGADisplayScreen({super.key, required this.svgaUrl});

  @override
  _SVGADisplayScreenState createState() => _SVGADisplayScreenState();
}

class _SVGADisplayScreenState extends State<SVGADisplayScreen> with SingleTickerProviderStateMixin {
  late SVGAAnimationController _animationController;
  bool isLoading = true;
  bool hasAudio = false;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _animationController = SVGAAnimationController(vsync: this);
    loadAnimation();
  }

  Future<void> loadAnimation() async {
    try {
      final videoItem = await SVGAParser().decodeFromAssets(widget.svgaUrl);
      if (mounted) {
        setState(() {
          _animationController.videoItem = videoItem;
          hasAudio = videoItem.audios.isNotEmpty;
          isLoading = false;
        });
        _animationController.forward(from: 0.0);
      }
    } catch (e) {
      print("Error loading SVGA: $e");
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("SVGA Animation")),
      body: Center(
        child: isLoading
            ? const CircularProgressIndicator()
            : SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: _animationController.videoItem != null
              ? SVGASimpleImage(controller: _animationController)
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}
