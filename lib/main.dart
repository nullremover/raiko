
import 'package:flutter/material.dart';

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
  int _selectedTab = 0;
  bool _isPlaying = false;
  bool _liked = false;

  static const _tabs = [
    'Home',
    'Library',
    'Now Playing',
    'Queue',
    'About',
  ];

  IconData _tabIcon(int index) {
    return switch (index) {
      0 => Icons.home_rounded,
      1 => Icons.library_music_rounded,
      2 => Icons.album_rounded,
      3 => Icons.queue_music_rounded,
      _ => Icons.info_outline_rounded,
    };
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
                          Expanded(
                            child: _buildPage(desktop),
                          ),
                          _buildMiniPlayer(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar:
              desktop ? null : _buildBottomNavigation(),
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
            for (var i = 0; i < _tabs.length; i++)
              _navItem(i),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'YOUR MUSIC.\nYOUR UNIVERSE.',
                style: TextStyle(
                  color: RaikoColors.muted,
                  height: 1.7,
                  fontSize: 10,
                  letterSpacing: 1.4,
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
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 3,
      ),
      child: ListTile(
        selected: selected,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        selectedTileColor:
            RaikoColors.cobalt.withValues(alpha: 0.2),
        leading: Icon(
          _tabIcon(index),
          color: selected
              ? RaikoColors.starlight
              : RaikoColors.muted,
        ),
        title: Text(
          _tabs[index],
          style: TextStyle(
            color: selected
                ? RaikoColors.text
                : RaikoColors.muted,
            fontWeight:
                selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        onTap: () => setState(() => _selectedTab = index),
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
        2 => _buildNowPlaying(),
        3 => _buildQueue(),
        _ => _buildAbout(),
      },
    );
  }

  Widget _buildHome(bool desktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'YOUR SOUND,',
          style: TextStyle(
            color: RaikoColors.starlight.withValues(alpha: 0.8),
            fontSize: 12,
            letterSpacing: 4,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Beyond the ordinary.',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'A universe for the music that moves you.',
          style: TextStyle(
            color: RaikoColors.muted,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 30),
        _buildFeaturedCard(desktop),
        const SizedBox(height: 32),
        const Text(
          'YOUR LIBRARY',
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _buildEmptyLibrary(),
      ],
    );
  }

  Widget _buildFeaturedCard(bool desktop) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF192F6B),
            Color(0xFF10172C),
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
            Icons.auto_awesome_rounded,
            color: RaikoColors.starlight,
            size: 24,
          ),
          const SizedBox(height: 18),
          const Text(
            'WELCOME TO RAIKO',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 3,
              color: RaikoColors.starlight,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Your music.\nYour universe.',
            style: TextStyle(
              fontSize: desktop ? 34 : 29,
              height: 1.15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Start with your own collection. '
            'More ways to discover music will come later.',
            style: TextStyle(
              color: RaikoColors.muted,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => setState(() => _selectedTab = 1),
            icon: const Icon(Icons.library_music_rounded),
            label: const Text('Open your library'),
            style: FilledButton.styleFrom(
              backgroundColor: RaikoColors.cobalt,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyLibrary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: RaikoColors.panel.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.music_note_rounded,
            color: RaikoColors.starlight,
            size: 30,
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'A little quiet in here',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 5),
                Text(
                  'Your music library will live here.',
                  style: TextStyle(
                    color: RaikoColors.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
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
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Your collection, on your terms.',
          style: TextStyle(color: RaikoColors.muted),
        ),
        const SizedBox(height: 28),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: RaikoColors.panel,
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Column(
            children: [
              Icon(
                Icons.library_music_rounded,
                size: 44,
                color: RaikoColors.starlight,
              ),
              SizedBox(height: 14),
              Text(
                'No tracks yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Local music import is the next major feature.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: RaikoColors.muted,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNowPlaying() {
    return Column(
      children: [
        const Text(
          'NOW PLAYING',
          style: TextStyle(
            color: RaikoColors.starlight,
            letterSpacing: 3,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 28),
        Container(
          width: 240,
          height: 240,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF345FD1),
                Color(0xFF10172D),
                Color(0xFF05070D),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: RaikoColors.cobalt.withValues(alpha: 0.22),
                blurRadius: 40,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.blur_on_rounded,
                size: 76,
                color: RaikoColors.starlight,
              ),
              SizedBox(height: 12),
              Text(
                'RAIKO',
                style: TextStyle(
                  letterSpacing: 8,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          'Nothing playing yet',
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your next favourite track starts here.',
          style: TextStyle(color: RaikoColors.muted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        IconButton.filled(
          onPressed: () => setState(() => _selectedTab = 1),
          icon: const Icon(Icons.library_music_rounded),
          iconSize: 30,
          style: IconButton.styleFrom(
            backgroundColor: RaikoColors.cobalt,
            minimumSize: const Size(68, 68),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Browse library',
          style: TextStyle(color: RaikoColors.muted),
        ),
      ],
    );
  }

  Widget _buildQueue() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Up next',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),
        const Center(
          child: Column(
            children: [
              Icon(
                Icons.queue_music_rounded,
                size: 54,
                color: RaikoColors.starlight,
              ),
              SizedBox(height: 12),
              Text('Your queue is empty'),
              SizedBox(height: 8),
              Text(
                'Tracks will appear here when you start listening.',
                textAlign: TextAlign.center,
                style: TextStyle(color: RaikoColors.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAbout() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'About Raiko',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 16),
        Text(
          'A music player built around your collection, '
          'your privacy, and your personal listening universe.',
          style: TextStyle(
            color: RaikoColors.muted,
            height: 1.8,
          ),
        ),
        SizedBox(height: 24),
        Text(
          'RAIKO • EARLY DEVELOPMENT',
          style: TextStyle(
            color: RaikoColors.starlight,
            letterSpacing: 2,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniPlayer() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF151B2B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: RaikoColors.starlight.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: const LinearGradient(
                colors: [
                  RaikoColors.cobalt,
                  Color(0xFF101522),
                ],
              ),
            ),
            child: const Icon(
              Icons.album_rounded,
              color: RaikoColors.starlight,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nothing playing',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 4),
                Text(
                  'Raiko player',
                  style: TextStyle(
                    color: RaikoColors.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: _isPlaying ? 'Pause' : 'Play',
            onPressed: () {
              setState(() => _isPlaying = !_isPlaying);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _isPlaying
                        ? 'Playback will be connected next.'
                        : 'Playback paused.',
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            icon: Icon(
              _isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              color: RaikoColors.text,
            ),
          ),
          IconButton(
            tooltip: _liked ? 'Unlike' : 'Like',
            onPressed: () => setState(() => _liked = !_liked),
            icon: Icon(
              _liked
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: _liked
                  ? RaikoColors.starlight
                  : RaikoColors.muted,
            ),
          ),
        ],
      ),
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

class _RaikoLogo extends StatelessWidget {
  const _RaikoLogo();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.blur_on_rounded,
          color: RaikoColors.starlight,
          size: 28,
        ),
        SizedBox(width: 8),
        Text(
          'raiko',
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
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
