import 'package:flutter/material.dart';
import 'package:svgaplayer_flutter/proto/svga.pb.dart';
import 'package:svgaplayer_flutter/parser.dart';
import 'package:svgaplayer_flutter/svgaplayer.dart';
import 'dart:ui' as ui;

class SVGAImage extends StatefulWidget {
  final SVGAAnimationController controller;

  const SVGAImage(this.controller, {Key? key}) : super(key: key);

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
    notifyListeners(); // 🔥 تأكد من تحديث الرسوم عند تغيير الفيديو
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

class _SVGAImageState extends State<SVGAImage> {
  MovieEntity? video;

  @override
  void initState() {
    super.initState();
    video = widget.controller.videoItem;
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

  _SVGAPainter(this.controller) : super(repaint: controller);

  @override
  void paint(Canvas canvas, Size size) {
    if (controller.videoItem == null) return;
    final MovieEntity video = controller.videoItem!;
    final int currentFrame = (controller.value * video.params.frames).toInt();
    
    if (currentFrame >= video.sprites.length) return;
    
    for (final sprite in video.sprites) {
      if (sprite.frames.isEmpty || sprite.frames.length <= currentFrame) continue;
      final frame = sprite.frames[currentFrame];
      if (frame.image == null) continue;
      final paint = Paint();
      
      canvas.drawImageRect(
        frame.image! as ui.Image,
        Rect.fromLTWH(0, 0, frame.image!.width.toDouble(), frame.image!.height.toDouble()),
        Rect.fromLTWH(
          sprite.layout.x,
          sprite.layout.y,
          sprite.layout.width,
          sprite.layout.height,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SVGAPainter oldDelegate) {
    return oldDelegate.controller.value != controller.value;
  }
}
