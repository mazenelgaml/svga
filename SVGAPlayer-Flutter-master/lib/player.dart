import 'package:flutter/material.dart';
import 'package:svgaplayer_flutter/proto/svga.pb.dart';
import 'package:svgaplayer_flutter/parser.dart';

class SVGAImage extends StatefulWidget {
  final SVGAAnimationController controller;

  const SVGAImage(this.controller, {Key? key}) : super(key: key);

  @override
  _SVGAImageState createState() => _SVGAImageState();
}

class _SVGAImageState extends State<SVGAImage> {
  MovieEntity? video;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleChange);
  }

  void _handleChange() {
    if (mounted) {
      setState(() {
        video = widget.controller.videoItem;
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.controller.videoItem == null) return const SizedBox.shrink();

    return IgnorePointer(
      child: CustomPaint(
        painter: _SVGAPainter(widget.controller),
        size: Size(
          widget.controller.videoItem!.params.viewBoxWidth,
          widget.controller.videoItem!.params.viewBoxHeight,
        ),
      ),
    );
  }
}

class _SVGAPainter extends CustomPainter {
  final SVGAAnimationController controller;

  _SVGAPainter(this.controller);

  @override
  void paint(Canvas canvas, Size size) {
    if (controller.videoItem == null) return;

    final videoItem = controller.videoItem!;
    final frames = videoItem.sprites;
    if (frames.isEmpty) return;

    final currentFrame = (controller.value * frames.length).toInt() % frames.length;
    final sprite = frames[currentFrame];

    if (sprite.image != null) {
      canvas.drawImage(sprite.image!, Offset.zero, Paint());
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class SVGAAnimationController extends AnimationController {
  MovieEntity? _videoItem;
  bool _isDisposed = false;

  SVGAAnimationController({required TickerProvider vsync})
      : super(vsync: vsync, duration: Duration.zero);

  Future<void> loadAnimation(String assetName) async {
    final parser = SVGAParser();
    final videoItem = await parser.decodeFromAssets(assetName);
    if (!_isDisposed && videoItem != null) {
      videoItem = videoItem;
      int fps = videoItem.params.fps > 0 ? videoItem.params.fps : 20;
      duration = Duration(milliseconds: (videoItem.params.frames / fps * 1000).toInt());
      reset();
      notifyListeners();
    }
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

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with SingleTickerProviderStateMixin {
  late SVGAAnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SVGAAnimationController(vsync: this);
    _controller.loadAnimation("assets/animation.svga");
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SVGAImage(_controller),
        ),
      ),
    );
  }
}
