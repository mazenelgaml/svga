import 'dart:developer';
import 'dart:ui' as ui;
import 'dart:typed_data' show Uint8List;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show decodeImageFromList;
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' show get;
import 'package:archive/archive.dart' as archive;
import 'proto/svga.pbserver.dart';

const _filterKey = 'SVGAParser';

class SVGAParser {
  const SVGAParser();
  static const shared = SVGAParser();

  Future<MovieEntity> decodeFromURL(String url) async {
    try {
      final response = await get(Uri.parse(url));
      if (response.statusCode == 200) {
        return decodeFromBuffer(response.bodyBytes);
      } else {
        throw Exception("Failed to load SVGA file from URL: $url");
      }
    } catch (e) {
      log("Error decoding SVGA from URL: $e");
      rethrow;
    }
  }

  Future<MovieEntity> decodeFromAssets(String path) async {
    try {
      final bytes = await rootBundle.load(path);
      return decodeFromBuffer(bytes.buffer.asUint8List());
    } catch (e) {
      log("Error decoding SVGA from assets: $e");
      rethrow;
    }
  }

  Future<MovieEntity> decodeFromBuffer(List<int> bytes) async {
    if (bytes.isEmpty) throw Exception("Invalid SVGA file: Buffer is empty");
    
    TimelineTask? timeline;
    if (!kReleaseMode) {
      timeline = TimelineTask(filterKey: _filterKey)..start('DecodeFromBuffer', arguments: {'length': bytes.length});
    }

    try {
      final inflatedBytes = archive.ZLibDecoder().decodeBytes(bytes);
      final movie = MovieEntity.fromBuffer(inflatedBytes);
      return await _prepareResources(_processShapeItems(movie), timeline: timeline);
    } catch (e) {
      log("Error processing SVGA file: $e");
      rethrow;
    } finally {
      timeline?.finish();
    }
  }

  MovieEntity _processShapeItems(MovieEntity movieItem) {
    for (var sprite in movieItem.sprites) {
      List<ShapeEntity>? lastShape;
      for (var frame in sprite.frames) {
        if (frame.shapes.isNotEmpty) {
          if (frame.shapes.first.type == ShapeEntity_ShapeType.KEEP && lastShape != null) {
            frame.shapes = lastShape;
          } else {
            lastShape = frame.shapes;
          }
        }
      }
    }
    return movieItem;
  }

  Future<MovieEntity> _prepareResources(MovieEntity movieItem, {TimelineTask? timeline}) async {
    if (movieItem.images.isEmpty) return movieItem;

    await Future.wait(movieItem.images.entries.map((entry) async {
      final decodedImage = await _decodeImageItem(entry.key, Uint8List.fromList(entry.value), timeline: timeline);
      if (decodedImage != null) {
        movieItem.bitmapCache[entry.key] = decodedImage;
      }
    }));
    return movieItem;
  }

  Future<ui.Image?> _decodeImageItem(String key, Uint8List bytes, {TimelineTask? timeline}) async {
    if (bytes.isEmpty) {
      log("Error: Image data is empty for key: $key");
      return null;
    }

    TimelineTask? task;
    if (!kReleaseMode) {
      task = TimelineTask(filterKey: _filterKey, parent: timeline)..start('DecodeImage', arguments: {'key': key, 'length': bytes.length});
    }

    try {
      final image = await decodeImageFromList(bytes);
      task?.finish(arguments: {'imageSize': '${image.width}x${image.height}'});
      return image;
    } catch (e, stack) {
      task?.finish(arguments: {'error': '$e', 'stack': '$stack'});
      log("Error decoding image: $e");
      return null;
    }
  }

  bool isMP3Data(Uint8List data) {
    const mp3MagicNumber = 'ID3';
    return String.fromCharCodes(data.take(mp3MagicNumber.length)) == mp3MagicNumber;
  }
}
