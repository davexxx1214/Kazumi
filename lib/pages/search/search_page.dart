import 'package:flutter/material.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/bean/card/bangumi_card.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:kazumi/bean/widget/error_widget.dart';
import 'package:kazumi/pages/search/search_controller.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/utils/search_parser.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, this.inputTag = ''});

  final String inputTag;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final SearchController searchController = SearchController();

  /// Don't use modular singleton here. We may have multiple search pages.
  /// Use a new instance of SearchPageController for each search page.
  final SearchPageController searchPageController = SearchPageController();
  final ScrollController scrollController = ScrollController();
  final FocusNode _searchFieldFocusNode = FocusNode();
  final FocusNode _searchButtonFocusNode = FocusNode();
  final FocusNode _settingsButtonFocusNode = FocusNode();

  final List<Tab> tabs = [
    Tab(text: "排序方式"),
    Tab(text: "过滤器"),
  ];

  @override
  void initState() {
    super.initState();
    scrollController.addListener(scrollListener);
    searchPageController.loadSearchHistories();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.inputTag.isNotEmpty) {
        final String tagString = 'tag:${Uri.decodeComponent(widget.inputTag)}';
        searchController.text = tagString;
        _submitSearch(tagString);
      }
    });
  }

  @override
  void dispose() {
    searchPageController.bangumiList.clear();
    scrollController.removeListener(scrollListener);
    _searchFieldFocusNode.dispose();
    _searchButtonFocusNode.dispose();
    _settingsButtonFocusNode.dispose();
    super.dispose();
  }

  void scrollListener() {
    if (scrollController.position.pixels >=
            scrollController.position.maxScrollExtent - 200 &&
        !searchPageController.isLoading &&
        searchController.text != '' &&
        searchPageController.bangumiList.length >= 20) {
      KazumiLogger().i('SearchController: search results is loading more');
      searchPageController.searchBangumi(searchController.text, type: 'add');
    }
  }

  void _submitSearch([String? value]) {
    final String query = (value ?? searchController.text).trim();
    if (query.isEmpty) {
      return;
    }
    searchController.text = query;
    searchPageController.searchBangumi(query, type: 'init');
  }

  String _currentSort() {
    return SearchParser(searchController.text).parseSort() ?? 'heat';
  }

  String _sortLabel(String sort) {
    switch (sort) {
      case 'rank':
        return '按评分排序';
      case 'match':
        return '按匹配程度排序';
      case 'heat':
      default:
        return '按热度排序';
    }
  }

  Future<void> _applySort(String sort) async {
    final String baseQuery = searchController.text.trim();
    final String query = searchPageController.attachSortParams(
      baseQuery,
      sort,
    );
    searchController.text = query;
    if (baseQuery.isNotEmpty) {
      _submitSearch(query);
    }
  }

  Future<void> _showTVSearchSettingsDialog() async {
    await showDialog(
      context: context,
      builder: (context) {
        return Observer(
          builder: (context) {
            final String currentSort = _currentSort();
            return AlertDialog(
              title: const Text('搜索设置'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('排序方式'),
                      const SizedBox(height: 8),
                      for (final String sort in const ['heat', 'rank', 'match'])
                        ListTile(
                          autofocus: sort == currentSort,
                          leading: Icon(
                            currentSort == sort
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                          ),
                          title: Text(_sortLabel(sort)),
                          onTap: () async {
                            await _applySort(sort);
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
                          },
                        ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        title: const Text('不显示已看过的番剧'),
                        value: searchPageController.notShowWatchedBangumis,
                        onChanged: (value) {
                          searchPageController.setNotShowWatchedBangumis(value);
                        },
                      ),
                      SwitchListTile(
                        title: const Text('不显示已抛弃的番剧'),
                        value: searchPageController.notShowAbandonedBangumis,
                        onChanged: (value) {
                          searchPageController.setNotShowAbandonedBangumis(
                            value,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('关闭'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showSearchSettings() async {
    if (isTV) {
      await _showTVSearchSettingsDialog();
      return;
    }
    showModalBottomSheet(
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: (MediaQuery.sizeOf(context).height >=
                LayoutBreakpoint.compact['height']!)
            ? MediaQuery.of(context).size.height * 1 / 4
            : MediaQuery.of(context).size.height,
        maxWidth: (MediaQuery.sizeOf(context).width >=
                LayoutBreakpoint.medium['width']!)
            ? MediaQuery.of(context).size.width * 9 / 16
            : MediaQuery.of(context).size.width,
      ),
      clipBehavior: Clip.antiAlias,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      context: context,
      builder: (context) {
        return showSearchOptionTabBar(
          options: [showSortSwitcher(), showFilterSwitcher()],
        );
      },
    );
  }

  Widget _buildTVSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: searchController,
              focusNode: _searchFieldFocusNode,
              autofocus: widget.inputTag.isEmpty,
              textInputAction: TextInputAction.search,
              onSubmitted: _submitSearch,
              decoration: const InputDecoration(
                hintText: '输入番剧名、tag 或 id',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            focusNode: _searchButtonFocusNode,
            onPressed: () => _submitSearch(),
            icon: const Icon(Icons.search),
            label: const Text('搜索'),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            focusNode: _settingsButtonFocusNode,
            onPressed: _showSearchSettings,
            icon: const Icon(Icons.tune),
            label: const Text('设置'),
          ),
        ],
      ),
    );
  }

  Widget _buildTVSearchHistory() {
    return Observer(
      builder: (context) {
        if (searchPageController.searchHistories.isEmpty) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '搜索历史',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 46,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: searchPageController.searchHistories.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    if (index == searchPageController.searchHistories.length) {
                      return OutlinedButton.icon(
                        onPressed: () {
                          searchPageController.clearSearchHistory();
                        },
                        icon: const Icon(Icons.delete_sweep_outlined),
                        label: const Text('清空历史'),
                      );
                    }
                    final history = searchPageController.searchHistories[index];
                    return OutlinedButton(
                      onPressed: () {
                        searchController.text = history.keyword;
                        _submitSearch(history.keyword);
                      },
                      child: Text(history.keyword),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget showFilterSwitcher() {
    return Wrap(
      children: [
        Observer(
          builder: (context) => InkWell(
            onTap: () {
              searchPageController.setNotShowWatchedBangumis(
                  !searchPageController.notShowWatchedBangumis);
            },
            child: ListTile(
              title: const Text('不显示已看过的番剧'),
              trailing: Switch(
                value: searchPageController.notShowWatchedBangumis,
                onChanged: (value) {
                  searchPageController.setNotShowWatchedBangumis(value);
                },
              ),
            ),
          ),
        ),
        Observer(
          builder: (context) => InkWell(
            onTap: () {
              searchPageController.setNotShowAbandonedBangumis(
                  !searchPageController.notShowAbandonedBangumis);
            },
            child: ListTile(
              title: const Text('不显示已抛弃的番剧'),
              trailing: Switch(
                value: searchPageController.notShowAbandonedBangumis,
                onChanged: (value) {
                  searchPageController.setNotShowAbandonedBangumis(value);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget showSortSwitcher() {
    return Wrap(
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('按热度排序'),
              onTap: () {
                Navigator.pop(context);
                searchController.text = searchPageController.attachSortParams(
                    searchController.text, 'heat');
                searchPageController.searchBangumi(searchController.text,
                    type: 'init');
              },
            ),
            ListTile(
              title: const Text('按评分排序'),
              onTap: () {
                Navigator.pop(context);
                searchController.text = searchPageController.attachSortParams(
                    searchController.text, 'rank');
                searchPageController.searchBangumi(searchController.text,
                    type: 'init');
              },
            ),
            ListTile(
              title: const Text('按匹配程度排序'),
              onTap: () {
                Navigator.pop(context);
                searchController.text = searchPageController.attachSortParams(
                    searchController.text, 'match');
                searchPageController.searchBangumi(searchController.text,
                    type: 'init');
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget showSearchOptionTabBar({required List<Widget> options}) {
    return DefaultTabController(
        length: tabs.length,
        child: Scaffold(
            body: Column(
          children: [
            PreferredSize(
              preferredSize: Size.fromHeight(kToolbarHeight),
              child: Material(
                child: TabBar(
                  tabs: tabs,
                ),
              ),
            ),
            Expanded(
                child: TabBarView(
              children: options,
             ))
           ],
         )));
  }

  Widget _buildSearchResults() {
    return Observer(builder: (context) {
      if (searchPageController.isTimeOut) {
        return Center(
          child: SizedBox(
            height: 400,
            child: GeneralErrorWidget(
              errMsg: '什么都没有找到 (´;ω;`)',
              actions: [
                GeneralErrorButton(
                  onPressed: () {
                    searchPageController.searchBangumi(
                        searchController.text,
                        type: 'init');
                  },
                  text: '点击重试',
                ),
              ],
            ),
          ),
        );
      }

      if (searchPageController.isLoading &&
          searchPageController.bangumiList.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      int crossCount = 3;
      if (MediaQuery.sizeOf(context).width >
          LayoutBreakpoint.compact['width']!) {
        crossCount = 5;
      }
      if (MediaQuery.sizeOf(context).width >
          LayoutBreakpoint.medium['width']!) {
        crossCount = 6;
      }
      List<BangumiItem> filteredList =
          searchPageController.bangumiList.toList();

      if (searchPageController.notShowWatchedBangumis) {
        final watchedBangumiIds =
            searchPageController.loadWatchedBangumiIds();
        filteredList = filteredList
            .where((item) => !watchedBangumiIds.contains(item.id))
            .toList();
      }

      if (searchPageController.notShowAbandonedBangumis) {
        final abandonedBangumiIds =
            searchPageController.loadAbandonedBangumiIds();
        filteredList = filteredList
            .where((item) => !abandonedBangumiIds.contains(item.id))
            .toList();
      }

      if (filteredList.isEmpty && searchController.text.trim().isEmpty) {
        return const Center(
          child: Text('在上方输入关键词开始搜索'),
        );
      }

      Widget gridView = GridView.builder(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          mainAxisSpacing: StyleString.cardSpace - 2,
          crossAxisSpacing: StyleString.cardSpace,
          crossAxisCount: crossCount,
          mainAxisExtent:
              MediaQuery.of(context).size.width / crossCount / 0.65 +
                  MediaQuery.textScalerOf(context).scale(32.0),
        ),
        itemCount: filteredList.length,
        itemBuilder: (context, index) {
          return BangumiCardV(
            enableHero: false,
            bangumiItem: filteredList[index],
          );
        },
      );

      if (isTV) {
        gridView = FocusTraversalGroup(child: gridView);
      }

      return gridView;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SysAppBar(
        backgroundColor: Colors.transparent,
        title: const Text("搜索"),
      ),
      floatingActionButton: isTV
          ? null
          : FloatingActionButton.extended(
              onPressed: _showSearchSettings,
              icon: const Icon(Icons.sort),
              label: const Text("搜索设置"),
            ),
      body: Column(
        children: [
          if (isTV) ...[
            _buildTVSearchBar(),
            _buildTVSearchHistory(),
          ] else
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
              child: FocusScope(
                descendantsAreFocusable: false,
                child: SearchAnchor.bar(
                  searchController: searchController,
                  barElevation: WidgetStateProperty<double>.fromMap(
                    <WidgetStatesConstraint, double>{WidgetState.any: 0},
                  ),
                  viewElevation: 0,
                  viewLeading: IconButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    icon: Icon(Icons.arrow_back),
                  ),
                  isFullScreen: MediaQuery.sizeOf(context).width <
                      LayoutBreakpoint.compact['width']!,
                  suggestionsBuilder: (context, controller) => [
                    Observer(
                      builder: (context) {
                        if (controller.text.isNotEmpty) {
                          return Container(
                            height: 400,
                            alignment: Alignment.center,
                            child: Text("无可用搜索建议，回车以直接检索"),
                          );
                        } else {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (var history in searchPageController
                                  .searchHistories
                                  .take(10))
                                ListTile(
                                  title: Text(history.keyword),
                                  onTap: () {
                                    controller.text = history.keyword;
                                    searchPageController.searchBangumi(
                                        controller.text,
                                        type: 'init');
                                    if (searchController.isOpen) {
                                      searchController
                                          .closeView(history.keyword);
                                    }
                                  },
                                  trailing: IconButton(
                                    icon: const Icon(Icons.close),
                                    onPressed: () {
                                      searchPageController
                                          .deleteSearchHistory(history);
                                    },
                                  ),
                                ),
                            ],
                          );
                        }
                      },
                    ),
                  ],
                  onSubmitted: (value) {
                    searchPageController.searchBangumi(value, type: 'init');
                    if (searchController.isOpen) {
                      searchController.closeView(value);
                    }
                  },
                ),
              ),
            ),
          Expanded(
            child: _buildSearchResults(),
          ),
        ],
      ),
    );
  }
}
