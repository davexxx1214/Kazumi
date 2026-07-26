import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/embedded_native_control_area.dart';
import 'package:kazumi/pages/router.dart';
import 'package:kazumi/utils/constants.dart';

class ScaffoldMenu extends StatefulWidget {
  const ScaffoldMenu({super.key});

  @override
  State<ScaffoldMenu> createState() => _ScaffoldMenu();
}

class _ScaffoldMenu extends State<ScaffoldMenu> {
  final _outletKey = GlobalKey<RouterOutletState>();
  final _contentAreaKey = GlobalKey();
  late final FocusNode _tvSearchFocusNode =
      FocusNode(debugLabel: 'tvSearchButton');
  late final List<FocusNode> _tvDestinationFocusNodes = List.generate(
    menu.size,
    (index) => FocusNode(debugLabel: 'tvDestination$index'),
  );
  DateTime? _lastExitPromptAt;

  @override
  void dispose() {
    _tvSearchFocusNode.dispose();
    for (final node in _tvDestinationFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _selectDestination(int index) {
    _lastExitPromptAt = null;
    final currentIndex =
        menu.indexForPath(context.routeState(listen: false).uri.path);
    if (index == currentIndex) {
      return;
    }
    _outletKey.currentState?.navigate('/tab${menu.getPath(index)}/');
  }

  void _handleSystemBack(BuildContext context) {
    if (_outletKey.currentState?.maybePop() ?? false) {
      _lastExitPromptAt = null;
      return;
    }

    final currentIndex =
        menu.indexForPath(context.routeState(listen: false).uri.path);
    if (currentIndex != 0) {
      _selectDestination(0);
      return;
    }

    final now = DateTime.now();
    final lastPromptAt = _lastExitPromptAt;
    if (lastPromptAt == null ||
        now.difference(lastPromptAt) > const Duration(seconds: 2)) {
      _lastExitPromptAt = now;
      KazumiDialog.showToast(message: '再按一次退出应用', context: context);
      return;
    }

    _lastExitPromptAt = null;
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = menu.indexForPath(context.routeState().uri.path);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handleSystemBack(context);
        }
      },
      child: OrientationBuilder(
        builder: (context, orientation) {
          return orientation == Orientation.portrait
              ? _bottomMenu(context, selectedIndex)
              : _sideMenu(context, selectedIndex);
        },
      ),
    );
  }

  Widget _outlet(BuildContext context, {BorderRadius? borderRadius}) {
    Widget child = NotificationListener<NavigationNotification>(
      // A non-poppable outlet must not override the shell's PopScope state.
      onNotification: (notification) => !notification.canHandlePop,
      child: RouterOutlet(key: _outletKey),
    );
    if (borderRadius != null) {
      child = ClipRRect(borderRadius: borderRadius, child: child);
    }
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: borderRadius,
      ),
      child: child,
    );
  }

  Widget _bottomMenu(BuildContext context, int selectedIndex) {
    return Scaffold(
      body: _outlet(context),
      bottomNavigationBar: NavigationBar(
        destinations: const <Widget>[
          NavigationDestination(
            selectedIcon: Icon(Icons.home),
            icon: Icon(Icons.home_outlined),
            label: '推荐',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.timeline),
            icon: Icon(Icons.timeline_outlined),
            label: '时间表',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.favorite),
            icon: Icon(Icons.favorite_outlined),
            label: '追番',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.settings),
            icon: Icon(Icons.settings),
            label: '我的',
          ),
        ],
        selectedIndex: selectedIndex,
        onDestinationSelected: _selectDestination,
      ),
    );
  }

  Widget _buildTVSideMenuButton({
    required FocusNode focusNode,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool selected = false,
  }) {
    return Focus(
      focusNode: focusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
          onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final hasFocus = Focus.of(context).hasFocus;
          final colors = Theme.of(context).colorScheme;
          final foreground =
              hasFocus || selected ? colors.primary : colors.onSurfaceVariant;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
            child: Material(
              color: hasFocus ? colors.primaryContainer : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onPressed,
                child: Container(
                  width: 88,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: hasFocus
                        ? Border.all(color: colors.primary, width: 2)
                        : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: foreground),
                      const SizedBox(height: 8),
                      Text(
                        label,
                        style: TextStyle(
                          color: foreground,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _tvSideMenu(BuildContext context, int selectedIndex) {
    const destinations = <(IconData, IconData, String)>[
      (Icons.home_outlined, Icons.home, '推荐'),
      (Icons.timeline_outlined, Icons.timeline, '时间表'),
      (Icons.favorite_border, Icons.favorite, '追番'),
      (Icons.settings_outlined, Icons.settings, '我的'),
    ];
    return FocusTraversalGroup(
      child: SizedBox(
        width: 120,
        child: Column(
          children: [
            const SizedBox(height: 18),
            _buildTVSideMenuButton(
              focusNode: _tvSearchFocusNode,
              icon: Icons.search,
              label: '搜索',
              onPressed: () => context.pushNamed('/search/'),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: destinations.length,
                padding: const EdgeInsets.only(bottom: 16),
                itemBuilder: (context, index) {
                  final (icon, selectedIcon, label) = destinations[index];
                  final selected = selectedIndex == index;
                  return _buildTVSideMenuButton(
                    focusNode: _tvDestinationFocusNodes[index],
                    icon: selected ? selectedIcon : icon,
                    label: label,
                    selected: selected,
                    onPressed: () => _selectDestination(index),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _handoffTVFocusToMenu(int selectedIndex) {
    final contentContext = _contentAreaKey.currentContext;
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (contentContext == null || focusContext == null) {
      return false;
    }
    final contentBox = contentContext.findRenderObject() as RenderBox?;
    final focusBox = focusContext.findRenderObject() as RenderBox?;
    if (contentBox == null || focusBox == null) {
      return false;
    }
    final contentLeft = contentBox.localToGlobal(Offset.zero).dx;
    final focusLeft = focusBox.localToGlobal(Offset.zero).dx;
    final tolerance = (focusBox.size.width * 0.25).clamp(24.0, 56.0).toDouble();
    if (focusLeft > contentLeft + tolerance) {
      return false;
    }
    _tvDestinationFocusNodes[selectedIndex].requestFocus();
    return true;
  }

  Widget _sideMenu(BuildContext context, int selectedIndex) {
    const borderRadius = BorderRadius.only(
      topLeft: Radius.circular(16),
      bottomLeft: Radius.circular(16),
    );
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      body: Row(
        children: [
          EmbeddedNativeControlArea(
            child: isTV
                ? _tvSideMenu(context, selectedIndex)
                : NavigationRail(
                    backgroundColor:
                        Theme.of(context).colorScheme.surfaceContainer,
                    groupAlignment: 1,
                    leading: FloatingActionButton(
                      elevation: 0,
                      heroTag: null,
                      onPressed: () => context.pushNamed('/search/'),
                      child: const Icon(Icons.search),
                    ),
                    labelType: NavigationRailLabelType.selected,
                    destinations: const <NavigationRailDestination>[
                      NavigationRailDestination(
                        selectedIcon: Icon(Icons.home),
                        icon: Icon(Icons.home_outlined),
                        label: Text('推荐'),
                      ),
                      NavigationRailDestination(
                        selectedIcon: Icon(Icons.timeline),
                        icon: Icon(Icons.timeline_outlined),
                        label: Text('时间表'),
                      ),
                      NavigationRailDestination(
                        selectedIcon: Icon(Icons.favorite),
                        icon: Icon(Icons.favorite_border),
                        label: Text('追番'),
                      ),
                      NavigationRailDestination(
                        selectedIcon: Icon(Icons.settings),
                        icon: Icon(Icons.settings_outlined),
                        label: Text('我的'),
                      ),
                    ],
                    selectedIndex: selectedIndex,
                    onDestinationSelected: _selectDestination,
                  ),
          ),
          Expanded(
            child: Focus(
              onKeyEvent: (node, event) {
                if (isTV &&
                    event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.arrowLeft &&
                    _handoffTVFocusToMenu(selectedIndex)) {
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: KeyedSubtree(
                key: _contentAreaKey,
                child: _outlet(context, borderRadius: borderRadius),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
