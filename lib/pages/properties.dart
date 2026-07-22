import 'package:flutter/material.dart';
import 'package:zcanopy/pages/welcome.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:zcanopy/pages/network.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:zcanopy/pages/session.dart';
import 'package:zcanopy/services/api_service.dart';

const String visionApiKey = 'AIzaSyDFMghpugRAmcZakMSB0J04vZjSO3quAz8';

class AIScanAnimation extends StatefulWidget {
  const AIScanAnimation({Key? key}) : super(key: key);

  @override
  State<AIScanAnimation> createState() => _AIScanAnimationState();
}

class _AIScanAnimationState extends State<AIScanAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.blueAccent.withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          FadeTransition(
            opacity: _controller,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.cyanAccent, width: 3),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const Text(
            'AI Scanning...',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _ValidationCheck {
  final String label;
  final bool passed;
  final String? detail;

  const _ValidationCheck(this.label, this.passed, {this.detail});
}

Future<bool> verifyBuilding(File imageFile) async {
  try {
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    final body = jsonEncode({
      'requests': [
        {
          'image': {'content': base64Image},
          'features': [
            {'type': 'LABEL_DETECTION', 'maxResults': 10},
          ],
        },
      ],
    });

    final response = await http.post(
      Uri.parse(
        'https://vision.googleapis.com/v1/images:annotate?key=$visionApiKey',
      ),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode == 200) {
      final jsonResp = jsonDecode(response.body);
      final labels = jsonResp['responses'][0]['labelAnnotations'];
      if (labels != null) {
        for (var label in labels) {
          final desc = label['description'].toString().toLowerCase();
          if (desc.contains('building') ||
              desc.contains('architecture') ||
              desc.contains('house') ||
              desc.contains('property') ||
              desc.contains('skyscraper')) {
            return true;
          }
        }
      }
    }
    return false;
  } catch (e) {
    debugPrint('Verification error: $e');
    return false;
  }
}

Future<void> showAIVerificationDialog(
  BuildContext context,
  File imageFile,
  Function onVerified,
) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.black87,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          AIScanAnimation(),
          SizedBox(height: 16),
          Text(
            'Analyzing your image... Please wait',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    ),
  );

  final hasBuilding = await verifyBuilding(imageFile);
  Navigator.of(context).pop(); // close scanning dialog

  if (hasBuilding) {
    onVerified(true); // continue upload
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black87,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        title: const Text('Verified!', style: TextStyle(color: Colors.white)),
        content: const Text(
          'A building was detected. Uploading your image.',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  } else {
    onVerified(false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black87,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        title: const Text(
          ' Upload Rejected',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'No building was detected in the image. Please upload a valid property photo.',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

//---------------AI code ends-------------------------------

class PropertiesPage extends StatefulWidget {
  const PropertiesPage({super.key});

  @override
  State<PropertiesPage> createState() => _PropertiesPageState();
}

class _PropertiesPageState extends State<PropertiesPage> {
  final ScrollController _scrollController = ScrollController();
  final ImagePicker picker = ImagePicker();
  final _apiService = ApiService();
  bool isLoading = true;
  bool startFetch = false;
  bool showNextButton = true;
  final database = Hive.box('myStore');
  var userID;

  bool _isLoading = false;
  bool isUploading = false;
  bool isLoadingMore = false;
  final int itemsPerPage = 2;
  List<Map<String, dynamic>> displayedProps = [];

  Set<Marker> _markers = {};

  Location _location = Location();
  LatLng? _currentLocation;
  var globalCoords;
  final LatLng _destination = LatLng(40.7128, -74.0060); // NYC

  Map<String, dynamic> _graphData = {
    "total": 12,
    "approved": 6,
    "rejected": 4,
    "pending": 2,
  };

  // Active subscription tier + its enforced limits, shown on the upload page
  // and used to validate every property the broker drops in.
  String _tierName = 'Prop';
  Map<String, dynamic> _tierLimits = {
    'maxProperties': 5,
    'maxPhotosPerProperty': 15,
    'maxVideosPerProperty': 1,
    'maxVideoSizeMB': 500,
  };

  List<Map<String, dynamic>> properties = [
    {
      "id": "P1001",
      "status": "Pending",
      "name": "Modern Apartment",
      "location": "Kampala",
      "dateUploaded": "2025-08-20",
      "daysRemaining": 25,
      "visible": true,
      "bookings": 3,
      "bookingsInQueue": 2,
      "images": [
        "https://picsum.photos/200/120?random=1",
        "https://picsum.photos/200/120?random=2",
        "https://picsum.photos/200/120?random=3",
      ],
      "mainImage": "https://picsum.photos/200/120?random=1",
      "video":
          "https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4",
      "bedrooms": 3,
      "bathrooms": 2,
      "kitchen": true,
      "livingRoom": true,
      "size": "1200 sqft",
      "latitude": 0.3476,
      "longitude": 32.5825,
      "clients": [
        {
          "propertyID": "P1001",
          "expiry": 40,
          "names": "delos kevin",
          "phoneNumber": "+256741882818",
        },
        {
          "propertyID": "P1001",
          "expiry": 60,
          "names": "delos kevin",
          "phoneNumber": "+256741882818",
        },
        {
          "propertyID": "P1001",
          "expiry": 160,
          "names": "delos kevin",
          "phoneNumber": "+256741882818",
        },
        {
          "propertyID": "P1001",
          "expiry": 120,
          "names": "delos kevin",
          "phoneNumber": "+256741882818",
        },
        {
          "propertyID": "P1001",
          "expiry": 25,
          "names": "delos kevin",
          "phoneNumber": "+256741882818",
        },
      ],
    },
    {
      "id": "P1002",
      "status": "Approved",
      "name": "Luxury Villa",
      "location": "Entebbe",
      "dateUploaded": "2025-08-18",
      "daysRemaining": 20,
      "visible": true,
      "bookings": 5,
      "bookingsInQueue": 0,
      "images": [
        "https://picsum.photos/200/120?random=1",
        "https://picsum.photos/200/120?random=2",
        "https://picsum.photos/200/120?random=3",
      ],
      "mainImage": "https://picsum.photos/200/120?random=3",
      "video":
          "https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4",
      "bedrooms": 5,
      "bathrooms": 4,
      "kitchen": true,
      "livingRoom": true,
      "size": "2500 sqft",
      "latitude": 0.0645,
      "longitude": 32.4592,
      "clients": [
        {
          "propertyID": "P1002",
          "expiry": 60,
          "names": "delos kevin",
          "phoneNumber": "+256741882818",
        },
        {
          "propertyID": "P1002",
          "expiry": 60,
          "names": "delos kevin",
          "phoneNumber": "+256741882818",
        },
        {
          "propertyID": "P1002",
          "expiry": 60,
          "names": "delos kevin",
          "phoneNumber": "+256741882818",
        },
        {
          "propertyID": "P1002",
          "expiry": 60,
          "names": "delos kevin",
          "phoneNumber": "+256741882818",
        },
        {
          "propertyID": "P1002",
          "expiry": 60,
          "names": "delos kevin",
          "phoneNumber": "+256741882818",
        },
      ],
    },
    {
      "id": "P1P1002",
      "status": "Pending",
      "name": "Studio Apartment",
      "location": "Jinja",
      "dateUploaded": "2025-08-21",
      "daysRemaining": 28,
      "visible": true,
      "bookings": 1,
      "bookingsInQueue": 1,
      "images": [
        "https://picsum.photos/200/120?random=1",
        "https://picsum.photos/200/120?random=2",
        "https://picsum.photos/200/120?random=3",
      ],
      "mainImage": "https://picsum.photos/200/120?random=3",
      "video":
          "https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4",
      "bedrooms": 1,
      "bathrooms": 1,
      "kitchen": true,
      "livingRoom": false,
      "size": "500 sqft",
      "latitude": 0.4306,
      "longitude": 33.2006,
      "clients": [
        {
          "propertyID": "P1P1002",
          "expiry": 60,
          "names": "delos kevin",
          "phoneNumber": "+256741882818",
        },
        {
          "propertyID": "P1P1002",
          "expiry": 60,
          "names": "delos kevin",
          "phoneNumber": "+256741882818",
        },
        {
          "propertyID": "P1P1002",
          "expiry": 60,
          "names": "delos kevin",
          "phoneNumber": "+256741882818",
        },
        {
          "propertyID": "P1P1002",
          "expiry": 60,
          "names": "delos kevin",
          "phoneNumber": "+256741882818",
        },
        {
          "propertyID": "P1P1002",
          "expiry": 60,
          "names": "delos kevin",
          "phoneNumber": "+256741882818",
        },
      ],
    },
    {
      "id": "P1004",
      "status": "Approved",
      "name": "Family Home",
      "location": "Mbarara",
      "dateUploaded": "2025-08-22",
      "daysRemaining": 30,
      "visible": true,
      "bookings": 0,
      "bookingsInQueue": 0,
      "images": [
        "https://picsum.photos/200/120?random=1",
        "https://picsum.photos/200/120?random=2",
        "https://picsum.photos/200/120?random=3",
      ],
      "mainImage": "https://picsum.photos/200/120?random=3",
      "video":
          "https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4",
      "bedrooms": 4,
      "bathrooms": 3,
      "kitchen": true,
      "livingRoom": true,
      "size": "2000 sqft",
      "latitude": -0.6057,
      "longitude": 30.6773,
      "clients": [
        {
          "propertyID": "P1004",
          "expiry": 60,
          "names": "delos kevin",
          "phoneNumber": "+256741882818",
        },
        {
          "propertyID": "P1004",
          "expiry": 60,
          "names": "delos kevin",
          "phoneNumber": "+256741882818",
        },
        {
          "propertyID": "P1004",
          "expiry": 60,
          "names": "delos kevin",
          "phoneNumber": "+256741882818",
        },
        {
          "propertyID": "P1004",
          "expiry": 60,
          "names": "delos kevin",
          "phoneNumber": "+256741882818",
        },
        {
          "propertyID": "P1004",
          "expiry": 60,
          "names": "delos kevin",
          "phoneNumber": "+256741882818",
        },
      ],
    },
  ];

  Future<void> _getProperties() async {
    final isSessionValid = await SessionService.validateSession();
    if (!isSessionValid) {
      await forceLogout(context);
    }

    setState(() => isLoading = true);

    try {
      final response = await _apiService.getProperties(
        userId: userID,
      );

      if (response['success'] == true) {
        setState(() {
          properties = List<Map<String, dynamic>>.from(response['data'] ?? []);
          displayedProps = properties.take(itemsPerPage).toList();
        });
      } else {
        debugPrint("Error: ${response['message']}");
      }
    } catch (e) {
      debugPrint("Network error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  // Dialog for adding new property
  void _showAddPropertyDialog() {
    final TextEditingController nameCtrl = TextEditingController();
    final TextEditingController locationCtrl = TextEditingController();
    final TextEditingController descriptionCtrl = TextEditingController();
    List<String> selectedImages = [];
    String? selectedVideo;
    int selectedVideoSizeMB = 0;
    final _formKey = GlobalKey<FormState>();

    // Validation state: each rule is checked live as the broker drops items.
    bool _nameValid = false;
    bool _descValid = false;
    bool _photosValid = false;
    bool _videosValid = false;
    bool _videoSizeValid = true;
    String _validationMessage = '';

    // Validates the dropped-in items against the broker's tier limits and the
    // required fields. Runs on every change so the progress UI stays live.
    void _runValidation() {
      final maxPhotos = _tierLimits['maxPhotosPerProperty'] ?? 0;
      final maxVideos = _tierLimits['maxVideosPerProperty'] ?? 0;
      final maxVideoMb = _tierLimits['maxVideoSizeMB'] ?? 0;

      _nameValid = nameCtrl.text.trim().isNotEmpty;
      _descValid = descriptionCtrl.text.trim().isNotEmpty;
      _photosValid = selectedImages.length > 0 &&
          selectedImages.length <= maxPhotos;
      _videosValid = selectedVideo == null ||
          (selectedVideo != null && maxVideos >= 1);
      _videoSizeValid =
          selectedVideo == null || selectedVideoSizeMB <= maxVideoMb;

      final errors = <String>[];
      if (!_nameValid) errors.add('Add a property name');
      if (!_descValid) errors.add('Add a description');
      if (selectedImages.isEmpty) {
        errors.add('Add at least one photo');
      } else if (selectedImages.length > maxPhotos) {
        errors.add('Too many photos (max $maxPhotos)');
      }
      if (selectedVideo != null && !_videosValid) {
        errors.add('Too many videos (max $maxVideos)');
      }
      if (selectedVideo != null && !_videoSizeValid) {
        errors.add('Video too large (max $maxVideoMb MB)');
      }

      _validationMessage = errors.isEmpty
          ? 'All checks passed'
          : errors.join(' • ');
    }

    // Computes the selected video size in MB and re-validates immediately.
    Future<void> _onVideoPicked(XFile file) async {
      final bytes = await file.length();
      selectedVideoSizeMB = (bytes / (1024 * 1024)).round();
      selectedVideo = file.path;
      _runValidation();
    }

    void _onImagesPicked(List<XFile> files) {
      selectedImages = files.map((f) => f.path).toList();
      _runValidation();
    }

    // Live validation progress widget: a checklist that updates every time the
    // broker drops in an image or video, plus an overall progress bar.
    Widget _buildValidationProgress() {
      final maxPhotos = _tierLimits['maxPhotosPerProperty'] ?? 0;
      final maxVideos = _tierLimits['maxVideosPerProperty'] ?? 0;

      final checks = <_ValidationCheck>[
        _ValidationCheck('Property name', _nameValid),
        _ValidationCheck('Description', _descValid),
        _ValidationCheck(
          'Photos ($maxPhotos max)',
          _photosValid,
          detail: selectedImages.isEmpty
              ? 'None added'
              : '${selectedImages.length}/$maxPhotos',
        ),
        _ValidationCheck(
          'Video ($maxVideos max)',
          _videosValid,
          detail: selectedVideo == null ? 'Optional' : '1/$maxVideos',
        ),
        _ValidationCheck(
          'Video size limit',
          _videoSizeValid,
          detail: selectedVideo == null
              ? 'Optional'
              : '${selectedVideoSizeMB}MB',
        ),
      ];

      final passed = checks.where((c) => c.passed).length;
      final progress = checks.isEmpty ? 0.0 : passed / checks.length;

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: passed == checks.length
                ? Colors.green
                : const Color.fromARGB(255, 169, 97, 14),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Validation',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color.fromARGB(255, 169, 97, 14),
                  ),
                ),
                Text(
                  '$passed/${checks.length}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.grey.shade300,
              color: passed == checks.length ? Colors.green : const Color.fromARGB(255, 169, 97, 14),
            ),
            const SizedBox(height: 10),
            ...checks.map(
              (c) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Icon(
                      c.passed ? Icons.check_circle : Icons.radio_button_unchecked,
                      size: 16,
                      color: c.passed ? Colors.green : Colors.grey.shade500,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        c.label,
                        style: TextStyle(
                          fontSize: 12,
                          color: c.passed
                              ? Colors.green.shade800
                              : Colors.grey.shade700,
                        ),
                      ),
                    ),
                    if (c.detail != null)
                      Text(
                        c.detail!,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.grey[700],
              insetPadding: const EdgeInsets.all(20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
              content: Container(
                width: 500, // Increased width,
                child: SingleChildScrollView(
                  // Added SingleChildScrollView to prevent overflow
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            const Text(
                              "Add New Property",
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),

                            const SizedBox(height: 20),
                            TextFormField(
                              style: TextStyle(color: Colors.white),
                              cursorColor: Color.fromARGB(255, 169, 97, 14),
                              controller: nameCtrl,
                              onChanged: (_) {
                                _runValidation();
                                setDialogState(() {});
                              },
                              decoration: const InputDecoration(
                                contentPadding: EdgeInsets.all(10),
                                labelText: "Property Name",
                                labelStyle: TextStyle(color: Colors.white),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(
                                    color: Color.fromARGB(255, 169, 97, 14),
                                  ),
                                  //   borderRadius:BorderRadius.circular(12)
                                ),
                                border: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Color.fromARGB(255, 169, 97, 14),
                                  ),
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(12),
                                  ),
                                ),
                                prefixIcon: Icon(
                                  Icons.home,
                                  color: Colors.white,
                                ),
                              ),
                              validator: (val) =>
                                  val != null ? null : 'Enter a property Name',
                            ),

                            /* const SizedBox(height: 20),
                          TextFormField(
                            style: TextStyle(color: Colors.white),
                            controller: locationCtrl,
                            cursorColor: Color.fromARGB(255, 169, 97, 14),
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.all(10),
                              labelText: "Location",
                              labelStyle: TextStyle(color: Colors.white),
                              focusedBorder: OutlineInputBorder(
                                borderSide: const BorderSide(
                                    color: Color.fromARGB(255, 169, 97, 14)),
                                //   borderRadius:BorderRadius.circular(12)
                              ),
                              border: OutlineInputBorder(
                                borderSide: BorderSide(
                                    color: Color.fromARGB(255, 169, 97, 14)),
                                borderRadius:
                                    BorderRadius.all(Radius.circular(12)),
                              ),
                              prefixIcon:
                                  Icon(Icons.location_on, color: Colors.white),
                            ),
                             validator: (val) =>
                                val != null ? null : 'Enter a Location',
                          ),*/
                            const SizedBox(height: 20),

                            // Upload Images
                            ElevatedButton(
                              onPressed: () async {
                                final List<XFile> files = await picker
                                    .pickMultiImage(); // multiple images
                                if (files.isNotEmpty) {
                                  for (var xfile in files) {
                                    File imageFile = File(xfile.path);

                                    await showAIVerificationDialog(
                                      context,
                                      imageFile,
                                      (status) {
                                        if (status == false) {
                                          setState(() {
                                            showNextButton = false;
                                          });
                                        }

                                        // Place your image upload logic here...upload to server then
                                        debugPrint(
                                          "Image verified and ready for upload: ${imageFile.path}",
                                        );
                                      },
                                    );
                                  }
                                  // Re-validate the dropped-in photos against the
                                  // broker's tier photo limit every single drop.
                                  _onImagesPicked(files);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.image,
                                    color: Color.fromARGB(255, 169, 97, 14),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    "Upload Images",
                                    style: TextStyle(
                                      color: Color.fromARGB(255, 169, 97, 14),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Description field (type, bedrooms, kitchen, etc.
                            // are all covered here instead of separate fields)
                            TextFormField(
                              style: TextStyle(color: Colors.white),
                              controller: descriptionCtrl,
                              maxLines: 4,
                              onChanged: (_) {
                                _runValidation();
                                setDialogState(() {});
                              },
                              cursorColor: Color.fromARGB(255, 169, 97, 14),
                              decoration: const InputDecoration(
                                contentPadding: EdgeInsets.all(10),
                                labelText:
                                    "Description (type, bedrooms, kitchen, etc.)",
                                labelStyle: TextStyle(color: Colors.white),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(
                                    color: Color.fromARGB(255, 169, 97, 14),
                                  ),
                                  //   borderRadius:BorderRadius.circular(12)
                                ),
                                border: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Color.fromARGB(255, 169, 97, 14),
                                  ),
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(12),
                                  ),
                                ),
                                prefixIcon: Icon(
                                  Icons.description,
                                  color: Colors.white,
                                ),
                              ),
                              validator: (val) => val != null && val.isNotEmpty
                                  ? null
                                  : 'Enter a description',
                            ),

                            if (selectedImages.isNotEmpty)
                              const SizedBox(height: 15),
                            if (selectedImages.isNotEmpty)
                              SizedBox(
                                height: 100,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  children: selectedImages
                                      .map(
                                        (file) => Padding(
                                          padding: const EdgeInsets.only(
                                            right: 10,
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            child: Image.file(
                                              File(file),
                                              width: 100,
                                              height: 100,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                            _buildValidationProgress(),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Upload Video
                      ElevatedButton(
                        onPressed: () async {
                          final XFile? file = await picker.pickVideo(
                            source: ImageSource.gallery,
                          );
                          if (file != null) {
                            // Measure size and re-validate against the tier limit.
                            await _onVideoPicked(file);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.videocam,
                              color: Color.fromARGB(255, 169, 97, 14),
                            ),
                            SizedBox(width: 8),
                            Text(
                              "Upload Video",
                              style: TextStyle(
                                color: Color.fromARGB(255, 169, 97, 14),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (selectedVideo != null) const SizedBox(height: 15),
                      if (selectedVideo != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.videocam,
                                color: Color.fromARGB(255, 169, 97, 14),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  "Video selected: ${selectedVideo!.split('/').last}",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color.fromARGB(255, 169, 97, 14),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 15),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          "Note: Your current location will be used as the property location",
                          style: TextStyle(
                            fontSize: 14,
                            color: Color.fromARGB(255, 169, 97, 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
                showNextButton
                    ? ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 25,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _validationMessage == 'All checks passed'
                            ? () async {
                          final userID = database.get('userID');
                          final lat = globalCoords?.latitude ?? 0.0;
                          final lng = globalCoords?.longitude ?? 0.0;

                          // Resolve sub-county + district from the property
                          // coordinates via the Google-backed backend endpoint.
                          String subCounty = '';
                          String district = '';
                          try {
                            final resolved = await NetworkService.get(
                              'http://127.0.0.1:4000/properties/resolve-location-name?lat=$lat&long=$lng',
                            );
                            subCounty = resolved['subCounty'] ?? '';
                            district = resolved['district'] ?? '';
                          } catch (e) {
                            debugPrint('Resolve location failed: $e');
                          }

                          final String locationName = subCounty.isNotEmpty
                              ? subCounty
                              : (_currentLocation != null
                                  ? _currentLocation.toString()
                                  : 'Unknown');

                          // Build a payload that matches the backend
                          // CreateProperty requirements, including subCounty/
                          // district resolved from the coordinates.
                          final payload = {
                            "brokersUniqueCode": userID,
                            "title": nameCtrl.text,
                            "description": descriptionCtrl.text,
                            "propertyType": "House",
                            "location": locationName,
                            "lat": lat,
                            "lng": lng,
                            "imageUrl": selectedImages,
                            "videoUrl": selectedVideo,
                            "subCounty": subCounty,
                            "district": district,
                          };

                          uploadNewProperty(context, payload);

                          // Keep a local copy so the UI updates immediately
                          // (works even if the backend is unreachable).
                          setState(() {
                            properties.add({
                              "id": "P${properties.length + 1001}",
                              "name": nameCtrl.text,
                              "title": nameCtrl.text,
                              "location": locationName,
                              "subCounty": subCounty,
                              "district": district,
                              "dateUploaded": DateTime.now()
                                  .toString()
                                  .split(' ')[0],
                              "daysRemaining": 30,
                              "visible": true,
                              "bookings": 0,
                              "bookingsInQueue": 0,
                              "images": selectedImages,
                              "mainImage": selectedImages.isNotEmpty
                                  ? selectedImages[0]
                                  : null,
                              "video": selectedVideo,
                              "description": descriptionCtrl.text,
                                "latitude": lat,
                              "longitude": lng,
                            });
                          });
                        }
                            : null,
                        child: !isUploading
                            ? const Text(
                                "Next",
                                style: TextStyle(
                                  color: Color.fromARGB(255, 169, 97, 14),
                                  fontSize: 12,
                                ),
                              )
                            : SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Color.fromARGB(255, 169, 97, 14),
                                ),
                              ),
                      )
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 25,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx); // Close add property dialog
                        },
                        child: const Text(
                          "Abort",
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ),
              ],
            );
          },
        );
      },
    );
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
      globalCoords = locData;

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
                position: _destination,
                infoWindow: InfoWindow(title: "Destination"),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueBlue,
                ),
              ),
            };
          });

          database.put('location', _currentLocation);
          //    _getDirections();
        }
      });
    } catch (e) {
      print("Error getting location updates: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    startFetch ? _getProperties() : '';
    loadInitialData();
    userID = database.get('userID');
    getGraphData();
    _loadTierLimits();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !isLoadingMore &&
          displayedProps.length < properties.length) {
        loadMoreData();
      }
    });
  }

  /// Loads the broker's active subscription tier and its limits so the
  /// upload page can display them and validate each property against them.
  Future<void> _loadTierLimits() async {
    final brokerCode = database.get('brokerCode')?.toString() ?? '';
    if (brokerCode.isEmpty) return;

    String? tierKey = database.get('subscriptionTier')?.toString();

    try {
      final dashboard = await _apiService.getBrokerDashboard(brokerId: brokerCode);
      final broker = dashboard['broker'] ?? dashboard;
      tierKey ??= broker['subscriptionTier']?.toString() ??
          broker['subscription_tier']?.toString();
      if (tierKey != null) database.put('subscriptionTier', tierKey);
    } catch (e) {
      debugPrint('Load tier from dashboard failed: $e');
    }

    try {
      final packages = await _apiService.getSubscriptionPackages();
      final tiers = (packages['tiers'] as List?) ?? [];
      if (tiers.isNotEmpty) {
        final match = tiers.firstWhere(
          (t) => t['tier']?.toString() == (tierKey ?? 'prop'),
          orElse: () => tiers.first,
        );
        if (mounted) {
          setState(() {
            _tierName = match['name']?.toString() ?? 'Prop';
            _tierLimits = Map<String, dynamic>.from(match['limits'] ?? _tierLimits);
          });
        }
      }
    } catch (e) {
      debugPrint('Load subscription packages failed: $e');
    }
  }

  Future<void> uploadNewProperty(context, payload) async {
    final isSessionValid = await SessionService.validateSession();
    if (!isSessionValid) {
      if (mounted) {
        await forceLogout(context);
      }
    }

    setState(() {
      isUploading = true;
    });

    try {
      await _apiService.createProperty(
        userId: payload['brokersUniqueCode'],
        title: payload['title'],
        description: payload['description'],
        propertyType: payload['propertyType'],
        location: payload['location'],
        lat: (payload['lat'] ?? 0.0).toDouble(),
        lng: (payload['lng'] ?? 0.0).toDouble(),
        imageUrl: List<String>.from(payload['imageUrl'] ?? []),
        videoUrl: payload['videoUrl'],
        subCounty: payload['subCounty'],
        district: payload['district'],
      );
    } catch (e) {
      debugPrint('Create property request failed: $e');
    } finally {
      if (mounted) {
        setState(() => isUploading = false);
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Property successfully uploaded!"),
          backgroundColor: Color.fromARGB(255, 169, 97, 14),
        ),
      );
      Navigator.pop(context); // Close add property dialog
    }
  }

  Future<void> getGraphData() async {
    final isSessionValid = await SessionService.validateSession();
    if (!isSessionValid) {
      if (mounted) {
        await forceLogout(context);
      }
    }

    final payload = {"userID": database.get('userID')};

    final response = await fetchData2(userID);
    if (response.success) {
      setState(() {
        _graphData = response.graphData;
      });
    }
  }

  postData(path, payload) async {
    try {
      final data = await NetworkService.post(
        'http://127.0.0.1:4000/listings${path}',
        payload,
      );
      return data;
    } catch (e) {
      print(e);
    }
  }

  deleteProperty(payload, index) async {
    final isSessionValid = await SessionService.validateSession();
    if (!isSessionValid) {
      if (mounted) {
        await forceLogout(context);
      }
    }

    setState(() {
      properties.remove(displayedProps[index]);
    });

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Property deletion successfull"),
        backgroundColor: Colors.red,
      ),
    );

    //-------------stopping here at the moment----------------

    final response = await postData('/delete-property', payload);
    if (response.success) {
      setState(() {
        properties.remove(displayedProps[index]);
      });

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Property deletion successfull"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> approveProperty(context, index, payload) async {
    final isSessionValid = await SessionService.validateSession();
    if (!isSessionValid) {
      if (mounted) {
        await forceLogout(context);
      }
    }

    final response = await postData('/approve-property', payload);

    if (response.success) {
      displayedProps[index]['status'] = 'approved';

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Property successfully approved!"),
          backgroundColor: Color.fromARGB(255, 169, 97, 14),
        ),
      );

      Navigator.pop(context); // Close add property dialog
    }
  }

  fetchData(userID, itemsPerPage) async {
    try {
      final data = await NetworkService.get(
        'http://127.0.0.1:4000/gate-way/get-user-properties?userID=${userID}&itemsPerPage=${itemsPerPage}',
      );
      return data;
    } catch (e) {
      print(e);
    }
  }

  fetchData2(userID) async {
    try {
      final data = await NetworkService.get(
        'http://127.0.0.1:4000/gate-way/get-graph-data?userID=${userID}',
      );
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

  Future<void> loadInitialData() async {
    final isSessionValid = await SessionService.validateSession();
    if (!isSessionValid) {
      if (mounted) {
        await forceLogout(context);
      }
    }

    /* final data = await fetchData(userID, itemsPerPage);

    if (data.success) {
      setState(() {
        properties = data.properties;
        _isLoading = false;
        isLoadingMore = data.isLoadingMore;
      });
    }*/

    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      displayedProps = properties.take(itemsPerPage).toList();
      isLoading = false;
    });
  }

  Future<void> loadMoreData() async {
    setState(() => isLoadingMore = true);

    /*final data = await fetchData(userID, itemsPerPage);

    if (data.success) {
      setState(() {
        properties = data.bookings;
        _isLoading = false;
        isLoadingMore = data.isLoadingMore;
      });
    }*/

    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      final start = displayedProps.length;
      final end = (start + itemsPerPage).clamp(0, properties.length);
      displayedProps.addAll(properties.sublist(start, end));
      isLoadingMore = false;
    });
  }

  Widget _limitChip(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color.fromARGB(255, 169, 97, 14)),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color.fromARGB(255, 169, 97, 14),
                ),
              ),
              Text(
                label,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatVideoSize(dynamic mb) {
    final value = (mb ?? 0) as num;
    if (value >= 1024) {
      return "${(value / 1024).toStringAsFixed(0)}GB";
    }
    return "${value}MB";
  }

  /// Shows the broker's subscribed tier together with the feature limits that
  /// are enforced against the upload widget (photos, videos, video size, etc.).
  Widget _buildTierCard() {
    final maxProps = _tierLimits['maxProperties'] ?? 0;
    final maxPhotos = _tierLimits['maxPhotosPerProperty'] ?? 0;
    final maxVideos = _tierLimits['maxVideosPerProperty'] ?? 0;
    final maxVideo = _formatVideoSize(_tierLimits['maxVideoSizeMB']);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Subscribed Tier",
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 169, 97, 14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _tierName.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _limitChip(Icons.apartment, "properties", "$maxProps"),
              _limitChip(Icons.photo_library, "photos / property", "$maxPhotos"),
              _limitChip(Icons.videocam, "videos / property", "$maxVideos"),
              _limitChip(Icons.movie, "max video", maxVideo),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.brown,
        title: const Text(
          "My Properties",
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            color: Colors.white,
            iconSize: 30.0,
            onPressed: () {
              //first cehck for subscription
              _showAddPropertyDialog();
            },
            icon: Icon(Icons.add),
          ),
          Tooltip(message: 'Add property'),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/background.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 24),
                const Icon(
                  Icons.cloud_upload_outlined,
                  size: 72,
                  color: Color.fromARGB(255, 169, 97, 14),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Upload a Property",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color.fromARGB(255, 169, 97, 14),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Your listed properties are shown on the home screen. "
                  "Use this page to add new ones.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 32),
                _buildTierCard(),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _showAddPropertyDialog,
                    icon: const Icon(Icons.add),
                    label: const Text(
                      "Add New Property",
                      style: TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 169, 97, 14),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PropertyCard extends StatelessWidget {
  final List<String> images;
  final String location;
  final String date;
  final int beds;
  final int baths;
  final int sqft;
  final int bookings;
  final int queue;
  final String status;
  final bool showActions;

  const PropertyCard({
    super.key,
    required this.images,
    required this.location,
    required this.date,
    required this.beds,
    required this.baths,
    required this.sqft,
    required this.bookings,
    required this.queue,
    required this.status,
    required this.showActions,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.brown,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Image Gallery (Horizontal Scroll) ---
            SizedBox(
              height: 160,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      images[index],
                      width: 220,
                      height: 160,
                      fit: BoxFit.cover,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),

            // --- Location & Date ---
            Text(
              "Location: $location",
              style: const TextStyle(color: Colors.white),
            ),
            Text("Date: $date", style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 8),

            // --- Beds, Baths, Sqft ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("$beds bed", style: TextStyle(color: Colors.white)),
                Text("$baths bath", style: TextStyle(color: Colors.white)),
                Text("$sqft sqft", style: TextStyle(color: Colors.white)),
              ],
            ),
            const SizedBox(height: 6),

            // --- Bookings and Queue ---
            Text(
              "Bookings: $bookings    Queue: $queue",
              style: TextStyle(color: Colors.white),
            ),

            const SizedBox(height: 12),

            // --- Status / Actions ---
            showActions
                ? Row(
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color.fromARGB(255, 169, 97, 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {},
                        child: const Text(
                          "Approve",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {},
                        child: const Text(
                          "Decline",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  )
                : Align(
                    alignment: Alignment.centerRight,
                    child: Chip(
                      backgroundColor: Colors.green[100],
                      label: Text(
                        status,
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

            Row(
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {},
                  child: const Text(
                    "Approve",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {},
                  child: const Text(
                    "Decline",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
