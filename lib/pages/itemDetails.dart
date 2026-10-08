import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:zcanopy/pages/brokerCollection.dart';
import 'package:zcanopy/pages/login.dart';
import 'package:zcanopy/services/gateway_api.dart';
import 'package:zcanopy/utils/property_normalizer.dart';
import 'package:zcanopy/utils/currency.dart';
import 'package:zcanopy/utils/theme_extensions.dart';
import 'package:zcanopy/widgets/payment_sheet.dart';
import 'package:zcanopy/widgets/property_listing_card.dart';
import 'package:zcanopy/widgets/video_tour_player.dart';

const _primary = Color(0xFFA9710E);

enum _MediaType { image, video }

class _Media {
  final _MediaType type;
  final String url;
  final int variant;

  const _Media.image(this.url, this.variant) : type = _MediaType.image;
  const _Media.video(this.url, this.variant) : type = _MediaType.video;
}

class _Variant {
  final String name;
  final dynamic price;
  final List<String> images;
  final String? video;
  final String description;
  final String beds;
  final String baths;
  final String area;

  const _Variant({
    required this.name,
    required this.price,
    required this.images,
    this.video,
    this.description = '',
    this.beds = '2',
    this.baths = '2',
    this.area = '—',
  });
}

List<String> _imagesFrom(Map<String, dynamic> m) {
  final raw = m['images'];
  if (raw is List) {
    return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
  }
  final single = m['image'];
  if (single != null && single.toString().isNotEmpty) {
    return [single.toString()];
  }
  return const [];
}

String? _videoFrom(Map<String, dynamic> m) {
  final v = m['video'];
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

_Variant _variantFrom(Map<String, dynamic> m,
    {required Map<String, dynamic> parent, required int index}) {
  final name = (m['name'] ?? m['unit'] ?? m['subTitle'] ?? 'Standard')
      .toString()
      .trim();
  var beds = (m['beds'] ?? m['bedrooms']).toString();
  var baths = (m['baths'] ?? m['bathrooms']).toString();
  var area = (m['area'] ?? m['size'] ?? m['sqft']).toString();
  if (beds.isEmpty || beds == 'null') beds = '2';
  if (baths.isEmpty || baths == 'null') baths = '2';
  if (area.isEmpty || area == 'null') area = '—';

  final images = _imagesFrom(m);
  final video = _videoFrom(m) ?? _videoFrom(parent);
  final desc =
      (m['description'] ?? parent['description'] ?? '').toString().trim();

  return _Variant(
    name: name,
    price: m['price'] ?? parent['price'],
    images: images.isNotEmpty ? images : _imagesFrom(parent),
    video: video,
    description: desc,
    beds: beds,
    baths: baths,
    area: area,
  );
}

List<_Variant> _buildVariants(Map<String, dynamic> p) {
  final raw = p['variants'];
  if (raw is List && raw.isNotEmpty) {
    final list = raw.whereType<Map>();
    final variants = <_Variant>[];
    for (var i = 0; i < list.length; i++) {
      variants.add(_variantFrom(
        Map<String, dynamic>.from(list.elementAt(i)),
        parent: p,
        index: i,
      ));
    }
    if (variants.isNotEmpty) return variants;
  }
  final v = _variantFrom(p, parent: p, index: 0);
  return [v];
}

class PropertyDetailsPage extends StatefulWidget {
  final String itemID;
  final Map<String, dynamic>? property;
  final String? brokerCode;
  final String? brokerName;
  final String? brokerPhone;
  final num? brokerRating;
  final bool revealContact;

  const PropertyDetailsPage({
    super.key,
    this.itemID = '',
    this.property,
    this.brokerCode,
    this.brokerName,
    this.brokerPhone,
    this.brokerRating,
    this.revealContact = false,
  });

  @override
  State<PropertyDetailsPage> createState() => _PropertyDetailsPageState();
}

class _PropData {
  final String id;
  final String title;
  final String type;
  final String location;
  final String status;
  final String description;
  final dynamic price;
  final num? rating;
  final int ratingCount;
  final LatLng? mapLocation;
  final List<Map<String, dynamic>> extraFeatures;
  final List<_Variant> variants;
  final List<_Media> media;
  final String brokerCode;
  final String brokerName;
  final String brokerPhone;
  final num? brokerRating;
  final num bookingFee;

  const _PropData({
    required this.id,
    required this.title,
    required this.type,
    required this.location,
    required this.status,
    required this.description,
    required this.price,
    required this.rating,
    required this.ratingCount,
    required this.mapLocation,
    required this.extraFeatures,
    required this.variants,
    required this.media,
    required this.brokerCode,
    required this.brokerName,
    required this.brokerPhone,
    required this.brokerRating,
    required this.bookingFee,
  });

  factory _PropData.fromMap(Map<String, dynamic> p,
      {required PropertyDetailsPage widget}) {
    final variants = _buildVariants(p);
    final media = <_Media>[];
    for (var i = 0; i < variants.length; i++) {
      final v = variants[i];
      for (final img in v.images) {
        media.add(_Media.image(img, i));
      }
      if (v.video != null) {
        media.add(_Media.video(v.video!, i));
      }
    }
    if (media.isEmpty) {
      media.add(const _Media.image('', 0));
    }

    final extraRaw = p['extraFeatures'];
    final extra = extraRaw is List
        ? extraRaw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[];

    final ml = p['mapLocation'];
    LatLng? mapLoc;
    if (ml is Map) {
      final lat = double.tryParse(ml['lat']?.toString() ?? '');
      final lng = double.tryParse(ml['lng']?.toString() ?? '');
      if (lat != null && lng != null) mapLoc = LatLng(lat, lng);
    }

    final rating = p['rating'] ?? p['averageRating'];
    final ratingCount = p['ratingCount'] ?? p['totalRatings'];
    final brokerRating = p['brokerRating'] ?? widget.brokerRating;

    return _PropData(
      id: (p['id'] ?? p['itemID'] ?? widget.itemID).toString(),
      title:
          (p['name'] ?? p['propertyTitle'] ?? p['title'] ?? 'Property').toString(),
      type: (p['type'] ?? 'Apartment').toString(),
      location: (p['location'] ?? p['area'] ?? '').toString(),
      status: (p['status'] ?? 'Available').toString(),
      description:
          (p['description'] ?? p['about'] ?? 'No description provided.').toString(),
      price: p['price'],
      rating: rating is num ? rating.toDouble() : null,
      ratingCount: ratingCount is num ? ratingCount.round() : 0,
      mapLocation: mapLoc,
      extraFeatures: extra,
      variants: variants,
      media: media,
      brokerCode: (p['brokerCode'] ?? widget.brokerCode ?? '').toString(),
      brokerName: (p['brokerName'] ?? widget.brokerName ?? 'Broker').toString(),
      brokerPhone:
          (p['brokerPhone'] ?? widget.brokerPhone ?? '+256700000000').toString(),
      brokerRating: brokerRating is num ? brokerRating.toDouble() : null,
      bookingFee: num.tryParse(p['brokerBookingFee']?.toString() ?? '') ??
          20000,
    );
  }
}

class _PropertyDetailsPageState extends State<PropertyDetailsPage> {
  final database = Hive.box('myStore');
  final PageController _pageController = PageController();

  _PropData? _model;
  bool _loading = true;
  bool _loadFailed = false;
  int _heroPage = 0;
  int _activeVariant = 0;
  bool _revealContact = false;
  bool _isFavorited = false;

  @override
  void initState() {
    super.initState();
    _revealContact = widget.revealContact;
    _isFavorited = _isSaved(widget.itemID);
    final prop = widget.property;
    if (prop != null) {
      _model = _PropData.fromMap(prop, widget: widget);
      _loading = false;
    } else {
      _fetchRemote();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  _Variant get _variant => _model!.variants[_activeVariant];

  bool _isSaved(String id) {
    final list = database.get('savedProperties');
    return list is List && list.contains(id);
  }

  void _toggleSave() {
    final id = _model!.id;
    final List<String> list =
        List<String>.from(database.get('savedProperties') ?? []);
    if (list.contains(id)) {
      list.remove(id);
    } else {
      list.add(id);
    }
    setState(() => _isFavorited = !_isFavorited);
    database.put('savedProperties', list);

    final model = _model;
    if (model != null) {
      GatewayApi()
          .toggleFavorite(
            propertyId: model.id,
            propertyTitle: model.title,
            propertyLocation: model.location,
            brokerCode: model.brokerCode,
            imageUrl: model.media.isNotEmpty &&
                    model.media.first.type == _MediaType.image
                ? model.media.first.url
                : '',
            price: model.price is num ? model.price as num : 0,
          )
          .catchError((_) => <String, dynamic>{});
    }
  }

  Future<void> _fetchRemote() async {
    try {
      final data = await GatewayApi().getPropertyDetails(
        propertyId: widget.itemID,
      );
      if (data.isNotEmpty && data['id'] != null && mounted) {
        setState(() {
          _model = _PropData.fromMap(normalizeProperty(data), widget: widget);
          _loading = false;
          _loadFailed = false;
        });
        return;
      }
      if (mounted) {
        setState(() {
          _loading = false;
          _loadFailed = true;
        });
      }
    } catch (e) {
      print('Fetch property details error: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _loadFailed = true;
        });
      }
    }
  }

  void _selectVariant(int index) {
    setState(() => _activeVariant = index);
    final firstIndex = _model!.media.indexWhere((m) => m.variant == index);
    if (firstIndex >= 0) {
      _pageController.jumpToPage(firstIndex);
      setState(() => _heroPage = firstIndex);
    }
  }

  void _openViewer(int index) {
    final model = _model!;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _MediaViewerPage(media: model.media, initial: index),
      ),
    );
  }

  Future<void> _shareProperty() async {
    final model = _model!;
    final v = _variant;
    await Share.share(
      '${model.title}\n'
      '${formatUgx(v.price)}${model.location.isNotEmpty ? ' · ${model.location}' : ''}\n'
      'Check out this property on ZCanopy.',
    );
  }

  void _openBrokerPage() {
    final model = _model!;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BrokerCollectionPage(
          brokerCode: model.brokerCode,
          brokerName: model.brokerName,
          brokerPhone: model.brokerPhone,
          brokerRating: model.brokerRating,
        ),
      ),
    );
  }

  void _openInMaps() async {
    final loc = _model!.mapLocation;
    final uri = loc != null
        ? Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=${loc.latitude},${loc.longitude}')
        : Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(_model!.location)}');
    await _tryLaunch(uri);
  }

  void _launchWhatsApp() async {
    final num = _model!.brokerPhone.replaceAll(RegExp(r'[^0-9+]'), '');
    await _tryLaunch(Uri.parse('https://wa.me/$num'));
  }

  void _callBroker() async {
    await _tryLaunch(Uri.parse('tel:${_model!.brokerPhone}'));
  }

  Future<void> _tryLaunch(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  bool get _isLoggedIn {
    final phone = database.get('phoneNumber')?.toString() ?? '';
    return phone.isNotEmpty &&
        phone != 'none' &&
        phone != 'unavailable';
  }

  Future<void> _openPaymentDialog() async {
    if (!_isLoggedIn) {
      if (!mounted) return;
      final loggedIn = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
      if (loggedIn != true || !mounted) return;
    }
    final model = _model!;
    final v = _variant;
    final property = <String, dynamic>{
      'name': model.title,
      'type': model.type,
      'location': model.location,
      'price': v.price ?? model.price,
      'bookingFee': model.bookingFee,
      'description':
          v.description.isNotEmpty ? v.description : model.description,
      'brokerName': model.brokerName,
    };
    await PaymentSheet.show(
      context,
      property: property,
      onSubmit: ({
        required String phone,
        required String email,
        required String amount,
      }) async {
        try {
          final result = await GatewayApi().initiatePropertyAccessPayment(
            propertyId: model.id,
            customerPhone: phone,
            customerEmail: email,
            amount: model.bookingFee,
            reason: 'property_access',
          );
          final code = result['bookingCode'] ??
              result['booking_code'] ??
              result['accessCode'];
          if (!mounted) return;
          setState(() => _revealContact = true);
          if (code != null && code.toString().isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Booking requested. Code: $code'),
                duration: const Duration(seconds: 6),
              ),
            );
          }
        } on ApiException catch (e) {
          print('Booking request error: ${e.message}');
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message)),
          );
        } catch (e) {
          print('Booking request error: $e');
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Booking failed. Please try again.')),
          );
        }
      },
    );
  }

  List<_Feature> _buildFeatures(_PropData model, _Variant v) {
    return [
      _Feature(Icons.home_outlined, model.type),
      _Feature(Icons.bed_outlined, '${v.beds} Beds'),
      _Feature(Icons.bathtub_outlined, '${v.baths} Bath'),
      _Feature(Icons.square_foot_outlined, v.area),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: _DetailsLoader());
    }
    if (_model == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined,
                    size: 48, color: Colors.grey),
                const SizedBox(height: 12),
                Text(_loadFailed
                    ? 'Could not load this property.'
                    : 'Property not found.'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _loading = true;
                      _loadFailed = false;
                    });
                    _fetchRemote();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final model = _model!;
    final v = _variant;

    return Scaffold(
      backgroundColor: context.appScaffoldColor,
      body: CustomScrollView(
        slivers: [
          _HeroSliver(
            media: model.media,
            controller: _pageController,
            activePage: _heroPage,
            onPageChanged: (i) => setState(() => _heroPage = i),
            onOpenAt: _openViewer,
            onShare: _shareProperty,
          ),
          SliverToBoxAdapter(
            child: _TitleCard(
              model: model,
              price: formatUgx(v.price),
              isFavorited: _isFavorited,
              onFavorite: _toggleSave,
              onShare: _shareProperty,
              onVariantSelected:
                  model.variants.length > 1 ? _selectVariant : null,
              activeVariant: _activeVariant,
            ),
          ),
          SliverToBoxAdapter(child: _FeatureStrip(features: _buildFeatures(model, v))),
          SliverToBoxAdapter(
            child: _MediaStrip(
              media: model.media,
              active: _heroPage,
              onOpenAt: _openViewer,
            ),
          ),
          SliverToBoxAdapter(
            child: _DescriptionCard(
              description:
                  v.description.isNotEmpty ? v.description : model.description,
            ),
          ),
          SliverToBoxAdapter(
            child: _LocationCard(model: model, revealContact: _revealContact, onOpenMaps: _openInMaps),
          ),
          SliverToBoxAdapter(
            child: _BrokerCard(
              model: model,
              onTap: _openBrokerPage,
              onWhatsApp: _launchWhatsApp,
              onCall: _callBroker,
              revealContact: _revealContact,
            ),
          ),
          if (model.id.isNotEmpty)
            SliverToBoxAdapter(child: _ReviewsCard(propertyId: model.id)),
          SliverToBoxAdapter(
            child: _SimilarProperties(
              currentId: model.id,
              currentType: model.type,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
      bottomNavigationBar: _BookingBar(
        amount: formatUgx(model.bookingFee),
        note: 'Property price: ${formatUgx(v.price ?? model.price)}',
        onBook: _openPaymentDialog,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero gallery inside a pinned SliverAppBar
// ---------------------------------------------------------------------------

class _HeroSliver extends StatelessWidget {
  final List<_Media> media;
  final PageController controller;
  final int activePage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onOpenAt;
  final VoidCallback onShare;

  const _HeroSliver({
    required this.media,
    required this.controller,
    required this.activePage,
    required this.onPageChanged,
    required this.onOpenAt,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final count = media.length;
    return SliverAppBar(
      pinned: true,
      expandedHeight: 300,
      backgroundColor: context.appCardColor,
      leading: _RoundBackButton(),
      actions: [
        _RoundIconButton(
          icon: Icons.ios_share_outlined,
          onTap: onShare,
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: GestureDetector(
          onTap: () => onOpenAt(activePage),
          child: Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                controller: controller,
                itemCount: count,
                onPageChanged: onPageChanged,
                itemBuilder: (context, i) {
                  final m = media[i];
                  return m.type == _MediaType.image
                      ? _HeroImageSlide(url: m.url)
                      : _VideoCoverSlide(url: m.url);
                },
              ),
              const _HeroGradientOverlay(),
              Positioned(
                bottom: 12,
                right: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$activePage/$count',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
              if (count > 1)
                Positioned(
                  top: 12,
                  left: 12,
                  child: IgnorePointer(
                    child: Row(
                      children: [
                        for (var i = 0; i < count && i < 6; i++)
                          Container(
                            width: 20,
                            height: 3,
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                              color: i == activePage
                                  ? _primary
                                  : Colors.white.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroImageSlide extends StatelessWidget {
  final String url;
  const _HeroImageSlide({required this.url});

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const _MediaPlaceholder();
      },
      errorBuilder: (_, __, ___) =>
          const _MediaPlaceholder(icon: Icons.image_not_supported_outlined),
    );
  }
}

class _VideoCoverSlide extends StatelessWidget {
  final String url;
  const _VideoCoverSlide({required this.url});

  @override
  Widget build(BuildContext context) {
    return const _MediaPlaceholder(
      icon: Icons.play_circle_fill,
      showSpinner: false,
      backgroundColorOverride: Color(0xFF141414),
    );
  }
}

class _HeroGradientOverlay extends StatelessWidget {
  const _HeroGradientOverlay();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black26,
            Colors.transparent,
            Colors.black38,
          ],
        ),
      ),
    );
  }
}

class _MediaPlaceholder extends StatelessWidget {
  final IconData icon;
  final bool showSpinner;
  final Color? backgroundColorOverride;

  const _MediaPlaceholder({
    this.icon = Icons.apartment_outlined,
    this.showSpinner = true,
    this.backgroundColorOverride,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: backgroundColorOverride != null
              ? [backgroundColorOverride!, backgroundColorOverride!]
              : const [Color(0xFF3E2A14), Color(0xFF6B4A1F)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white38, size: 46),
            if (showSpinner) ...[
              const SizedBox(height: 10),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: _primary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RoundBackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Material(
          color: Colors.black.withValues(alpha: 0.35),
          shape: const CircleBorder(),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
            onPressed: () => Navigator.maybePop(context),
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Material(
        color: Colors.black.withValues(alpha: 0.35),
        shape: const CircleBorder(),
        child: IconButton(
          icon: Icon(icon, color: Colors.white, size: 22),
          onPressed: onTap,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Title card
// ---------------------------------------------------------------------------

class _TitleCard extends StatelessWidget {
  final _PropData model;
  final String price;
  final bool isFavorited;
  final VoidCallback onFavorite;
  final VoidCallback onShare;
  final ValueChanged<int>? onVariantSelected;
  final int activeVariant;

  const _TitleCard({
    required this.model,
    required this.price,
    required this.isFavorited,
    required this.onFavorite,
    required this.onShare,
    this.onVariantSelected,
    required this.activeVariant,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final card = context.appCardColor;
    final muted = context.appMutedTextColor;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: isDark ? Border.all(color: Colors.white12) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  model.title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              IconButton(
                onPressed: onShare,
                icon: Icon(Icons.ios_share, color: muted),
              ),
              IconButton(
                onPressed: onFavorite,
                icon: Icon(
                  isFavorited ? Icons.favorite : Icons.favorite_border,
                  color: isFavorited ? Colors.redAccent : muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _StatusBadge(status: model.status),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  model.location.isEmpty ? 'Location on request' : model.location,
                  style: TextStyle(color: muted, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price,
                style: const TextStyle(
                  color: _primary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  'per booking',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
              ),
            ],
          ),
          if (model.rating != null) ...[
            const SizedBox(height: 10),
            _RatingRow(
              rating: model.rating!.toDouble(),
              count: model.ratingCount,
              textColor: muted,
            ),
          ],
          if (onVariantSelected != null) ...[
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < model.variants.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _VariantChip(
                        label: model.variants[i].name,
                        price: formatUgx(model.variants[i].price),
                        active: i == activeVariant,
                        onTap: () => onVariantSelected!(i),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final available = !status.toLowerCase().contains('book');
    final color = available ? const Color(0xFF1B9E48) : Colors.orange.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 7, color: color),
          const SizedBox(width: 5),
          Text(
            status,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _VariantChip extends StatelessWidget {
  final String label;
  final String price;
  final bool active;
  final VoidCallback onTap;

  const _VariantChip({
    required this.label,
    required this.price,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? _primary : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? _primary : Colors.grey.shade400,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: active ? Colors.white : context.appOnSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                price,
                style: TextStyle(
                  color: active
                      ? Colors.white70
                      : context.appMutedTextColor,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RatingRow extends StatelessWidget {
  final double rating;
  final int count;
  final Color textColor;

  const _RatingRow({
    required this.rating,
    required this.count,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.star_rate_rounded, color: Colors.amber, size: 18),
        const SizedBox(width: 4),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(
            color: textColor,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (count > 0) ...[
          const SizedBox(width: 6),
          Text(
            '($count)',
            style: TextStyle(color: textColor, fontSize: 12),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Feature strip
// ---------------------------------------------------------------------------

class _Feature {
  final IconData icon;
  final String label;
  const _Feature(this.icon, this.label);
}

class _FeatureStrip extends StatelessWidget {
  final List<_Feature> features;
  const _FeatureStrip({required this.features});

  @override
  Widget build(BuildContext context) {
    final muted = context.appMutedTextColor;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final f in features) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: context.appCardColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(f.icon, color: _primary, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      f.label,
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Thumbnail strip
// ---------------------------------------------------------------------------

class _MediaStrip extends StatelessWidget {
  final List<_Media> media;
  final int active;
  final ValueChanged<int> onOpenAt;

  const _MediaStrip({
    required this.media,
    required this.active,
    required this.onOpenAt,
  });

  @override
  Widget build(BuildContext context) {
    if (media.length <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Photos & Videos',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.appOnSurface,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => onOpenAt(active),
                style: TextButton.styleFrom(
                  foregroundColor: _primary,
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.fullscreen, size: 16),
                label: const Text('View all'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: media.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final m = media[i];
                final isActive = i == active;
                return GestureDetector(
                  onTap: () => onOpenAt(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 112,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isActive ? _primary : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: m.type == _MediaType.image
                          ? _ThumbImage(url: m.url)
                          : const _MediaPlaceholder(
                              icon: Icons.play_circle_fill,
                              showSpinner: false,
                              backgroundColorOverride: Color(0xFF141414),
                            ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ThumbImage extends StatelessWidget {
  final String url;
  const _ThumbImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          url,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const _MediaPlaceholder();
          },
          errorBuilder: (_, __, ___) =>
              const _MediaPlaceholder(icon: Icons.image_not_supported_outlined),
        ),
        if ((context.appCardColor.computeLuminance() > 0.5))
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.35),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Description card
// ---------------------------------------------------------------------------

class _DescriptionCard extends StatelessWidget {
  final String description;
  const _DescriptionCard({required this.description});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'About this property',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: context.appOnSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: context.appMutedTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appCardColor,
        borderRadius: BorderRadius.circular(16),
        border: isDark ? Border.all(color: Colors.white12) : null,
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// Location
// ---------------------------------------------------------------------------

class _LocationCard extends StatelessWidget {
  final _PropData model;
  final bool revealContact;
  final VoidCallback onOpenMaps;

  const _LocationCard({
    required this.model,
    required this.revealContact,
    required this.onOpenMaps,
  });

  @override
  Widget build(BuildContext context) {
    final muted = context.appMutedTextColor;
    final locked = !revealContact || model.mapLocation == null;
    final subtitle =
        'The exact location is revealed after you book.'; // can't be const, used conditionally

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Location',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: context.appOnSurface,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.place_outlined, color: _primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    model.location.isEmpty ? 'Location on request' : model.location,
                    style: TextStyle(color: muted, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (locked)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.appMutedTextColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_outline, color: muted, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        subtitle,
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                height: 160,
                width: double.infinity,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: model.mapLocation!,
                    zoom: 14,
                  ),
                  markers: {marker(model.mapLocation!)},
                  myLocationEnabled: false,
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onOpenMaps,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primary,
                  side: const BorderSide(color: _primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.navigation_outlined, size: 18),
                label: const Text('Open in Google Maps'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Marker marker(LatLng pos) {
    return Marker(
      markerId: const MarkerId('property'),
      position: pos,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
    );
  }
}

// ---------------------------------------------------------------------------
// Broker card
// ---------------------------------------------------------------------------

class _BrokerCard extends StatelessWidget {
  final _PropData model;
  final VoidCallback onTap;
  final VoidCallback onWhatsApp;
  final VoidCallback onCall;
  final bool revealContact;

  const _BrokerCard({
    required this.model,
    required this.onTap,
    required this.onWhatsApp,
    required this.onCall,
    required this.revealContact,
  });

  String get _initials {
    final parts = model.brokerName.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
    }
    return model.brokerName.isNotEmpty
        ? model.brokerName[0].toUpperCase()
        : 'B';
  }

  @override
  Widget build(BuildContext context) {
    final muted = context.appMutedTextColor;
    final isDark = context.isDarkMode;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: _primary,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        model.brokerName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.verified,
                              color: Color(0xFF1B9E48), size: 14),
                          const SizedBox(width: 4),
                          Text(
                            'Verified broker',
                            style: TextStyle(color: muted, fontSize: 12),
                          ),
                          if (model.brokerRating != null) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.star_rate_rounded,
                                color: Colors.amber, size: 15),
                            Text(
                              model.brokerRating!.toStringAsFixed(1),
                              style:
                                  TextStyle(color: muted, fontSize: 12),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onWhatsApp,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF128C7E),
                      side: const BorderSide(color: Color(0xFF128C7E)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.chat_outlined, size: 18),
                    label: const Text('WhatsApp'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onCall,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _primary,
                      side: const BorderSide(color: _primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.phone_outlined, size: 18),
                    label: const Text('Call'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: onTap,
                style: TextButton.styleFrom(foregroundColor: _primary),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('View profile & listings'),
                    SizedBox(width: 4),
                    Icon(Icons.chevron_right, size: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reviews
// ---------------------------------------------------------------------------

class _ReviewsCard extends StatefulWidget {
  final String propertyId;
  const _ReviewsCard({required this.propertyId});

  @override
  State<_ReviewsCard> createState() => _ReviewsCardState();
}

class _ReviewsCardState extends State<_ReviewsCard> {
  List<Map<String, dynamic>> _comments = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    try {
      final data = await GatewayApi()
          .getPropertyComments(propertyId: widget.propertyId);
      final list = data['comments'] ?? data['data'] ?? [];
      if (list is List && mounted) {
        setState(() {
          _comments = list
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          _loaded = true;
        });
      } else if (mounted) {
        setState(() => _loaded = true);
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  void _openAll() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _AllReviewsPage(comments: _comments),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final muted = context.appMutedTextColor;
    final shown = _comments.take(5).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Reviews & Comments',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.appOnSurface,
                    ),
                  ),
                ),
                if (_comments.length > 5)
                  TextButton.icon(
                    onPressed: _openAll,
                    style: TextButton.styleFrom(foregroundColor: _primary),
                    icon: const Icon(Icons.chevron_right, size: 16),
                    label: const Text('View all'),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (!_loaded)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: _primary),
                  ),
                ),
              )
            else if (shown.isEmpty)
              Text(
                'No comments yet. Be the first to review this property.',
                style: TextStyle(color: muted, fontSize: 12),
              )
            else
              for (final c in shown) _CommentTile(comment: c),
          ],
        ),
      ),
    );
  }
}

class _AllReviewsPage extends StatelessWidget {
  final List<Map<String, dynamic>> comments;
  const _AllReviewsPage({required this.comments});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Reviews'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: comments.length,
        separatorBuilder: (_, __) => const Divider(height: 24),
        itemBuilder: (context, i) => _CommentTile(comment: comments[i]),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final Map<String, dynamic> comment;
  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    final name = (comment['customerName'] ?? comment['name'] ?? 'Customer')
        .toString();
    final text = (comment['comment'] ?? comment['text'] ?? '').toString();
    final rating = comment['rating'];
    final muted = context.appMutedTextColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              name.isEmpty ? '?' : name[0].toUpperCase(),
              style: const TextStyle(
                  color: _primary, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (rating is num)
                      Row(
                        children: [
                          const Icon(Icons.star_rate_rounded,
                              color: Colors.amber, size: 14),
                          Text(
                            rating.toStringAsFixed(1),
                            style:
                                TextStyle(color: muted, fontSize: 11),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: TextStyle(fontSize: 12, color: muted, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Booking bar
// ---------------------------------------------------------------------------

class _BookingBar extends StatelessWidget {
  final String amount;
  final String? note;
  final VoidCallback onBook;

  const _BookingBar({required this.amount, this.note, required this.onBook});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    return Material(
      color: context.appCardColor,
      elevation: 12,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          decoration: BoxDecoration(
            border: isDark ? Border.all(color: Colors.white12) : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Booking fee',
                      style: TextStyle(
                          fontSize: 11, color: context.appMutedTextColor),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      amount,
                      style: const TextStyle(
                        color: _primary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (note != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(
                          note!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 10, color: context.appMutedTextColor),
                        ),
                      ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: onBook,
                style: FilledButton.styleFrom(
                  backgroundColor: _primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
                icon: const Icon(Icons.calendar_today, size: 16),
                label: const Text(
                  'Book tour',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Similar properties
// ---------------------------------------------------------------------------

class _SimilarProperties extends StatefulWidget {
  final String currentId;
  final String currentType;

  const _SimilarProperties({
    required this.currentId,
    required this.currentType,
  });

  @override
  State<_SimilarProperties> createState() => _SimilarPropertiesState();
}

class _SimilarPropertiesState extends State<_SimilarProperties> {
  List<Map<String, dynamic>> _similar = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await GatewayApi().searchProperties(
        query: '',
        page: 1,
        limit: 12,
      );
      final raw = res['properties'];
      final list = raw is List
          ? raw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .where((p) => p['id']?.toString() != widget.currentId)
              .toList()
          : <Map<String, dynamic>>[];
      final current = widget.currentType.toLowerCase();
      final same = list
          .where((p) => p['type']?.toString().toLowerCase() == current)
          .toList();
      final others = list.where((p) => !same.contains(p)).toList();
      if (mounted) {
        setState(() {
          _similar = (same + others).take(6).toList();
        });
      }
    } catch (e) {
      debugPrint('Similar properties fetch failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final similar = _similar;
    if (similar.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Similar Properties',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: context.appOnSurface,
            ),
          ),
          const SizedBox(height: 12),
          for (final property in similar)
            PropertyListingCard(
              property: property,
              onOpen: () => _openDetails(context, property),
              onPlayVideo: () => _openVideoTour(context, property),
            ),
        ],
      ),
    );
  }

  void _openDetails(BuildContext context, Map<String, dynamic> property) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PropertyDetailsPage(property: property),
      ),
    );
  }

  void _openVideoTour(
      BuildContext context, Map<String, dynamic> property) {
    if (property['video'] == null ||
        property['video'].toString().isEmpty) {
      _openDetails(context, property);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoTourPlayer(property: property),
      ),
    );
  }

}

// ---------------------------------------------------------------------------
// Full-screen media viewer
// ---------------------------------------------------------------------------

class _MediaViewerPage extends StatefulWidget {
  final List<_Media> media;
  final int initial;

  const _MediaViewerPage({required this.media, required this.initial});

  @override
  State<_MediaViewerPage> createState() => _MediaViewerPageState();
}

class _MediaViewerPageState extends State<_MediaViewerPage> {
  late final PageController _controller;
  late int _page;

  @override
  void initState() {
    super.initState();
    _page = widget.initial;
    _controller = PageController(initialPage: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${_page + 1} / ${widget.media.length}',
          style: const TextStyle(fontSize: 14),
        ),
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.media.length,
        onPageChanged: (i) => setState(() => _page = i),
        itemBuilder: (context, i) {
          final m = widget.media[i];
          return m.type == _MediaType.image
              ? _ViewerImage(url: m.url)
              : _ViewerVideo(url: m.url);
        },
      ),
    );
  }
}

class _ViewerImage extends StatelessWidget {
  final String url;
  const _ViewerImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      maxScale: 4,
      child: Center(
        child: Image.network(
          url,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const Center(
              child: CircularProgressIndicator(color: _primary),
            );
          },
          errorBuilder: (_, __, ___) => const Center(
            child: Icon(Icons.broken_image_outlined,
                color: Colors.white38, size: 52),
          ),
        ),
      ),
    );
  }
}

class _ViewerVideo extends StatefulWidget {
  final String url;
  const _ViewerVideo({required this.url});

  @override
  State<_ViewerVideo> createState() => _ViewerVideoState();
}

class _ViewerVideoState extends State<_ViewerVideo> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller!
        .initialize()
        .then((_) {
      if (mounted) setState(() {});
      _controller?.play();
    })
        .catchError((_) {
      if (mounted) setState(() => _failed = true);
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const Center(
        child: Icon(Icons.videocam_off_outlined,
            color: Colors.white38, size: 52),
      );
    }
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: _primary),
      );
    }
    return Center(
      child: AspectRatio(
        aspectRatio: c.value.aspectRatio,
        child: GestureDetector(
          onTap: () => c.value.isPlaying ? c.pause() : c.play(),
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(c),
              if (!c.value.isPlaying)
                const Icon(Icons.play_circle_fill,
                    color: Colors.white70, size: 64),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailsLoader extends StatelessWidget {
  const _DetailsLoader();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(color: _primary),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading property...',
            style: TextStyle(color: context.appMutedTextColor),
          ),
        ],
      ),
    );
  }
}