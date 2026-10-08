import 'package:flutter/material.dart';
import 'package:zcanopy/pages/welcome.dart';
import 'package:zcanopy/pages/loadIndicator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:zcanopy/pages/session.dart';
import 'package:zcanopy/utils/colors.dart';
import 'package:zcanopy/pages/bookings.dart';
import 'package:zcanopy/pages/payments.dart';
import 'package:zcanopy/pages/properties.dart';
import 'package:zcanopy/utils/theme_extensions.dart';
import 'package:zcanopy/services/gateway_api.dart';
import 'package:zcanopy/utils/property_normalizer.dart';

/// Notification categories the page is able to receive and render.
enum NotificationCategory {
  booking, // booking requests from customers
  payment, // payment messages / receipts / reminders
  propertyRemoved, // admin property removal notices
  propertyUpload, // admin property upload / review messages
  system, // system / admin announcements
}

class NotificationsPage extends StatefulWidget {
  @override
  _NotificationsPageState createState() => _NotificationsPageState();

  // Static method to count unread notifications
  static int countUnreadNotifications(
      List<Map<String, dynamic>> notifications) {
    return notifications.where((notification) => !(notification['read'] ?? false)).length;
  }
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool isGettingNotifs = false;
  bool isLoading = true;
  bool isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();
  final int notesPerPage = 10;
  List<Map<String, dynamic>> _notifications = [];
  List<Map<String, dynamic>> displayedNotifs = [];
  final database = Hive.box('myStore');
  final box = Hive.box('notifications');
  final _api = GatewayApi();
  var userID;

  // Filter chips shown at the top of the page
  final List<String> _filters = [
    'all',
    'booking',
    'payment',
    'propertyRemoved',
    'propertyUpload',
    'system',
  ];
  String _activeFilter = 'all';

  @override
  void initState() {
    super.initState();
    userID = database.get('userID');
    loadInitialData();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !isLoadingMore &&
        displayedNotifs.length < _visibleNotifications().length) {
      loadMoreData();
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
      return;
    }

    // Load cached notifications immediately while fetching fresh ones.
    final cached = box.get('items');
    if (cached != null && cached is List) {
      setState(() {
        _notifications = List<Map<String, dynamic>>.from(cached);
        displayedNotifs = _visibleNotifications().take(notesPerPage).toList();
      });
    }

    await _getNotif(refresh: true);
  }

  Future<void> loadMoreData() async {
    if (isLoadingMore) return;
    setState(() => isLoadingMore = true);

    await Future.delayed(const Duration(milliseconds: 600));
    setState(() {
      final visible = _visibleNotifications();
      final start = displayedNotifs.length;
      final end = (start + notesPerPage).clamp(0, visible.length);
      displayedNotifs.addAll(visible.sublist(start, end));
      isLoadingMore = false;
    });
  }

  List<Map<String, dynamic>> _visibleNotifications() {
    if (_activeFilter == 'all') return _notifications;
    return _notifications
        .where((n) => (n['type'] ?? '') == _activeFilter)
        .toList();
  }

  void _applyFilter(String filter) {
    setState(() {
      _activeFilter = filter;
      displayedNotifs = _visibleNotifications().take(notesPerPage).toList();
    });
  }

  Future<void> _getNotif({bool refresh = false}) async {
    if (isGettingNotifs) return;
    setState(() => isGettingNotifs = true);

    try {
      final response = await _api.getNotifications(page: 1, limit: 50);
      var fetched = normalizeNotifications(response['notifications']);

      if (fetched.isNotEmpty) {
        final localById = {
          for (var n in _notifications)
            if (n['id'] != null) n['id']: n
        };
        fetched = fetched.map((n) {
          final id = n['id'];
          if (id != null && localById.containsKey(id)) {
            return {...n, 'read': localById[id]?['read'] ?? n['read']};
          }
          return n;
        }).toList();

        await box.put('items', fetched);
      }

      if (mounted) {
        setState(() {
          _notifications = fetched;
          displayedNotifs = _visibleNotifications().take(notesPerPage).toList();
        });
      }
    } on ApiException catch (e) {
      debugPrint("Notifications error: ${e.message}");
    } catch (e) {
      debugPrint("Network error: $e");
    } finally {
      if (mounted) {
        setState(() => isGettingNotifs = false);
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _persistNotifications() async {
    await box.put('items', _notifications);
  }

  Future<void> _markAsReadOnServer(String? id) async {
    if (id == null || id.toString().isEmpty) return;
    try {
      await _api.markNotificationsRead(id: id);
    } catch (e) {
      debugPrint("Mark as read error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Notifications",
          style: TextStyle(
            color: context.isDarkMode ? Colors.white : Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: context.isDarkMode ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.mark_chat_read,
              color: context.isDarkMode ? Colors.white : Colors.black,
            ),
            onPressed: _markAllAsRead,
          ),
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: context.isDarkMode ? Colors.white : Colors.black,
            ),
            onPressed: () => _getNotif(refresh: true),
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
          child: isLoading
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                      child: ZLoadingIndicator(
                    size: 25,
                    strokeWidth: 2,
                    color: AppColors.primaryBrown,
                  )),
                )
              : Column(
                  children: [
                    _buildFilterChips(),
                    Expanded(
                      child: _notifications.isEmpty
                          ? _buildEmptyState()
                          :                             ListView.builder(
                              controller: _scrollController,
                              padding: EdgeInsets.zero,
                              itemCount:
                                  displayedNotifs.length + (isLoadingMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index < displayedNotifs.length) {
                                  return _buildNotificationItem(
                                      displayedNotifs[index], index);
                                } else {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 20),
                                    child: Center(
                                        child: ZLoadingIndicator(
                                      size: 22,
                                      strokeWidth: 2,
                                      color: AppColors.primaryBrown,
                                    )),
                                  );
                                }
                              },
                            ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _filters.map((filter) {
            final isActive = _activeFilter == filter;
            final label = filter == 'all'
                ? 'All'
                : filter == 'propertyRemoved'
                    ? 'Removed'
                    : filter == 'propertyUpload'
                        ? 'Uploads'
                        : filter[0].toUpperCase() + filter.substring(1);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: Text(label),
                selected: isActive,
                selectedColor: AppColors.primaryBrown,
                labelStyle: TextStyle(
                  color: isActive ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
                onSelected: (_) => _applyFilter(filter),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> notification, int index) {
    final read = notification['read'] ?? false;
    final divider = Divider(
      height: 1,
      thickness: 1,
      color: context.isDarkMode
          ? Colors.grey.shade800
          : Colors.grey.shade200,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          color: context.isDarkMode
              ? (read ? Colors.transparent : const Color(0xFF223047))
              : (read ? Colors.transparent : Color(0xFFEFF5FF)),
          child: InkWell(
            onTap: () => _onNotificationTap(notification),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildNotificationIcon(notification['type']),
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
                                notification['title'] ?? '',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: read
                                      ? FontWeight.w500
                                      : FontWeight.w700,
                                  color: context.isDarkMode
                                      ? Colors.white
                                      : Colors.black,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (!read)
                              Container(
                                margin: const EdgeInsets.only(top: 5),
                                width: 9,
                                height: 9,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryBrown,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notification['message'] ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            color: context.isDarkMode
                                ? Colors.grey.shade400
                                : Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          notification['time'] ?? '',
                          style: TextStyle(
                            fontSize: 11,
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
        ),
        divider,
      ],
    );
  }

  Widget _buildNotificationIcon(String? type) {
    switch (type) {
      case 'booking':
        return _iconCircle(Icons.calendar_today, AppColors.primaryBrown);
      case 'payment':
        return _iconCircle(Icons.account_balance_wallet_outlined, Colors.green);
      case 'propertyUpload':
        return _iconCircle(Icons.upload_file_outlined, Colors.blue);
      case 'propertyRemoved':
        return _iconCircle(Icons.delete_outline, Colors.red);
      case 'system':
        return _iconCircle(Icons.admin_panel_settings_outlined, Colors.purple);
      case 'new_property':
        return _iconCircle(Icons.home_outlined, AppColors.primaryBrown);
      case 'transaction':
        return _iconCircle(
            Icons.account_balance_wallet_outlined, Colors.green);
      default:
        return _iconCircle(Icons.notifications_outlined, Colors.grey);
    }
  }

  Widget _iconCircle(IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: color,
        size: 24,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_outlined,
            size: 80,
            color: Colors.grey[300],
          ),
          SizedBox(height: 20),
          Text(
            "No notifications yet",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 10),
          Text(
            "We'll notify you when there's something new",
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

  void _onNotificationTap(Map<String, dynamic> notification) {
    final wasUnread = !(notification['read'] ?? false);
    setState(() {
      notification['read'] = true;
    });
    _persistNotifications();
    if (wasUnread) _markAsReadOnServer(notification['id']);

    // Route the user to the most relevant screen for the notification type.
    switch (notification['type']) {
      case 'booking':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => BookingsPage()),
        );
        break;
      case 'payment':
      case 'transaction':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PaymentsPage()),
        );
        break;
      case 'propertyUpload':
      case 'propertyRemoved':
      case 'new_property':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PropertiesPage()),
        );
        break;
      case 'system':
      default:
        // System / admin messages stay on the notifications page.
        break;
    }
  }

  void _markAllAsRead() {
    setState(() {
      for (var notification in _notifications) {
        notification['read'] = true;
      }
    });
    _persistNotifications();
    _api.markNotificationsRead(all: true).catchError((_) => <String, dynamic>{});

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("All notifications marked as read"),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
