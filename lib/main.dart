import 'dart:io';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

void main() {
  runApp(const RaikoApp());
}

abstract final class RaikoColors {
  static const background = Color(0xFF070910);
  static const panel = Color(0xFF111522);
  static const cobalt = Color(0xFF1749C9);
  static const starlight = Color(0xFF86B4FF);
  static const text = Color(0xFFF4F6FF);
  static const muted = Color(0xFF9299AD);
}

class RaikoApp extends StatelessWidget {
  const RaikoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Raiko',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: RaikoColors.background,
        colorScheme: const ColorScheme.dark(
          primary: RaikoColors.cobalt,
          secondary: RaikoColors.starlight,
          surface: RaikoColors.panel,
        ),
        useMaterial3: true,
      ),
      home: const RaikoHome(),
    );
  }
}

class RaikoHome extends StatefulWidget {
  const RaikoHome({super.key});

  @override
  State<RaikoHome> createState() => _RaikoHomeState();
}

class _RaikoHomeState extends State<RaikoHome> {
  final AudioPlayer _player = AudioPlayer();
  final List<PlatformFile> _tracks = [];
  final Set<String> _likedTracks = {};
  final Map<String, AudioMetadata> _trackMetadata = {};

  static const _iosFolderChannel = MethodChannel('com.raiko.app/ios_folder');

  int _selectedTab = 0;
  bool _queueLoaded = false;
  bool _importing = false;
  String? _errorMessage;

  static const _allowedExtensions = ['mp3', 'm4a', 'aac', 'wav', 'ogg', 'flac', 'aiff', 'aif'];

  static const _tabs = [
    'Home',
    'Library',
    'Now Playing',
    'Queue',
    'About',
  ];

  IconData _tabIcon(int index) => switch (index) {
        0 => Icons.grid_view_rounded,
        1 => Icons.library_music_rounded,
        2 => Icons.graphic_eq_rounded,
        3 => Icons.queue_music_rounded,
        _ => Icons.info_outline_rounded,
      };

  PlatformFile? get _currentTrack {
    final index = _player.currentIndex;
    if (index == null || index < 0 || index >= _tracks.length) {
      return null;
    }
    return _tracks[index];
  }

  String _trackTitle(PlatformFile track) {
    final metadata = _trackMetadata[track.name];
    if (metadata != null && metadata.title != null && metadata.title!.isNotEmpty) {
      return metadata.title!;
    }
    final name = track.name;
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  String _trackArtist(PlatformFile track) {
    final metadata = _trackMetadata[track.name];
    if (metadata != null && metadata.artist != null && metadata.artist!.isNotEmpty) {
      return metadata.artist!;
    }
    return 'Local file';
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '--:--';

    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);

    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String _mimeType(String name) {
    final extension = name.split('.').last.toLowerCase();

    return switch (extension) {
      'mp3' => 'audio/mpeg',
      'm4a' || 'aac' => 'audio/mp4',
      'wav' => 'audio/wav',
      'ogg' => 'audio/ogg',
      'flac' => 'audio/flac',
      'aif' || 'aiff' => 'audio/aiff',
      _ => 'application/octet-stream',
    };
  }

  Future<void> _importMusic() async {
    if (_importing) return;

    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: RaikoColors.panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add Music', style: TextStyle(fontFamily: 'DelaGothicOne', fontSize: 20)),
        content: const Text('Would you like to import individual audio files or a whole folder?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'files'),
            child: const Text('Files', style: TextStyle(color: RaikoColors.starlight)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'folder'),
            style: FilledButton.styleFrom(backgroundColor: RaikoColors.cobalt),
            child: const Text('Folder'),
          ),
        ],
      ),
    );

    if (choice == null) return;

    setState(() {
      _importing = true;
      _errorMessage = null;
    });

    try {
      final List<PlatformFile> collectedFiles = [];

      if (choice == 'files') {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: _allowedExtensions,
          allowMultiple: true,
          withData: true,
        );

        if (result != null && result.files.isNotEmpty) {
          collectedFiles.addAll(result.files.where((file) {
            return kIsWeb ? file.bytes != null : file.path != null;
          }));
        }
      } else if (choice == 'folder') {
        if (kIsWeb) {
          throw Exception('Folder picking is not supported on the web.');
        }

        final directoryPath = await FilePicker.platform.getDirectoryPath();
        if (directoryPath != null) {
          List<String> filePaths = [];

          if (Platform.isIOS) {
            final List<dynamic> paths = await _iosFolderChannel.invokeMethod(
              'getFolderFiles',
              {'path': directoryPath},
            );
            filePaths = paths.cast<String>();
          } else {
            final directory = Directory(directoryPath);
            filePaths = directory
                .listSync(recursive: true)
                .whereType<File>()
                .map((e) => e.path)
                .toList();
          }

          for (final path in filePaths) {
            final extension = path.split('.').last.toLowerCase();
            if (_allowedExtensions.contains(extension)) {
              final file = File(path);
              final name = path.split(Platform.pathSeparator).last;
              final bytes = await file.readAsBytes();
              collectedFiles.add(
                PlatformFile(
                  name: name,
                  path: path,
                  size: bytes.length,
                  bytes: bytes,
                ),
              );
            }
          }
        }
      }

      if (collectedFiles.isEmpty) return;

      final oldCount = _tracks.length;

      setState(() {
        for (final file in collectedFiles) {
          final alreadyAdded = _tracks.any(
            (track) => track.name == file.name && track.path == file.path,
          );

          if (!alreadyAdded) {
            _tracks.add(file);

            if (!kIsWeb && file.path != null) {
              try {
                final metadata = readMetadata(
								  File(file.path!),
								  getImage: true,
								);
                if (mounted) {
                  setState(() {
                    _trackMetadata[file.name] = metadata;
                  });
                }
              } catch (_) {}
            }
          }
        }
      });

      if (_tracks.isEmpty) return;

      final sources = _tracks.map((track) {
        final uri = kIsWeb
            ? Uri.dataFromBytes(
                track.bytes!,
                mimeType: _mimeType(track.name),
              )
            : Uri.file(track.path!);

        return AudioSource.uri(uri);
      }).toList();

      final startIndex = oldCount < _tracks.length ? oldCount : 0;

      await _player.setAudioSources(
        sources,
        initialIndex: startIndex,
        initialPosition: Duration.zero,
      );

      _queueLoaded = true;

      if (mounted) {
        setState(() => _selectedTab = 2);
      }

      await _player.play();
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not load music: $error';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _importing = false);
      }
    }
  }

  Future<void> _playTrack(int index) async {
    try {
      if (!_queueLoaded) return;

      await _player.seek(Duration.zero, index: index);
      await _player.play();

      if (mounted) setState(() => _selectedTab = 2);
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = 'Could not play this track: $error');
      }
    }
  }

  Future<void> _togglePlayback() async {
    try {
      if (!_queueLoaded || _tracks.isEmpty) {
        await _importMusic();
        return;
      }

      if (_player.playing) {
        await _player.pause();
      } else {
        if (_player.processingState == ProcessingState.completed) {
          await _player.seek(Duration.zero);
        }
        await _player.play();
      }
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = 'Playback failed: $error');
      }
    }
  }

  Future<void> _nextTrack() async {
    if (_player.hasNext) {
      await _player.seekToNext();
    }
  }

  Future<void> _previousTrack() async {
    if (_player.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
    } else if (_player.hasPrevious) {
      await _player.seekToPrevious();
    } else {
      await _player.seek(Duration.zero);
    }
  }

  void _toggleLike() {
    final track = _currentTrack;
    if (track == null) return;

    setState(() {
      if (!_likedTracks.add(track.name)) {
        _likedTracks.remove(track.name);
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 760;

        return Scaffold(
          body: Stack(
            children: [
              const Positioned(
                top: -130,
                right: -100,
                child: _GlowOrb(),
              ),
              SafeArea(
                child: Row(
                  children: [
                    if (desktop) _buildSidebar(),
                    Expanded(
                      child: Column(
                        children: [
                          _buildHeader(),
                          Expanded(child: _buildPage(desktop)),
                          _buildMiniPlayer(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: desktop ? null : _buildBottomNavigation(),
        );
      },
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 210,
      decoration: BoxDecoration(
        color: RaikoColors.panel.withValues(alpha: 0.65),
        border: Border(
          right: BorderSide(
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(24),
              child: _RaikoLogo(),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 8, 24, 12),
              child: Text(
                'YOUR SPACE',
                style: TextStyle(
                  color: RaikoColors.muted,
                  fontSize: 10,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            for (var i = 0; i < _tabs.length; i++) _navItem(i),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'MUSIC IN MIND.',
                style: TextStyle(
                  color: RaikoColors.muted,
                  fontSize: 10,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navItem(int index) {
    final selected = _selectedTab == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: selected
            ? RaikoColors.cobalt.withValues(alpha: 0.22)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          selected: selected,
          selectedTileColor: Colors.transparent,
          leading: Icon(
            _tabIcon(index),
            color: selected ? RaikoColors.starlight : RaikoColors.muted,
          ),
          title: Text(
            _tabs[index],
            style: TextStyle(
              color: selected ? RaikoColors.text : RaikoColors.muted,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          onTap: () => setState(() => _selectedTab = index),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 12),
      child: Row(
        children: [
          const Expanded(child: _RaikoLogo()),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: RaikoColors.panel,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.offline_bolt_rounded,
                  size: 16,
                  color: RaikoColors.starlight,
                ),
                SizedBox(width: 7),
                Text(
                  'LOCAL FIRST',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1,
                    color: RaikoColors.text,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(bool desktop) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        desktop ? 36 : 22,
        18,
        desktop ? 36 : 22,
        30,
      ),
      child: switch (_selectedTab) {
        0 => _buildHome(desktop),
        1 => _buildLibrary(),
        2 => _buildNowPlaying(desktop),
        3 => _buildQueue(),
        _ => _buildAbout(),
      },
    );
  }

  Widget _buildHome(bool desktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'GOOD TO HAVE YOU HERE',
          style: TextStyle(
            color: RaikoColors.starlight,
            fontSize: 11,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'raiko',
          style: TextStyle(
            fontFamily: 'DelaGothicOne',
            fontSize: 34,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Break through the music.',
          style: TextStyle(color: RaikoColors.muted),
        ),
        const SizedBox(height: 28),
        _buildFeaturedCard(desktop),
        const SizedBox(height: 28),
        Row(
          children: [
            const Expanded(
              child: Text(
                'YOUR LIBRARY',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _selectedTab = 1),
              child: const Text('View all'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _tracks.isEmpty ? _buildEmptyLibrary() : _buildTrackList(compact: true),
      ],
    );
  }

  Widget _buildFeaturedCard(bool desktop) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF213D83),
            Color(0xFF111A32),
            Color(0xFF11121C),
          ],
        ),
        border: Border.all(
          color: RaikoColors.starlight.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.graphic_eq_rounded,
            color: RaikoColors.starlight,
            size: 28,
          ),
          const SizedBox(height: 18),
          Text(
            _tracks.isEmpty ? 'NOTHING PLAYING' : 'IN YOUR LIBRARY',
            style: const TextStyle(
              fontSize: 10,
              letterSpacing: 2,
              color: RaikoColors.starlight,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _tracks.isEmpty ? 'Got music?' : 'Pick up where you left off.',
            style: TextStyle(
              fontSize: desktop ? 25 : 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _tracks.isEmpty
                ? 'Add the songs you already have.'
                : '${_tracks.length} tracks in your library.',
            style: const TextStyle(
              color: RaikoColors.muted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _importing ? null : _importMusic,
            icon: Icon(
              _importing ? Icons.hourglass_top : Icons.add_rounded,
            ),
            label: Text(_importing ? 'Loading music…' : 'Add music'),
            style: FilledButton.styleFrom(
              backgroundColor: RaikoColors.cobalt,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 14,
              ),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.orangeAccent),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyLibrary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: RaikoColors.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.library_music_outlined,
            color: RaikoColors.starlight,
            size: 30,
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No music yet',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 5),
                Text(
                  'Add some songs to get started.',
                  style: TextStyle(
                    color: RaikoColors.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Add music',
            onPressed: _importing ? null : _importMusic,
            icon: const Icon(Icons.add_circle_outline_rounded),
            color: RaikoColors.starlight,
          ),
        ],
      ),
    );
  }

  Widget _buildLibrary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Library',
          style: TextStyle(
            fontFamily: 'DelaGothicOne',
            fontSize: 27,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${_tracks.length} ${_tracks.length == 1 ? 'track' : 'tracks'}',
          style: const TextStyle(color: RaikoColors.muted),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _importing ? null : _importMusic,
            icon: const Icon(Icons.add_rounded),
            label: Text(_importing ? 'Loading…' : 'Add music'),
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.orangeAccent),
          ),
        ],
        const SizedBox(height: 18),
        if (_tracks.isEmpty) _buildEmptyLibrary() else _buildTrackList(),
      ],
    );
  }

  Widget _buildTrackList({bool compact = false}) {
    return StreamBuilder<int?>(
      stream: _player.currentIndexStream,
      builder: (context, snapshot) {
        final currentIndex = snapshot.data;

        return Column(
          children: [
            for (var i = 0; i < _tracks.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Material(
                  color: currentIndex == i
                      ? RaikoColors.cobalt.withValues(alpha: 0.17)
                      : RaikoColors.panel.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(14),
                  child: ListTile(
                    onTap: () => _playTrack(i),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: currentIndex == i
                            ? RaikoColors.cobalt
                            : const Color(0xFF202941),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        currentIndex == i
                            ? Icons.graphic_eq_rounded
                            : Icons.music_note_rounded,
                        color: RaikoColors.starlight,
                      ),
                    ),
                    title: Text(
                      _trackTitle(_tracks[i]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      _trackArtist(_tracks[i]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: RaikoColors.muted,
                        fontSize: 12,
                      ),
                    ),
                    trailing: compact
                        ? const Icon(
                            Icons.play_arrow_rounded,
                            color: RaikoColors.starlight,
                          )
                        : IconButton(
                            tooltip: _likedTracks.contains(_tracks[i].name)
                                ? 'Unlike'
                                : 'Like',
                            onPressed: () {
                              setState(() {
                                if (!_likedTracks.add(_tracks[i].name)) {
                                  _likedTracks.remove(_tracks[i].name);
                                }
                              });
                            },
                            icon: Icon(
                              _likedTracks.contains(_tracks[i].name)
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: _likedTracks.contains(_tracks[i].name)
                                  ? RaikoColors.starlight
                                  : RaikoColors.muted,
                            ),
                          ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildNowPlaying(bool desktop) {
    return StreamBuilder<int?>(
      stream: _player.currentIndexStream,
      builder: (context, snapshot) {
        final track = _currentTrack;
        final hasTrack = track != null;

        return Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'NOW PLAYING',
                style: TextStyle(
                  color: RaikoColors.starlight.withValues(alpha: 0.9),
                  letterSpacing: 2.5,
                  fontSize: 10,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: desktop ? 290 : 240,
              height: desktop ? 290 : 240,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF345FD1),
                    Color(0xFF17213D),
                    Color(0xFF080A12),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: RaikoColors.cobalt.withValues(alpha: 0.2),
                    blurRadius: 36,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: (() {
                  if (track != null) {
                    final metadata = _trackMetadata[track.name];
                    if (metadata != null && metadata.pictures.isNotEmpty) {
                      return Image.memory(
                        metadata.pictures.first.bytes,
                        fit: BoxFit.cover,
                      );
                    }
                  }
                  return Center(
                    child: Icon(
                      hasTrack ? Icons.graphic_eq_rounded : Icons.album_rounded,
                      size: 82,
                      color: RaikoColors.starlight,
                    ),
                  );
                })(),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              hasTrack ? _trackTitle(track) : 'Nothing playing',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasTrack ? _trackArtist(track) : 'Pick a song from Library',
              style: const TextStyle(color: RaikoColors.muted),
            ),
            const SizedBox(height: 20),
            _buildSeekBar(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Previous track',
                  onPressed: hasTrack ? _previousTrack : null,
                  icon: const Icon(Icons.skip_previous_rounded),
                  iconSize: 34,
                ),
                const SizedBox(width: 12),
                StreamBuilder<PlayerState>(
                  stream: _player.playerStateStream,
                  builder: (context, snapshot) {
                    final playing = snapshot.data?.playing ?? false;
                    final loading = snapshot.data?.processingState ==
                            ProcessingState.loading ||
                        snapshot.data?.processingState ==
                            ProcessingState.buffering;

                    return IconButton.filled(
                      tooltip: playing ? 'Pause' : 'Play',
                      onPressed: _togglePlayback,
                      icon: loading
                          ? const SizedBox(
                              width: 25,
                              height: 25,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : Icon(
                              playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                            ),
                      iconSize: 34,
                      style: IconButton.styleFrom(
                        backgroundColor: RaikoColors.cobalt,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(68, 68),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),
                IconButton(
                  tooltip: 'Next track',
                  onPressed: hasTrack ? _nextTrack : null,
                  icon: const Icon(Icons.skip_next_rounded),
                  iconSize: 34,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: _currentTrack != null &&
                          _likedTracks.contains(_currentTrack!.name)
                      ? 'Unlike'
                      : 'Like',
                  onPressed: hasTrack ? _toggleLike : null,
                  icon: Icon(
                    hasTrack && _likedTracks.contains(track.name)
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: hasTrack && _likedTracks.contains(track.name)
                        ? RaikoColors.starlight
                        : RaikoColors.muted,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => setState(() => _selectedTab = 3),
                  icon: const Icon(Icons.queue_music_rounded),
                  label: const Text('Queue'),
                ),
              ],
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.orangeAccent),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSeekBar() {
    return StreamBuilder<Duration?>(
      stream: _player.durationStream,
      builder: (context, durationSnapshot) {
        final duration = durationSnapshot.data ?? Duration.zero;

        return StreamBuilder<Duration>(
          stream: _player.positionStream,
          builder: (context, positionSnapshot) {
            final position = positionSnapshot.data ?? Duration.zero;
            final maxMs = duration.inMilliseconds;
            final currentMs =
                position.inMilliseconds.clamp(0, maxMs > 0 ? maxMs : 1);

            return Column(
              children: [
                Slider(
                  min: 0,
                  max: maxMs > 0 ? maxMs.toDouble() : 1,
                  value: currentMs.toDouble(),
                  onChanged: maxMs > 0
                      ? (value) {
                          _player.seek(
                            Duration(milliseconds: value.round()),
                          );
                        }
                      : null,
                  activeColor: RaikoColors.starlight,
                  inactiveColor: RaikoColors.panel,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(position),
                        style: const TextStyle(
                          color: RaikoColors.muted,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        _formatDuration(duration),
                        style: const TextStyle(
                          color: RaikoColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildQueue() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Up next',
          style: TextStyle(
            fontFamily: 'DelaGothicOne',
            fontSize: 26,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your listening queue.',
          style: TextStyle(color: RaikoColors.muted),
        ),
        const SizedBox(height: 22),
        if (_tracks.isEmpty) _buildEmptyLibrary() else _buildTrackList(),
      ],
    );
  }

  Widget _buildAbout() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'About raiko',
          style: TextStyle(
            fontFamily: 'DelaGothicOne',
            fontSize: 27,
          ),
        ),
        SizedBox(height: 28),
        _AboutQuestion(
          question: 'hiii!! So what is… “Raiko?” And why should I use it?',
          answer:
              'Raiko is a free music app that aims to bring the same '
              'features to EVERY platform. From mobile to PC!\n\n'
              'The goal is to break through the music, wherever life '
              'takes it (or you). ;)',
        ),
        SizedBox(height: 26),
        _AboutQuestion(
          question: 'Sounds tuff :) But what about it is really a selling point?',
          answer:
              'Well, it started out with Mish. mish is where I got my '
              'chance to play around and make some… questionable design '
              'choices.\n\n'
              'Now, with this lean mean machine, we’ll have more room '
              'to breathe, experiment, and recover.\n\n'
              'Music, and more ideas. It’s a good mix.',
        ),
        SizedBox(height: 26),
        _AboutQuestion(
          question: 'And yes, it’s a work in progress.',
          answer:
              'Raiko is being built one step at a time (in fact, I use '
              'my phone to type this into the code lolll).\n\n'
              'There’s a lot more I want it to be, so we’re starting '
              'somewhere good. With a little humanity.',
        ),
        SizedBox(height: 26),
        Text(
          'music in mind.',
          style: TextStyle(
            color: RaikoColors.starlight,
            fontFamily: 'DelaGothicOne',
            fontSize: 17,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Designed as an alternative to the now-retired mish. '
          'But it’ll be back. ;)',
          style: TextStyle(
            color: RaikoColors.muted,
            height: 1.7,
          ),
        ),
        SizedBox(height: 28),
        Text(
          'RAIKO • EARLY DEVELOPMENT',
          style: TextStyle(
            color: RaikoColors.starlight,
            letterSpacing: 1.5,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniPlayer() {
    return StreamBuilder<int?>(
      stream: _player.currentIndexStream,
      builder: (context, indexSnapshot) {
        final track = _currentTrack;

        return Container(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF151B2B),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: RaikoColors.starlight.withValues(alpha: 0.14),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  gradient: const LinearGradient(
                    colors: [
                      RaikoColors.cobalt,
                      Color(0xFF101522),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.graphic_eq_rounded,
                  color: RaikoColors.starlight,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedTab = 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track == null ? 'Nothing playing' : _trackTitle(track),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        track == null ? 'raiko' : _trackArtist(track),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: RaikoColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              StreamBuilder<PlayerState>(
                stream: _player.playerStateStream,
                builder: (context, snapshot) {
                  return IconButton(
                    tooltip: snapshot.data?.playing == true ? 'Pause' : 'Play',
                    onPressed: _togglePlayback,
                    icon: Icon(
                      snapshot.data?.playing == true
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomNavigation() {
    return NavigationBar(
      backgroundColor: RaikoColors.panel,
      indicatorColor: RaikoColors.cobalt.withValues(alpha: 0.3),
      selectedIndex: _selectedTab,
      onDestinationSelected: (index) {
        setState(() => _selectedTab = index);
      },
      destinations: [
        for (var i = 0; i < _tabs.length; i++)
          NavigationDestination(
            icon: Icon(_tabIcon(i)),
            label: _tabs[i],
          ),
      ],
    );
  }
}

class _AboutQuestion extends StatelessWidget {
  const _AboutQuestion({
    required this.question,
    required this.answer,
  });

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          answer,
          style: const TextStyle(
            color: RaikoColors.muted,
            height: 1.8,
          ),
        ),
      ],
    );
  }
}

class _RaikoLogo extends StatelessWidget {
  const _RaikoLogo();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.graphic_eq_rounded,
          color: RaikoColors.starlight,
          size: 27,
        ),
        SizedBox(width: 9),
        Text(
          'raiko',
          style: TextStyle(
            fontFamily: 'DelaGothicOne',
            fontSize: 22,
          ),
        ),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: 280,
        height: 280,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              RaikoColors.cobalt.withValues(alpha: 0.18),
              RaikoColors.cobalt.withValues(alpha: 0.04),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}
