import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:zcanopy/pages/homeScreen.dart';
import 'package:zcanopy/services/api_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:zcanopy/utils/theme_extensions.dart';
import 'package:zcanopy/widgets/themed_page_background.dart';

class OnBoardingScreen extends StatefulWidget {
  const OnBoardingScreen({super.key});

  @override
  State<OnBoardingScreen> createState() => _OnBoardingScreenState();
}

class _OnBoardingScreenState extends State<OnBoardingScreen> {
  final PageController _ctrl = PageController();
  bool isLastPage = false;
  bool _starting = false;
  final database = Hive.box('myStore');
  String? userID;

  static const _brown = Color.fromARGB(255, 169, 97, 14);

  final List<_Slide> _slides = const [
    _Slide(
      image: 'assets/welcome2.png',
      icon: Icons.home_work_outlined,
      title: 'Find Your Perfect Property',
      subtitle:
          'Browse houses, apartments, land and more across Uganda — curated '
          'listings that match your budget and lifestyle.',
    ),
    _Slide(
      image: 'assets/info2.jpg',
      icon: Icons.ondemand_video_outlined,
      title: 'Take Virtual Video Tours',
      subtitle:
          'Walk through your next home with real video tours before you ever '
          'set foot on the ground.',
    ),
    _Slide(
      image: 'assets/map2.jpg',
      icon: Icons.verified_user_outlined,
      title: 'Book Securely & Instantly',
      subtitle:
          'Reserve your favourite property with a simple booking fee — no '
          'paper work, no hassle, just peace of mind.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    userID = database.get('userID');
  }

  Future<void> _getStarted() async {
    if (_starting) return;
    setState(() => _starting = true);

    // Customers are anonymous: ensure a tracking session exists, then go home.
    await ApiService().ensureCustomerSession();

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => BottomNavBar()),
    );
  }

  void _goToPage(int page) {
    _ctrl.animateToPage(
      page,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final onSurface = context.appOnSurface;

    return Scaffold(
      body: ThemedPageBackground(
        lightOverlay: true,
        child: SafeArea(
          child: Column(
            children: [
              // Branding + Skip
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(5),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/midLOGO.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'ZCanopy',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    if (!isLastPage)
                      TextButton(
                        onPressed: _starting ? null : _getStarted,
                        child: Text(
                          'Skip',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : _brown,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Slides
              Expanded(
                child: PageView.builder(
                  controller: _ctrl,
                  itemCount: _slides.length,
                  onPageChanged: (index) {
                    setState(() => isLastPage = index == _slides.length - 1);
                  },
                  itemBuilder: (context, index) =>
                      _SlideView(slide: _slides[index]),
                ),
              ),

              // Indicator + CTA
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SmoothPageIndicator(
                      controller: _ctrl,
                      count: _slides.length,
                      effect: WormEffect(
                        dotHeight: 9,
                        dotWidth: 9,
                        spacing: 10,
                        activeDotColor: _brown,
                        dotColor: isDark
                            ? Colors.white38
                            : const Color(0xFFB8975E),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: 300,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _brown,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shadowColor: Colors.black.withValues(alpha: 0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                        ),
                        onPressed: _starting
                            ? null
                            : () {
                                if (isLastPage) {
                                  _getStarted();
                                } else {
                                  _goToPage(
                                      (_ctrl.page?.round() ?? 0) + 1);
                                }
                              },
                        child: _starting
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    isLastPage ? 'Get Started' : 'Next',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    isLastPage
                                        ? Icons.arrow_forward_rounded
                                        : Icons.arrow_forward,
                                    size: 20,
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${userID == null ? 'New' : 'Welcome back'} to ZCanopy',
                      style: TextStyle(
                        fontSize: 12,
                        color: onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Slide {
  final String image;
  final IconData icon;
  final String title;
  final String subtitle;

  const _Slide({
    required this.image,
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

class _SlideView extends StatelessWidget {
  final _Slide slide;

  const _SlideView({required this.slide});

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(32);
    final onSurface = context.appOnSurface;
    final muted = context.appMutedTextColor;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
      child: Column(
        children: [
          // Illustration
          Expanded(
            child: ClipRRect(
              borderRadius: borderRadius,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    slide.image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: const Color(0xFFB8975E).withValues(alpha: 0.25),
                      child: Icon(
                        slide.icon,
                        size: 72,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.05),
                          const Color(0xFF6B4A1F).withValues(alpha: 0.45),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(slide.icon,
                          color: const Color.fromARGB(255, 169, 97, 14),
                          size: 24),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.2,
              color: onSurface,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            slide.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: muted,
            ),
          ),
        ],
      ),
    );
  }
}