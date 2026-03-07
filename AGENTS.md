# AGENTS.md

## Repo overview

- This repository is a Flutter application.
- The required Flutter SDK version is pinned in `pubspec.yaml` to `3.41.4`.
- Matching Dart comes from that Flutter release and should resolve to Dart `3.11.1`.

## Cursor Cloud specific instructions

- Cursor Cloud base images for this repo should have Flutter `3.41.4` preinstalled at `/opt/flutter`.
- If `/opt/flutter/bin/flutter --version` does not report `3.41.4`, switch the shared SDK checkout before doing repo work:
  - `git -C /opt/flutter fetch --tags origin`
  - `git -C /opt/flutter checkout 3.41.4`
- Ensure `/opt/flutter/bin` is on `PATH`.
- Run `flutter config --no-analytics` once in the environment if needed.
- In a fresh workspace, run `flutter pub get` from the repository root before analysis or tests.
- Validation commands that should work in this repo after setup:
  - `flutter analyze`
  - `flutter test`

## Testing notes

- `flutter test` includes a networked rule-source regression test, so outbound HTTPS access to `raw.githubusercontent.com` is required.
- Prefer targeted test runs when changing a narrow area, but use full `flutter analyze` and `flutter test` when validating environment readiness.
