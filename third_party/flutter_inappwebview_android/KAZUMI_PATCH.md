# Kazumi Android WebView compatibility patch

Vendored from the pub.dev `flutter_inappwebview_android` 1.1.3 package (upstream
LICENSE retained). Only the package runtime sources, metadata and documentation
are included; the example application and upstream Dart tests are omitted.

Sony AE2 Android 14 / com.sony.dtv.b2b.webview 1.0.2 passes AndroidX WebKit
1.12.0's ALGORITHMIC_DARKENING public capability check via framework support,
but its provider rejects the compat setter. The shipped APK's DEX debug line
1339 in InAppWebView.prepare maps exactly to that unsupported-operation branch.

The local patch wraps only algorithmic darkening initialization, updates and
reads. Supported providers retain their existing behavior, including the
requested boolean value. UnsupportedOperationException is logged and tolerated;
an unsupported read reports null (unknown). Other exceptions still propagate.
There is no manufacturer/model blacklist, global feature disable, provider
replacement or parser change. This preserves the old Sony VH22 path too.

Regression tests cover supported true/false values, unsupported initialization
and update calls, unknown reads, unrelated failures, and provider isolation.
Run from android: `gradlew :flutter_inappwebview_android:testDebugUnitTest`.

When updating the vendored dependency, review whether upstream has fixed all
three algorithmic-darkening call sites before removing this patch.

## Validation (2026-11-08)

- Five Java/JUnit regression tests passed, including normal providers and the
  unsupported-provider fallback. Flutter TV suite: 260 passed; analyze clean.
- AE2 background instrumentation using this actual patched plugin passed:
  original setter reproduced UnsupportedOperationException;
  prepare, true/false updates, reads, page loading and video-URL JavaScript passed.
- Provider observed: com.sony.dtv.b2b.webview 1.0.2 / Android 14.
- The independent instrumentation package was removed after testing. Existing
  Kazumi and its data were not replaced. No Activity was opened.
- VH22 was unreachable at its last-known ADB endpoint. Its supported-provider
  behavior is regression-tested, but device playback has not been revalidated.
- The page test uses local fixture HTML; this is not a live-source playback test.
- TV release APK built successfully with Flutter 3.47.9. Local signing falls back
  to the debug key because android/key.properties is absent; use the existing CI
  release-signing secrets for an update preserving the installed app's data.
