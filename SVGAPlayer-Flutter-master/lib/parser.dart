import 'dart:developer';
import 'dart:ui' as ui;
import 'dart:typed_data' show Uint8List;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show decodeImageFromList;
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' show get;
import 'package:archive/archive.dart' as archive;
// ignore: import_of_legacy_library_into_null_safe
import 'proto/svga.pbserver.dart';

const _filterKey = 'SVGAParser';

/// You use SVGAParser to load and decode animation files.
class SVGAParser {
  const SVGAParser();
  static const shared = SVGAParser();

  /// Download animation file from remote server, and decode it.
  Future<MovieEntity> decodeFromURL(String url) async {
    final response = await get(Uri.parse(url));
    return decodeFromBuffer(response.bodyBytes);
  }

  /// Download animation file from bundle assets, and decode it.
  Future<MovieEntity> decodeFromAssets(String path) async {
    return decodeFromBuffer((await rootBundle.load(path)).buffer.asUint8List());
  }

  /// Download animation file from buffer, and decode it.
  Future<MovieEntity> decodeFromBuffer(List<int> bytes) {
    TimelineTask? timeline;
    if (!kReleaseMode) {
      timeline = TimelineTask(filterKey: _filterKey)
        ..start('DecodeFromBuffer', arguments: {'length': bytes.length});
    }
    final inflatedBytes = const archive.ZLibDecoder().decodeBytes(bytes);
    if (timeline != null) {
      timeline.instant('MovieEntity.fromBuffer()',
          arguments: {'inflatedLength': inflatedBytes.length});
    }
    final movie = MovieEntity.fromBuffer(inflatedBytes);
    if (timeline != null) {
      timeline.instant('prepareResources()',
          arguments: {'images': movie.images.keys.join(',')});
    }
    return _prepareResources(
      _processShapeItems(movie),
      timeline: timeline,
    ).whenComplete(() {
      if (timeline != null) timeline.finish();
    });
  }

  MovieEntity _processShapeItems(MovieEntity movieItem) {
    for (var sprite in movieItem.sprites) {
      List<ShapeEntity>? lastShape;
      for (var frame in sprite.frames) {
        if (frame.shapes.isNotEmpty && frame.shapes.isNotEmpty) {
          if (frame.shapes[0].type == ShapeEntity_ShapeType.KEEP &&
              lastShape != null) {
            frame.shapes = lastShape;
          } else if (frame.shapes.isNotEmpty == true) {
            lastShape = frame.shapes;
          }
        }
      }
    }
    return movieItem;
  }

  Future<MovieEntity> _prepareResources(MovieEntity movieItem,
      {TimelineTask? timeline}) {
    final images = movieItem.images;
    if (images.isEmpty) return Future.value(movieItem);
    return Future.wait(images.entries.map((item) async {
      // result null means a decoding error occurred
      Uint8List data = Uint8List.fromList(item.value);
      if (getSound(data)) {
        movieItem.audiosData[item.key] = data;
      } else {
        final decodeImage =
            await _decodeImageItem(item.key, data, timeline: timeline);
        if (decodeImage != null) {
          movieItem.bitmapCache[item.key] = decodeImage;
        }
      }
    })).then((_) => movieItem);
  }

Future<ui.Image?> _decodeImageItem(String key, Uint8List bytes,
    {TimelineTask? timeline}) async {
  if (bytes.isEmpty || bytes.length < 10) {
    log('Image data is empty or too small: $key');
    return null;
  }

  if (getSound(bytes)) {
    log('Skipping image decoding for audio file: $key');
    return null;
  }

  TimelineTask? task;
  if (!kReleaseMode) {
    task = TimelineTask(filterKey: _filterKey, parent: timeline)
      ..start('DecodeImage', arguments: {'key': key, 'length': bytes.length});
  }

  try {
    final image = await decodeImageFromList(bytes);
    task?.finish(arguments: {'imageSize': '${image.width}x${image.height}'});
    return image;
  } catch (e, stack) {
    task?.finish(arguments: {'error': '$e', 'stack': '$stack'});
    log('Failed to decode image: $key, error: $e');

    assert(() {
      FlutterError.reportError(FlutterErrorDetails(
        exception: e,
        stack: stack,
        library: 'svgaplayer',
        context: ErrorDescription('during prepare resource'),
        informationCollector: () sync* {
          yield ErrorSummary('Decoding image failed for key: $key.');
        },
      ));
      return true;
    }());

    return null;
  }
}

bool getSound(Uint8List data) {
  try {
    print("Checking for sound...");

    const String mp3MagicNumber = 'ID3';
    if (data.length < mp3MagicNumber.length) {
      return false; // البيانات غير كافية للتحقق
    }

    String header = String.fromCharCodes(data.take(mp3MagicNumber.length));
    bool hasSound = header.startsWith(mp3MagicNumber);

    print("Sound detected: $hasSound");
    return hasSound;
  } catch (e) {
    print("Error checking sound: $e");
    return false; // في حالة حدوث خطأ، نعتبر أنه لا يوجد صوت
  }
}

}

