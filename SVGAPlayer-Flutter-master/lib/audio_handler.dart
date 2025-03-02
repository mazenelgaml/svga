import 'dart:io'; // Import for file handling
import 'package:audioplayers/audioplayers.dart'; // Import for audio playback
import 'package:path_provider/path_provider.dart'; // Import for getting storage directories
import 'package:svgaplayer_flutter/proto/svga.pb.dart'; // Import SVGA file definitions

/// **AudioHandler class to manage audio playback from SVGA files**
class AudioHandler {
  final AudioPlayer _player = AudioPlayer(); // Audio player instance
  bool _isMuted = false; // Flag to track mute state
  bool _isPlaying = false; // Flag to track if audio is playing
  File? _audioFile; // Temporary file for storing audio data

  /// **Play audio extracted from an SVGA file**
  Future<void> playAudioFromSVGA(MovieEntity videoItem) async {
    if (videoItem.audios.isEmpty) return; // If no audio in SVGA, exit function

    // Retrieve the audio data from the SVGA file
    final audioData = videoItem.audiosData[videoItem.audios.first.audioKey];
    if (audioData == null) {
      print('❌ No audio data found.'); // Print an error if no audio data exists
      return;
    }

    // Get temporary storage directory
    final cacheDir = await getTemporaryDirectory();
    _audioFile = File('${cacheDir.path}/temp_audio.mp3'); // Create a temporary audio file

    // If the file doesn't already exist, write audio data to it
    if (!_audioFile!.existsSync()) {
      await _audioFile!.writeAsBytes(audioData);
    }

    // Play the audio file using the audio player
    await _player.play(DeviceFileSource(_audioFile!.path));
    _isPlaying = true; // Update playing state to "playing"
  }

  /// **Mute or unmute the audio**
  void muteAudio(bool mute) {
    _isMuted = mute; // Update mute state
    _player.setVolume(mute ? 0 : 1); // Set volume to 0 if muted, 1 if unmuted
  }

  /// **Pause the audio playback**
  void pauseAudio() {
    if (_isPlaying) {
      _player.pause(); // Pause audio playback
      _isPlaying = false; // Update playing state
    }
  }

  /// **Resume the audio playback**
  void resumeAudio() {
    if (!_isPlaying) {
      _player.resume(); // Resume audio playback
      _isPlaying = true; // Update playing state
    }
  }

  /// **Clean up resources when finished**
  void dispose() {
    _player.dispose(); // Dispose of the audio player
    if (_audioFile != null && _audioFile!.existsSync()) {
      _audioFile!.delete(); // Delete the temporary audio file
    }
  }
}
