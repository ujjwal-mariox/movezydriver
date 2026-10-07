import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:movezy_driver_app/Screens/BookingsDetailsScreen/pickup_trip_sheet.dart';
import 'package:movezy_driver_app/Screens/TechnicianDashboard/Model/driver_dashboard_response.dart';
import 'package:movezy_driver_app/Utils/Localization/app_translations.dart';

DashboardBooking fixture({
  bool long = false,
  bool addons = true,
  bool missing = false,
  String status = 'ASSIGNED',
}) => DashboardBooking.fromJson({
  'id': 'regression-booking',
  'bookingNumber': long ? 'REGRESSION-' * 12 : 'REGRESSION',
  'serviceType': 'OUTSTATION',
  'status': status,
  'customerName': missing
      ? ''
      : long
      ? 'A customer with a very long name ' * 8
      : 'Regression customer',
  'pickup': {
    'address': missing
        ? ''
        : long
        ? 'A long pickup address with building and locality details ' * 12
        : 'Regression pickup address',
    'lat': 12,
    'lng': 77,
  },
  'drop': {'address': 'Regression drop address', 'lat': 13, 'lng': 78},
  'vehicleTypeName': long
      ? 'A long vehicle category description ' * 8
      : 'Regression vehicle',
  'goodsType': 'Regression parcel category',
  'goodsDescription': long ? 'Parcel description ' * 15 : 'Parcel description',
  'distanceKm': missing ? 0 : 23.4,
  'durationMin': missing ? 0 : 58,
  'estimatedFare': missing ? double.nan : 12456,
  'estimatedEarnings': missing ? 0 : 9876,
  'customerTotal': missing ? double.nan : 12456,
  'gstAmount': 500,
  'commissionAmount': 2080,
  'commissionPercent': 20,
  'paymentMethod': missing
      ? ''
      : long
      ? 'A very long payment method description ' * 8
      : 'WALLET',
  'addons': addons
      ? List.generate(
          long ? 8 : 2,
          (i) => {
            'name': long
                ? 'Loading and packing requirement $i ' * 10
                : 'Requirement $i',
            'price': 120 + i,
            'quantity': i + 1,
          },
        )
      : [],
  'loadingUnloading': addons
      ? {'type': 'LOADING', 'pickupFloor': 3, 'dropFloor': 4, 'charge': 120}
      : null,
  'stops': [
    {'address': 'Regression intermediate stop', 'lat': 12.5, 'lng': 77.5},
  ],
});

Future<void> mount(
  WidgetTester tester, {
  DashboardBooking? booking,
  Size size = const Size(360, 800),
  double scale = 1,
  Map<String, int>? counts,
  Future<void> Function()? arrive,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  void action(String name) {
    if (counts != null) counts[name] = (counts[name] ?? 0) + 1;
  }

  await tester.pumpWidget(
    GetMaterialApp(
      theme: const String.fromEnvironment('PICKUP_PREVIEW_FONT_DIR').isEmpty
          ? null
          : ThemeData(fontFamily: 'Roboto'),
      translations: AppTranslations(),
      locale: const Locale('en', 'IN'),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: const EdgeInsets.only(top: 24, bottom: 34),
            textScaler: TextScaler.linear(scale),
          ),
          child: RepaintBoundary(
            key: const ValueKey('pickup-qa-frame'),
            child: Scaffold(
              body: Stack(
                children: [
                  const Positioned.fill(
                    child: ColoredBox(color: Color(0xFFE8ECEF)),
                  ),
                  PickupTripSheet(
                    booking: booking ?? fixture(),
                    startTime: '--',
                    isArriving: false,
                    onCall: () => action('call'),
                    onChat: () => action('chat'),
                    onDirections: () => action('directions'),
                    onHelp: () => action('help'),
                    onTicket: () => action('ticket'),
                    onCancel: () => action('cancel'),
                    onArrived:
                        arrive ??
                        () async {
                          action('arrived');
                        },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

DraggableScrollableSheet sheet(WidgetTester tester) =>
    tester.widget(find.byType(DraggableScrollableSheet));
Future<void> expand(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('pickup-sheet-handle')));
  await tester.pumpAndSettle();
}

Future<void> savePreview(WidgetTester tester, String name) async {
  const directory = String.fromEnvironment('PICKUP_PREVIEW_DIR');
  if (directory.isEmpty) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('pickup-qa-frame')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(directory).create(recursive: true);
    await File('$directory/$name.png').writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> reveal(WidgetTester tester, String key) async {
  await tester.scrollUntilVisible(
    find.byKey(ValueKey(key)),
    170,
    maxScrolls: 250,
    scrollable: find.descendant(
      of: find.byKey(const ValueKey('pickup-sheet-scroll')),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    const fonts = String.fromEnvironment('PICKUP_PREVIEW_FONT_DIR');
    if (fonts.isEmpty) return;
    for (final entry in {
      'Roboto': 'roboto-regular.ttf',
      'MaterialIcons': 'materialicons-regular.otf',
    }.entries) {
      final loader = FontLoader(entry.key)
        ..addFont(
          File(
            '$fonts/${entry.value}',
          ).readAsBytes().then(ByteData.sublistView),
        );
      await loader.load();
    }
  });
  testWidgets(
    'starts at 42 percent with map space and keeps secondary details hidden',
    (tester) async {
      await mount(tester);
      final surface = tester.getSize(
        find.byKey(const ValueKey('pickup-sheet-surface')),
      );
      expect(surface.height / 800, closeTo(.42, .005));
      expect(find.text('Booking Details'), findsNothing);
      expect(find.byKey(const ValueKey('pickup-cancel')), findsNothing);
      expect(
        find.byKey(const ValueKey('pickup-arrival-action')),
        findsOneWidget,
      );
      expect(find.text('Regression pickup address'), findsOneWidget);
      expect(find.text('Regression customer'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await savePreview(tester, 'driver-pickup-default');
    },
  );

  testWidgets(
    'handle toggles and velocity drag reaches all three snap positions',
    (tester) async {
      await mount(tester);
      await expand(tester);
      expect(sheet(tester).controller!.size, closeTo(.85, .005));
      expect(find.text('Booking Details'), findsOneWidget);
      await savePreview(tester, 'driver-pickup-expanded');
      await expand(tester);
      expect(sheet(tester).controller!.size, closeTo(.42, .005));
      await tester.fling(
        find.byKey(const ValueKey('pickup-sheet-handle')),
        const Offset(0, 200),
        1800,
      );
      await tester.pumpAndSettle();
      expect(
        sheet(tester).controller!.size,
        closeTo(sheet(tester).minChildSize, .005),
      );
      await savePreview(tester, 'driver-pickup-collapsed');
      await expand(tester);
      expect(sheet(tester).controller!.size, closeTo(.42, .005));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'noninteractive pickup region expands while Call and Chat do not toggle the sheet',
    (tester) async {
      final counts = <String, int>{};
      await mount(tester, counts: counts);
      await tester.tap(find.byKey(const ValueKey('pickup-call')));
      await tester.tap(find.byKey(const ValueKey('pickup-chat')));
      await tester.pumpAndSettle();
      expect(counts, {'call': 1, 'chat': 1});
      expect(sheet(tester).controller!.size, closeTo(.42, .005));
      await tester.tap(find.text('Regression pickup address'));
      await tester.pumpAndSettle();
      expect(sheet(tester).controller!.size, closeTo(.85, .005));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'body dragging and expanded scrolling cooperate; pulling from the top collapses',
    (tester) async {
      await mount(tester, booking: fixture(long: true));
      await tester.drag(
        find.byKey(const ValueKey('pickup-sheet-scroll')),
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
      expect(sheet(tester).controller!.size, closeTo(.85, .01));
      final scroll = tester
          .widget<ListView>(find.byKey(const ValueKey('pickup-sheet-scroll')))
          .controller!;
      await tester.drag(
        find.byKey(const ValueKey('pickup-sheet-scroll')),
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
      expect(scroll.offset, greaterThan(0));
      scroll.jumpTo(0);
      await tester.pump();
      await tester.drag(
        find.byKey(const ValueKey('pickup-sheet-scroll')),
        const Offset(0, 350),
      );
      await tester.pumpAndSettle();
      expect(sheet(tester).controller!.size, lessThan(.85));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'details retain actions and arrival stays fixed while internal content scrolls',
    (tester) async {
      final counts = <String, int>{};
      await mount(tester, counts: counts);
      final originalY = tester
          .getTopLeft(find.byKey(const ValueKey('pickup-arrival-action')))
          .dy;
      await expand(tester);
      for (final action in ['directions', 'help', 'ticket', 'cancel']) {
        await reveal(tester, 'pickup-$action');
        await tester.tap(find.byKey(ValueKey('pickup-$action')));
        await tester.pumpAndSettle();
        expect(counts[action], 1);
        expect(
          tester
              .getTopLeft(find.byKey(const ValueKey('pickup-arrival-action')))
              .dy,
          originalY,
        );
      }
      final ctaBottom = tester
          .getBottomLeft(find.byKey(const ValueKey('pickup-arrival-action')))
          .dy;
      expect(ctaBottom, lessThanOrEqualTo(800 - 34 - 12));
      await tester.tap(find.byKey(const ValueKey('pickup-arrival-action')));
      await tester.pumpAndSettle();
      expect(counts['arrived'], 1);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [
    const Size(320, 568),
    const Size(360, 800),
    const Size(700, 360),
  ]) {
    testWidgets(
      'long dynamic content at 2x font scale fits $size in every sheet state',
      (tester) async {
        await mount(tester, booking: fixture(long: true), size: size, scale: 2);
        expect(tester.takeException(), isNull);
        final defaultScroll = tester
            .widget<ListView>(find.byKey(const ValueKey('pickup-sheet-scroll')))
            .controller!;
        defaultScroll.jumpTo(defaultScroll.position.maxScrollExtent);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expand(tester);
        await reveal(tester, 'pickup-ticket');
        expect(
          find.byKey(const ValueKey('pickup-arrival-action')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.fling(
          find.byKey(const ValueKey('pickup-sheet-handle')),
          const Offset(0, 200),
          1600,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'missing optional values omit sections and never display NaN or a fake estimate',
    (tester) async {
      await mount(
        tester,
        booking: fixture(missing: true, addons: false, status: 'PICKED'),
      );
      expect(find.text('Trip estimate unavailable'), findsOneWidget);
      await expand(tester);
      final scroll = tester
          .widget<ListView>(find.byKey(const ValueKey('pickup-sheet-scroll')))
          .controller!;
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(find.text('ADD-ON SERVICES'), findsNothing);
      expect(find.byKey(const ValueKey('pickup-cancel')), findsNothing);
      expect(find.textContaining('NaN'), findsNothing);
      expect(find.textContaining('undefined'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'arrival blocks repeated taps until the original handler finishes',
    (tester) async {
      final pending = Completer<void>();
      var calls = 0;
      await mount(
        tester,
        arrive: () {
          calls++;
          return pending.future;
        },
      );
      await tester.tap(find.byKey(const ValueKey('pickup-arrival-action')));
      await tester.pump();
      expect(find.byKey(const ValueKey('pickup-arrival-busy')), findsOneWidget);
      expect(calls, 1);
      pending.complete();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('pickup-arrival-action')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
