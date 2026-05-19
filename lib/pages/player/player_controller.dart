import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:media_kit/media_kit.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/pages/player/controller/external_playback_launcher.dart';
import 'package:kazumi/pages/player/controller/player_danmaku_controller.dart';
import 'package:kazumi/pages/player/controller/player_debug_controller.dart';
import 'package:kazumi/pages/player/controller/player_models.dart';
import 'package:kazumi/pages/player/controller/player_panel_controller.dart';
import 'package:kazumi/pages/player/controller/player_playback_controller.dart';
import 'package:kazumi/pages/player/controller/player_syncplay_controller.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/shaders/shaders_controller.dart';

export 'package:kazumi/pages/player/controller/player_models.dart';

class PlayerController {
  final Box setting = GStorage.setting;
  final ShadersController shadersController = Modular.get<ShadersController>();
  final PlayerPanelController panel = PlayerPanelController();
  final PlayerDebugController debug = PlayerDebugController();

  late final PlayerDanmakuController danmaku = PlayerDanmakuController(
    setting: setting,
    isLocalPlayback: () => isLocalPlayback,
  );
  late final PlayerPlaybackController playback = PlayerPlaybackController(
    setting: setting,
    shadersController: shadersController,
    debug: debug,
    videoUrl: () => videoUrl,
    onExitSyncPlayRoom: () => syncplay.exitRoom(),
  );
  late final PlayerSyncPlayController syncplay = PlayerSyncPlayController(
    setting: setting,
    bangumiId: () => bangumiId,
    currentEpisode: () => currentEpisode,
    currentRoad: () => currentRoad,
    playing: () => playback.playing,
    currentPosition: () => playback.currentPosition,
    playerPosition: () => playback.playerPosition,
    duration: () => playback.duration,
    pause: pause,
    play: play,
    seek: seek,
  );
  late final ExternalPlaybackLauncher externalPlayback =
      ExternalPlaybackLauncher(
    videoUrl: () => videoUrl,
    referer: () => referer,
  );

  late int bangumiId;
  late int currentEpisode;
  late int currentRoad;
  late String referer;
  String? coverUrl;
  String videoUrl = '';
  bool isLocalPlayback = false;
  Timer? hideVolumeUITimer;

  Future<bool> init(PlaybackInitParams params) async {
    videoUrl = params.videoUrl;
    isLocalPlayback = params.isLocalPlayback;
    bangumiId = params.bangumiId;
    currentEpisode = params.episode;
    currentRoad = params.currentRoad;
    referer = params.referer;

    KazumiLogger().i(
        'PlayerController: ${params.isLocalPlayback ? "local" : "online"} playback, url: ${params.videoUrl}');

    playback.resetForInit();
    debug.playerLogLevel =
        setting.get(SettingBoxKey.playerLogLevel, defaultValue: 2);
    playback.playerSpeed =
        setting.get(SettingBoxKey.defaultPlaySpeed, defaultValue: 1.0);
    panel.aspectRatioType =
        setting.get(SettingBoxKey.defaultAspectRatioType, defaultValue: 1);

    playback.buttonSkipTime =
        setting.get(SettingBoxKey.buttonSkipTime, defaultValue: 80);
    playback.arrowKeySkipTime =
        setting.get(SettingBoxKey.arrowKeySkipTime, defaultValue: 10);
    try {
      await dispose(
        disposeSyncPlayController: false,
      );
    } catch (_) {}
    final Player? player;
    try {
      player = await playback.createVideoController(
        params.httpHeaders,
        params.adBlockerEnabled,
        offset: params.offset,
      );
    } catch (e) {
      playback.loading = false;
      KazumiLogger()
          .e('PlayerController: failed to initialize video', error: e);
      return false;
    }
    if (player == null || !playback.isCurrentPlayer(player)) {
      return false;
    }

    if (Utils.isDesktop()) {
      playback.volume = playback.volume != -1 ? playback.volume : 100;
      await setVolume(playback.volume);
      if (!playback.isCurrentPlayer(player)) {
        return false;
      }
    } else {
      await FlutterVolumeController.getVolume().then((value) {
        playback.volume = (value ?? 0.0) * 100;
      });
      if (!playback.isCurrentPlayer(player)) {
        return false;
      }

      await FlutterVolumeController.updateShowSystemUI(false);
      if (!playback.isCurrentPlayer(player)) {
        await FlutterVolumeController.updateShowSystemUI(true);
        return false;
      }

      FlutterVolumeController.addListener((volume) {
        if (player == null || !playback.isCurrentPlayer(player)) {
          return;
        }
        playback.volume = volume * 100;
        if (!Platform.isAndroid && !panel.volumeSeeking) {
          panel.showVolume = true;
          hideVolumeUITimer?.cancel();
          hideVolumeUITimer = Timer(const Duration(seconds: 1), () {
            panel.showVolume = false;
            hideVolumeUITimer = null;
          });
        }
      }, category: AudioSessionCategory.playback, emitOnStart: false);
      if (!playback.isCurrentPlayer(player)) {
        return false;
      }
    }
    setPlaybackSpeed(playback.playerSpeed);
    if (!playback.isCurrentPlayer(player)) {
      return false;
    }
    KazumiLogger().i('PlayerController: video initialized');
    playback.loading = false;

    coverUrl = params.coverUrl;

    if (syncplay.syncplayController?.isConnected ?? false) {
      if (syncplay.syncplayController!.currentFileName !=
          "$bangumiId[$currentEpisode]") {
        setSyncPlayPlayingBangumi(
            forceSyncPlaying: true, forceSyncPosition: 0.0);
      }
    }
    return true;
  }

  Future<void> setShader(int type,
      {bool synchronized = true, Player? player}) async {
    await playback.setShader(
      type,
      synchronized: synchronized,
      player: player,
    );

    playerLog.clear();
    setupPlayerDebugInfoSubscription();

    var pp = mediaPlayer!.platform as NativePlayer;
    // media-kit 默认启用硬盘作为双重缓存，这可以维持大缓存的前提下减轻内存压力
    // media-kit 内部硬盘缓存目录按照 Linux 配置，这导致该功能在其他平台上被损坏
    // 该设置可以在所有平台上正确启用双重缓存
    await pp.setProperty("demuxer-cache-dir", await Utils.getPlayerTempPath());
    await pp.setProperty("af", "scaletempo2=max-speed=8");
    if (Platform.isAndroid) {
      await pp.setProperty("volume-max", "100");
      if (androidEnableOpenSLES) {
        await pp.setProperty("ao", "opensles");
      } else {
        await pp.setProperty("ao", "audiotrack");
      }
    }

    // 设置 HTTP 代理
    final bool proxyEnable =
        setting.get(SettingBoxKey.proxyEnable, defaultValue: false);
    if (proxyEnable) {
      final String proxyUrl =
          setting.get(SettingBoxKey.proxyUrl, defaultValue: '');
      final formattedProxy = ProxyUtils.getFormattedProxyUrl(proxyUrl);
      if (formattedProxy != null) {
        await pp.setProperty("http-proxy", formattedProxy);
        KazumiLogger().i('Player: HTTP 代理设置成功 $formattedProxy');
      }
    }

    await mediaPlayer!.setAudioTrack(
      AudioTrack.auto(),
    );

    String? videoRenderer;
    if (Platform.isAndroid) {
      final String androidVideoRenderer =
          setting.get(SettingBoxKey.androidVideoRenderer, defaultValue: 'auto');

      if (androidVideoRenderer == 'auto') {
        // Android 14 及以上使用基于 Vulkan 的 MPV GPU-NEXT 视频输出，着色器性能更好
        // GPU-NEXT 需要 Vulkan 1.2 支持
        // 避免 Android 14 及以下设备上部分机型 Vulkan 支持不佳导致的黑屏问题
        final int androidSdkVersion = await Utils.getAndroidSdkVersion();
        if (androidSdkVersion >= 34) {
          videoRenderer = 'gpu-next';
        } else {
          videoRenderer = 'gpu';
        }
      } else {
        videoRenderer = androidVideoRenderer;
      }
    }

    if (videoRenderer == 'mediacodec_embed') {
      hAenable = true;
      hardwareDecoder = 'mediacodec';
      superResolutionType = 1;
    }

    videoController ??= VideoController(
      mediaPlayer!,
      configuration: VideoControllerConfiguration(
        vo: videoRenderer,
        enableHardwareAcceleration: hAenable,
        hwdec: hAenable ? hardwareDecoder : 'no',
        androidAttachSurfaceAfterVideoParameters: false,
      ),
    );
    mediaPlayer!.setPlaylistMode(PlaylistMode.none);

    // error handle
    // TV版本默认关闭播放器错误提示（因为TV上无法点击dismiss按钮）
    bool showPlayerError =
        setting.get(SettingBoxKey.showPlayerError, defaultValue: !isTV);
    mediaPlayer!.stream.error.listen((event) {
      if (showPlayerError) {
        if (event.toString().contains('Failed to open') && playerBuffering) {
          KazumiDialog.showToast(
              message: '加载失败, 请尝试更换其他视频来源', showActionButton: true);
        } else {
          KazumiDialog.showToast(
              message: '播放器内部错误 ${event.toString()} $videoUrl',
              duration: const Duration(seconds: 5),
              showActionButton: true);
        }
      }
      KazumiLogger()
          .e('PlayerController: Player intent error $videoUrl', error: event);
    });

    if (superResolutionType != 1) {
      await setShader(superResolutionType);
    }

    await mediaPlayer!.open(
      Media(videoUrl,
          start: Duration(seconds: offset), httpHeaders: httpHeaders),
      play: autoPlay,
    );

    return mediaPlayer!;
  }

  Future<void> setShader(int type, {bool synchronized = true}) async {
    var pp = mediaPlayer!.platform as NativePlayer;
    await pp.waitForPlayerInitialization;
    await pp.waitForVideoControllerInitializationIfAttached;
    if (type == 2) {
      await pp.command([
        'change-list',
        'glsl-shaders',
        'set',
        Utils.buildShadersAbsolutePath(
            shadersController.shadersDirectory.path, mpvAnime4KShadersLite),
      ]);
      superResolutionType = 2;
      return;
    }
    if (type == 3) {
      await pp.command([
        'change-list',
        'glsl-shaders',
        'set',
        Utils.buildShadersAbsolutePath(
            shadersController.shadersDirectory.path, mpvAnime4KShaders),
      ]);
      superResolutionType = 3;
      return;
    }
    await pp.command(['change-list', 'glsl-shaders', 'clr', '']);
    superResolutionType = 1;
  }

  Future<void> setPlaybackSpeed(double playerSpeed) async {
    await playback.setPlaybackSpeed(playerSpeed);
    try {
      updateDanmakuSpeed();
    } catch (_) {}
  }

  void updateDanmakuSpeed() {
    danmaku.updateDanmakuSpeed(playback.playerSpeed);
  }

  Future<void> setVolume(double value) async {
    await playback.setVolume(value);
  }

  void syncPlaybackState() {
    playback.syncPlaybackState();
  }

  Future<void> playOrPause() async {
    await playback.playOrPause(pause: pause, play: play);
  }

  Future<void> seek(Duration duration, {bool enableSync = true}) async {
    final player = playback.mediaPlayer;
    if (player == null) return;
    playback.currentPosition = duration;
    danmaku.canvasController.clear();
    try {
      await player.seek(duration);
    } catch (_) {
      return;
    }
    if (syncplay.syncplayController != null) {
      setSyncPlayCurrentPosition();
      if (enableSync) {
        await requestSyncPlaySync(doSeek: true);
      }
    }
  }

  Future<void> pause({bool enableSync = true}) async {
    final player = playback.mediaPlayer;
    if (player == null) return;
    danmaku.canvasController.pause();
    try {
      await player.pause();
    } catch (_) {
      return;
    }
    playback.playing = false;
    if (syncplay.syncplayController != null) {
      setSyncPlayCurrentPosition();
      if (enableSync) {
        await requestSyncPlaySync();
      }
    }
  }

  Future<void> play({bool enableSync = true}) async {
    final player = playback.mediaPlayer;
    if (player == null) return;
    danmaku.canvasController.resume();
    try {
      await player.play();
    } catch (_) {
      return;
    }
    playback.playing = true;
    if (syncplay.syncplayController != null) {
      setSyncPlayCurrentPosition();
      if (enableSync) {
        await requestSyncPlaySync();
      }
    }
  }

  Future<void> dispose({
    bool disposeSyncPlayController = true,
  }) async {
    hideVolumeUITimer?.cancel();
    FlutterVolumeController.removeListener();
    await FlutterVolumeController.updateShowSystemUI(true);
    await playback.dispose(
      disposeSyncPlayController: disposeSyncPlayController,
    );
  }

  Future<void> stop() async {
    await playback.stop();
  }

  Future<Uint8List?> screenshot({String format = 'image/jpeg'}) async {
    return await playback.screenshot(format: format);
  }

  void setButtonForwardTime(int time) {
    playback.buttonSkipTime = time;
    setting.put(SettingBoxKey.buttonSkipTime, time);
  }

  void setArrowKeyForwardTime(int time) {
    playback.arrowKeySkipTime = time;
    setting.put(SettingBoxKey.arrowKeySkipTime, time);
  }

  Future<void> launchExternalPlayer() async {
    await externalPlayback.launch();
  }

  Future<void> createSyncPlayRoom(
      String room,
      String username,
      Future<void> Function(int episode, {int currentRoad, int offset})
          changeEpisode,
      {bool enableTLS = true}) async {
    await syncplay.createRoom(
      room,
      username,
      changeEpisode,
      enableTLS: enableTLS,
    );
  }

  void setSyncPlayCurrentPosition(
      {bool? forceSyncPlaying, double? forceSyncPosition}) {
    syncplay.setCurrentPosition(
      forceSyncPlaying: forceSyncPlaying,
      forceSyncPosition: forceSyncPosition,
    );
  }

  Future<void> setSyncPlayPlayingBangumi(
      {bool? forceSyncPlaying, double? forceSyncPosition}) async {
    await syncplay.setPlayingBangumi(
      forceSyncPlaying: forceSyncPlaying,
      forceSyncPosition: forceSyncPosition,
    );
  }

  Future<void> requestSyncPlaySync({bool? doSeek}) async {
    await syncplay.requestSync(doSeek: doSeek);
  }

  Future<void> sendSyncPlayChatMessage(String message) async {
    await syncplay.sendChatMessage(message);
  }

  Future<void> exitSyncPlayRoom() async {
    await syncplay.exitRoom();
  }
}
