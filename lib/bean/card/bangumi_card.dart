import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/card/network_img_layer.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/utils/utils.dart';

// 视频卡片 - 垂直布局
class BangumiCardV extends StatelessWidget {
  const BangumiCardV({
    super.key,
    required this.bangumiItem,
    this.canTap = true,
    this.enableHero = true,
  });

  final BangumiItem bangumiItem;
  final bool canTap;
  final bool enableHero;

  void _openBangumiInfo(BuildContext context) {
    if (!canTap) {
      KazumiDialog.showToast(
        message: '编辑模式',
      );
      return;
    }
    Modular.to.pushNamed('/info/', arguments: bangumiItem);
  }

  Widget _buildCard(BuildContext context, {bool hasFocus = false}) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: hasFocus ? 4 : 0,
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      color: hasFocus ? colorScheme.primaryContainer : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: hasFocus
            ? BorderSide(color: colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: GestureDetector(
        child: InkWell(
          onTap: () => _openBangumiInfo(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 0.65,
                child: LayoutBuilder(builder: (context, boxConstraints) {
                  final double maxWidth = boxConstraints.maxWidth;
                  final double maxHeight = boxConstraints.maxHeight;
                  return enableHero
                      ? Hero(
                          transitionOnUserGestures: true,
                          tag: bangumiItem.id,
                          child: NetworkImgLayer(
                            src: bangumiItem.images['large'] ?? '',
                            width: maxWidth,
                            height: maxHeight,
                          ),
                        )
                      : NetworkImgLayer(
                          src: bangumiItem.images['large'] ?? '',
                          width: maxWidth,
                          height: maxHeight,
                        );
                }),
              ),
              BangumiContent(bangumiItem: bangumiItem)
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isTV) {
      return _buildCard(context);
    }

    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
          _openBangumiInfo(context);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          return _buildCard(
            context,
            hasFocus: Focus.of(context).hasFocus,
          );
        },
      ),
    );
  }
}

class BangumiContent extends StatelessWidget {
  const BangumiContent({super.key, required this.bangumiItem});

  final BangumiItem bangumiItem;

  @override
  Widget build(BuildContext context) {
    final ts = MediaQuery.textScalerOf(context);

    final int maxTextLines = Utils.isDesktop() ? 3 
      : (Utils.isTablet() && MediaQuery.of(context).orientation == Orientation.landscape) ? 3 : 2;

    return Expanded(
      child: Padding(
        // 多列
        padding: const EdgeInsets.fromLTRB(5, 3, 5, 1),
        // 单列
        // padding: const EdgeInsets.fromLTRB(14, 10, 4, 8),
        child: Text(
          bangumiItem.nameCn,
          textAlign: TextAlign.start,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
          textScaler: ts.clamp(maxScaleFactor: 1.1),
          maxLines: maxTextLines,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
