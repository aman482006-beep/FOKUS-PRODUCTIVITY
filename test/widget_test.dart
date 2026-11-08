import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fokus/core/app.dart';
import 'package:fokus/services/storage_service.dart';

void main() {
  testWidgets('App launches without errors', (WidgetTester tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    StorageService.prefs = await SharedPreferences.getInstance();

    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // Just verify the app can build without throwing
    await tester.pumpWidget(const ProviderScope(child: FocusApp()));
    await tester.pump();
    // If we get here without an error, the smoke test passes
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
