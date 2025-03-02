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
    notifyListeners();
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

  // ✅ تشغيل الأنيميشن تلقائياً عند الانتهاء
  void startLooping() {
    addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        reset(); // إعادة تعيين الأنيميشن
        forward(); // تشغيله مرة أخرى
      }
    });
    forward(); // تشغيل الأنيميشن مباشرة عند الاستدعاء
  }

  // تشغيل الصوت (لو متاح في المكتبة)
  void initializeSound() {
    // خاصية افتراضية لتفعيل الصوت حسب دعم مكتبة SVGA
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
    // إنشاء الكونترولر وتمريره لـ SVGAImage
    controller = SVGAAnimationController(vsync: this);

    // تشغيل الأنيميشن بشكل متكرر
    controller.startLooping();
    controller.initializeSound(); // تشغيل الصوت إذا كان مدعومًا
  }

  @override
  void dispose() {
    // تنظيف الكونترولر لتجنب تسرب الذاكرة
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        // تمرير الكونترولر إلى SVGAImage لإعادة استخدامه
        child: SVGAImage(controller: controller),
      ),
    );
  }
}
