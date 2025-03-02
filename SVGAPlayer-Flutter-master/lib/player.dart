import 'package:flutter/material.dart';
import 'package:svgaplayer_flutter/proto/svga.pb.dart';
import 'package:svgaplayer_flutter/parser.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:ui' as ui;
import 'audio_handler.dart';

class SVGAImage extends StatelessWidget {
  final SVGAAnimationController controller;

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
  final AudioHandler audioHandler; // ✅ تمرير معالج الصوت

  SVGAAnimationController({required TickerProvider vsync, required this.audioHandler}) 
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
    audioHandler.dispose(); // ✅ تنظيف الصوت عند التخلص من الكائن
    super.dispose();
  }

  // ✅ تشغيل SVGA وبعدها تشغيل الصوت، ثم إعادة SVGA بعد انتهاء الصوت
  void startLooping() {
    addStatusListener((status) async {
      if (status == AnimationStatus.completed) {
        audioHandler.playAudioFromSVGA(videoItem!); // تشغيل الصوت بعد انتهاء SVGA
      }
    });

    audioHandler.onAudioComplete = () { 
      forward(from: 0); // إعادة تشغيل SVGA بعد انتهاء الصوت
    };

    forward(); // تشغيل SVGA في البداية
  }
}

class SVGAAnimationPage extends StatefulWidget {
  const SVGAAnimationPage({Key? key}) : super(key: key);

  @override
  _SVGAAnimationPageState createState() => _SVGAAnimationPageState();
}

class _SVGAAnimationPageState extends State<SVGAAnimationPage> with TickerProviderStateMixin {
  late SVGAAnimationController controller;
  late AudioHandler audioHandler;

  @override
  void initState() {
    super.initState();
    audioHandler = AudioHandler(); 
    controller = SVGAAnimationController(vsync: this, audioHandler: audioHandler);
    controller.startLooping(); // ✅ تشغيل SVGA والصوت بالتناوب
  }

  @override
  void dispose() {
    controller.dispose();
    audioHandler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SVGAImage(controller: controller),
      ),
    );
  }
}
