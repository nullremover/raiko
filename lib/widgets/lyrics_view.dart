import 'package:flutter/material.dart';

import '../services/lyrics_service.dart';
import '../theme/raiko_colors.dart';

class LyricsView extends StatefulWidget {
  const LyricsView({super.key, required this.title, required this.artist, required this.positionStream});
  final String title;
  final String artist;
  final Stream<Duration> positionStream;

  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView> {
  final LyricsService _service = LyricsService();
  Future<LyricsResult>? _request;

  @override
  void initState() {
    super.initState();
    _startLookup();
  }

  @override
  void didUpdateWidget(covariant LyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title || oldWidget.artist != widget.artist) _startLookup();
  }

  void _startLookup() {
    _request = widget.title.isEmpty || widget.artist.isEmpty || widget.artist == 'Local file'
        ? Future.value(const LyricsResult(plainLyrics: null, syncedLyrics: []))
        : _service.lookup(title: widget.title, artist: widget.artist);
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('LYRICS', style: TextStyle(color: RaikoColors.starlight, letterSpacing: 2, fontSize: 11)),
      const SizedBox(height: 8),
      Text(widget.title.isEmpty ? 'Nothing playing' : widget.title, style: const TextStyle(fontFamily: 'DelaGothicOne', fontSize: 25)),
      Text(widget.artist, style: const TextStyle(color: RaikoColors.muted)),
      const SizedBox(height: 24),
      FutureBuilder<LyricsResult>(
        future: _request,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasError) {
            return _message('Lyrics could not be loaded. Check your connection and try again.', action: TextButton.icon(onPressed: () => setState(_startLookup), icon: const Icon(Icons.refresh_rounded), label: const Text('Retry')));
          }
          final result = snapshot.data;
          if (result == null || !result.hasAnyLyrics) return _message('No lyrics found for this track.');
          if (!result.hasSyncedLyrics) {
            return SelectableText(result.plainLyrics ?? '', style: const TextStyle(fontSize: 18, height: 1.8, color: RaikoColors.text));
          }
          return StreamBuilder<Duration>(
            stream: widget.positionStream,
            initialData: Duration.zero,
            builder: (context, positionSnapshot) {
              final position = positionSnapshot.data ?? Duration.zero;
              var active = -1;
              for (var i = 0; i < result.syncedLyrics.length; i++) {
                if (result.syncedLyrics[i].time <= position) active = i;
                else break;
              }
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (var i = 0; i < result.syncedLyrics.length; i++)
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 180),
                    style: TextStyle(fontSize: i == active ? 23 : 18, height: 1.55, fontWeight: i == active ? FontWeight.w700 : FontWeight.w400, color: i == active ? RaikoColors.text : RaikoColors.muted.withValues(alpha: 0.72)),
                    child: Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Text(result.syncedLyrics[i].text.isEmpty ? '♪' : result.syncedLyrics[i].text)),
                  ),
              ]);
            },
          );
        },
      ),
    ]);
  }

  Widget _message(String message, {Widget? action}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(color: RaikoColors.panel, borderRadius: BorderRadius.circular(18)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(message, style: const TextStyle(color: RaikoColors.muted, height: 1.5)), if (action != null) action]),
  );
}
