import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/bean/card/rule_card.dart';
import 'package:kazumi/bean/widget/kazumi_menu.dart';

void main() {
  testWidgets('remote arrows reach the rule menu and select operates it', (
    tester,
  ) async {
    final rowFocusNode = FocusNode();
    final menuFocusNode = FocusNode();
    var edited = false;
    addTearDown(rowFocusNode.dispose);
    addTearDown(menuFocusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RuleCard(
            title: '测试规则',
            focusNode: rowFocusNode,
            trailingFocusNode: menuFocusNode,
            onTap: menuFocusNode.requestFocus,
            trailing: KazumiMenuButton(
              menuChildren: [
                KazumiMenuItem(onPressed: () => edited = true, label: '编辑'),
              ],
              builder: (context, toggle) => IconButton(
                focusNode: menuFocusNode,
                onPressed: toggle,
                icon: const Icon(Icons.more_vert),
              ),
            ),
          ),
        ),
      ),
    );

    rowFocusNode.requestFocus();
    await tester.pump();
    expect(rowFocusNode.hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(menuFocusNode.hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(rowFocusNode.hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.text('编辑'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(edited, isTrue);
  });
}
