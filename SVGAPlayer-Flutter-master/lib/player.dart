import 'package:flutter/material.dart';
import 'package:svgaplayer_flutter/proto/svga.pb.dart';
import 'package:svgaplayer_flutter/parser.dart';
import 'package:svgaplayer_flutter/player.dart';
import 'package:audioplayers/audioplayers.dart';

class SVGAImage extends StatefulWidget {
  final String assetName;
  const SVGAImage(this.assetName, {Key? key}) : super(key: key);

  @override
  _SVGAImageState createState() => _SVGAImageState();
}

class _SVGAImageState extends State<SVGAImage> with SingleTickerProviderStateMixin {
  late SVGAAnimationController _animationController;
  final SVGAParser _parser = SVGAParser();
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _animationController = SVGAAnimationController(vsync: this);
    _loadAnimation();
    _playAudio();
  }

  Future<void> _loadAnimation() async {
    try {
      final videoItem = await _parser.decodeFromAssets(widget.assetName);
      if (!mounted) return;
      setState(() {
        _animationController.videoItem = videoItem;
      });
      _animationController.forward(from: 0.0);
    } catch (e) {
      print("❌ Error loading SVGA: $e");
    }
  }

  Future<void> _playAudio() async {
    try {
      await _audioPlayer.setSource(AssetSource('audio/sound.mp3'));
      await _audioPlayer.resume();
    } catch (e) {
      print("❌ Error playing audio: $e");
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 200,
        height: 200,
        child: _animationController.videoItem != null
            ? SVGASimpleImage(controller: _animationController)
            : const CircularProgressIndicator(),
      ),
    );
  }
}
