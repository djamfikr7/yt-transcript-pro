import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yt_transcript_pro/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const YTTranscriptProApp());

    // Verify app renders
    expect(find.text('YT Transcript Pro'), findsOneWidget);

    // Verify main UI elements
    expect(find.text('Projects'), findsOneWidget);
    expect(find.text('Transcript'), findsOneWidget);
  });
}
