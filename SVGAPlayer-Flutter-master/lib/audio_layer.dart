// import 'dart:developer';

// import 'package:path_provider/path_provider.dart';
// import 'package:audioplayers/audioplayers.dart';
// import 'proto/svga.pb.dart';
// import 'dart:io';

// class SVGAAudioLayer {
//   final AudioPlayer _player = AudioPlayer();
//   late final AudioEntity audioItem;
//   late final MovieEntity _videoItem;
//   bool _isReady = false;
//   SVGAAudioLayer(this.audioItem, this._videoItem);
//   Future<void> playAudio() async {
//     final audioData = _videoItem.audiosData[audioItem.audioKey];
//     if (audioData != null) {
//       final cacheDir = await getApplicationCacheDirectory();
//       final cacheFile = File('${cacheDir.path}/temp_${audioItem.audioKey}.mp3');
//       if (!cacheFile.existsSync()) {
//         await cacheFile.writeAsBytes(audioData);
//       }
//       try {
//         if (!_isReady) {
//           _isReady = true;
//           await _player.play(DeviceFileSource(cacheFile.path));
//           _isReady = false;
//         }
//       } catch (e) {
//         log('Failed to play audio: $e');
//       }
//     }
//   }

//   pauseAudio() {
//     _player.pause();
//   }

//   resumeAudio() {
//     _player.resume();
//   }

//   stopAudio() {
//     if (isPlaying() || isPaused()) _player.stop();
//   }

//   isPlaying() {
//     return _player.state == PlayerState.playing;
//   }

//   isPaused() {
//     return _player.state == PlayerState.paused;
//   }

//   Future<void> dispose() {
//     if (isPlaying()) stopAudio();
//     return _player.dispose();
//   }
// }
