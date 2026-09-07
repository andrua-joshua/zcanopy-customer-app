import 'package:flutter/material.dart';
import 'package:zcanopy/pages/welcome.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:zcanopy/pages/homeScreen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:zcanopy/services/notification_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zcanopy/pages/videoWidget.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:zcanopy/pages/network.dart';
import 'package:zcanopy/pages/itemDetailsShimmer.dart';
import 'package:zcanopy/pages/session.dart';
import 'package:zcanopy/services/api_service.dart';
import 'package:zcanopy/utils/theme_extensions.dart';
import 'package:zcanopy/widgets/payment_sheet.dart';

const _primary = Color(0xFFA9610E);

class PropertyDetailsPage extends StatefulWidget {
  final String itemID;
  final String? brokerCode;
  final String? brokerName;
  final String? brokerPhone;
  final bool revealContact;

  const PropertyDetailsPage({
    super.key,
    required this.itemID,
    this.brokerCode,
    this.brokerName,
    this.brokerPhone,
    this.revealContact = false,
  });

  @override
  State<PropertyDetailsPage> createState() => _PropertyDetailsPageState();
}

class _PropertyDetailsPageState extends State<PropertyDetailsPage> {
  final database = Hive.box('myStore');

  final PageController _pageController = PageController();
  late GoogleMapController _mapController;
  Location _location = Location();
  LatLng? _currentLocation;
  LatLng? _destination;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  bool _isFavorited = false;
  String _whatsappNumber = "+256701234567";
  String _description = '';
  String _propertyType = "Apartment";
  bool _phoneNumberVisible = false;
  bool _revealContact = false;
  List<Map<String, dynamic>> _extraFeatures = [
    {"icon": Icons.local_parking, "label": "Garage"},
    {"icon": Icons.pool, "label": "Swimming Pool"},
    {"icon": Icons.weekend, "label": "Furnished"},
  ];

  bool isLoading = false;
  String propertyTitle = "MDelos apartments";
  String amount = '1,200,000';
  String _locationName = 'Kampala';
  double _priceValue = 1200000.0;
  String videoURL =
      'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4';

  List<String> _images = [
    "assets/newHomes/kampala1.jpg",
    "assets/newHomes/kampala2.jpg",
    "assets/newHomes/kampala3.jpg",
    "assets/newHomes/kampala4.jpg"
  ];

  bool isFetchingItemData = false;
  String itemID1 = '';
  List<Map<String, dynamic>> _comments = [];
  double _averageRating = 0;
  final TextEditingController _commentController = TextEditingController();
  int _commentRating = 5;
  bool _submittingComment = false;

  Future<void> _getItemDetails() async {
    if (isFetchingItemData) return;
    setState(() => isFetchingItemData = true);

    try {
      final url = Uri.parse(
          "http://127.0.0.1:4000/listings/get-item-details?item-id=${itemID1}");

      final response = await http.get(url);

      if (response.statusCode == 200) {
        var data = json.decode(response.body);

        setState(() {
          if (data.isNotEmpty) {
            _images = data['images'];
            _whatsappNumber = data['whatsappNo'];
            _propertyType = data['type'] ?? _propertyType;
            _extraFeatures = data['extraFeatures'] ?? _extraFeatures;
            if (data['location'] != null) {
              _locationName = data['location'].toString();
            }
            if (data['price'] != null) {
              _priceValue = (data['price'] is num)
                  ? (data['price'] as num).toDouble()
                  : double.tryParse(data['price'].toString()) ?? _priceValue;
              amount = _priceValue.round().toString().replaceAllMapped(
                    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                    (m) => '${m[1]},',
                  );
            }
            if (data['mapLocation'] is Map) {
              final ml = data['mapLocation'] as Map;
              final lat = double.tryParse(ml['lat']?.toString() ?? '');
              final lng = double.tryParse(ml['lng']?.toString() ?? '');
              if (lat != null && lng != null) {
                _destination = LatLng(lat, lng);
              }
            }
          }
        });
      } else {
        debugPrint("Error: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Network error: $e");
    } finally {
      setState(() => isFetchingItemData = false);
    }
  }

  Future<void> _initBookingRequest(context, email, contact) async {
    try {
      var obj = {
        "itemID": itemID1,
        "userID": database.get('userID'),
        "customerEmail": email,
        "phoneNumber": contact
      };

      final response = await postData('/book-property', obj);

      if (response.success) {
        var data = response;
        setState(() {
          if (data['status'] == 'done') {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Booking request sent successfully!"),
                duration: Duration(seconds: 3),
              ),
            );

            print("Booking request sent:");
            print("Customer Email: $email");
            print("Customer Phone: $contact");
            print("Property Owner ID: ${data['holderID']}");
          }
        });
      } else {
        debugPrint("Error: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Network error: $e");
    } finally {
      setState(() => isFetchingItemData = false);
    }
  }

  @override
  void initState() {
    super.initState();
    itemID1 = widget.itemID != null ? widget.itemID : '1234';

    if (widget.revealContact) {
      _revealContact = true;
    }

    getItemInfo();

    try {
      _getLocationUpdates();
    } catch (e) {
      print("Error initializing location updates: $e");
    }
  }

  postData(path, payload) async {
    try {
      final data = await NetworkService.post(
          'http://127.0.0.1:4000/listings${path}', payload);
      return data;
    } catch (e) {
      print(e);
    }
  }

  Future<void> forceLogout(BuildContext context) async {
    await database.clear();
    await database.clear();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const OnBoardingScreen()),
      (_) => false,
    );
  }

  Future<void> getItemInfo() async {
    final isSessionValid = await SessionService.validateSession();
    if (!isSessionValid) {
      if (mounted) {
        await forceLogout(context);
      }
    }

    setState(() {
      isLoading = true;
    });

    try {
      final data = await fetchData(database.get('userID'), widget.itemID);
      if (data != null && data.success) {
        setState(() {
          if (data.isNotEmpty) {
            _images = data['images'];
            _whatsappNumber = data['phoneNumber'];
            _propertyType = data['type'];
            _extraFeatures = data['extraFeatures'];
            propertyTitle = data['propertyTitle'];
            _description = data['description'] ?? _description;
            _description = data['description'] ?? _description;
          }
          isLoading = false;
        });
        return;
      }
    } catch (e) {
      print('Fetch error: $e');
    }

    // Fallback: populate with default data so the page renders immediately.
    if (mounted) {
      setState(() {
        _images = [
          'https://picsum.photos/400/250?1',
          'https://picsum.photos/400/250?2',
          'https://picsum.photos/400/250?3',
        ];
        _whatsappNumber = '+256701234567';
        _propertyType = 'Apartment';
        _extraFeatures = <Map<String, dynamic>>[
          {'name': 'Bedroom', 'available': true},
          {'name': 'Bathroom', 'available': true},
          {'name': 'Living Room', 'available': true},
          {'name': 'Kitchen', 'available': true},
        ];
        propertyTitle = widget.itemID;
        _description = 'Mutaasa brokers, 1 dining room, 2 toilets, spacious compound, secure gated community.';
        isLoading = false;
      });
    }
  }

  fetchData(userID, itemID) async {
    try {
      final response = await NetworkService.get(
          'http://127.0.0.1:4000/listings/get-user-properties?userID=${userID}&itemID=${itemID}');
      return response;
    } catch (e) {
      print(e);
      rethrow;
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    try {
      _mapController = controller;
    } catch (e) {
      print("Error creating map: $e");
    }
  }

  Future<void> _getLocationUpdates() async {
    try {
      bool _serviceEnabled;
      PermissionStatus _permissionGranted;

      _serviceEnabled = await _location.serviceEnabled();
      if (!_serviceEnabled) {
        _serviceEnabled = await _location.requestService();
        if (!_serviceEnabled) return;
      }

      _permissionGranted = await _location.hasPermission();
      if (_permissionGranted == PermissionStatus.denied) {
        _permissionGranted = await _location.requestPermission();
        if (_permissionGranted != PermissionStatus.granted) return;
      }

      final locData = await _location.getLocation();
      if (locData.latitude != null && locData.longitude != null) {
        _currentLocation = LatLng(locData.latitude!, locData.longitude!);
      }

      _location.onLocationChanged.listen((newLoc) {
        if (newLoc.latitude != null && newLoc.longitude != null) {
          setState(() {
            _currentLocation = LatLng(newLoc.latitude!, newLoc.longitude!);
            _markers = {
              Marker(
                markerId: MarkerId("currentLocation"),
                position: _currentLocation!,
                infoWindow: InfoWindow(title: "You are here"),
              ),
              Marker(
                markerId: MarkerId("destination"),
                position: _destination ?? const LatLng(0.3476, 32.5825),
                infoWindow: InfoWindow(title: "Destination"),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueBlue),
              ),
            };
          });
          _getDirections();
        }
      });
    } catch (e) {
      print("Error getting location updates: $e");
    }
  }

  Future<void> _getDirections() async {
    try {
      if (_currentLocation == null) return;

      final String apiKey = "AIzaSyAxwzGVIr7p9hzK4PZhJWoRKq4ggqEhZgY";
      if (apiKey == "YOUR_GOOGLE_API_KEY" || apiKey.isEmpty) {
        return;
      }

      final destLat = _destination?.latitude ?? _currentLocation?.latitude ?? 0.3476;
      final destLng = _destination?.longitude ?? _currentLocation?.longitude ?? 32.5825;
      final url =
          "https://maps.googleapis.com/maps/api/directions/json?origin=${_currentLocation!.latitude},${_currentLocation!.longitude}&destination=$destLat,$destLng&key=$apiKey";

      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);

      if (data["routes"].isNotEmpty) {
        final points = data["routes"][0]["overview_polyline"]["points"];
        final List<LatLng> polylinePoints = _decodePolyline(points);

        setState(() {
          _polylines = {
            Polyline(
              polylineId: PolylineId("route"),
              points: polylinePoints,
              color: _primary,
              width: 5,
            ),
          };
        });
      }
    } catch (e) {
      print("Error getting directions: $e");
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    try {
      List<LatLng> points = [];
      int index = 0, len = encoded.length;
      int lat = 0, lng = 0;

      while (index < len) {
        int b, shift = 0, result = 0;

        do {
          b = encoded.codeUnitAt(index++) - 63;
          result |= (b & 0x1f) << shift;
          shift += 5;
        } while (b >= 0x20);
        int dLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
        lat += dLat;

        shift = 0;
        result = 0;

        do {
          b = encoded.codeUnitAt(index++) - 63;
          result |= (b & 0x1f) << shift;
          shift += 5;
        } while (b >= 0x20);
        int dLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
        lng += dLng;

        points.add(LatLng(lat / 1E5, lng / 1E5));
      }
      return points;
    } catch (e) {
      print("Error decoding polyline: $e");
      return [];
    }
  }

  void _shareProperty() {
    final String propertyInfo =
        "Check out this property: $propertyTitle\nPrice: UGX $amount / mo";
    Share.share(propertyInfo);
  }

  /// Open the item's location in the Google Maps app (or web fallback) using a
  /// geo: / maps URI built from the property coordinates.
  Future<void> _openInMaps() async {
    final lat = _destination?.latitude ?? _currentLocation?.latitude ?? 0.3476;
    final lng = _destination?.longitude ?? _currentLocation?.longitude ?? 32.5825;
    final label = Uri.encodeComponent(propertyTitle);
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng&query_place_id=$label');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Could not open Google Maps")),
    );
  }
}

class _CommentsSection extends StatefulWidget {
  final String propertyId;

  const _CommentsSection({required this.propertyId});

  @override
  State<_CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends State<_CommentsSection> {
  List<Map<String, dynamic>> _comments = [];
  double _averageRating = 0;
  final TextEditingController _commentController = TextEditingController();
  int _commentRating = 5;
  bool _submittingComment = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    try {
      final data = await ApiService().getPropertyComments(propertyId: widget.propertyId);
      setState(() {
        _comments = List<Map<String, dynamic>>.from(data['comments'] ?? []);
        _averageRating = (data['averageRating'] ?? 0).toDouble();
      });
    } catch (e) {
      print('Load comments error: $e');
    }
  }

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty) return;
    final session = SessionManager.getSessionID();
    if (session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please login to comment")),
      );
      return;
    }

    setState(() => _submittingComment = true);
    try {
      final userId = Hive.box('myStore').get('userID')?.toString() ?? session;
      await ApiService().addComment(
        sessionToken: session,
        propertyId: widget.propertyId,
        customerName: userId,
        customerPhone: userId,
        comment: _commentController.text.trim(),
        rating: _commentRating.toDouble(),
      );
      _commentController.clear();
      await _loadComments();
    } catch (e) {
      print('Submit comment error: $e');
    } finally {
      setState(() => _submittingComment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 100),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Reviews & Comments",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              if (_averageRating > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    "Average rating: ${_averageRating.toStringAsFixed(1)} / 5",
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              const SizedBox(height: 12),
              if (_comments.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    "No comments yet. Be the first to review this property.",
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                )
              else
                ..._comments.map((c) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c['customerName'] ?? 'Anonymous',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                Text(c['comment'] ?? ''),
                                const SizedBox(height: 4),
                                Text(
                                  "Rating: ${c['rating'] ?? 0}/5",
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )),
              const SizedBox(height: 16),
              const Text(
                "Add a review",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _commentController,
                decoration: const InputDecoration(
                  hintText: "Share your experience...",
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text("Rating: "),
                  DropdownButton<int>(
                    value: _commentRating,
                    items: [5, 4, 3, 2, 1]
                        .map((r) => DropdownMenuItem(value: r, child: Text("$r")))
                        .toList(),
                    onChanged: (val) => setState(() => _commentRating = val ?? 5),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submittingComment ? null : _submitComment,
                  child: Text(_submittingComment ? "Submitting..." : "Submit Review"),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not open Google Maps")),
        );
      }
    }
  }

  Future<void> _toggleFavorite() async {
    final session = SessionManager.getSessionID();
    if (session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please login to favorite properties")),
      );
      return;
    }

    final api = ApiService();
    final userId = database.get('userID')?.toString() ?? session;

    try {
      if (_isFavorited) {
        await api.removeFromFavorites(userId: userId, propertyId: itemID1);
      } else {
        await api.addToFavorites(userId: userId, propertyId: itemID1);
      }
      setState(() {
        _isFavorited = !_isFavorited;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              _isFavorited ? "Added to favorites" : "Removed from favorites"),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      print('Toggle favorite error: $e');
    }
  }

  Future<void> _loadComments() async {
    try {
      final data = await ApiService().getPropertyComments(propertyId: itemID1);
      setState(() {
        _comments = List<Map<String, dynamic>>.from(data['comments'] ?? []);
        _averageRating = (data['averageRating'] ?? 0).toDouble();
      });
    } catch (e) {
      print('Load comments error: $e');
    }
  }

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty) return;
    final session = SessionManager.getSessionID();
    if (session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please login to comment")),
      );
      return;
    }

    setState(() => _submittingComment = true);
    try {
      final userId = database.get('userID')?.toString() ?? session;
      await ApiService().addComment(
        sessionToken: session,
        propertyId: itemID1,
        customerName: userId,
        customerPhone: userId,
        comment: _commentController.text.trim(),
        rating: _commentRating.toDouble(),
      );
      _commentController.clear();
      await _loadComments();
    } catch (e) {
      print('Submit comment error: $e');
    } finally {
      setState(() => _submittingComment = false);
    }
  }

    final String message = "Hello, I'm interested in the property you posted.";
    final Uri whatsappUri =
        Uri.parse("https://wa.me/$_whatsappNumber?text=$message");

    try {
      await launchUrl(whatsappUri);
      NotificationService().showNotification(
        title: "Contacting Owner",
        body: "You are now contacting the property owner via WhatsApp",
        id: 1,
      );
    } catch (e) {
      final Uri webUri = Uri.parse(
          "https://web.whatsapp.com/send?phone=$_whatsappNumber&text=$message");
      try {
        await launchUrl(webUri);
        NotificationService().showNotification(
          title: "Contacting Owner",
          body: "You are now contacting the property owner via WhatsApp Web",
          id: 1,
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not open WhatsApp")),
        );
      }
    }
  }

  void _showPhoneNumberWarning() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text("Before you call"),
          content: const Text(
            "No one should ask for money using this phone number. "
            "Verify any payment requests directly with the property owner.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            FilledButton(
              onPressed: () {
                setState(() => _phoneNumberVisible = true);
                Navigator.pop(context);
              },
              style: FilledButton.styleFrom(backgroundColor: _primary),
              child: const Text("Show number", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _handleBookingRequest() {
    _openPaymentDialog();
  }

  /// Show the payment dialog that slides up from the bottom of the screen when
  /// the customer requests to book a property. On a successful payment the
  /// backend returns a unique code which is stored locally (and emailed/SMS'd
  /// via the invoice) and then used to retrieve bookings and payments later.
  void _openPaymentDialog() {
    final property = <String, dynamic>{
      'name': propertyTitle,
      'type': _propertyType,
      'location': _locationName,
      'price': _priceValue,
      'description': _description,
      'brokerName': widget.brokerName ?? 'Broker',
    };
    PaymentSheet.show(
      context,
      property: property,
      onSubmit: ({
        required String phone,
        required String email,
        required String amount,
      }) async {
        final sessionToken = database.get('sessionID')?.toString() ?? '';
        final brokerCode =
            widget.brokerCode ?? database.get('userID')?.toString() ?? '';
        try {
          await _initBookingRequest(context, email, phone);
          setState(() => _revealContact = true);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Payment successful! Booking confirmed."),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } catch (e) {
          rethrow;
        }
        // Persist the session token and broker code for later retrieval.
        database.put('sessionID', sessionToken);
        database.put('brokerCode', brokerCode);
      },
    );
  }

  List<_FeatureData> _buildPropertyFeatures() {
    final features = <_FeatureData>[];

    if (_propertyType == "Apartment" || _propertyType == "House") {
      features.add(const _FeatureData(Icons.bed_outlined, "3 Beds"));
    } else if (_propertyType == "Single Room") {
      features.add(const _FeatureData(Icons.bed_outlined, "1 Bed"));
    } else {
      features.add(const _FeatureData(Icons.bed_outlined, "2 Beds"));
    }

    if (_propertyType == "Apartment" || _propertyType == "House") {
      features.add(const _FeatureData(Icons.bathtub_outlined, "2 Bath"));
    } else if (_propertyType == "Single Room") {
      features.add(const _FeatureData(Icons.bathtub_outlined, "1 Bath"));
    } else {
      features.add(const _FeatureData(Icons.bathtub_outlined, "1 Bath"));
    }

    if (_propertyType == "Apartment") {
      features.add(const _FeatureData(Icons.square_foot_outlined, "1200 sqft"));
    } else if (_propertyType == "House") {
      features.add(const _FeatureData(Icons.square_foot_outlined, "2500 sqft"));
    } else if (_propertyType == "Single Room") {
      features.add(const _FeatureData(Icons.square_foot_outlined, "400 sqft"));
    } else {
      features.add(const _FeatureData(Icons.square_foot_outlined, "800 sqft"));
    }

    for (final feature in _extraFeatures) {
      features.add(_FeatureData(feature["icon"], feature["label"]));
    }
    return features;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: PropertyDetailsShimmer());
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            stretch: true,
            backgroundColor: Colors.white,
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: _OverlayButton(
                icon: Icons.arrow_back_ios_new_rounded,
                iconColor: Colors.black87,
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => BottomNavBar()),
                  );
                },
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _OverlayButton(
                  icon: Icons.share_outlined,
                  onTap: _shareProperty,
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    controller: _pageController,
                    itemCount: _images.length,
                    itemBuilder: (context, index) {
                      return Image.asset(
                        _images[index],
                        fit: BoxFit.cover,
                      );
                    },
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x66000000),
                          Colors.transparent,
                          Color(0x99000000),
                        ],
                        stops: [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "UGX $amount / mo",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: SmoothPageIndicator(
                        controller: _pageController,
                        count: _images.length,
                        effect: const ExpandingDotsEffect(
                          activeDotColor: Colors.white,
                          dotColor: Color(0x88FFFFFF),
                          dotHeight: 6,
                          dotWidth: 6,
                          expansionFactor: 3,
                          spacing: 6,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailsHeader(
                    title: propertyTitle,
                    isFavorited: _isFavorited,
                    onFavoriteTap: _toggleFavorite,
                  ),
                //  const SizedBox(height: 16),
               //   _FeatureStrip(features: _buildPropertyFeatures()),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _SectionCard(
                      child: Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _primary.withOpacity(0.2),
                                width: 2,
                              ),
                            ),
                            child: const CircleAvatar(
                              radius: 28,
                              backgroundImage: AssetImage("assets/map2.png"),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Delos Kevin",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.brokerName != null &&
                                          widget.brokerName!.isNotEmpty
                                      ? "Listed by ${widget.brokerName}"
                                      : "Brokers contact",
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            children: [
                              _ContactChip(
                                icon: Icons.chat_bubble_outline,
                                label: "WhatsApp",
                                onTap: _openWhatsApp,
                              ),
                              const SizedBox(height: 8),
                              if (_revealContact) ...[
                                if (_phoneNumberVisible)
                                  Text(
                                    _whatsappNumber,
                                    style: const TextStyle(
                                      color: _primary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  )
                                else
                                  _ContactChip(
                                    icon: Icons.phone_outlined,
                                    label: "Call",
                                    filled: true,
                                    onTap: _showPhoneNumberWarning,
                                  ),
                              ] else
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    "Tap Book to reveal",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: _primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SectionTitle(
                            icon: Icons.description_outlined,
                            title: "Overview",
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _description.isNotEmpty
                                ? _description
                                : 'No description available.',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 14,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionTitle(
                          icon: Icons.photo_library_outlined,
                          title: "Gallery",
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 96,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _images.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 10),
                            itemBuilder: (context, index) {
                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => GalleryViewPage(
                                        images: _images,
                                        initialIndex: index,
                                      ),
                                    ),
                                  );
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.asset(
                                    _images[index],
                                    width: 120,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionTitle(
                          icon: Icons.videocam_outlined,
                          title: "Property tour",
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: VideoPlayerX(video_url: videoURL),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _revealContact
                        ? _SectionCard(
                            padding: EdgeInsets.zero,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 16, 16, 12),
                                  child: _SectionTitle(
                                    icon: Icons.location_on_outlined,
                                    title: "Location",
                                  ),
                                ),
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    bottom: Radius.circular(16),
                                  ),
                                  child: SizedBox(
                                    height: 200,
                                      child: GoogleMap(
                                        onMapCreated: _onMapCreated,
                                        initialCameraPosition: CameraPosition(
                                          target: _destination ??
                                              _currentLocation ??
                                              const LatLng(0.3476, 32.5825),
                                          zoom: 14,
                                        ),
                                      myLocationEnabled: true,
                                      markers: _markers,
                                      polylines: _polylines,
                                      zoomControlsEnabled: false,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: _openInMaps,
                                      icon: const Icon(Icons.map_outlined),
                                      label: const Text("Open in Google Maps"),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: _primary,
                                        side: BorderSide(color: _primary),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _SectionCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _SectionTitle(
                                  icon: Icons.location_on_outlined,
                                  title: "Location",
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Icon(Icons.lock_outline,
                                        color: Colors.grey.shade500),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        "The exact location is hidden until "
                                        "you book the property.",
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                   ),
                   const SizedBox(height: 100),
                   _CommentsSection(
                     propertyId: itemID1,
                   ),
                 ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BookingBar(
        amount: amount,
        onBook: _handleBookingRequest,
      ),
    );
  }
}

class _FeatureData {
  final IconData? icon;
  final String label;

  const _FeatureData(this.icon, this.label);
}

class _OverlayButton extends StatelessWidget {
  final IconData? icon;
  final VoidCallback onTap;
  final Color? iconColor;

  const _OverlayButton({
    this.icon,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.95),
      shape: const CircleBorder(),
      elevation: 2,
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon ?? Icons.help_outline, size: 20, color: iconColor ?? _primary),
        ),
      ),
    );
  }
}

class _DetailsHeader extends StatelessWidget {
  final String title;
  final bool isFavorited;
  final VoidCallback? onFavoriteTap;

  const _DetailsHeader({
    required this.title,
    this.isFavorited = false,
    this.onFavoriteTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ),
              if (onFavoriteTap != null)
                IconButton(
                  onPressed: onFavoriteTap,
                  icon: Icon(
                    Icons.favorite,
                    color: isFavorited ? Colors.red : Colors.grey,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _FeatureStrip extends StatelessWidget {
  final List<_FeatureData> features;

  const _FeatureStrip({required this.features});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: features.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final feature = features[index];
          return Container(
            width: 88,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                  Icon(feature.icon ?? Icons.help_outline, color: _primary, size: 24),
                const SizedBox(height: 6),
                Text(
                  feature.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _SectionCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: _primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ContactChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  const _ContactChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? _primary : _primary.withOpacity(0.08),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: filled ? Colors.white : _primary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: filled ? Colors.white : _primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookingBar extends StatelessWidget {
  final String amount;
  final VoidCallback onBook;

  const _BookingBar({required this.amount, required this.onBook});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Monthly rent",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  RichText(
                    text: TextSpan(
                      style: DefaultTextStyle.of(context).style,
                      children: [
                        TextSpan(
                          text: "UGX $amount",
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: _primary,
                          ),
                        ),
                        TextSpan(
                          text: " / mo",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
            /*  FilledButton(
                onPressed: onBook,
                style: FilledButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  "Book now",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            */
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-screen dark gallery viewer. Tapping a thumbnail in the property
/// details gallery opens this page where the customer can scroll through the
/// images exactly like the horizontal gallery.
class GalleryViewPage extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const GalleryViewPage({
    super.key,
    required this.images,
    this.initialIndex = 0,
  });

  @override
  State<GalleryViewPage> createState() => _GalleryViewPageState();
}

class _GalleryViewPageState extends State<GalleryViewPage> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.images.length,
        itemBuilder: (context, index) {
          return InteractiveViewer(
            child: Center(
              child: Image.asset(
                widget.images[index],
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          );
        },
      ),
    );
  }
}
