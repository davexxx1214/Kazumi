import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/modules/roads/road_module.dart';
import 'package:kazumi/pages/video/episode_selection_panel.dart';
import 'package:kazumi/utils/constants.dart';

void main() {
  testWidgets(
    'TV episode panel focuses the current episode and selects with remote',
    (tester) async {
      final key = GlobalKey<EpisodeSelectionPanelState>();
      int? chosenEpisode;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EpisodeSelectionPanel(
              key: key,
              title: '测试番剧',
              roads: [
                Road(
                  name: '线路一',
                  data: ['1', '2', '3'],
                  identifier: ['第一集', '第二集', '第三集'],
                ),
              ],
              selectedRoad: 0,
              selectedEpisode: 2,
              downloads: const {},
              onEpisodeSelected: (episode, road) => chosenEpisode = episode,
            ),
          ),
        ),
      );

      final focus = key.currentState!.focusCurrentEpisode();
      await tester.pumpAndSettle();
      await focus;
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'Episode 0:2 menu card',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'Episode 0:3 menu card',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();
      expect(chosenEpisode, 3);
    },
    skip: !isTV,
  );
}
