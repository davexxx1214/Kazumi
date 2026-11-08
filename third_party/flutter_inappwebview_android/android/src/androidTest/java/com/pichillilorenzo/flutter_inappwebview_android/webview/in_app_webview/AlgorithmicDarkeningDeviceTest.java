package com.pichillilorenzo.flutter_inappwebview_android.webview.in_app_webview;

import androidx.test.platform.app.InstrumentationRegistry;
import org.junit.Test;
import static org.junit.Assert.*;
import android.util.Log;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import androidx.webkit.WebSettingsCompat;
import androidx.webkit.WebViewCompat;
import androidx.webkit.WebViewFeature;

import com.pichillilorenzo.flutter_inappwebview_android.InAppWebViewFlutterPlugin;

import java.util.HashMap;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicReference;

/** Runs without opening an Activity or replacing the installed Kazumi app. */
public class AlgorithmicDarkeningDeviceTest {
  @Test public void testPrepareUpdateReadAndJavascript() throws Throwable {
    CountDownLatch loaded = new CountDownLatch(1);
    AtomicReference<String> result = new AtomicReference<>();
    InAppWebView[] view = {null};
    try {
      InstrumentationRegistry.getInstrumentation().runOnMainSync(() -> {
        InAppWebView webView = new InAppWebView(InstrumentationRegistry.getInstrumentation().getTargetContext());
        view[0] = webView;
        webView.plugin = new InAppWebViewFlutterPlugin();
        webView.plugin.applicationContext = InstrumentationRegistry.getInstrumentation().getTargetContext();
        android.content.pm.PackageInfo provider = WebViewCompat.getCurrentWebViewPackage(webView.getContext());
        Log.i("KazumiCompatTest", "provider=" + provider.packageName + "/" + provider.versionName);
        boolean advertised = WebViewFeature.isFeatureSupported(WebViewFeature.ALGORITHMIC_DARKENING);
        boolean setterSupported = false;
        if (advertised) {
          try {
            WebSettingsCompat.setAlgorithmicDarkeningAllowed(webView.getSettings(), false);
            setterSupported = true;
          } catch (UnsupportedOperationException expected) {
            Log.i("KazumiCompatTest", "CONTROL: original setter reproduces UnsupportedOperationException");
          }
        }
        Log.i("KazumiCompatTest", "advertised=" + advertised + " setterSupported=" + setterSupported);
        webView.prepare();
        Log.i("KazumiCompatTest", "PATCH: prepare passed");
        for (boolean allowed : new boolean[] {true, false}) {
          InAppWebViewSettings settings = new InAppWebViewSettings();
          settings.algorithmicDarkeningAllowed = allowed;
          HashMap<String, Object> updates = new HashMap<>();
          updates.put("algorithmicDarkeningAllowed", allowed);
          webView.setSettings(settings, updates);
          Object actual = settings.getRealSettings(webView).get("algorithmicDarkeningAllowed");
          if (advertised && !setterSupported) assertNull(actual);
          if (setterSupported) assertEquals(Boolean.valueOf(allowed), actual);
        }
        Log.i("KazumiCompatTest", "PATCH: settings update/read passed");
        webView.setWebViewClient(new WebViewClient() {
          @Override public void onPageFinished(WebView view, String url) {
            view.evaluateJavascript("document.querySelector('video').getAttribute('src')", value -> {
              result.set(value);
              loaded.countDown();
            });
          }
        });
        webView.loadDataWithBaseURL("https://fixture.invalid/",
            "<html><body><video src='https://fixture.invalid/video.m3u8'></video></body></html>",
            "text/html", "UTF-8", null);
      });
      assertTrue("WebView page/JS timed out", loaded.await(30, TimeUnit.SECONDS));
      assertEquals("\"https://fixture.invalid/video.m3u8\"", result.get());
      Log.i("KazumiCompatTest", "PATCH: page load and video URL JavaScript passed");
    } finally {
      InstrumentationRegistry.getInstrumentation().runOnMainSync(() -> {
        if (view[0] != null) view[0].destroy();
      });
    }
  }
}
