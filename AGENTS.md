# AGENTS.md

## Cursor Cloud specific instructions

### Project overview

Kazumi is a cross-platform anime streaming and collection Flutter application (v1.9.4). It uses custom XPath-based rules to scrape video sources and provides a built-in video player with Anime4K super-resolution, danmaku overlay, and more. It is a client-only app with no backend; all data comes from third-party public APIs (Bangumi, DanDanPlay).

### Flutter SDK

The project requires **Flutter 3.38.6** (stable channel, Dart 3.10.7). Flutter is installed at `/opt/flutter/bin` and is on `PATH` via `~/.bashrc`.

### Key commands

- **Lint**: `flutter analyze` — exits with code 1 due to ~180 pre-existing info-level warnings (naming conventions, deprecated APIs). No errors or warnings.
- **Test**: `flutter test` — one smoke test in `test/widget_test.dart`. Passes.
- **Build (Linux)**: `flutter build linux` — produces binary at `build/linux/x64/release/bundle/kazumi`.
- **Dependencies**: `flutter pub get`

### Running the Linux app in Cloud VM

- **XDG user directories must be configured.** Run `xdg-user-dirs-update` before first launch or the app will crash with `MissingPlatformDirectoryException`. This is already handled by the update script.
- **Environment variables** needed: `DISPLAY=:1`, `XDG_DATA_HOME=/home/ubuntu/.local/share`, `XDG_CONFIG_HOME=/home/ubuntu/.config`.
- Launch: `DISPLAY=:1 XDG_DATA_HOME=/home/ubuntu/.local/share build/linux/x64/release/bundle/kazumi`
- On first launch, the app shows an X11 environment detection dialog (click "继续" to continue) and a disclaimer (click "已阅读并同意").
- ALSA audio warnings are expected in a headless environment — they don't affect app functionality.
- **Web builds are not supported** — `media_kit` depends on `dart:ffi` which is incompatible with web/WASM targets.

### System dependencies for Linux build

The following system packages are needed (Ubuntu 24.04): `clang cmake libgtk-3-dev ninja-build libayatana-appindicator3-dev unzip webkit2gtk-4.1 libasound2-dev libstdc++-14-dev g++ xdg-user-dirs libva-dev libva-wayland2`.

### Project structure

- `lib/pages/` — UI pages (player, search, settings, history, etc.)
- `lib/modules/` — Data models
- `lib/request/` — HTTP API clients (Bangumi, DanDanPlay)
- `lib/plugins/` — Plugin system for custom video source rules
- `lib/utils/` — Utilities (storage, WebDAV, SyncPlay, proxy, logging)
- `test/` — Contains only a minimal smoke test
