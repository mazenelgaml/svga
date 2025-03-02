import 'package:flutter/material.dart';
import 'package:svgaplayer_flutter/proto/svga.pb.dart';
import 'package:svgaplayer_flutter/parser.dart';
import 'dart:ui' as ui;

class SVGAImage extends StatelessWidget {
  final SVGAAnimationController controller;

  // The controller is passed from the parent widget, preventing duplication.
  const SVGAImage({Key? key, required this.controller}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (controller.videoItem == null) return const SizedBox.shrink();

    return IgnorePointer(
      child: CustomPaint(
        painter: _SVGAPainter(controller),
        size: Size(controller.videoItem!.params.viewBoxWidth, controller.videoItem!.params.viewBoxHeight),
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
      final imageKey = sprite.imageKey;
      final bitmap = video.dynamicItem.dynamicImages[imageKey] ?? video.bitmapCache[imageKey];
      if (bitmap == null) continue;
      final paint = Paint();
      
      canvas.drawImageRect(
        bitmap,
        Rect.fromLTWH(0, 0, bitmap.width.toDouble(), bitmap.height.toDouble()),
        Rect.fromLTWH(
          frame.layout.x,
          frame.layout.y,
          frame.layout.width,
          frame.layout.height,
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
    notifyListeners(); // 🔥 Ensure the animation updates when the video changes
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

  // Add logic to restart the animation when it finishes and ensure it loops
  void startLooping() {
    addListener(() {
      if (value >= 1.0) {
        reset(); // Reset the animation to the beginning
        forward(); // Restart the animation
      }
    });
    forward(); // Start the animation immediately
  }

  // Optional: Ensure sound is played properly
  void initializeSound() {
    // Hypothetical property to enable sound (depends on SVGA library)
    // audioEnabled = true;
  }
}

class SVGAAnimationPage extends StatefulWidget {
  const SVGAAnimationPage({Key? key}) : super(key: key);

  @override
  _SVGAAnimationPageState createState() => _SVGAAnimationPageState();
}

class _SVGAAnimationPageState extends State<SVGAAnimationPage> with TickerProviderStateMixin {
  late SVGAAnimationController controller;

  @override
  void initState() {
    super.initState();
    // The controller is created here once. It's passed down to the SVGAImage widget.
    // The controller is not recreated, thus preventing duplication.
    controller = SVGAAnimationController(vsync: this);
    
    // Start the animation loop automatically once the controller is ready
    controller.startLooping();
    controller.initializeSound(); // Make sure sound is initialized if applicable
  }

  @override
  void dispose() {
    // Proper cleanup of the controller to avoid memory leaks
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        // The controller is passed down to SVGAImage, and it's reused, not duplicated
        child: SVGAImage(controller: controller), 
      ),
    );
  }
}
