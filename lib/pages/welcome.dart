import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:zcanopy/pages/homeScreen.dart';
import 'package:zcanopy/pages/login.dart';
import 'package:zcanopy/services/auth_service.dart';
import 'package:zcanopy/services/gateway_api.dart';
import 'package:zcanopy/utils/onboarding_palette.dart';
import 'package:zcanopy/widgets/onboarding_kit.dart';

enum _OnboardingStep { welcome, intro, preferences, allSet }

class OnBoardingScreen extends StatefulWidget {
  const OnBoardingScreen({super.key});

  @override
  State<OnBoardingScreen> createState() => _OnBoardingScreenState();
}

class _OnBoardingScreenState extends State<OnBoardingScreen> {
  final _store = Hive.box('myStore');
  final _api = GatewayApi();

  _OnboardingStep _step = _OnboardingStep.welcome;
  String _intent = 'browse';
  Set<String> _areas = <String>{};
  bool _signedIn = false;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    final storedIntent = _store.get('onboardingIntent');
    if (storedIntent is String && storedIntent.isNotEmpty) {
      _intent = storedIntent;
    }
    final storedAreas = _store.get('onboardingAreas');
    if (storedAreas is List) {
      _areas = storedAreas
          .map((area) => area.toString())
          .where((area) => area.isNotEmpty)
          .toSet();
    }
    _signedIn = AuthService.instance.isSignedIn;
  }

  void _goTo(_OnboardingStep step) {
    setState(() => _step = step);
  }

  void _handleBack() {
    switch (_step) {
      case _OnboardingStep.welcome:
        return;
      case _OnboardingStep.intro:
        _goTo(_OnboardingStep.welcome);
      case _OnboardingStep.preferences:
        _goTo(_OnboardingStep.intro);
      case _OnboardingStep.allSet:
        _goTo(_OnboardingStep.preferences);
    }
  }

  Future<void> _openAccount({required bool signUp}) async {
    final verified = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => LoginPage(startInSignUp: signUp)),
    );
    if (!mounted || verified != true) return;
    setState(() {
      _signedIn = true;
      _step = _OnboardingStep.allSet;
    });
  }

  Future<void> _finishPreferences(String intent, Set<String> areas) async {
    setState(() {
      _intent = intent;
      _areas = areas;
      _step = _OnboardingStep.allSet;
    });
    await _store.put('onboardingIntent', intent);
    await _store.put('onboardingAreas', areas.toList());
  }

  Future<void> _enterApp() async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      await _api.ensureCustomerSession();
    } catch (_) {
      if (!mounted) return;
      setState(() => _starting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not reach the server. Try again.')),
      );
      return;
    }
    await _store.put('onboardingCompleted', true);
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const BottomNavBar()));
  }

  @override
  Widget build(BuildContext context) {
    final palette = OnboardingPalette.of(context);

    return PopScope(
      canPop: _step == _OnboardingStep.welcome,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: palette.background,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: SizedBox.expand(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    final slide = Tween<Offset>(
                      begin: const Offset(0.04, 0),
                      end: Offset.zero,
                    ).animate(animation);
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(position: slide, child: child),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey(_step),
                    child: _buildStep(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case _OnboardingStep.welcome:
        return _WelcomeStep(
          onStart: () => _goTo(_OnboardingStep.intro),
          onSignIn: () => _openAccount(signUp: false),
        );
      case _OnboardingStep.intro:
        return _IntroStep(
          onDone: () => _goTo(_OnboardingStep.preferences),
          onSkip: () => _goTo(_OnboardingStep.preferences),
          onBack: () => _goTo(_OnboardingStep.welcome),
        );
      case _OnboardingStep.preferences:
        return _PreferencesStep(
          initialIntent: _intent,
          initialAreas: _areas,
          onBack: () => _goTo(_OnboardingStep.intro),
          onSkip: () => _goTo(_OnboardingStep.allSet),
          onContinue: _finishPreferences,
        );
      case _OnboardingStep.allSet:
        return _AllSetStep(
          signedIn: _signedIn || AuthService.instance.isSignedIn,
          name: AuthService.instance.displayName,
          intent: _intent,
          areas: _areas,
          starting: _starting,
          onExplore: _enterApp,
          onCreateAccount: () => _openAccount(signUp: true),
          onSignIn: () => _openAccount(signUp: false),
        );
    }
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.onStart, required this.onSignIn});

  final VoidCallback onStart;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final palette = OnboardingPalette.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final imageHeight = (constraints.maxHeight * 0.42).clamp(220.0, 420.0);

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: OnboardingReveal(child: BrandMark()),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: imageHeight,
                child: OnboardingReveal(
                  delay: const Duration(milliseconds: 60),
                  offset: const Offset(0, 0.04),
                  child: OnboardingFloating(
                    child: OnboardingImageFrame(
                      asset: 'assets/welcome2.png',
                      borderRadius: 32,
                      topLeft: const OnboardingStatusPill(
                        icon: Icons.location_on_outlined,
                        label: 'Kampala · 4 bd',
                      ),
                      bottomRight: const OnboardingPriceTag(
                        price: 'From UGX 50M',
                        label: 'Verified listing',
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              OnboardingReveal(
                delay: const Duration(milliseconds: 120),
                child: Text(
                  'The right property,\nfound with care',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    height: 1.08,
                    letterSpacing: -0.6,
                    color: palette.ink,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              OnboardingReveal(
                delay: const Duration(milliseconds: 150),
                child: Text(
                  'Verified listings, virtual tours and agents who know every '
                  'neighbourhood — all in one place.',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: palette.muted,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              OnboardingReveal(
                delay: const Duration(milliseconds: 180),
                child: GoldButton(label: 'Get started', onPressed: onStart),
              ),
              const SizedBox(height: 6),
              OnboardingReveal(
                delay: const Duration(milliseconds: 210),
                child: GoldButton(
                  label: 'I already have an account',
                  variant: GoldButtonVariant.ghost,
                  onPressed: onSignIn,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _IntroSlide {
  const _IntroSlide({
    required this.image,
    required this.title,
    required this.body,
    required this.chip,
    required this.chipIcon,
  });

  final String image;
  final String title;
  final String body;
  final String chip;
  final IconData chipIcon;
}

const List<_IntroSlide> _introSlides = [
  _IntroSlide(
    image: 'assets/welcome2.png',
    title: 'Find homes in the\nneighbourhoods you love',
    body:
        'Filter by location, price and property type, then see new listings '
        'as they go live.',
    chip: 'Fresh listings near you',
    chipIcon: Icons.location_on_outlined,
  ),
  _IntroSlide(
    image: 'assets/info2.jpg',
    title: 'Tour from your sofa,\nvisit when it matters',
    body:
        'Walk through real video tours, then book an in-person viewing when '
        'you are ready.',
    chip: 'Virtual video tours',
    chipIcon: Icons.play_circle_outline,
  ),
  _IntroSlide(
    image: 'assets/map2.jpg',
    title: 'Book with confidence,\nevery step of the way',
    body:
        'Reserve securely with a booking fee held in escrow until you have '
        'seen the property.',
    chip: 'Escrow-protected booking',
    chipIcon: Icons.verified_user_outlined,
  ),
];

class _IntroStep extends StatefulWidget {
  const _IntroStep({
    required this.onDone,
    required this.onSkip,
    required this.onBack,
  });

  final VoidCallback onDone;
  final VoidCallback onSkip;
  final VoidCallback onBack;

  @override
  State<_IntroStep> createState() => _IntroStepState();
}

class _IntroStepState extends State<_IntroStep> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    if (index < 0) {
      widget.onBack();
      return;
    }
    if (index >= _introSlides.length) {
      widget.onDone();
      return;
    }
    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _next() => _goTo(_index + 1);

  @override
  Widget build(BuildContext context) {
    final palette = OnboardingPalette.of(context);
    final isLast = _index == _introSlides.length - 1;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: Row(
            children: [
              if (_index == 0)
                const BrandMark(small: true)
              else
                OnboardingIconButton(
                  icon: Icons.chevron_left_rounded,
                  onTap: () => _goTo(_index - 1),
                ),
              const Spacer(),
              if (!isLast)
                TextButton(
                  onPressed: widget.onSkip,
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: palette.muted,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: PageView.builder(
            controller: _controller,
            itemCount: _introSlides.length,
            onPageChanged: (index) => setState(() => _index = index),
            itemBuilder: (context, index) {
              return _IntroSlideView(slide: _introSlides[index]);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OnboardingDots(
                count: _introSlides.length,
                index: _index,
                onTap: _goTo,
              ),
              OnboardingProgressButton(
                progress: (_index + 1) / _introSlides.length,
                isLast: isLast,
                onTap: _next,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IntroSlideView extends StatelessWidget {
  const _IntroSlideView({required this.slide});

  final _IntroSlide slide;

  @override
  Widget build(BuildContext context) {
    final palette = OnboardingPalette.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: OnboardingImageFrame(
              asset: slide.image,
              borderRadius: 32,
              bottomCenter: OnboardingStatusPill(
                icon: slide.chipIcon,
                label: slide.chip,
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            slide.title,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              height: 1.1,
              letterSpacing: -0.5,
              color: palette.ink,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            slide.body,
            style: TextStyle(fontSize: 15, height: 1.5, color: palette.muted),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _PreferencesStep extends StatefulWidget {
  const _PreferencesStep({
    required this.initialIntent,
    required this.initialAreas,
    required this.onBack,
    required this.onSkip,
    required this.onContinue,
  });

  final String initialIntent;
  final Set<String> initialAreas;
  final VoidCallback onBack;
  final VoidCallback onSkip;
  final void Function(String intent, Set<String> areas) onContinue;

  @override
  State<_PreferencesStep> createState() => _PreferencesStepState();
}

class _PreferencesStepState extends State<_PreferencesStep> {
  late String _intent;
  late Set<String> _areas;

  @override
  void initState() {
    super.initState();
    _intent = _intentOptions.any((option) => option.id == widget.initialIntent)
        ? widget.initialIntent
        : 'browse';
    _areas = {...widget.initialAreas};
  }

  void _toggleArea(String area) {
    setState(() {
      if (!_areas.add(area)) _areas.remove(area);
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = OnboardingPalette.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: Row(
            children: [
              OnboardingIconButton(
                icon: Icons.chevron_left_rounded,
                onTap: widget.onBack,
              ),
              const Spacer(),
              TextButton(
                onPressed: widget.onSkip,
                child: Text(
                  'Skip',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: palette.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What brings you\nto Zcanopy?',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                    letterSpacing: -0.5,
                    color: palette.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'We’ll shape your feed around it. You can change this anytime.',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: palette.muted,
                  ),
                ),
                const SizedBox(height: 24),
                for (final option in _intentOptions) ...[
                  _IntentCard(
                    option: option,
                    selected: _intent == option.id,
                    onTap: () => setState(() => _intent = option.id),
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 12),
                Text(
                  'Neighbourhoods to watch',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: palette.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pick a few and we’ll surface new listings there.',
                  style: TextStyle(fontSize: 13, color: palette.muted),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final area in _areaOptions)
                      _AreaChip(
                        label: area,
                        selected: _areas.contains(area),
                        onTap: () => _toggleArea(area),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: GoldButton(
            label: 'Show me homes',
            onPressed: () => widget.onContinue(_intent, _areas),
          ),
        ),
      ],
    );
  }
}

class _IntentOption {
  const _IntentOption({
    required this.id,
    required this.label,
    required this.hint,
    required this.icon,
  });

  final String id;
  final String label;
  final String hint;
  final IconData icon;
}

const List<_IntentOption> _intentOptions = [
  _IntentOption(
    id: 'buy',
    label: 'Buy a home',
    hint: 'Browse homes for sale and book viewings',
    icon: Icons.home_outlined,
  ),
  _IntentOption(
    id: 'rent',
    label: 'Rent a place',
    hint: 'Find rentals that fit your move-in date',
    icon: Icons.key_outlined,
  ),
  _IntentOption(
    id: 'sell',
    label: 'Sell my property',
    hint: 'Get a free valuation from an agent',
    icon: Icons.sell_outlined,
  ),
  _IntentOption(
    id: 'browse',
    label: 'Just exploring',
    hint: 'See what is available around you',
    icon: Icons.explore_outlined,
  ),
];

const List<String> _areaOptions = [
  'Kampala',
  'Entebbe',
  'Jinja',
  'Mbarara',
  'Gulu',
  'Mbale',
  'Fort Portal',
  'Arua',
];

class _IntentCard extends StatelessWidget {
  const _IntentCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _IntentOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = OnboardingPalette.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? palette.paper : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? OnboardingPalette.gold : palette.line,
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected ? OnboardingPalette.gold : palette.champagne,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  option.icon,
                  size: 20,
                  color: selected ? palette.ink : palette.deepAccent,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: palette.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      option.hint,
                      style: TextStyle(fontSize: 13, color: palette.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: selected ? OnboardingPalette.gold : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? OnboardingPalette.gold : palette.line,
                  ),
                ),
                child: selected
                    ? Icon(Icons.check_rounded, size: 15, color: palette.ink)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AreaChip extends StatelessWidget {
  const _AreaChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = OnboardingPalette.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? palette.brandSurface : palette.paper,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? palette.brandSurface : palette.line,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                const Icon(
                  Icons.check_rounded,
                  size: 14,
                  color: OnboardingPalette.gold,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: selected ? palette.ink : palette.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AllSetStep extends StatelessWidget {
  const _AllSetStep({
    required this.signedIn,
    required this.name,
    required this.intent,
    required this.areas,
    required this.starting,
    required this.onExplore,
    required this.onCreateAccount,
    required this.onSignIn,
  });

  final bool signedIn;
  final String name;
  final String intent;
  final Set<String> areas;
  final bool starting;
  final VoidCallback onExplore;
  final VoidCallback onCreateAccount;
  final VoidCallback onSignIn;

  String get _areaSummary {
    if (areas.isEmpty) return 'new listings near you';
    final values = areas.toList();
    if (values.length == 1) return values.first;
    if (values.length == 2) return '${values[0]} & ${values[1]}';
    return '${values[0]}, ${values[1]} +${values.length - 2} more';
  }

  String get _intentLabel {
    switch (intent) {
      case 'buy':
        return 'buying';
      case 'rent':
        return 'renting';
      case 'sell':
        return 'selling';
      default:
        return 'exploring';
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = OnboardingPalette.of(context);
    final greeting = name.trim().isEmpty ? 'there' : name.trim();

    final rows = <({IconData icon, String text})>[
      (icon: Icons.tune_rounded, text: 'Feed tuned for $_intentLabel'),
      (icon: Icons.location_on_outlined, text: 'Watching $_areaSummary'),
      signedIn
          ? (
              icon: Icons.notifications_none_rounded,
              text: 'Instant alerts for new listings',
            )
          : (
              icon: Icons.favorite_border_rounded,
              text: 'Browse freely — no account needed',
            ),
      if (signedIn)
        (
          icon: Icons.bookmark_border_rounded,
          text: 'Your shortlist synced across devices',
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final imageHeight = (constraints.maxHeight * 0.4).clamp(180.0, 360.0);

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: imageHeight,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    OnboardingReveal(
                      child: OnboardingImageFrame(
                        asset: 'assets/info2.jpg',
                        borderRadius: 32,
                        imageAlignment: Alignment.center,
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: OnboardingReveal(
                        delay: const Duration(milliseconds: 220),
                        child: const OnboardingSeal(),
                      ),
                    ),
                    Positioned(
                      left: 26,
                      top: 34,
                      child: OnboardingReveal(
                        delay: const Duration(milliseconds: 300),
                        child: const OnboardingSparkle(size: 18),
                      ),
                    ),
                    Positioned(
                      right: 42,
                      bottom: 42,
                      child: OnboardingReveal(
                        delay: const Duration(milliseconds: 360),
                        child: const OnboardingSparkle(size: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              OnboardingReveal(
                delay: const Duration(milliseconds: 120),
                child: Text(
                  signedIn
                      ? 'Welcome home,\n$greeting.'
                      : 'Your feed is ready.',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                    letterSpacing: -0.5,
                    color: palette.ink,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              OnboardingReveal(
                delay: const Duration(milliseconds: 150),
                child: Text(
                  signedIn
                      ? 'Everything is saved. We’ve tuned your feed to match what '
                            'you are looking for.'
                      : 'We’ve tuned your feed to match what you are looking for. '
                            'No account needed to start.',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: palette.muted,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: palette.line),
                    bottom: BorderSide(color: palette.line),
                  ),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < rows.length; i++) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            Icon(
                              rows[i].icon,
                              size: 17,
                              color: palette.deepAccent,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                rows[i].text,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: palette.ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (i != rows.length - 1)
                        Divider(height: 1, color: palette.line),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              GoldButton(
                label: signedIn ? 'Explore homes' : 'Start browsing',
                loading: starting,
                onPressed: onExplore,
              ),
              if (!signedIn) ...[
                const SizedBox(height: 10),
                Text(
                  'Want alerts and a saved shortlist?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: palette.muted),
                ),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TextButton(
                      onPressed: onCreateAccount,
                      child: Text(
                        'Create a free account',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: palette.deepAccent,
                        ),
                      ),
                    ),
                    Text('·', style: TextStyle(color: palette.muted)),
                    TextButton(
                      onPressed: onSignIn,
                      child: Text(
                        'Sign in',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: palette.deepAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
