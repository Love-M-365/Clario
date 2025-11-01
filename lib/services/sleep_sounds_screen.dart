import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../main.dart'; // To get the audioHandler instance

class SleepSoundsScreen extends StatefulWidget {
  const SleepSoundsScreen({Key? key}) : super(key: key);

  @override
  _SleepSoundsScreenState createState() => _SleepSoundsScreenState();
}

class _SleepSoundsScreenState extends State<SleepSoundsScreen> {
  // TODO: REPLACE WITH YOUR FIREBASE URLS AND TITLES
  final List<MediaItem> _sleepSounds = [
    MediaItem(
      id: 'https://firebasestorage.googleapis.com/v0/b/clario-f60b0.firebasestorage.app/o/Sounds%2F10%20Minute%20Meditation%20Music%20for%20Deep%20Relaxation_Stress%20Relief%20_%20Positive%20Energy%20_%20Healing%20Sleep%20Music(M4A_128K).m4a?alt=media&token=e7b785db-2305-4413-8f14-e5d5c877ee0b', // <-- YOUR URL
      title: 'Forest Night',
      artist: 'Nature Sounds',
      artUri: Uri.parse(
          'https://images.unsplash.com/photo-1515694346937-940358e3879f'), // Placeholder
    ),
    MediaItem(
      id: 'https://firebasestorage.googleapis.com/v0/b/clario-f60b0.firebasestorage.app/o/Sounds%2F45%20Minute%20Deep%20Sleep%20Music%20for%20Relaxing%20and%20Falling%20Asleep_%20Doze(M4A_128K).m4a?alt=media&token=c64fbc78-f755-4701-b7d4-12e4c29c62c3', // <-- YOUR URL
      title: 'Ocean Waves',
      artist: 'Nature Sounds',
      artUri: Uri.parse(
          'https://images.unsplash.com/photo-1507525428034-b723cf961d3e'), // Placeholder
    ),
    MediaItem(
      id: 'https://firebasestorage.googleapis.com/v0/b/clario-f60b0.firebasestorage.app/o/Sounds%2FPowerful%20night%20thunderstorm%20-%20Heavy%20Rain%20and%20Thunder%20-%20Rain%20Sounds%20for%20sleep%20-%201%20hour%20Windy%20Rain(M4A_128K).m4a?alt=media&token=9753cb53-d6e8-43af-8103-0bb3c4b21237', // <-- YOUR URL
      title: 'Gentle Rain',
      artist: 'Nature Sounds',
      artUri: Uri.parse(
          'https://images.unsplash.com/photo-1448375240586-882707db888b'), // Placeholder
    ),
    MediaItem(
      id: 'https://firebasestorage.googleapis.com/v0/b/clario-f60b0.firebasestorage.app/o/Sounds%2F%5BTry%20Listening%20for%203%20Minutes%5D%20FALL%20ASLEEP%20FAST%20_%20DEEP%20SLEEP%20RELAXING%20MUSIC(M4A_128K).m4a?alt=media&token=a4b25a56-72c6-4845-8771-2f5d3d99c43b', // <-- YOUR URL
      title: 'Cozy Fireplace',
      artist: 'Ambient Sounds',
      artUri: Uri.parse(
          'https://images.unsplash.com/photo-1542779263-02e232c6116c'), // Placeholder
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFC),
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        "Sleep Sounds",
        style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
      ),
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black54),
        onPressed: () => Navigator.of(context).pop(),
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildCurrentPlayer(),
          const SizedBox(height: 16),
          ..._sleepSounds.map((item) => _buildSoundCard(item)).toList(),
        ],
      ),
    );
  }

  /// Builds the main player UI at the top
  Widget _buildCurrentPlayer() {
    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      builder: (context, snapshot) {
        final mediaItem = snapshot.data;
        if (mediaItem == null) {
          // No sound loaded yet
          return Card(
            elevation: 2,
            shadowColor: Colors.black.withOpacity(0.1),
            color: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: const SizedBox(
              height: 120,
              child: Center(
                child: Text(
                  "Choose a sound to begin",
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
              ),
            ),
          );
        }

        // A sound is loaded, show the full player
        return Card(
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.1),
          color: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Image.network(
                mediaItem.artUri.toString(),
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) =>
                    const Icon(Icons.music_note, size: 150),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        mediaItem.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    _buildPlayPauseButton(), // The main play/pause button
                  ],
                ),
              ),
            ],
          ),
        ).animate().fadeIn();
      },
    );
  }

  /// Builds the small play/pause button for the main player
  Widget _buildPlayPauseButton() {
    return StreamBuilder<PlaybackState>(
      stream: audioHandler.playbackState,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final isPlaying = state?.playing ?? false;
        final processingState = state?.processingState;

        if (processingState == AudioProcessingState.loading ||
            processingState == AudioProcessingState.buffering) {
          return Container(
            width: 48,
            height: 48,
            padding: const EdgeInsets.all(8),
            child: const CircularProgressIndicator(),
          );
        }

        return IconButton(
          icon: Icon(isPlaying ? Icons.pause_circle : Icons.play_circle,
              color: Colors.blue.shade700, size: 48),
          onPressed: isPlaying ? audioHandler.pause : audioHandler.play,
        );
      },
    );
  }

  /// Builds a card for each sound in the list
  Widget _buildSoundCard(MediaItem item) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 1,
      shadowColor: Colors.black.withOpacity(0.05),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: NetworkImage(item.artUri.toString()),
          onBackgroundImageError: (e, s) =>
              const Icon(Icons.music_note, size: 20),
        ),
        title: Text(item.title,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(item.artist ?? 'Sleep Sound'),
        onTap: () {
          // --- THIS IS THE FIX ---
          // When tapped, load this sound into the player
          audioHandler.loadSound(item); // <-- Changed from .loadSound
          // --- END OF FIX ---
          audioHandler.play();
        },
      ),
    ).animate().fadeIn(delay: (100 * _sleepSounds.indexOf(item)).ms);
  }
}
