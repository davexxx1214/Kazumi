import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/widget/embedded_native_control_area.dart';
import 'package:kazumi/pages/router.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:provider/provider.dart';

class ScaffoldMenu extends StatefulWidget {
  const ScaffoldMenu({super.key});

  @override
  State<ScaffoldMenu> createState() => _ScaffoldMenu();
}

class NavigationBarState extends ChangeNotifier {
  late int _selectedIndex = getDefaultSelectedIndex();
  bool _isHide = false;
  bool _isBottom = false;

  int get selectedIndex => _selectedIndex;

  bool get isHide => _isHide;

  bool get isBottom => _isBottom;

  int getDefaultSelectedIndex() {
    final defaultPage = GStorage.setting
        .get(SettingBoxKey.defaultStartupPage, defaultValue: "/tab/popular/");

    switch (defaultPage) {
      case "/tab/popular/":
        return 0;
      case "/tab/timeline/":
        return 1;
      case "/tab/collect/":
        return 2;
      case "/tab/my/":
        return 3;
      default:
        return 0;
    }
  }

  void updateSelectedIndex(int pageIndex) {
    _selectedIndex = pageIndex;
    notifyListeners();
  }

  void hideNavigate() {
    _isHide = true;
    notifyListeners();
  }

  void showNavigate() {
    _isHide = false;
    notifyListeners();
  }
}

class TVSideMenuController extends ChangeNotifier {
  TVSideMenuController()
      : searchFocusNode = FocusNode(debugLabel: 'tvSearchButton'),
        destinationFocusNodes = List.generate(
          menu.size,
          (index) => FocusNode(debugLabel: 'tvDestination$index'),
        );

  final FocusNode searchFocusNode;
  final List<FocusNode> destinationFocusNodes;
  final GlobalKey contentAreaKey = GlobalKey();

  void requestSearchFocus() {
    searchFocusNode.requestFocus();
  }

  void requestDestinationFocus(int index) {
    if (index < 0 || index >= destinationFocusNodes.length) {
      return;
    }
    destinationFocusNodes[index].requestFocus();
  }

  bool handoffFocusToMenuIfNeeded(int selectedIndex) {
    final BuildContext? contentContext = contentAreaKey.currentContext;
    final BuildContext? primaryFocusContext =
        FocusManager.instance.primaryFocus?.context;
    if (contentContext == null || primaryFocusContext == null) {
      return false;
    }

    final RenderBox? contentBox =
        contentContext.findRenderObject() as RenderBox?;
    final RenderBox? focusBox =
        primaryFocusContext.findRenderObject() as RenderBox?;
    if (contentBox == null || focusBox == null) {
      return false;
    }

    final double contentLeft = contentBox.localToGlobal(Offset.zero).dx;
    final double focusLeft = focusBox.localToGlobal(Offset.zero).dx;
    final double tolerance =
        (focusBox.size.width * 0.25).clamp(24.0, 56.0).toDouble();

    if (focusLeft <= contentLeft + tolerance) {
      requestDestinationFocus(selectedIndex);
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    searchFocusNode.dispose();
    for (final node in destinationFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }
}

class _ScaffoldMenu extends State<ScaffoldMenu> {
  final PageController _page = PageController();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => NavigationBarState()),
        ChangeNotifierProvider(create: (context) => TVSideMenuController()),
      ],
      child: Consumer2<NavigationBarState, TVSideMenuController>(
        builder: (context, state, tvSideMenuController, _) {
          return OrientationBuilder(builder: (context, orientation) {
            state._isBottom = orientation == Orientation.portrait;
            return orientation != Orientation.portrait
                ? sideMenuWidget(context, state, tvSideMenuController)
                : bottomMenuWidget(context, state);
          });
        },
      ),
    );
  }

  Widget bottomMenuWidget(BuildContext context, NavigationBarState state) {
    return Scaffold(
        body: Container(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: PageView.builder(
            physics: const NeverScrollableScrollPhysics(),
            controller: _page,
            itemCount: menu.size,
            itemBuilder: (_, __) => const RouterOutlet(),
          ),
        ),
        bottomNavigationBar: state.isHide
            ? const SizedBox(height: 0)
            : NavigationBar(
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
                selectedIndex: state.selectedIndex,
                onDestinationSelected: (int index) {
                  state.updateSelectedIndex(index);
                  Modular.to.navigate("/tab${menu.getPath(index)}/");
                },
              ));
  }

  void _navigateToIndex(NavigationBarState state, int index) {
    state.updateSelectedIndex(index);
    Modular.to.navigate("/tab${menu.getPath(index)}/");
  }

  Widget _buildTVSideMenuButton({
    required BuildContext context,
    required FocusNode focusNode,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool autofocus = false,
    bool selected = false,
  }) {
    return Focus(
      focusNode: focusNode,
      autofocus: autofocus,
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
          final bool hasFocus = Focus.of(context).hasFocus;
          final ColorScheme colorScheme = Theme.of(context).colorScheme;
          final Color foregroundColor = (hasFocus || selected)
              ? colorScheme.primary
              : colorScheme.onSurfaceVariant;
          final Color backgroundColor = hasFocus
              ? colorScheme.primaryContainer
              : Colors.transparent;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
            child: Material(
              color: backgroundColor,
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
                        ? Border.all(color: colorScheme.primary, width: 2)
                        : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: foregroundColor),
                      const SizedBox(height: 8),
                      Text(
                        label,
                        style: TextStyle(
                          color: foregroundColor,
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

  Widget _buildTVSideMenu(BuildContext context, NavigationBarState state,
      TVSideMenuController tvSideMenuController) {
    final List<(IconData, IconData, String)> destinations = [
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
              context: context,
              focusNode: tvSideMenuController.searchFocusNode,
              icon: Icons.search,
              label: '搜索',
              onPressed: () {
                Modular.to.pushNamed('/search/');
              },
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: destinations.length,
                padding: const EdgeInsets.only(bottom: 16),
                itemBuilder: (context, index) {
                  final (icon, selectedIcon, label) = destinations[index];
                  final bool selected = state.selectedIndex == index;
                  return _buildTVSideMenuButton(
                    context: context,
                    focusNode: tvSideMenuController.destinationFocusNodes[index],
                    icon: selected ? selectedIcon : icon,
                    label: label,
                    selected: selected,
                    autofocus: state.selectedIndex == index,
                    onPressed: () => _navigateToIndex(state, index),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget sideMenuWidget(BuildContext context, NavigationBarState state,
      TVSideMenuController tvSideMenuController) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      body: Row(
        children: [
          EmbeddedNativeControlArea(
            child: Visibility(
              visible: !state.isHide,
              child: isTV
                  ? _buildTVSideMenu(context, state, tvSideMenuController)
                  : NavigationRail(
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceContainer,
                      groupAlignment: 1.0,
                      leading: FloatingActionButton(
                        elevation: 0,
                        heroTag: null,
                        onPressed: () {
                          Modular.to.pushNamed('/search/');
                        },
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
                      selectedIndex: state.selectedIndex,
                      onDestinationSelected: (int index) {
                        _navigateToIndex(state, index);
                      },
                    ),
            ),
          ),
          Expanded(
            child: Focus(
              onKeyEvent: (node, event) {
                if (!isTV || event is! KeyDownEvent) {
                  return KeyEventResult.ignored;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
                    tvSideMenuController
                        .handoffFocusToMenuIfNeeded(state.selectedIndex)) {
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: Container(
                key: tvSideMenuController.contentAreaKey,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16.0),
                    bottomLeft: Radius.circular(16.0),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16.0),
                    bottomLeft: Radius.circular(16.0),
                  ),
                  child: PageView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: menu.size,
                    itemBuilder: (_, __) => const RouterOutlet(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
