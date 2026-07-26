import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/empty_state_widget.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:path_provider/path_provider.dart';

abstract interface class LogsRepository {
  Future<String?> read();

  Future<void> clear();
}

class FileLogsRepository implements LogsRepository {
  const FileLogsRepository();

  @override
  Future<String?> read() async {
    final directory = await getApplicationSupportDirectory();
    final file = File('${directory.path}/logs/kazumi_logs.log');
    if (!await file.exists()) {
      return null;
    }
    return file.readAsString();
  }

  @override
  Future<void> clear() async {
    if (!await clearLogs()) {
      throw StateError('Failed to clear logs');
    }
  }
}

class LogsPage extends StatefulWidget {
  const LogsPage({
    super.key,
    this.repository = const FileLogsRepository(),
  });

  final LogsRepository repository;

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  final List<String> _logLines = [];
  final ScrollController _scrollController = ScrollController();
  final FocusNode _scrollFocusNode = FocusNode(debugLabel: 'logs-scroll');
  final FocusNode _clearFocusNode = FocusNode(debugLabel: 'logs-clear');
  final FocusNode _copyFocusNode = FocusNode(debugLabel: 'logs-copy');

  bool _isLoading = true;
  bool _hasError = false;
  String _fullContent = '';

  static const int _initialLoadCount = 50;
  static const int _loadMoreCount = 100;
  int _displayedLines = 0;
  List<String> _allLines = [];

  @override
  void initState() {
    super.initState();
    _loadLogs();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _scrollFocusNode.dispose();
    _clearFocusNode.dispose();
    _copyFocusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted || _displayedLines >= _allLines.length) {
      return;
    }

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final threshold = maxScroll * 0.8;

    if (currentScroll >= threshold) {
      _loadMoreLines();
    }
  }

  KeyEventResult _handleTVScrollKey(FocusNode node, KeyEvent event) {
    if (!isTV || (event is! KeyDownEvent && event is! KeyRepeatEvent)) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (event is KeyDownEvent) {
        _clearFocusNode.requestFocus();
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (event is KeyDownEvent) {
        _copyFocusNode.requestFocus();
      }
      return KeyEventResult.handled;
    }
    if (!_scrollController.hasClients) {
      return KeyEventResult.ignored;
    }

    final direction = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowDown => 1.0,
      LogicalKeyboardKey.arrowUp => -1.0,
      _ => 0.0,
    };
    if (direction == 0) {
      return KeyEventResult.ignored;
    }

    final position = _scrollController.position;
    final target =
        (position.pixels + direction * position.viewportDimension * 0.75)
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble();
    if ((target - position.pixels).abs() < 1) {
      return KeyEventResult.ignored;
    }

    unawaited(
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      ),
    );
    return KeyEventResult.handled;
  }

  KeyEventResult _handleClearButtonKey(FocusNode node, KeyEvent event) {
    if (!isTV || (event is! KeyDownEvent && event is! KeyRepeatEvent)) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (event is KeyDownEvent) {
        _scrollFocusNode.requestFocus();
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (event is KeyDownEvent) {
        _copyFocusNode.requestFocus();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleCopyButtonKey(FocusNode node, KeyEvent event) {
    if (!isTV || (event is! KeyDownEvent && event is! KeyRepeatEvent)) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (event is KeyDownEvent) {
        _clearFocusNode.requestFocus();
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (event is KeyDownEvent) {
        _scrollFocusNode.requestFocus();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _loadLogs() async {
    if (!mounted) return;

    try {
      final content = await widget.repository.read();
      if (!mounted) return;

      if (content != null) {
        _allLines = content.split('\n');
        _fullContent = content;

        final initialCount = _allLines.length < _initialLoadCount
            ? _allLines.length
            : _initialLoadCount;

        if (!mounted) return;
        setState(() {
          _logLines.clear();
          _logLines.addAll(_allLines.take(initialCount));
          _displayedLines = initialCount;
          _isLoading = false;
        });
        _focusLogsOnTV();
      } else {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  void _loadMoreLines() {
    if (_displayedLines >= _allLines.length) {
      return;
    }

    // 使用 Future.microtask 避免在构建过程中调用 setState
    Future.microtask(() {
      if (!mounted) return;

      final remainingLines = _allLines.length - _displayedLines;
      final linesToLoad =
          remainingLines < _loadMoreCount ? remainingLines : _loadMoreCount;

      final newLines = _allLines.skip(_displayedLines).take(linesToLoad);

      if (!mounted) return;
      setState(() {
        _logLines.addAll(newLines);
        _displayedLines += linesToLoad;
      });
    });
  }

  void _focusLogsOnTV() {
    if (!isTV) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scrollFocusNode.requestFocus();
      }
    });
  }

  Future<void> _clearLogs() async {
    try {
      await widget.repository.clear();
      if (!mounted) return;

      setState(() {
        _logLines.clear();
        _allLines.clear();
        _fullContent = '';
        _displayedLines = 0;
      });
    } catch (e) {
      if (!mounted) return;
      KazumiDialog.showToast(message: '清空失败: $e');
    }
  }

  Future<void> _copyLogs() async {
    try {
      await Clipboard.setData(ClipboardData(text: _fullContent));
      if (!mounted) return;
      KazumiDialog.showToast(message: '已复制到剪贴板');
    } catch (e) {
      if (!mounted) return;
      KazumiDialog.showToast(message: '复制失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SysAppBar(
        title: Text('日志'),
      ),
      body: buildBody,
      floatingActionButton: buildFloatingButtons,
    );
  }

  Widget get buildBody {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_hasError) {
      return const Center(
        child: Text('加载日志失败'),
      );
    }

    if (_logLines.isEmpty) {
      return const Center(
        child: GeneralEmptyState(
          icon: Icons.receipt_long_rounded,
          title: '暂无日志',
        ),
      );
    }

    return SelectionArea(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: MediaQuery.of(context).size.width.clamp(600, double.infinity),
          child: Focus(
            focusNode: _scrollFocusNode,
            autofocus: isTV,
            canRequestFocus: isTV,
            onKeyEvent: _handleTVScrollKey,
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16.0),
              shrinkWrap: false,
              itemCount: _logLines.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Text(
                    _logLines[index],
                    softWrap: false,
                    overflow: TextOverflow.clip,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget get buildFloatingButtons {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (isTV)
          Focus(
            canRequestFocus: false,
            skipTraversal: true,
            onKeyEvent: _handleClearButtonKey,
            child: FloatingActionButton.extended(
              heroTag: null,
              focusNode: _clearFocusNode,
              onPressed: _clearLogs,
              tooltip: '清空日志',
              icon: const Icon(Icons.clear_all),
              label: const Text('清除'),
            ),
          )
        else
          FloatingActionButton(
            heroTag: null,
            onPressed: _clearLogs,
            tooltip: '清空日志',
            child: const Icon(Icons.clear_all),
          ),
        const SizedBox(width: 15),
        Focus(
          canRequestFocus: false,
          skipTraversal: isTV,
          onKeyEvent: _handleCopyButtonKey,
          child: FloatingActionButton(
            heroTag: null,
            focusNode: _copyFocusNode,
            onPressed: _copyLogs,
            tooltip: '复制日志',
            child: const Icon(Icons.copy),
          ),
        ),
      ],
    );
  }
}
