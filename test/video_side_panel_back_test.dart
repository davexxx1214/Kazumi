import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/pages/video/video_side_panel.dart';

void main() {
  testWidgets('back closes the episode panel before leaving the video route', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final panelKey = GlobalKey<VideoSidePanelState>();
    var closeCount = 0;
    var routePopCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Text('previous page')),
      ),
    );
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => PopScope(
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) routePopCount++;
          },
          child: Scaffold(
            body: VideoSidePanel(
              key: panelKey,
              fullscreen: true,
              disableAnimations: true,
              onClosed: () => closeCount++,
              child: const Text('episode list'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    panelKey.currentState!.toggle();
    await tester.pump();
    expect(find.text('episode list'), findsOneWidget);

    await navigatorKey.currentState!.maybePop();
    await tester.pumpAndSettle();
    expect(closeCount, 1);
    expect(find.text('episode list'), findsNothing);
    expect(find.byType(VideoSidePanel), findsOneWidget);
    expect(routePopCount, 0);

    await navigatorKey.currentState!.maybePop();
    await tester.pumpAndSettle();
    expect(find.text('previous page'), findsOneWidget);
    expect(find.byType(VideoSidePanel), findsNothing);
    expect(routePopCount, 1);
  });

  testWidgets('closing the episode panel releases its back history', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final panelKey = GlobalKey<VideoSidePanelState>();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Text('previous page')),
      ),
    );
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          body: VideoSidePanel(
            key: panelKey,
            fullscreen: true,
            disableAnimations: true,
            child: const Text('episode list'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    panelKey.currentState!.toggle();
    await tester.pump();
    panelKey.currentState!.close();
    await tester.pump();

    await navigatorKey.currentState!.maybePop();
    await tester.pumpAndSettle();
    expect(find.text('previous page'), findsOneWidget);
  });
}
