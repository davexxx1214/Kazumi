package com.pichillilorenzo.flutter_inappwebview_android.webview.in_app_webview;

import android.util.Log;
import android.webkit.WebSettings;

import androidx.webkit.WebSettingsCompat;

/** AndroidX's public feature check can pass via the framework while its setter
 * requires provider support (notably on Android 14 Sony TV WebViews).
 * Keep the existing capability guards and normal behavior on other devices.
 */
final class AlgorithmicDarkeningCompat {
  private static final String TAG = "KazumiWebViewCompat";

  static void setAllowed(WebSettings settings, boolean allowed) {
    OptionalWebViewFeature.apply(
        () -> WebSettingsCompat.setAlgorithmicDarkeningAllowed(settings, allowed),
        exception -> Log.w(TAG,
            "WebView provider does not support setAlgorithmicDarkeningAllowed; "
                + "skipping optional darkening setting", exception));
  }

  static Boolean isAllowed(WebSettings settings) {
    return OptionalWebViewFeature.read(
        () -> WebSettingsCompat.isAlgorithmicDarkeningAllowed(settings),
        exception -> Log.w(TAG,
            "WebView provider does not support isAlgorithmicDarkeningAllowed; "
                + "reporting unknown", exception));
  }

  private AlgorithmicDarkeningCompat() {}
}
