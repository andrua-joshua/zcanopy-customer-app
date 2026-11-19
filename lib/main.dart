
import 'package:flutter/material.dart';
import 'package:zcanopy/pages/welcome.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:zcanopy/services/notification_service.dart';
import 'package:zcanopy/pages/homeScreen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:zcanopy/theme/app_theme.dart';
import 'package:zcanopy/theme/theme_controller.dart';
import 'package:zcanopy/services/property_monitor_service.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Handle messages when app is in background
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await Hive.initFlutter();
  var box = await Hive.openBox('notifications');
  await box.add({
    "title": message.notification?.title ?? "ZCanopy Update",
    "body": message.notification?.body ?? "",
    "time": DateTime.now().toString(),
  });

  _showNotification(message);
  try {
    FlutterAppBadger.updateBadgeCount(1);
  } catch (_) {}
}

void _showNotification(RemoteMessage message) async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
        'zcanopy_channel',
        'ZCanopy Alerts',
        importance: Importance.max,
        priority: Priority.high,
        icon: 'taskBar',
      );
  const NotificationDetails platformChannelSpecifics = NotificationDetails(
    android: androidPlatformChannelSpecifics,
  );

  await flutterLocalNotificationsPlugin.show(
    0,
    message.notification?.title ?? 'ZCanopy Update',
    message.notification?.body ?? 'You have a new update!',
    platformChannelSpecifics,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('myStore');
  await Hive.openBox('notifications');

  themeController.init();

  // Run the app immediately to show splash
  runApp(const ZCanopy());

  // Initialize async services in background
  await _initializeServices();
}

Future<void> _initializeServices() async {
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('taskBar');
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // Initialize Hive
  await Hive.initFlutter();
  await Hive.openBox('myStore');
  await Hive.openBox('notifications');
  await Hive.openBox('propertyMonitor');

  await MobileAds.instance.initialize();

  PropertyMonitorService.navigatorKey = navigatorKey;
  await PropertyMonitorService().init();
  PropertyMonitorService().startMonitoring();
}

class ZCanopy extends StatelessWidget {
  const ZCanopy({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeController,
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeController.themeMode,
          home: const SplashWrapper(),
        );
      },
    );
  }
}

class SplashWrapper extends StatefulWidget {
  const SplashWrapper({super.key});

  @override
  State<SplashWrapper> createState() => _SplashWrapperState();
}

class _SplashWrapperState extends State<SplashWrapper> {
  final database = Hive.box('myStore');
  late Box notificationsBox;
  var userID;

  @override
  void initState() {
    super.initState();
    notificationsBox = Hive.box('notifications');
    userID = database.get('userID');
    _initSettings();
    mockFirebaseMessage();

    NotificationService().init();

    // Navigate after short delay
    Future.delayed(const Duration(seconds: 3), () {
      _handleNavigation();
    });
  }

  void _initSettings() async {
    await Firebase.initializeApp();

    FirebaseMessaging.instance.getToken().then((token) {
      debugPrint('FCM Token: $token');
    });

    // Foreground notifications
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      await _storeNotification(message);

//incase the backend forces us to logut / revoke the session
 if (message.data['action'] == 'LOGOUT') {
    Hive.box('myStore').clear();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const OnBoardingScreen()),
    );
  }
  else{
   _showNotification(message);
      setState(() {}); // refresh UI if needed
  }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      await _storeNotification(message);
      debugPrint('Notification clicked!');
    });
  }

  Future<void> mockFirebaseMessage() async {
    final message = RemoteMessage(
      notification: RemoteNotification(
        title: 'Mock FCM',
        body: 'Stored + displayed like real FCM',
      ),
    );

    await _storeNotification(message);
    _showNotification(message);
  }

  Future<void> _storeNotification(RemoteMessage message) async {
    await notificationsBox.add({
      "title": message.notification?.title ?? "ZCanopy Alert",
      "body": message.notification?.body ?? "",
      "time": DateTime.now().toString(),
    });
  }

  void _handleNavigation() {
    // Guests browse with an anonymous session id. Signing in is optional and
    // only required for favourites, bookings, payments and notifications.
    // First launch shows onboarding; afterwards go straight home.
    final sessionID = database.get('sessionID');

    if (sessionID == null || sessionID.toString().isEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OnBoardingScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => BottomNavBar()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const SplashScreen();
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Image.asset('assets/splashScreen.png', fit: BoxFit.cover),
      ),
    );
  }
}
