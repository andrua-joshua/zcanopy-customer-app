/*import 'package:flutter/material.dart';
import 'package:zcanopy/pages/welcome.dart';
import 'package:zcanopy/pages/editProfile.dart';
import 'package:zcanopy/pages/help.dart';
import 'package:zcanopy/pages/notifications.dart';
import 'package:zcanopy/pages/payments.dart';
import 'package:zcanopy/pages/properties.dart';
import 'package:zcanopy/pages/bookings.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePage();
}

class _ProfilePage extends State<ProfilePage> {
  final database = Hive.box('myStore');
  bool isTenant = false;

  void showLogoutWarning(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Color.fromARGB(255, 169, 97, 14),
          title: const Text("Warning", style: TextStyle(color: Colors.white)),
          content: const Text("Are you sure you want to logout?",
              style: TextStyle(color: Colors.white)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text("Cancel", style: TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _logOutUser(context);
              },
              child:
                  const Text("Continue", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _logOutUser(context) async {
    try {
      final url = Uri.parse("https://my-server-url/users/logout-user");

      var obj = {"userID": "122343"};

      final response = await http.post(url, body: jsonEncode(obj));

      if (response.statusCode == 200) {
        var data = json.decode(response.body);

        setState(() {
          if (data['isLoggedOut'] == 'done') {
            Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (_) => const OnBoardingScreen()));
          }
        });
      } else {
        debugPrint("Error: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Network error: $e");
    } finally {}
  }

  @override
  void initState() {
    super.initState();
    isTenant = database.get('accountType') == 'tenant' ? true : false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Color.fromARGB(255, 169, 97, 14),
          leading: const Icon(Icons.home, color: Colors.white),
          title: const Text(
            "Profile",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: () {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Container(
              decoration: isDark
                  ? BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor)
                  : const BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage('assets/background.jpg'),
                        fit: BoxFit.cover,
                      ),
                    ),
              child: Container(
                decoration: isDark
                    ? BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor)
                    : const BoxDecoration(
                        image: DecorationImage(
                          image: AssetImage('assets/background.jpg'),
                          fit: BoxFit.cover,
                        ),
                      ),
                child: SingleChildScrollView(
                  child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // Profile picture + name
                    Center(
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          const CircleAvatar(
                            radius: 50,
                            backgroundImage: AssetImage(
                                "assets/profile.jpg"), // replace with NetworkImage if needed
                          ),
                          Container(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color.fromARGB(255, 169, 97, 14),
                            ),
                            padding: const EdgeInsets.all(6),
                            child: const Icon(Icons.edit,
                                color: Colors.white, size: 18),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      database.get('username')!=null ?database.get('username'):'delos kevo',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),

                    const SizedBox(height: 20),
                    const Divider(),

                    // Menu items
                  //  isTenant
                         _buildMenuItem(Icons.calendar_today, "My Bookings",
                            onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => BookingsPage()),
                            );
                          }),

                    //isTenant
                     _buildMenuItem(Icons.payment, "Payments", onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => PaymentsPage()),
                            );
                          }),

                    _buildMenuItem(Icons.person, "Profile", onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => ProfilePageEdit()),
                      );
                    }),
                    isTenant
                        ? _buildMenuItem(Icons.house_sharp, "My Properties",
                            onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => PropertiesPage()),
                            );
                          })
                        : Text(''),

                    _buildMenuItem(Icons.notifications, "Notification",
                        onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => NotificationsPage()),
                      );
                    }),
                    _buildMenuItem(Icons.lock, "Security"),
                    _buildMenuItem(Icons.language, "Language",
                        trailing: const Text("English (US)")),
                    _buildMenuItem(Icons.dark_mode, "Dark Mode",
                        trailing: Switch(value: false, onChanged: (_) {})),
                    _buildMenuItem(Icons.help_outline, "Help Center",
                        onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => HelpCenterPage()),
                      );
                    }),
                    _buildMenuItem(Icons.group, "Invite Friends"),

                    const Divider(),

                    // Logout
                 _buildMenuItem(Icons.logout, "Logout", textColor: Colors.red),
                  ],
                ),
              ),
            )));
  }

  // Helper method to reduce repetition
  static Widget _buildMenuItem(IconData icon, String title,
      {Widget? trailing, VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: Color.fromARGB(255, 169, 97, 14)),
      title: Text(title, style: const TextStyle(fontSize: 16)),
      trailing: trailing ??
          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
    );
  }
}*/

import 'package:flutter/material.dart';
import 'package:zcanopy/pages/welcome.dart';
import 'package:zcanopy/pages/loadIndicator.dart';
import 'package:zcanopy/pages/editProfile.dart';
import 'package:zcanopy/pages/help.dart';
import 'package:zcanopy/pages/notifications.dart';
import 'package:zcanopy/pages/payments.dart';
import 'package:zcanopy/pages/terms.dart';
import 'package:zcanopy/pages/properties.dart';
import 'package:zcanopy/pages/bookings.dart';
import 'package:zcanopy/pages/favourite.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:zcanopy/pages/settings.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:zcanopy/pages/network.dart';
import 'package:zcanopy/pages/session.dart';
import 'package:zcanopy/widgets/themed_page_background.dart';
import 'package:zcanopy/utils/theme_extensions.dart';
import 'package:zcanopy/services/api_service.dart';
import 'package:zcanopy/utils/colors.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePage();
}

class _ProfilePage extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  final database = Hive.box('myStore');
  final ApiService _apiService = ApiService();
  bool isTenant = false;
  bool _isLoadingDashboard = false;
  bool _isWithdrawing = false;
  bool _isUnsubscribing = false;
  bool _locationLoading = true;
  Map<String, dynamic>? _brokerDashboard;
  late AnimationController _controller;
  late Animation<double> _animation;
  Set<Marker> _markers = {};

  Location _location = Location();
  LatLng? _currentLocation;
  String locationString = '';
  final LatLng _destination = LatLng(40.7128, -74.0060); // NYC

  void showLogoutWarning(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white24,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          title: const Text("Warning", style: TextStyle(color: Colors.black)),
          content: const Text("Are you sure you want to logout?",
              style: TextStyle(color: Colors.black)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text("Cancel", style: TextStyle(color: Colors.black)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _logOutUser(context);
              },
              child:
                  const Text("Continue", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
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

  Future<void> _logOutUser(context) async {
     final isSessionValid = await SessionService.validateSession();
    if (!isSessionValid) {
      if (mounted) {
        await forceLogout(context);
      }
      return;
    }

    try {
      // Revoke the session on the backend so the broker is logged out server-side.
      await _apiService.logoutBroker(
        brokerCode: database.get('brokerCode') ?? '',
        sessionId: database.get('sessionID'),
      );
    } catch (e) {
      debugPrint("Logout broker error: $e");
    } finally {
      if (mounted) {
        await forceLogout(context);
      }
    }
  }

  Future<void> _loadBrokerDashboard() async {
    final brokerId = database.get('userID');
    if (brokerId == null) return;
    if (mounted) setState(() => _isLoadingDashboard = true);
    try {
      final response = await _apiService.getBrokerDashboard(brokerId: brokerId);
      if (mounted) {
        setState(() {
          _brokerDashboard = response['broker'] ?? response;
        });
      }
    } catch (e) {
      debugPrint("Load broker dashboard error: $e");
    } finally {
      if (mounted) setState(() => _isLoadingDashboard = false);
    }
  }

  void _showWithdrawDialog() {
    final amountController = TextEditingController();
    final phoneController = TextEditingController(
      text: _brokerDashboard?['phoneNumber']?.toString() ?? '',
    );
    String provider = 'MTN';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final minWithdraw =
                (_brokerDashboard?['minimumWithdrawal'] ?? 0) is int
                    ? (_brokerDashboard?['minimumWithdrawal'] ?? 0).toDouble()
                    : (_brokerDashboard?['minimumWithdrawal'] ?? 0.0);
            return AlertDialog(
              title: const Text("Withdraw Funds"),
              content: SizedBox(
                width: MediaQuery.of(context).size.width,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                    Text(
                      "Minimum withdrawal: UGX ${_formatAmount(minWithdraw)}",
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Amount (UGX)",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: "Mobile money number",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: provider,
                      decoration: const InputDecoration(
                        labelText: "Provider",
                        border: OutlineInputBorder(),
                      ),
                      items: ['MTN', 'AIRTEL']
                          .map((p) =>
                              DropdownMenuItem(value: p, child: Text(p)))
                          .toList(),
                      onChanged: (v) =>
                          setDialogState(() => provider = v ?? 'MTN'),
                    ),
                  ],
                ),
              ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBrown,
                  ),
                  onPressed: _isWithdrawing
                      ? null
                      : () async {
                          final amount =
                              double.tryParse(amountController.text) ?? 0;
                          if (amount <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text("Enter a valid amount")),
                            );
                            return;
                          }
                          if (amount < minWithdraw) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      "Minimum withdrawal is UGX ${_formatAmount(minWithdraw)}")),
                            );
                            return;
                          }
                          setDialogState(() => _isWithdrawing = true);
                          try {
                            await _apiService.withdrawBroker(
                              amount: amount,
                              phoneNumber: phoneController.text,
                              provider: provider,
                              payeeName: database.get('username'),
                            );
                            if (mounted) {
                              Navigator.pop(dialogContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        "Withdrawal request submitted")),
                              );
                              _loadBrokerDashboard();
                            }
                          } catch (e) {
                            if (mounted) {
                              Navigator.pop(dialogContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Withdrawal failed: $e")),
                              );
                            }
                          }
                        },
                  child: _isWithdrawing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text("Withdraw",
                          style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showUnsubscribeDialog() {
    final passwordController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Unsubscribe Account"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "This will deactivate your broker account and revoke your session. This action cannot be undone.",
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: "Confirm password",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: _isUnsubscribing
                      ? null
                      : () async {
                          setDialogState(() => _isUnsubscribing = true);
                          try {
                            await _apiService.unsubscribeBroker(
                              brokerCode: database.get('brokerCode') ?? '',
                              password: passwordController.text,
                              sessionId: database.get('sessionID'),
                            );
                            if (mounted) {
                              Navigator.pop(dialogContext);
                              await forceLogout(context);
                            }
                          } catch (e) {
                            if (mounted) {
                              Navigator.pop(dialogContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Unsubscribe failed: $e")),
                              );
                            }
                          }
                        },
                  child: _isUnsubscribing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text("Unsubscribe",
                          style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatAmount(dynamic value) {
    final num = (value is double)
        ? value
        : double.tryParse(value.toString()) ?? 0;
    return num
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (m) => '${m[1]},');
  }

  @override
  void initState() {
    super.initState();
    isTenant = database.get('accountType') == 'tenant' ? true : false;
    _loadBrokerDashboard();
    _getLocationUpdates();

    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);

    _animation = Tween<double>(begin: 1, end: 1.2).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  getLocationString(location) async {
    try {
      final data = await NetworkService.get(
          'http://127.0.0.1:4000/gate-way/get-current-location?lat=${location.latitude}&longitude=${location.longitude}');
      if (data is Map) {
        return data['location']?.toString() ??
            data['address']?.toString() ??
            data['place']?.toString() ??
            'Unknown location';
      }
      return data?.toString() ?? 'Unknown location';
    } catch (e) {
      print(e);
      return 'Location unavailable';
    }
  }

  Future<void> _getLocationUpdates() async {
    try {
      bool _serviceEnabled;
      PermissionStatus _permissionGranted;

      _serviceEnabled = await _location.serviceEnabled();
      if (!_serviceEnabled) {
       _serviceEnabled = await _location.requestService();
       if (!_serviceEnabled) {
         if (mounted) setState(() => _locationLoading = false);
         return;
       }
      }

      _permissionGranted = await _location.hasPermission();
      if (_permissionGranted == PermissionStatus.denied) {
       _permissionGranted = await _location.requestPermission();
       if (_permissionGranted != PermissionStatus.granted) {
         if (mounted) setState(() => _locationLoading = false);
         return;
       }
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
                position: _destination,
                infoWindow: InfoWindow(title: "Destination"),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueBlue),
              ),
            };
          });

          database.put('location', _currentLocation);
          //    _getDirections();
        }
      });

           locationString = await getLocationString(_currentLocation);
           if (mounted) setState(() => _locationLoading = false);
    } catch (e) {
      print("Error getting location updates: $e");
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentLocation =
        _currentLocation ?? database.get('location'); // Example location

    return Scaffold(
        backgroundColor: context.appSurface,
        body: SafeArea(
          child: ThemedPageBackground(
            child: SingleChildScrollView(
               child: Column(
                children: [
                  const SizedBox(height: 20),
                  _buildLocationCard(),

                /* Withdraw funds button (brokers only)
                (isTenant != true)
                    ? _buildMenuItem(Icons.account_balance_wallet, "Withdraw Funds",
                        onTap: _showWithdrawDialog)
                    : const SizedBox.shrink(),
                SizedBox(height: 5.0),
*/

                // Menu items
                _buildMenuItem(Icons.calendar_today, "My Bookings", onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => BookingsPage()),
                  );
                }),
                SizedBox(height: 5.0),
                (isTenant != true)
                    ? _buildMenuItem(Icons.payment, "Payments", onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => PaymentsPage()),
                        );
                      })
                    : SizedBox.shrink(),
                SizedBox(height: 5.0),
                /*
                _buildMenuItem(Icons.person, "Profile", onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ProfilePageEdit()),
                  );
                }),
                SizedBox(height: 5.0),
                */
                
                /*(isTenant != true)
                    ? _buildMenuItem(Icons.house_sharp, "Upload asset",
                        onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => PropertiesPage()),
                        );
                      })
                    : const SizedBox.shrink(),*/

                SizedBox(height: 5.0),
                _buildMenuItem(Icons.notifications, "Notification", onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => NotificationsPage()),
                  );
                }),
                  SizedBox(height: 5.0),
               
               /* _buildMenuItem(Icons.favorite, "My Favourites", onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => FavouritePage()),
                  );
                }),
                SizedBox(height: 5.0),
                  */

             //   _buildMenuItem(Icons.lock, "Security"),
             //   SizedBox(height: 5.0),

                _buildMenuItem(Icons.language, "Language",
                    trailing: const Text("English (US)")),
                SizedBox(height: 5.0),
                _buildMenuItem(
                  Icons.settings,
                  "Settings",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SettingsPage()),
                    );
                  },
                ),
                SizedBox(height: 5.0),
                _buildMenuItem(Icons.help_outline, "Help Center", onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => HelpCenterPage()),
                  );
                }),
                SizedBox(height: 5.0),
                _buildMenuItem(Icons.description_outlined, "Terms of Agreement",
                    onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const TermsOfServicePage()),
                  );
                }),
                SizedBox(height: 5.0),
                _buildMenuItem(Icons.group, "Invite Friends"),

                Divider(color: context.appDividerColor),

                // Unsubscribe widget (brokers only)
               /* (isTenant != true)
                    ? ListTile(
                        leading: const Icon(Icons.cancel_presentation,
                            color: Colors.orange),
                        title: const Text(
                          "Unsubscribe Account",
                          style: TextStyle(color: Colors.orange),
                        ),
                        subtitle: const Text(
                          "Deactivate your broker account",
                          style: TextStyle(fontSize: 12),
                        ),
                        onTap: _showUnsubscribeDialog,
                      )
                    : const SizedBox.shrink(),
                    */

               /* ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: Text(
                    "Logout",
                    style: TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                  onTap: () {
                    showLogoutWarning(context);
                  },
                ),
                */
              ],
            ),
          ),
         )));
  }

  Widget _buildLocationCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appCardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.grey.shade700
              : const Color(0xFFA9710E).withOpacity(0.25),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFA9710E).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.place_rounded,
              color: Color(0xFFA9710E),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Location',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey.shade400 : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                _locationLoading
                    ? Row(
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: const Color(0xFFA9710E),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Detecting location...',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        locationString.isNotEmpty
                            ? locationString
                            : 'Location not available',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title,
      {Widget? trailing, VoidCallback? onTap}) {
    return Container(
        color: context.appCardColor,
        child: ListTile(
          leading: Icon(icon, color: context.appPrimaryBrown),
          title: Text(title, style: const TextStyle(fontSize: 16)),
          trailing: trailing ??
              Icon(Icons.arrow_forward_ios, size: 16, color: context.appMutedTextColor),
          onTap: onTap,
        ));
  }

  Widget _buildBrokerDetailsCard() {
    if (isTenant) return const SizedBox.shrink();

    if (_isLoadingDashboard && _brokerDashboard == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: ZLoadingIndicator(
            color: Color.fromARGB(255, 169, 97, 14),
          ),
        ),
      );
    }

    final broker = _brokerDashboard ?? {};
    final brokerCode = broker['brokerCode']?.toString() ??
        database.get('brokerCode')?.toString() ??
        '—';
    final tier = broker['subscriptionTier']?.toString() ?? 'prop';
    final walletBalance = broker['walletBalance'] ?? 0;
    final phone = broker['phoneNumber']?.toString() ?? '—';
    final minWithdraw = broker['minimumWithdrawal'] ?? 0;

    return Container(
      color: context.appCardColor,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Broker Account",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: context.appPrimaryBrown,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryBrown.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  tier.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBrown,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _detailRow(Icons.badge, "Broker Code", brokerCode),
          _detailRow(Icons.phone, "Phone", phone),
          _detailRow(Icons.account_balance_wallet, "Wallet Balance",
              "UGX ${_formatAmount(walletBalance)}"),
          _detailRow(Icons.money_off, "Min. Withdrawal",
              "UGX ${_formatAmount(minWithdraw)}"),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: context.appMutedTextColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: context.appMutedTextColor),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
