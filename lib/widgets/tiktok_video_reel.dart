import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:zcanopy/utils/colors.dart';
import 'package:zcanopy/pages/brokerCollection.dart';

/// A TikTok-style vertical video reel.
/// Videos snap-scroll one-at-a-time, only the focused video plays (muted by
/// default), and each tile shows property info plus a TikTok-style action rail
/// with like, share, view and mute controls.
class TikTokVideoReel extends StatefulWidget {
  final List<Map<String, dynamic>> videos;

  const TikTokVideoReel({super.key, required this.videos});

  @override
  State<TikTokVideoReel> createState() => _TikTokVideoReelState();
}

class _TikTokVideoReelState extends State<TikTokVideoReel> {
  final PageController _pageController = PageController();
  final Map<int, VideoPlayerController> _controllers = {};
  final Set<String> _liked = {};
  int _currentIndex = 0;
  bool _muted = true;

  @override
  void initState() {
    super.initState();
    _loadLikes();
    _initController(0);
    if (widget.videos.length > 1) _initController(1);
  }

  void _loadLikes() {
    try {
      if (!Hive.isBoxOpen('myStore')) return;
      final stored = Hive.box('myStore').get('likedVideoIds');
      if (stored is List) {
        _liked.addAll(stored.map((id) => id.toString()));
      }
    } catch (_) {}
  }

  String _videoKey(Map<String, dynamic> video) {
    final id = video['id']?.toString() ?? '';
    if (id.isNotEmpty) return id;
    return video['videoUrl']?.toString() ?? '';
  }

  void _toggleLike(Map<String, dynamic> video) {
    final key = _videoKey(video);
    if (key.isEmpty) return;
    setState(() {
      if (!_liked.add(key)) _liked.remove(key);
    });
    try {
      if (Hive.isBoxOpen('myStore')) {
        Hive.box('myStore').put('likedVideoIds', _liked.toList());
      }
    } catch (_) {}
  }

  Future<void> _shareVideo(Map<String, dynamic> video) async {
    final title = video['title']?.toString() ?? 'Property tour';
    final location = video['location']?.toString() ?? '';
    final district = video['district']?.toString() ?? '';
    final place = location.isNotEmpty ? location : district;
    await SharePlus.instance.share(
      ShareParams(
        text:
            '$title${place.isNotEmpty ? '\n$place' : ''}\n'
            'Check out this property tour on Zcanopy.',
      ),
    );
  }

  void _openBroker(Map<String, dynamic> video) {
    final brokerCode = video['brokerCode']?.toString();
    if (brokerCode == null || brokerCode.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BrokerCollectionPage(
          brokerCode: brokerCode,
          brokerName: video['brokerName']?.toString() ?? 'Broker',
          brokerPhone: video['brokerPhone']?.toString() ?? '',
        ),
      ),
    );
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
        final key = _videoKey(video);
        final liked = _liked.contains(key);
        final baseLikes =
            int.tryParse('${video['likeCount'] ?? video['likes'] ?? 0}') ?? 0;
        return _ReelTile(
          video: video,
          controller: controller,
          isActive: index == _currentIndex,
          muted: _muted,
          liked: liked,
          likeCount: baseLikes + (liked ? 1 : 0),
          onToggleMute: _toggleMute,
          onToggleLike: () => _toggleLike(video),
          onShare: () => _shareVideo(video),
          onView: () => _openBroker(video),
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
  final bool liked;
  final int likeCount;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleLike;
  final VoidCallback onShare;
  final VoidCallback onView;

  const _ReelTile({
    required this.video,
    required this.controller,
    required this.isActive,
    required this.muted,
    required this.liked,
    required this.likeCount,
    required this.onToggleMute,
    required this.onToggleLike,
    required this.onShare,
    required this.onView,
  });

  String _formatCount(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return '$value';
  }

  @override
  Widget build(BuildContext context) {
    final title = video['title']?.toString() ?? 'Property tour';
    final location = video['location']?.toString() ?? '';
    final subCounty = video['subCounty']?.toString() ?? '';
    final district = video['district']?.toString() ?? '';
    final brokerName = video['brokerName']?.toString() ?? '';
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
          const Center(child: CircularProgressIndicator(color: Colors.white70)),
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black54, Colors.transparent, Colors.black87],
              stops: [0.0, 0.45, 1.0],
            ),
          ),
        ),
        Positioned(
          top: 16,
          right: 16,
          child: IconButton(
            onPressed: onToggleMute,
            tooltip: muted ? 'Unmute' : 'Mute',
            icon: Icon(
              muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              color: Colors.white,
            ),
            style: IconButton.styleFrom(backgroundColor: Colors.black45),
          ),
        ),
        Positioned(
          right: 12,
          bottom: 88,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ReelAction(
                icon: liked ? Icons.favorite : Icons.favorite_border,
                iconColor: liked ? const Color(0xFFFF3B5C) : Colors.white,
                label: _formatCount(likeCount),
                semanticLabel: liked ? 'Unlike tour' : 'Like tour',
                onTap: onToggleLike,
              ),
              const SizedBox(height: 18),
              _ReelAction(
                icon: Icons.ios_share_rounded,
                label: 'Share',
                semanticLabel: 'Share tour',
                onTap: onShare,
              ),
              const SizedBox(height: 18),
              _ReelAction(
                icon: Icons.visibility_outlined,
                label: 'View',
                semanticLabel: 'View broker',
                onTap: onView,
              ),
            ],
          ),
        ),
        Positioned(
          left: 16,
          right: 88,
          bottom: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  subCounty.isNotEmpty ? subCounty : location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  height: 1.15,
                ),
              ),
              if (district.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    district,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              if (brokerName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    'Listed by $brokerName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReelAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final String semanticLabel;
  final Color iconColor;
  final VoidCallback onTap;

  const _ReelAction({
    required this.icon,
    required this.label,
    required this.semanticLabel,
    required this.onTap,
    this.iconColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.black.withValues(alpha: 0.4),
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: SizedBox(
                width: 50,
                height: 50,
                child: Icon(icon, color: iconColor, size: 26),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
            ),
          ),
        ],
      ),
    );
  }
}
