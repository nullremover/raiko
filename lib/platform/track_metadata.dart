import 'dart:typed_data';

class TrackMetadata {
  const TrackMetadata({
    this.title,
    this.artist,
    this.album,
    this.duration,
    this.pictures = const [],
  });

  final String? title;
  final String? artist;
  final String? album;
  final Duration? duration;
  final List<TrackArtwork> pictures;
}

class TrackArtwork {
  const TrackArtwork(this.bytes, this.mimeType);
  final Uint8List bytes;
  final String mimeType;
}

class LocalAudioFile {
  const LocalAudioFile({required this.path, required this.name, required this.size});
  final String path;
  final String name;
  final int size;
}
