import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:zcanopy/utils/colors.dart';
import 'package:zcanopy/pages/itemDetails.dart';
import 'package:zcanopy/pages/brokerCollection.dart';

/// A TikTok-style vertical video reel.
/// Videos snap-scroll one-at-a-time, only the focused video plays (muted by
/// default), and each tile shows an elegant overlay with property info, a mute
/// toggle and a like action.
class TikTokVideoReel extends StatefulWidget {
  final List<Map<String, dynamic>> videos;

  const TikTokVideoReel({super.key, required this.videos});

  @override
  State<TikTokVideoReel> createState() => _TikTokVideoReelState();
}

class _TikTokVideoReelState extends State<TikTokVideoReel> {
  final PageController _pageController = PageController();
  final Map<int, VideoPlayerController> _controllers = {};
  int _currentIndex = 0;
  bool _muted = true;

  @override
  void initState() {
    super.initState();
    _initController(0);
    if (widget.videos.length > 1) _initController(1);
  }

  void _initController(int index) {
    if (index < 0 || index >= widget.videos.length) return;
    if (_controllers.containsKey(index)) return;
    final url = widget.videos[index]['videoUrl'] ?? '';
    if (url.isEmpty) return;
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    controller.setLooping(true);
    controller.setVolume(_muted ? 0 : 1);
    _controllers[index] = controller;
    controller.initialize().then((_) {
      if (mounted && index == _currentIndex) {
        controller.play();
        setState(() {});
      }
    });
  }

  void _onPageChanged(int index) {
    final prev = _currentIndex;
    _currentIndex = index;
    _initController(index);
    _initController(index + 1);
    _initController(index - 1);

    _controllers[prev]?.pause();
    _controllers[index]?.setVolume(_muted ? 0 : 1);
    _controllers[index]?.play();
    setState(() {});
  }

  void _toggleMute() {
    _muted = !_muted;
    for (final c in _controllers.values) {
      c.setVolume(_muted ? 0 : 1);
    }
    setState(() {});
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.videos.isEmpty) {
      return const SizedBox.shrink();
    }
    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      onPageChanged: _onPageChanged,
      itemCount: widget.videos.length,
      itemBuilder: (context, index) {
        final video = widget.videos[index];
        final controller = _controllers[index];
        return _ReelTile(
          video: video,
          controller: controller,
          isActive: index == _currentIndex,
          muted: _muted,
          onToggleMute: _toggleMute,
        );
      },
    );
  }
}

class _ReelTile extends StatelessWidget {
  final Map<String, dynamic> video;
  final VideoPlayerController? controller;
  final bool isActive;
  final bool muted;
  final VoidCallback onToggleMute;

  const _ReelTile({
    required this.video,
    required this.controller,
    required this.isActive,
    required this.muted,
    required this.onToggleMute,
  });

  @override
  Widget build(BuildContext context) {
    final title = video['title'] ?? 'Property tour';
    final location = video['location'] ?? '';
    final subCounty = video['subCounty'] ?? '';
    final district = video['district'] ?? '';
    final accent = AppColors.brown;

    final bool isInitialized = controller?.value.isInitialized ?? false;

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: Colors.black),
        if (isInitialized)
          Center(
            child: AspectRatio(
              aspectRatio: controller!.value.aspectRatio,
              child: VideoPlayer(controller!),
            ),
          )
        else
          const Center(
            child: CircularProgressIndicator(color: Colors.white70),
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
          top: 16,
          right: 16,
          child: IconButton(
            onPressed: onToggleMute,
            icon: Icon(
              muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              color: Colors.white,
            ),
            style: IconButton.styleFrom(
              backgroundColor: Colors.black45,
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 24,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        (subCounty.isNotEmpty ? subCounty : location),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (district.isNotEmpty)
                      Text(
                        district,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  final brokerCode = video['brokerCode']?.toString();
                  final brokerName = video['brokerName']?.toString() ?? 'Broker';
                  final brokerPhone = video['brokerPhone']?.toString() ?? '';
                  if (brokerCode != null && brokerCode.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BrokerCollectionPage(
                          brokerCode: brokerCode,
                          brokerName: brokerName,
                          brokerPhone: brokerPhone,
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.visibility, size: 18),
                label: const Text('View', style: TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brown,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
