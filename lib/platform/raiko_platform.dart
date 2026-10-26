import 'track_metadata.dart';
import 'raiko_platform_stub.dart'
    if (dart.library.io) 'raiko_platform_io.dart' as implementation;

export 'track_metadata.dart';

Future<bool> localFileExists(String path) => implementation.localFileExists(path);
Future<int> localFileSize(String path) => implementation.localFileSize(path);
String localBasename(String path) => implementation.localBasename(path);
Future<List<LocalAudioFile>> listLocalAudioFiles(String path, List<String> extensions) =>
    implementation.listLocalAudioFiles(path, extensions);
bool get localPlatformIsIOS => implementation.localPlatformIsIOS;
Future<TrackMetadata?> readLocalMetadata(String path) => implementation.readLocalMetadata(path);
