import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:svgaplayer_flutter/parser.dart';
import 'package:svgaplayer_flutter/proto/svga.pb.dart';

class SVGAAnimationController extends AnimationController {
  MovieEntity? _videoItem;
  bool _isDisposed = false;

  SVGAAnimationController({required TickerProvider vsync}) 
      : super(vsync: vsync, duration: Duration.zero);

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

  void startAnimation() {
    if (_videoItem != null) {
      forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _videoItem = null;
    _isDisposed = true;
    super.dispose();
  }
}

class SVGAImage extends StatefulWidget {
  final SVGAAnimationController controller;
  final String assetName;

  const SVGAImage(this.controller, {Key? key, required this.assetName}) : super(key: key);

  @override
  _SVGAImageState createState() => _SVGAImageState();
}

class _SVGAImageState extends State<SVGAImage> {
  MovieEntity? video;

  @override
  void initState() {
    super.initState();
    loadAnimation();
    widget.controller.addListener(_handleChange);
  }

  Future<void> loadAnimation() async {
    final parser = SVGAParser(sharedContext);
    parser.decodeFromAssets(widget.assetName, (movie) {
      if (mounted) {
        setState(() {
          widget.controller.videoItem = movie;
          widget.controller.startAnimation();
        });
      }
    }, onError: (error) {
      debugPrint("Error loading SVGA: $error");
    });
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
    if (video == null) return const SizedBox.shrink();

    return IgnorePointer(
      child: CustomPaint(
        painter: _SVGAPainter(widget.controller),
        size: Size(video!.params.viewBoxWidth, video!.params.viewBoxHeight),
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
    final currentFrame = (controller.value * videoItem.params.frames).toInt();
    if (currentFrame >= videoItem.params.frames) return;
    final frame = videoItem.sprites[currentFrame];
    frame.draw(canvas, size);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
