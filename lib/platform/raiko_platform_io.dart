import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart' as reader;

import 'track_metadata.dart';

Future<bool> localFileExists(String path) => File(path).exists();
Future<int> localFileSize(String path) => File(path).length();
String localBasename(String path) => path.split(Platform.pathSeparator).last;
bool get localPlatformIsIOS => Platform.isIOS;

Future<List<LocalAudioFile>> listLocalAudioFiles(String path, List<String> extensions) async {
  final directory = Directory(path);
  final files = <LocalAudioFile>[];
  await for (final entity in directory.list(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final extension = entity.path.split('.').last.toLowerCase();
    if (!extensions.contains(extension)) continue;
    files.add(LocalAudioFile(
      path: entity.path,
      name: localBasename(entity.path),
      size: await entity.length(),
    ));
  }
  return files;
}

Future<TrackMetadata?> readLocalMetadata(String path) async {
  final metadata = reader.readMetadata(File(path), getImage: true);
  return TrackMetadata(
    title: metadata.title,
    artist: metadata.artist,
    album: metadata.album,
    duration: metadata.duration,
    pictures: metadata.pictures
        .map((picture) => TrackArtwork(picture.bytes, picture.mimetype))
        .toList(growable: false),
  );
}
