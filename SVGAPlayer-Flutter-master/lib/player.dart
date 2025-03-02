import 'package:flutter/material.dart';
import 'package:svgaplayer_flutter/proto/svga.pb.dart';
import 'package:svgaplayer_flutter/parser.dart';
import 'dart:ui' as ui;

//SVGAImage widget to display SVGA animation using a CustomPainter
class SVGAImage extends StatelessWidget {
  final SVGAAnimationController controller;

  //Receives an SVGAAnimationController from the parent widget to prevent duplication
  const SVGAImage({Key? key, required this.controller}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (controller.videoItem == null) return const SizedBox.shrink(); // Return an empty widget if no animation

    return IgnorePointer(
      child: CustomPaint(
        painter: _SVGAPainter(controller),
        size: Size(controller.videoItem!.params.viewBoxWidth, controller.videoItem!.params.viewBoxHeight),
      ),
    );
  }
}

//Custom painter to render SVGA animations frame by frame
class _SVGAPainter extends CustomPainter {
  final SVGAAnimationController controller;

  _SVGAPainter(this.controller) : super(repaint: controller); // Repaints when animation updates

  @override
  void paint(Canvas canvas, Size size) {
    if (controller.videoItem == null) return;

    final MovieEntity video = controller.videoItem!;
    final int currentFrame = (controller.value * video.params.frames).toInt(); // Get the current frame index

    if (currentFrame >= video.sprites.length) return; // Exit if the frame index is out of bounds

    for (final sprite in video.sprites) {
      if (sprite.frames.isEmpty || sprite.frames.length <= currentFrame) continue;

      final frame = sprite.frames[currentFrame]; // Get the current sprite frame
      final imageKey = sprite.imageKey; // Get the sprite image key
      final bitmap = video.dynamicItem.dynamicImages[imageKey] ?? video.bitmapCache[imageKey]; // Retrieve image from cache
      if (bitmap == null) continue;

      final paint = Paint();

      // Draw the frame image onto the canvas
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
    return oldDelegate.controller.value != controller.value; // Redraw only if animation updates
  }
}

//Controller for handling SVGA animation playback
class SVGAAnimationController extends AnimationController {
  MovieEntity? _videoItem;
  bool _isDisposed = false;

  SVGAAnimationController({required TickerProvider vsync}) : super(vsync: vsync, duration: Duration.zero);

  //Set a new SVGA animation and update its duration based on frame rate**
  set videoItem(MovieEntity? value) {
    if (_isDisposed) return;
    if (isAnimating) stop(); // Stop previous animation if running
    _videoItem = value;

    if (value != null) {
      int fps = value.params.fps > 0 ? value.params.fps : 20;
      duration = Duration(milliseconds: (value.params.frames / fps * 1000).toInt());
    } else {
      duration = Duration.zero;
    }

    reset(); // Reset animation state
    notifyListeners(); // Notify listeners of the update
  }

  MovieEntity? get videoItem => _videoItem;

  //Clear animation data and notify listeners*
  void clear() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _videoItem = null;
    _isDisposed = true;
    super.dispose();
  }

  /// **Start the animation in a loop when it reaches the end**
  void startLooping() {
    addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        reset(); // Reset animation to the beginning
        forward(); // Restart animation
      }
    });

    forward(); // Start animation immediately
  }

  //Optional: Initialize audio settings if supported by the SVGA library**
  void initializeSound() {
    // Placeholder for enabling sound if SVGA library supports it
  }
}

//A StatefulWidget to display and control SVGA animation playback
class SVGAAnimationPage extends StatefulWidget {
  const SVGAAnimationPage({Key? key}) : super(key: key);

  @override
  _SVGAAnimationPageState createState() => _SVGAAnimationPageState();
}

//State class that manages the SVGA animation and its controller
class _SVGAAnimationPageState extends State<SVGAAnimationPage> with TickerProviderStateMixin {
  late SVGAAnimationController controller;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller and pass vsync to avoid performance issues
    controller = SVGAAnimationController(vsync: this);

    // Start the animation loop and initialize sound if applicable
    controller.startLooping();
    controller.initializeSound();
  }

  @override
  void dispose() {
    // Properly dispose of the controller to prevent memory leaks
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        // Pass the controller to SVGAImage to render the animation
        child: SVGAImage(controller: controller),
      ),
    );
  }
}
