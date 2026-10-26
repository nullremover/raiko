import 'track_metadata.dart';

Future<bool> localFileExists(String path) async => false;
Future<int> localFileSize(String path) async => 0;
String localBasename(String path) => path.split('/').last;
Future<List<LocalAudioFile>> listLocalAudioFiles(String path, List<String> extensions) async => const [];
bool get localPlatformIsIOS => false;
Future<TrackMetadata?> readLocalMetadata(String path) async => null;
