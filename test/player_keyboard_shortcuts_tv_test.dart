import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/pages/player/player_keyboard_shortcuts.dart';
import 'package:kazumi/utils/constants.dart';

void main() {
  Future<void> pumpShortcuts(
    WidgetTester tester, {
    required FocusNode focusNode,
    required Map<String, PlayerShortcutAction> actions,
    required Map<String, List<String>> shortcuts,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Focus(
            focusNode: focusNode,
            autofocus: true,
            child: PlayerKeyboardShortcuts(
              focusScopeNode: focusNode,
              actions: actions,
              shortcuts: shortcuts,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(focusNode.hasPrimaryFocus, isTrue);
  }

  testWidgets(
    'TV select remains play/pause when persisted desktop shortcuts exist',
    (tester) async {
      final focusNode = FocusNode();
      var playPauseCount = 0;
      await pumpShortcuts(
        tester,
        focusNode: focusNode,
        actions: <String, PlayerShortcutAction>{
          'playorpause': () => playPauseCount++,
        },
        shortcuts: const <String, List<String>>{
          'playorpause': <String>[' '],
        },
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();

      expect(playPauseCount, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      focusNode.dispose();
    },
    skip: !isTV,
  );

  testWidgets(
    'TV menu key dispatches the episode selection action',
    (tester) async {
      final focusNode = FocusNode();
      var showEpisodesCount = 0;
      await pumpShortcuts(
        tester,
        focusNode: focusNode,
        actions: <String, PlayerShortcutAction>{
          'showepisodes': () => showEpisodesCount++,
        },
        shortcuts: tvShortcuts,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
      await tester.pump();

      expect(showEpisodesCount, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      focusNode.dispose();
    },
    skip: !isTV,
  );
}
