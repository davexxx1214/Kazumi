import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:kazumi/pages/logs/logs_page.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.applicationSupportPath);

  final String applicationSupportPath;

  @override
  Future<String?> getApplicationSupportPath() async => applicationSupportPath;
}

class _MemoryLogsRepository implements LogsRepository {
  _MemoryLogsRepository(this.content);

  String content;

  @override
  Future<String?> read() async => content;

  @override
  Future<void> clear() async {
    content = '';
  }
}

void main() {
  late Directory tempDirectory;
  late PathProviderPlatform originalPathProvider;

  setUpAll(() async {
    originalPathProvider = PathProviderPlatform.instance;
    tempDirectory = await Directory.systemTemp.createTemp(
      'kazumi_logs_tv_scroll_',
    );
    PathProviderPlatform.instance = _FakePathProvider(tempDirectory.path);
    Hive.init('${tempDirectory.path}/hive');
    await GStorage.init();
  });

  tearDownAll(() async {
    await Hive.close();
    PathProviderPlatform.instance = originalPathProvider;
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tempDirectory.delete(recursive: true);
  });

  testWidgets(
    'TV arrow down scrolls the log list and clear empties it',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LogsPage(
            repository: _MemoryLogsRepository(
              List.generate(300, (index) => 'log line $index').join('\n'),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);

      final verticalScrollable = find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      );
      final scrollableState =
          tester.state<ScrollableState>(verticalScrollable.first);
      expect(scrollableState.position.pixels, 0);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);

      expect(scrollableState.position.pixels, greaterThan(0));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      final clearButton = tester.widget<FloatingActionButton>(
        find.widgetWithText(FloatingActionButton, '清除'),
      );
      expect(clearButton.focusNode?.hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      final copyButton = tester.widget<FloatingActionButton>(
        find.widgetWithIcon(FloatingActionButton, Icons.copy),
      );
      expect(copyButton.focusNode?.hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(clearButton.focusNode?.hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(find.text('暂无日志'), findsOneWidget);
    },
    timeout: const Timeout(Duration(seconds: 30)),
    skip: !isTV,
  );
}
