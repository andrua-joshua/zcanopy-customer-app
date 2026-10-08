import 'package:flutter/material.dart';
import 'package:zcanopy/pages/welcome.dart';
import 'package:zcanopy/pages/loadIndicator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:zcanopy/pages/session.dart';
import 'package:zcanopy/utils/theme_extensions.dart';
import 'package:zcanopy/services/gateway_api.dart';
import 'package:zcanopy/utils/colors.dart';
import 'package:zcanopy/utils/property_normalizer.dart';


class BookingsPage extends StatefulWidget {
  const BookingsPage({super.key});

  @override
  State<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends State<BookingsPage> {
  bool isLoading = false;
  bool isLoadingMore = false;
  bool _isRetrieving = false;
  final database = Hive.box('myStore');
  final _api = GatewayApi();
  int _page = 1;
  bool _hasMore = true;
  var userID;
  final ScrollController _scrollController = ScrollController();
  TextEditingController numberEditCtrl = TextEditingController();
  final TextEditingController _codeCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  String _retrievedCode = '';
  String _retrievedPhone = '';

  List<Map<String, dynamic>> bookings = [];
  final int bookingsPerPage = 4;
  List<Map<String, dynamic>> displayedBookings = [];

  @override
  void initState() {
    super.initState();
    // Pre-fill with values persisted locally after a successful payment.
    _codeCtrl.text = database.get('customerCode')?.toString() ?? '';
    _phoneCtrl.text = database.get('phoneNumber')?.toString() ?? '';
    // Prefer retrieval by the unique customer code + phone number.
    final storedCode = _codeCtrl.text;
    final storedPhone = _phoneCtrl.text;
    if (storedCode.isNotEmpty && storedPhone.isNotEmpty) {
      _retrieveBookings(storedCode, storedPhone);
    } else {
      loadInitialData();
    }
    userID = database.get('userID');

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !isLoadingMore &&
          _hasMore) {
        loadMoreData();
      }
    });
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

  /// Retrieve the customer's bookings using the unique code issued after a
  /// successful payment together with their phone number.
  Future<void> _retrieveBookings(String code, String phone) async {
    if (code.trim().isEmpty || phone.trim().length < 9) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter both your code and phone number")),
      );
      return;
    }
    setState(() {
      _isRetrieving = true;
      isLoading = true;
      _retrievedCode = code.trim();
      _retrievedPhone = phone.trim();
    });

    try {
      final data = await _api.retrieveBookingByCode(
        bookingCode: _retrievedCode,
        customerPhone: _retrievedPhone,
      );
      final fetched = normalizeBookings(data['bookings'] ?? data['data']);
      if (mounted) {
        setState(() {
          bookings = fetched;
          displayedBookings = fetched.take(bookingsPerPage).toList();
          isLoading = false;
          _isRetrieving = false;
        });
      }
      if (fetched.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No bookings found for that code")),
        );
      }
    } on ApiException catch (e) {
      print('Error retrieving bookings: ${e.message}');
      if (mounted) {
        setState(() {
          bookings = [];
          displayedBookings = [];
          isLoading = false;
          _isRetrieving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      print('Error retrieving bookings: $e');
      if (mounted) {
        setState(() {
          displayedBookings = bookings.take(bookingsPerPage).toList();
          isLoading = false;
          _isRetrieving = false;
        });
      }
    }
  }

  Future<void> loadInitialData() async {
    final isSessionValid = await SessionService.validateSession();
    if (!isSessionValid) {
      if (mounted) await forceLogout(context);
      return;
    }

    setState(() => isLoading = true);
    try {
      final data = await _api.getCustomerBookings(
        page: 1,
        limit: bookingsPerPage,
      );
      final fetched = normalizeBookings(data['bookings']);
      if (!mounted) return;
      setState(() {
        bookings = fetched;
        displayedBookings = fetched.take(bookingsPerPage).toList();
        _page = 1;
        _hasMore = fetched.length >= bookingsPerPage;
        isLoading = false;
        isLoadingMore = false;
      });
    } on ApiException catch (e) {
      print('Error loading bookings: ${e.message}');
      if (!mounted) return;
      setState(() {
        bookings = [];
        displayedBookings = [];
        isLoading = false;
        isLoadingMore = false;
      });
    } catch (e) {
      print('Error loading bookings: $e');
      if (!mounted) return;
      setState(() {
        displayedBookings = bookings.take(bookingsPerPage).toList();
        isLoading = false;
        isLoadingMore = false;
      });
    }
  }

  Future<void> loadMoreData() async {
    if (!_hasMore || isLoadingMore) return;
    setState(() => isLoadingMore = true);
    try {
      final data = await _api.getCustomerBookings(
        page: _page + 1,
        limit: bookingsPerPage,
      );
      final fetched = normalizeBookings(data['bookings']);
      if (!mounted) return;
      setState(() {
        _page++;
        if (fetched.isNotEmpty) {
          bookings.addAll(fetched);
          displayedBookings.addAll(fetched);
        }
        _hasMore = fetched.length >= bookingsPerPage;
        isLoadingMore = false;
      });
    } catch (e) {
      print('Error loading more bookings: $e');
      if (!mounted) return;
      setState(() => isLoadingMore = false);
    }
  }

  void _declineBooking(int index, String id) async {
    try {
      await _api.declineBooking(transactionCode: id);
      if (!mounted) return;
      setState(() {
        bookings[index]["status"] = "Declined";
        if (index < displayedBookings.length) {
          displayedBookings[index]["status"] = "Declined";
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Booking declined")),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      print('Decline booking error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not decline booking")),
      );
    }
  }

  void _rejectBooking(int index) {
    setState(() {
      bookings[index]["status"] = "Pending";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Bookings",
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Color.fromARGB(255, 169, 97, 14),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () async {
              setState(() {
                isLoading = false;
                displayedBookings = [];
              });
              await Future.delayed(const Duration(seconds: 2));
           //   _getBookings();
              loadInitialData();
            },
          ),
        ],
      ),
      body: Container(
        decoration: context.isDarkMode
            ? BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor)
            : const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/background.jpg'),
                  fit: BoxFit.cover,
                ),
              ),
        child: Container(
          color: context.isDarkMode
              ? Colors.transparent
              : Colors.white.withOpacity(0.85),
          child: Column(
            children: [
              _buildRetrievalCard(),
              Expanded(
                child: displayedBookings.isEmpty && !isLoading
                    ? _buildEmptyState()
                    : isLoading
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                                child: ZLoadingIndicator(
                              size: 25,
                              strokeWidth: 2,
                              color: Color.fromARGB(255, 169, 97, 14),
                            )),
                          )
                        : ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.zero,
                  itemCount: displayedBookings.length + (isLoadingMore ? 3 : 0),
                  itemBuilder: (context, index) {
                    if (index < displayedBookings.length) {
                      return _buildBookingCard(displayedBookings[index], index);
                    } else {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                            child: ZLoadingIndicator(
                          size: 22,
                          strokeWidth: 2,
                          color: Color.fromARGB(255, 169, 97, 14),
                        )),
                      );
                    }
                  }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Card that lets the customer retrieve their bookings by entering the unique
  /// code they received after a successful payment plus their phone number.
  Widget _buildRetrievalCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      color: context.isDarkMode
          ? const Color(0xFF2A2A2A)
          : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Retrieve your bookings",
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 4),
          const Text(
            "Use the unique code from your payment invoice and your phone number.",
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _codeCtrl,
                  decoration: const InputDecoration(
                    labelText: "Booking code",
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: "Phone number",
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _isRetrieving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      onPressed: () =>
                          _retrieveBookings(_codeCtrl.text, _phoneCtrl.text),
                      icon: const Icon(Icons.search),
                      color: AppColors.primaryBrown,
                    ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking, int index) {
    final status = booking["status"];
    Color statusColor;
    Color statusBg;

    switch (status) {
      case "Approved":
        statusColor = Colors.green;
        statusBg = Colors.green.withOpacity(0.1);
        break;
      case "Rejected":
        statusColor = Colors.red;
        statusBg = Colors.red.withOpacity(0.1);
        break;
      default:
        statusColor = Colors.orange;
        statusBg = Colors.orange.withOpacity(0.1);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            if (status == "Pending") {
              _showActionDialog(context, booking, index);
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    booking["houseImg"]?.toString() ?? '',
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 56,
                      height: 56,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.home_outlined,
                          color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              booking["houseName"],
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: context.isDarkMode
                                    ? Colors.white
                                    : Colors.black,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (status != "Rejected")
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: _buildRippleDot(statusColor),
                            ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Date: ${booking["date"]}",
                        style: TextStyle(
                          fontSize: 13,
                          color: context.isDarkMode
                              ? Colors.grey.shade400
                              : Colors.grey[700],
                        ),
                      ),
                      Text(
                        "Phone: ${booking["phone"]}",
                        style: TextStyle(
                          fontSize: 13,
                          color: context.isDarkMode
                              ? Colors.grey.shade400
                              : Colors.grey[700],
                        ),
                      ),
                      Text(
                        "ID: ${booking["id"]}",
                        style: TextStyle(
                          fontSize: 12,
                          color: context.isDarkMode
                              ? Colors.grey.shade500
                              : Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Divider(
          height: 1,
          thickness: 1,
          color: context.isDarkMode
              ? Colors.grey.shade800
              : Colors.grey.shade200,
        ),
      ],
    );
  }

  /// Ripple animation for live status
  Widget _buildRippleDot(Color color) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.8, end: 1.4),
      duration: const Duration(seconds: 1),
      curve: Curves.easeInOut,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.5),
            ),
          ),
        );
      },
      onEnd: () {
        // triggers rebuild for continuous ripple
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) setState(() {});
        });
      },
    );
  }

  void _showActionDialog(
      BuildContext context, Map<String, dynamic> booking, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black87,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        title: const Text("Booking Request"),
        content: Text(
          "Decline booking for ${booking["houseName"]}?",
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _rejectBooking(index);
            },
            child: const Text("No", style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _declineBooking(index, booking['id']);
            },
            child: const Text("Yes", style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 20),
          Text(
            "No bookings yet",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "You’ll see your booking requests here",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
