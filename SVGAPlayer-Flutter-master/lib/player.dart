import 'package:flutter/material.dart';
import 'package:svgaplayer_flutter/proto/svga.pb.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

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

class SVGAAnimationController extends AnimationController {
  MovieEntity? _videoItem;
  bool _isDisposed = false;
  final AudioPlayer _audioPlayer = AudioPlayer();
  File? _audioFile;

  SVGAAnimationController({required TickerProvider vsync}) : super(vsync: vsync, duration: Duration.zero);

  set videoItem(MovieEntity? value) async {
    if (_isDisposed) return;
    if (isAnimating) stop();
    _videoItem = value;
    if (value != null) {
      int fps = value.params.fps > 0 ? value.params.fps : 20;
      duration = Duration(milliseconds: (value.params.frames / fps * 1000).toInt());
      print("🎬 SVGA Loaded: ${value.params.frames} frames at $fps FPS");
      await _prepareAudio(value);
    } else {
      duration = Duration.zero;
    }
    reset();
    notifyListeners();
    startLooping();
  }

  MovieEntity? get videoItem => _videoItem;

  Future<void> _prepareAudio(MovieEntity videoItem) async {
    try {
      if (videoItem.audios.isEmpty) return;
      final audioData = videoItem.audiosData[videoItem.audios.first.audioKey];
      if (audioData == null) return;
      final cacheDir = await getTemporaryDirectory();
      _audioFile = File('${cacheDir.path}/temp_audio.mp3');
      if (!_audioFile!.existsSync()) {
        await _audioFile!.writeAsBytes(audioData);
      }
    } catch (e) {
      print("❌ Error preparing audio: $e");
    }
  }

  void startLooping() {
    addStatusListener((status) async {
      if (status == AnimationStatus.completed) {
        reset();
        forward();
      }
    });

    _audioPlayer.onPlayerComplete.listen((event) {
      _playAudio(); // إعادة تشغيل الصوت عند الانتهاء
    });

    forward(); // بدء تشغيل الأنيميشن
    _playAudio(); // بدء تشغيل الصوت متزامنًا مع الأنيميشن
  }

  Future<void> _playAudio() async {
    try {
      if (_audioFile != null && _audioFile!.existsSync()) {
        await _audioPlayer.stop(); // إيقاف الصوت قبل إعادة تشغيله
        await _audioPlayer.seek(Duration.zero);
        await _audioPlayer.play(DeviceFileSource(_audioFile!.path));
      }
    } catch (e) {
      print("❌ Error playing audio: $e");
    }
  }

  void clear() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _videoItem = null;
    _isDisposed = true;
    _audioPlayer.dispose();
    if (_audioFile != null && _audioFile!.existsSync()) {
      _audioFile!.delete();
    }
    super.dispose();
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
    controller = SVGAAnimationController(vsync: this);
  }

  @override
  void dispose() {
    controller.dispose();
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
