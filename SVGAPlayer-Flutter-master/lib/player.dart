import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:svgaplayer_flutter/proto/svga.pb.dart';
import 'package:svgaplayer_flutter/parser.dart';
import 'package:svgaplayer_flutter/player.dart';

class SVGAImage extends StatefulWidget {
  final SVGAAnimationController controller;

  const SVGAImage(this.controller, {Key? key}) : super(key: key);

  @override
  _SVGAImageState createState() => _SVGAImageState();
}

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
      reset();
      forward();
    } else {
      duration = Duration.zero;
    }

    notifyListeners();
  }

  MovieEntity? get videoItem => _videoItem;

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

    final frameIndex = (controller.value * (controller.videoItem!.params.frames - 1)).toInt();
    final frame = controller.videoItem!.sprites;

    for (var sprite in frame) {
      if (frameIndex < sprite.frames.length) {
        final drawFrame = sprite.frames[frameIndex];

        // ✅ التأكد من وجود الصورة من خلال imageKey
        if (drawFrame.hasImageKey()) {  
          final key = drawFrame.imageKey;
          if (controller.videoItem!.images.containsKey(key)) {
            _decodeAndDrawImage(canvas, controller.videoItem!.images[key]!);
          }
        }
      }
    }
  }

  void _decodeAndDrawImage(Canvas canvas, Uint8List bitmap) async {
    final codec = await ui.instantiateImageCodec(bitmap);
    final frame = await codec.getNextFrame();
    canvas.drawImage(frame.image, Offset.zero, Paint());
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

