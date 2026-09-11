import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:zcanopy/pages/itemDetails.dart';
import 'package:zcanopy/theme/app_theme.dart';

Map<String, dynamic> sampleProperty() => {
      'id': 'p1',
      'type': 'House',
      'name': 'Bungalow in Ntinda',
      'price': 250000000,
      'location': 'Ntinda',
      'subCounty': 'Ntinda',
      'district': 'Kampala Central',
      'status': 'Available',
      'image': 'https://picsum.photos/400/200?1',
      'uploadDate': '2024-05-12',
      'description':
          'Mutaasa brokers, 1 dining room, 2 toilets, spacious compound, secure gated community.',
      'mapLocation': {'lat': 0.3476, 'lng': 32.5825},
      'video': '',
      'brokerCode': 'BRK-MUTAASA',
      'brokerName': 'Mutaasa Brokers',
      'brokerPhone': '+256701234567',
      'bookState': {'isBooked': false, 'bookingCount': 0},
      'bookedCount': 0,
    };

void main() {
  setUpAll(() async {
    Directory.current = Directory.systemTemp;
    if (Hive.isBoxOpen('myStore')) {
      await Hive.close();
    }
    final dir = await Directory.systemTemp.createTemp('zcanopy_test');
    Hive.init(dir.path);
    await Hive.openBox('myStore');
  });

  tearDownAll(() async {
    await Hive.close();
  });

  testWidgets('property details page renders all sections', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: PropertyDetailsPage(property: sampleProperty()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Bungalow in Ntinda', skipOffstage: false), findsOneWidget);
    expect(find.text('Available', skipOffstage: false), findsWidgets);
    expect(find.textContaining('250,000,000', skipOffstage: false),
        findsWidgets);
    expect(find.text('House', skipOffstage: false), findsOneWidget);
    expect(find.textContaining('Beds', skipOffstage: false), findsOneWidget);
    expect(find.textContaining('Bath', skipOffstage: false), findsOneWidget);
    expect(find.text('Mutaasa Brokers', skipOffstage: false), findsWidgets);
    expect(find.textContaining('WhatsApp', skipOffstage: false),
        findsWidgets);
    expect(find.text('Open in Google Maps', skipOffstage: false),
        findsOneWidget);
    expect(find.text('Reviews & Comments', skipOffstage: false),
        findsOneWidget);
    expect(find.text('Book tour', skipOffstage: false), findsOneWidget);
    expect(find.text('Booking fee', skipOffstage: false), findsOneWidget);
    expect(find.text('UGX 20,000', skipOffstage: false), findsOneWidget);
    expect(find.text('Similar Properties', skipOffstage: false),
        findsOneWidget);
    expect(find.text('Submit review', skipOffstage: false), findsNothing);

    await tester.dragFrom(const Offset(400, 500), const Offset(0, -700));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text('Reviews & Comments', skipOffstage: false),
      findsOneWidget,
    );
    expect(
      tester
          .getRect(find.text('Reviews & Comments', skipOffstage: false))
          .top,
      lessThan(600),
    );
  });
}