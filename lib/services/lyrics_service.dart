import 'dart:convert';

import 'package:http/http.dart' as http;

class LyricLine {
  const LyricLine(this.time, this.text);
  final Duration time;
  final String text;
}

class LyricsResult {
  const LyricsResult({required this.plainLyrics, required this.syncedLyrics});
  final String? plainLyrics;
  final List<LyricLine> syncedLyrics;
  bool get hasSyncedLyrics => syncedLyrics.isNotEmpty;
  bool get hasAnyLyrics => (plainLyrics?.trim().isNotEmpty ?? false) || hasSyncedLyrics;
}

/// LRCLIB lookup, kept independent from the player UI for easier testing.
class LyricsService {
  LyricsService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<LyricsResult> lookup({required String title, required String artist}) async {
    final uri = Uri.https('lrclib.net', '/api/get', {
      'track_name': title,
      'artist_name': artist,
    });
    final response = await _client.get(uri, headers: const {'User-Agent': 'Raiko/0.1 (music player)'}).timeout(const Duration(seconds: 12));
    if (response.statusCode == 404) {
      return const LyricsResult(plainLyrics: null, syncedLyrics: []);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('LRCLIB returned HTTP ${response.statusCode}.');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      return const LyricsResult(plainLyrics: null, syncedLyrics: []);
    }
    final rawSynced = decoded['syncedLyrics'];
    final lines = rawSynced is String ? parseLrc(rawSynced) : <LyricLine>[];
    final plain = decoded['plainLyrics'];
    return LyricsResult(
      plainLyrics: plain is String && plain.trim().isNotEmpty ? plain : null,
      syncedLyrics: lines,
    );
  }

  static List<LyricLine> parseLrc(String input) {
    final lines = <LyricLine>[];
    final timestamp = RegExp(r'\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\]');
    for (final row in input.split(RegExp(r'\r?\n'))) {
      final matches = timestamp.allMatches(row).toList();
      if (matches.isEmpty) continue;
      final lyricText = row.substring(matches.last.end).trim();
      for (final match in matches) {
        final minutes = int.tryParse(match.group(1) ?? '') ?? 0;
        final seconds = int.tryParse(match.group(2) ?? '') ?? 0;
        final fraction = match.group(3) ?? '0';
        final millis = int.parse((fraction.length == 1 ? '${fraction}00' : fraction.length == 2 ? '${fraction}0' : fraction).substring(0, 3));
        lines.add(LyricLine(Duration(minutes: minutes, seconds: seconds, milliseconds: millis), lyricText));
      }
    }
    lines.sort((a, b) => a.time.compareTo(b.time));
    return lines;
  }

  void dispose() => _client.close();
}
