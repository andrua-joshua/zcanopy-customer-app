import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Fullscreen video tour player opened from a listing card's play overlay.
/// Initializes the video on demand, auto-plays, and lets the user pause on tap
/// or toggle mute.
class VideoTourPlayer extends StatefulWidget {
  final Map<String, dynamic> property;

  const VideoTourPlayer({super.key, required this.property});

  @override
  State<VideoTourPlayer> createState() => _VideoTourPlayerState();
}

class _VideoTourPlayerState extends State<VideoTourPlayer> {
  VideoPlayerController? _controller;
  bool _initializing = true;
  bool _muted = false;
  bool _playing = true;

  String get _url => widget.property['video']?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final url = _url;
    if (url.isEmpty) {
      if (mounted) setState(() => _initializing = false);
      return;
    }
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = controller;
    controller.setLooping(true);
    controller.setVolume(_muted ? 0 : 1);
    try {
      await controller.initialize();
      if (!mounted) return;
      setState(() => _initializing = false);
      controller.play();
    } catch (_) {
      if (mounted) setState(() => _initializing = false);
    }
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    setState(() {
      _playing = !_playing;
      if (_playing) {
        c.play();
      } else {
        c.pause();
      }
    });
  }

  void _toggleMute() {
    setState(() {
      _muted = !_muted;
      _controller?.setVolume(_muted ? 0 : 1);
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initialized = _controller?.value.isInitialized ?? false;
    final name = widget.property['name']?.toString() ?? '';
    final sub = widget.property['subCounty']?.toString() ?? '';
    final dist = widget.property['district']?.toString() ?? '';
    final loc = sub.isNotEmpty && dist.isNotEmpty
        ? '$sub, $dist'
        : (widget.property['location']?.toString() ?? '');

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (initialized)
            Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              ),
            )
          else
            Center(
              child: _initializing
                  ? const CircularProgressIndicator(color: Colors.white70)
                  : const Icon(Icons.error_outline,
                      color: Colors.white54, size: 48),
            ),
          if (initialized)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _togglePlay,
              ),
            ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black54, Colors.transparent, Colors.black54],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              style: IconButton.styleFrom(backgroundColor: Colors.black45),
            ),
          ),
          if (initialized)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 8,
              child: IconButton(
                onPressed: _toggleMute,
                icon: Icon(
                  _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  color: Colors.white,
                ),
                style:
                    IconButton.styleFrom(backgroundColor: Colors.black45),
              ),
            ),
          if (name.isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (loc.isNotEmpty)
                    Text(
                      loc,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}